# 4. The bot gate claims absence of evidence, not clearance

Date: 2026-08-04

## Status

Accepted. Supersedes the settle-window and skipped-file clauses described in
`skills/pr-with-codex-bot-review/SKILL.md` § 7 before this date.

## Context

`scripts/bot-gate` decides whether a PR's review bots have finished with the current tip.
It is a merge *prerequisite*, not merge authorization: § 8 of the skill runs the
base-freshness ancestor test before merging, which this gate never looks at, and the skill
explicitly forbids chaining `bot-gate && gh pr merge`.

That prohibition postdates the problem below. The chain WAS the documented usage while
this predicate grew, which is why exit 0 was a merge authorization in practice whatever
the prose said — and why the wording of the verdict had to change rather than only the
docs around it.

Across roughly twenty review findings, the CLEAR condition grew to six conjuncts. Every
finding was real and every fix was correct, yet the rate of new findings did not fall.
That is the signature of a misspecified predicate rather than a hard problem being solved
correctly: each round produced not an implementation bug against a fixed model, but a new
clause, timeout, or body parser, because the model itself had never been written down.

What the predicate was implicitly claiming — "the bots have cleared this tree" — is not
observable. Measured across 19 rounds on this repo's PR #16:

- the codex bot's review `state` is always `COMMENTED`, never `APPROVED`
- its `+1` reaction fired zero times
- the review wrapper carries `commit_id` and `submitted_at`, which prove *which* tree was
  read and *when*, but not that the round is over
- GitHub's review API exposes no round-terminal field

So every clause was an inference from absence, and the gate could not distinguish "the
bots are done" from "nothing has arrived yet."

Two panel reviewers were asked to decide what the gate should claim. They split. One
proposed renaming and bounding the predicate, keeping a single exit code. The other
proposed splitting the gate: exit 0 only for server-decidable facts, with bot quietness
demoted to an advisory report — and argued, correctly, that renaming alone changes
documentation rather than safety, because `&&` ignores prose.

## Decision

**Rename and bound the predicate; keep one exit code.** The verdict is
`NO_PENDING_EVIDENCE`, and it claims exactly:

> Across API reads finishing at time T, nothing indicated an unfinished review round on
> this tip, and no bot finding on it was left undispositioned.

Not "at instant T": the reads are not atomic, so the JSON reports both ends of the
observation window and the claim is bounded by an interval.

**Delete the settle window.** It sampled the unresolved-thread count, slept 120 seconds,
sampled again, and required the wrapper to have aged past the window. It defended against
the wrapper landing before its own line comments — a gap measured not to exist. Every
round's comments carry the wrapper's own timestamp to within a second
(`19:40:19Z/19:40:19Z`, `20:24:30Z/20:24:31Z`, `03:55:25Z/03:55:25Z`). The bot submits a
round atomically; the apparent gap was an artifact of polling two endpoints in sequence.

**Delete the skipped-vs-changed-files intersection.** CodeRabbit's "Files skipped from
review" list enumerates files of the PR it is reviewing, by construction — it cannot skip
a file the PR does not touch. The intersection was therefore non-empty whenever a skip
existed, making it behaviourally identical to the blanket "any skip blocks" rule it was
written to replace, and the only way to empty it was a truncated changed-files response.
The clause could only be the old deadlock or a fail-open, never the thing it claimed. The
skip list is now printed and not gated: a vendor skipping what it judged trivial is
something to read, not something to deadlock on.

**Scope unresolved threads to the two gated bots** (`chatgpt-codex-connector`,
`coderabbitai`) rather than every account GitHub types as a `Bot`.

**Keep the `eyes` reaction as a one-way detector.** Its presence blocks; its absence
clears nothing.

## Consequences

Six conjuncts become three, plus the `eyes` blocker. Calls no longer take two minutes.
`--settle-seconds` is rejected with exit 2 rather than accepted and ignored, because a
caller passing it believes it is buying a guarantee.

The residual risk is now explicit rather than a bug: a round that starts after the last
read and before the merge is undetectable, and `--match-head-commit` closes only the
head-SHA race, not a comment or status transition in that gap. A newly imagined gap of
this shape is a known limitation, not a defect to be closed with a seventh clause.

