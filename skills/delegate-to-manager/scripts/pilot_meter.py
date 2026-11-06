#!/usr/bin/env python3
"""Local pilot accounting. Transcripts are inspected for metadata only."""
import argparse
from collections import defaultdict
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import math
from pathlib import Path
import sys
import uuid


LIMITS = dict(accepted=5, attempts=10, usd=100, active_seconds=8 * 3600)
STATUSES = {"running", "accepted", "failed", "abandoned", "stopped"}


def timestamp(value):
    result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if result.tzinfo is None:
        raise ValueError("timestamps must include a timezone")
    return result.astimezone(timezone.utc)


def now():
    return datetime.now(timezone.utc).isoformat()


def records(path):
    with Path(path).open(encoding="utf-8") as stream:
        for number, line in enumerate(stream, 1):
            try:
                yield json.loads(line)
            except ValueError:
                raise ValueError(f"invalid JSON record at {path}:{number}") from None


def claude_counts(usage):
    parts = [p for p in usage.get("iterations", []) if p.get("type") == "message"] or [usage]
    five = sum((p.get("cache_creation") or {}).get("ephemeral_5m_input_tokens", 0) for p in parts)
    hour = sum((p.get("cache_creation") or {}).get("ephemeral_1h_input_tokens", 0) for p in parts)
    return dict(input_uncached=usage.get("input_tokens", 0), cache_read=usage.get("cache_read_input_tokens", 0),
                cache_write_5m=five, cache_write_1h=hour,
                cache_write_untiered=max(0, usage.get("cache_creation_input_tokens", 0) - five - hour),
                output=usage.get("output_tokens", 0),
                web_searches=(usage.get("server_tool_use") or {}).get("web_search_requests", 0))


def codex_counts(usage):
    cached, writes = usage.get("cached_input_tokens", 0), usage.get("cache_write_input_tokens", 0)
    return dict(input_uncached=usage.get("input_tokens", 0)-cached-writes,
                cache_read=cached, cache_write_untiered=writes, output=usage.get("output_tokens", 0))


