---
name: bead-polish-loop
description: >-
  Refine an existing bead graph through repeated review-and-revise rounds until
  it converges into audit-ready executable memory with strong coverage,
  deduplication, dependency shape, sizing, priority, and verification detail.
  Use when beads already exist but feel vague, duplicated, over-broad,
  dependency-wrong, or under-tested; when a large transfer from a markdown plan
  just landed; when a plan revision likely introduced graph drift; or when the
  user asks to clean up, tighten, review, or launch-ready the beads. Do not use
  for first-draft planning, direct implementation, or repos that do not yet have
  meaningful beads to inspect. Normal completion hands the converged graph to the
  second-model-bead-audit reviewer panel before implementation.
---

Polish the bead graph until it is ready for the independent launch gate, not
merely plausible.

## Core invariants

- Check beads many times, implement once.
- Preserve functionality and intent; do not oversimplify away features, constraints, or verification.
- Optimize for fungible agents: clear beads, correct dependencies, and a healthy ready frontier for parallel work.
- Stop on convergence, not on an arbitrary round count.
- Treat convergence as readiness for the independent audit, not permission to skip it.

## Preflight

- Confirm `br`, `bv`, and the exact `beads-jsonl-path` companion are available. The
  companion diagnoses its own host dependencies, including `jq`; if it cannot resolve
  and prove a clean tracked JSONL, do not write to the graph.
- Record whether `codex` and `claude` are available for the final reviewer panel.
  Missing panel tools do not block polishing, but they determine whether the eventual
  audit can be full, degraded, or blocked.
