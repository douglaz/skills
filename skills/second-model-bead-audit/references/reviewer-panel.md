# Bead Audit Reviewer Panel

Exact setup, prompt, invocations, and failure handling for the default read-only
Codex + Claude bead-audit panel. Load this before starting an audit.

## Why a panel

The graph may have been built by Codex, Claude, both, or an unknown agent. Running
both reviewers removes authorship detection from reviewer selection and guarantees
a cross-model read whenever the full panel is healthy. Shared findings raise
confidence; disagreements identify assumptions the orchestrator must verify.

Both reviewers receive the same custom prompt and inspect the same plan and graph
snapshot. Unlike `multi-reviewer-loop`, this panel uses `codex exec`, not
`codex review`, because the audit target is a plan and bead graph rather than a Git
diff.

## Audit directory

Before running any block, set `PLAN_PATH` to the absolute authoritative plan/spec
path and `AUDIT_SCOPE` to the plan-backed root beads/epics plus their
child/dependency closure.

```bash
set -euo pipefail

: "${PLAN_PATH:?Set PLAN_PATH to an absolute plan/spec path}"
: "${AUDIT_SCOPE:?Set AUDIT_SCOPE before capture}"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
_PROJECT=$(basename "$REPO_ROOT")
AUDIT_DIR=$(mktemp -d "/tmp/bead-audit-${_PROJECT}.XXXXXXXX")

AUDIT_PROMPT_FILE="$AUDIT_DIR/audit-prompt.txt"
CODEX_OUT="$AUDIT_DIR/codex.txt"
CODEX_TRACE="$AUDIT_DIR/codex.trace.txt"
CODEX_ERR="$AUDIT_DIR/codex.stderr.txt"
CLAUDE_RAW="$AUDIT_DIR/claude.raw.json"
CLAUDE_OUT="$AUDIT_DIR/claude.txt"
CLAUDE_ERR="$AUDIT_DIR/claude.stderr.txt"
MERGED_OUT="$AUDIT_DIR/merged.md"
GRAPH_JSON="$AUDIT_DIR/graph.json"
GRAPH_JSONL="$AUDIT_DIR/issues.jsonl"
GRAPH_AFTER_JSONL="$AUDIT_DIR/issues.after.jsonl"
TRIAGE_OUT="$AUDIT_DIR/triage.txt"
PLAN_OUT="$AUDIT_DIR/plan.txt"
SUGGEST_OUT="$AUDIT_DIR/suggest.txt"
GRAPH_DEPS_JSON="$AUDIT_DIR/graph-dependencies.json"
ISSUE_DIR="$AUDIT_DIR/issues"
SOURCE_DIR="$AUDIT_DIR/sources"
SOURCE_MANIFEST="$AUDIT_DIR/source-manifest.txt"
SOURCE_STATE_BEFORE="$AUDIT_DIR/source-state.before.txt"
SOURCE_STATE_AFTER="$AUDIT_DIR/source-state.after.txt"
mkdir -p "$ISSUE_DIR" "$SOURCE_DIR"
```

Use a unique directory so retries never overwrite the evidence from a failed or
ambiguous run.

Run every shell block in this reference in the same Bash process. The initial
`set -euo pipefail` is part of the safety contract: snapshot capture must stop on
any failed `br`, `bv`, `jq`, copy, or fingerprint command.

## Shared graph snapshot

Flush before capture, prohibit graph mutations while the panel runs, and give both
reviewers the same baseline files. First define `SOURCE_FILES` as a Bash array
containing the authoritative plan/spec, `README.md`, `AGENTS.md` when present,
approved deltas/waivers, and every linked document needed to interpret the plan.
The panel must not discover requirement sources live.

