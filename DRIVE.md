# DRIVE — execute the open skills safety and correctness backlog

**Scope:** exactly the 29 GitHub issues in the #30–#66 set enumerated by
`docs/specs/backlog-execution-plan.md`; the Beads graph is the only work. GitHub
#67 is out of scope.
**Scope-Label:** `drive-open-issues`
**Baseline:** E3a 140 production lines — pinned admission, minimal typed selector,
zero-`br` Drive handoff, consumer docs, and gate wiring.
**Do-NOT-build:** selector launcher/second parser, downloader/installer, admission
registry, scheduler/closure code, cosmetic row validation, locks/daemon/recovery API.
**Phase:** SHAPE · **Bead:** E3 split · **Branch:** `shape/e3a-e3b-split`
**Pending:** —
**Gate:** `./check.sh`

## Done

- E1 (`skills-iog`) is closed; it is the prerequisite for the new E3a admission
  bead.
- The user-approved reduced shape splits E3 into E3a exact `br`
  admission/typed selection and E3b native closure/consumers. Current-tip review
  is pending. Rule 9 is the sole metadata-closure lifecycle owner; E3a has only
  its one-time coordinator bootstrap, and merged E3b supplies reusable Step 11.
- Exact v0.3.2 evidence now covers deferred selection, authenticated-archive
  extraction, byte-identical admitted `br`, and a history-reconstructed candidate.
- The planned GRAPH delta is bounded: create E3a depending on closed E1; change
  `skills-dhm` to depend on E3a; retain its identity and all 15 dependents; update
  descriptions only for `skills-dta`, `skills-xfd`, `skills-qmi`, `skills-rrk`,
  new E3a, and E3b `skills-dhm`. Do not edit Beads in this SHAPE pass.

## Now

E3a fresh baseline: admission 22; dispatch 14; selector modes/parser 12; query
capture 20; typed projection 26; Drive handoff 18; consumer docs 18; plan/gate 10
= **140 production lines**; exact BUILD budget **420** (`3 × 140`).

E3b fresh baseline: entry/guards 12; forge state matrix 22; clone/preflight 18;
close/flush 5; proof 28; retained-clone resume 9; PR lifecycle 18; links/ADR/
plan/gate 16 = **128 production lines**; exact BUILD budget **384** (`3 × 128`).
It resumes one exact-ID OPEN closure only; cross-ID, CLOSED-unmerged, partial, or
ambiguous attempts stop for human resolution.

## Next

Transition reviewed spec → graph transfer: create E3a only, transfer its closed-E1
edge and `skills-dhm`→E3a edge, keep all 15 `skills-dhm` dependents unchanged, and
confirm E3a alone is ready. Then E3b alone is ready; normal scheduling starts only
after E3b work and its rule-9 closure merge.

## Standing decisions

- Tests and fixtures are not production LOC and remain outside the production
  budgets; they still require relevant, mutation-sensitive coverage and the normal
  gate.
- When rule 7 applies, its reservation is held until rule 9 completes. Rule 9
  independently requires one authorized coordinator; it is not a forge lock.
