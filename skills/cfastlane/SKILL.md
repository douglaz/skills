---
name: cfastlane
description: >-
  Run a fast-lane change with ONE combined session instead of a manager plus an implementer: a
  single codex session plans the work, writes the code, builds it and writes the handoff; scripts
  commit, reproduce and write a receipt; one independent reviewer reads the diff and the receipt;
  the assistant judges the findings; a meter reports what the change cost in tokens, without
  limiting anything. Use this whenever the owner says "cfastlane", "combined fast lane", "single
  manager/implementer", "one sol session for both", "no separate manager" or "manager-less fast
  lane", and whenever a fast lane's manager turns are costing more than the work they coordinate.
  Prefer it over fastlane for one bounded change (a slice, a packet, a single feature or proof)
  that one session can hold; keep fastlane for long multi-iteration lanes, several managers, or
  deploy-and-retest loops.
---

# Combined fast lane

The fast lane splits a change between a manager, which writes a task file and coordinates, and an
implementer, which codes. On small bounded changes that split costs more than it buys: each manager
turn re-reads the project before doing anything, then transcribes instructions the assistant already
wrote. In one measured pilot the manager spent 63,843 new tokens beside an implementer's 102,801;
the next, larger slice ran as one combined session for 116,053 in 18 minutes.

This lane keeps the fast lane's idea, the live test decides, and changes who does what:

| | fastlane | cfastlane |
|---|---|---|
| Plans and writes the task | Manager | The assistant writes one page; the session plans its own work |
| Implements | Separate codex implementer | The same session |
| Commits, reproduces | Manager | Scripts the assistant starts |
| Reviews | opus, astra, sol | One independent reviewer by default (any fastlane seats on request) |
| Judges findings | Manager | The assistant; blocking-line calls go to the owner |
| Tokens | Not measured | Measured per role and reported; never limited |

What does not change: the project's hard safety lines, who may push and merge, the severity rule
(only P0/P1 send work back; P2/P3 become follow-ups), and the fast lane's definition of a live test.
Read [fastlane](../fastlane/SKILL.md) for those; this skill reuses its scripts and must be installed
beside it.

## Roles

- **Session**: one codex `gpt-6.1-sol` session at effort high. It plans, codes, builds, runs the
  project's own checks and writes the handoff and a commit message. It never commits, pushes, starts
  other models, writes the tracker or judges review findings.
- **Scripts**: meter, commit, diff, receipt. Everything mechanical lives here so no model spends
  tokens on it.
- **Reviewer**: read-only, independent of the session. It reads the diff and the receipt.
- **Assistant** (the main session): writes the task and the review brief, starts the scripts, judges
  findings, relays to the owner in a line per event, and meters itself.

One separation is easy to lose once the manager is gone: the session that wrote the code must not
rate findings against it. That is why the assistant judges, and why the assistant in turn hands the
owner any call at the blocking line.

## Set up a packet

A packet is one bounded change. Give it a folder beside the project's brief, for example
`/var/tmp/<project>-manager/packet-<name>/`, called PKT below, and a worktree on a fresh branch.

1. **Get the scope from the owner**: what the change must achieve, and which follow-ups, if any,
   they name into it. A filed follow-up enters only when the owner names it.
2. **Write `PKT/config.json`**:

   ```json
   {
     "name": "n1",
     "worktree": "/abs/path/to/worktree",
     "banned_text": "<regex for text the project forbids in commits>",
     "allowed_paths": ["src/"],
     "identity": {"name": "…", "email": "…"}
   }
   ```

   Only `name` and `worktree` are required.
3. **Write `PKT/task.md`** from [references/prompts.md](references/prompts.md). It is the session's
   whole handoff: one page it can act on without reading a brief, a plan or earlier sessions.

## The loop

Scripts are in `scripts/` next to this file; `F` is fastlane's `scripts/` folder.

1. **Start the session**: `scripts/session.sh PKT`. It refuses a dirty worktree, records the base
   commit, stamps the meter's start and starts the session. Wait with
   `F/wait.sh <deadline> PKT/turns/1/session` and re-arm on 124.