```bash
fingerprint_file() {
  local raw
  if command -v sha256sum >/dev/null 2>&1; then
    raw=$(sha256sum "$1") || return
    printf '%s\n' "${raw%% *}"
  elif command -v shasum >/dev/null 2>&1; then
    raw=$(shasum -a 256 "$1") || return
    printf '%s\n' "${raw%% *}"
  else
    echo "SHA-256 unavailable: install sha256sum or shasum" >&2
    return 1
  fi
}

# Add every authoritative/linked requirement file before capture, without
# duplicates. Use add_source for approved deltas, waivers, and linked docs.
SOURCE_FILES=()
add_source() {
  local candidate=$1 existing
  for existing in "${SOURCE_FILES[@]}"; do
    [ "$existing" != "$candidate" ] || return 0
  done
  SOURCE_FILES+=("$candidate")
}
add_source "$PLAN_PATH"
[ ! -f "$REPO_ROOT/README.md" ] || add_source "$REPO_ROOT/README.md"
# Extend before AGENTS discovery, for example:
# add_source "$REPO_ROOT/docs/APPROVED-DELTA.md"
# add_source "$REPO_ROOT/docs/ROLLOUT.md"

# Include every AGENTS.md that governs a source: the file's directory, each
# ancestor directory, and the repository root.
governed_sources=("${SOURCE_FILES[@]}")
for governed in "${governed_sources[@]}"; do
  dir=$(dirname "$governed")
  while [ "$dir" = "$REPO_ROOT" ] || [[ "$dir" == "$REPO_ROOT/"* ]]; do
    [ ! -f "$dir/AGENTS.md" ] || add_source "$dir/AGENTS.md"
    [ "$dir" != "$REPO_ROOT" ] || break
    dir=$(dirname "$dir")
  done
done

: >"$SOURCE_MANIFEST"
: >"$SOURCE_STATE_BEFORE"
source_n=0
for src in "${SOURCE_FILES[@]}"; do
  [ -f "$src" ] || {
    echo "Missing audit source: $src" >&2
    exit 1
  }
  source_n=$((source_n + 1))
  copy="$SOURCE_DIR/$(printf '%03d' "$source_n")-$(basename "$src")"
  cp "$src" "$copy"
  copy_fp=$(fingerprint_file "$copy") || {
    echo "Could not fingerprint source snapshot: $copy" >&2
    exit 1
  }
  live_fp=$(fingerprint_file "$src") || {
    echo "Could not fingerprint source: $src" >&2
    exit 1
  }
  [ -n "$copy_fp" ] && [ "$copy_fp" = "$live_fp" ] || {
    echo "Audit source changed while being snapshotted: $src" >&2
    exit 1
  }
  printf '%s\t%s\n' "$src" "$copy" >>"$SOURCE_MANIFEST"
  printf '%s\t%s\n' "$live_fp" "$src" >>"$SOURCE_STATE_BEFORE"
done

# RESOLVE AND INSPECT BEFORE FLUSHING. The flush writes the cache over the tracked file,
# so an unstaged hand-edit is destroyed HERE — and the diff below then compares the file
# against an index that already matches it, comes back empty, and the audit snapshots the
# truncated graph having "checked". The check has to precede the write it guards.
_bw=$(br where --json) || { echo "cannot resolve the beads JSONL path" >&2; exit 1; }
BEADS_JSONL=$(printf '%s' "$_bw" | jq -er .jsonl_path) || { echo "cannot resolve the beads JSONL path" >&2; exit 1; }
# INSPECT before flushing — the next line writes the cache over this file, so anything in
# the worktree that the cache does not know about is gone afterwards, with no diff left to
# show it. Do NOT gate on a clean file: the normal `bead-polish-loop` handoff arrives with
# the round's intended `br` edits uncommitted, so demanding cleanliness would block the
# audit after every non-noop round.
#
# The question is not "is it dirty" but "is any of this dirt something the cache will
# destroy" — i.e. hand-edited bead text, which never advances `updated_at`. Read the diff
# and continue only once you can say which it is.
# Against HEAD, not the index: a damaged JSONL that is STAGED makes a worktree-vs-index
# diff empty while HEAD still holds the good bodies, so the operator would acknowledge a
# clean-looking diff and flush the damage.
git status --porcelain -- "$BEADS_JSONL" || { echo "cannot read the worktree — do NOT flush" >&2; exit 1; }
git diff HEAD -- "$BEADS_JSONL"          || { echo "cannot diff the JSONL — do NOT flush" >&2; exit 1; }
# Keep a copy of what the worktree held BEFORE the flush. Neither git ref works as the
# post-flush baseline: if the index holds an earlier damaged export and the worktree holds
# the good recovery, HEAD-vs-worktree looks fine beforehand, the flush replaces the good
# copy with the indexed damage, and a worktree-vs-index diff afterwards is EMPTY because
# both now hold it. Only the pre-flush bytes can show that.
cp "$BEADS_JSONL" "$AUDIT_DIR/preflush.jsonl" || { echo "cannot preserve the pre-flush graph" >&2; exit 1; }
: "${BEADS_DIFF_REVIEWED:?read the two commands above, then set this to how you resolved it}"
br sync --flush-only || { echo "flush failed — do not audit an unwritten graph" >&2; exit 1; }

# STOP HERE AND READ THIS DIFF before snapshotting. The flush just re-exported EVERY bead
# from the gitignored cache over the tracked JSONL, so any body the cache held a stale copy
# of was silently reverted — exit 0, no warning. Snapshot now and the panel audits the
# truncated graph, which is the one failure an audit cannot catch by reading: the text it
# would have objected to is already gone. Field-diff it, key the +/- lines by `id`, and
# assert only the fields you meant to change moved. Ids on one side only, or a
# `description` this session did not write, is the tell. Recovery:
# exact companion skill rb-lite-backlog-drain, step 11:
# ../../rb-lite-backlog-drain/SKILL.md#backlog-step-11.
git diff -- "$BEADS_JSONL"
```

