---
name: second-model-bead-audit
description: >-
  Runs the default final launch-readiness audit for a polished bead graph against
  its plan. A read-only two-reviewer panel (Codex gpt-5.6-sol at xhigh plus Claude
  Fable at high effort) independently checks coverage, ownership, bead quality,
  dependencies, priority, verification, and operational obligations; the
  orchestrator merges and reconciles their findings into one verdict. Use after
  bead-polish-loop by default, or when the user asks to sanity-check, audit, get a
  second opinion on, or approve beads before implementation. Prefer read-only
  review unless the user explicitly asks for bead edits.
argument-hint: "[plan/spec path] [--reviewers codex|fable|codex,fable]"
compatibility: >-
  Requires br, bv, jq, SHA-256 tooling (sha256sum or shasum), and GNU timeout
  (timeout or gtimeout) on PATH, plus a repo that uses .beads/. The full default
  panel also requires authenticated codex and claude CLIs. One available reviewer
  produces a DEGRADED audit; if no requested reviewer can run, the audit is
  BLOCKED.
---

# second-model-bead-audit

Give the polished bead graph a fresh, adversarial launch-readiness check before
implementation starts.

This is still called a second-model audit because at least one panel member should
be independent of the model lineage that built and polished the graph. The default
is now a panel, not one hand-picked alternate model: two independent reads expose
both shared findings and useful disagreements, and avoid making graph authorship a
prerequisite for choosing the reviewer.

## Default posture

- Run this audit after every non-trivial `bead-polish-loop`, not only for
  high-stakes launches.
- Keep the panel read-only. It reports exact fixes; `bead-polish-loop` owns normal
  graph mutation.
- Run both reviewers independently and in parallel. Never seed one with the
  other's findings or with your own conclusions.
- Treat panel findings as hypotheses to verify, not commands to obey.
- Do not proceed to implementation on `FAIL` or `CONDITIONAL PASS`. Resolve and
  re-audit every accepted condition first; any graph edit invalidates the old
  verdict.

The user may explicitly opt out for a tiny or low-risk graph. Record the skipped
gate rather than silently treating the polisher's own convergence judgment as an
independent audit.

## Inputs

Parse `--reviewers <list>` first. Valid values are `codex`, `fable`, and
`codex,fable`; the default is both. A user-pinned one-reviewer audit is a
`PINNED PANEL`, not an availability failure, but it still lacks full-panel
agreement.

The remaining argument is the plan/spec path. If it is absent, discover the
relevant plan from the beads' spec refs and repo docs. Ask only when multiple
plausible source plans would materially change the coverage audit.

## Tool dependencies and panel health

The graph audit itself requires `br`, `bv`, `jq`, SHA-256 tooling (`sha256sum` or
`shasum`), and GNU `timeout` (`timeout` or `gtimeout`). If any is missing, stop
and tell the user. If their commands fail unexpectedly, flag a likely CLI-version
mismatch rather than inventing alternate syntax.

The default panel is:

| Reviewer | Invocation | Role |
|---|---|---|
| `codex` | `codex exec`, `gpt-5.6-sol`, `model_reasoning_effort="xhigh"`, read-only sandbox | Independent plan/graph audit with a custom rubric |
| `fable` | `claude -p`, `--model fable --effort high`, read-only tool set | Independent plan/graph audit with the same rubric |

`jq` is used to build the common graph snapshot and unwrap the Claude JSON result.

- Both healthy: `FULL PANEL`.
- One missing, unauthenticated, timed out, or unusable: continue with the survivor
  and label the audit `DEGRADED`.
- No requested external reviewer runs successfully: `BLOCKED`. Do not silently
  replace the panel with the coordinating agent's self-review.
- A user-pinned reviewer that runs successfully: `PINNED PANEL`.
- Never turn an empty, truncated, ambiguous, or failed reviewer response into a
  clean vote.

