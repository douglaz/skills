---
name: fastlane
description: >-
  Ship a change fast by iterating against a live end-to-end test instead of rloop Runs and test
  suites. A manager writes a short task file and calls codex directly to implement it. opus, astra
  and sol review the diff, with fable as an optional extra seat. The manager commits, deploys and
  runs the live test: the system exercised exactly the way a real user would. The loop repeats
  until the live test is perfect. Tests are neither run nor fixed until then. For spec-only work
  the lane is about writing the spec, and there is no live test. Use this whenever the owner says
  "fastlane", "fast lane", "suspend rloops", "skip the Runs", "focus on live testing", "suspend the
  test suite", "the manager calls codex directly", "just get it working live", or otherwise trades
  the full review-and-test loop for speed, even when they don't name the skill.
---

# Fast lane

The normal lane, rloop Runs with five reviewers and a full suite every round, is thorough but slow.
One Round took over an hour before any reviewer read a line. The evidence that settles whether a
change works is a real user's journey through the real system. The fast lane cuts everything that
isn't on the path to that journey passing, and brings the rest back once it passes.

Owner, 2026-11-15, verbatim: "Suspend rloops. We need a fastlane. The manager now calls codex
directly for impl. Reviewers are opus, astra and sol. We suspend test fix and execution until the
live test is perfect". The same day: "For other projects 'live test' may mean different things, but
the idea is to execute a full end to end test that exercises the system the same way a real user
would. As general rule keep fable optional by default". And: "For spec only work the focus is
writing it".

## What changes

| | Normal lane | Fast lane |
|---|---|---|
| Implementation | rloop Run: instruction, panel, Implementer, Rounds | Manager writes a task file; codex implements it directly |
| Review | Five rloop Reviewer seats every Round | opus, astra, sol read the diff; fable optional; grok not seated |
| Tests | Suite, per-round checks, qualification | None run, fixed, edited or added until the live test is perfect |
| Gate | Round acceptance plus CI | The live test, run on the deployed candidate |
| Builds | Everything | Only what gets deployed: codex compiles that |

Some things don't change:
- The project's hard safety lines: secrets, spending approvals, public-text rules, production limits.
- The severity rule: only P0/P1 send work back.
- Who pushes, opens PRs and merges: the project's own rule (delegate-to-manager and the project's memory) still
  decides. If deploying needs a push that rule doesn't allow, ask before the first deploy.

The fast lane removes test gates, never safety gates.

## Roles

- **Manager** runs the lane: an Opus subagent at effort high, a fresh one per phase (delegate-to-manager skill).
  It writes task files, launches codex and the readers, judges findings, commits, deploys and runs the live test.
- **Assistant** (the main session) watches every wait and relays to the owner in one line per meaningful event.
  When delegated, the manager never runs its own monitor or sleep loop. It ends its turn with a wait command.
- Without a manager (the owner asked the main session to do it directly), the session plays both roles.

## Set up once per project

1. **Define the live test** in the project's metadata directory, for example
   `/var/tmp/<project>-manager/live-test.md`, from [references/live-test-template.md](references/live-test-template.md).
   - A live test drives the deployed system through a real user's journey, start to finish, on the same code paths a
     user hits.
   - No mocks, test-only helpers, fixtures or shortcuts that a real user wouldn't have.
   - What that means differs by project:

     | Project | Live test |
     |---|---|
     | Web app | A real browser through the real page against real backends |
     | CLI | Install the built binary fresh and run what a user runs |
     | Service | Call it from outside as a client would |
     | Library | A small downstream program that uses the public API |
     | Spec-only | None (see below) |
   - Write the driver script once and reuse it. The driver isn't part of the suspended suite, so build and repair it
     whenever needed.
   - If the project has no definition, draft one from the owner's words and the project notes. Get the owner's OK
     before the first run if it spends money or touches anything shared.