**Stop the block here.** The line above is a real gate, not a comment: run the snapshot
block only up to this point, read the diff, and continue *in a second invocation* once you
have. A comment does not pause a shell — pasted as one block, the diff scrolls past and the
copy below snapshots whatever the flush produced, which is the entire failure this check
exists to catch. If you must automate it, make the continuation conditional on an explicit
recorded acknowledgement rather than on the diff having been printed.

```bash
# Compare against the PRE-FLUSH bytes, not against the index. This is the only baseline
# that can show a flush replacing a good worktree copy with an indexed damaged one.
diff -u "$AUDIT_DIR/preflush.jsonl" "$BEADS_JSONL" \
  || : "${BEADS_POSTFLUSH_REVIEWED:?the flush changed the graph — read that diff, then set this}"
cp "$BEADS_JSONL" "$GRAPH_JSONL"
GRAPH_FINGERPRINT=$(fingerprint_file "$GRAPH_JSONL") || {
  echo "Could not fingerprint initial graph snapshot" >&2
  exit 1
}
[ -n "$GRAPH_FINGERPRINT" ] || {
  echo "Initial graph fingerprint is empty" >&2
  exit 1
}

br list --limit 0 --json -a >"$GRAPH_JSON"
bv --robot-triage >"$TRIAGE_OUT"
bv --robot-plan >"$PLAN_OUT"
bv --robot-suggest >"$SUGGEST_OUT"
br graph --all --json >"$GRAPH_DEPS_JSON"

if ISSUE_IDS=$(jq -er '(.issues // .)[] | .id' <"$GRAPH_JSON"); then
  :
else
  echo "Could not extract issue IDs from graph snapshot" >&2
  exit 1
fi

while IFS= read -r id; do
  safe_id=$(printf '%s' "$id" | tr -c 'A-Za-z0-9._-' '_')
  br show "$id" --json >"$ISSUE_DIR/$safe_id.json"
done <<<"$ISSUE_IDS"

br sync --flush-only
CAPTURE_AFTER_JSONL="$AUDIT_DIR/issues.capture-after.jsonl"
cp "$BEADS_JSONL" "$CAPTURE_AFTER_JSONL"
CAPTURE_AFTER_FINGERPRINT=$(fingerprint_file "$CAPTURE_AFTER_JSONL") || {
  echo "Could not fingerprint graph after capture" >&2
  exit 1
}
[ -n "$CAPTURE_AFTER_FINGERPRINT" ] || {
  echo "Post-capture graph fingerprint is empty" >&2
  exit 1
}
[ "$GRAPH_FINGERPRINT" = "$CAPTURE_AFTER_FINGERPRINT" ] || {
  echo "Graph changed while audit artifacts were being captured" >&2
  exit 1
}
```

Set `AUDIT_SCOPE` to the plan-backed root bead IDs/epics and their child/dependency
closure. The full graph remains available for cross-scope dependency and frontier
checks, but unrelated backlog is not a coverage defect.

## Shared prompt

Build the prompt in a file so both reviewers get byte-for-byte identical
instructions and shell quoting cannot truncate the rubric.

