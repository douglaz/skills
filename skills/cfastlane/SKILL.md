---
name: cfastlane
description: >-
  Run fastlane for one bounded change with one combined sol session that plans, codes, builds and
  writes the handoff, resumed for repairs. All fastlane rules apply except the five listed role,
  commit, review ownership, token and scope differences. The session calls opus, astra and sol before the script
  commits, with grok when available and fable optional; then the live test decides. Task-required
  checks run in full. Other tests stay suspended until the live test passes. Use for "cfastlane", "combined fast lane", "single manager/implementer",
  "one sol session for both", "no separate manager" or "manager-less fast lane", and when manager
  turns cost more than the bounded work they coordinate. Use fastlane for several managers or an
  open-ended lane.
---

# Combined fast lane

Read [fastlane](../fastlane/SKILL.md) in full first. **Everything there applies**, including its
setup, loop order, review and re-review rules, records, stops, spec-only work, live-run cleanup,
waits and return to tests. This skill is a delta on it and must be installed beside it.

## The five exceptions

| | cfastlane exception | Why |
|---|---|---|
| Session | One codex `gpt-6.2-sol` session at effort high plans, codes, builds and writes the handoff. Resume it for repairs; never restart it. No separate manager or implementer. | One session holds the packet's context. |
| Commit | The session never commits. The assistant runs `close.py`, keeping its banned-text and allowed-path scans. | Commit checks stay mechanical. |
| Review ownership | The session writes the fixed brief, reviews a complete candidate, judges, repairs and re-reviews under fastlane's round caps. It batches owner calls before lowering a reviewer's P0/P1 or deciding a raised P0/P1 must stay open outside the round-cap rule. | The owner chose the session as judge, with these guards. |
| Tokens | Measure and report per role; never impose a token cap, checkpoint or stop. | Report the cost of finished work. |
| Scope | One bounded change, called a packet. | Use fastlane for an open-ended lane or several managers. |

The assistant starts and resumes the session, reads its report and final review round, relays owner
calls, and performs the commit, deploy, live-test and close-out steps. It neither launches reviewers
nor judges findings. It writes one page of scope; the session plans its own work. The session never
commits, pushes, deploys or writes the tracker; it launches other models only through the reviewer
launcher. Reviewers are the same panel as fastlane: **opus,
astra and sol by default, plus grok when its one-word probe answers**. Fable is optional and never
waited on. Use fastlane's failed-seat rule (relaunch once; at least two of opus, astra, sol must
answer), and name missing seats, including unavailable grok, in the report.

## Stopping early

The session does all the work the task asks before it stops. A partial handoff is for a **named
obstacle**, never for work that merely remains:

- evidence that a requirement cannot be met as written, with a baseline before proposing a
  requirement change;
- one specific step, with what was tried and why each attempt failed;
- a run or decision the task reserves for the assistant or the owner;
- the turn's time limit.

A task's own stop condition ("if X cannot be finished, stop") means one of these, so write it that
way: name the obstacle that justifies the stop. In one packet a session read "not yet proved" as
"cannot be finished", stopped 35 minutes into a six-hour turn without attempting the proof, and
finished it within the hour once resumed.

Two rules follow:

- **No review of a partial candidate.** On an early stop the session launches no reviewers and
  writes the handoff. A panel on a candidate its own handoff calls unfinished mostly reports the
  omissions the handoff already lists; in that packet it cost more new tokens than the session.
- **A required fix is not an owner call.** A P0/P1 the task already requires fixing is repaired in
  the turn under the round-cap rule, whoever rated it. For owner calls, finish independent work,
  look ahead for other owner decisions and report them together with a recommendation and evidence
  for each. Record preexisting gaps or defects in the handoff and continue. Run task-required checks
  in full, tests included.

What the assistant does with a partial handoff depends on what it names:

| The handoff names | The assistant |
|---|---|
| No obstacle: work merely remains | Resumes the same session with a note that says so and lists the remaining work. No owner call. |
| The turn's time limit | Resumes the same session to continue. No owner call. |
| A run or decision reserved for the assistant | Does the run or makes the decision, then resumes with the result. |
| A contradiction within the packet brief, including task versus live-test instructions | Resolves it and resumes with the corrected brief. |
| A run or decision reserved for the owner, or evidence that a requirement cannot be met as written | Takes it to the owner with the session's evidence and resumes only with the owner's result or decision. Never resumes against the unchanged requirement. |
| One specific step that failed | Resumes once if it can add something the session lacked (a fact, a pointer, a different approach). Otherwise, or if the same step fails again, takes it to the owner. |

