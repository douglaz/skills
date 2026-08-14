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
# Clear loader injection in this already-running shell before the locator starts
# any new process. The resolver/git-clean script bodies are too late: a shebang
# interpreter would already have loaded caller-selected libraries.
_bjp_posixly_was_set=${POSIXLY_CORRECT+x}
_bjp_posixly_value=${POSIXLY_CORRECT-}
POSIXLY_CORRECT=y
export POSIXLY_CORRECT
\unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE \
  LD_ORIGIN_PATH LD_PRELOAD_32 LD_PRELOAD_64 DYLD_INSERT_LIBRARIES \
  DYLD_LIBRARY_PATH DYLD_FRAMEWORK_PATH DYLD_FALLBACK_LIBRARY_PATH \
  DYLD_FALLBACK_FRAMEWORK_PATH LIBPATH SHLIB_PATH GCONV_PATH LOCPATH || {
  printf '%s\n' 'cannot clear dynamic-loader injection before beads-jsonl-path — do NOT write' >&2
  exit 1
}
if [ -n "$_bjp_posixly_was_set" ]; then
  POSIXLY_CORRECT=$_bjp_posixly_value
  export POSIXLY_CORRECT
else
  \unset POSIXLY_CORRECT
fi
BEADS_JSONL_RESOLVER=$(
  (
    # Resolve the clean interpreter in a subshell. POSIX special-builtin precedence
    # prevents exported caller functions from redefining this trust path, and the
    # subshell leaves the caller's shell state untouched.
    POSIXLY_CORRECT=y
    export POSIXLY_CORRECT
    \unset -f command builtin exec unset 2>/dev/null || :
    _bjp_bash=$(command -p -v bash) || {
      printf '%s\n' 'cannot locate a trusted Bash for the beads JSONL locator — do NOT write' >&2
      exit 1
    }
    unset BASH_ENV ENV BASH_COMPAT BASH_LOADABLES_PATH BASH_XTRACEFD CDPATH GLOBIGNORE
    exec "$_bjp_bash" --noprofile --norc -p -s <<'__BJP_TRUSTED_BASH__'
# Privileged Bash ignores inherited functions. Clear the other startup controls too,
# then perform every candidate, worktree, provenance, and byte-agreement decision here.
command unset BASH_ENV ENV BASH_COMPAT BASH_LOADABLES_PATH BASH_XTRACEFD CDPATH GLOBIGNORE || {
  printf '%s\n' 'cannot sanitize the beads JSONL locator shell environment — do NOT write' >&2
  exit 1
}
while command builtin read -r _ _ _bjp_function; do
  command unset -f -- "$_bjp_function" || {
    printf '%s\n' 'cannot sanitize the beads JSONL locator shell environment — do NOT write' >&2
    exit 1
  }
done < <(command builtin declare -F)
unset _bjp_function
_bjp_git=$(command -p -v git) || {
  printf '%s\n' 'cannot locate a trusted Git for beads-jsonl-path — do NOT write' >&2
  exit 1
}
_bjp_cmp=$(command -p -v cmp) || {
  printf '%s\n' 'cannot locate a trusted cmp for beads-jsonl-path — do NOT write' >&2
  exit 1
}
_bjp_stat=$(command -p -v stat) || {
  printf '%s\n' 'cannot locate a trusted stat for beads-jsonl-path — do NOT write' >&2
  exit 1
}
_bjp_regular_link_count() {
  local path=$1 count
  if count=$("$_bjp_stat" -c %h "$path" 2>/dev/null) && [[ $count =~ ^[0-9]+$ ]]; then
    :
  elif count=$("$_bjp_stat" -f %l "$path" 2>/dev/null) && [[ $count =~ ^[0-9]+$ ]]; then
    :
  else
    return 1
  fi
  printf '%s\n' "$count"
}
_bjp_git_environment=( "${!GIT@}" )
for _bjp_git_variable in "${_bjp_git_environment[@]}"; do
  command unset -- "$_bjp_git_variable" || {
    printf '%s\n' 'cannot sanitize the Git environment for beads-jsonl-path — do NOT write' >&2
    exit 1
  }
done
unset _bjp_git_variable _bjp_git_environment

BEADS_JSONL_RESOLVER=
BEADS_GIT_RUNNER=
for _bjp_dir in "$HOME/.claude/skills/beads-jsonl-path" \
  "${CODEX_HOME:-$HOME/.codex}/skills/beads-jsonl-path" \
  "$HOME/.agents/skills/beads-jsonl-path"; do
  case $_bjp_dir in
    /*) ;;
    *) printf '%s\n' 'installed beads-jsonl-path target is not absolute — do NOT write' >&2; exit 1 ;;
  esac
  _bjp_candidate="$_bjp_dir/scripts/resolve-beads-jsonl"
  [ -x "$_bjp_candidate" ] || continue
  [ ! -L "$_bjp_candidate" ] || {
    printf '%s\n' 'installed beads-jsonl-path resolver is a symbolic link — do NOT write' >&2
    exit 1
  }
  _bjp_root_raw=$("$_bjp_git" --no-replace-objects -c core.fsmonitor=false rev-parse --show-toplevel 2>/dev/null) || {
    printf '%s\n' 'cannot resolve the current Git worktree — do NOT write' >&2
    exit 1
  }
  _bjp_root=$(
    CDPATH=
    export CDPATH
    cd -P -- "$_bjp_root_raw" 2>/dev/null && pwd -P
  ) || {
    printf '%s\n' 'cannot canonicalize the current Git worktree — do NOT write' >&2
    exit 1
  }
  _bjp_candidate_dir=$(
    CDPATH=
    export CDPATH
    cd -P -- "$_bjp_dir/scripts" 2>/dev/null && pwd -P
  ) || {
    printf '%s\n' 'cannot canonicalize installed beads-jsonl-path target — do NOT write' >&2
    exit 1
  }
  _bjp_candidate="$_bjp_candidate_dir/resolve-beads-jsonl"
  [ ! -L "$_bjp_candidate" ] || {
    printf '%s\n' 'installed beads-jsonl-path resolver is a symbolic link — do NOT write' >&2
    exit 1
  }
  case $_bjp_root:$_bjp_candidate_dir in
    /:/*|*:"$_bjp_root"|*:"$_bjp_root"/*)
      printf '%s\n' 'installed beads-jsonl-path target is inside the current Git worktree — do NOT write' >&2
      exit 1
      ;;
  esac
  [ -f "$_bjp_candidate" ] || {
    printf '%s\n' 'installed beads-jsonl-path resolver is not a regular file — do NOT write' >&2
    exit 1
  }
  _bjp_link_count=$(_bjp_regular_link_count "$_bjp_candidate") || {
    printf '%s\n' 'cannot inspect installed beads-jsonl-path resolver hard-link count — do NOT write' >&2
    exit 1
  }
  [ "$_bjp_link_count" = 1 ] || {
    printf '%s\n' 'installed beads-jsonl-path resolver has multiple hard links — do NOT write' >&2
    exit 1
  }
  unset _bjp_link_count
  if ! IFS= command builtin read -r _bjp_shebang <"$_bjp_candidate"; then
    printf '%s\n' 'cannot inspect installed beads-jsonl-path resolver interpreter — do NOT write' >&2
    exit 1
  fi
  [ "$_bjp_shebang" = '#!/bin/sh' ] || {
    printf '%s\n' 'installed beads-jsonl-path resolver has an unexpected interpreter — do NOT write' >&2
    exit 1
  }
  unset _bjp_shebang
  _bjp_runner="$_bjp_candidate_dir/git-clean"
  [ -x "$_bjp_runner" ] || {
    printf '%s\n' 'installed beads-jsonl-path Git runner unavailable — do NOT write' >&2
    exit 1
  }
  [ ! -L "$_bjp_runner" ] || {
    printf '%s\n' 'installed beads-jsonl-path Git runner is a symbolic link — do NOT write' >&2
    exit 1
  }
  [ -f "$_bjp_runner" ] || {
    printf '%s\n' 'installed beads-jsonl-path Git runner is not a regular file — do NOT write' >&2
    exit 1
  }
  _bjp_link_count=$(_bjp_regular_link_count "$_bjp_runner") || {
    printf '%s\n' 'cannot inspect installed beads-jsonl-path Git runner hard-link count — do NOT write' >&2
    exit 1
  }
  [ "$_bjp_link_count" = 1 ] || {
    printf '%s\n' 'installed beads-jsonl-path Git runner has multiple hard links — do NOT write' >&2
    exit 1
  }
  unset _bjp_link_count
  if ! IFS= command builtin read -r _bjp_shebang <"$_bjp_runner"; then
    printf '%s\n' 'cannot inspect installed beads-jsonl-path Git runner interpreter — do NOT write' >&2
    exit 1
  fi
  [ "$_bjp_shebang" = '#!/bin/sh' ] || {
    printf '%s\n' 'installed beads-jsonl-path Git runner has an unexpected interpreter — do NOT write' >&2
    exit 1
  }
  unset _bjp_shebang
  unset _bjp_candidate_dir
  if [ -z "$BEADS_JSONL_RESOLVER" ]; then
    BEADS_JSONL_RESOLVER=$_bjp_candidate
    BEADS_GIT_RUNNER=$_bjp_runner
  elif ! "$_bjp_cmp" -s "$BEADS_JSONL_RESOLVER" "$_bjp_candidate" \
      || ! "$_bjp_cmp" -s "$BEADS_GIT_RUNNER" "$_bjp_runner"; then
    printf '%s\n' 'installed beads-jsonl-path companions disagree — do NOT write' >&2
    exit 1
  fi
  unset _bjp_runner
done
unset _bjp_candidate _bjp_root _bjp_root_raw _bjp_git _bjp_cmp _bjp_stat
[ -n "$BEADS_JSONL_RESOLVER" ] && [ -n "$BEADS_GIT_RUNNER" ] || {
  printf '%s\n' 'beads-jsonl-path companion unavailable — do NOT write' >&2
  exit 1
}
printf '%s\n' "$BEADS_JSONL_RESOLVER"
__BJP_TRUSTED_BASH__
  )
) || exit 1
BEADS_GIT_RUNNER=${BEADS_JSONL_RESOLVER%/*}/git-clean
unset _bjp_candidate
# Installed targets only. A relative `skills/beads-jsonl-path/scripts/resolve-beads-jsonl`
# is whatever executable the audited repo planted there, and this snippet would run it.
# From a checkout, run that checkout's copy by absolute path instead.
[ -n "$BEADS_JSONL_RESOLVER" ] || {
  echo "beads-jsonl-path companion unavailable — do NOT flush" >&2
  exit 1
}
REPO_ROOT=$("$BEADS_GIT_RUNNER" worktree-root) || exit 1
_PROJECT=${REPO_ROOT##*/}
[[ -n "$_PROJECT" ]] || _PROJECT=root
_PROJECT=${_PROJECT//[^A-Za-z0-9._-]/_}
AUDIT_DIR=$("$BEADS_GIT_RUNNER" make-temp-dir "bead-audit-${_PROJECT}") || exit 1

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
GRAPH_AFTER_SYNC_JSONL="$AUDIT_DIR/issues.after-sync.jsonl"
TRIAGE_OUT="$AUDIT_DIR/triage.txt"
PLAN_OUT="$AUDIT_DIR/plan.txt"
SUGGEST_OUT="$AUDIT_DIR/suggest.txt"
GRAPH_DEPS_JSON="$AUDIT_DIR/graph-dependencies.json"
ISSUE_DIR="$AUDIT_DIR/issues"
SOURCE_DIR="$AUDIT_DIR/sources"
SOURCE_MANIFEST="$AUDIT_DIR/source-manifest.txt"
SOURCE_STATE_BEFORE="$AUDIT_DIR/source-state.before.txt"
SOURCE_STATE_AFTER="$AUDIT_DIR/source-state.after.txt"
"$BEADS_GIT_RUNNER" make-dir "$ISSUE_DIR" "$SOURCE_DIR"
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
  "$BEADS_GIT_RUNNER" hash-file "$1"
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
  [[ "$governed" == /*/* ]] || {
    echo "Audit source is not an absolute file path: $governed" >&2
    exit 1
  }
  dir=${governed%/*}
  [[ -n "$dir" ]] || dir=/
  while [[ "$REPO_ROOT" == / || "$dir" == "$REPO_ROOT" \
           || "$dir" == "$REPO_ROOT/"* ]]; do
    [ ! -f "$dir/AGENTS.md" ] || add_source "$dir/AGENTS.md"
    [ "$dir" != "$REPO_ROOT" ] || break
    dir=${dir%/*}
    [[ -n "$dir" ]] || dir=/
  done
done

"$BEADS_GIT_RUNNER" snapshot-files \
  "$SOURCE_MANIFEST" "$SOURCE_STATE_BEFORE" "$SOURCE_DIR" -- \
  "${SOURCE_FILES[@]}" || {
  echo "Could not capture a stable authoritative-source snapshot" >&2
  exit 1
}

# RESOLVE AND INSPECT BEFORE FLUSHING. The flush writes the cache over the tracked file,
# so an unstaged hand-edit is destroyed HERE — and the diff below then compares the file
# against an index that already matches it, comes back empty, and the audit snapshots the
# truncated graph having "checked". The check has to precede the write it guards.
# --allow-dirty: do NOT gate on a clean file here. The normal `bead-polish-loop` handoff
# arrives with the round's intended `br` edits flushed and uncommitted, so the owner's
# default clean-state mode would block the audit after every non-noop round.
#
# The question is not "is it dirty" but "is any of this dirt something the cache will
# destroy" — i.e. hand-edited bead text, which never advances `updated_at`. Read the diff
# and continue only once you can say which it is.
# Against HEAD, not the index: a damaged JSONL that is STAGED makes a worktree-vs-index
# diff empty while HEAD still holds the good bodies, so the operator would acknowledge a
# clean-looking diff and flush the damage.
#
# `--allow-dirty` retains the owner's tracked stage-0, normal-flag, regular-mode proof and
# drops byte identity only where the HEAD diff below can still expose both staged and
# unstaged differences. The clean runner disables stale fsmonitor answers, external
# diff drivers, textconv, and binary attributes.
unset BEADS_DIFF_REVIEWED
BEADS_JSONL=$("$BEADS_JSONL_RESOLVER" --allow-dirty) || exit 1
"$BEADS_GIT_RUNNER" --literal-pathspecs diff --no-ext-diff --no-textconv --text HEAD -- "$BEADS_JSONL"          || { echo "cannot diff the JSONL — do NOT flush" >&2; exit 1; }
# Keep a copy of what the worktree held BEFORE the flush. Neither git ref works as the
# post-flush baseline: if the index holds an earlier damaged export and the worktree holds
# the good recovery, HEAD-vs-worktree looks fine beforehand, the flush replaces the good
# copy with the indexed damage, and a worktree-vs-index diff afterwards is EMPTY because
# both now hold it. Only the pre-flush bytes can show that.
"$BEADS_GIT_RUNNER" copy-file "$BEADS_JSONL" "$AUDIT_DIR/preflush.jsonl" || { echo "cannot preserve the pre-flush graph" >&2; exit 1; }
```

**Stop the block here and read the HEAD diff.** Continue in the same Bash process
only after binding `BEADS_DIFF_REVIEWED` to this audit. A value from an earlier
skill step or audit was explicitly cleared above and cannot authorize this flush.

```bash
: "${BEADS_DIFF_REVIEWED:?read the HEAD diff above, then set this to how you resolved it}"
"$BEADS_JSONL_RESOLVER" --run-br sync --flush-only || { echo "flush failed — do not audit an unwritten graph" >&2; exit 1; }

# STOP HERE AND READ THIS DIFF before snapshotting. The flush just re-exported EVERY bead
# from the gitignored cache over the tracked JSONL, so any body the cache held a stale copy
# of was silently reverted — exit 0, no warning. Snapshot now and the panel audits the
# truncated graph, which is the one failure an audit cannot catch by reading: the text it
# would have objected to is already gone. Field-diff it, key the +/- lines by `id`, and
# assert only the fields you meant to change moved. Ids on one side only, or a
# `description` this session did not write, is the tell. Recovery:
# exact companion skill rb-lite-backlog-drain, step 11:
# ../../rb-lite-backlog-drain/SKILL.md#backlog-step-11.
unset BEADS_POSTFLUSH_REVIEWED
if "$BEADS_GIT_RUNNER" diff-files "$AUDIT_DIR/preflush.jsonl" "$BEADS_JSONL"; then
  _BEADS_POSTFLUSH_DIFF_RC=0
else
  _BEADS_POSTFLUSH_DIFF_RC=$?
fi
case $_BEADS_POSTFLUSH_DIFF_RC in
  0|1) ;;
  *) echo "cannot compare the pre/post-flush JSONL bytes — do NOT audit" >&2; exit 1 ;;
esac
```

**Stop the block here.** The line above is a real gate, not a comment: run the snapshot
block only up to this point, read the diff, and continue *in a second invocation* once you
have. A comment does not pause a shell — pasted as one block, the diff scrolls past and the
copy below snapshots whatever the flush produced, which is the entire failure this check
exists to catch. If you must automate it, make the continuation conditional on an explicit
recorded acknowledgement rather than on the diff having been printed.

```bash
# The first block accepted only diff statuses 0 (same) and 1 (different). Status
# 1 needs an acknowledgement bound to this audit after reading that block's output.
case $_BEADS_POSTFLUSH_DIFF_RC in
  0) ;;
  1) : "${BEADS_POSTFLUSH_REVIEWED:?the flush changed the graph — read this audit's diff, then set this}" ;;
  *) echo "missing a valid pre/post-flush comparison — do NOT audit" >&2; exit 1 ;;
esac
"$BEADS_GIT_RUNNER" copy-file "$BEADS_JSONL" "$GRAPH_JSONL"
GRAPH_FINGERPRINT=$(fingerprint_file "$GRAPH_JSONL") || {
  echo "Could not fingerprint initial graph snapshot" >&2
  exit 1
}
[ -n "$GRAPH_FINGERPRINT" ] || {
  echo "Initial graph fingerprint is empty" >&2
  exit 1
}

"$BEADS_JSONL_RESOLVER" --run-br list --limit 0 --json -a >"$GRAPH_JSON"
"$BEADS_GIT_RUNNER" run-audit-tool bv --robot-triage >"$TRIAGE_OUT"
"$BEADS_GIT_RUNNER" run-audit-tool bv --robot-plan >"$PLAN_OUT"
"$BEADS_GIT_RUNNER" run-audit-tool bv --robot-suggest >"$SUGGEST_OUT"
"$BEADS_JSONL_RESOLVER" --run-br graph --all --json >"$GRAPH_DEPS_JSON"

if ISSUE_IDS=$("$BEADS_JSONL_RESOLVER" --run-jq -er '(.issues // .)[] | .id' <"$GRAPH_JSON"); then
  :
else
  echo "Could not extract issue IDs from graph snapshot" >&2
  exit 1
fi

while IFS= read -r id; do
  safe_id=${id//[^A-Za-z0-9._-]/_}
  "$BEADS_JSONL_RESOLVER" --run-br show "$id" --json >"$ISSUE_DIR/$safe_id.json"
done <<<"$ISSUE_IDS"

"$BEADS_JSONL_RESOLVER" --run-br sync --flush-only
CAPTURE_AFTER_JSONL="$AUDIT_DIR/issues.capture-after.jsonl"
"$BEADS_GIT_RUNNER" copy-file "$BEADS_JSONL" "$CAPTURE_AFTER_JSONL"
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
  "$BEADS_GIT_RUNNER" run-posix sed -n 'p' <<'EOF'
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

Use this audit's already validated tool boundary for the probe. Do **not** run the
ambient-tool probe from `multi-reviewer-loop`: its caller-PATH lookup would cross
the trust boundary before this panel's hardened dispatch.

```bash
CLAUDE_MODEL=""
CLAUDE_MODEL_LADDER="${CLAUDE_REVIEWER_MODELS:-fable opus}"
_CLAUDE_PROBE="$AUDIT_DIR/claude-model-probe.json"
_CLAUDE_PROBE_TIMEOUT=
if "$BEADS_GIT_RUNNER" run-audit-tool timeout \
     --kill-after=1s 1s true >/dev/null 2>&1; then
  _CLAUDE_PROBE_TIMEOUT=timeout
elif "$BEADS_GIT_RUNNER" run-audit-tool gtimeout \
     --kill-after=1s 1s true >/dev/null 2>&1; then
  _CLAUDE_PROBE_TIMEOUT=gtimeout
fi
if [ -n "$_CLAUDE_PROBE_TIMEOUT" ] \
    && CLAUDE_BIN=$("$BEADS_GIT_RUNNER" resolve-tool claude); then
  for _m in $CLAUDE_MODEL_LADDER; do
    _rc=0
    "$BEADS_GIT_RUNNER" run-audit-tool "$_CLAUDE_PROBE_TIMEOUT" \
      --kill-after=15 90 "$CLAUDE_BIN" -p 'Reply with exactly: PANEL_OK' \
      --model "$_m" --output-format json \
      --no-session-persistence --safe-mode --strict-mcp-config \
      --mcp-config '{"mcpServers":{}}' \
      --tools "Read" --allowedTools "Read" \
      --disallowedTools "Edit,Write,NotebookEdit" \
      </dev/null >"$_CLAUDE_PROBE" 2>/dev/null || _rc=$?
    if [ "$_rc" -eq 0 ] \
       && "$BEADS_JSONL_RESOLVER" --run-jq -e \
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

An unreachable model hangs rather than erroring, so without the bounded probe
the 900s audit timeout is the first thing that notices and reports a failure
after fifteen minutes rather than a substitution after one.

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
if "$BEADS_GIT_RUNNER" run-audit-tool timeout \
     --kill-after=1s 1s true >/dev/null 2>&1; then
  TIMEOUT_TOOL=timeout
elif "$BEADS_GIT_RUNNER" run-audit-tool gtimeout \
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
  CODEX_BIN=$("$BEADS_GIT_RUNNER" resolve-tool codex) || exit 1
  "$BEADS_GIT_RUNNER" run-audit-tool "$TIMEOUT_TOOL" \
    --kill-after=30s 900s "$CODEX_BIN" exec \
    -C "$REPO_ROOT" \
    --sandbox read-only \
    --ephemeral \
    --ignore-user-config \
    -c 'mcp_servers={}' \
    -m gpt-5.6-sol \
    -c 'model_reasoning_effort="xhigh"' \
    --output-last-message "$CODEX_OUT" \
    "$(<"$AUDIT_PROMPT_FILE")" \
    </dev/null >"$CODEX_TRACE" 2>"$CODEX_ERR" &
  CODEX_PID=$!
fi

if $RUN_CLAUDE; then
  CLAUDE_BIN=$("$BEADS_GIT_RUNNER" resolve-tool claude) || exit 1
  (
    "$BEADS_GIT_RUNNER" run-audit-tool "$TIMEOUT_TOOL" \
      --kill-after=30s 900s "$CLAUDE_BIN" -p "$(<"$AUDIT_PROMPT_FILE")" \
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
if "$BEADS_JSONL_RESOLVER" --run-jq -er \
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
  if CLAUDE_DENIALS=$("$BEADS_JSONL_RESOLVER" --run-jq -r \
      '.permission_denials[]?.tool_name' <"$CLAUDE_RAW"); then
    if "$BEADS_JSONL_RESOLVER" --run-jq -e \
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
  "$BEADS_JSONL_RESOLVER" --run-jq -r '.modelUsage | keys[]' <"$CLAUDE_RAW" || true
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
  verdict=$("$BEADS_GIT_RUNNER" run-posix sed -n '1s/^VERDICT: //p' "$file")
  rationale=$("$BEADS_GIT_RUNNER" run-posix sed -n '2p' "$file")
  [ -n "$rationale" ] || return 1
  if "$BEADS_GIT_RUNNER" grep -qE \
      '^(\[(BLOCKER|IMPORTANT|NIT)\]|No findings\.|COVERAGE:|DEPENDENCIES:|VERIFICATION:)' \
      <<<"$rationale"; then
    return 1
  fi
  if blockers=$("$BEADS_GIT_RUNNER" grep -cE \
      '^[[:space:]]*\[BLOCKER\]' "$file"); then
    :
  else
    grep_rc=$?
    [ "$grep_rc" -eq 1 ] || return 1
    blockers=${blockers:-0}
  fi
  if important=$("$BEADS_GIT_RUNNER" grep -cE \
      '^[[:space:]]*\[IMPORTANT\]' "$file"); then
    :
  else
    grep_rc=$?
    [ "$grep_rc" -eq 1 ] || return 1
    important=${important:-0}
  fi
  if nits=$("$BEADS_GIT_RUNNER" grep -cE \
      '^[[:space:]]*\[NIT\]' "$file"); then
    :
  else
    grep_rc=$?
    [ "$grep_rc" -eq 1 ] || return 1
    nits=${nits:-0}
  fi
  total=$((blockers + important + nits))

  closing=$("$BEADS_GIT_RUNNER" run-posix tail -n 3 "$file")
  mapfile -t closing_lines <<<"$closing"
  [ "${#closing_lines[@]}" -eq 3 ] || return 1
  [[ "${closing_lines[0]}" == COVERAGE:* ]] || return 1
  [[ "${closing_lines[1]}" == DEPENDENCIES:* ]] || return 1
  [[ "${closing_lines[2]}" == VERIFICATION:* ]] || return 1

  # Every finding must carry all three support fields before the next finding.
  "$BEADS_GIT_RUNNER" run-posix awk '
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
    "$BEADS_GIT_RUNNER" grep -qx 'No findings\.' "$file" || return 1
  else
    ! "$BEADS_GIT_RUNNER" grep -qx 'No findings\.' "$file" || return 1
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

# Read and preserve the live JSONL BEFORE any flush can overwrite a concurrent
# hand edit. Only an unchanged live snapshot may proceed to the cache-drift
# flush below.
if BEADS_CURRENT_JSONL=$("$BEADS_JSONL_RESOLVER" --allow-dirty) \
    && [ "$BEADS_CURRENT_JSONL" = "$BEADS_JSONL" ] \
    && "$BEADS_GIT_RUNNER" copy-file "$BEADS_CURRENT_JSONL" "$GRAPH_AFTER_JSONL" \
    && GRAPH_AFTER_FINGERPRINT=$(fingerprint_file "$GRAPH_AFTER_JSONL") \
    && [ -n "$GRAPH_AFTER_FINGERPRINT" ]; then
  :
else
  echo "Could not preserve the live graph before the final drift check" >&2
  PANEL_INVALID=true
fi
if ! $PANEL_INVALID && [ "$GRAPH_FINGERPRINT" != "$GRAPH_AFTER_FINGERPRINT" ]; then
  printf 'Graph changed during audit before any final flush: before=%s after=%s\n' \
    "$GRAPH_FINGERPRINT" "$GRAPH_AFTER_FINGERPRINT" >&2
  PANEL_INVALID=true
fi

if ! $PANEL_INVALID; then
  "$BEADS_JSONL_RESOLVER" --run-br sync --flush-only || {
    echo "Could not flush for the final cache-drift check" >&2
    exit 1
  }
  "$BEADS_GIT_RUNNER" copy-file "$BEADS_CURRENT_JSONL" "$GRAPH_AFTER_SYNC_JSONL"
  GRAPH_AFTER_SYNC_FINGERPRINT=$(fingerprint_file "$GRAPH_AFTER_SYNC_JSONL") || {
    echo "Could not fingerprint graph after final cache flush" >&2
    exit 1
  }
  if [ "$GRAPH_FINGERPRINT" != "$GRAPH_AFTER_SYNC_FINGERPRINT" ]; then
    printf 'Beads cache changed during audit: before=%s after-sync=%s\n' \
      "$GRAPH_FINGERPRINT" "$GRAPH_AFTER_SYNC_FINGERPRINT" >&2
    PANEL_INVALID=true
  fi
fi

if ! "$BEADS_GIT_RUNNER" verify-files \
    "$SOURCE_STATE_BEFORE" "$SOURCE_STATE_AFTER" -- "${SOURCE_FILES[@]}"; then
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
"$BEADS_GIT_RUNNER" grep -q '^# Bead Graph Audit$' "$MERGED_OUT"
"$BEADS_GIT_RUNNER" grep -q '^## Panel$' "$MERGED_OUT"
"$BEADS_GIT_RUNNER" grep -q '^## Launch verdict$' "$MERGED_OUT"
"$BEADS_GIT_RUNNER" grep -q '^## Logs$' "$MERGED_OUT"

if $RUN_CODEX && [ "${CODEX_STATE:-failed}" = usable ]; then
  [ -s "$CODEX_OUT" ]
  "$BEADS_GIT_RUNNER" copy-file "$CODEX_OUT" "$AUDIT_DIR/audit.codex.txt"
fi
if $RUN_CLAUDE && [ "${CLAUDE_STATE:-failed}" = usable ]; then
  [ -s "$CLAUDE_OUT" ]
  "$BEADS_GIT_RUNNER" copy-file "$CLAUDE_OUT" "$AUDIT_DIR/audit.claude.txt"
fi
"$BEADS_GIT_RUNNER" copy-file "$MERGED_OUT" "$AUDIT_DIR/audit.merged.md"
```