```bash
{
  printf 'Audit the bead graph in repository: %s\n' "$REPO_ROOT"
  printf 'Source snapshot manifest: %s\n' "$SOURCE_MANIFEST"
  printf 'Source snapshot directory: %s\n\n' "$SOURCE_DIR"
  printf 'Audit scope: %s\n' "$AUDIT_SCOPE"
  printf 'Graph fingerprint: %s\n' "$GRAPH_FINGERPRINT"
  printf 'Shared graph JSON: %s\n' "$GRAPH_JSON"
  printf 'Authoritative issues JSONL: %s\n' "$GRAPH_JSONL"
  printf 'Shared triage output: %s\n' "$TRIAGE_OUT"
  printf 'Shared plan output: %s\n' "$PLAN_OUT"
  printf 'Shared suggest output: %s\n' "$SUGGEST_OUT"
  printf 'Shared dependency graph: %s\n' "$GRAPH_DEPS_JSON"
  printf 'Per-issue JSON directory: %s\n\n' "$ISSUE_DIR"
  cat <<'EOF'
This is the final read-only launch-readiness gate after bead polishing. Independently
derive your judgment from the plan and graph. Do not trust or search for another
reviewer's conclusions.

First read the snapshotted AGENTS.md, README.md, source plan/spec, approved
deltas/waivers, and linked docs listed in the source manifest. Treat those copies,
not live repo versions, as authoritative.
Use only the shared snapshot, dependency graph, and per-issue JSON files as the
authoritative graph baseline. Do not run br or bv commands. Do not modify, create,
or delete files.

Audit both directions (plan -> beads and beads -> plan) and check:
- missing plan workflows, constraints, failure/recovery paths, rollout, docs, or
  operator obligations
- duplicate or overlapping ownership and in-scope beads with no plan backing
- vague, overloaded, undersized, or non-self-contained beads
- dependency direction, missing edges, cycles, bottlenecks, and ready-frontier health
- priority and sequencing
- concrete unit, integration/e2e, acceptance, regression, logging, diagnostics,
  observability, migration, and recovery obligations where relevant

Do not invent requirements or recommend speculative hardening. Every finding must
cite affected bead IDs and the supporting plan section (or explain that the bead
has no plan backing). Verify graph claims from the shared files before asserting
them.

Output contract:
1. First line: VERDICT: FAIL | CONDITIONAL PASS | PASS
2. One-sentence rationale.
3. Findings, one per item, beginning with exactly one of:
     [BLOCKER] <claim>
     [IMPORTANT] <claim>
     [NIT] <claim>
   Under each item include:
     Evidence: <plan section + bead IDs>
     Why: <concrete execution or launch risk>
     Fix: <exact bead-level remedy; br command only when safe>
4. End with all three exact headings:
     COVERAGE: <short notes>
     DEPENDENCIES: <short notes>
     VERIFICATION: <short notes>

FAIL means at least one blocker. CONDITIONAL PASS means no blocker but named
important conditions remain. PASS means no blocker or important condition remains.
If there are no findings, after the rationale output exactly: No findings.
EOF
} >"$AUDIT_PROMPT_FILE"
```

Do not append the polishing ledger, the orchestrator's assessment, or one
reviewer's findings. Independence is lost if the prompt tells auditors what to
find.

## Run both reviewers in parallel

Set `PANEL_REVIEWERS` from the parsed `--reviewers` value. The default is
`codex,claude`; a pinned run starts only the requested block.

Three steps, **in this order** — normalize, then probe, then dispatch. The order is the
point: the probe reads the ladder, so a pin parsed *after* it has already been ignored.

One thing has to happen before all three: **validate GNU `timeout`**, using step 3's
check (`timeout --kill-after=1s 1s true`) rather than a bare `command -v`, which cannot
tell GNU's `timeout` from busybox's. Ordering that check first is necessary but not
sufficient — the probe selects its own binary, so it must validate too, which is why
§ Resolving now tries each candidate rather than taking `timeout` whenever it exists.
Without both, a host with busybox `timeout` ahead of GNU `gtimeout` fails every rung's
`--kill-after=15 90` invocation, the ladder concludes no candidate answered, and a
`--reviewers claude` run dies reporting "the only requested reviewer had no reachable
model" — a false diagnosis for a dependency problem this file can name precisely.

### 1. Normalize a model-name pin to its slot

`--reviewers fable` and `--reviewers opus` are documented as valid, and the case
statement below accepts only slot names — so without this step a documented invocation
exits 2 having started no auditor at all. A model pin fills the `claude` slot *and*
pins the ladder to that one model:

```bash
# The default belongs HERE, not at dispatch: normalization reads $PANEL_REVIEWERS, and
# under this file's `set -u` an unset one aborts before the probe with no auditor
# started — i.e. it would break the DEFAULT audit while the pinned case it was written
# for passed.
PANEL_REVIEWERS=${PANEL_REVIEWERS:-codex,claude}
# Map any model name in the list onto the claude slot, remembering the pin.
CLAUDE_MODEL_PIN=""
_norm=""
IFS=',' read -ra _rv <<<"$PANEL_REVIEWERS"
for _r in "${_rv[@]}"; do
  case "$_r" in
    codex|claude)      _norm="${_norm:+$_norm,}$_r" ;;
    "")                ;;
    # Known model names only. A bare `*)` catch-all turns a TYPO into a pin: `codx`
    # becomes a claude-slot pin on a nonexistent model, silently dropping the codex
    # auditor and leaving a one-reviewer panel that then fails its own pin. Before
    # this normalizer existed, the same typo exited 2 naming the bad token, which is
    # strictly more useful. These are exactly the ladder's rungs — keep it that way, so
    # a reader can tell rungs from extras — and extend this list, `multi-reviewer-loop`
    # § Inputs, and SKILL.md's documented values together when the ladder grows.
    fable|opus)   CLAUDE_MODEL_PIN="$_r"; _norm="${_norm:+$_norm,}claude" ;;
    *) echo "Unknown reviewer or model: $_r" >&2; exit 2 ;;
  esac
done
PANEL_REVIEWERS="$_norm"
# A pin REPLACES the ladder; an unreachable pinned model fails the slot rather than
# substituting, because the user named that model specifically. `if` rather than
# `[ ... ] && ...`: the latter returns 1 on the no-pin path, which is harmless mid-script
# — bash exempts the left operand of `&&` from errexit — but lethal as a function's last
# statement, the shape #37 already cost this repo once. Written as `if` so its safety
# does not depend on where the line happens to sit.
if [ -n "$CLAUDE_MODEL_PIN" ]; then export CLAUDE_REVIEWER_MODELS="$CLAUDE_MODEL_PIN"; fi
```

