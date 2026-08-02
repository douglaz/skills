---
name: drive
description: >-
  Use this whenever the user hands over a GOAL instead of a single action and expects
  you to keep working until it is reached. Make sure to use it even when the user never
  says the word "drive" — a request that spans more than one phase of the software
  lifecycle is a drive, and running the phases ad hoc instead is the mistake this skill
  exists to prevent. Trigger phrases: "drive this", "drive the project", "take X from
  spec to merged", "from idea to merged", "handle it end to end", "run the whole
  pipeline", "work on X until it's done", "keep going until the beads/backlog are
  drained", "don't stop and ask me between steps", "I'll check back later", plus any
  request that names a feature, epic or milestone rather than a file, or that states a
  finish condition rather than an action. Also use it to answer "where are we / what's
  next" on a project, and to resume a half-finished project in a fresh session. It
  sequences the specialist lifecycle skills — spec, then beads, then build, then tests,
  then the reviewer panel, then the PR and merge, then the next bead — and enforces the
  evidence gate between each, so prefer it over invoking any single one of those skills
  directly whenever the work spans more than one of those phases. Skip it only for a
  single bounded action, a one-off edit, a question, or debugging and ops work.
argument-hint: "[goal or bead id] [--phase shape|graph|build|prove|harden|land]"
compatibility: >-
  Inherits the prerequisites of whichever phases a project actually reaches:
  `codex` and `claude` on PATH for HARDEN, `rb-lite` (PATH or the Nix wrapper) for
  BUILD, `br` and `jq` for the bead phases, `gh` authenticated for LAND. The
  bundled `scripts/drive-status` detector needs none of them — it degrades to
  `n/a`/`unknown` and exits 0 — but its bead counts and PR state stay blank
  without them. SHAPE delegates to planning skills that are not in this repo.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
  - AskUserQuestion
---

# drive

The project driver. It does not implement anything itself — it decides **which phase the
project is in**, runs **the right specialist skill for that phase**, demands **evidence**
that the phase actually completed, records the transition, and **immediately enters the
next phase**.

Every rule below exists because its absence showed up as a human intervention in real
sessions. Keep that framing: this skill's job is to make the user stop having to type
`continue`, `status?`, `commit/push`, `call codex again`, and `are you sure?`.

## Prime directive: the continuation contract

**Once the user names a goal, every step required to reach that goal is authorized.**

- Never end a turn with "Want me to do X?" when X is the obvious next step inside the
  drive lane. Say "Doing X now" and do it.
- Never end a turn with a summary and a stop. A summary is a *transition marker*, not a
  finish line. Report the phase that closed, then open the next one in the same turn.
- Never wait for a nudge after a background job completes. The completion notification is
  the trigger to continue, not to report and idle.
- A phase that fails does not end the drive. Diagnose, fix, re-run the gate. Only the
  stop-list below ends a turn.

The only things that end a turn: the goal is reached, a **stop-list** item is hit, or a
gate has failed the same way twice with no new hypothesis to try.

### Stop-list — genuinely needs the human

Everything else is yours to decide.

1. **Irreversible or outward-facing.** A drive goal *does* authorize the ordinary
   mechanics of landing its own work: pushing its own feature branch, opening the PR,
   `--force-with-lease` on that branch, and squash-merging it once the gates are green.
   That is the deliverable, not a separate decision.
   It does **not** authorize anything whose blast radius leaves the repository or cannot
   be undone: production deploys, publishing packages or releases, posting outside the
   PR, spending real money, touching secrets or credentials, force-pushing a shared or
   protected branch, rewriting history someone else has pulled, or deleting branches,
   data, or issues the goal never named. When the repo's own rules disagree with this
   (protected default branch, required human approval), the repo wins.
2. **A design fork inside a money/consensus/data-loss path** where two defensible
   mechanisms lead to materially different systems.
3. **The cross-cutting tell**: a second review round adds *another* consumer of the same
   concept. Stop expanding scope file-by-file — run a design pass and surface it.
   (See `references/autonomy-contract.md` § 5.)
4. **Scope budget blown** — see Guard 2.
5. **The goal itself was wrong** — what you learned building contradicts the premise.