- Re-read `AGENTS.md`, `README.md`, and the relevant plan/spec before editing the graph.
- If there are no meaningful beads yet, redirect to `plan-to-beads-transfer`.
- If polishing keeps surfacing architecture questions, step back into plan space instead of repeatedly fixing downstream symptoms.


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
# is whatever executable the repo you are polishing planted there, and this snippet would
# run it. From a checkout, run that checkout's copy by absolute path instead.
[ -n "$BEADS_JSONL_RESOLVER" ] || {
  echo "beads-jsonl-path companion unavailable — do NOT write" >&2
  exit 1
}
BEADS_JSONL=$("$BEADS_JSONL_RESOLVER") || exit 1
```

If the owner refuses, resolve the reported state first — recovery case (a) in
exact companion skill [`rb-lite-backlog-drain`, step 11](../rb-lite-backlog-drain/SKILL.md#backlog-step-11).
**Companion unavailable: stop, rerun the same installer command once, reload it, and do
not improvise this procedure.**
After the first flush the choice
is gone.

## Session shape

- Expect 2-3 serious polish passes per session before context quality drops.
- Treat that as a per-session limit, not a convergence target.
- Run multiple sessions for non-trivial graphs.
- If improvements flatline or the current session feels anchored to stale assumptions, start fresh, reread the context, and do a fresh-eyes pass.

## Pass budget and coverage gates

Plan a minimum pass budget before editing:

- tiny graph: at least 3 rounds
- normal graph: at least 4 rounds
- large or launch-critical graph: at least 5 rounds and one fresh-session pass

Do not declare convergence before all of these are true:

- the minimum round budget for the graph size is met
- every epic was inspected at least once
- every `P0` and `P1` bead was inspected at least once
- every bead on the critical dependency path was inspected at least once
- every important unresolved finding is either fixed or explicitly waived with a reason

Convergence ends the polishing phase. It does not complete the bead lifecycle:
run `second-model-bead-audit` by default after the graph meets these gates.

## Per-round workflow

1. Establish the baseline:

   ```bash
   "$BEADS_JSONL_RESOLVER" --run-br list --limit 0 --json -a
   bv --robot-triage
   bv --robot-plan
   bv --robot-suggest
   ```

   Optionally add `bv --robot-insights`, `bv --robot-priority`, or `bv --robot-diff --diff-since <ref>` when the graph is large or you need a precise delta since the last round.

2. Build a findings ledger before round 1 and keep updating it every round. Track at least:
   - uncovered plan elements
   - duplicate or overlap suspects
   - low-rubric beads
   - dependency anomalies
   - weak verification or observability obligations
   - any `P0`/`P1`, epic, or critical-path beads not yet reviewed

3. Run these passes in order.

### Pass A. Detect duplicates and overlap

- Look for exact duplicates, near-duplicates, and beads with heavily overlapping ownership.
- Pick one canonical survivor when two beads are effectively the same job.
- Use [references/dedupe-heuristics.md](references/dedupe-heuristics.md).

### Pass B. Audit coverage against the plan

- Walk the plan against the beads and the beads against the plan.
- Check both open and closed beads when that helps explain where obligations landed.
- Make sure workflows, constraints, failure paths, and verification obligations still survive in the graph.

### Pass C. Rewrite low-quality beads

- Score material beads with [references/polish-rubric.md](references/polish-rubric.md).
- Rewrite low-scoring beads until a fresh agent can execute without guessing.
- Preserve rich why/constraints/failure/test context instead of shortening for style.

### Pass D. Repair dependencies and launchability

- Fix missing, reversed, or over-constraining dependencies.
- Inspect for cycles, bottlenecks, and unhealthy ready-frontier shape.
- Prefer a graph that allows multiple independent agents to proceed safely.

### Pass E. Tighten verification and operational trust

- Require explicit unit, integration/e2e, or equivalent verification where relevant.
- Require logging, metrics, diagnostics, or operator surfaces when the work is user-facing or operationally sensitive.
- Refuse beads whose acceptance path is still "someone will know it when they see it."

### Pass F. Clean up sizing and priority

- Split oversized umbrella beads that hide multiple deliverables.
- Merge tiny beads only when the merge sharpens execution instead of blurring it.
- Reconcile priority with graph reality so critical blockers are obvious.

4. Write the replay manifest **before** applying anything — one line per intended `br`
   command, verbatim and complete (ids, field values, order). Step 6's round summary is
   written after the flush and records decisions, not the commands; recovery discards the
   working JSONL before you could read them back off it. Then apply the changes with `br`.

5. Flush with an **explicit** `"$BEADS_JSONL_RESOLVER" --run-br sync --flush-only` and require it to succeed:

   ```bash
   "$BEADS_JSONL_RESOLVER" --run-br sync --flush-only || { echo "flush failed — mutations not persisted"; exit 1; }
   ```

   The explicit sync is the whole guard: the hazard is the *automatic* flush after a
   mutating `br` command swallowing its error, and the mutation is still in the shared DB,
   so this either writes it or fails loudly. A round that applied no changes syncs cleanly
   and reports nothing — a healthy convergence signal, not a failed flush.

   **But a flush writes the cache over the file.** The sync proves your mutation
   persisted; it does not tell you what else it overwrote. Every `br` write re-exports
   *all* beads from the gitignored `.beads/beads.db`, so a body the cache holds a stale
   copy of is reverted — silently, exit 0. Hand-editing `.beads/issues.jsonl` is what makes
   the cache stale (a hand edit does not advance `updated_at`, so the two are
   indistinguishable by timestamp), and this skill rewrites long bead bodies for a living,
   which is exactly when opening the file is tempting. Write bead text with
   `"$BEADS_JSONL_RESOLVER" --run-br update <id> --description "<full body>"`, rerun the resolver-locator block from Preflight,
   stopping before its final clean-mode `BEADS_JSONL=` call, and resolve the post-write path
   with
   `BEADS_JSONL=$("$BEADS_JSONL_RESOLVER" --allow-dirty) || exit 1` before field-diffing it
   (your own round is the divergence the default mode refuses; the `.beads/` layout is
   only the default, and a hardcoded path diffs nothing on the others): a full
   re-serialization with every id on both sides is normal, ids on only one side or a
   `description` you did not touch is the tell. Recovery — and why `"$BEADS_JSONL_RESOLVER" --run-br sync --import-only`
   cannot do it — is in
   [exact companion skill `rb-lite-backlog-drain`, step 11](../rb-lite-backlog-drain/SKILL.md#backlog-step-11), with one
   caveat: its replay step assumes a SINGLE mutation, the drain's case. A polish round
   batches several rewrites, so enumerate the complete intended delta (the step 4 replay manifest, NOT
   the step 6 round summary — the summary records decisions, not commands, ids or order) before restoring — and restore from the side you established holds the good bodies, not
   unconditionally from `HEAD`: when the index holds the last good export,
   `git checkout HEAD --` overwrites that staged copy too, discarding the very source you
   selected. Step 11 requires the choice explicitly; make it there.

6. Write a round summary:
   - beads added, rewritten, merged, closed, or reprioritized
   - findings ledger entries closed this round
   - findings ledger entries still open
   - whether another round is warranted
7. Score convergence with [references/convergence-scorecard.md](references/convergence-scorecard.md).

If the round summary is suspiciously short relative to the graph size, assume the pass was shallow and run another, more exhaustive pass.
If a round touches only a narrow subset of the graph, do not count it toward convergence until the untouched high-priority and critical-path areas are reviewed.

## Convergence model

Expect these phases:

- rounds 1-3: major fixes, wild swings, fundamental changes
- rounds 4-7: architecture and boundary refinement
- rounds 8-12: edge cases and nuanced handling
- rounds 13+: polishing toward steady state

Prefer to stop when most of these are true:

- no major uncovered plan elements remain
- no obvious duplicate or near-duplicate beads remain
- dependency anomalies are rare and localized
- low-quality beads are rare and localized
- every epic, `P0`/`P1`, and critical-path bead has been reviewed at least once
- the findings ledger is empty or only contains explicitly waived low-risk items
- two consecutive rounds make only small, corrective edits
- convergence score is at least `0.85` and nothing strategically important still feels weak

## Red flags and escalation

Stop and reframe instead of polishing harder if you see:

- oscillation between two decompositions
- graph growth that keeps adding complexity without clarifying ownership
- plateau at obviously low quality

Use these escalations:

- step back into plan space when the graph keeps expanding because the plan is still undecided
- restart in a fresh session when current assumptions feel sticky or compaction degraded context
- stop and ask for a decision when the graph exposes a real product or architecture ambiguity

## Default reviewer-panel gate

After convergence:

1. Flush the final graph with `"$BEADS_JSONL_RESOLVER" --run-br sync --flush-only`.
2. Invoke `second-model-bead-audit` with the source plan/spec path. Its default
   Codex + Claude panel is read-only and must not receive this skill's findings
   ledger or conclusions.
3. Handle the verdict:
   - unqualified `PASS`: polishing is complete; proceed to implementation.
   - `PASS (DEGRADED)` or `PASS (PINNED PANEL)`: do not proceed automatically.
     Rerun a healthy full panel, or obtain and record the user's explicit
     acceptance of the reduced review coverage.
   - `CONDITIONAL PASS`: add accepted conditions to the ledger, run a focused
     polish round, and re-audit before any implementation starts.
   - `FAIL`: reopen polishing, resolve blocking findings, and rerun the panel.
4. Preserve the audit quality label. A qualified pass is not equivalent to a
   healthy full-panel pass, and a blocked audit has no launch verdict.

The panel gate is the default for every non-trivial graph, not merely
launch-critical work. The user may explicitly opt out for tiny or low-risk work;
record that the gate was skipped. Do not count panel audits toward the minimum
polish-round budget, and do not let the read-only reviewers mutate beads.

Bound an automatic polish/audit cycle to three panel runs. Stop sooner if the same
material finding survives two genuine fix attempts, the graph changes while a
panel is reading it, reviewer health is blocked, or a product/architecture choice
is required. Report the remaining issue instead of recursively bouncing between
skills forever. Any graph mutation after an audit invalidates that verdict and
requires a new panel snapshot.

## Hard failure modes

Do not:

- treat 2-3 passes in one session as evidence that the graph is done
- polish only titles while leaving descriptions vague
- deduplicate solely by title similarity
- change priorities without checking graph impact
- assume a large graph is complete because it is verbose
- oversimplify and silently delete functionality or test obligations
- stop after the first pass that merely feels decent
- proceed directly to implementation after non-trivial polishing without running
  or explicitly waiving the reviewer-panel gate
- bias the audit by handing the panel this session's findings ledger

## Command palette

```bash
"$BEADS_JSONL_RESOLVER" --run-br list --limit 0 --json -a
"$BEADS_JSONL_RESOLVER" --run-br show <id> --json
"$BEADS_JSONL_RESOLVER" --run-br update <id> --description "..."
"$BEADS_JSONL_RESOLVER" --run-br close <id> --reason "..."
"$BEADS_JSONL_RESOLVER" --run-br dep add <issue> <depends-on>
"$BEADS_JSONL_RESOLVER" --run-br dep remove <issue> <depends-on>
"$BEADS_JSONL_RESOLVER" --run-br lint
bv --robot-triage
bv --robot-plan
bv --robot-suggest
bv --robot-insights
bv --robot-priority
bv --robot-diff --diff-since <ref>
"$BEADS_JSONL_RESOLVER" --run-br sync --flush-only
```

## Pipeline position

This is the second step in the bead lifecycle:

1. `plan-to-beads-transfer`
2. `bead-polish-loop`
3. `second-model-bead-audit`

Before using this skill, beads should already exist. After convergence, run
`second-model-bead-audit` as the normal final gate. Failed and conditional audits
loop back here with their accepted findings, then return to the panel.
