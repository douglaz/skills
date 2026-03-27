---
name: bead-polish-loop
description: Refines an existing bead graph through repeated review-and-revise rounds for coverage, deduplication, dependency repair, sizing, priority, and verification completeness until the graph converges. Use when a bead batch already exists but still feels vague, duplicated, over-broad, or dependency-wrong. Do not use for first-draft planning or ordinary code review.
compatibility: Requires br and bv on PATH and a repo that uses .beads/.
---

Polish the bead graph until it is launch-ready, not just plausible.

## Use this skill when

- a fresh batch of beads was just created from a plan
- a large feature slice was added to an existing graph
- the graph feels vague, duplicated, over-broad, or dependency-wrong
- you want to improve the graph before implementation starts

## Do not use this skill when

- the project still needs plan-level work more than bead-level work
- the user is asking for implementation rather than graph refinement
- there are no meaningful beads yet to inspect

## Required outputs for each invocation

1. A refined bead graph, with actual `br` updates when changes are justified.
2. A concise round report: what changed, what remains risky, and whether to continue.
3. A convergence judgment: major-change mode, refinement mode, or near-converged.

## Recommended loop shape

- small projects: at least 3 full rounds
- normal projects: 4 to 6 rounds
- high-stakes work: keep going while fresh rounds still find meaningful issues

Do not stop because you hit a number. Stop because the changes became small,
local, and mostly corrective.

## Per-round workflow

1. Reread `AGENTS.md`, then load the current graph and relevant plan/spec.
2. Establish a baseline:
   - `br list --limit 0 --json -a`
   - `bv --robot-triage`
   - `bv --robot-plan`
   - `bv --robot-suggest`
   - optionally `bv --robot-insights` and `bv --robot-priority`
3. Run these passes in order.

### Pass A. Duplicate and overlap detection

- look for exact duplicates, near-duplicates, and beads with heavily overlapping ownership
- prefer one canonical survivor when two beads are effectively the same job
- use [references/dedupe-heuristics.md](references/dedupe-heuristics.md)

### Pass B. Coverage audit

- check plan -> beads and beads -> plan
- make sure every workflow, constraint, failure path, and verification obligation still lands somewhere
- split or add beads if coverage is thin

### Pass C. Quality rewrite

Score material beads with [references/polish-rubric.md](references/polish-rubric.md). Rewrite low-scoring beads so they become self-contained and testable.

### Pass D. Dependency and launchability repair

- fix missing, reversed, or over-constraining dependencies
- inspect for cycles, bottlenecks, and unhealthy ready-frontier shape
- prefer a graph that allows multiple independent agents to proceed safely

### Pass E. Test and observability completeness

Make sure the graph names how work will be verified. If the project is
user-facing or operationally sensitive, insist on explicit unit and integration/e2e
obligations and useful logging or diagnostics.

### Pass F. Sizing and priority cleanup

- split oversized beads that hide multiple deliverables
- merge tiny beads only when the merge sharpens execution rather than blurring it
- tighten priority where the graph and plan disagree

4. Apply only justified changes with `br`.
5. Flush mutations with `br sync --flush-only`.
6. Record a round summary:
   - beads added, rewritten, merged, closed, or reprioritized
   - major risks still open
   - whether another round is warranted
7. Score convergence with [references/convergence-scorecard.md](references/convergence-scorecard.md).

## Stop conditions

Prefer to stop when most of these are true:

- no major uncovered plan elements remain
- no obvious duplicate or near-duplicate beads remain
- no dependency anomalies block understanding of the frontier
- low-quality beads are now rare and localized
- two consecutive rounds make only small, corrective edits
- convergence score is high enough that another round is likely low yield

## Escalation rules

- If the graph keeps expanding, step back into plan space.
- If the graph oscillates between two shapes, reframe the decomposition instead of polishing forever.
- If the current session stops finding subtle issues, start a fresh session and rerun this skill.
- For a final independent check, hand the graph to the `second-model-bead-audit` skill.

## Command palette

```bash
br list --limit 0 --json -a
br show <id> --json
br update <id> --description "..."
br close <id> --reason "merged into ..."
br dep add <issue> <depends-on>
br dep remove <issue> <depends-on>
bv --robot-triage
bv --robot-plan
bv --robot-suggest
bv --robot-insights
bv --robot-priority
br sync --flush-only
```

## Common failure patterns to avoid

- polishing only titles while leaving descriptions vague
- deduplicating solely by title similarity
- changing priorities without checking graph impact
- assuming a big graph is complete because it is verbose
- oversimplifying and silently deleting functionality or test obligations
- treating the first decent pass as final

## Additional resources

- For scoring bead quality, see [references/polish-rubric.md](references/polish-rubric.md).
- For convergence decisions, see [references/convergence-scorecard.md](references/convergence-scorecard.md).
- For dedup rules, see [references/dedupe-heuristics.md](references/dedupe-heuristics.md).