When you hit one, state the fork in a few sentences, give your recommendation first, and
ask one question. Then resume the moment it is answered.

## Phase 0 — Orient (always run first)

```bash
# Resolve from whichever target this skill was installed into — `install.sh --target codex`
# never creates ~/.claude/skills. Do NOT add a `$(dirname "$0")` fallback: this snippet is
# run by the agent's shell, so $0 is the shell, and the resulting relative path would point
# into the DRIVEN repo's parent — where it could execute an unrelated `scripts/drive-status`.
for d in "$HOME/.claude/skills/drive" "${CODEX_HOME:-$HOME/.codex}/skills/drive" \
         "$HOME/.agents/skills/drive"; do
  [ -x "$d/scripts/drive-status" ] && { "$d/scripts/drive-status"; break; }
done
```

This takes the first match. With a normal `install.sh` run every target is a symlink to
one source, so the order is irrelevant — but if you have both a Claude and a Codex install
that are *separate copies*, the first one wins and it may be the stale one. When the skill
directory the harness handed you is one of these paths, prefer that one; it is by
definition the version being executed.

If none resolve, you are running from a checkout rather than an install: run
`<skill-dir>/scripts/drive-status` explicitly. If you cannot locate it, say so — do not
infer the phase by hand.

It prints repo, branch, cleanliness, gate command, bead counts, PR state, spec files, and
an inferred phase. Read it, then confirm the inference against `DRIVE.md` if present.
**Never guess the phase.**

Its `pr` field is the one output to distrust in both directions. It reads review
wrappers, so a PR that two bots have approved by *reaction* still prints `no-review` —
`+1` from `chatgpt-codex-connector[bot]` lives on the issue reactions endpoint, and
CodeRabbit's verdict is a status check. Confirm with `pr-with-codex-bot-review`'s queries
before believing either that a reviewed PR is unreviewed (you re-run HARDEN for nothing)
or that a `SUCCESS` check means a review happened.

That second direction is a LAND gate, not a caution. **CodeRabbit reports `SUCCESS` when
it *skips*** — on a rate limit, or when it judges the diff similar to previous changes —
and LAND requires that both bots cleared the tree, which a skip did not do. So a `SUCCESS`
check counts as cleared only once you have read the walkthrough comment's "Files skipped
from review" list and can say the skip was expected. An unexplained skip, a rate-limit
skip, or a skipped file that is part of this change is **not cleared**: `@coderabbitai
review` to re-trigger, and wait. `pr-with-codex-bot-review` § 7 carries the same rule and
the query.

**The record wins when it exists; the tree wins when it does not.** `DRIVE.md` is written
at every transition, and several phases leave no trace git can distinguish — a `PROVE`
branch and a `HARDEN` branch are byte-identical, a spec committed but not yet reviewed
looks finished, and a dirty tree cannot say whether the edit is implementation, a test
being authored, or a reviewer fix being applied. So the detector reports three things:
`phase` (what to act on), `tree_phase` (what the tree alone suggests), and whether they
disagree.

A disagreement is information, not an error. It usually means a transition was interrupted.
Read both, decide, and **state your reason** if you override the record — an unexplained
override silently skips that phase's exit gate. If the record is genuinely stale (the user
just handed you a new goal), say so and rewrite `DRIVE.md` as your first act.

Route to the first phase whose exit gate is not yet satisfied. `--phase <name>` overrides
the inference and *starts* there — it pins the entry point, not the exit; the drive still
runs forward through every later phase. Use it when the detector is wrong or the user
wants to re-run a phase.

