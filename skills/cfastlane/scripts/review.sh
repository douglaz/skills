#!/bin/sh
# review.sh PKT [SEAT...]
#
# Launch the packet's independent reviewers on PKT/review-brief.md. Seats default to: opus (one
# reviewer). Any of fastlane's seats can be named instead: opus astra sol fable.
# Each PKT/review/SEAT gets unit, err, exit and answer.md; units are named fastlane-NAME-SEAT.
# Stamps PKT/review-start, which `meter.py PKT --phase review` counts from.
# A re-review needs the old PKT/review moved aside first.
set -eu
[ $# -ge 1 ] || { echo "usage: $0 PKT [SEAT...]" >&2; exit 2; }
H=$(cd "$(dirname "$0")" && pwd)
F=${CFASTLANE_FASTLANE_SCRIPTS:-$H/../../fastlane/scripts}
[ -x "$F/review.sh" ] || { echo "fastlane scripts not found at $F (install the fastlane skill beside this one)" >&2; exit 2; }
PKT=$(cd "$1" && pwd); shift
[ $# -gt 0 ] || set -- opus
[ -s "$PKT/review-brief.md" ] || { echo "no $PKT/review-brief.md" >&2; exit 2; }
[ ! -e "$PKT/review" ] || { echo "$PKT/review exists: move it aside before a re-review" >&2; exit 3; }
PY=$(command -v python3)
NAME=$("$PY" -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$PKT/config.json")
WT=$("$PY" -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["worktree"])' "$PKT/config.json")
date +%s > "$PKT/review-start"
exec "$F/review.sh" "$WT" "$PKT/review-brief.md" "$PKT/review" "$NAME" "$@"
