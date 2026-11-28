#!/usr/bin/env python3
"""Launch the shared reader seats on an owner question and tally their ballots."""

import argparse
from collections import Counter
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time


SCRIPTS = Path(__file__).resolve().parent
REQUIRED = ("opus", "astra", "sol", "grok")
SEATS = (*REQUIRED, "fable")  # what a launch seated before the seats file listed its seats
WAITED = (*REQUIRED, "neon")  # optional neon, once seated, is waited on like grok
FIELDS = ("PICK", "RANKING", "CAN LIVE WITH", "ARGUMENT")


def option_ids(path):
    options = path.read_text().split()
    if (len(options) < 2 or len(set(options)) != len(options)
            or any(not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", option) for option in options)):
        raise ValueError(f"{path}: expected at least two distinct option IDs (letters, digits, _ or -)")
    return options


def panel_seats(fable, neon=False):
    """The seats to launch: all of REQUIRED, or without astra when FASTLANE_SEATS leaves it out,
    then optional neon and fable when named by flag or by FASTLANE_SEATS."""
    names, required = [], REQUIRED
    if "FASTLANE_SEATS" in os.environ:
        # review.sh owns the switch's checks and prints the accepted list.
        listed = subprocess.run(
            [SCRIPTS / "review.sh", "--seats"], stdout=subprocess.PIPE, text=True,
        )
        if listed.returncode:
            raise ValueError("FASTLANE_SEATS refused; see the message above")
        names = listed.stdout.split()
        required = tuple(seat for seat in REQUIRED if seat in names)
        if required not in (REQUIRED, ("opus", "sol", "grok")):
            raise ValueError("FASTLANE_SEATS: a decision panel seats opus, sol and grok,"
                             f" with astra optional, plus optional neon and fable: {' '.join(names)}")
    optional = (("neon",) if neon or "neon" in names else ()) + (("fable",) if fable or "fable" in names else ())
    return (*required, *optional)


def seated(out):
    """The seats a launch started; an output directory from before the seats file had them all."""
    try:
        return (out / "seats").read_text().split()
    except FileNotFoundError:
        return list(SEATS)


def launch(args):
    if not args.worktree.is_dir():
        raise ValueError(f"no worktree at {args.worktree}")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", args.tag):
        raise ValueError("tag must start with a letter or digit and use only letters, digits, _ or -")
    question = (args.brief / "question.md").read_text().strip()
    if not question:
        raise ValueError("question.md is empty")
    options = option_ids(args.brief / "options")
    seats = panel_seats(args.fable, args.neon)
    # review.sh checks it again at launch; checking here first leaves no output directory behind.
    if "FASTLANE_NEON_DIRS" in os.environ and subprocess.run(
            [SCRIPTS / "neon.py", "--dirs"], stdout=subprocess.DEVNULL).returncode:
        raise ValueError("FASTLANE_NEON_DIRS refused; see the message above")
    lenses = {}
    for seat in seats:
        path = args.brief / f"{seat}.lens.md"
        if path.is_file():
            lenses[seat] = path.read_text()

    out = args.out.resolve()
    out.mkdir(parents=True)
    (out / "options").write_text("\n".join(options) + "\n")
    (out / "seats").write_text(" ".join(seats) + "\n")
    for seat, lens in lenses.items():
        (out / f"{seat}.lens.md").write_text(lens)
    brief = out / "brief.md"
    brief.write_text(f"""{question}

## Ballot

Use only these option IDs: {', '.join(options)}.
Return exactly four plain-text lines, with these labels and no other text or code fences:

PICK: <one option ID>
RANKING: <all option IDs, best first, separated by spaces>
CAN LIVE WITH: <acceptable option IDs separated by spaces, or - if none>
ARGUMENT: <your strongest argument for the pick, on one line>
""")
    status = subprocess.run([
        SCRIPTS / "review.sh", "--decision", args.worktree.resolve(), brief, out, args.tag, *seats,
    ]).returncode
    if status == 0:
        (out / "launch-complete").touch()
    return status


def ballot(directory, options):
    try:
        if (directory / "exit").read_text().strip() != "success exited 0":
            return None
        lines = (directory / "answer.md").read_text().strip().splitlines()
    except (FileNotFoundError, UnicodeDecodeError):
        return None
    if len(lines) != len(FIELDS):
        return None

    values = []
    for field, line in zip(FIELDS, lines):
        label, colon, value = line.partition(":")
        if not colon or label != field or not value.strip():
            return None
        values.append(value.strip())
    pick, ranking, acceptable, argument = values
    rank = ranking.split()
    if rank[0] != pick or Counter(rank) != Counter(options):
        return None
    if acceptable != "-":
        choices = acceptable.split()
        if len(set(choices)) != len(choices) or not set(choices).issubset(options):
            return None
    return pick, argument


def tally(out, options):
    # An unseated seat is not a missing or failed one: it is left out of the panel entirely.
    seats = seated(out)
    answers = {}
    for seat in seats:
        answer = ballot(out / seat, options)
        if answer is not None:
            answers[seat] = answer

    counts = Counter(pick for pick, _ in answers.values())
    total = len(answers)
    unseated = [seat for seat in REQUIRED if seat not in seats]
    verdict = "OWNER_DECISION"
    if total:
        pick, votes = counts.most_common(1)[0]
        opus_agrees = "opus" in answers and answers["opus"][0] == pick
        # Without astra, a unanimous vote needs opus in it and at least two answers.
        if ((votes == total and (not unseated or (opus_agrees and total >= 2)))
                or (opus_agrees and (votes, total) in {(2, 3), (3, 4), (4, 5)})):
            verdict = f"{pick} accepted under the owner's 2026-11-05 panel rule"

    counts_line = " ".join(f"{option}={counts[option]}" for option in options)
    result = f"Not seated: {' '.join(unseated)}\n" if unseated else ""
    result += f"Counts ({total} answering): {counts_line}\nVERDICT: {verdict}\n"
    synthesis = ["# Decision panel", ""]
    for seat in (*REQUIRED, *(("neon",) if "neon" in seats else ()), "fable"):
        if seat in answers:
            pick, argument = answers[seat]
            synthesis.append(f"- {seat} picked {pick}. {argument}")
        elif seat in unseated:
            synthesis.append(f"- {seat} was not seated.")
        else:
            synthesis.append(f"- {seat} had no valid completed ballot.")
    synthesis.extend(["", "## Tally", "", result])
    return "\n".join(synthesis)


def wait_for_readers(out, deadline_seconds):
    end = time.monotonic() + min(deadline_seconds, 3300)
    # Wait on each seated required seat, and neon, so a gone unit cannot end the wait for the others.
    seats = seated(out)
    for seat in (seat for seat in WAITED if seat in seats):
        directory = out / seat
        # A launch error can be reported after systemd has already started the unit.
        if not (directory / "unit").is_file():
            continue
        remaining = max(0, round(end - time.monotonic()))
        status = subprocess.run(
            [SCRIPTS / "wait.sh", str(remaining), directory], stdout=sys.stderr,
        ).returncode
        if status == 2:
            # wait.sh cannot distinguish a gone unit from a failed systemd query.
            unit = (directory / "unit").read_text().strip()
            state = subprocess.run(
                ["systemctl", "--user", "show", "--property=ActiveState", "--value", "--", unit],
                stdout=subprocess.PIPE, text=True,
            )
            if state.returncode or state.stdout.strip() not in ("inactive", "failed"):
                print(f"cannot confirm {unit} stopped; retry collection", file=sys.stderr)
                return 2
        elif status not in (0, 1):
            return status
    return 0


def collect(args):
    if args.deadline_seconds < 0:
        raise ValueError("deadline must be a non-negative number of seconds")
    out = args.out.resolve()
    if not (out / "launch-complete").is_file():
        raise ValueError(f"{out}: launch did not complete; use a fresh output directory and tag to retry")
    synthesis = out / "synthesis.md"
    if not synthesis.is_file():
        options = option_ids(out / "options")
        status = wait_for_readers(out, args.deadline_seconds)
        if status:
            return status
        # Publish a complete file once, even if another collector finishes at the same time.
        with tempfile.NamedTemporaryFile(mode="w", dir=out) as pending:
            pending.write(tally(out, options))
            pending.flush()
            try:
                os.link(pending.name, synthesis)
            except FileExistsError:
                pass
    print(synthesis.read_text().rsplit("\n## Tally\n\n", 1)[1], end="")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    start = commands.add_parser("launch", help="launch readers and return")
    start.add_argument("worktree", type=Path)
    start.add_argument("brief", type=Path, help="directory containing question.md and options")
    start.add_argument("out", type=Path, help="fresh output directory")
    start.add_argument("tag", help="fresh unit name suffix")
    start.add_argument("--fable", action="store_true", help="include optional fable")
    start.add_argument("--neon", action="store_true", help="include optional neon (agy), waited on like grok")
    finish = commands.add_parser("collect", help="wait for required seats and neon, then write synthesis.md")
    finish.add_argument("deadline_seconds", type=int, help="wait in seconds, capped at 3300")
    finish.add_argument("out", type=Path)
    args = parser.parse_args()
    try:
        return launch(args) if args.command == "launch" else collect(args)
    except (OSError, ValueError) as exc:
        parser.exit(2, f"{parser.prog}: {exc}\n")


if __name__ == "__main__":
    raise SystemExit(main())
