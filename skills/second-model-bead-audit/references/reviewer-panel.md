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

## Shared graph snapshot

The producer owns a successful flush and review of intended fields before handoff.
Audit the exported JSONL and source copies; do not flush or query the live database.

Set absolute `PLAN_PATH` and `AUDIT_SCOPE` (root beads plus child/dependency closure).
Include all authoritative linked documents and their governing instructions in `SOURCE_FILES`.

```bash
set -euo pipefail
: "${PLAN_PATH:?Set the absolute plan/spec path}"
: "${AUDIT_SCOPE:?Set the audit scope}"
REPO_ROOT=$(git rev-parse --show-toplevel)
WHERE=$(br --no-auto-flush --no-auto-import where --json) || exit 1
BEADS_JSONL=$(jq -er '.jsonl_path | select(type == "string" and startswith("/"))' <<<"$WHERE") || exit 1
AUDIT_DIR=$(mktemp -d)
SOURCE_DIR="$AUDIT_DIR/sources"
SOURCE_MANIFEST="$AUDIT_DIR/source-manifest.txt"
GRAPH_JSONL="$AUDIT_DIR/issues.jsonl"
AUDIT_PROMPT_FILE="$AUDIT_DIR/audit-prompt.txt"
CODEX_OUT="$AUDIT_DIR/codex.txt"
CODEX_TRACE="$AUDIT_DIR/codex.trace.txt"
CODEX_ERR="$AUDIT_DIR/codex.stderr.txt"
CLAUDE_RAW="$AUDIT_DIR/claude.raw.json"
CLAUDE_OUT="$AUDIT_DIR/claude.txt"
CLAUDE_ERR="$AUDIT_DIR/claude.stderr.txt"
MERGED_OUT="$AUDIT_DIR/merged.md"
mkdir "$SOURCE_DIR"
SOURCE_FILES=("$PLAN_PATH")
for source in "$REPO_ROOT/README.md" "$REPO_ROOT/AGENTS.md"; do
  if [ -f "$source" ]; then SOURCE_FILES+=("$source"); fi
done
# Add approved deltas, waivers, linked requirements and nested AGENTS.md here.
: >"$SOURCE_MANIFEST"
i=0
for source in "${SOURCE_FILES[@]}"; do
  i=$((i + 1))
  copy="$SOURCE_DIR/$i-${source##*/}"
  cp "$source" "$copy"
  printf '%s\t%s\n' "$source" "$copy" >>"$SOURCE_MANIFEST"
done
cp "$BEADS_JSONL" "$GRAPH_JSONL"
jq -se 'length > 0 and all(.[]; (.id | type) == "string")' "$GRAPH_JSONL" >/dev/null
GRAPH_FINGERPRINT=$(git hash-object --no-filters "$GRAPH_JSONL")
```

Keep the full export for cross-scope dependencies. Reviewers derive graph structure
from its embedded dependencies; the audit does not need live `br`/`bv` views.

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
  printf 'Authoritative issues JSONL: %s\n\n' "$GRAPH_JSONL"
  sed -n 'p' <<'EOF'
This is the final read-only launch-readiness gate after bead polishing. Independently
derive your judgment from the plan and graph. Do not trust or search for another
reviewer's conclusions.

First read the snapshotted AGENTS.md, README.md, source plan/spec, approved
deltas/waivers, and linked docs listed in the source manifest. Treat those copies,
not live repo versions, as authoritative.
Use only the copied JSONL, including its dependencies and comments, as the
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

Normalize requested slots before probing and dispatch. Require GNU `timeout`
with `--kill-after` support to bound both probes and reviews.

### 1. Normalize a model-name pin to its slot

A model-name pin selects the `claude` slot and replaces its ladder.

```bash
PANEL_REVIEWERS=${PANEL_REVIEWERS:-codex,claude}
CLAUDE_MODEL_PIN=""
_norm=""
IFS=',' read -ra _rv <<<"$PANEL_REVIEWERS"
for _r in "${_rv[@]}"; do
  case "$_r" in
    codex|claude)      _norm="${_norm:+$_norm,}$_r" ;;
    "")                ;;
    fable|opus)   CLAUDE_MODEL_PIN="$_r"; _norm="${_norm:+$_norm,}claude" ;;
    *) echo "Unknown reviewer or model: $_r" >&2; exit 2 ;;
  esac
done
PANEL_REVIEWERS="$_norm"
if [ -n "$CLAUDE_MODEL_PIN" ]; then export CLAUDE_REVIEWER_MODELS="$CLAUDE_MODEL_PIN"; fi
```

