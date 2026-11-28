#!/usr/bin/env python3
"""neon.py SEAT_DIR -- CMD [ARGS...]

Run one headless `agy --output-format json` call for the neon seat and print its response.
SEAT_DIR gets agy.json (the CLI's raw stdout) and, when the CLI refused something, denied-actions.
agy exits 0 even when it denied an action, sometimes with an empty response, so an empty or
missing response is a failed seat (exit 1). A failed command keeps its exit status; signed out,
agy exits 1 after about 60 seconds with status ERROR and an error field, which stderr repeats.
"""

import json
from pathlib import Path
import subprocess
import sys


def main(argv):
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
    if run.returncode:
        print(f"neon: agy exited {run.returncode}", file=sys.stderr)
        return run.returncode if run.returncode > 0 else 128 - run.returncode
    if not isinstance(data, dict):
        print(f"neon: agy printed no JSON object; see {seat / 'agy.json'}", file=sys.stderr)
        return 1
    response = data.get("response")
    if not isinstance(response, str) or not response.strip():
        print("neon: empty response, a failed seat", file=sys.stderr)
        return 1
    sys.stdout.write(response if response.endswith("\n") else response + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
