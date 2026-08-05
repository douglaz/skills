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

- Confirm `br` and `bv` are on `PATH`. If either is missing, stop and say so.
- Record whether `codex`, `claude`, and `jq` are available for the final reviewer
  panel. Missing panel tools do not block polishing, but they determine whether
  the eventual audit can be full, degraded, or blocked.
- Re-read `AGENTS.md`, `README.md`, and the relevant plan/spec before editing the graph.
- If there are no meaningful beads yet, redirect to `plan-to-beads-transfer`.
- If polishing keeps surfacing architecture questions, step back into plan space instead of repeatedly fixing downstream symptoms.

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
   br list --limit 0 --json -a
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

4. Apply only justified changes with `br`.
5. Flush mutations with `br sync --flush-only` and require it to SUCCEED (`&&`, or check
   `$?`) — an explicit sync propagates a real exit code. The sync's own exit code covers
   its write; a JSONL check is what catches an *auto*-flush silently swallowed by the `br`
   mutations earlier in the round.

   Take that check against a **pre-round baseline**, not against `HEAD`. `git status
   --porcelain` compares the worktree with the last commit, so once the JSONL is dirty from
   an earlier round it stays dirty — and every later round then "confirms" a write it never
   made, which is exactly the swallowed auto-flush this is here to catch:

   ```bash
   beads_fingerprint() {   # portable: macOS sort has no -z and BSD xargs has no -r
     git ls-files -co --exclude-standard -- '*.beads.jsonl' '.beads/*.jsonl' \
       | LC_ALL=C sort | while IFS= read -r f; do printf '%s ' "$f"; cksum < "$f"; done | cksum
   }
   BEFORE=$(beads_fingerprint)
   MUTATED=0   # set to 1 at each `br` mutation this round actually applies
   # ... apply this round's `br` mutations, then:
   br sync --flush-only || { echo "flush failed"; exit 1; }
   # Only assert drift when this run actually issued a mutating `br` command. A refresh
   # whose graph already matches, or a convergence round with zero justified changes, is a
   # legitimate no-op — the prose below says so, and an unconditional check calls it a
   # failure.
   if [ "${MUTATED:-0}" = 1 ]; then
     [ "$(beads_fingerprint)" != "$BEFORE" ] || { echo "round changed nothing on disk"; exit 1; }
   fi
   ```

   Only require the change when the round actually applied mutations. A late round that
   applies zero justified changes leaves the fingerprint equal, and that is a healthy
   convergence signal, not a failed flush.
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

1. Flush the final graph with `br sync --flush-only`.
2. Invoke `second-model-bead-audit` with the source plan/spec path. Its default
   Codex + Fable panel is read-only and must not receive this skill's findings
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
bv --robot-diff --diff-since <ref>
br sync --flush-only
```

## Pipeline position

This is the second step in the bead lifecycle:

1. `plan-to-beads-transfer`
2. `bead-polish-loop`
3. `second-model-bead-audit`

Before using this skill, beads should already exist. After convergence, run
`second-model-bead-audit` as the normal final gate. Failed and conditional audits
loop back here with their accepted findings, then return to the panel.