The assistant sorts a handoff into these rows by what it says; that is routing, not judging a
review finding.

## Set up a packet

Use fastlane's setup and records in a folder beside the brief, for example
`/var/tmp/<project>-manager/packet-<name>/`, called PKT below. Create `progress.md`,
`deferred-tests.md`, `followups.md`, `notes.md` and an empty `waits` in **PKT itself** so fastlane's launcher
finds the packet as its lane folder. Define `live-test.md` from fastlane's template (spec-only
work follows its spec-only section). Use a working branch; keep any inherited uncommitted
candidate and save its resume copy before launching, as fastlane requires.

Write `PKT/config.json` (only `name` and `worktree` are required):

```json
{
  "name": "n1",
  "worktree": "/abs/path/to/worktree",
  "banned_text": "<regex for text the project forbids in commits>",
  "allowed_paths": ["src/"],
  "identity": {"name": "…", "email": "…"}
}
```

Write `PKT/task.md` using [references/prompts.md](references/prompts.md) and keep fastlane's test
suspension with its exception for task-required checks.

## The loop: fastlane's order

Scripts here are in `scripts/`; `F` below is fastlane's `scripts/` folder. Use fresh review and
live-run output directories each round; keep earlier findings and judgments for re-review.

1. **Task and session** (fastlane steps 1–2): the assistant runs `scripts/session.sh PKT`, which records the base, stamps
   the meter and starts the one combined session. Wait for each session turn with
   `scripts/session.sh --wait <deadline_seconds> PKT/turns/N/session`, starting at turn 1.
   Handle a content-filter exit before reading `PKT/handoff.md` and build exits.
   On a partial handoff, follow the table in "Stopping early" before anything else, whether or not the build also failed: some
   obstacles go to the owner before any resume. Otherwise, on a build failure, write a short note
   and run `scripts/session.sh PKT NOTE_FILE`, resuming the same session; wait on
   `PKT/turns/N/session`. Keep `FASTLANE_TESTS=on` on every resume within tests-back.
   Never start a separate implementer. The session performs
   steps 2–3 inside its turn before writing its final handoff. The default turn timeout is six
   hours (`CFASTLANE_TIMEOUT` overrides). This is a wall-clock limit, never a token limit.
   For quota balancing, `CFASTLANE_ENGINE=claude` on the first turn runs the session on Opus
   (`claude-opus-5-5`, effort high, `claude -p`) instead. It is off by default, and resumes keep the
   first turn's engine. Exit 4 below is codex-only: a Claude refusal or limit line is an
   ordinary wait result. The session collects and judges
   every required reader it launched before it ends, unless that wait would pass the limit; if it
   still ends with readers active, it reports their units and exit paths and the assistant resumes
   the same session to collect them, without duplicates.
   The session wait uses fastlane's exit codes and adds exit 4 (`CONTENT_FILTER`). On the
   first filter stop, resume the same session once with a plainly worded note. If the resume
   also exits 4, move the packet and its existing work to fastlane with an Opus manager.
   The assistant does this directly and tells the owner in one line.
   The assistant may append to `PKT/notes.md` during a turn. The session reads it before each
   review round, each repair and its handoff. For an urgent change, stop the session unit with
   `systemctl --user stop UNIT`, then resume with a note. A wait exiting 1 after that stop is expected.
