#!/usr/bin/env python3
"""File a fastlane followups.md in the current worktree's tracked Beads export."""
import argparse
from dataclasses import dataclass
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from typing import Optional


@dataclass(frozen=True)
class Entry:
    priority: int
    label: str
    title: str
    location: str
    body: str
    existing: Optional[str]

    @property
    def description(self):
        return f"Location: {self.location}\n\n{self.body}"


def markdown_sections(text):
    sections = [[]]
    fence = None
    for line in text.splitlines(keepends=True):
        marker = re.match(r"(`{3,}|~{3,})(.*)", line)
        if fence:
            if marker and marker[1][0] == fence[0] and len(marker[1]) >= len(fence) and not marker[2].strip():
                fence = None
        elif marker and (marker[1][0] == "~" or "`" not in marker[2]):
            fence = marker[1]
        elif line.startswith("## "):
            sections.append([line[3:]])
            continue
        sections[-1].append(line)
    if fence:
        raise ValueError("close the fenced block in followups.md before filing")
    return ["".join(section) for section in sections]


def entries_from(path):
    sections = markdown_sections(path.read_text(encoding="utf-8"))
    if sections[0].strip() not in ("", "# Follow-ups"):
        raise ValueError("expected # Follow-ups or an entry heading")
    entries = []
    for section in sections[1:]:
        heading, _, fields = section.partition("\n")
        match = re.fullmatch(r"(?:[0-9]+ )?P([0-3]) (\S.*)", heading)
        if not match:
            raise ValueError(f"invalid entry heading: {heading}")
        priority = int(match[1])
        title = match[2]
        if priority <= 1:
            disposition = re.fullmatch(r"\[(preexisting|cap)\] (\S.*)", title)
            if not disposition:
                raise ValueError(f"invalid disposition: {heading}")
            label = "review-preexisting" if disposition[1] == "preexisting" else "review-followup"
            title = disposition[2]
        else:
            label = "review-followup" if priority == 2 else "review-nit"
        metadata, *body_parts = re.split(r"\n(?:[ \t]*\n)+", fields, maxsplit=1)
        body = re.sub(r"(?:\n[ \t]*)+\Z", "", body_parts[0]) if body_parts else ""
        location, *extra = metadata.splitlines()
        if not re.fullmatch(r"Location: \S.*:[1-9][0-9]*", location) or not body.strip():
            raise ValueError(f"expected Location: file:line and a body for {heading}")
        existing = None
        if extra:
            if len(extra) != 1 or not re.fullmatch(r"Existing: \S+", extra[0]):
                raise ValueError(f"invalid Existing field for {heading}")
            existing = extra[0][len("Existing: "):]
        entries.append(Entry(priority, label, title.rstrip(), location[len("Location: "):],
                             body, existing))
    return entries


def run(*args, input=None):
    result = subprocess.run(args, input=input, check=True, stdout=subprocess.PIPE, text=True)
    return result.stdout


def br(*args, input=None):
    return json.loads(run("br", "--no-auto-flush", "--no-auto-import", *args, "--json", input=input))


def export_rows(data):
    return [json.loads(line) for line in data.splitlines() if line.strip()]


def identity(status):
    return (status["path"], status["head"]["object_id"], status["index"]["object_id"],
            status["worktree_raw_git_blob_hash"])


def observe(export, relative):
    status = br("vcs-status")
    if (status.get("schema") != "br.vcs-export-status.v2" or status.get("available") is not True
            or status.get("vcs") != "git" or status.get("tracked") is not True
            or status.get("path_scope") != "workspace" or status.get("path") != relative
            or not all(isinstance(value, str) and value for value in identity(status))):
        raise ValueError("cannot verify the tracked Beads export in this worktree")
    data = export.read_bytes()
    if hashlib.sha256(data).hexdigest() != status.get("worktree_raw_sha256"):
        raise ValueError("Beads export changed during admission")
    return status, data


def matching_open(entry, rows):
    for row in rows:
        if row["status"] in ("closed", "tombstone") or row["priority"] > entry.priority:
            continue
        if row["id"] == entry.existing or (
            row["title"] == entry.title and row.get("description") == entry.description
        ):
            return row["id"]
    return None


def export_diff(export, *flags):
    return run("git", "--no-pager", "--literal-pathspecs", "-c", "core.fsmonitor=false",
               "diff", "--no-ext-diff", "--no-textconv", "--text", *flags, "--", str(export))