def scan_sources(sources, since, until, prices):
    """Keep finalized usage across streaming records and stale transcript copies."""
    calls, boundaries = {}, {}
    modern_sessions = set()
    modern_signatures = set()

    def remember(collection, key, value):
        previous = collection.get(key)
        if previous and previous["role"] != value["role"]:
            raise ValueError("one usage identity has conflicting role assignments")
        scopes = (previous["bounds"] if previous else set()) | {value["bounds"]}
        chosen = value
        if previous and "counts" in value:
            if (previous["model"], previous["fast"]) != (value["model"], value["fast"]):
                raise ValueError("conflicting model or speed for one usage identity")
            fields = previous["counts"].keys() | value["counts"].keys()
            old, new = previous["counts"], value["counts"]
            if value.get("format") == "counter" and old != new:
                raise ValueError("conflicting cumulative usage copies")
            old_ge = all(old.get(k, 0) >= new.get(k, 0) for k in fields)
            new_ge = all(new.get(k, 0) >= old.get(k, 0) for k in fields)
            if not old_ge and not new_ge:
                raise ValueError("incomparable usage copies; cannot identify finalized counts")
            if old_ge and (not new_ge or timestamp(previous["ts"]) > timestamp(value["ts"])):
                chosen = previous
        collection[key] = dict(chosen, bounds=scopes)

    for source in sources:
        path, role = Path(source["path"]), source.get("role", "unattributed")
        bounds = (max(since, timestamp(source["since"])) if source.get("since") else since,
                  min(until, timestamp(source["until"])) if source.get("until") else until)
        if bounds[0] >= bounds[1]:
            raise ValueError("source window must intersect its attempt")
        if not path.is_file() or path.suffix != ".jsonl":
            raise ValueError(f"missing or non-JSONL transcript: {path}")
        model, session = "unknown", str(path.resolve())
        has_records, counters, no_id = False, [], defaultdict(int)
        for entry in records(path):
            kind = entry.get("type")
            payload = entry.get("payload") or {}
            ts = entry.get("timestamp")
            if kind == "session_meta":
                session = payload.get("id") or payload.get("session_id") or session
            elif kind == "turn_context":
                model = payload.get("model", model)
            elif kind == "assistant":
                message = entry.get("message") or {}
                usage = message.get("usage")
                if usage and message.get("id"):
                    counts = claude_counts(usage)
                    if message.get("model") == "<synthetic>" and not any(counts.values()):
                        continue
                    base = ("claude", message["id"])
                    remember(calls, base, dict(ts=ts, model=message.get("model", "unknown"), role=role,
                                       counts=counts, fast=usage.get("speed") == "fast", bounds=bounds))
                    for index, part in enumerate(usage.get("iterations", [])):
                        if part.get("type") == "advisor_message":
                            remember(calls, base + (index,), dict(ts=ts, model=part.get("model", "unknown"),
                                role=role, counts=claude_counts(part), fast=False, bounds=bounds))
            elif kind == "token_usage_record":
                has_records = True
                modern_sessions.add(session)
                usage = payload.get("usage")
                if not usage:
                    raise ValueError("Codex per-call record lacks usage")
                response = payload.get("response_id")
                if response is None:
                    no_id[ts] += 1
                    key = ("codex", session, "no-response", ts, no_id[ts])
                else:
                    key = ("codex", "response", response)
                remember(calls, key, dict(ts=ts, model=model, role=role, fast=False, bounds=bounds,
                         session=session, format="record", counts=codex_counts(usage)))
                modern_signatures.add((session, timestamp(ts), model, tuple(sorted(codex_counts(usage).items()))))
            elif kind == "event_msg" and payload.get("type") == "token_count":
                info = payload.get("info") or {}
                if info.get("total_token_usage"):
                    counters.append((ts, model, info["total_token_usage"]))
                elif info.get("last_token_usage"):
                    raise ValueError("Codex counter record lacks cumulative usage")
            if kind == "system" and entry.get("subtype") == "compact_boundary":
                key = ("claude", entry.get("uuid") or (str(path), ts))
                metadata = entry.get("compactMetadata") or {}
                remember(boundaries, key, dict(ts=ts, role=role, pre_tokens=metadata.get("preTokens"), bounds=bounds))
            elif kind == "event_msg" and payload.get("type") == "context_compacted":
                remember(boundaries, ("codex", session, ts), dict(ts=ts, role=role, pre_tokens=None, bounds=bounds))
        if not has_records:
            previous, previous_total = {}, 0
            for ts, counter_model, total in counters:
                current_total = total.get("total_tokens", total.get("input_tokens", 0)+total.get("output_tokens", 0))
                if current_total == previous_total:
                    continue
                base = previous if current_total > previous_total else {}
                delta = {k:total.get(k, 0)-base.get(k, 0) for k in total}
                key = ("codex", session, "counter", ts, json.dumps(total, sort_keys=True))
                remember(calls, key, dict(ts=ts, model=counter_model, role=role, fast=False, bounds=bounds,
                         session=session, format="counter", counts=codex_counts(delta)))
                previous, previous_total = total, current_total
    totals = defaultdict(lambda: defaultdict(float))
    selected, unknown = [], set()
    for key, call in calls.items():
        if call.get("format") == "counter" and call.get("session") in modern_sessions:
            signature = (call["session"], timestamp(call["ts"]), call["model"], tuple(sorted(call["counts"].items())))
            if signature in modern_signatures:
                continue
            raise ValueError("mixed record/counter copies lack corroborating per-call usage")
        if not call["ts"]:
            raise ValueError("usage record missing timestamp")
        if not any(a <= timestamp(call["ts"]) < b for a,b in call["bounds"]):
            continue
        counts, provider = call["counts"], key[0]
        if any(not isinstance(n, (int, float)) or not math.isfinite(n) or n < 0 for n in counts.values()):
            raise ValueError("invalid token count")
        model = call["model"]
        rates = prices.get(provider, {}).get(model)
        # Dated snapshots and bracketed variants inherit their canonical price.
        if rates is None:
            import re
            canonical = re.sub(r"(?:-\d{8}|\[[^]]+\])$", "", model)
            rates = prices.get(provider, {}).get(canonical)
        cost = None
        context = sum(v for k, v in counts.items() if k not in {"output", "web_searches"})
        if rates:
            rates = dict(rates)
            if provider == "codex" and context > rates.get("long_context", {}).get("threshold", float("inf")):
                rates.update(rates["long_context"])
            names = dict(input_uncached="input", cache_write_untiered="cache_write_1h")
            if provider == "codex":
                names["cache_read"] = "cached_input"
                names["cache_write_untiered"] = "cache_write"
            cost = 0
            for field, value in counts.items():
                if not value or field == "web_searches":
                    continue
                rate = rates[names.get(field, field)]
                if not math.isfinite(rate) or rate < 0:
                    raise ValueError("invalid price rate")
                cost += value * rate / 1e6
            if call["fast"]:
                cost *= rates.get("fast_multiplier", 1)
            if counts.get("web_searches"):
                if "web_search_per_request" not in rates:
                    unknown.add(provider + ":" + model + ":web_search_fee")
                else:
                    cost += counts["web_searches"] * rates["web_search_per_request"]
        else:
            unknown.add(provider + ":" + model)
        bucket = totals[(provider, call["role"], model)]
        for field, value in counts.items():
            bucket[field] += value
        bucket["calls"] += 1
        bucket["known_usd"] += cost or 0
        selected.append(dict(identity=list(key), ts=call["ts"], role=call["role"], input=context))
    compact = [dict(provider=key[0], **{k:v for k,v in value.items() if k != "bounds"})
               for key, value in boundaries.items()
               if value["ts"] and any(a <= timestamp(value["ts"]) < b for a,b in value["bounds"])]
    return dict(usage=[dict(provider=k[0], role=k[1], model=k[2], **v) for k, v in sorted(totals.items())],
                known_usd=sum(v["known_usd"] for v in totals.values()), unpriced=sorted(unknown),
                compactions=compact, calls=selected)


