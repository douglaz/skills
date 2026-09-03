# DRIVE — execute the open skills safety and correctness backlog

**Scope:** exactly the 29 GitHub issues in the #30–#66 set enumerated by
`docs/specs/backlog-execution-plan.md`; the Beads graph is the only work. GitHub
#67 is out of scope.
**Scope-Label:** `drive-open-issues`
**Baseline:** E3a 141 production lines — pinned admission, minimal typed selector,
zero-`br` Drive handoff, consumer docs, and gate wiring.
**Do-NOT-build:** selector launcher/second parser, downloader/installer, admission
registry, scheduler/closure code, cosmetic row validation, locks/daemon/recovery API.
**Phase:** GRAPH · **Bead:** E3a (`skills-uay`) · **Branch:** `shape/e3-final-reconciliation`
**Pending:** —
**Gate:** `./check.sh` · last green 2026-09-03 before GRAPH transfer (exit 0)

## Done

- E1 (`skills-iog`) is closed; it is the prerequisite for the new E3a admission
  bead.
- The user-approved reduced shape splits E3 into E3a exact `br`
  admission/typed selection and E3b native closure/consumers. Current-tip review
  is pending. Rule 9 is the sole metadata-closure lifecycle owner; E3a has only
  its one-time coordinator bootstrap, and merged E3b supplies reusable Step 11.
- Exact v0.3.2 evidence now covers deferred selection, authenticated-archive
  extraction, byte-identical admitted `br`, and a history-reconstructed candidate.
- Pinned Codex CLI 0.149.0 with `gpt-5.6-sol`/xhigh reviewed `a32cb9f`
  against `cddc78b` with no P0/P1; two P2 observations remain visible in the
  E3a/E3b bodies. The exact-tree gate exited 0.
- GRAPH created E3a `skills-uay` depending on closed E1, rewired
  `skills-dhm` to depend on E3a, retained its 15 dependents, and updated only
  the six approved description bodies.

## Now

Polish and independently audit the 34-row graph. Prove the only semantic delta:
new E3a `skills-uay`; five existing description replacements; and
`skills-dhm`'s dependency moving from closed `skills-iog` to `skills-uay`.
Confirm E3a alone is ready and `skills-dhm` retains all 15 dependents.

## Next

After GRAPH audit PASS, enter BUILD for E3a `skills-uay` at baseline 141 and
budget 423. E3b `skills-dhm` becomes ready only after E3a work and rule-9
closure; normal scheduling starts only after E3b and its closure merge.

## Standing decisions

- Tests and fixtures are not production LOC and remain outside the production
  budgets; they still require relevant, mutation-sensitive coverage and the normal
  gate.
- When rule 7 applies, its reservation is held until rule 9 completes. Rule 9
  independently requires one authorized coordinator; it is not a forge lock.
- Reductions the skeptic asks for are pre-authorized: cutting an unconsumed
  contract clause, deleting prose a fact owner already states, and dropping a
  requirement no routing decision reads need no approval. Adding a mechanism to
  replace one still does.
- SHAPE-phase spec corrections that leave the Beads graph, BUILD, push, and PR
  untouched are pre-authorized. Report them; do not ask first.
- Itemizations are re-derived when the requirement set changes. Adjusting a
  baseline and its `3 ×` stop to match what is actually being built is
  bookkeeping, not a budget increase, and needs no approval — raising a stop
  without a matching requirement change does.
