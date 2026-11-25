#!/bin/sh
# implement.sh WORKTREE TASK_FILE OUT_DIR UNIT [TIMEOUT_SECONDS]
#
# Launch codex as the fast-lane implementer in WORKTREE, as its own capped unit (launch-unit.sh).
# The prompt only points at TASK_FILE, so the task can be any length.
# OUT_DIR gets unit, out (codex progress), err, exit and answer.md (codex's final message).
# Model: FASTLANE_IMPL_MODEL (default gpt-6.1-sol); effort is always high. Timeout default 7200 s.
# Tests stay banned unless FASTLANE_TESTS=on (only after the live test is perfect).
set -eu
[ $# -ge 4 ] || { echo "usage: $0 WORKTREE TASK_FILE OUT_DIR UNIT [TIMEOUT_SECONDS]" >&2; exit 2; }
WT=$1 TASK=$2 OUT=$3 UNIT=$4 TO=${5:-7200}
H=$(cd "$(dirname "$0")" && pwd)
[ -d "$WT" ] || { echo "no worktree $WT" >&2; exit 2; }
[ -s "$TASK" ] || { echo "no task file $TASK" >&2; exit 2; }
case "$TASK" in /*) ;; *) TASK=$(pwd)/$TASK ;; esac
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
CODEX=$HOME/.npm-global/bin/codex; [ -x "$CODEX" ] || CODEX=$(command -v codex)
TIMEOUT=$(command -v timeout)
# FASTLANE_TESTS=on is for the task that brings the tests back after the live test passed.
if [ "${FASTLANE_TESTS:-off}" = on ]; then
  T="Tests are back: run, fix, edit or add tests only as the task file says."
else
  T="Tests are suspended: do not run, fix, edit or add tests. Compile only what the task file says gets deployed."
fi
P="Read the task file $TASK in full before doing anything, then do exactly what it says. Work only in $WT. Do not commit, push, deploy, change branches, stash, reset, or write any issue tracker. $T Do all the work the task asks before you stop. Leave something undone only for a named obstacle: evidence that a requirement cannot be met as written, one specific step with what you tried and why each attempt failed, something the task reserves for the manager or the owner, or the time limit. Work that merely remains is not an obstacle; keep going. Finish by writing the handoff file the task names; if anything is undone, it names the obstacle."
FASTLANE_CWD=$WT exec "$H/launch-unit.sh" "$UNIT" "$OUT" -- \
  "$TIMEOUT" "$TO" "$CODEX" exec --dangerously-bypass-approvals-and-sandbox \
  -m "${FASTLANE_IMPL_MODEL:-gpt-6.1-sol}" -c model_reasoning_effort=high \
  -c model_auto_compact_token_limit=250000 -o "$OUT/answer.md" "$P"