2. **Make a work directory** next to the brief: `fastlane-<topic>/`. It holds:
   - `progress.md`: one UTC line per event.
   - `deferred-tests.md`: test-only findings and broken tests, kept for later.
   - `followups.md`: P2/P3 findings, filed at the end.
   - One `iN/` directory per iteration.
3. **Record the switch.** Note in the brief and memory that the project is in the fast lane, quoting the owner.
   - If an rloop Run is live, stop it: `systemctl --user stop <unit>`.
   - Keep its uncommitted work as the starting candidate. Save a resume copy of the dirty tree before anything
     changes it.

## The loop

Each iteration lives in `iN/`. The scripts are in `scripts/` next to this file. Every one launches a capped
`systemd-run --user` unit (16G, no swap, OOMPolicy=continue, an exit file) and returns at once.

1. **Task.** Write `iN/task.md` from [references/prompts.md](references/prompts.md), including:
   - What the live test showed: the step, what the user saw, and the evidence paths.
   - The diagnosis, if you have one.
   - What to change and what to compile.
   - The handoff file codex writes.

   Put every failure from the same live run into one task. Fixing them one by one costs a deploy each.
2. **Implement.** Run `scripts/implement.sh <worktree> iN/task.md iN/impl <unit>`. That is codex gpt-6.1-sol, effort
   exactly high, in the worktree.
   - Codex edits and compiles what gets deployed. It doesn't commit, push, deploy or write the tracker, and it doesn't
     touch tests.
   - Wait with `scripts/wait.sh 3300 iN/impl`.
   - Then read its handoff and build exits. A failed build goes straight back to codex with the error, in a new
     `iN/impl-2`, without review.
3. **Review.**
   - Run `scripts/make-diff.sh <worktree> <base> iN/diff.patch`. It captures tracked changes plus new files, and
     prints the diff's sha.
   - Write `iN/review-brief.md` from [references/prompts.md](references/prompts.md).
   - Run `scripts/review.sh <worktree> iN/review-brief.md iN/review <tag>` for opus, astra and sol. To add the
     optional seat, name all four: `scripts/review.sh <worktree> iN/review-brief.md iN/review <tag> opus astra sol fable`.
   - Wait only on the required seats: `scripts/wait.sh 3300 iN/review/opus iN/review/astra iN/review/sol`. Read
     fable's answer if it has arrived by then, and never wait for it.
   - On a re-review after a fix, the brief covers the delta and the earlier findings, not the whole change again.
4. **Judge.** Read every finding against the code before believing it. Votes never outweigh a verified defect, and a
   unanimous finding can still be wrong.
   - **Verified P0/P1 product defect the change introduces, or one that leaves the task unmet:** goes back to step 1
     as a fix task, with a re-review of the delta. Any seat can raise one. An older P0/P1 outside the task goes to
     `followups.md` as `review-preexisting` instead.
   - **Test-only finding:** a test unrun, a fixture broken, missing coverage, a check that "can't fail". Add it to
     `deferred-tests.md`; it is never a blocker here. Check first that it really is test-only. A test that fails
     because the product misbehaves is a product defect.
   - **P2/P3:** add it to `followups.md`, to be filed at the end (severity rule). Don't fix it now unless the live
     test shows it.
   - **A seat that failed or hit a limit:** relaunch it once in a fresh directory and tag. If it fails again, go on
     only while at least two of opus, astra and sol answered, and name the missing seat in the report. With fewer
     than two, stop and report.

   Write the calls to `iN/judgement.md`.
5. **Commit.** Re-run `make-diff.sh` and confirm the sha matches the one the reviewers read. Then commit on the
   working branch with the project's author identity and public-text rules. Push only as the project's rule allows.
6. **Deploy and live test.**
   - Deploy that commit the way `live-test.md` says and run the driver as its own unit.
   - Wait, read the evidence, then clean up whatever the run created (servers, credit, accounts).
   - Log one line to `progress.md`, and tell the assistant or owner: pass, or what broke.
   - **Perfect** means every step of the journey completed and nothing the user saw was wrong: the wording, an
     unreadable or debug-looking message, an extra click, an unreasonable wait.
   - Anything short of that is a live failure, and the next iteration starts at step 1. It is a failure even when a
     reviewer had rated the same issue P2.

