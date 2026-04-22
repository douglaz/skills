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

## 8. Codex auth breaks mid-run (401 from OpenAI)

**Symptom:** ralph-burning final_review fails with:
```
backend invocation failed for contract 'final_review:reviewer' via 'codex':
codex exited with code 1
ERROR: unexpected status 401 Unauthorized: Missing bearer or basic
authentication in header
```
Even `codex exec "say hi"` directly fails with the same 401. The ralph
run is marked `failed`, but the journal shows R(last): 0 amendments —
the implementation converged before the reviewer side died.

**Diagnosis:** codex's auth token expired or credits exhausted. Not a
ralph problem; it's upstream.

**What to do:**

1. **Code edits survive backend failures.** Ralph-burning edits files
   directly in the working tree and commits checkpoint commits on the
   feature branch; those persist even when the structured JSON output
   that would close out the run fails to land.

2. **Re-login** (`codex login` or equivalent) and re-test with
   `codex exec "say hi"`. If it returns cleanly, run `run resume`.

3. **If codex stays down and the journal showed convergence**, validate
   locally (`cargo test`, `nix build`, etc.). If all gates pass, push
   and merge with an explicit PR-body note: "ralph run status = failed
   due to upstream 401 after R(N):0; all local gates pass; shipping per
   the skill's 'code survives backend failures' recovery pattern."
   This is not free-wheeling — it's a documented recovery path.

4. **Do not invent evidence.** If the journal shows the run died
   mid-round with amendments still pending, do NOT ship. Wait for
   codex to come back, resume, and let it finish.

## 9. Over-correction on narrowing fixes

**Symptom:** a previous bead fixed a security issue by narrowing a
check (cookie scope, predicate output, allowlist). The new iteration's
codex review finds a *different* legitimate user is now broken by the
narrow. You reopen and ping-pong between too-wide (leak) and too-narrow
(breakage) across iterations.

**Fix:** the bead's Acceptance Criteria must list *what must keep
working* alongside *what the narrow blocks*. Narrowing-only acceptance
criteria practically guarantees an iteration-N+1 over-correction bead.

Concrete patterns that triggered this on the author's real branch:
- Host-only cookie scoping (fixed leak to tenant subdomains, broke
  workspace subdomain access).
- Invite record filtering (fixed cross-user claim_token leak, broke
  admin visibility of machine invites).
- Integration-manager predicate narrowing (fixed pending-invitee
  escalation, broke admin onboarding flows).

In each case, the iteration-N bead would have saved the iteration-N+1
bead if its Acceptance Criteria had listed the legitimate users that
still needed access.

## 10. Tests exist but never run

**Symptom:** ralph adds a test file and it passes. Codex review in
iteration-N+2 reports the test file exists but isn't executed by
`npm test` (or `cargo test`, or the repo's CI command). The
coverage is dead — the file was never a gate.

**Fix:** the bead's Acceptance Criteria should always include a line
like "the new test runs under the repo's default test command". Add a
verification step that literally runs the command and greps for the
new test name / file in the output. If the runner's glob doesn't cover
the new location, broaden it (as a separate bead, or inside the same
one if tiny).

## 11. `br` DB corruption after branch resets (< 0.1.45)

**Symptom:** `br update <bead-id>` and `br close <bead-id>` return
`ISSUE_NOT_FOUND`, but `br show <bead-id>` and `br list` both work —
the bead is clearly present. Happens after `git reset --hard` on the
work branch, which replaces `.beads/issues.jsonl` without notifying
the sqlite cache.

**Fix:** upgrade `br` to ≥ 0.1.45. If stuck on an older version, delete
`.beads/beads.db*` and run `br sync --import-only --force` to rebuild
from JSONL. If even that fails on a specific bead, patch
`.beads/issues.jsonl` directly with a Python one-liner to set
`status="closed"` + `closed_at` + `close_reason`, then `git add` +
commit. Document the workaround in the commit message so future
readers know why the JSONL diff is formatted differently.

## 12. Ralph-burning `run.json` missing after max_completion_rounds

**Symptom:** ralph finishes, but `ralph-burning run status` fails with
"No such file or directory (os error 2)". Checking the project
directory shows the journal exists but `run.json` does not — the run
hit `max_completion_rounds` and the post-run bookkeeping step didn't
land.

**Fix:** trust the journal + merged-commit evidence over `run status`.
If the journal shows amendment convergence and all validation passes,
the run is functionally complete even if the status command cannot
report it. Ship.
