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

- Confirm `br`, `bv`, **and `jq`** are on `PATH`. If any is missing, stop and say so.
  `jq` is not a panel tool here: every `br` write can silently revert other beads
  (step 5), and both the damage check and the recovery resolve the graph's real path
  through `br where --json | jq`. Without it you can still mutate the graph and then
  cannot tell whether you destroyed anything — the one ordering that must not be
  possible. If `br where --json` cannot be parsed on this host, do not write to the
  graph at all.
- Record whether `codex` and `claude` are available for the final reviewer panel.
  Missing panel tools do not block polishing, but they determine whether the eventual
  audit can be full, degraded, or blocked.
- Re-read `AGENTS.md`, `README.md`, and the relevant plan/spec before editing the graph.
- If there are no meaningful beads yet, redirect to `plan-to-beads-transfer`.
- If polishing keeps surfacing architecture questions, step back into plan space instead of repeatedly fixing downstream symptoms.


**Before the first `br` write, check the JSONL for divergence.** Any `br` mutation
auto-flushes the cache over the tracked file, so an unstaged hand-edit is erased by your
first write — and since neither the index nor `HEAD` holds it, every later diff shows only
your intended changes and the loss becomes *undetectable*. Resolve the path in its own
checked steps, and check the inspection too — embedded in a `git status` argument the
resolution's exit code is swallowed, and two of those failures are **silent** rather than
loud. Measured on git 2.54.0 / jq 1.8.2:

- `br where` exiting non-zero *after* emitting valid JSON. The pipeline reports only its
  last command's status, so `jq` succeeds and the assignment returns 0.
- `br where` emitting JSON without the key: `jq -er .jsonl_path` exits 1 **and prints
  `null`**, so the substitution yields the literal pathspec `null` and
  `git status --porcelain -- null` exits 0 printing nothing.

(A genuinely empty pathspec is *not* the hazard — `git status --porcelain -- ""` fails
loudly with `fatal: empty string is not a valid pathspec`, exit 128, on the version stated
above. Behavior may differ on older git — unmeasured here; if you must support one,
measure there.)

And `git status` itself can fail — a JSONL resolved outside this worktree exits 128
(`fatal: … is outside repository`) — printing nothing on **stdout**, so gating on stdout
emptiness alone reads a failed inspection as a clean tree right before the destructive
first flush:

```bash
_bw=$(br where --json) || { echo "cannot resolve the beads JSONL"; exit 1; }
BEADS_JSONL=$(printf '%s' "$_bw" | jq -er .jsonl_path) || { echo "cannot resolve the beads JSONL"; exit 1; }
_st=$(git status --porcelain -- "$BEADS_JSONL") \
  || { echo "cannot read the worktree — do NOT write"; exit 1; }
printf '%s' "$_st"
```

If it is not empty, resolve it first — recovery
case (a) in [orchestrating-with-rb-lite](../orchestrating-with-rb-lite/SKILL.md) step 11. After the first flush the choice
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

4. Write the replay manifest **before** applying anything — one line per intended `br`
   command, verbatim and complete (ids, field values, order). Step 6's round summary is
   written after the flush and records decisions, not the commands; recovery discards the
   working JSONL before you could read them back off it. Then apply the changes with `br`.

5. Flush with an **explicit** `br sync --flush-only` and require it to succeed:

   ```bash
   br sync --flush-only || { echo "flush failed — mutations not persisted"; exit 1; }
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
   `br update -d/--notes`, and field-diff the tracked JSONL before committing (resolve it
   with `br where --json | jq -er .jsonl_path`; the `.beads/` layout is only the default,
   and a hardcoded path diffs nothing on the others): a full
   re-serialization with every id on both sides is normal, ids on only one side or a
   `description` you did not touch is the tell. Recovery — and why `br sync --import-only`
   cannot do it — is in
   [orchestrating-with-rb-lite](../orchestrating-with-rb-lite/SKILL.md) step 11, with one
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

1. Flush the final graph with `br sync --flush-only`.
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
