# DRIVE — execute the open skills safety and correctness backlog

**Scope:** the 29 GitHub issues enumerated in
`docs/specs/backlog-execution-plan.md` (#30–#66, exact set in that plan); the
Beads graph created from the reviewed plan will be the ONLY work this drive may
take.
**Phase:** GRAPH · **Bead:** n/a (update/polish the reviewed 33-row graph)
· **Branch:** `plan/backlog-execution`
**Pending:** —
**Gate:** `./check.sh`
· last green 2026-08-12 on the `9965c24` tree (exit 0).

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
- Repeated pinned Codex xhigh reviews drove the canonical gate wrapper to
  fail-closed process-group, output, cleanup, and inherited-signal behavior.
  `./check.sh` exited 0 on the `10c0288` tree (26 installer, 124 bot-gate, and 70
  drive-status fixtures passed).
- Called Fable at high effort to review the complete `docs/specs` inventory. It
  read all 33 rows and found two blocking plan gaps: B2d lacked its B2c
  serialization/artifact edge, and E3 relied on an unattested `br sync --status
  --json` schema. The plan now adds that edge, pins the measured `br 0.2.19`
  schema/hash, and incorporates the valid lower-severity corrections.
- Cleared the repeated SHAPE hard stop on `9965c24`: pinned
  `gpt-5.6-sol`/xhigh Codex reported no P0/P1 findings (one non-blocking P2 about
  the pre-supervisor ignored-signal startup window), Fable/high reported
  `NO BLOCKING FINDINGS`, and `./check.sh` exited 0 (26 installer, 124 bot-gate,
  and 70 drive-status fixtures).

## Now

Update the existing 33 flat beads in place from the reviewed plan, preserving all
generated IDs, and change the intentional dependency set from 22 to 24 edges.
Then run the required polish passes and the independent second-model graph audit.

## Next

Return to GRAPH → update/polish/audit the 33 beads → land the planning/bootstrap
branch → bootstrap E1 and then E3 exactly as plan global rule 8 requires → only
then start A1, GitHub issue #42, through rb-lite → continue the highest-priority
unblocked lane while respecting the two human-authority checkpoints.

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