2. **Review** (step 3), by the session, once the candidate is complete (see "Stopping early"):
   Before each review, put the required check commands and exits for its candidate in
   `PKT/handoff.md`. Refresh checks a repair can affect before re-review.
   `F/make-diff.sh WORKTREE BASE PKT/diff.patch`, where BASE
   is the commit in `PKT/base`. Fill `PKT/review-brief.md` from the fixed template in our
   references; never reword reviewer instructions or P0–P3 lines. `scripts/review.sh PKT` checks
   the fixed instructions and Report section against fastlane's source before launching.
   The session runs it; the shared launcher launches opus, astra, sol and probes grok.
   Let `<review-output>` mean this launch's output: `PKT/review` on the packet's first round.
   Use fresh `--out` and `--tag` for every later launch, including a new stage's first round.
   Wait with `F/wait.sh <deadline_seconds>
   <review-output>/opus <review-output>/astra <review-output>/sol`, adding
   `<review-output>/grok` only if that reader launched (`<review-output>/grok/unit` exists).
   Read `<review-output>/grok-missing` if present. Never use an earlier round's exits.
   To add fable, name all five seats:
   `scripts/review.sh PKT opus astra sol grok fable`; never include fable in the wait.
   For a failed seat's one retry, run `scripts/review.sh PKT --out PKT/review-retry-N
   --tag <fresh-tag> <seat>` and wait on that output directory's seat. Keep active seats in
   place; do not move their directories or wait for optional fable to end.
3. **Judge** (step 4), by the session: follow fastlane's judgment rules and round caps and write
   `PKT/judgement.md` each round. Apply its deferred-tests and follow-up rules. Batch owner calls
   under "Stopping early" and resume with their decisions. Repair accepted P0/P1 as fastlane requires
   and write the handoff for the assistant to commit when the cap calls for it.
   When a fix needs re-review, keep the old review and judgment, make the new diff and the delta, and re-review
   with fresh `--out` and `--tag` values using fastlane's earlier-findings and follow-ups rules.
   Wait on the required seats under that new `--out`, as step 2 says.
   No commit yet.
4. **Commit** (step 5), by the assistant: read the handoff and final review round; unresolved owner
   calls return to the owner. Re-run `make-diff.sh` and confirm the sha matches what the reviewers read.
   Run `scripts/close.py PKT check`, inspect the scans, then `scripts/close.py PKT commit`.
   It blocks banned text, disallowed paths and a session that committed by itself. After a live
   failure, repairs build on its last candidate; reviews still cover the packet from its base,
   with re-reviews focused on the delta.
5. **Deploy and live test** (step 6): use fastlane's exact rules and `live-test.md`. Start deploy
   and live units through `F/launch-unit.sh --kind deploy|live …` with output directories under
   PKT, keeping the work inside the unit for its entire run. Wait, read evidence, clean up what
   the run created and log the result. A live failure resumes the same session and repeats this
   loop, including review **before** the next `close.py` commit.
   After the run, `scripts/receipt.py PKT <summary and exit files>` writes `PKT/manifest.json`.
   The assistant reads it at close-out to bind the commit and diff to the live evidence; it is
   not a prerequisite for pre-commit review. Keep each round's receipt with its evidence.
6. **Close out**: follow fastlane's end-of-lane records, stops, follow-ups and cleanup. After the
   live test is perfect (or spec writing is done), bring tests and checks back as fastlane says:
   update the task to lift its test ban and include the no-change handoff, then resume with
   `FASTLANE_TESTS=on scripts/session.sh PKT NOTE_FILE`. Record the suite result. If tests-back
   is complete, HEAD matches `PKT/candidate` (or `PKT/base` before the first commit), and
   `git status --porcelain --untracked-files=all --ignore-submodules=none` succeeds with empty output,
   finish the handoff without a new review or close.
   For the reviewed tests-back changes, remake
   the diff, match its SHA to the new reviewed diff, then run `scripts/close.py PKT check` and
   `scripts/close.py PKT commit` again before filing follow-ups. Any resulting product fix goes through
   review, script commit and live test again. Push, PR and merge only as the project's rule
   allows. The merge lane uses [gate-and-merge](../pr-with-codex-bot-review-merge/SKILL.md#normal-merge).
   Take the readings below and report the result, findings, missing seats and cost.

Use fastlane's wait record and busy check unchanged: session and review units are `other`, and
nothing about naming the lane folder a packet changes the guards. Set `FASTLANE_MANAGER` to the
coordinator's name for recorded waits. `wait.sh` takes seconds. Pass `3300` for 55 minutes. Use its
bounded polling and wait hand-off rules, re-arming on 124. Never override a busy deploy or live run.

## Measuring tokens

Measure without limiting anything. At close-out, report new tokens (uncached input plus output)
for each role, with total tokens as a diagnostic:

- `scripts/meter.py PKT`: the combined session.
- `scripts/meter.py PKT --phase review`: reviewers, including earlier rounds (keep `review-start`).
- `scripts/meter.py --claude-transcript <your transcript> --since <packet start, ISO UTC>`:
  the coordinating session when it is Claude. For a different transcript format use the
  project's token ledger.

The meter selects the combined session by its recorded session ID and excludes that ID from
review totals, even when the session resumes after starting readers. It reads Codex and Claude
transcripts. Report Grok usage separately from its
available usage records; if it cannot be measured, name that limitation rather than reporting zero
or including it in a claimed panel total. No missing measurement stops work. Memory, disk,
wall-clock and project quota limits still apply as in fastlane.

## When not to use it

Use fastlane when the scope is open-ended or needs several managers. A bounded packet can repeat
its deploy-and-live-test loop with the same session. If a few edits suffice without a lane, do them.