2. **Read the result**: `PKT/handoff.md`, and the plan or claim file if the task asked for one. A
   partial handoff names one exact remaining goal: decide whether to continue, and if so write a
   short note file and run `scripts/session.sh PKT NOTE_FILE`. That resumes the same session, whose
   history comes back from cache, so nothing is read in twice. Never start a second session for the
   same packet: it would pay the read-in again and lose what the first one learned.
3. **Commit**: `scripts/close.py PKT check`, read the scans, then `scripts/close.py PKT commit`. It
   blocks on banned text, files outside the allowed paths, or a session that committed by itself.
4. **Live test**: run the project's live test on that commit from a fresh clone, as its own unit
   (`F/launch-unit.sh --kind live …`), exactly as the fast lane defines it.
5. **Receipt**: `F/make-diff.sh WORKTREE BASE PKT/diff.patch`, then
   `scripts/receipt.py PKT <the live run's summary and exit files>`. It writes `PKT/manifest.json`.
6. **Review**: write `PKT/review-brief.md` from the references, then `scripts/review.sh PKT`. Wait
   with `F/wait.sh <deadline> PKT/review/opus`.
7. **Judge** every finding against the code, as the fast lane's step 4 says: re-rate each one, check
   a P0/P1 is reachable in a supported case, and write `PKT/judgement.md` with one line per finding.
   - **Nothing at P0/P1**: go to step 8.
   - **A verified P0/P1**: resume the session with a note naming the smallest change that removes it
     (step 2's resume), then repeat steps 3–7 on the delta.
   - **A call at the blocking line** goes to the owner before you act on it: a reviewer's P0/P1 you
     would lower, or a finding you would raise to P0/P1. You wrote the task and the brief, so you are
     not a neutral judge of whether the result is acceptable; the owner is the tiebreak.
8. **Close out**: file P2/P3 follow-ups under the severity rule, close any follow-ups the packet
   resolved, push and open the PR as the project's rule allows, take the meters (next section) and
   report to the owner: what was shown, the live result, the findings and what it cost.

## Measuring tokens

The lane measures what a change cost and limits nothing: no cap, no checkpoint, no stop. A stop set
too low costs more than it saves (a first checkpoint placed below a session's read-in once killed it
within a minute), and the owner would rather see the real cost of finished work than a partial
result that stayed inside a guess.

Take three readings at close-out and report each:

- `scripts/meter.py PKT`: the session.
- `scripts/meter.py PKT --phase review`: the reviewers.
- `scripts/meter.py --claude-transcript <your transcript> --since <packet start, ISO UTC>`: your own
  session. A packet has cost the assistant roughly as much as the session; leaving it out makes the
  lane look cheaper than it is.

The figure is **new tokens**: uncached input plus output. A long session re-reads its own history
from cache at every step, so total tokens measure the number of steps, not the work; the total is
printed as a diagnostic only. The meter can be run at any time for a progress reading.

Reference points from measured packets, for telling the owner what to expect, not for limiting:
a sol session spends roughly 50,000 new tokens reading a mid-sized project before it writes
anything; an Opus reviewer has cost about 110 new tokens per diff line (92,140 for 812 lines;
121,137 for 1,105).

Limits that are not about tokens stay: each unit's memory cap, the disk floor and the session's
wall-clock timeout come from the fast lane's launcher, and the project's quota rules still apply.

## When not to use it

- The change needs many deploy-and-retest iterations, or several managers working in parallel: use
  the fast lane. One session's context is the limit here.
- The owner wants three reviewers and a manager's separation by default: use the fast lane.
- The work is so small you would finish it in a few edits: just do it.

## Don'ts

- Don't let the session commit, push, call a reviewer or rate a finding.
- Don't add a token cap, checkpoint or stop of your own, and don't tell the session to ration its
  reading. Measure and report.
- Don't fix a P2 or P3 in the same change, and don't fold in a filed follow-up the owner did not name.
- Don't hand the reviewer the session's own summary as fact. The brief calls the handoff "claims to
  check", and the receipt, not the handoff, says what ran.
- Don't count a result the receipt does not cover as shown.