| Phase | Entry condition | Skill it runs | Exit gate (evidence required) |
|---|---|---|---|
| **SHAPE** | Goal is prose; no reviewed spec | `planning-workflow`, `grill-with-docs`, `spec` | Spec file committed **and** a codex xhigh review returns no P0/P1 |
| **GRAPH** | Spec exists; no bead graph covering it | `plan-to-beads-transfer` → `bead-polish-loop` → `second-model-bead-audit` | Audit verdict PASS; a **scoped** `br ready` bead exists (see `Scope:` in `DRIVE.md`) |
| **BUILD** | A ready bead exists | `orchestrating-with-rb-lite` (one bead = one branch) | rb-lite exits clean **and** you independently ran the gate |
| **PROVE** | Bead's deliverable is a test/gate, or the change touches money/data/infra | gate folded into the BUILD task, **or** a separate test bead run through `testing-with-rb-lite` — decide *before* BUILD starts, since a second rb-lite run on the same branch is forbidden | The gate **ran** and printed green, with the real exit code |
| **HARDEN** | Branch has unreviewed substantive code | `multi-reviewer-loop` (its "ask the user at the end" step is satisfied by the drive goal — keep going; its stop-list still applies), then a final pinned `codex review --base <ref>` | `multi-reviewer-loop` reports `CLEAN` — both reviewers clean **and** its consistency pass clean, on the same tree; gate green at a real exit code |
| **LAND** | Nothing uncommitted or unreviewed is left in the tree, and the branch tip **is** the tree HARDEN went clean on | `pr-with-codex-bot-review` | Merged SHA is that same SHA and both bots cleared **it**; branch reset; bead closed and `DRIVE.md` updated **by a reviewed path** — never as a commit pushed after clearance (see below) |
| → **BUILD** | More ready beads **in scope** | — | loop until the scoped set is empty — not the repository backlog |

Full per-phase mechanics, including how to skip phases legitimately, live in
`references/phases.md`.

### LAND merges the reviewed tree, not the current one

Sweep everything into the branch **before** HARDEN, then review, then land. Bookkeeping
counts: `DRIVE.md`, the beads JSONL, a stray comment fix you noticed on the way past.

A commit added after the panel went clean puts the branch back in HARDEN — including one
that only touches bookkeeping. This is not pedantry about a JSONL file; it is that "the
panel was clean" and "the thing I am merging was reviewed" quietly stop being the same
sentence the moment a commit lands between them, and every dashboard keeps saying
`reviewed` regardless. The multi-reviewer-loop already states this for its own passes
("fixing something after either pass means that tree was never reviewed"); LAND is where
it gets violated, because bookkeeping does not feel like a change.

So, before merging, name the three SHAs out loud and refuse if they differ:

```text
panel clean on : <sha>
bots cleared   : <sha>
merging        : <sha>
```

**Get the middle one from the review wrapper, not from the reaction.** The codex bot's
`+1` is a reaction on the issue — it carries a timestamp and no SHA, so after an amend and
force-push a lingering `+1` from the previous head reads exactly like approval of the
current one. Its review wrapper comment *does* name the tree it read (`**Reviewed
commit:** <sha>`), and that is the value to compare:

```bash
gh api repos/<owner>/<repo>/pulls/<N>/reviews \
  --jq '.[] | select(.user.login|startswith("chatgpt-codex-connector"))
        | .body | capture("Reviewed commit:[^0-9a-f]*(?<sha>[0-9a-f]{7,40})").sha'
```

(`[^0-9a-f]*` and not `\D*`: the wrapper writes the SHA inside backticks, and `\D` treats
`a`–`f` as skippable, so a hash beginning with hex letters gets silently truncated to its
tail — a comparison that looks like it works and passes whenever the SHA happens to start
with a digit.)

If the bot reacted `+1` without leaving a wrapper (its silent-approval path), you have no
SHA anchor: `@codex review` and wait for one rather than reading the reaction as coverage
of the current tip. CodeRabbit's check is per-commit, so its `SUCCESS` already refers to
the head it ran on — but it still has to be a review and not a skip (see Phase 0).

### Bookkeeping goes in before the panel, or through its own PR

`DRIVE.md` and the beads JSONL are the two files this skill itself writes, so they are the
ones most likely to land after clearance. Guard 4 rewrites `DRIVE.md` at every transition
and LAND runs `br close` — neither is optional, so the ordering has to be stated rather
than left to be discovered when the gate fails.

**Before the merge — fold it into the final HARDEN sweep.** The commit that sets
`**Phase:** LAND` is the *last commit before* the final panel run, not the first one after
it. The panel clears a tree that already says LAND, the tip stays that SHA, and nothing is
added between clearance and merge.

