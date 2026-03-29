---
name: plan-to-beads-transfer
description: >-
  Converts a stable spec, PRD, or markdown plan into actual `br` beads with
  rich self-contained descriptions, explicit dependencies, and verification
  obligations. Use when a feature plan is approved and needs to become an
  execution graph, when the user says "break this plan into tasks", "create
  beads from this spec", "turn this into work items", "the plan is done, let's
  set up execution", or when a major plan revision means the bead graph must be
  refreshed. Do not use for implementation, loose brainstorming, or unstable
  architecture work.
compatibility: Requires br and bv on PATH and a repo that uses .beads/.
---

Turn a stable plan into executable beads without losing meaning.

## Tool dependencies

This skill requires `br` (beads_rust) and `bv` (bead viewer) on `PATH`.
If either command is missing, stop and tell the user. If commands fail with
unexpected errors, check whether the CLI version matches the expected subcommand
signatures in the command palette below — flag version mismatches to the user
rather than guessing at alternative syntax.

## Use this skill when

- a markdown plan or spec is already detailed enough to guide execution
- the user wants actual `br` beads, not pseudo-tasks in markdown
- a feature batch was approved and now needs a dependency-aware bead graph
- an existing plan changed enough that the bead graph must be refreshed

## Do not use this skill when

- the architecture is still actively undecided
- the work is tiny enough for an ephemeral TODO and should not become permanent project memory
- the user wants code written now instead of task graph setup
- the current request is really a plan-writing or idea-generation request

## Required outputs

1. Actual beads created or updated with `br`.
2. Explicit dependency links.
3. A short coverage report that maps plan areas to bead IDs.
4. A short note listing unresolved contradictions or questions, if any remain.

## Workflow

1. Reread `AGENTS.md`, the relevant plan/spec files, and any repo-local best-practices docs.
2. Decide whether the plan is translation-ready. If major workflows, constraints, failure paths, sequencing, or test expectations are still vague, stop and report plan gaps instead of creating brittle beads.
3. Ground in the current graph before creating anything new:
   - `br list --limit 0 --json -a`
   - `bv --robot-triage`
   - `bv --robot-plan`
   - optionally `bv --robot-search --search "..."` when checking overlap with existing work
4. Build a coverage map from the plan. Every material item should appear somewhere in the map:
   - user workflows and success paths
   - failure paths and operational flows
   - constraints and non-goals
   - migrations, compatibility edges, rollout details, or docs work if the plan calls for them
   - verification obligations: unit, integration, e2e, logging, observability
5. Choose the graph shape before creating beads:
   - epics for major user-visible surfaces or architectural slices
   - tasks for independently claimable work packets
   - subtasks only when they sharpen sequencing or reduce ambiguity
   - avoid giant umbrella beads that mix unrelated surfaces
6. Create or revise actual beads only with `br`. Do not leave pseudo-beads in markdown.
7. For each created or revised bead, make the description self-contained. Use the template in [references/bead-description-template.md](references/bead-description-template.md).
8. Add explicit dependencies with `br dep add`. Prefer dependencies that preserve a healthy ready frontier instead of over-constraining the graph.
9. Run a transfer audit in both directions:
   - plan -> beads: every important plan element lands somewhere
   - beads -> plan: every bead has a clear reason to exist in the plan or approved delta
10. Split, merge, rewrite, or close beads until the graph can stand on its own.
11. Flush the bead state with `br sync --flush-only` after mutations.

## Quality bar

A good transfer means a fresh agent can claim a bead and execute it without reopening the original plan just to understand the goal.

Each material bead should say:

- what outcome changes for the user, system, or operator
- why the work exists
- boundaries and non-goals
- dependencies or ordering assumptions
- how the result will be verified
- any critical gotchas the next agent would otherwise rediscover the hard way

## Command palette

```bash
br list --limit 0 --json -a
br create "Title" --type task --priority 2 --description "..."
br create "Epic" --type epic --priority 1 --description "..."
br create "Subtask" --parent <epic-id> --priority 2 --description "..."
br update <id> --description "..."
br dep add <issue> <depends-on>
bv --robot-triage
bv --robot-plan
bv --robot-search --search "query"
br sync --flush-only
```

## Common failure patterns to avoid

- collapsing a rich plan into terse TODOs
- omitting test or observability obligations because they are "obvious"
- creating duplicate beads without reading the existing graph first
- creating beads that only make sense if the original plan stays open nearby
- encoding sequencing in prose without explicit dependencies
- overusing parent/child depth when ordinary dependencies would be clearer

## Pipeline context

This skill is the **first step** in the bead lifecycle:

1. **plan-to-beads-transfer** (you are here) — create beads from a stable plan
2. **bead-polish-loop** — refine the graph through iterative review rounds
3. **second-model-bead-audit** — independent launch-readiness verdict

After completing a transfer, the graph is usually good enough to understand but
not yet launch-ready. Recommend `bead-polish-loop` as the next step unless the
transfer was small and clean. For high-stakes work, also recommend
`second-model-bead-audit` before implementation begins.

## Additional resources

- For the bead description structure, see [references/bead-description-template.md](references/bead-description-template.md).
- For the translation coverage pass, see [references/coverage-matrix-template.md](references/coverage-matrix-template.md).
