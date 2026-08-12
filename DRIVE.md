# DRIVE — execute the open skills safety and correctness backlog

**Scope:** the 29 GitHub issues enumerated in
`docs/specs/backlog-execution-plan.md` (#30–#66, exact set in that plan); the
Beads graph created from the reviewed plan will be the ONLY work this drive may
take.
**Phase:** LAND · **Bead:** n/a (planning/bootstrap graph)
· **Branch:** `plan/backlog-execution`
**Pending:** —
**Gate:** `./check.sh`
· last green 2026-08-12 on the `7d88c46` tree (exit 0; 26 installer,
124 bot-gate, and 70 drive-status fixtures passed under GNU Bash 5.3.3,
non-POSIX mode).

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
  124 bot-gate, and 66 drive-status fixtures passed under GNU Bash 5.3.3,
  non-POSIX mode).
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
  drive-status fixtures passed under GNU Bash 5.3.3, non-POSIX mode).
- Called Fable at high effort to review the complete `docs/specs` inventory. It
  read all 33 rows and found two blocking plan gaps: B2d lacked its B2c
  serialization/artifact edge, and E3 relied on an unattested `br sync --status
  --json` schema. The plan now adds that edge, pins the measured `br 0.2.19`
  schema/hash, and incorporates the valid lower-severity corrections.
- Cleared the repeated SHAPE hard stop on `9965c24`: pinned
  `gpt-5.6-sol`/xhigh Codex reported no P0/P1 findings (one non-blocking P2 about
  the pre-supervisor ignored-signal startup window), Fable/high reported
  `NO BLOCKING FINDINGS`, and `./check.sh` exited 0 (26 installer, 124 bot-gate,
  and 70 drive-status fixtures under GNU Bash 5.3.3, non-POSIX mode).
- Updated all 33 existing beads in place at `c921749`, preserving IDs and
  producing the reviewed 24-edge graph; exact field/body, label, cycle, and ready
  audits passed.
- Ran five fresh read-only polish passes. Coverage mapping passed, while the
  critical-path passes found that E1/E3 bootstrap ordering was not encoded in the
  graph, closure metadata needed an explicit merge between bootstrap stages, E3
  was materially undersized, and several shared owners/acceptance commands were
  implicit. Returned to SHAPE and accepted those corrections.
- Cleared the second SHAPE hard stop on `ec076e9`: Fable/high reported
  `NO BLOCKING FINDINGS`; pinned `gpt-5.6-sol`/xhigh Codex reported no P0/P1
  findings (one non-blocking P2 on fixture-only startup-timeout orphan cleanup);
  and `./check.sh` exited 0 with 26 installer, 124 bot-gate, and 70 drive-status
  fixtures under GNU Bash 5.3.3, non-POSIX mode.
- Updated all 33 beads in place to the final reviewed 37-edge graph at
  `7d88c46`, preserving every generated ID. Exact field/body, lint, cycle,
  sync-health, and frontier audits passed: E1 (`skills-iog`) is the sole ready
  bead.
- Completed the independent second-model bead audit against immutable JSONL
  snapshot
  `481a8b9192717cbf2df26a08d1c76bdf4d3910875f9f1c3dee810ed2a3c0de44`.
  Pinned `gpt-5.6-sol`/xhigh and Fable/high both read all 33 bodies and voted
  PASS with no blocking or important findings. Fable's two optional nits do
  not change the graph: exact tests already exist in the five cited bodies,
  and keyword-driven `bv` executor-label suggestions conflict with the
  authoritative one-lane contract.
- Reran `./check.sh` on `7d88c46` under GNU Bash 5.3.3, non-POSIX mode; all
  220 fixtures passed.
- PR #68 review found and fixed two additional fail-open shell-shim paths plus
  two specification/body defects: the gate wrapper now clears startup variables
  and exported functions before either Python launch; E3 reads only immutable
  helper-private evidence snapshots; E2b permits only the measured initial
  `br agents --add --force` path and verifies the installed block bytes instead
  of trusting `--update`'s false zero-status no-op. Fable's convergence pass
  caught the two sibling beads that also embed the E2 section; the corrected
  contract is now present in E2a, E2b, and E2c. Focused mutations made each new
  gate fixture fail for its intended assertion before the production fix.

## Now

Land this fully reviewed planning/bootstrap branch without changing the audited
graph. Refresh clean master after merge, reserve the single `executor-skills`
lane, and dispatch sole-ready E1 through rb-lite.

## Next

Bootstrap E1 and then E3 exactly as plan global rule 8 requires, including each
exclusive reviewed closure-metadata PR. Only then start A1, GitHub issue #42,
through rb-lite and continue the highest-priority unblocked lane while
respecting the two human-authority checkpoints.

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
