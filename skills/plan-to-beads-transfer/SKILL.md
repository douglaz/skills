---
name: plan-to-beads-transfer
description: >-
  Translate a converged markdown plan, PRD, or approved spec into actual `br`
  beads that preserve rationale, workflows, failure handling, dependencies, and
  verification so fresh agents can execute without reopening the source plan.
  Use when the user asks to break a plan/spec into beads, tasks, or work items;
  when a feature plan is approved and needs an executable graph; or when a major
  plan revision means an existing bead graph must be refreshed from source
  truth. Do not use for brainstorming, unstable architecture, or direct
  implementation requests where plan-space work is still unfinished.
---

Turn plan-space intent into bead-space executable memory without losing anything important.

## Core invariants

- Treat plan-to-beads as translation, not extraction.
- Prefer memory density over brevity. Long bead descriptions are good when they remove guesswork.
- Make the graph rich enough that fresh agents rarely need to reopen the original plan.
- Create and modify real beads with `br`; never draft pseudo-beads in markdown.

## Preflight

- Confirm `br`, `bv`, and the exact `beads-jsonl-path` companion are available. The
  companion diagnoses its own host dependencies, including `jq`; if it cannot resolve
  and prove a clean tracked JSONL, do not write to the graph.
- Re-read `AGENTS.md`, `README.md`, and every relevant plan/spec file before mutating the graph.
- If the session was compacted, or the plan changed materially since the last pass, reread before editing.
- Refuse the transfer if core workflows, boundaries, constraints, failure modes, sequencing, or verification are still unstable. Report plan gaps instead of encoding guesses into beads.


**Before the first `br` write, resolve and prove the JSONL clean through its exact fact
owner.** Any `br` mutation auto-flushes the cache over the tracked file, so staged,
unstaged, hidden-index, unmerged, type, mode, or wrong-worktree state must refuse the
write before the cache can overwrite it:

```bash
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
_bjp_git_environment=( "${!GIT_@}" )
for _bjp_git_variable in "${_bjp_git_environment[@]}"; do
  command unset -- "$_bjp_git_variable" || {
    printf '%s\n' 'cannot sanitize the Git environment for beads-jsonl-path — do NOT write' >&2
    exit 1
  }
done
unset _bjp_git_variable _bjp_git_environment

BEADS_JSONL_RESOLVER=
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
  unset _bjp_candidate_dir
  if [ -z "$BEADS_JSONL_RESOLVER" ]; then
    BEADS_JSONL_RESOLVER=$_bjp_candidate
  elif ! "$_bjp_cmp" -s "$BEADS_JSONL_RESOLVER" "$_bjp_candidate"; then
    printf '%s\n' 'installed beads-jsonl-path companions disagree — do NOT write' >&2
    exit 1
  fi
done
unset _bjp_candidate _bjp_root _bjp_root_raw _bjp_git _bjp_cmp
[ -n "$BEADS_JSONL_RESOLVER" ] || {
  printf '%s\n' 'beads-jsonl-path companion unavailable — do NOT write' >&2
  exit 1
}
printf '%s\n' "$BEADS_JSONL_RESOLVER"
__BJP_TRUSTED_BASH__
  )
) || exit 1
unset _bjp_candidate
# Installed targets only. A relative `skills/beads-jsonl-path/scripts/resolve-beads-jsonl`
# is whatever executable the repo you are transferring into planted there, and this
# snippet would run it. From a checkout, run that checkout's copy by absolute path.
[ -n "$BEADS_JSONL_RESOLVER" ] || {
  echo "beads-jsonl-path companion unavailable — do NOT write" >&2
  exit 1
}
BEADS_JSONL=$("$BEADS_JSONL_RESOLVER") || exit 1
```

