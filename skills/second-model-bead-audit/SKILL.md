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
   health is `BLOCKED`. State whether the § 3b coherence pass was run and what it
   found — a verdict on text nobody read end to end is worth less than it looks.
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
   # An explicit sync propagates a real exit code, so require success. (Only the automatic
   # post-mutation flush swallows its error.) An unchanged graph legitimately reports no
   # diff, so do not also demand that the JSONL changed here.
   # A flush writes the whole gitignored beads.db cache over the tracked issues.jsonl, so
   # any bead body hand-edited into the file (which does not advance updated_at) is
   # silently reverted here — exit 0, no warning. `git diff .beads/issues.jsonl` after
   # this and check the field-level changes before capturing a baseline: an audit over a
   # truncated graph reviews text the reviewers will never see. See
   # ../orchestrating-with-rb-lite/SKILL.md step 11 for recovery.
   br sync --flush-only || { echo "flush failed"; exit 1; }
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
commands, persist stdout/stderr separately, and bound hangs with GNU `timeout`, which is
**required** — the prerequisites say to stop if it is missing, and the reference's snippet
`exit 1`s rather than run an unbounded panel.

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

### 3b. The coherence pass — read each bead end to end

Every panel round re-reads the beads, which sounds like it should catch anything. It
does not catch the defect class that a *long* loop creates: an edit that is correct
where it lands and falsifies a claim three sections away. Bead text is prose with
internal cross-references, so each fix is also a chance to contradict something the
bead already said.

**Entry:** the panel came back clean, OR you have applied fixes across two or more
rounds. The second trigger is the important one — do not wait for a clean panel to
check coherence, because incoherence is what keeps the panel from going clean.

**How, and this is the whole point: read, do not grep.** Open each bead's full text
and read it top to bottom, in order, as an implementer would. Targeted edits at cited
line numbers are what introduced the drift; more targeted edits will not find it. If
you catch yourself grepping for the phrase a reviewer quoted, you are repeating the
mistake.

Check, per bead and then across the set:

- **Title against scope.** A bead retitled or rescoped mid-loop often keeps its
  original first sentence, which is the line an implementer reads first.
- **Requirements against each other.** A decision made in one requirement can be
  forbidden by another written two rounds earlier.
- **Requirements against ACs.** The commonest failure: the prose is fixed and the AC
  that asserts the opposite survives, because the reviewer quoted the prose.
- **Both against the authority docs.** An ADR amended mid-loop leaves beads citing
  what it used to say — and beads that widened a rule the ADR never granted.
- **Work-already-done sections.** "On merge, also amend X" is stale once X is amended.
- **Superseded instructions.** "Delete the glossary entry for Y" is wrong once Y has
  been replaced rather than removed.
- **Counts, inventories and file lists.** These go stale silently and are cheap to
  re-derive. Re-measure them; do not carry them forward. A count that was true two
  rounds ago reads exactly like one that is true now.
- **Across the set:** every cross-bead dependency rationale. A bead that says "depends
  on X because Y" is wrong the moment X's own text stops claiming Y.

Fix by **re-authoring the bead** when the contradictions are structural rather than
local. A bead carrying half a dozen of them has been patched past the point where
patching converges; rewriting it from the settled decisions is faster and leaves
something an implementer can follow.

Then re-run the panel. A coherence fix is a graph change like any other.

**Why this is a phase and not advice.** Observed on a three-bead money-path set: four
panel rounds, findings *rising* each round, because most were the orchestrator's own
partial fixes coming back. One coherence pass found eleven contradictions in a single
bead — including its own title contradicting its scope, an AC demanding exactly what a
requirement forbade, and a smoke-conversion count wrong by a factor of two — and
resolved more than the previous two rounds combined. `multi-reviewer-loop` § 4b makes
the same argument for diffs; bead graphs need it more, because prose has no compiler.

- `FAIL`: any blocking coverage, ownership, dependency, execution, or verification
  defect remains.
- `CONDITIONAL PASS`: no blocker, but one or more named important conditions must
  be fixed before the intended launch shape is safe.
- `PASS`: no blocking or important findings remain; optional nits may remain, AND
  § 3b has been run on the current text. A panel can only see what it was asked to
  look at; a bead that contradicts itself can pass every round, because each reviewer
  reads the section it was pointed at. Do not issue `PASS` on a set that has been
  edited across rounds without a coherence pass over it.

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

**When findings RISE across rounds, suspect your own fixes before the graph.** A
panel that returns more blockers than last time is usually not finding new defects —
it is finding the contradictions the last round's edits introduced. Two tells: the
same finding returns in new wording after you "fixed" it, and reviewers begin citing
your own text against itself. Neither is answered by another round. Run § 3b, then
re-panel.

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
