#!/bin/sh
# session.sh PKT [NOTE_FILE]
#
# Start the packet's one combined session (it plans, implements, builds, reviews and judges), or
# resume it. The prompt tells it to stop early only for a named obstacle and to review only a
# complete candidate.
#
#   session.sh PKT             first turn: the session reads PKT/task.md
#   session.sh PKT NOTE_FILE   later turn: resume the same session; it reads NOTE_FILE
#   session.sh --wait DEADLINE TURN_DIR   wait.sh results, plus 4 for a codex content-filter stop
#
# PKT/config.json needs "name" and "worktree". Each turn gets PKT/turns/N/session (unit, engine, err,
# exit, answer.md, and out for codex); the unit is named cfl-NAME-sN. The first turn stamps
# PKT/meter-start, which the
# meter counts from, and records the worktree's HEAD in PKT/base. Inherited uncommitted work is kept,
# as in fastlane; save its resume copy before launching. A later turn always resumes the same session: its
# history comes back from cache, so nothing is read in twice.
# Engine: CFASTLANE_ENGINE, codex (the default) or claude, for quota balancing; anything else is
# refused. The first turn fixes it for the packet: a resume uses the first turn's engine and refuses
# a different CFASTLANE_ENGINE. Both engines record "session id: ID" in the turn's err.
# Model: CFASTLANE_MODEL (default gpt-6.2-sol, or claude-opus-5-5 for claude); effort is always high.
# Timeout: CFASTLANE_TIMEOUT seconds (default 21600).
# Caps, exit file and the disk floor come from fastlane's launch-unit.sh.
set -eu
usage() {
  printf 'usage: %s PKT [NOTE_FILE]\n       %s --wait DEADLINE TURN_DIR\n' "$0" "$0" >&2
  exit 2
}
H=$(cd "$(dirname "$0")" && pwd)
F=${CFASTLANE_FASTLANE_SCRIPTS:-$H/../../fastlane/scripts}
if [ "${1:-}" = --wait ]; then
  [ $# -eq 3 ] || usage
  rc=0
  "$F/wait.sh" "$2" "$3" || rc=$?
  # The filter line is codex's; a claude turn's refusal or limit stays an ordinary wait result.
  engine=codex; [ ! -s "$3/engine" ] || engine=$(cat "$3/engine")
  if [ "$rc" -eq 1 ] && [ "$engine" = codex ] && [ "$(cat "$3/exit")" = "exit-code exited 1" ] && [ -r "$3/err" ]; then
    # This is the CLI's terminal diagnostic. Ignore an earlier error superseded by another.
    last_error=$(sed -n '/^ERROR: /h; ${x;p;}' "$3/err") || exit "$rc"
    if [ "$last_error" = "ERROR: stream disconnected before completion: Incomplete response returned, reason: content_filter" ]; then
      printf 'CONTENT_FILTER %s\n' "$3"
      exit 4
    fi
  fi
  exit "$rc"
fi
[ $# -ge 1 ] && [ $# -le 2 ] || usage
ENGINE=${CFASTLANE_ENGINE:-}
case "$ENGINE" in ''|codex|claude) ;; *) echo "CFASTLANE_ENGINE must be codex or claude: $ENGINE" >&2; exit 2 ;; esac
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
  # A session resumes only on the engine that started it; packets older than the switch ran codex.
  FIRST=codex; [ ! -s "$PKT/turns/1/session/engine" ] || FIRST=$(cat "$PKT/turns/1/session/engine")
  case "$FIRST" in codex|claude) ;; *) echo "unknown engine in $PKT/turns/1/session/engine: $FIRST" >&2; exit 2 ;; esac
  [ -z "$ENGINE" ] || [ "$ENGINE" = "$FIRST" ] \
    || { echo "the session started on $FIRST and resumes only there: unset CFASTLANE_ENGINE or set it to $FIRST" >&2; exit 2; }
  ENGINE=$FIRST