def source_reads(path, attempt, since, until, seen=None):
    if not path:
        return dict(source_bytes=None, reread_bytes=None, events=0)
    seen = {} if seen is None else seen
    total, repeated, count = 0, 0, 0
    ids = set()
    for event in records(path):
        if event.get("attempt") != attempt or event.get("role") != "manager":
            continue
        if not since <= timestamp(event["ts"]) < until or event["id"] in ids:
            continue
        ids.add(event["id"])
        start, size = event["start"], event["bytes"]
        end = start + size
        if start < 0 or size < 0:
            raise ValueError("invalid read range")
        spans = seen.get(event["sha256"], [])
        repeated += sum(max(0, min(end, b) - max(start, a)) for a, b in spans)
        merged = []
        for a, b in sorted(spans + [(start, end)]):
            if merged and a <= merged[-1][1]:
                merged[-1] = (merged[-1][0], max(b, merged[-1][1]))
            else:
                merged.append((a, b))
        seen[event["sha256"]] = merged
        total += size
        count += 1
    return dict(source_bytes=total, reread_bytes=repeated, events=count)


def attempt_report(attempt, prices, snapshot, read_history=None):
    if attempt["status"] != "running" and not attempt.get("until"):
        raise ValueError("terminal attempts require an exclusive until timestamp")
    start, end = timestamp(attempt["since"]), timestamp(attempt.get("until") or snapshot)
    if start >= end or attempt["status"] not in STATUSES:
        raise ValueError("invalid attempt interval or status")
    result = scan_sources(attempt["sources"], start, end, prices)
    reads = source_reads(attempt.get("read_journal"), attempt["id"], start, end, read_history)
    issues = list(attempt.get("control_failures", []))
    if attempt.get("quality", {}).get("material_regression"):
        issues.append("material_quality_regression")
    spans = sorted((timestamp(s["since"]), timestamp(s.get("until") or snapshot))
                   for s in attempt.get("manager_activity", []))
    for index, (a, b) in enumerate(spans):
        if a < start or b > end or a >= b:
            raise ValueError("manager activity must fit the attempt window")
        if index and a < spans[index - 1][1]:
            issues.append("overlapping_manager_activity")
    active = sum((b - a).total_seconds() for a, b in spans) if spans else (end - start).total_seconds()
    complete = (attempt.get("coverage_complete") is True and not result["unpriced"] and bool(result["calls"])
                and bool(spans) and reads["source_bytes"] is not None)
    managers = [c for c in result["calls"] if c["role"] == "manager"]
    latest = max(managers, key=lambda c: timestamp(c["ts"])) if managers else None
    return dict(id=attempt["id"], phase_id=attempt["phase_id"], phase_type=attempt["phase_type"], status=attempt["status"],
                since=start.isoformat(), until=end.isoformat(), **result, reads=reads,
                active_seconds=active, active_basis="recorded_turn_intervals" if spans else "attempt_wall_upper_bound",
                coverage_complete=complete, control_failures=issues,
                latest_manager_input=latest["input"] if latest else None,
                quality=attempt.get("quality", {}), metering_lag=attempt.get("metering_lag", "not reported"))


