#!/bin/sh
# implement.sh WORKTREE TASK_FILE OUT_DIR UNIT [TIMEOUT_SECONDS]
#
# Launch the fast-lane implementer in WORKTREE, as its own capped unit (launch-unit.sh).
# The prompt only points at TASK_FILE, so the task can be any length.
# OUT_DIR gets unit, err, exit and answer.md (the final message); codex also writes out (its progress).
# Engine: FASTLANE_IMPL_ENGINE, codex (the default) or claude, for quota balancing; anything else is refused.
# Model: FASTLANE_IMPL_MODEL (default gpt-6.2-sol, or claude-opus-5-5 for claude); effort is always high.
# Timeout default 7200 s.
# Only task-required checks run until FASTLANE_TESTS=on (after the live test is perfect).
set -eu
[ $# -ge 4 ] || { echo "usage: $0 WORKTREE TASK_FILE OUT_DIR UNIT [TIMEOUT_SECONDS]" >&2; exit 2; }
WT=$1 TASK=$2 OUT=$3 UNIT=$4 TO=${5:-7200}
ENGINE=${FASTLANE_IMPL_ENGINE:-codex}
case "$ENGINE" in codex|claude) ;; *) echo "FASTLANE_IMPL_ENGINE must be codex or claude: $ENGINE" >&2; exit 2 ;; esac
H=$(cd "$(dirname "$0")" && pwd)
[ -d "$WT" ] || { echo "no worktree $WT" >&2; exit 2; }
[ -s "$TASK" ] || { echo "no task file $TASK" >&2; exit 2; }
case "$TASK" in /*) ;; *) TASK=$(pwd)/$TASK ;; esac
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
TIMEOUT=$(command -v timeout)
# FASTLANE_TESTS=on is for the task that brings the tests back after the live test passed.
if [ "${FASTLANE_TESTS:-off}" = on ]; then
  T="Tests are back: run, fix, edit or add tests only as the task file says."
else
  T="Other tests are suspended: do not run, fix, edit or add them. For standalone builds, compile only what the task says gets deployed."
fi
T="Run every check the task names as required, in full, including its tests. That is never a reason to stop. $T"
P="Read the task file $TASK in full before doing anything, then do exactly what it says. Work only in $WT. Do not commit, push, deploy, change branches, stash, reset, or write any issue tracker. $T Do all the work the task asks before you stop. Leave something undone only for a named obstacle: evidence that a requirement cannot be met as written, one specific step with what you tried and why each attempt failed, something the task reserves for the manager or the owner, or the time limit. Work that merely remains is not an obstacle; keep going. Finish by writing the handoff file the task names; if anything is undone, it names the obstacle."
if [ "$ENGINE" = claude ]; then
  # A long working session: it keeps its transcript and the default prompt cache. Its shell calls may
  # run up to an hour, so a 55-minute wait.sh fits in one call.
  CLAUDE=$HOME/.npm-global/bin/claude; [ -x "$CLAUDE" ] || CLAUDE=$(command -v claude)
  # Codex reads AGENTS.md itself; Claude may load only CLAUDE.md, so name it.
  P="$P Read and follow every AGENTS.md from the repository root down to $WT."
  FASTLANE_CWD=$WT exec "$H/launch-unit.sh" "$UNIT" "$OUT" --stdout "$OUT/answer.md" -- \
    "$(command -v env)" -u CLAUDE_CODE_AUTO_COMPACT_WINDOW BASH_MAX_TIMEOUT_MS=3600000 \
    "$TIMEOUT" "$TO" "$CLAUDE" -p "$P" --model "${FASTLANE_IMPL_MODEL:-claude-opus-5-5}" --effort high \
    --dangerously-skip-permissions --strict-mcp-config --mcp-config '{"mcpServers":{}}'
fi
CODEX=$HOME/.npm-global/bin/codex; [ -x "$CODEX" ] || CODEX=$(command -v codex)
FASTLANE_CWD=$WT exec "$H/launch-unit.sh" "$UNIT" "$OUT" -- \
  "$TIMEOUT" "$TO" "$CODEX" exec --dangerously-bypass-approvals-and-sandbox \
  -m "${FASTLANE_IMPL_MODEL:-gpt-6.2-sol}" -c model_reasoning_effort=high \
  -c model_auto_compact_token_limit=250000 -o "$OUT/answer.md" "$P"
