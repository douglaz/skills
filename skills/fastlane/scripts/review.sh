#!/bin/sh
# review.sh WORKTREE BRIEF_FILE OUT_DIR TAG [SEAT...]
#
# Launch one read-only reader per seat, each as its own capped unit named fastlane-TAG-SEAT.
# Seats default to: opus astra sol grok (grok only when its one-word probe answers).
# To add optional fable name all five: opus astra sol grok fable (never wait on fable).
# Each OUT_DIR/SEAT gets unit, err, exit and answer.md.
# Models: FASTLANE_OPUS_MODEL (claude-opus-5-5), FASTLANE_FABLE_MODEL (claude-fable-5-2),
#         FASTLANE_ASTRA_MODEL (gpt-6-astra), FASTLANE_SOL_MODEL (gpt-6.1-sol). Effort high.
# Grok: grok-4.7, effort high, 8G; probe is bounded at 90 seconds. On probe failure,
# OUT_DIR/grok-missing records why; no grok reader starts and nothing waits on that seat.
# Readers can't run commands: put the diff in a file (make-diff.sh) and name it in the brief.
set -eu
[ $# -ge 4 ] || { echo "usage: $0 WORKTREE BRIEF_FILE OUT_DIR TAG [SEAT...]" >&2; exit 2; }
WT=$1 BRIEF=$2 OUT=$3 TAG=$4; shift 4
[ $# -gt 0 ] || set -- opus astra sol grok
H=$(cd "$(dirname "$0")" && pwd)
[ -d "$WT" ] || { echo "no worktree $WT" >&2; exit 2; }
[ -s "$BRIEF" ] || { echo "no review brief $BRIEF" >&2; exit 2; }
case "$BRIEF" in /*) ;; *) BRIEF=$(pwd)/$BRIEF ;; esac
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
CODEX=$HOME/.npm-global/bin/codex; [ -x "$CODEX" ] || CODEX=$(command -v codex)
CLAUDE=$HOME/.npm-global/bin/claude; [ -x "$CLAUDE" ] || CLAUDE=$(command -v claude)
TIMEOUT=$(command -v timeout) ENV=$(command -v env)
P="You are a code reviewer in a fast lane. Read the review brief $BRIEF in full first and follow it. You are read-only: never edit files, commit, check out, stash, reset or clean, and never run builds or tests (tests are suspended until the live test passes). Do not read credential files or the model config folders ~/.claude, ~/.codex, ~/.grok."
for s in "$@"; do
  D=$OUT/$s U=fastlane-$TAG-$s
  case $s in
    opus|fable)
      if [ "$s" = opus ]; then M=${FASTLANE_OPUS_MODEL:-claude-opus-5-5}; else M=${FASTLANE_FABLE_MODEL:-claude-fable-5-2}; fi
      FASTLANE_CWD=$WT "$H/launch-unit.sh" "$U" "$D" --stdout "$D/answer.md" -- \
        "$ENV" -u CLAUDE_CODE_AUTO_COMPACT_WINDOW CLAUDE_CODE_PROMPT_CACHE_TTL=5m \
        "$TIMEOUT" 5400 "$CLAUDE" -p "$P" --model "$M" --effort high \
        --dangerously-skip-permissions --tools Read,Grep,Glob \
        --safe-mode --strict-mcp-config --mcp-config '{"mcpServers":{}}' ;;
    astra|sol)
      if [ "$s" = astra ]; then M=${FASTLANE_ASTRA_MODEL:-gpt-6-astra}; else M=${FASTLANE_SOL_MODEL:-gpt-6.1-sol}; fi
      FASTLANE_CWD=$WT "$H/launch-unit.sh" "$U" "$D" -- \
        "$TIMEOUT" 5400 "$CODEX" exec --skip-git-repo-check --sandbox read-only \
        -m "$M" -c model_reasoning_effort=high -o "$D/answer.md" "$P" ;;
    grok)
      GROK=$(command -v grok) || GROK=
      if [ -z "$GROK" ]; then
        echo "grok missing: executable unavailable" | tee "$OUT/grok-missing"
        continue
      fi
      PROBE=$OUT/grok-probe
      FASTLANE_MEM=8G FASTLANE_CWD=$WT "$H/launch-unit.sh" "$U-probe" "$PROBE" --stdout "$PROBE/answer.md" -- \
        "$TIMEOUT" 90 "$GROK" --no-auto-update -p "Reply with exactly one word: GROK_OK" \
        --model grok-4.7 --effort high --output-format plain --always-approve --sandbox off \
        --no-subagents --no-memory --disable-web-search \
        --disallowed-tools "search_replace,write,search_tool,use_tool" --tools "read_file,grep,list_dir"
      if "$H/wait.sh" 120 "$PROBE" && grep -qx 'GROK_OK' "$PROBE/answer.md"; then
        FASTLANE_MEM=8G FASTLANE_CWD=$WT "$H/launch-unit.sh" "$U" "$D" --stdout "$D/answer.md" -- \
          "$TIMEOUT" 5400 "$GROK" --no-auto-update -p "$P" \
          --model grok-4.7 --effort high --output-format plain --always-approve --sandbox off \
          --no-subagents --no-memory --disable-web-search \
          --disallowed-tools "search_replace,write,search_tool,use_tool" --tools "read_file,grep,list_dir"
      else
        echo "grok missing: one-word probe did not answer; see $PROBE" | tee "$OUT/grok-missing"
      fi ;;
    *) echo "unknown seat $s (opus, astra, sol, grok, fable)" >&2; exit 2 ;;
  esac
done