Two consequences worth stating, because getting them wrong is the loop:

- **`Phase: LAND` on a branch whose panel has not yet cleared means "LAND is next", not
  "LAND has begun."** LAND's entry condition — tip equals the cleared SHA — is what
  actually admits it. The record is not lying; it is pointing one step ahead.
- **A re-review round inside HARDEN does not rewrite the record back to `HARDEN`.** If the
  panel finds something, fix it, commit, re-run the panel — the line still reads LAND
  throughout. Rewriting it back is what turns "commit after clearance returns you to
  HARDEN" into a cycle that never terminates, because every rewrite is itself a commit
  after clearance.

**After the merge — `br close` cannot ride that branch.** Closing the bead before the
merge marks work done that may still fail to land, so the closure is genuinely post-merge
and genuinely unreviewed if committed straight to the default branch. That is the exact
incident this section exists for, so it does not get an exception for being ours:

- **A scoped bead remains** → carry the closure and the `DRIVE.md` update into the next
  bead's branch. It rides that PR through the panel and both bots with everything else.
- **The scope is empty** → open one small metadata PR (bead closure + final `DRIVE.md`)
  and land it through the same gates. DONE is not reached until it merges.

Do not commit them to the default branch and push, even where the branch permits it and
the repo's history is full of exactly that. That history is a convention about *where*
bookkeeping goes, not a licence to skip review — and it is what leaves a default branch
carrying a commit no reviewer and no bot ever saw while every dashboard still reports the
work as reviewed.

### Sizing — do not run the whole machine for a typo

- **≤ a couple of lines, mechanical and self-evident** → edit directly, run the gate,
  commit, push. No spec, no bead, no rb-lite — the orchestration overhead only pays off
  when the change is big enough to need review convergence.
- **Bounded, one or two files, clear** → skip SHAPE/GRAPH. Go straight to BUILD.
- **Multi-file, needs design judgment, or a new invariant** → full pipeline from SHAPE.

Say which size you picked and why, in one line. Then go.

## The four guards

These are the automated versions of interventions the user currently performs by hand.

### Guard 1 — Evidence, not assertion

A phase closes on evidence or it does not close.

- Run the real gate yourself. rb-lite's panel and every reviewer **read** code; they do
  not **run** it. A clean panel is not a passing build.
- **Never pipe a gate through `tail`/`head`/`grep`.** The pipeline exit code is the last
  stage's, so a red gate reports 0. (See `references/autonomy-contract.md` § 2.)

  ```bash
  <gate-cmd> > /tmp/gate.log 2>&1; echo "EXIT=$?"
  ```

  Then read the log. Quote the command and the exit code in your report.
- For a test you just wrote: make it **fail first** against the unfixed code, then pass. A
  green test that never could have gone red proves nothing.
- Words that need a number or an exit code behind them: "passing", "working", "clean",
  "verified", "done". Without one, say what you actually observed instead.

### Guard 2 — Scope budget (the overengineering brake)

Declare before entering BUILD, in the task file:

- exact file list (file-lock — forbid all others from round 1), **plus a standing
  exemption for `DRIVE.md` and the beads JSONL**. Guard 4 rewrites `DRIVE.md` at every
  transition and LAND runs `br close`, so a lock that forbids them forbids the
  bookkeeping this skill requires. Exempt them; do not spend budget on them. The exemption
  is from the **budget**, not from review — they ride the same branch, the same panel and
  the same bots as everything else (see "LAND merges the reviewed tree").
- rough LOC budget
- an explicit **do NOT build** list: defensive edges, abstractions, and config knobs
  beyond this milestone
- done-definition tied to named tests

Then watch each round. Two proxies raise the alarm — **round count climbing** and **LOC
far past comparable work**. Proxies only flag; confirm by re-reading the goal and asking
whether what got built matches what the goal actually requires. When they diverge, cut
back to the goal.

Hard brake: **at 2× the LOC budget or round 4, stop and report** rather than feeding
another round. That is a stop-list item.

