#!/bin/sh
# review.sh PKT [--out OUT_DIR] [--tag TAG] [SEAT...]
#
# Launch the packet's independent reviewers on PKT/review-brief.md. Seats default to:
# opus astra sol grok (when available), or fastlane's FASTLANE_SEATS list when that is set.
# Optional fable is never waited on.
# Each PKT/review/SEAT gets unit, err, exit and answer.md; units are named fastlane-NAME-SEAT.
# Stamps PKT/review-start, which `meter.py PKT --phase review` counts from.
# Retries/re-reviews use fresh --out and --tag values; never move an active seat's directory.
set -eu
[ $# -ge 1 ] || { echo "usage: $0 PKT [--out OUT_DIR] [--tag TAG] [SEAT...]" >&2; exit 2; }
H=$(cd "$(dirname "$0")" && pwd)
F=${CFASTLANE_FASTLANE_SCRIPTS:-$H/../../fastlane/scripts}
[ -x "$F/review.sh" ] || { echo "fastlane scripts not found at $F (install the fastlane skill beside this one)" >&2; exit 2; }
PKT=$(cd "$1" && pwd); shift
# session.sh keeps the caller's FASTLANE_NEON_DIRS in PKT/neon-dirs, since the session's unit does not
# inherit the environment; a value set here wins. Fastlane's review.sh checks it before launching.
if [ "${FASTLANE_NEON_DIRS+set}" != set ] && [ -s "$PKT/neon-dirs" ]; then
  FASTLANE_NEON_DIRS=$(cat "$PKT/neon-dirs"); export FASTLANE_NEON_DIRS
fi
OUT=$PKT/review TAG=
while [ $# -gt 0 ]; do
  case $1 in
    --out|--tag)
      [ $# -ge 2 ] || { echo "$1 needs a value" >&2; exit 2; }
      if [ "$1" = --out ]; then OUT=$2; else TAG=$2; fi
      shift 2 ;;
    *) break ;;
  esac
done
# Without named seats, take fastlane's default: FASTLANE_SEATS when set, checked before anything starts.
if [ $# -eq 0 ]; then SEATS=$("$F/review.sh" --seats) || exit 2; set -- $SEATS; fi
[ -s "$PKT/review-brief.md" ] || { echo "no $PKT/review-brief.md" >&2; exit 2; }
[ ! -e "$OUT" ] || { echo "$OUT exists: use a fresh --out and --tag for a retry or re-review" >&2; exit 3; }
PY=$(command -v python3)
NAME=$("$PY" -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$PKT/config.json")
WT=$("$PY" -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["worktree"])' "$PKT/config.json")
# Compare the fixed instruction and Report blocks with the shared template, not a second copy.
# Other fields hold the packet's goal, paths and re-review context; the session may fill those only.
"$PY" -I - "$F/../references/prompts.md" "$PKT/review-brief.md" <<'PY'
import sys
from pathlib import Path
source, brief = (Path(p).read_text() for p in sys.argv[1:])
template = source.split('## Review brief (', 1)[1].split('```markdown\n', 1)[1].split('\n```', 1)[0]
instructions = template.split('\n\n', 2)[1]
report = '\n## Report\n' + template.split('\n## Report\n', 1)[1]
if instructions not in brief or not brief.rstrip().endswith(report.rstrip()):
    sys.exit('review brief reworded: keep fixed reviewer instructions and Report section unchanged')
PY
[ -s "$PKT/review-start" ] || date +%s > "$PKT/review-start"
exec "$F/review.sh" "$WT" "$PKT/review-brief.md" "$OUT" "${TAG:-$NAME}" "$@"