### 2. Resolve `$CLAUDE_MODEL`

**Only when the normalized panel contains `claude`.** A `--reviewers codex` audit must
not pay for a probe of a reviewer it excluded — up to 90 seconds per unreachable rung,
and a real model call.

Probe only the requested slot; a model pin replaces the ladder.

```bash
CLAUDE_MODEL=""
CLAUDE_MODEL_LADDER="${CLAUDE_REVIEWER_MODELS:-fable opus}"
_CLAUDE_PROBE="$AUDIT_DIR/claude-model-probe.json"
_CLAUDE_PROBE_TIMEOUT=
if timeout \
     --kill-after=1s 1s true >/dev/null 2>&1; then
  _CLAUDE_PROBE_TIMEOUT=timeout
elif gtimeout \
     --kill-after=1s 1s true >/dev/null 2>&1; then
  _CLAUDE_PROBE_TIMEOUT=gtimeout
fi
if [ -n "$_CLAUDE_PROBE_TIMEOUT" ] \
    && CLAUDE_BIN=$(command -v claude); then
  for _m in $CLAUDE_MODEL_LADDER; do
    _rc=0
    env -u CLAUDE_CODE_AUTO_COMPACT_WINDOW \
      "$_CLAUDE_PROBE_TIMEOUT" --kill-after=15 90 "$CLAUDE_BIN" -p 'Reply with exactly: PANEL_OK' \
      --model "$_m" --output-format json \
      --no-session-persistence --safe-mode --strict-mcp-config \
      --mcp-config '{"mcpServers":{}}' \
      --tools "Read" --allowedTools "Read" \
      --disallowedTools "Edit,Write,NotebookEdit" \
      </dev/null >"$_CLAUDE_PROBE" 2>/dev/null || _rc=$?
    if [ "$_rc" -eq 0 ] \
       && jq -e \
          '(.is_error | not) and ((.result // "") != "")' \
          <"$_CLAUDE_PROBE" >/dev/null 2>&1; then
      CLAUDE_MODEL=$_m
      break
    fi
    echo "claude auditor: '$_m' did not answer (exit $_rc)"
  done
fi
unset _CLAUDE_PROBE_TIMEOUT _rc
```

If no candidate answers, drop `claude` from `PANEL_REVIEWERS` and record why:

```bash
_keep=""
for _r in ${PANEL_REVIEWERS//,/ }; do
  if [ "$_r" = claude ]; then continue; fi
  _keep="${_keep:+$_keep,}$_r"
done
PANEL_REVIEWERS="$_keep"
```

If no requested reviewer remains, report `BLOCKED` rather than substituting one:

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
if timeout \
     --kill-after=1s 1s true >/dev/null 2>&1; then
  TIMEOUT_TOOL=timeout
elif gtimeout \
     --kill-after=1s 1s true >/dev/null 2>&1; then
  TIMEOUT_TOOL=gtimeout
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
  CODEX_BIN=$(command -v codex) || exit 1
  "$TIMEOUT_TOOL" \
    --kill-after=30s 900s "$CODEX_BIN" exec \
    -C "$REPO_ROOT" \
    --sandbox read-only \
    --ephemeral \
    --ignore-user-config \
    -c 'mcp_servers={}' \
    -m gpt-6.1-sol \
    -c 'model_reasoning_effort="high"' \
    --output-last-message "$CODEX_OUT" \
    "$(<"$AUDIT_PROMPT_FILE")" \
    </dev/null >"$CODEX_TRACE" 2>"$CODEX_ERR" &
  CODEX_PID=$!
fi