### 2. Resolve `$CLAUDE_MODEL`

**Only when the normalized panel contains `claude`.** A `--reviewers codex` audit must
not pay for a probe of a reviewer it excluded — up to 90 seconds per unreachable rung,
and a real model call.

Run the bounded probe in
[multi-reviewer-loop/references/reviewer-panel.md](../../multi-reviewer-loop/references/reviewer-panel.md)
§ Resolving the Claude reviewer's model — same ladder, same acceptance rule, reading the
`CLAUDE_REVIEWER_MODELS` just set. An unreachable model hangs rather than erroring, so
without the probe the 900s `timeout` is the first thing that notices, and it reports the
auditor as `failed` after fifteen minutes rather than as `substituted` after one.

If no candidate answers, **drop `claude` from `PANEL_REVIEWERS`** and record why —
rebuilding the list rather than deleting a token, since `codex,claude` minus a token
leaves `codex,`, which the dispatch `case` rejects as an invalid panel with the real
reason lost:

```bash
_keep=""
for _r in ${PANEL_REVIEWERS//,/ }; do
  if [ "$_r" = claude ]; then continue; fi
  _keep="${_keep:+$_keep,}$_r"
done
PANEL_REVIEWERS="$_keep"
```

That is all: `RUN_CLAUDE` then derives to `false` in step 3, and every existing guard — the
launch, the `wait`, the unwrap, the `CLAUDE_STATE` table, the `DEGRADED` verdict — is
already written for a reviewer that was not requested. Do not add a second flag beside
`RUN_CLAUDE` for it; an earlier draft did, and each of the three review rounds that
followed found an unbound variable or an uninitialised state on the new path.

Dropping the **only** reviewer leaves `PANEL_REVIEWERS` empty, which the dispatch `case`
below matches with `*)` and rejects as an invalid panel — exiting 2 during argument
validation, with the real reason (an exhausted ladder) lost. Catch it here instead:

```bash
if [ -z "$PANEL_REVIEWERS" ]; then
  echo "audit BLOCKED: the only requested reviewer had no reachable model" >&2
  # BLOCKED with no launch verdict, per the recovery table — not an argument error,
  # and never a silent substitution of the reviewer the user did not ask for.
  exit 1
fi
```

### 3. Dispatch

```bash
# $PANEL_REVIEWERS was defaulted and normalized in step 1 — do not re-default it here.
if command -v timeout >/dev/null 2>&1 &&
   timeout --kill-after=1s 1s true >/dev/null 2>&1; then
  TIMEOUT_BIN=$(command -v timeout)
elif command -v gtimeout >/dev/null 2>&1 &&
     gtimeout --kill-after=1s 1s true >/dev/null 2>&1; then
  TIMEOUT_BIN=$(command -v gtimeout)
else
  echo "GNU timeout is required (timeout or gtimeout)" >&2
  exit 1
fi

RUN_CODEX=false
RUN_CLAUDE=false
case "$PANEL_REVIEWERS" in
  codex)        RUN_CODEX=true ;;
  claude)       RUN_CLAUDE=true ;;
  codex,claude) RUN_CODEX=true; RUN_CLAUDE=true ;;
  *) echo "Invalid reviewer panel: $PANEL_REVIEWERS" >&2; exit 2 ;;
esac

if $RUN_CODEX; then
  "$TIMEOUT_BIN" --kill-after=30s 900s codex exec \
    -C "$REPO_ROOT" \
    --sandbox read-only \
    --ephemeral \
    --ignore-user-config \
    -c 'mcp_servers={}' \
    -m gpt-5.6-sol \
    -c 'model_reasoning_effort="xhigh"' \
    --output-last-message "$CODEX_OUT" \
    "$(cat "$AUDIT_PROMPT_FILE")" \
    </dev/null >"$CODEX_TRACE" 2>"$CODEX_ERR" &
  CODEX_PID=$!
fi

if $RUN_CLAUDE; then
  (
    cd "$REPO_ROOT"
    "$TIMEOUT_BIN" --kill-after=30s 900s claude -p "$(cat "$AUDIT_PROMPT_FILE")" \
      --model "$CLAUDE_MODEL" \
      --effort high \
      --output-format json \
      --no-session-persistence \
      --safe-mode \
      --strict-mcp-config \
      --mcp-config '{"mcpServers":{}}' \
      --add-dir "$AUDIT_DIR" \
      --tools "Read,Glob,Grep" \
      --allowedTools "Read,Glob,Grep" \
      --disallowedTools "Edit,Write,NotebookEdit" \
      </dev/null
  ) >"$CLAUDE_RAW" 2>"$CLAUDE_ERR" &
  CLAUDE_PID=$!
fi

if $RUN_CODEX; then
  if wait "$CODEX_PID"; then CODEX_RC=0; else CODEX_RC=$?; fi
fi
if $RUN_CLAUDE; then
  if wait "$CLAUDE_PID"; then CLAUDE_RC=0; else CLAUDE_RC=$?; fi
fi
```

