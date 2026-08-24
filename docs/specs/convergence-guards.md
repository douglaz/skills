# Convergence guards for the implement/review loop

**Status:** proposed, 2026-08-24. **Owner:** unassigned. **Surfaces:** `~/.config/tau/harness.yaml`,
`~/p/rb-lite`, `~/p/skills`.

## Problem

Session `skills-4sp5es` (2026-08-11 → 08-23, 13,581 inference requests, 151 agents,
~$1,089 notional) produced 5 merged PRs and ~137 commits stranded on unmerged branches.
The dominant failure was a review loop that ratcheted instead of converging: on 08-18 alone,
38 consecutive `fix:` commits, one per reviewer finding, on a design that PR #72 replaced
three days later.

The guards that would have stopped it already exist. They were not in the loop.

| Evidence | Value |
| --- | --- |
| `consensus_failure` (rb-lite exit 13) in 671,252 session events | **0** |
| Findings declined by any agent, all sources | **0** |
| `.rb-lite-reviewers` file present in either skills clone | **absent** |
| `Budget:` / do-NOT-build header in `DRIVE.md` during the ratchet | **absent** |
| rb-lite runs on 08-16, 08-17, 08-18 (96 agents, ~$509) | **0** |
| Agent launches whose task was "remediate the latest findings" | 152/206 (73%) |
| Agent launches carrying any size budget | 6/206 (2%) |

And where a budget *was* later set, the artifact grew to fill it exactly: the closure block
is 338 lines against a 350-line stop; `select-bead-lanes` is 450 lines against a 450-line stop.

## Root causes

- **RC1 — The uninstrumented path is the default.** The Tau driver contract says *"Delegate
  only concrete, bounded tasks to the implementer or reviewer roles"*. Hand-relaying findings
  between spawned `implementer` and `reviewer` agents is therefore the path of least
  resistance, and it reimplements rb-lite without any of its brakes.
- **RC2 — Declining is permitted but invisible.** rb-lite's default implementer prompt already
  grants the challenge right and asks for `challenges-round-$ROUND.md`. Nothing in rb-lite ever
  reads that file, counts it, or reports it, so the documented tripwire *"zero rejections across
  many rounds is a red flag"* has no mechanical signal behind it.
- **RC3 — The panel is structurally biased to add.** The default panel is two reviewers that
  both hunt what is missing. The skeptical reviewer that hunts what is over-built exists only
  as a snippet a human must paste into `.rb-lite-reviewers`.
- **RC4 — A ceiling is a target.** Guard 2 budgets are numbers chosen in advance, and nothing
  asks whether the correct size for `br close && br sync --flush-only` is 5 lines rather than 350.
- **RC5 — Guard 2 can be silently unarmed.** `Budget:` and the do-NOT-build list are prose a
  driver can simply not write, and no phase refuses to proceed.

## Non-goals (do NOT build)

Named up front so this spec cannot absorb them:

- No new orchestration daemon, run database, or state machine.
- No voting, arbiter, or weighted-consensus logic in the review panel.
- No changes to the closure/`br` work — that is tracked separately and must not ride this branch.
- No automatic reverting or diff surgery when a budget trips. Report and stop; a human decides.
- No new Tau roles beyond the single `skeptic` in T2.
- No enforcement in `drive-status` beyond the presence/format checks in S1.

## Changes

### Tau — `~/.config/tau/harness.yaml`

**T1. Route loops through the instrumented path.** Extend `user.driver-contract` with:

> One review round on a change is fine. The moment you would feed a reviewer's findings back
> to an implementer, stop and run `rb-lite` instead — do not hand-relay findings between
> spawned agents. A hand-rolled implement/review loop has no round cap, no rejection
> accounting, and no consensus stop, and is the documented cause of the 2026-08-18 ratchet.

**T2. Give the driver counter-pressure to spawn.** Add a `skeptic` role to the `review` group,
same model/effort/tools as `reviewer`, with contract:

> Review the change for over-specification, not defects. Flag any mechanism, handling, config,
> or abstraction not required for correctness, security, or data safety, and say what already
> covers the case. Tag each finding `CUT`, `SIMPLIFY`, or `DEFER`. Another role owns missing
> behavior; do not duplicate it. Return "No findings." when the change is already minimal
> for its stated goal.

Add to the driver contract: *whenever you spawn more than one reviewer on the same change,
one of them must be `skeptic`.*

**T3. Give Tau implementers the challenge right rb-lite implementers already have.** Extend
`user.implementer-contract` with the decline clause, mirroring rb-lite's default prompt:

> Reviewer findings are hypotheses, not orders. If a finding is a false positive, or is valid
> but over-specification — it adds mechanism, hardening, config, or abstraction that no real
> correctness, security, or data-loss requirement needs — do NOT implement it. Report the
> finding and your reason to the caller instead. Apply the test: if you simply do not do this,
> does a real correctness/security/data-loss problem break, or only an operational
> inconvenience? A documented rejection is a valid outcome.

### rb-lite — `~/p/rb-lite`

**R1. Count and report rejections.** After each implementer round, count entries in
`challenges-round-$ROUND.md` in the run dir. Emit per round in the log:

```
round 3: 7 findings addressed, 2 declined
```

Add `rejections_total` and `rejections_by_round` to the JSON summary. When three consecutive
rounds record zero rejections while the panel is still returning findings, log once, loudly:

```
WARNING: 3 rounds with zero declined findings while reviewers keep reporting.
The implementer may be accepting everything; consider a skeptical pass.
```

No new exit code — this is a signal, not a stop.

