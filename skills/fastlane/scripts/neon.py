#!/usr/bin/env python3
"""neon.py SEAT_DIR -- CMD [ARGS...]
neon.py --dirs

Run one headless `agy --output-format json` call for the neon seat and print its response.
SEAT_DIR gets agy.json (the CLI's raw stdout) and, when the CLI refused something, denied-actions.
agy exits 0 even when it denied an action, sometimes with an empty response, so an empty or
missing response is a failed seat (exit 1). A failed command keeps its exit status; signed out,
agy exits 1 after about 60 seconds with status ERROR and an error field, which stderr repeats.

--dirs checks FASTLANE_NEON_DIRS, the extra folders the seat may read (each one more --add-dir),
and prints each folder, resolved, on its own line; unset, it prints nothing. Entries are separated
by ':'. Each must be an absolute path to an existing folder, in plain characters (letters, digits
and . _ / @ + = , -) as written and resolved. A folder is refused when it is /, the home folder or
one above it, or is inside or holds a hidden entry of the home folder (~/.claude, ~/.codex, ~/.grok,
~/.gemini, ~/.ssh and every other ~/.*, where model configs and credential files live), as written
or resolved, or where such an entry links to. A home folder that cannot be listed refuses them all.
Any refusal exits 2 and names the entry.
"""

import json
import os
from pathlib import Path
import re
import subprocess
import sys

SETTING = "FASTLANE_NEON_DIRS"
PLAIN = re.compile(r"[A-Za-z0-9._/@+=,-]+")


def within(path, folder):
    """path is folder or under it."""
    return path == folder or folder in path.parents


def hidden_in_home(path, homes):
    """path is a hidden entry of a home folder or under one."""
    return any(path != folder and within(path, folder) and path.relative_to(folder).parts[0].startswith(".")
               for folder in homes)


def neon_dirs(value):
    home = Path(os.path.abspath(os.path.expanduser("~")))
    homes = {home, home.resolve()}
    # Where the home's hidden entries lead, for a folder outside home that holds one or is inside one.
    # A home that cannot be listed cannot be checked, so the setting is refused.
    targets = set()
    for folder in homes:
        try:
            names = os.listdir(folder)
        except OSError as exc:
            raise ValueError(f"{SETTING}: cannot list {folder} to check the no-read locations ({exc.strerror})")
        targets.update((folder / name).resolve() for name in names if name.startswith("."))
    dirs = []
    for entry in value.split(":"):
        if not entry:
            raise ValueError(f"{SETTING}: an empty entry in '{value}'")
        if not PLAIN.fullmatch(entry):
            raise ValueError(f"{SETTING}: {entry}: plain paths only (letters, digits and . _ / @ + = , -)")
        if not entry.startswith("/"):
            raise ValueError(f"{SETTING}: {entry}: not an absolute path")
        if not os.path.isdir(entry):
            raise ValueError(f"{SETTING}: {entry}: not an existing folder")
        real = Path(entry).resolve()
        # What is printed is split by the shell, so it must be plain too.
        if not PLAIN.fullmatch(str(real)):
            raise ValueError(f"{SETTING}: {entry}: resolves to {real}, not a plain path")
        for path in (Path(os.path.normpath(entry)), real):
            if any(within(folder, path) for folder in homes):
                raise ValueError(f"{SETTING}: {entry}: holds the home folder and its no-read folders")
            if hidden_in_home(path, homes) or any(within(path, x) or within(x, path) for x in targets):
                raise ValueError(f"{SETTING}: {entry}: inside or holding a no-read location (a hidden entry of ~)")
        dirs.append(str(real))
    return dirs


def main(argv):
    if argv[1:] == ["--dirs"]:
        if SETTING not in os.environ:
            return 0
        try:
            dirs = neon_dirs(os.environ[SETTING])
        except ValueError as exc:
            print(exc, file=sys.stderr)
            return 2
        print("\n".join(dirs))
        return 0
    if len(argv) < 4 or argv[2] != "--":
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        return 2
    seat = Path(argv[1])
    run = subprocess.run(argv[3:], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE)
    (seat / "agy.json").write_bytes(run.stdout)
    try:
        data = json.loads(run.stdout)
    except (UnicodeDecodeError, ValueError):
        data = None
    denied_read = False
    if isinstance(data, dict):
        print(f"neon: status {data.get('status')}, {data.get('num_turns')} turns,"
              f" {data.get('duration_seconds')} s", file=sys.stderr)
        if data.get("error"):
            print(f"neon: agy error: {data['error']}", file=sys.stderr)
        denied = data.get("denied_actions")
        if denied:
            (seat / "denied-actions").write_text(json.dumps(denied, indent=2) + "\n")
            count = len(denied) if isinstance(denied, list) else 1
            print(f"neon: agy denied {count} action(s); see {seat / 'denied-actions'}", file=sys.stderr)
            denied_read = isinstance(denied, list) and any(
                isinstance(action, dict) and action.get("action") == "read_file" for action in denied)
    if run.returncode:
        print(f"neon: agy exited {run.returncode}", file=sys.stderr)
        return run.returncode if run.returncode > 0 else 128 - run.returncode
    if not isinstance(data, dict):
        print(f"neon: agy printed no JSON object; see {seat / 'agy.json'}", file=sys.stderr)
        return 1
    response = data.get("response")
    if not isinstance(response, str) or not response.strip():
        if denied_read:
            # agy records no path for a refused read: it reads only the worktree and --add-dir folders.
            print("neon: empty response, a failed seat: agy denied a read_file, so its brief probably named a"
                  f" file outside the readable folders (the worktree, the brief's lane folder and {SETTING});"
                  f" name that file's folder in {SETTING}", file=sys.stderr)
        else:
            print("neon: empty response, a failed seat", file=sys.stderr)
        return 1
    sys.stdout.write(response if response.endswith("\n") else response + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