Keep `--min-findings-severity` open at first — P2/P3 are often genuine polish. Raise the
floor to P1 only once that stream has turned into gold-plating. `--max-rounds` is a
checkpoint to assess and relaunch, not a finish line. (See
`references/autonomy-contract.md` § 4.)

### Guard 3 — Transitions fire their own gates

Committing, pushing, reviewing, and opening the PR are **parts of a phase transition**,
not separate requests. When a phase's gate goes green:

1. Commit with a real message. 2. Push. 3. Fire the next phase's reviewer.

Do not report a green gate and wait. The user should never need to type "commit/push" or
"call codex again" — if they do, this guard failed.

Exception: the stop-list. Never auto-push to a protected branch. `--force-with-lease` on
**your own PR branch** is part of LAND (amending after bot findings) and is allowed; a
force-push to a shared or protected branch, over someone else's work, or without a lease,
is not.

### Guard 4 — Durable state (`DRIVE.md`)

Maintain `DRIVE.md` at the repo root. Rewrite it at **every phase transition**, before
starting the next phase. It exists so a fresh session resumes without re-deriving
anything, and so "status?" is already answered.

**One transition is written early: HARDEN→LAND.** Committing it *after* the panel clears
would invalidate the clearance LAND then requires, so the `**Phase:** LAND` edit goes into
the last commit *before* the final panel run, and HARDEN's own re-review rounds leave the
line alone. See § "Bookkeeping goes in before the panel, or through its own PR" — that
section is the authority on ordering; this one only records that the exception exists.

```markdown
# DRIVE — <goal, one line>

**Scope:** epic acme-M2 (beads acme-40..acme-49) — the ONLY beads this drive may take
**Phase:** BUILD · **Bead:** acme-42 · **Branch:** acme-42-retry-budget
**Gate:** `nix develop -c ./check.sh` · last green 2026-08-01 (exit 0)

## Done
- acme-40 validate destination addresses — merged #118
- acme-41 encode request-id in the audit log — merged #119

## Now
acme-42: wire the retry budget into prod. Budget: 3 files, ~250 LOC. Round 2 of max 4.
Do NOT build: retry policy config, pluggable backends.

## Next
acme-43 (blocked on 42) → acme-44 → re-audit graph

## Open questions for the human
- none
```

Commit it with the work. Keep it under a screen — it is a resume point, not a log.

**`Scope:` is the one canonical definition and every phase reads it.** `drive-status`
counts the whole repository — it cannot know your scope — so its bead numbers and its
`DONE` are repository-wide. Filter them through `Scope:` before believing either. GRAPH
needs a *scoped* ready bead, BUILD may only take a bead inside the scope, and DONE means
the scope is empty, not the backlog. Without this line a fresh session inherits the goal
but not its boundary, and will happily pick up unrelated work.

## Reporting

At each transition, one compact block. No preamble, no re-explaining what the user asked.

```text
✅ BUILD acme-42 — clean in 2 rounds, 3 files, +180 LOC (budget 250)
   gate: nix develop -c ./check.sh → EXIT=0
   → HARDEN: launching codex + fable panel now
```

If a background job is running, say what you're waiting on and that you'll continue
automatically. Then actually continue — do not stop and wait to be pinged.

## Self-continuation across turns

**Claude Code only, and check before relying on it.** `/goal` is a harness built-in — it
has no file under `~/.claude/commands` and no Codex equivalent, so a filesystem search will
not find it. Confirm it exists in your build with `/help` before depending on it; if it is
absent, the continuation contract above is the only mechanism and you follow it that much
more strictly. Never report a backlog as "being drained by the hook" without having seen
the hook confirm it is active.

If the drive spans a long backlog and you have been stopping early, set a session goal so
the harness enforces continuation:

```text
/goal drain all ready beads for <project>
```

That installs a session-scoped Stop hook that blocks the session from idling until the
condition holds. Use it when the user hands over a backlog rather than a single bead. Do
not tell them to clear it afterwards; it auto-clears when the condition is met.

## Reference

- `references/phases.md` — per-phase mechanics, skip rules, failure recovery
- `references/autonomy-contract.md` — the intervention patterns this skill automates,
  with the transcript evidence behind each rule