Exact prompts, invocations, log layout, clean detection, and recovery rules live
in [references/reviewer-panel.md](references/reviewer-panel.md). Read that file
before launching the panel.

## Independence from the graph

Panel health and graph independence are different claims. Report both.

Determine who built or substantially polished the graph from session context or
`br show <id> --json` actor/history fields when practical. Do not delay the audit
just to establish authorship.

For each reviewer, label independence:

- `INDEPENDENT`: a different model family from the graph's builder/polisher.
- `BUILDER-LINEAGE`: the same model family; useful corroboration, but not the
  second opinion.
- `UNKNOWN`: graph authorship could not be established.

With a Codex-built graph, Fable supplies the independent vote; with a Claude-built
graph, Codex does. When authorship is mixed or unknown, the two-reviewer panel is
still stronger than guessing which single auditor to invoke.

## Required outputs

1. Launch verdict: `FAIL`, `CONDITIONAL PASS`, or `PASS`; `NONE` when panel
   health is `BLOCKED`.
2. Audit quality: `FULL PANEL`, `DEGRADED`, `PINNED PANEL`, or `BLOCKED`.
3. Panel roster, model settings, exit health, and independence labels.
4. One merged report with blockers first and every finding tagged `BOTH`,
   `CODEX`, `FABLE`, or `CONFLICT`.
5. Exact bead-level fixes or proposed `br` actions where they are safe to state.
6. Disagreements and contradictions, plus the plan section or bead evidence that
   settled them.
7. Paths to the raw reviewer outputs and merged report.

A semantic `PASS` from a degraded or pinned audit must retain that quality label,
for example `PASS (DEGRADED)`. Only a healthy full panel can produce an
unqualified `PASS`. If no reviewer is `INDEPENDENT` from the known graph lineage,
also append `NO INDEPENDENT VOTE` to any pass label. A blocked audit produces no
launch verdict.

Only an unqualified `PASS` clears the gate automatically. A qualified pass
requires either a later healthy full-panel pass or the user's explicit,
recorded acceptance of the reduced review coverage.

## Workflow

### 1. Preflight and shared scope

1. Read `AGENTS.md`, `README.md`, the relevant plan/spec, and any graph-specific
   guidance.
2. Confirm the graph is meaningful and has already had a real polish pass. If it
   is raw, redirect to `bead-polish-loop`; the final gate should not substitute for
   routine cleanup.
3. Confirm `br`, `bv`, the requested reviewer CLIs, and `jq` as applicable.
4. Define the audit scope explicitly:
   - authoritative plan/spec files, approved deltas, and recorded waivers
   - plan-backed root beads/epics and their child/dependency closure
   - the wider graph only for cross-scope dependencies and frontier health

   Do not label unrelated backlog beads as unplanned merely because
   `br list -a` includes them.
5. Flush once, capture one shared baseline, and fingerprint it before launching
   either reviewer:

   ```bash
   br sync --flush-only && git diff --stat -- '*.beads/*.jsonl'   # must be non-empty
   br list --limit 0 --json -a
   bv --robot-triage
   bv --robot-plan
   bv --robot-suggest
   ```

   Add `bv --robot-insights`, `bv --robot-priority`, and targeted
   `br show <id> --json` when useful.
6. Create a unique audit directory and one neutral prompt containing the
   snapshotted requirement and graph paths, audit scope, categories, severity
   rules, and output contract. Do not include your conclusions or prior polish
   findings.

### 2. Run the panel

Start Codex and Fable in parallel with the same prompt. Close stdin on both batch
commands, persist stdout/stderr separately, and bound hangs when `timeout` is
available.

The panel audits:

- plan-to-bead and bead-to-plan coverage
- duplicate or overlapping ownership
- vague, overloaded, undersized, or under-specified beads
- dependency direction, cycles, bottlenecks, and ready-frontier health
- priority and sequencing fit
- unit, integration/e2e, acceptance, and regression obligations
- logging, diagnostics, rollout, recovery, and operator-visible obligations
- scope growth or beads with no plan backing

