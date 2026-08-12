# DRIVE — execute the open skills safety and correctness backlog

**Scope:** the 29 GitHub issues enumerated in
`docs/specs/backlog-execution-plan.md` (#30–#66, exact set in that plan); the
Beads graph created from the reviewed plan will be the ONLY work this drive may
take.
**Phase:** GRAPH · **Bead:** n/a (graph transfer in progress)
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

## Now

Initialize Beads, transfer the 33 flat execution/decision records exactly from
the reviewed plan, and verify labels, priorities, external references, and
dependency direction. Then run the polish loop and an independent second-model
graph audit. Do NOT start implementation until the graph passes both checks.

## Next

Land the planning/bootstrap branch → start A1, GitHub issue #42, through rb-lite
→ continue the highest-priority unblocked lane while respecting the two human
authority checkpoints.

## Open questions for the human

- Before B1 BUILD: choose between refusing unsupported dirty delegated paths
  (recommended: disposable worktree plus fail-closed refusal) and supporting
  dirty in-scope preservation through the larger snapshot mechanism. This is a
  user-state/data-loss design checkpoint.
- Before F2 release: authorize publishing the required upstream rb-lite release.
  Opening and reviewing its branch/PR may proceed; publishing the release may not.
