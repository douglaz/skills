#!/bin/sh
# session.sh PKT [NOTE_FILE]
#
# Start the packet's one combined session (it plans, implements, builds, reviews and judges), or
# resume it.
#
#   session.sh PKT             first turn: the session reads PKT/task.md
#   session.sh PKT NOTE_FILE   later turn: resume the same session; it reads NOTE_FILE
#
# PKT/config.json needs "name" and "worktree". Each turn gets PKT/turns/N/session (unit, out, err,
# exit, answer.md); the unit is named cfl-NAME-sN. The first turn stamps PKT/meter-start, which the
# meter counts from, and records the worktree's HEAD in PKT/base. Inherited uncommitted work is kept,
# as in fastlane; save its resume copy before launching. A later turn always resumes the same session: its
# history comes back from cache, so nothing is read in twice.
# Model: CFASTLANE_MODEL (default gpt-6.2-sol); effort is always high. Timeout: CFASTLANE_TIMEOUT
# seconds (default 21600: coding, two 90-minute review rounds and one seat retry fit in a turn).
# Caps, exit file and the disk floor come from fastlane's launch-unit.sh.
set -eu
[ $# -ge 1 ] && [ $# -le 2 ] || { echo "usage: $0 PKT [NOTE_FILE]" >&2; exit 2; }
H=$(cd "$(dirname "$0")" && pwd)
F=${CFASTLANE_FASTLANE_SCRIPTS:-$H/../../fastlane/scripts}
[ -x "$F/launch-unit.sh" ] || { echo "fastlane scripts not found at $F (install the fastlane skill beside this one)" >&2; exit 2; }
PKT=$(cd "$1" && pwd)
[ -s "$PKT/config.json" ] || { echo "no $PKT/config.json" >&2; exit 2; }
PY=$(command -v python3)
NAME=$("$PY" -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$PKT/config.json")
WT=$("$PY" -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["worktree"])' "$PKT/config.json")
case "$NAME" in ''|*[!A-Za-z0-9._-]*) echo "config name: letters, digits and . _ - only" >&2; exit 2 ;; esac
[ -d "$WT" ] || { echo "no worktree $WT" >&2; exit 2; }
mkdir -p "$PKT/turns"
N=1; while [ -e "$PKT/turns/$N" ]; do N=$((N + 1)); done
if [ "$N" -gt 1 ]; then
  PREV=$PKT/turns/$((N - 1))/session
  [ -s "$PREV/exit" ] || { echo "turn $((N - 1)) has not ended ($PREV/exit missing)" >&2; exit 3; }
fi
CODEX=$HOME/.npm-global/bin/codex; [ -x "$CODEX" ] || CODEX=$(command -v codex)
TIMEOUT=$(command -v timeout)
if [ "${FASTLANE_TESTS:-off}" = on ]; then
  TESTS="Tests are back: run, fix, edit or add tests only as the task file says."
else
  TESTS="Tests are suspended: do not run, fix, edit or add tests. Compile only what the task file says gets deployed."
fi
if [ $# -eq 1 ]; then
  [ "$N" -eq 1 ] || { echo "turn $N needs a NOTE_FILE: the session is resumed, never restarted" >&2; exit 2; }
  [ -s "$PKT/task.md" ] || { echo "no $PKT/task.md" >&2; exit 2; }
  git -C "$WT" rev-parse HEAD > "$PKT/base"
  date +%s > "$PKT/meter-start"
  P="Read the task file $PKT/task.md in full before doing anything, then do exactly what it says. Work only in $WT and under $PKT. Do not commit, push, deploy, change branches, stash, reset or write any issue tracker. $TESTS"
  set --
else
  [ "$N" -gt 1 ] || { echo "no earlier turn to resume: run $0 PKT first" >&2; exit 2; }
  NOTE=$2; case "$NOTE" in /*) ;; *) NOTE=$(pwd)/$NOTE ;; esac
  [ -s "$NOTE" ] || { echo "no note file $NOTE" >&2; exit 2; }
  ID=$(sed -n 's/^session id: *\([A-Za-z0-9-][A-Za-z0-9-]*\).*/\1/p' "$PKT"/turns/*/session/err | head -n 1)
  [ -n "$ID" ] || { echo "no session id in $PKT/turns/*/session/err" >&2; exit 3; }
  P="Read the note $NOTE in full, then continue under the same task file and the same rules. $TESTS"
  set -- resume "$ID"
fi
P="$P In this turn write the review brief from the fixed fastlane template, filling fields without rewording reviewer instructions or P0-P3 lines. Run $H/review.sh $PKT (it probes grok), wait on required seats with $F/wait.sh, judge every finding, repair accepted P0/P1 and re-review the delta under the task's rules. Do not launch models or agents except through that reviewer launcher. Never lower a reviewer's P0/P1 on your own: end your turn with the evidence and call for the owner. Also end for an owner call if you raise a finding to P0/P1 and will not fix it. The assistant relays those calls; it does not judge. Finish by writing the handoff, final review and judgement paths, and commit message files the task names. If the turn ends with reviewers still active, report their units and exit paths so the same session can be resumed without launching duplicates."
P="$P Read $H/../SKILL.md for the review and wait rules, and read $F/../references/prompts.md for the exact fixed review template. For a failed seat's one retry or a delta re-review, run $H/review.sh $PKT --out $PKT/review-<round> --tag <fresh-tag> [SEAT...], using a fresh output directory and tag. Never move active readers' directories. Wait on the required seat directories under the --out just launched, including grok only when that round launched it; read grok-missing from that same output. Never use an earlier round's exit files or wait on fable."
T=$PKT/turns/$N
mkdir -p "$T"  # the turn exists from here on, whatever the launch does
FASTLANE_CWD=$WT "$F/launch-unit.sh" "cfl-$NAME-s$N" "$T/session" -- \
  "$TIMEOUT" "${CFASTLANE_TIMEOUT:-21600}" "$CODEX" exec "$@" --dangerously-bypass-approvals-and-sandbox \
  -m "${CFASTLANE_MODEL:-gpt-6.2-sol}" -c model_reasoning_effort=high \
  -c model_auto_compact_token_limit=250000 -o "$T/session/answer.md" "$P"
echo "turn $N: wait on $T/session"
