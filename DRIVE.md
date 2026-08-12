# DRIVE — execute the open skills safety and correctness backlog

**Scope:** the 29 GitHub issues enumerated in
`docs/specs/backlog-execution-plan.md` (#30–#66, exact set in that plan); the
Beads graph created from the reviewed plan will be the ONLY work this drive may
take.
**Phase:** SHAPE · **Bead:** n/a (graph pending)
· **Branch:** `plan/backlog-execution`
**Pending:** —
**Gate:** `./check.sh`
· not yet run on this branch.

## Done

- Queried all 29 open GitHub issues and confirmed that this repository has no
  initialized Beads store.
- Reconciled umbrellas, overlaps, priorities, dependencies, and parallel work
  lanes.
- Replaced the stale PR #64 drive record with this newly authorized goal.
- Installed the portable working agreement for subsequent implementers and
  panels.

## Now

Write and review the buildable execution plan. Expanded review-discovered
bootstrap budget: `AGENTS.md`, `DRIVE.md`, one spec, the canonical gate wrapper,
its detectable `check.sh` entry point, two Drive references to that sole owner,
and one `install.test` regression fixture (~500 LOC; reviewed hard stop 1,000).
This replaces the earlier ~100 LOC estimate after independent review required
conditional-shell, pipeline, cleanup, signal, stopped-process, stdin, startup,
and synchronization coverage. Do NOT implement any of the 29 planned GitHub
issues in SHAPE.

## Next

Codex xhigh spec review → initialize/transfer the scoped Beads graph → polish and
audit → start A1, GitHub issue #42, through rb-lite.

## Open questions for the human

- Before B1 BUILD: choose between refusing unsupported dirty delegated paths
  (recommended: disposable worktree plus fail-closed refusal) and supporting
  dirty in-scope preservation through the larger snapshot mechanism. This is a
  user-state/data-loss design checkpoint.
- Before F2 release: authorize publishing the required upstream rb-lite release.
  Opening and reviewing its branch/PR may proceed; publishing the release may not.
