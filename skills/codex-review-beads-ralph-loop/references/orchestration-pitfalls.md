# Orchestration pitfalls

Patterns that have caused runs to stall or produce misleading output.

## 1. Reviewers flagging `.ralph-burning/` as code findings

**Symptom:** every completion round produces the same amendment pointing at
`.ralph-burning/run.json` or `journal.ndjson`. The implementer cannot modify
live orchestration state, so the amendment never resolves. The run hits
`max_completion_rounds` and force-completes.

**Fix:** put the exclusion block into the prompt. The implementer cannot
enforce scope — the reviewer has to be told.

```
## IMPORTANT: Exclude orchestration state from review scope
Files under `.ralph-burning/` are live orchestration state and MUST NOT be
reviewed or flagged. Only review source code under `src/`, `tests/`,
`docs/`, `dashboard/`, `scripts/`, and config files.
```

If the run is already going and looping, stop the run, amend the prompt,
then `ralph-burning run resume`. Do not edit `run.json` by hand.

## 2. Test-seam shortcuts that bypass the fix path

**Symptom:** a reviewer amendment points out that the new tests exercise a
test-only shortcut (env-var-gated early return, in-memory fake, etc.) that
does not exercise the production code path being fixed. CI stays green even
if the fix is wrong.

**Fix:** test through the real code path. If a live kube/db dependency is
the problem, inject a fake *below* the seam you care about, not above it.
The reviewer is usually right on this one — accept the amendment.

## 3. Amendment oscillation

**Symptom:** per-round amendment counts follow a pattern like
`4 → 2 → 4 → 3 → 4`. Two reviewers are disagreeing with each other across
rounds, not with the implementer.

**What to do:** let it run. `max_completion_rounds` will force-completion,
and the code itself is usually fine — the oscillation is in
*opinions on the code*. Validate locally and ship. If the user cares about
"clean final_review", add a more specific Acceptance Criterion that
resolves the disagreement (e.g. "reject the non-Hermes case at the handler,
not the service layer").

## 4. Same finding reappears after merge

**Symptom:** bead is closed, PR is merged, next iteration's `codex review`
returns the same finding.

**What this usually means:**

- The fix landed in a helper that the failing path does not go through.
  Widen the fix.
- The bead's Acceptance Criteria missed an entry point (both
  `runtime_publish_published_app` and `publish_machine_published_app`, for
  instance — not just one).
- The test covers behavior the fix no longer exhibits, but not the behavior
  the user-facing call actually produces.

Treat a repeated finding as the loop's most important signal. Reopen, widen
the bead, and rerun — don't paper over it.

## 5. Backend exhaustion (credits/quota)

**Symptom:** `reviewer unavailable (backend exhausted), proceeding with
remaining reviewers`, often on `gpt-5.3-codex-spark`. The run continues
with a quorum of the remaining reviewers and usually completes.

**What to do:** ignore unless *all* backends exhaust (then the stage
fails). A degraded reviewer set is fine.

## 6. Hung backend (0% CPU, no events)

**Symptom:** `ralph-burning run tail` shows no events for 30+ minutes and
the backend process is at 0% CPU. Usually Codex's GPT API is hung.

**What to do:** wait for the 1-hour timeout, or `run stop` + `run resume`.
Resume is safe — code edits already persisted to the working tree.

## 7. Nondeterministic `nix build` failures

**Symptom:** `cargo test` passes but `nix build` fails with errors that do
not appear locally (often dependency resolution or feature-flag differences
in the sandbox).

**What to do:** do NOT ignore. The nix build is the authoritative gate.
Rerun it, inspect the error, and treat it as a real blocker. A common cause
is a missing Cargo.lock update that is visible in the sandbox but masked by
a dev cache locally.