def review_export(export, relative, current, before, entry, new_id):
    status, after = observe(export, relative)
    diff = export_diff(export, "HEAD")
    lines = after.splitlines(keepends=True)
    added = [line for line in lines if line.strip() and json.loads(line)["id"] == new_id]
    if len(added) == 1:
        issue = json.loads(added[0])
        lines.remove(added[0])
        if (identity(status)[:3] == identity(current)[:3] and b"".join(lines) == before
                and diff and issue["title"] == entry.title
                and issue["description"] == entry.description and issue["priority"] == entry.priority
                and issue["issue_type"] == "task" and issue["status"] == "open"
                and issue["labels"] == [entry.label]):
            return status, issue
    print(diff, file=sys.stderr, end="")
    raise ValueError(f"unexpected export after filing {new_id}. Inspect the changes before continuing")


def file_entries(entries, export, relative):
    status, data = observe(export, relative)
    approved = json.loads(os.environ.get("BEADS_REVIEWED", "null"))
    rows = export_rows(data)
    known_ids = {row["id"] for row in rows}
    for entry in entries:
        if entry.existing and entry.existing not in known_ids:
            raise ValueError(f"unknown Existing bead: {entry.existing}")
    for entry in entries:
        duplicate = matching_open(entry, rows)
        current, before = observe(export, relative)
        clean = current.get("index_clean") is True and current.get("worktree_clean") is True
        if identity(current) != identity(status) or (
            not duplicate and not clean and (approved is None or identity(current) != identity(approved))
        ):
            print(export_diff(export, "--cached", "HEAD"), file=sys.stderr, end="")
            print(export_diff(export), file=sys.stderr, end="")
            raise ValueError("existing Beads JSONL changes. Review them before writing")
        sync = br("sync", "--status")
        stored_hash = sync.get("jsonl_content_hash")
        coverage = sync.get("coverage") or {}
        fresh_empty = (stored_hash is None and not before
                       and coverage.get("db_exportable_issues") == 0
                       and coverage.get("jsonl_unique_ids") == 0)
        fresh_export = sync.get("jsonl_newer") is False and stored_hash == current["worktree_raw_sha256"]
        if sync.get("dirty_count") != 0 or sync.get("coverage_drift") is not False or not (fresh_empty or fresh_export):
            raise ValueError("the Beads database and export have pending changes")
        if identity(observe(export, relative)[0]) != identity(current):
            raise ValueError("Beads export changed before filing")
        if duplicate:
            print(f"Skipped {duplicate} {entry.title}", flush=True)
            continue
        issue = br("create", f"--title={entry.title}", "--type", "task", "--priority",
                   str(entry.priority), "--labels", entry.label, "--description-file", "-",
                   input=entry.description)
        new_id = issue["id"]
        if identity(observe(export, relative)[0]) != identity(current):
            raise ValueError(f"Beads export changed during create of {new_id}. Inspect before flushing")
        if br("sync", "--status").get("dirty_count") != 1:
            raise ValueError(f"unexpected pending tracker changes after creating {new_id}. Inspect before flushing")
        try:
            br("sync", "--flush-only")
        except subprocess.CalledProcessError as error:
            raise ValueError(f"could not export {new_id}. Inspect the tracker before retrying") from error
        status, issue = review_export(export, relative, current, before, entry, new_id)
        approved = status
        rows.append(issue)
        print(f"Filed {new_id} {entry.title}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("followups", type=Path)
    args = parser.parse_args()
    try:
        entries = entries_from(args.followups)
        if not entries:
            return
        if not shutil.which("br"):
            raise ValueError("br is unavailable. File these follow-ups by hand")
        root = Path(run("git", "rev-parse", "--show-toplevel").strip())
        export = Path(br("where")["jsonl_path"])
        if not export.is_absolute() or root not in export.resolve().parents:
            raise ValueError("Beads export is outside the current worktree")
        relative = str(export.relative_to(root))
        lock = Path(run("git", "rev-parse", "--git-path", "fastlane-followups.lock").strip())
        with lock.open("ab") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)
            file_entries(entries, export, relative)
    except (OSError, KeyError, TypeError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"file-followups: {error}")


if __name__ == "__main__":
    main()
