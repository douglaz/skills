# DRIVE — execute the open skills safety and correctness backlog

**Scope:** the 29 GitHub issues enumerated in
`docs/specs/backlog-execution-plan.md` (#30–#66, exact set in that plan); the
Beads graph created from the reviewed plan will be the ONLY work this drive may
take.
**Phase:** SHAPE · **Bead:** n/a (polish returned gaps to plan space)
· **Branch:** `plan/backlog-execution`
**Pending:** —
**Gate:** `./check.sh`
· last green 2026-08-12 at `bceb919` (exit 0).

## Done

- Queried all 29 open GitHub issues and confirmed that this repository has no
  initialized Beads store.
- Reconciled umbrellas, overlaps, priorities, dependencies, and parallel work
  lanes.
- Replaced the stale PR #64 drive record with this newly authorized goal.
- Installed the portable working agreement for subsequent implementers and
  panels.
- Passed the SHAPE hard stop: `codex review --base master` with
  `gpt-5.6-sol`/`xhigh` reported no P0/P1 findings at `bceb919`. Its two P2
  hardening observations (startup-watchdog group cancellation and defensive
  fixture orphan cleanup) remain non-blocking follow-up evidence for the
  admission-integrity stream.
- Ran the repository gate at `bceb919`: `./check.sh` exited 0 (26 installer,
  124 bot-gate, and 66 drive-status fixtures passed).
- Initialized Beads and transferred all 33 reviewed rows with 22 dependency
  edges; the first transfer audit found the exact expected labels, priorities,
  URLs, bodies, and ready A1 (`skills-ro5`).
- GRAPH polish then found that several lower workstream rows copied real intent
  but not enough API, failure, recovery, or fixture detail to be executable by a
  fresh agent. Per the GRAPH escalation rule, returned to SHAPE rather than
  encoding implementation guesses downstream.

## Now

Amend the plan with the accepted polish findings: complete the delegated-edit
fixture matrix; settle the generated-protocol and verifier owners; make C1/C2,
D2, E1/E3, F1/F2r/F3, and G1–G3 executable memory; correct priorities that meet
the plan's own P0 definition; and make design/format/decision acceptance paths
honest. Preserve the reviewed 33-row flat graph and its intentional direct
dependency edges. Re-run the pinned SHAPE review before updating Beads.

## Next

Return to GRAPH → update/polish/audit the 33 beads → land the planning/bootstrap
branch → start A1, GitHub issue #42, through rb-lite → continue the
highest-priority unblocked lane while respecting the two human-authority
checkpoints.

## Open questions for the human

- Before B1 BUILD: choose between refusing unsupported dirty delegated paths
  (recommended: disposable worktree plus fail-closed refusal) and supporting
  dirty in-scope preservation through the larger snapshot mechanism. This is a
  user-state/data-loss design checkpoint.
- Before F2 release: authorize publishing the required upstream rb-lite release.
  Opening and reviewing its branch/PR may proceed; publishing the release may not.
  Once authorized, the coordinating skills agent performs and verifies the
  mechanical publication—human authority does not require the human to run the
  release commands.