Close stdin even though each command receives a prompt argument. These are
non-interactive batch commands; an unexpected stdin read must get EOF rather than
hang the audit.

GNU `timeout` is mandatory so a hung reviewer cannot block the panel indefinitely.
The snippet accepts GNU's usual `timeout` name or Homebrew coreutils' `gtimeout`.
Exit 124 is a failed reviewer, never a clean one.

The `if wait` form is deliberate: under `set -e`, a plain failing `wait` would
abort before the other reviewer's status is collected.

The Codex sandbox enforces read-only filesystem access; `--ignore-user-config`
plus the empty `mcp_servers` override prevents configured MCP tools from bypassing
it. The Claude auditor's safe/strict empty-MCP configuration and built-in tool allowlist expose
only file inspection tools. `--add-dir "$AUDIT_DIR"` makes the snapshots readable
when Claude restricts file access to declared working directories; the absence of
write-capable tools keeps that added directory read-only in practice. The
coordinator pre-captures every `br`/`bv` output the reviewers need. Do not add
`Bash`, remove the MCP isolation flags, or use `--permission-mode acceptEdits`.

## Unwrap and validate the Claude auditor

Run this only when the Claude auditor was requested — i.e. `$RUN_CLAUDE`, which an
exhausted ladder has already turned off. It is also the only place `JQ_RC` and
`CLAUDE_INSPECTION_BLOCKED` are initialised; the state table below reads them, but every
read there sits behind `$RUN_CLAUDE`, and `false && [ "$JQ_RC" -eq 0 ]` short-circuits
before the expansion — so skipping this block on that path is safe under `set -u`.
Keep both facts true together: any future read of these variables that is *not* behind
`$RUN_CLAUDE` needs them initialised here or it aborts.

```bash
if jq -er 'if .is_error then error(.result // "claude auditor returned is_error")
           else (.result // empty) end' <"$CLAUDE_RAW" >"$CLAUDE_OUT"; then
  JQ_RC=0
else
  JQ_RC=$?
fi
```

If unwrapping succeeded, inspect denied tool names and carry inspection denials
into reviewer state:

```bash
CLAUDE_DENIALS=
CLAUDE_INSPECTION_BLOCKED=false
if [ "$JQ_RC" -eq 0 ]; then
  if CLAUDE_DENIALS=$(jq -r '.permission_denials[]?.tool_name' <"$CLAUDE_RAW"); then
    if printf '%s\n' "$CLAUDE_DENIALS" |
       grep -qE '^(Read|Glob|Grep)$'; then
      CLAUDE_INSPECTION_BLOCKED=true
    fi
  else
    JQ_RC=$?
  fi
fi
printf '%s\n' "$CLAUDE_DENIALS"
```

- Denied `Edit`, `Write`, or `NotebookEdit`: the read-only guard worked; note it,
  but do not degrade the audit.
- Denied `Read`, `Glob`, or `Grep`: the reviewer could not inspect what it
  needed. Treat that reviewer as failed; the surviving one can only produce a
  degraded panel result.

Optionally confirm the actual model:

```bash
if [ "$JQ_RC" -eq 0 ]; then
  jq -r '.modelUsage | keys[]' <"$CLAUDE_RAW" || true
fi
```

## Healthy, findings, ambiguous, failed

A reviewer is:

- **Clean**: exit 0, non-empty output, a valid `VERDICT: PASS`, no finding tags,
  and an explicit `No findings.` line.
- **Findings present**: exit 0, non-empty output, one or more `[BLOCKER]`,
  `[IMPORTANT]`, or `[NIT]` lines, all required closing headings, and a verdict
  consistent with the highest finding severity.
- **Ambiguous**: exit 0 but missing a valid verdict, or zero findings without the
  explicit clean signal, or any verdict/severity/section contradiction. Rerun
  once; do not count it as clean.