Each reviewer must cite plan sections and bead IDs, propose bead-level remedies,
and state `No findings.` explicitly when clean.

Before parsing or merging findings, recompute the graph and requirement-source
fingerprints. Any drift during the panel invalidates every vote: report
`BLOCKED`, preserve the evidence, do not reset user state, and rerun only from a
stable new snapshot. Also reject contradictory or truncated reviewer output as
ambiguous rather than treating the presence of any finding tag as a usable audit.

### 3. Merge and reconcile

Merge on the underlying claim, not wording:

- `BOTH`: both reviewers found the same issue.
- `CODEX` / `FABLE`: only that reviewer found it.
- `CONFLICT`: one asserts a problem and the other explicitly says the same graph
  shape is correct.

Agreement increases confidence and review order; it does not replace verification.
Silence from the other reviewer is not counter-evidence. For every contradiction,
read the cited plan and beads yourself, decide with citations, and record which
reviewer was right.

Reject a finding only with concrete plan, bead, or graph evidence. If a proposed
fix adds work not required by the plan or a real delivery/verification risk,
record it as out of scope rather than expanding the graph reflexively.

Use [references/review-report-template.md](references/review-report-template.md)
for the synthesis.

### 4. Decide the verdict

- `FAIL`: any blocking coverage, ownership, dependency, execution, or verification
  defect remains.
- `CONDITIONAL PASS`: no blocker, but one or more named important conditions must
  be fixed before the intended launch shape is safe.
- `PASS`: no blocking or important findings remain; optional nits may remain.

Reviewer verdict votes are evidence, not a majority election. The orchestrator
owns the final verdict and must explain any departure from either vote.

### 5. Handoff and re-audit

Normal mode is report-only:

- `PASS`: proceed to implementation.
- `CONDITIONAL PASS` or `FAIL`: send accepted findings into
  `bead-polish-loop`'s ledger, fix them there, then rerun the full panel.

If the user explicitly asks this skill to apply fixes, mutate only reconciled,
clearly justified items with `br`, flush with `br sync --flush-only`, and rerun the
panel before upgrading the verdict. Never let a reviewer edit the graph directly.

Bound an automatic polish/audit cycle to three panel runs. Stop earlier when the
same material finding survives two genuine fix attempts, the graph drifts during
review, reviewer health is blocked, or an architecture/product decision is
required. Surface the remaining issue instead of recursively invoking the two
skills forever.

Stop and ask for a product/architecture decision when a finding exposes ambiguity
in the plan rather than a bead-quality defect.

## Command palette

```bash
br list --limit 0 --json -a
br show <id> --json
br update <id> --description "..."
br close <id> --reason "..."
br dep add <issue> <depends-on>
br dep remove <issue> <depends-on>
br lint
bv --robot-triage
bv --robot-plan
bv --robot-suggest
bv --robot-insights
bv --robot-priority
br sync --flush-only
```

## Failure patterns to avoid

- choosing only the presumed alternate model when both reviewers are available
- running reviewers sequentially or showing one the other's conclusions
- giving reviewers the polish findings and creating an echo chamber
- calling a one-reviewer, failed, empty, or ambiguous panel an unqualified pass
- counting reviewer votes instead of reconciling claims against the plan and graph
- dismissing a single-source finding because the other reviewer stayed silent
- letting either reviewer mutate beads
- nitpicking wording while missing absent work, dependency errors, or test gaps
- expanding the graph for speculative hardening with no plan or delivery need

## Pipeline context

This is the default final gate in the bead lifecycle:

1. `plan-to-beads-transfer` — create executable memory from a stable plan.
2. `bead-polish-loop` — iteratively refine the graph.
3. `second-model-bead-audit` — run the read-only reviewer panel and issue the
   launch verdict.

The gate is part of normal completion, not an optional high-stakes add-on. A
failed or conditional audit loops back to polishing and then through this gate
again.
