---
name: fastlane
description: >-
  Ship a change fast by iterating against a live end-to-end test instead of rloop Runs and test
  suites. A manager writes a short task file and calls codex directly to implement it. opus, astra
  and sol review the diff, with grok when available and fable as an optional extra seat. The manager commits, deploys and
  runs the live test: the system exercised exactly the way a real user would. The loop repeats
  until the live test is perfect. Tests stay suspended except for checks required by the task. For spec-only work
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
| Review | Five rloop Reviewer seats every Round | opus, astra, sol read the diff; grok when available; fable optional |
| Tests | Suite, per-round checks, qualification | Only task-required checks run before the live test is perfect |
| Gate | Round acceptance plus CI | The live test, run on the deployed candidate |
| Builds | Everything | Only what gets deployed: codex compiles that |

Some things don't change:
- The project's hard safety lines: secrets, spending approvals, public-text rules, production limits.
- The severity rule: only P0/P1 send work back.
- Who pushes, opens PRs and merges: the project's own rule (delegate-to-manager and the project's memory) still
  decides. If deploying needs a push that rule doesn't allow, ask before the first deploy.

The fast lane removes test gates, never safety gates.

## Roles

- **Manager** runs the lane: a sol manager at effort high, per
  [delegate-to-manager section 7](../delegate-to-manager/SKILL.md#7-a-sol-manager). It writes task files,
  launches codex and the readers, judges findings, commits, deploys and runs the live test.
  - A manager runs its part of the lane, every iteration until the live test is perfect. Each iteration continues
    what the last one started, so the lane is one task with no boundary to clear at.
  - A lane can run several managers, one per role, as delegate-to-manager's "Several managers in one lane" says. Only
    the lead manager deploys, promotes and merges. The assistant relays peer hand-offs and questions through
    section 7's resume turns; managers cannot receive messages mid-turn.
  - Never replace it for context size. If it stops mid-lane, resume it; spawn one replacement only if the resume is
    refused, and point it at the lane's state file.
  - A [cfastlane filter handoff](../cfastlane/SKILL.md#the-loop-fastlanes-order) uses an Opus manager
    at effort high under [delegate-to-manager section 1](../delegate-to-manager/SKILL.md#1-set-up).
- **Assistant** (the main session) watches the manager (delegate-to-manager section 4) and relays to the owner in
  one line per meaningful event. Use delegate-to-manager section 7 for Sol resumes and section 2 for Opus relays.
  The lane's wait record shows the assistant the units and hand-offs being watched (see Waits).
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
   - `followups.md`: review follow-ups, filed when the lane ends. With several managers, each one numbers its items from
     its own id range (the brief's role line), so ids never collide before filing.
   - `waits`: the wait record, empty at first (see Waits).
   - One `iN/` directory per iteration.
3. **Record the switch.** Note in the brief and memory that the project is in the fast lane, quoting the owner.
   - If an rloop Run is live, stop it: `systemctl --user stop <unit>`.
   - Keep its uncommitted work as the starting candidate. Save a resume copy of the dirty tree before anything
     changes it.

## The loop

Each iteration lives in `iN/`. The scripts are in `scripts/` next to this file. Every one launches a capped
`systemd-run --user` unit (16G, or 8G for grok; no swap, OOMPolicy=continue, an exit file) through `scripts/launch-unit.sh` and
returns at once. `launch-unit.sh` also guards the host and the lane:
- **Disk floor.** It refuses while the working directory's filesystem or the nix store has less than 45 GiB free
  (`FASTLANE_MIN_FREE_GB` sets a lane's own floor). Build a flake from a git checkout or a small dedicated folder: a
  flake in a folder outside git, or named with `path:`, is copied whole into the nix store on every call. Build
  each tool the lane calls once, with `nix build --out-link <work dir>/tools/<name>`, and call it through the link,
  because the nix daemon collects garbage on its own when space runs low. When the lane ends, delete rebuildable
  output (`target/`) in the worktrees it has finished with.
- **Busy check.** Start a deploy with `--kind deploy` and a live run with `--kind live`; anything else is `other`.
  A deploy refuses while a live unit started in the work directory is active, and a live run refuses while a deploy
  is. Nothing else blocks: a test never blocks development. The guard sees only active units, so a deploy or a live
  run, a promote script included, runs inside its `--kind` unit for the whole run, started through
  `launch-unit.sh`: the unit of that kind is active exactly as long as the work. A launcher that hands off to
  another unit stays active until that unit ends. `scripts/launch-unit.sh --check deploy|live <work dir>` is only
  an early warning for a caller (exit 1 prints the holders), never the guard.
- **Manager.** `--manager <name>` puts the manager's name on the unit's wait-record line. `implement.sh` and
  `review.sh` take it from `FASTLANE_MANAGER`.

1. **Task.** Write `iN/task.md` from [references/prompts.md](references/prompts.md), including:
   - What the live test showed: the step, what the user saw, and the evidence paths.
   - The diagnosis, if you have one.
   - What to change and what to compile.
   - The handoff file codex writes.

   Put every failure from the same live run into one task. Fixing them one by one costs a deploy each.
2. **Implement.** Run `scripts/implement.sh <worktree> iN/task.md iN/impl <unit>`. That is codex gpt-6.2-sol, effort
   exactly high, in the worktree.
   - Codex edits and compiles what gets deployed. It doesn't commit, push, deploy or write the tracker, and it doesn't
     change suspended tests. It runs any check the task names as required in full, including its tests.
   - Wait with `scripts/wait.sh <deadline_seconds> iN/impl`, following Waits below.
   - Then read its handoff and build exits. A failed build goes straight back to codex with the error, in a new
     `iN/impl-2`, without review.
   - So does a handoff that leaves part of the task undone: review only a complete candidate. Readers on an
     unfinished one mostly report the omissions its handoff already lists. Send it back naming the remaining
     work. Take it to the assistant only when the handoff names a real obstacle: evidence that a requirement
     cannot be met as written, one specific step with what was tried and why it failed, or something reserved
     for you or the owner. Work that merely remains is not one.
   - Route contradictions within the lane brief to the assistant. Record preexisting gaps or defects in the handoff
     and continue. Before proposing a requirement change, run a baseline to establish whether the symptom predates
     this work. For an owner call, finish independent work and look ahead for other owner decisions, then report all
     calls together with a recommendation and evidence for each.
3. **Review.**
   - Run `scripts/make-diff.sh <worktree> <base> iN/diff.patch`. It captures tracked changes plus new files, and
     prints the diff's sha.
   - Write `iN/review-brief.md` from [references/prompts.md](references/prompts.md). Keep its P0–P3 lines exactly
     as the template has them, the owner's text: never add, drop or reword a clause for one change.
   - Run `scripts/review.sh <worktree> iN/review-brief.md iN/review <tag>` for opus, astra, sol and grok when
     available. To add fable, name all five:
     `scripts/review.sh <worktree> iN/review-brief.md iN/review <tag> opus astra sol grok fable`.
   - Grok is available only if its bounded one-word `grok -p` probe answers. Otherwise `iN/review/grok-missing`
     records the missing seat: name it in the report, never wait on it and never block on it.
   - Wait on the required seats: `scripts/wait.sh <deadline_seconds> iN/review/opus iN/review/astra iN/review/sol`, adding
     `iN/review/grok` only when its reader launched (`iN/review/grok/unit` exists). Follow Waits below. Read
     fable's answer if it has arrived by then, and never wait for it.
   - On a re-review after a fix, the brief covers the delta and the earlier findings, not the whole change again.
4. **Judge.** Read every finding against the code before believing it. Votes never outweigh a verified defect, and a
   unanimous finding can still be wrong.
   - **Re-rate every finding yourself, every round.** A seat's tag is evidence, not a verdict. Lowering a P0/P1
     needs file:line evidence; raising one to P0/P1 names the owner's clause, never a clause a brief added.
   - **Before accepting a P0/P1 in code, check that it is reachable** in a supported case, on the path the live test
     and the launch actually run. If it isn't, it is not a P0/P1; the launch line or code that shows it unreachable
     is the lowering's evidence. Spec-only text has no such path: judge its findings against the scope's
     requirements.
   - **Verified P0/P1 product defect the change introduces, or one that leaves the task unmet:** goes back to step 1
     as a fix task, subject to the round cap below, with a re-review of the delta. Any seat can raise one.
     The fix task names the smallest change
     that removes each P0/P1; anything beyond it is a follow-up. An older P0/P1 outside the task goes to
     `followups.md` as `review-preexisting` instead.
   - **Test-only finding:** a test unrun, a fixture broken, missing coverage, a check that "can't fail". Add it to
     `deferred-tests.md`; it is never a blocker here. Check first that it really is test-only. A test that fails
     because the product misbehaves is a product defect. This covers the suspended test suite only, not the
     live-test driver or checks the task requires.
   - **P2/P3:** add it to `followups.md`, to be filed at the end (severity rule). Never fix it in this change, not
     even beside a P0/P1 or on the same lines. If a later live run shows it, re-rate it in that iteration's
     `judgement.md` with the run as evidence; it then enters the next task as a live failure.
   - **A listed or filed follow-up** enters a task mid-lane only after a re-rating to P0/P1 recorded in
     `judgement.md` with its clause and evidence, or when the owner names it.
   - **A seat that failed or hit a limit:** relaunch it once in a fresh directory and tag. If it fails again, go on
     only while at least two of opus, astra and sol answered, and name the missing seat in the report. With fewer
     than two, stop and report.

   Write `iN/judgement.md` every round, one line per finding: every seat's tag, your rating, the file:line
   evidence for a lowering or the clause for a raise, and where it went (fix task, `deferred-tests.md`,
   `followups.md`, or rejected and why).
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

A lane ends on the owner's word or when its named scope is done; a stop above pauses it for the owner. Whatever ends
the lane, file `followups.md` under the severity rule before you report: each item that still holds at the committed
tip. Until then, each day's summary to the owner carries the count of unfiled follow-ups.

After the same live failure survives two fixes, revisit the diagnosis and report progress to the owner. Continue
unless an authorised limit or an outside blocker prevents it.

**Review round caps.** Each stage that ends in its own commit has a separate count: three rounds for product
code, two for test tooling (live-test driver, checkers, smoke, cleanup, gate scripts and lane tools), and two
for bringing tests back. Keep the count across resumes in the same stage. A repair after a failed live test starts at one.
After the last allowed round, put every finding still open in `followups.md` (a P0/P1 at its own priority labelled
`review-followup`), commit and let the live test judge. A finding that touches money, data loss, machine
deletion, secrets, broken core function or a check that can pass when it should fail still goes back for a fix
and another round.

**Time each live test.** The owner's iteration rule covers it. If a run goes over 20 minutes, first make it faster:
reuse setup that isn't under test, and cut idle waits. If it's still over, halt before the next iteration and bring
the owner a proposal.

## Spec-only work

"For spec only work the focus is writing it."
- There is no deploy and no live test.
- Running and fixing model checks, proofs, linters and other gates is suspended like tests until the writing is
  done, except for checks the task requires. Writing a formal model or proof that the scope asks for is part of the writing.
- The loop is task → codex writes → opus, astra, sol and available grok read the text → judge → commit.
- Readers look for contradictions, unmet scope, ambiguity an implementer would trip on, and claims the text doesn't
  support.
- Done means the owner's scope is fully written and no reader raises a verified P0/P1. Then the suspended checks come
  back, as in the next section.

## When the live test is perfect

1. Tell the owner in one line that the live test passed, and what comes next.
2. Bring the tests back. Unless the owner redirects, the suspension ends here, and `deferred-tests.md` becomes the
   next fast-lane task:
   - Codex updates the tests to the new behaviour, and the suite runs once, within the iteration-check limits.
     Launch it with `FASTLANE_TESTS=on scripts/implement.sh ...`, which lifts the launcher's test ban, and drop the
     tests line from the task file's constraints.
   - Product code changes only for a real defect a test exposes. Such a change goes through review and the live test
     again.
   - Record the suite result. If tests-back changed files, review the stage, remake the diff, match it
     to the reviewed diff and commit.
3. File the follow-ups after the tests-back stage and any resulting commit, deduped against open items:
   - P2 at priority 2, labelled `review-followup`;
   - P3 at priority 3, labelled `review-nit`;
   - an older P0/P1 at its own priority, labelled `review-preexisting`, holding nothing;
   - a P0/P1 a review round cap left open, at its own priority, labelled `review-followup`.
4. Push, PR and merge as the project's rule allows.

## Seats and commands

| Seat | Model, effort high | Runs as |
|---|---|---|
| Implementer | codex `gpt-6.2-sol` | `codex exec --dangerously-bypass-approvals-and-sandbox`, auto-compact at 250k |
| opus | `claude-opus-5-5` | `claude -p` limited to Read, Grep and Glob, no MCP servers; 5-minute prompt cache; keeps its transcript (no `--no-session-persistence`), so `token-ledger` can count it |
| astra | codex `gpt-6.2-astra` | `codex exec --sandbox read-only` |
| sol | codex `gpt-6.2-sol` | `codex exec --sandbox read-only` |
| grok (when available) | `grok-4.7` | `grok -p`, 8G, no swap, stdin from `/dev/null`; one-word probe first |
| fable (optional) | `claude-fable-5-2` | like opus; never waited on; a limit line is a missing seat |

- Override a model with the `FASTLANE_*_MODEL` variables the scripts list.
- Every seat runs at effort high, never xhigh, grok included.
- Grok runs with `--no-auto-update --model grok-4.7 --effort high --output-format plain --always-approve
  --sandbox off --no-subagents --no-memory --disable-web-search
  --disallowed-tools "search_replace,write,search_tool,use_tool" --tools "read_file,grep,list_dir"`.
  The read-only allowlist excludes shell and other built-in tools; explicitly denying `search_tool`
  and `use_tool` also removes MCP discovery and invocation, which survive the built-in allowlist.
  Its probe and reader each run in their own 8G unit with no swap and stdin from `/dev/null`.
- Readers must not run commands. The review brief gives them the diff file, and they read the repo for context.
- Reader no-read list: credential files and model config folders `~/.claude`, `~/.codex`, `~/.grok`.

**Waits.** `wait.sh DEADLINE_SECONDS DIR...` waits until every DIR has an exit file. The deadline is in
seconds, capped at 3300. Pass `3300` for 55 minutes. Its exit codes are:

| Code | Meaning |
|---|---|
| 0 | all succeeded |
| 1 | some failed |
| 2 | a unit is gone with no exit file |
| 124 | deadline |

For longer waits follow delegate-to-manager's [Sol procedure](../delegate-to-manager/SKILL.md#7-a-sol-manager)
or [Opus procedure](../delegate-to-manager/SKILL.md#4-watching-long-jobs). Re-arm on 124. The live-test driver gets its own watch
script with the same codes, plus a "findings printed, keep waiting" mode if it streams progress.

**Wait record.** The work directory's `waits` file has one line per armed wait: `manager | unit | exit path |
deadline`, the deadline in UTC (`2026-11-19T18:30Z`) and the exit path absolute. `launch-unit.sh` appends the line
for each unit it starts. `wait.sh` rewrites it with its own deadline while it waits and removes it when it returns,
on every exit path, its own deadline included. To wait on a peer's unit, run
`env FASTLANE_MANAGER=<your name> scripts/wait.sh ...`, so the line is yours and the peer's stays. For a wait on a
peer's hand-off, write a line by hand with `-` for the unit and remove it when the hand-off arrives; `wait.sh`
touches only its own manager's lines for the units it waits on. The assistant reads the record as
delegate-to-manager section 4 says.

## Owner decision panels

Use `scripts/decision-panel.py` when readers should pick from options in an owner question. It uses the
same seat commands as `review.sh` with the listed models fixed for voting. It requires Python 3 and
the fastlane launcher dependencies above.

Put the question, context and option descriptions in `BRIEF_DIR/question.md`. List the corresponding
option IDs in `BRIEF_DIR/options`, one per line. Use at least two distinct IDs. Each starts with an
ASCII letter or digit and can also contain `_` and `-`. For a seat-specific lens, put its instructions
in `BRIEF_DIR/SEAT.lens.md`, for example `opus.lens.md`. Launch snapshots these inputs in the output
directory. Use a fresh output directory and tag for each run.

```sh
scripts/decision-panel.py launch /path/to/worktree /tmp/deploy-question /tmp/deploy-panel deploy-1 --fable
scripts/decision-panel.py collect 1200 /tmp/deploy-panel
```

Launch starts opus, astra and sol, probes grok and starts it when the probe answers. `--fable` adds
the optional fable seat. Run `collect` after `launch` succeeds. Collect waits on the launched
required seats only. Its deadline is in seconds, capped at 3300. Exit 124 means the wait expired.
Run `collect` again on the same directory to resume. If systemd could not confirm a required seat
stopped, collection returns 2. Retry when systemd is reachable. Exit 0 means the tally is ready,
including when the decision goes to the owner. Later collections return the published verdict.

Each ballot gives a pick, a full ranking, the options the reader can live with, and its strongest
argument. The tally counts picks from valid, completed ballots, including fable if ready when collected.
A limit line, a failed unit or a missing answer contributes no vote. A unanimous nonempty panel is
accepted. A split of 2 of 3, 3 of 4 or 4 of 5 is accepted only when opus picked the majority option.
Other splits and an empty panel go to the owner. Collect prints the counts and verdict and writes
`OUT_DIR/synthesis.md` with each pick and argument. When recording an accepted pick, name any narrowing
or widening of an earlier owner pick.

## Don'ts

- Run any check the task requires in full. Leave other tests suspended until the live test is perfect.
- Don't count a test-only shortcut as live evidence. If a step can't be driven the way a user drives it, say so.
- Don't let codex commit, and don't let readers edit. Run one implementer per worktree at a time.
- Don't push, open a PR or merge beyond what the project's rule allows.
- Don't drop a finding silently. It ends up judged, deferred or in follow-ups, and `judgement.md` says which.