def report(manifest, prices, snapshot):
    if manifest.get("pilot") != "lean-native-r2" or not manifest.get("repository"):
        raise ValueError("manifest must identify lean-native-r2 and its approved repository")
    registered = {a["id"]:a for a in manifest.get("attempts", [])}
    journals = {Path(a["read_journal"]).resolve() for a in registered.values() if a.get("read_journal")}
    for path in journals:
        for event in records(path):
            if event.get("role") != "manager":
                continue
            owner = registered.get(event.get("attempt"))
            if owner is None:
                raise ValueError("read journal references an unregistered attempt")
            if not owner.get("read_journal") or Path(owner["read_journal"]).resolve() != path:
                raise ValueError("read event is in the wrong attempt journal")
            if not timestamp(owner["since"]) <= timestamp(event["ts"]) < timestamp(owner.get("until") or snapshot):
                raise ValueError("read event is outside its registered attempt window")
    history = defaultdict(dict)
    attempts = [attempt_report(a, prices, snapshot, history[a["phase_id"]])
                for a in sorted(manifest.get("attempts", []), key=lambda a: timestamp(a["since"]))]
    if len({a["id"] for a in attempts}) != len(attempts):
        raise ValueError("duplicate attempt id")
    identities = set()
    for attempt in attempts:
        for call in attempt["calls"]:
            key = tuple(call["identity"])
            if key in identities:
                raise ValueError("a usage call belongs to multiple attempts")
            identities.add(key)
    ordered = sorted(attempts, key=lambda a: timestamp(a["since"]))
    if any(timestamp(b["since"]) < timestamp(a["until"]) for a, b in zip(ordered, ordered[1:])):
        raise ValueError("attempt windows overlap")
    accepted = [a["phase_id"] for a in attempts if a["status"] == "accepted"]
    if len(set(accepted)) != len(accepted):
        raise ValueError("a phase was accepted more than once")
    totals = dict(accepted=len(accepted), attempts=len(attempts),
                  usd=sum(a["known_usd"] for a in attempts), active_seconds=sum(a["active_seconds"] for a in attempts))
    for field in ["source_bytes", "reread_bytes"]:
        totals[field] = (sum(a["reads"][field] for a in attempts)
                         if all(a["reads"][field] is not None for a in attempts) else None)
    reasons = [key + "_ceiling" for key, limit in LIMITS.items() if totals[key] >= limit]
    reasons += [a["id"] + ":" + failure for a in attempts for failure in a["control_failures"]]
    reasons += [a["id"] + ":incomplete_metering" for a in attempts if not a["coverage_complete"]]
    reasons += [a["id"] + ":still_running" for a in attempts if a["status"] == "running"]
    return dict(snapshot=snapshot, repository=manifest["repository"], pilot=manifest["pilot"],
                attempts=attempts, totals=totals, ceilings=LIMITS, stop_reasons=reasons,
                next_attempt="STOP" if reasons else "WITHIN_RECORDED_LIMITS",
                cost_per_accepted_phase=totals["usd"] / totals["accepted"] if totals["accepted"] else None,
                setup_usd=manifest.get("setup_usd"),
                note="Sampled API-equivalent accounting; not a hard billing cap. Unknown coverage is not zero.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prices", type=Path, default=Path(__file__).resolve().parents[2] / "token-ledger/scripts/prices.json")
    sub = parser.add_subparsers(dest="command", required=True)
    scan = sub.add_parser("scan", help="usage/compactions for explicit transcripts or bounded roots")
    scan.add_argument("--transcript", action="append", type=Path, default=[])
    scan.add_argument("--root", action="append", type=Path, default=[])
    scan.add_argument("--since", required=True)
    scan.add_argument("--until", required=True, help="exclusive, timezone required")
    summary = sub.add_parser("report", help="recompute every attempt and all four ceilings")
    summary.add_argument("manifest", type=Path)
    summary.add_argument("--at", default=None, help="UTC snapshot for running attempts")
    read = sub.add_parser("read", help="emit source bytes and journal metadata; never use on transcripts/secrets")
    read.add_argument("--source", required=True, type=Path)
    read.add_argument("--journal", required=True, type=Path)
    read.add_argument("--attempt", required=True)
    read.add_argument("--start", type=int, default=0)
    read.add_argument("--bytes", type=int, required=True)
    card = sub.add_parser("card", help="validate the reader's bounded card, without rewriting it")
    card.add_argument("source", type=Path)
    args = parser.parse_args()
    if args.command == "read":
        if args.start < 0 or args.bytes < 0:
            raise ValueError("negative source range")
        digest = hashlib.sha256()
        with args.source.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
            stream.seek(args.start)
            selected = stream.read(args.bytes)
        sys.stdout.buffer.write(selected)
        sys.stdout.buffer.flush()
        event = dict(id=str(uuid.uuid4()), ts=now(), attempt=args.attempt, role="manager",
                     sha256=digest.hexdigest(), start=args.start, bytes=len(selected))
        args.journal.parent.mkdir(parents=True, exist_ok=True)
        with args.journal.open("a") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            stream.write(json.dumps(event) + "\n")
        return 0
    if args.command == "card":
        body = args.source.read_bytes()
        if body.count(b"BEGIN CARD") != 1 or body.count(b"END CARD") != 1:
            raise ValueError("exactly one BEGIN CARD / END CARD pair is required")
        start = body.index(b"BEGIN CARD") + len(b"BEGIN CARD")
        end = body.index(b"END CARD")
        if start > end:
            raise ValueError("card markers are reversed")
        words = len(body[start:end].decode("utf-8").split())
        print(json.dumps(dict(words=words, within_limit=words <= 250,
                              start=start, bytes=end-start, sha256=hashlib.sha256(body).hexdigest())))
        return 0 if words <= 250 else 1
    prices = json.loads(args.prices.read_text())
    if args.command == "scan":
        paths = set(args.transcript)
        for root in args.root:
            if not root.is_dir():
                raise ValueError("transcript root does not exist")
            paths.update(root.rglob("*.jsonl"))
        if not paths or timestamp(args.since) >= timestamp(args.until):
            raise ValueError("provide transcripts or roots and a valid time interval")
        result = scan_sources([dict(path=str(p)) for p in sorted(paths)], timestamp(args.since), timestamp(args.until), prices)
        result.update(reads=dict(source_bytes=None, reread_bytes=None), active_time="unknown without attempt turn intervals",
                      ceilings=LIMITS, pilot_totals=None,
                      admission="UNKNOWN: use report with the attempt manifest for running totals and admission")
    else:
        manifest = json.loads(args.manifest.read_text())
        for attempt in manifest.get("attempts", []):
            for source in attempt["sources"]:
                source["path"] = str(args.manifest.resolve().parent / source["path"])
            if attempt.get("read_journal"):
                attempt["read_journal"] = str(args.manifest.resolve().parent / attempt["read_journal"])
        result = report(manifest, prices, args.at or now())
    print(json.dumps(result, indent=2))
    return 3 if args.command == "report" and result["next_attempt"] == "STOP" else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError) as error:
        print(f"pilot_meter: {error}", file=sys.stderr)
        sys.exit(2)