**R2. Make the skeptic a default panel member.** When no `.rb-lite-reviewers` file exists, the
built-in panel becomes three reviewers: the existing codex reviewer, the existing claude
reviewer, and the skeptical reviewer already documented in
`skills/orchestrating-with-rb-lite/SKILL.md` (the `CUT`/`SIMPLIFY`/`DEFER` prompt). Add
`--no-skeptic` to drop it for small bounded beads. Panel success remains "at least one reviewer
exited 0", unchanged.

**R3. Enforce the production budget mechanically.** Add `--max-production-lines N`
(`RB_LITE_MAX_PRODUCTION_LINES`). After each round, count added lines in the diff against
`--base`, excluding paths matching `--budget-exclude GLOB` (repeatable; defaults to
`*.test`, `*_test.*`, `test/*`, `tests/*`, `fixtures/*` so a budget is never met by deleting
coverage). If the count exceeds N, stop with new exit **14 `budget_exceeded`**, printing the
count, the limit, and the top five files by added lines. Absent the flag, behavior is unchanged.

**R4. Record the disposition of every finding.** Extend the default implementer prompt: the
per-round challenges file must list every finding the round received with exactly one of
`ACCEPTED`, `DECLINED — <reason>`, or `DEFERRED — <reason>`, so R1's count is well-defined
and a human reading the run dir can see what the round decided rather than inferring it
from the diff.

### skills — `~/p/skills`

**S1. Make Guard 2 derived and machine-checked.** In `skills/drive/SKILL.md` Guard 2 and
`skills/drive/references/autonomy-contract.md` §4:

- The budget is **derived, not chosen**. Before BUILD, state the *baseline*: the smallest
  implementation that satisfies the outcome, in lines, named concretely (e.g. "`br close`
  plus `br sync --flush-only` plus argument validation: ~15 lines"). The budget is
  `3 × baseline`. If a round's design cannot fit `3 × baseline`, that is a signal the
  outcome is wrong, not that the budget is too small — stop and re-shape.
- `DRIVE.md` gains two machine-checked header fields alongside `Scope-Label:`:
  `**Baseline:** <n> lines — <one-line justification>` and `**Do-NOT-build:** <comma list>`.
- `drive-status` reports a lane with a missing or unparseable `Baseline:` or `Do-NOT-build:`
  as not BUILD-ready. (`drive-status` does not read `Scope-Label:` at all — that field is
  checked by the bead-lanes selector in `docs/specs/backlog-execution-plan.md`, not here.)
  This is the only `drive-status` change in this spec.

**S2. Document the instrumented path as mandatory.** In
`skills/orchestrating-with-rb-lite/SKILL.md`:

- In "The fractal tail, and challenging the panel": the zero-rejection red flag is now
  reported by rb-lite (R1); state that and stop asking the operator to notice it unaided.
- Record that hand-relaying findings between agents is not an accepted alternative to
  rb-lite, with the 2026-08-18 run as the cited reason.
- Update the reviewer-panel section: the skeptic is now a default, `--no-skeptic` opts out,
  and the pasteable three-reviewer `.rb-lite-reviewers` menu stays for customization only.
- Document `--max-production-lines`, `--budget-exclude`, exit 14, and the new JSON fields.

**S3. Wire the budget through.** In `skills/rb-lite-backlog-drain/SKILL.md` and
`skills/drive/references/phases.md` BUILD: the rb-lite invocation passes
`--max-production-lines` computed from the `DRIVE.md` `Baseline:` field. Exit 14 is a stop-and-
report, never an automatic retry with a larger number.

## Budget for this spec

Baseline: R1 ~40 lines, R2 ~15, R3 ~45, R4 ~10 → **~110 production lines in `bin/rb-lite`**;
budget `3 × 110 = 330`. Tau config and skills edits are documentation/config and are outside the
LOC budget but inside review. Tests are outside the budget per S1.

Max 4 rb-lite rounds. If a round trips exit 14 on this spec's own branch, that is the correct
outcome and the spec has failed its own test.

## Deferred

- **Fractal-tail detector** (stop when findings-per-round hold steady while the diff grows).
  Deferred because R1–R3 address the same failure with less machinery. Build it only if a run
  ratchets *after* the skeptic and rejection accounting are live; that is the evidence that
  would justify it.

## Acceptance

Each change is verified independently; none is complete on assertion.

| ID | Verification |
| --- | --- |
| T1–T3 | Start a driver on a two-round change; confirm from the session event log that it invoked `rb-lite` rather than spawning a second implementer round. Confirm `skeptic` appears in `harness.roles_available`. |
| R1 | `tests/smoke.sh`: a stub implementer that writes a challenges file with two `DECLINED` entries yields `rejections_total: 2` in the JSON summary; a stub that declines nothing for three rounds emits the warning exactly once. |
| R2 | With no `.rb-lite-reviewers`, the run log reports a three-reviewer panel; `--no-skeptic` reports two. |
| R3 | A stub implementer that adds 500 lines under `--max-production-lines 100` exits 14 and names the files; adding 500 lines of `*.test` does not. |
| R4 | Challenges file lists every received finding with a disposition; count in R1 matches. |
| S1 | `drive-status` reports a lane not BUILD-ready when `Baseline:` or `Do-NOT-build:` is missing or malformed, and ready when both parse. |
| S2–S3 | `./check.sh` passes; the BUILD invocation in the drain skill contains `--max-production-lines`. |

## Rollout

R1–R4 first, on one rb-lite branch, reviewed by rb-lite itself under `--max-production-lines 330`.
Then S1–S3 in the skills repo, which depend on the flags existing. Tau config (T1–T3) last, since
it points at behavior that must already be shipped. Do not batch the three surfaces into one
branch.