That gives the design a falsifiable convergence test. **If a seventh conjunct appears, the
specification is still wrong** — the correct response is to re-examine the predicate, not
to add the clause.

The alternative was rejected on practical grounds, not principled ones. Splitting the gate
so exit 0 covers only server-decidable facts is more honest, but its hard half reduces to
"GitHub says mergeable," which branch protection already enforces, and its advisory half is
the same inference with the safety removed. It becomes the right answer the moment a bot
emits a real completion signal.

The primitive that would make this decidable is named, so the workaround can be retired
rather than maintained: a bot-owned **CheckRun** bound to `head_sha`, carrying a round
`external_id`, `status=completed`, and a meaningful `conclusion`, made a required status
check from that specific GitHub App. GitHub defines exactly those fields. Neither bot here
emits one, and polling cannot synthesize it.

Where the forge can enforce a rule server-side — required status checks, required
conversation resolution — that is the better home for it. Those rules are decidable and
cannot be skipped by forgetting to run a script. This gate remains a stop sign for a human
who still owns the merge.

---

## Amendment, 2026-08-04: CodeRabbit is removed from the verdict

The decision above left CodeRabbit as one of the three surviving conditions, on the
assumption that a `SUCCESS` status on the head meant CodeRabbit had reviewed that head.
Running the reworked gate against this PR disproved it.

CodeRabbit's status is a **PR-level signal**: it lands on whatever head exists when the bot
posts it, and carries nothing that binds it to a tree. Observed on PR #16:

```text
18:55:40Z  f69bf01 pushed
18:55:55Z  CodeRabbit's status comment updated, still carrying "Reviews paused"
18:56:55Z  CodeRabbit posts  success / "Review completed"  on f69bf01
           CodeRabbit review comments anchored to f69bf01: 0
```

CodeRabbit had auto-paused the PR ("this branch is under active development"), so it cannot
have reviewed f69bf01 — and stamped it green anyway, 75 seconds after the push. Five of the
last six heads carry a green status with no review; only `310a35d` has comments anchored to
it. The gate's own accidental block on the pause marker was the only thing standing between
that and a false clear.

Nothing available distinguishes "reviewed and found nothing" from "never reviewed": the
status has a null `target_url`, the walkthrough carries no SHA or reviewed-commit marker,
and CodeRabbit's only head-bound artifact is `commit_id` on line comments, which exist only
when it has findings.

Two alternatives were rejected. Requiring a comment anchored to the tip would prove it read
the tree, and would deadlock every PR that converges — a clean round leaves no comment.
Moving the requirement into branch protection does not help either, because the signal
already *is* a commit status on the head, so a required check reads the same green.

**Decision.** CodeRabbit no longer affects the verdict. The current verdict has six
conditions: a *submitted* codex review naming the tip; no PENDING review from the bot on
that tip; no `@codex review` request newer than the wrapper; no `eyes` reaction newer than
it; no base mutation unless a later explicit review request precedes the wrapper (and no
`ready_for_review` event newer than it); and zero unresolved review threads from either
gated bot. The PENDING and rerun-request checks cover in-flight rounds that `eyes` cannot
report, since a reaction is never refreshed on a rerun. The timeline check is decidable:
those events carry timestamps, and a wrapper's `commit_id` identifies the tree but not the
diff the bot read. `--no-coderabbit` is removed and rejected as an unknown option with exit
2; the "absence is undecidable" problem it existed for dissolves with CodeRabbit's removal
from the verdict.

CodeRabbit's status, its rate-limit and paused markers, and its skipped-files list are all
still **printed** — the same call made for the skip list above, for the same reason: a bug
in report-only parsing costs a human information, not a merge. Its review threads still
gate, because those carry disposition and are head-anchored.

Consequences, stated plainly. A rate-limit skip no longer blocks a merge; the gate says so
in its output and a human decides. A CodeRabbit query failure is no longer exit 3, because
it can no longer make the answer indeterminate — refusing a decidable PR because a warning
could not be rendered is the wrong trade.

This does not weaken the convergence test above; it applies it. A condition was found to be
measuring nothing, so it was removed rather than repaired.