**Stop and report** instead of iterating when any of these happens:
- the next run would pass a spending cap;
- the live test can't run for a reason outside the code, such as a vendor being down or credentials expiring.

After the same live failure survives two fixes, revisit the diagnosis and report progress to the owner. Continue
unless an authorised limit or an outside blocker prevents it.

**Time each live test.** The owner's iteration rule covers it. If a run goes over 20 minutes, first make it faster:
reuse setup that isn't under test, and cut idle waits. If it's still over, halt before the next iteration and bring
the owner a proposal.

## Spec-only work

"For spec only work the focus is writing it."
- There is no deploy and no live test.
- Running and fixing model checks, proofs, linters and other gates is suspended like tests until the writing is
  done. Writing a formal model or proof that the scope asks for is part of the writing, not suspended.
- The loop is task → codex writes → opus, astra and sol read the text → judge → commit.
- Readers look for contradictions, unmet scope, ambiguity an implementer would trip on, and claims the text doesn't
  support.
- Done means the owner's scope is fully written and no reader raises a verified P0/P1. Then the suspended checks come
  back, as in the next section.

## When the live test is perfect

1. Tell the owner in one line that the live test passed, and what comes next.
2. File the follow-ups under the severity rule, deduped against open items:
   - P2 at priority 2, labelled `review-followup`;
   - P3 at priority 3, labelled `review-nit`;
   - an older P0/P1 at its own priority, labelled `review-preexisting`.
3. Bring the tests back. Unless the owner redirects, the suspension ends here, and `deferred-tests.md` becomes the
   next fast-lane task:
   - Codex updates the tests to the new behaviour, and the suite runs once, within the iteration-check limits.
     Launch it with `FASTLANE_TESTS=on scripts/implement.sh ...`, which lifts the launcher's test ban, and drop the
     tests line from the task file's constraints.
   - Product code changes only for a real defect a test exposes. Such a change goes through review and the live test
     again.
4. Push, PR and merge as the project's rule allows.

## Seats and commands

| Seat | Model, effort high | Runs as |
|---|---|---|
| Implementer | codex `gpt-6.1-sol` | `codex exec --dangerously-bypass-approvals-and-sandbox`, auto-compact at 250k |
| opus | `claude-opus-5-5` | `claude -p` limited to Read, Grep and Glob, no MCP servers; 5-minute prompt cache |
| astra | codex `gpt-6-astra` | `codex exec --sandbox read-only` |
| sol | codex `gpt-6.1-sol` | `codex exec --sandbox read-only` |
| fable (optional) | `claude-fable-5-2` | like opus; never waited on; a limit line is a missing seat |

- Override a model with the `FASTLANE_*_MODEL` variables the scripts list.
- Codex effort is always high, never xhigh.
- grok isn't seated. The owner's seat list replaces the general fifth-reader rule for fast-lane reviews.
- Readers can't run commands. The review brief gives them the diff file, and they read the repo for context.

**Waits.** `wait.sh DEADLINE DIR...` waits until every DIR has an exit file. Its exit codes:

| Code | Meaning |
|---|---|
| 0 | all succeeded |
| 1 | some failed |
| 2 | a unit is gone with no exit file |
| 124 | deadline |

Deadlines are at most 3300 s, so the prompt cache stays warm. Re-arm on 124. The live-test driver gets its own watch
script with the same codes, plus a "findings printed, keep waiting" mode if it streams progress.

## Don'ts

- Don't run, fix, edit or add tests until the live test is perfect. That includes "just this one quick case".
- Don't count a test-only shortcut as live evidence. If a step can't be driven the way a user drives it, say so.
- Don't let codex commit, and don't let readers edit. Run one implementer per worktree at a time.
- Don't push, open a PR or merge beyond what the project's rule allows.
- Don't drop a finding silently. It ends up judged, deferred or in follow-ups, and `judgement.md` says which.
