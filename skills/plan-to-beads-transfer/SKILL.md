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

- Confirm `br` and `bv` are on `PATH`. If either is missing, stop and say so.
- Re-read `AGENTS.md`, `README.md`, and every relevant plan/spec file before mutating the graph.
- If the session was compacted, or the plan changed materially since the last pass, reread before editing.
- Refuse the transfer if core workflows, boundaries, constraints, failure modes, sequencing, or verification are still unstable. Report plan gaps instead of encoding guesses into beads.

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
10. Flush with `br sync --flush-only` and require it to succeed — an explicit sync
    propagates a real exit code. Then confirm the JSONL actually changed, against a
    fingerprint taken **before** the transfer's mutations rather than against `HEAD`:
    a JSONL already dirty when you started stays dirty whether or not this transfer
    wrote anything, so the bare check cannot support the guarantee it claims.

    ```bash
    beads_fingerprint() {   # portable: macOS sort has no -z and BSD xargs has no -r
      git ls-files -co --exclude-standard -- '*.beads.jsonl' '.beads/*.jsonl' \
        | LC_ALL=C sort | while IFS= read -r f; do printf '%s ' "$f"; cksum < "$f"; done | cksum
    }
    BEFORE=$(beads_fingerprint)     # before step 1's br mutations
    br sync --flush-only || { echo "flush failed"; exit 1; }
    [ "$(beads_fingerprint)" != "$BEFORE" ] || { echo "transfer wrote nothing"; exit 1; }
    ```

    A transfer that created beads must report a change. A re-run whose graph already
    matches the plan legitimately reports none; that is a no-op, not a failed flush.
    The sync's exit code covers its own write; this check catches an auto-flush
    swallowed by an earlier `br` mutation.
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