If the owner refuses, resolve the reported state first — recovery case (a) in
[exact companion skill `rb-lite-backlog-drain`, step 11](../rb-lite-backlog-drain/SKILL.md#backlog-step-11).
**Companion unavailable: stop, rerun the same installer command once, reload it, and do
not improvise this procedure.**
After the first flush the choice
is gone.

## Translation readiness test

Only transfer when most of the hard thinking already happened in plan space.

Stop and report plan gaps when any of these are still fuzzy:

- the main user and operator workflows
- the important failure, retry, or recovery paths
- architecture or ownership boundaries
- migration, rollout, compatibility, or security constraints
- ship-gate tests, diagnostics, or observability expectations

## Workflow

1. Establish the current graph baseline before creating anything:

   ```bash
   br list --limit 0 --json -a
   bv --robot-triage
   bv --robot-plan
   bv --robot-search --search "..."    # optional overlap check
   ```

2. Build a coverage map using [references/coverage-matrix-template.md](references/coverage-matrix-template.md). Include:
   - primary user workflows
   - admin/operator workflows
   - failure, retry, and recovery paths
   - constraints, non-goals, and security boundaries
   - migrations, rollout, docs, and compatibility work when the plan calls for them
   - verification obligations: unit, integration/e2e, logging, diagnostics, observability
3. Choose the graph shape before typing `br create`:
   - use epics only for real umbrella surfaces or architectural slices
   - use tasks for independently claimable work packets
   - use subtasks only when they sharpen sequencing instead of hiding it
   - when one plan concept fans out into multiple deliverables, choose a canonical root bead that carries the full why/constraints/test story and let dependents carry the local details they need
**Start the replay manifest before step 4, and keep it current.** Steps 4 and 7 write
beads and auto-flush, so by step 9 the damage may already be done; recovery discards the
working JSONL before you could read the generated ids back off it. One line per intended
`br` command, complete enough to re-run verbatim, appended as each id is assigned. The
coverage matrix maps plan elements to beads — it does not preserve ids, field values, or
order.

4. Create or update actual beads only with `br`.
5. Write each material bead so it is self-contained. Use [references/bead-description-template.md](references/bead-description-template.md), and elaborate beyond the source plan whenever that removes ambiguity.
6. Preserve important intent, not just surface tasks:
   - why the bead exists
   - what changes for users, operators, or the system
   - critical boundaries and non-goals
   - failure handling or recovery obligations
   - decisive tests and diagnostics
   - gotchas a future agent would otherwise rediscover
7. Add explicit dependencies with `br dep add`. Optimize for correctness and a healthy ready frontier; over-constraining the graph slows the swarm.
8. Run the transfer audit in both directions:
   - plan -> beads: every important plan element lands somewhere
   - beads -> plan: every bead has clear backing in the plan or an explicitly approved delta
   - if the audit feels suspiciously short or self-satisfied, assume coverage is incomplete and rerun more exhaustively
9. Split, merge, rewrite, or close beads until the graph can stand on its own as executable memory.
10. Flush with an **explicit** `br sync --flush-only` and require it to succeed:

    ```bash
    br sync --flush-only || { echo "flush failed — mutations not persisted"; exit 1; }
    ```

    The explicit sync propagates a real exit code, which the *automatic* flush after each
    `br` mutation does not — it swallows its error and leaves the JSONL unwritten. The
    mutation is still in the shared DB, so this sync either writes it or fails loudly. A
    re-run whose graph already matches the plan syncs cleanly and writes nothing; that is
    a no-op, not a failure.

    **A flush also writes the cache over the file.** The sync proves your mutation
    persisted; it does not tell you what else it overwrote. Every `br` write re-exports
    *all* beads from the gitignored `.beads/beads.db`, so a body the cache holds a stale
    copy of is reverted — silently, exit 0. Transferring a plan means writing long
    specification bodies, and pasting one into `.beads/issues.jsonl` by hand is precisely
    what makes the cache stale: a hand edit does not advance `updated_at`, so the two
    become indistinguishable by timestamp. Write every body through `br update -d/--notes`,
    rerun the resolver-locator block above,
    stopping before its final clean-mode `BEADS_JSONL=` call, and resolve the post-write
    path with
    `BEADS_JSONL=$("$BEADS_JSONL_RESOLVER" --allow-dirty) || exit 1` before field-diffing it
    (the transfer you just wrote is the divergence the default mode refuses; `.beads/` is
    only the default layout, and a hardcoded path diffs nothing on the others) — ids on
    only one side, or a
    `description` you did not touch, is the tell. Recovery, and why `br sync --import-only`
    cannot do it, is in
    [exact companion skill `rb-lite-backlog-drain`, step 11](../rb-lite-backlog-drain/SKILL.md#backlog-step-11) — but note
    its replay step assumes a SINGLE mutation, the drain's case. A transfer has a whole
    graph in flight, so enumerate the complete intended delta (the replay manifest you started before step 4 —
    NOT the coverage matrix, which maps plan elements to beads and preserves no ids, field
    values or ordering) before restoring — and restore from the source you established holds the good bodies,
    which is not automatically `HEAD`: if the index holds the last good export and HEAD
    an older one, `git checkout HEAD --` overwrites the good staged copy too. Step 11
    requires that choice explicitly; make it there rather than assuming.
11. If the repo workflow supports it, run `br lint` after major rewrites to catch missing sections.

## Quality bar

A transfer is good only when a fresh agent can claim a bead and execute correctly without improvising architecture.

Each material bead should make these obvious:

- the intended outcome
- the reason it exists
- its scope and non-goals
- ordering assumptions and true dependencies
- failure handling, rollout, or operator hooks when relevant
- exactly how the result will be verified

## Hard failure modes

Do not:

- collapse a rich plan into terse TODOs
- omit tests or observability because they seem "obvious"
- recreate work that already exists in the graph
- leave critical context only in the original plan
- hide sequencing in prose while leaving dependencies implicit
- silently invent architecture that the plan never settled

## Command palette

```bash
br list --limit 0 --json -a
br search "query" -a --json
br show <id> --json
br create "Title" --type task --priority 2 --description "..."
br create "Epic" --type epic --priority 1 --description "..."
br create "Subtask" --parent <epic-id> --priority 2 --description "..."
br update <id> --description "..."
br dep add <issue> <depends-on>
br close <id> --reason "..."
br lint
bv --robot-triage
bv --robot-plan
bv --robot-search --search "query"
br sync --flush-only
```

## Pipeline position

This is the first step in the bead lifecycle:

1. `plan-to-beads-transfer`
2. `bead-polish-loop`
3. `second-model-bead-audit`

Run `bead-polish-loop` after almost every non-trivial transfer. Normal polish
completion now includes the `second-model-bead-audit` reviewer-panel gate before
implementation; do not reserve that audit only for high-stakes graphs.
