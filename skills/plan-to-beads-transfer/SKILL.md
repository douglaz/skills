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

- Confirm `br`, `bv`, **and `jq`** are on `PATH`. If any is missing, stop and say so.
  `jq` is load-bearing, not optional: every `br` write can silently revert other beads
  (step 10), and both the damage check and the recovery resolve the graph's real path
  through `br where --json | jq`. Without it a transfer can write a whole graph and then
  be unable to tell whether it destroyed one — the ordering that must not be possible.
  If `br where --json` cannot be parsed on this host, do not write to the graph.
- Re-read `AGENTS.md`, `README.md`, and every relevant plan/spec file before mutating the graph.
- If the session was compacted, or the plan changed materially since the last pass, reread before editing.
- Refuse the transfer if core workflows, boundaries, constraints, failure modes, sequencing, or verification are still unstable. Report plan gaps instead of encoding guesses into beads.


**Before the first `br` write, check the JSONL for divergence.** Any `br` mutation
auto-flushes the cache over the tracked file, so an unstaged hand-edit is erased by your
very first `br create`/`br update` — and because neither the index nor `HEAD` holds it,
every later diff shows only your intended changes and the loss is undetectable, let alone
recoverable. The window is open from the moment the session starts:

```bash
BEADS_JSONL=$(br where --json | jq -er '.jsonl_path') \
  || { echo "cannot resolve the beads JSONL path"; exit 1; }
git status --porcelain -- "$BEADS_JSONL"
```

Not empty? Resolve it now — see recovery case (a) in
[orchestrating-with-rb-lite](../orchestrating-with-rb-lite/SKILL.md) step 11 — before
writing anything. After the first flush the choice is gone.

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
    and field-diff the tracked JSONL before committing (resolve it with
    `br where --json | jq -r .jsonl_path`; `.beads/` is only the default layout, and a
    hardcoded path diffs nothing on the others) — ids on only one side, or a
    `description` you did not touch, is the tell. Recovery, and why `br sync --import-only`
    cannot do it, is in
    [orchestrating-with-rb-lite](../orchestrating-with-rb-lite/SKILL.md) step 11 — but note
    its replay step assumes a SINGLE mutation, the drain's case. A transfer has a whole
    graph in flight, so enumerate the complete intended delta (your coverage matrix is
    that list) before the `git checkout HEAD --`, or the restore discards every bead this
    transfer wrote along with the damage.
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