- **Failed**: non-zero exit, timeout, Claude `is_error: true`, failed `jq`, empty
  output, or denied inspection tools.

Validate the complete contract, not only whether tags exist:

```bash
validate_audit_output() {
  local file=$1 verdict rationale blockers important nits total closing
  [ -s "$file" ] || return 1
  verdict=$(sed -n '1s/^VERDICT: //p' "$file")
  rationale=$(sed -n '2p' "$file")
  [ -n "$rationale" ] || return 1
  if printf '%s\n' "$rationale" |
     grep -qE '^(\[(BLOCKER|IMPORTANT|NIT)\]|No findings\.|COVERAGE:|DEPENDENCIES:|VERIFICATION:)'; then
    return 1
  fi
  blockers=$(grep -cE '^[[:space:]]*\[BLOCKER\]' "$file" || true)
  important=$(grep -cE '^[[:space:]]*\[IMPORTANT\]' "$file" || true)
  nits=$(grep -cE '^[[:space:]]*\[NIT\]' "$file" || true)
  total=$((blockers + important + nits))

  closing=$(tail -n 3 "$file")
  printf '%s\n' "$closing" | sed -n '1p' | grep -q '^COVERAGE:' || return 1
  printf '%s\n' "$closing" | sed -n '2p' | grep -q '^DEPENDENCIES:' || return 1
  printf '%s\n' "$closing" | sed -n '3p' | grep -q '^VERIFICATION:' || return 1

  # Every finding must carry all three support fields before the next finding.
  awk '
    function finish() {
      if (in_item && !(have_evidence && have_why && have_fix)) exit 1
    }
    /^[[:space:]]*\[(BLOCKER|IMPORTANT|NIT)\]/ {
      finish()
      in_item=1
      have_evidence=have_why=have_fix=0
      next
    }
    in_item && /^[[:space:]]+Evidence:[[:space:]]*[^[:space:]]/ { have_evidence=1 }
    in_item && /^[[:space:]]+Why:[[:space:]]*[^[:space:]]/ { have_why=1 }
    in_item && /^[[:space:]]+Fix:[[:space:]]*[^[:space:]]/ { have_fix=1 }
    END { finish() }
  ' "$file" || return 1

  if [ "$blockers" -gt 0 ]; then
    [ "$verdict" = FAIL ] || return 1
  elif [ "$important" -gt 0 ]; then
    [ "$verdict" = "CONDITIONAL PASS" ] || return 1
  else
    [ "$verdict" = PASS ] || return 1
  fi

  if [ "$total" -eq 0 ]; then
    grep -qx 'No findings\.' "$file" || return 1
  else
    ! grep -qx 'No findings\.' "$file" || return 1
  fi
}

if $RUN_CODEX && [ "$CODEX_RC" -eq 0 ]; then
  if validate_audit_output "$CODEX_OUT"; then
    CODEX_STATE=usable
  else
    CODEX_STATE=ambiguous
  fi
elif $RUN_CODEX; then
  CODEX_STATE=failed
fi
if $RUN_CLAUDE && [ "$CLAUDE_RC" -eq 0 ] && [ "$JQ_RC" -eq 0 ] &&
   ! $CLAUDE_INSPECTION_BLOCKED; then
  if validate_audit_output "$CLAUDE_OUT"; then
    CLAUDE_STATE=usable
  else
    CLAUDE_STATE=ambiguous
  fi
elif $RUN_CLAUDE && $CLAUDE_INSPECTION_BLOCKED; then
  CLAUDE_STATE=failed
elif $RUN_CLAUDE; then
  CLAUDE_STATE=failed
fi
```

## Detect graph drift

After both reviewers finish:

```bash
PANEL_INVALID=false

br sync --flush-only
cp "$BEADS_JSONL" "$GRAPH_AFTER_JSONL"
GRAPH_AFTER_FINGERPRINT=$(fingerprint_file "$GRAPH_AFTER_JSONL") || {
  echo "Could not fingerprint graph after audit" >&2
  exit 1
}
[ -n "$GRAPH_AFTER_FINGERPRINT" ] || {
  echo "Post-audit graph fingerprint is empty" >&2
  exit 1
}
if [ "$GRAPH_FINGERPRINT" != "$GRAPH_AFTER_FINGERPRINT" ]; then
  printf 'Graph changed during audit: before=%s after=%s\n' \
    "$GRAPH_FINGERPRINT" "$GRAPH_AFTER_FINGERPRINT" >&2
  PANEL_INVALID=true
fi

: >"$SOURCE_STATE_AFTER"
for src in "${SOURCE_FILES[@]}"; do
  [ -f "$src" ] || {
    echo "Audit source disappeared during panel: $src" >&2
    PANEL_INVALID=true
    continue
  }
  if source_fp=$(fingerprint_file "$src") && [ -n "$source_fp" ]; then
    printf '%s\t%s\n' "$source_fp" "$src" >>"$SOURCE_STATE_AFTER"
  else
    echo "Could not fingerprint audit source after panel: $src" >&2
    PANEL_INVALID=true
  fi
done
if ! cmp -s "$SOURCE_STATE_BEFORE" "$SOURCE_STATE_AFTER"; then
  echo "One or more requirement sources changed during audit" >&2
  PANEL_INVALID=true
fi

if $PANEL_INVALID; then
  echo "Audit BLOCKED: snapshot drift invalidated every reviewer vote" >&2
  # Preserve all evidence. Do not reset or overwrite user changes.
  exit 1
fi
```