if $RUN_CLAUDE; then
  CLAUDE_BIN=$(command -v claude) || exit 1
  (
    env -u CLAUDE_CODE_AUTO_COMPACT_WINDOW \
      "$TIMEOUT_TOOL" --kill-after=30s 900s "$CLAUDE_BIN" -p "$(<"$AUDIT_PROMPT_FILE")" \
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
coordinator supplies the exported graph and authority copies. Do not add
`Bash`, remove the MCP isolation flags, or use `--permission-mode acceptEdits`.

## Unwrap and validate the Claude auditor

Unwrap only the requested slot; keep process and JSON failure statuses.

```bash
if jq -er \
     'if .is_error then error(.result // "claude auditor returned is_error")
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
  if CLAUDE_DENIALS=$(jq -r \
      '.permission_denials[]?.tool_name' <"$CLAUDE_RAW"); then
    if jq -e \
         'any(.permission_denials[]?.tool_name;
              . == "Read" or . == "Glob" or . == "Grep")' \
         <"$CLAUDE_RAW" >/dev/null; then
      CLAUDE_INSPECTION_BLOCKED=true
    else
      _CLAUDE_DENIAL_PREDICATE_RC=$?
      if [ "$_CLAUDE_DENIAL_PREDICATE_RC" -ne 1 ]; then
        JQ_RC=$_CLAUDE_DENIAL_PREDICATE_RC
      fi
      unset _CLAUDE_DENIAL_PREDICATE_RC
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
  local file=$1 verdict rationale blockers important nits total closing grep_rc
  local -a closing_lines
  [ -s "$file" ] || return 1
  verdict=$(sed -n '1s/^VERDICT: //p' "$file")
  rationale=$(sed -n '2p' "$file")
  [ -n "$rationale" ] || return 1
  if grep -qE \
      '^(\[(BLOCKER|IMPORTANT|NIT)\]|No findings\.|COVERAGE:|DEPENDENCIES:|VERIFICATION:)' \
      <<<"$rationale"; then
    return 1
  fi
  if blockers=$(grep -cE \
      '^[[:space:]]*\[BLOCKER\]' "$file"); then
    :
  else
    grep_rc=$?
    [ "$grep_rc" -eq 1 ] || return 1
    blockers=${blockers:-0}
  fi
  if important=$(grep -cE \
      '^[[:space:]]*\[IMPORTANT\]' "$file"); then
    :
  else
    grep_rc=$?
    [ "$grep_rc" -eq 1 ] || return 1
    important=${important:-0}
  fi
  if nits=$(grep -cE \
      '^[[:space:]]*\[NIT\]' "$file"); then
    :
  else
    grep_rc=$?
    [ "$grep_rc" -eq 1 ] || return 1
    nits=${nits:-0}
  fi
  total=$((blockers + important + nits))

  closing=$(tail -n 3 "$file")
  mapfile -t closing_lines <<<"$closing"
  [ "${#closing_lines[@]}" -eq 3 ] || return 1
  [[ "${closing_lines[0]}" == COVERAGE:* ]] || return 1
  [[ "${closing_lines[1]}" == DEPENDENCIES:* ]] || return 1
  [[ "${closing_lines[2]}" == VERIFICATION:* ]] || return 1

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

## Verdict scope

Votes apply to the copied export and authority sources. Any subsequent graph or
source edit requires a new audit before implementation.

## Recovery

| Symptom | Action |
|---|---|
| Codex model unavailable | Retry once without `-m gpt-6.1-sol`; record the environment-default fallback. |
| Codex auth/non-zero error | Surface stderr; continue `DEGRADED` with the Claude auditor. |
| Claude `is_error`, rate limit, overload, or auth error | Retry once. If it fails again, **re-resolve the ladder once** and rerun on the next model before degrading — credits can expire between the probe and a 900s audit, and degrading with an untried rung is the exact outcome the ladder exists to prevent. `DEGRADED` when that single re-resolution is spent or the candidates run out, whichever is first. |
| Output ambiguous | Reread the prompt file and rerun that reviewer once. A second ambiguity is a reviewer failure. |
| Reviewer timeout | Ignore partial output and mark that reviewer failed. On the Claude side a timeout is also the signature of an unreachable model, so re-resolve the ladder once (same one-re-resolution cap) before concluding the auditor is merely slow. |
| A model pin cannot be reached | Report the slot as failed. Do **not** substitute: a pin replaces the ladder, and the user named that model specifically. |
| Graph or authority sources edited after capture | Capture the new export and sources and rerun the audit. |
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