fi
ENGINE=${ENGINE:-codex}
# Find the CLI before anything is recorded, so a missing one leaves no unfinished turn behind.
if [ "$ENGINE" = claude ]; then
  CLAUDE=$HOME/.npm-global/bin/claude; [ -x "$CLAUDE" ] || CLAUDE=$(command -v claude)
else
  CODEX=$HOME/.npm-global/bin/codex; [ -x "$CODEX" ] || CODEX=$(command -v codex)
fi
TIMEOUT=$(command -v timeout)
if [ "${FASTLANE_TESTS:-off}" = on ]; then
  TESTS="Tests are back: run, fix, edit or add tests only as the task file says. If tests-back is complete, HEAD is the last accepted candidate in $PKT/candidate (or $PKT/base before the first commit), and git status --porcelain --untracked-files=all --ignore-submodules=none succeeds with empty output, record the suite result and finish the handoff without a new review."
else
  TESTS="Other tests are suspended: do not run, fix, edit or add them. For standalone builds, compile only what the task says gets deployed."
fi
TESTS="Run every check the task names as required, in full, including its tests. That is never a reason to stop. $TESTS"
if [ $# -eq 1 ]; then
  [ "$N" -eq 1 ] || { echo "turn $N needs a NOTE_FILE: the session is resumed, never restarted" >&2; exit 2; }
  [ -s "$PKT/task.md" ] || { echo "no $PKT/task.md" >&2; exit 2; }
  git -C "$WT" rev-parse HEAD > "$PKT/base"
  date +%s > "$PKT/meter-start"
  P="Read the task file $PKT/task.md in full before doing anything, then do exactly what it says. Work only in $WT and under $PKT. Do not commit, push, deploy, change branches, stash, reset or write any issue tracker. $TESTS"
  set --
  if [ "$ENGINE" = claude ]; then
    ID=$("$PY" -I -c 'import uuid; print(uuid.uuid4())')
    set -- --session-id "$ID"
  fi
else
  [ "$N" -gt 1 ] || { echo "no earlier turn to resume: run $0 PKT first" >&2; exit 2; }
  NOTE=$2; case "$NOTE" in /*) ;; *) NOTE=$(pwd)/$NOTE ;; esac
  [ -s "$NOTE" ] || { echo "no note file $NOTE" >&2; exit 2; }
  ID=$(sed -n 's/^session id: *\([A-Za-z0-9-][A-Za-z0-9-]*\).*/\1/p' "$PKT"/turns/*/session/err | head -n 1)
  [ -n "$ID" ] || { echo "no session id in $PKT/turns/*/session/err" >&2; exit 3; }
  P="Read the note $NOTE and the current $PKT/task.md in full. Re-read any corrected packet files the note names, then continue under the same rules. $TESTS"
  if [ "$ENGINE" = claude ]; then set -- --resume "$ID"; else set -- resume "$ID"; fi
fi
P="$P Do all the work the task asks before you stop. End the turn early only for a named obstacle: evidence that a requirement cannot be met as written, one specific step with what you tried and why each attempt failed, a run or decision the task reserves for the assistant or the owner, or the turn's time limit. Work that merely remains is not an obstacle; keep going. On an early stop write the handoff as partial, naming the obstacle. Send contradictions within the packet brief, including task versus live-test instructions, to the assistant. Record preexisting gaps or defects in the handoff and continue. Before proposing a requirement change, run a baseline to determine whether the symptom predates the packet."
P="$P Review only a complete candidate. If completing tests-back with the no-change handoff above, skip these review steps. Before each review, put the current candidate's required check commands and exits in $PKT/handoff.md. Refresh checks a repair can affect before re-review. Once the candidate is complete, write the review brief from the fixed fastlane template without rewording reviewer instructions or P0-P3 lines. On the packet's first review launch run $H/review.sh $PKT (it probes grok). Wait on required seats with $F/wait.sh, judge every finding, repair eligible P0/P1 and re-review the delta. Do not launch models or agents except through that reviewer launcher."
P="$P Apply fastlane's round caps: three for product code, two for test tooling and two for tests-back. Count each separately committed stage from one, retaining the count across resumes in the stage. Start at one after a failed live test. At the cap, put every open finding in $PKT/followups.md for the assistant to commit the candidate and let the live test judge. Keep P0/P1 at their own priorities with the review-followup label. Findings touching money, data loss, machine deletion, secrets, broken core function or a check that can pass when it should fail still get a fix and another round. Write all follow-ups in the fixed entry format in $F/../references/prompts.md."
P="$P Never lower a reviewer's P0/P1 without the owner's decision. Also take a raised P0/P1 to the owner if you believe it should not or cannot be fixed within the task, except when deferring it at the cap. Do the required repairs under the cap rule. Before ending for an owner call, finish independent work, look ahead for other owner decisions and report all calls together with a recommendation and evidence for each."
P="$P Read $PKT/notes.md if present before each review round, before each repair and before writing the handoff. Finish by writing the handoff, final review and judgement paths, and commit message files the task names. Before ending, collect and judge every required reader you launched unless that wait would pass the turn's limit. If the turn still ends with reviewers active, report their units and exit paths so the same session can be resumed without launching duplicates."
P="$P Read $H/../SKILL.md for the review and wait rules, and read $F/../references/prompts.md for the exact fixed review template. After the packet's first review launch, run $H/review.sh $PKT --out <fresh-output> --tag <fresh-tag> [SEAT...] for each new launch, including a new stage's first round or a seat retry. Use a fresh output directory and tag. Never move active readers' directories. Wait on the required seat directories under the --out just launched, including grok only when that round launched it; read grok-missing from that same output. Never use an earlier round's exit files or wait on fable."
T=$PKT/turns/$N
mkdir -p "$T/session"  # the turn exists from here on, whatever the launch does
printf '%s\n' "$ENGINE" > "$T/session/engine"
TO=${CFASTLANE_TIMEOUT:-21600}
if [ "$ENGINE" = claude ]; then
  # A long working session: it keeps its transcript and the default prompt cache, and its shell calls
  # may run up to an hour, so a 55-minute wait.sh fits in one call. The wrapper writes the session id
  # to err, where codex prints its own, so the resume above and the meter read either engine.
  # Codex reads AGENTS.md itself; Claude may load only CLAUDE.md, so name it.
  P="$P Read and follow every AGENTS.md from the repository root down to $WT."
  FASTLANE_CWD=$WT "$F/launch-unit.sh" "cfl-$NAME-s$N" "$T/session" --stdout "$T/session/answer.md" -- \
    /bin/sh -c 'printf "session id: %s\n" "$0" >&2; exec "$@"' "$ID" \
    "$(command -v env)" -u CLAUDE_CODE_AUTO_COMPACT_WINDOW BASH_MAX_TIMEOUT_MS=3600000 \
    "$TIMEOUT" "$TO" "$CLAUDE" -p "$P" "$@" --model "${CFASTLANE_MODEL:-claude-opus-5-5}" --effort high \
    --dangerously-skip-permissions --strict-mcp-config --mcp-config '{"mcpServers":{}}'
else
  FASTLANE_CWD=$WT "$F/launch-unit.sh" "cfl-$NAME-s$N" "$T/session" -- \
    "$TIMEOUT" "$TO" "$CODEX" exec --color never "$@" --dangerously-bypass-approvals-and-sandbox \
    -m "${CFASTLANE_MODEL:-gpt-6.2-sol}" -c model_reasoning_effort=high \
    -c model_auto_compact_token_limit=250000 -o "$T/session/answer.md" "$P"
fi
echo "turn $N: wait with $H/session.sh --wait DEADLINE $T/session"