Any graph or requirement-source mismatch invalidates the panel because the votes
no longer describe current source truth. Its audit quality is `BLOCKED` and it has
no launch verdict. Preserve logs, establish who or what changed when possible,
and rerun only after capturing a stable new baseline.

## Recovery

| Symptom | Action |
|---|---|
| Codex model unavailable | Retry once without `-m gpt-5.6-sol`; record the environment-default fallback. |
| Codex auth/non-zero error | Surface stderr; continue `DEGRADED` with the Claude auditor. |
| Claude `is_error`, rate limit, overload, or auth error | Retry once. If it fails again, **re-resolve the ladder once** and rerun on the next model before degrading — credits can expire between the probe and a 900s audit, and degrading with an untried rung is the exact outcome the ladder exists to prevent. `DEGRADED` when that single re-resolution is spent or the candidates run out, whichever is first. |
| Output ambiguous | Reread the prompt file and rerun that reviewer once. A second ambiguity is a reviewer failure. |
| Reviewer timeout | Ignore partial output and mark that reviewer failed. On the Claude side a timeout is also the signature of an unreachable model, so re-resolve the ladder once (same one-re-resolution cap) before concluding the auditor is merely slow. |
| A model pin cannot be reached | Report the slot as failed. Do **not** substitute: a pin replaces the ladder, and the user named that model specifically. |
| Graph or source snapshot drifts | Invalidate every vote and report `BLOCKED`; never synthesize a verdict from stale evidence. |
| All requested reviewers fail or are absent | Report `BLOCKED` with no launch verdict; preserve every failure reason. |

A user-pinned one-reviewer run is `PINNED PANEL` if healthy. It becomes
`BLOCKED` if the requested reviewer fails; do not silently substitute a reviewer
the user excluded.

## Merge

Merge duplicate claims into one finding and tag source:

```markdown
| # | Severity | Source | Claim | Evidence | Disposition |
|---|---|---|---|---|---|
| 1 | BLOCKER | BOTH | Recovery workflow is unowned | Plan §4; bd-12, bd-18 | UPHELD |
| 2 | IMPORTANT | CLAUDE | bd-31 has no executable acceptance signal | Plan §7; bd-31 | UPHELD |
| 3 | NIT | CODEX | Two tiny docs beads could merge | Plan §9; bd-42, bd-43 | REJECTED |
| 4 | IMPORTANT | CONFLICT | Whether rollout blocks the API epic | Plan §8; bd-7, bd-20 | RESOLVED: CODEX |
```

`BOTH` is a confidence and ordering signal, not automatic truth. A single-source
finding keeps its severity until evidence changes it. Silence is not
counter-evidence. Resolve `CONFLICT` from the plan and graph, with citations.

Write the complete reconciled report from
[review-report-template.md](review-report-template.md) to `"$MERGED_OUT"` before
publishing stable names. Artifact preservation is part of audit completeness and
must fail closed:

```bash
[ -s "$MERGED_OUT" ] || {
  echo "Audit BLOCKED: merged report was not created" >&2
  exit 1
}
grep -q '^# Bead Graph Audit$' "$MERGED_OUT"
grep -q '^## Panel$' "$MERGED_OUT"
grep -q '^## Launch verdict$' "$MERGED_OUT"
grep -q '^## Logs$' "$MERGED_OUT"

if $RUN_CODEX && [ "${CODEX_STATE:-failed}" = usable ]; then
  [ -s "$CODEX_OUT" ]
  cp "$CODEX_OUT" "$AUDIT_DIR/audit.codex.txt"
fi
if $RUN_CLAUDE && [ "${CLAUDE_STATE:-failed}" = usable ]; then
  [ -s "$CLAUDE_OUT" ]
  cp "$CLAUDE_OUT" "$AUDIT_DIR/audit.claude.txt"
fi
cp "$MERGED_OUT" "$AUDIT_DIR/audit.merged.md"
```
