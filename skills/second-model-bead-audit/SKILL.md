---
name: second-model-bead-audit
description: Audits a bead graph against the plan with an independent second opinion, checking coverage gaps, duplicate ownership, weak descriptions, dependency mistakes, and missing verification obligations before implementation starts. Use when another agent already created or polished the beads and you want a launch verdict with exact fixes. Prefer read-only review unless the user explicitly asks for bead edits.
compatibility: Requires br and bv on PATH and a repo that uses .beads/.
---

Provide a second-model audit of the bead graph without inheriting the first
model's blind spots.

## Default posture

Stay in read-only audit mode unless the user explicitly asks you to apply fixes.

## Use this skill when

- Claude or another agent already created/refined beads and the user wants Codex or another model to review them
- the project is important enough that a second-model check is worth the time
- the graph feels plausible but you want an independent launch verdict

## Do not use this skill when

- there is no real bead graph yet
- the user wants implementation instead of review
- the request is actually a planning task, not a bead audit

## Required outputs

1. A launch verdict: fail, conditional pass, or pass.
2. A structured report with blocking findings first.
3. Exact bead-level fixes or proposed `br` actions where possible.
4. Clear distinction between hard blockers, important improvements, and optional nits.

## Workflow

1. Reread `AGENTS.md`, then read the relevant plan/spec and current bead graph.
2. Ground in reality:
   - `br list --limit 0 --json -a`
   - `bv --robot-triage`
   - `bv --robot-plan`
   - `bv --robot-suggest`
   - optionally `bv --robot-insights`, `bv --robot-priority`, and `br show <id> --json`
3. Re-derive the judgment independently. Do not assume the existing graph is correct because another strong model made it.
4. Audit the graph across these categories:
   - plan coverage
   - duplicate or overlapping ownership
   - vague or under-specified beads
   - dependency correctness and frontier health
   - priority and sequencing fit
   - verification obligations, including unit/integration/e2e and useful diagnostics where relevant
   - user-visible and operator-visible risks that are still unowned
5. Use the template in [references/review-report-template.md](references/review-report-template.md).
6. If you are asked to apply fixes, mutate only the clearly justified ones with `br`, then flush with `br sync --flush-only`.

## Review standards

A good audit is not a rubber stamp. It should be willing to say:

- the graph is missing work even though it looks large
- two beads should merge even though their titles differ
- one bead is overloaded and should split
- the graph is not launch-ready because testing or failure-handling is still implicit

## Command palette

```bash
br list --limit 0 --json -a
br show <id> --json
bv --robot-triage
bv --robot-plan
bv --robot-suggest
bv --robot-insights
bv --robot-priority
```

## Common failure patterns to avoid

- praising the graph without independently checking plan coverage
- nitpicking style while missing missing-work risks
- collapsing all findings into one severity bucket
- suggesting implementation changes when the graph itself is the problem
- editing beads by default when the user asked for a review

## Additional resources

- For the report structure, see [references/review-report-template.md](references/review-report-template.md).
