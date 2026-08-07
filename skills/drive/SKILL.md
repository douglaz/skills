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
4. **Scope budget blown** — see Guard 2. A PR still producing bot findings after three
   rounds is the same signal: the change is wrong-shaped, not one patch short.
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

**If you are recalling this skill rather than reading it now, re-read the on-disk copy
before following it.** A copy loaded earlier in a session, or carried through a context
summarisation, may predate a script that replaced prose — this skill and
`pr-with-codex-bot-review` both moved load-bearing logic out of their text and into
`scripts/`, and remembered prose is then a version that was retired for being wrong. The
tell is a procedure you can recite in full without having opened a file this turn.

It prints repo, branch, cleanliness, gate command, bead counts, PR state, spec files, the
cleared SHA, and an inferred phase. `scripts/drive-status.test` covers the derivation —
one case per real defect, against scratch repos and a stubbed `gh`, each shown to go red against a
real defect. Run it after touching the phase logic. Read it, then confirm the inference against `DRIVE.md`
if present. **Never guess the phase.**

### Install the working agreement, once per repo

Invoke the **`agents-md` skill** with `--check` — as a skill, not a shell command; it is a
skill directory, not a PATH executable. `--check` is read-only and reports whether the
block is present *and* current. If it says absent or stale, invoke `agents-md` without
`--check`. It is a no-op on every later run.

These rules only bind agents that read them, and `AGENTS.md` is the only place they travel
— including to the rb-lite implementers and reviewer panels this skill spawns. `agents-md`
writes but never commits.

**Who carries the edit depends on where the drive entered.** If a BUILD branch is coming,
leave it uncommitted and let that branch carry it through review like any other change. If
one is not — a drive resuming at HARDEN or LAND, or the tiny-change path that skips BUILD
outright — that instruction has no addressee, and the edit sits dirty until LAND's
clean-tree guard refuses the merge. Commit it onto the current branch instead and let the
panel and the bots review it there. Do not leave it for a branch that will never exist.

### Reading the `pr` field

Distrust it in both directions — it reads review wrappers, so a PR two bots approved by
*reaction* still prints `no-review`, and a `SUCCESS` check may be a *skip* rather than a
review. `pr-with-codex-bot-review` § 7 owns the rules for both and carries the queries.

**Bot approval is never clearance.** LAND is admitted by the *local* `cleared` marker
alone. A fresh clone has no marker by design, however thoroughly the bots approved — so
"the bots already approved, no need to re-run HARDEN" is the bypass the derivation exists
to prevent. Use PR state to avoid *duplicate bot rounds*, never to skip the panel.

**The record is the default when it exists; the tree is the fallback when it does not** —
with three exceptions the detector announces, where the record cannot honestly describe
this checkout (see Guard 4). `DRIVE.md` is written
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
| **BUILD** | A ready bead exists | `orchestrating-with-rb-lite` (one bead = one branch) | rb-lite exits clean, you ran the gate yourself at a real exit code, **and** each load-bearing behavior the bead introduced was inverted with its pinning assertion observed to fail |
| **PROVE** | Bead's deliverable is a test/gate, or the change touches money/data/infra | gate folded into the BUILD task, **or** a separate test bead run through `testing-with-rb-lite` — decide *before* BUILD starts, since a second rb-lite run on the same branch is forbidden | the gate ran green at a real exit code **and** a matching assertion was observed to FAIL for every property it claims; quote both runs. Green alone does not close PROVE |
| **HARDEN** | Branch has unreviewed substantive code | `multi-reviewer-loop` (its "ask the user at the end" step is satisfied by the drive goal — keep going; its stop-list still applies), then a final pinned `codex review --base <ref>` | `multi-reviewer-loop` reports `CLEAN` — both reviewers clean **and** its consistency pass clean, on the same tree; gate green at a real exit code |
| **LAND** | The panel cleared this checkout, `cleared` still equals the tip, the base is an ancestor of it *and* is still the base the panel reviewed, and the worktree is clean (derived, never recorded — see Guard 4). Exit needs `bot-gate` at `NO_PENDING_EVIDENCE` — no bot exposes a terminal "cleared" signal, so waiting for one never ends (ADR 0004) | `pr-with-codex-bot-review` | `bot-gate` exits 0 (`NO_PENDING_EVIDENCE`) and no bot thread is left unresolved — never "the bots cleared it", which ADR 0004 shows cannot be observed; base still fresh at merge time, squash-merged, branch reset; bead closed and `DRIVE.md` updated **by a reviewed path** |
| → **BUILD** | More ready beads **in scope** | — | loop until the scoped set is empty — not the repository backlog |
| **DONE** | The scope is empty — not the repository backlog | — | Any outstanding closure has merged. A `Pending:` PR that has not merged is `WAITING_FOR_MERGE`, not DONE |

Full per-phase mechanics — including how to skip phases legitimately, LAND's SHA and
base-freshness checks, the bot-round cap, and the closure path — live in
`references/phases.md`.

**LAND merges the tree the panel cleared, and nothing else.** That is the one invariant
worth carrying in your head: "the panel was clean" and "the thing I am merging was
reviewed" stop being the same sentence the moment a commit lands between them, and every
dashboard keeps saying `reviewed` regardless. Everything in `phases.md` about LAND is
machinery for keeping those two sentences identical.

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
- **A commit is not evidence its content landed.** `nothing to commit, working tree
  clean` is what you see both when the work is already committed and when it was
  destroyed underneath you — and an edit made while `codex review` is running *is*
  destroyed, silently, leaving nothing in the file or in `HEAD`. So never edit the repo
  while a review process is in flight, and take both checks the message hides:

  ```bash
  # Stage the paths this change touched — NOT `git add -A`. On the dirty tree § 1.6
  # permits, `-A` sweeps in another agent's edits and any untracked file lying around,
  # including a secret, and `git show --stat` only reveals that after the commit exists.
  git add -- <every path this change touched>
  git diff --cached          # READ IT NOW, while the index still has something in it.
                             # Staging by name still takes another agent's hunks from a
                             # file that was already dirty. After the commit this is
                             # empty, and `git show --stat` shows path names, not hunks.
  git commit -m "<msg>" || { echo "commit produced nothing"; exit 1; }
  _chk=$(mktemp); trap 'rm -f "$_chk"' EXIT
  git show --stat --format= HEAD        # does this list all of them, and only them?
  for f in <every file that gained new content>; do
    # Capture, do not pipe: `git show ... | grep -q` returns 141 under `pipefail` when
    # grep exits on an early match and git show takes SIGPIPE — verified — which reads
    # as "no match" and inverts both checks below.
    git show "HEAD:$f" >"$_chk" 2>/dev/null || { echo "$f did not land"; exit 1; }
    grep -Fq -- "<a distinctive phrase from that file's change>" "$_chk" \
      || { echo "$f did not land"; exit 1; }
  done
  # Removal-only edits have no new phrase to find, and any surviving phrase passes even if
  # the removal was reverted — so they belong here, NOT in the loop above. Existence first:
  # `git show HEAD:<gone>` fails, grep returns nonzero, and the `&&` is skipped, so an
  # accidental whole-file deletion reads exactly like a clean removal.
  for f in <every file you removed lines from>; do
    git show "HEAD:$f" >"$_chk" 2>/dev/null || { echo "$f is missing from HEAD entirely"; exit 1; }
    _n=$(grep -Fo -- "<a distinctive phrase you deleted>" "$_chk" | wc -l || true)
    # `|| true` because grep exits 1 on no match, and under `pipefail` that aborts the
  # whole check at exactly the case it must report: a COMPLETE removal, count 0.
  # COUNT the OCCURRENCES, not the matching lines (`grep -c` reports lines, so two
    # hits on one line count as one), and not absence: removing one of several
    # identical lines legitimately leaves the phrase behind, and demanding zero
    # rejects that correct commit.
    [ "${_n:-0}" -eq <occurrences expected AFTER the removal> ] \
      || { echo "$f: expected <n> occurrence(s) of the removed text, found ${_n:-0}"; exit 1; }
  done
  # Deletions are verified by ABSENCE — `git show HEAD:<path>` fails by design on a
  # deleted path, so folding them into the loops above fails every correct deletion:
  for f in <every path you deleted>; do
    git show "HEAD:$f" >/dev/null 2>&1 && { echo "$f is still present"; exit 1; }
  done
  ```

  The `||` catches a total loss — `git commit` with nothing staged exits **1**, however
  reassuring its message reads. The loop catches a partial one, which commits cleanly at
  exit 0. **Check every file, not one.** Grepping a single path proves only that path
  survived: if another file was reverted while your sample was left intact, the commit
  exits 0 and the grep passes, and the guard reports success for exactly the loss it was
  written to catch. Gates that passed *before* the loss are not evidence either; the work
  was real when they ran. See
  [multi-reviewer-loop/references/reviewer-panel.md](../multi-reviewer-loop/references/reviewer-panel.md).
- **`br` is not exempt — but know which failure you are guarding.** An *explicit*
  `br sync --flush-only` propagates a real exit code, so just require it to succeed. The
  *automatic* flush that follows a mutating command like `br close` does not: its error is
  caught and logged at debug level, so `br close` exits 0 with the JSONL unwritten. A
  closed bead is not a closed bead until an explicit sync has confirmed the write:

  ```bash
  # Divergence check FIRST — `br close` auto-flushes the cache over the tracked JSONL, so
  # an unstaged hand-edit is destroyed by this very command and neither the index nor HEAD
  # holds it. Capture separately: `[ -z "$(git status ...)" ]` discards git's exit code, so
  # a failed inspection would read as clean and let the write through.
  BEADS_JSONL=$(br where --json | jq -er '.jsonl_path') \
    || { echo "cannot resolve the beads JSONL — do NOT close"; exit 1; }
  _st=$(git status --porcelain -- "$BEADS_JSONL") \
    || { echo "cannot read the worktree — do NOT close"; exit 1; }
  [ -z "$_st" ] || { git diff HEAD -- "$BEADS_JSONL"
    echo "JSONL differs from HEAD — resolve that BEFORE closing"; exit 1; }
  br close <id> || { echo "br close failed"; exit 1; }
  br sync --flush-only || { echo "closure not persisted to the JSONL"; exit 1; }
  ```

  The explicit sync is the whole guard, and it needs to know nothing about the repo: the
  mutation is already in the shared DB, so the sync either writes it out or fails with a
  real exit code. This replaced a before/after fingerprint of the JSONL files, which had to
  know every beads layout, stay portable across GNU and BSD userland, and be captured
  before the first mutation — and got each of those wrong once, in review, across six
  copies of itself.

  That sync proves *your* write landed. It does not tell you what else it overwrote: a
  flush re-exports **every** bead from the gitignored `.beads/beads.db` over the tracked
  JSONL, so any body the cache holds a stale copy of is reverted, silently, at exit 0.
  Hand-editing `.beads/issues.jsonl` is what makes the cache stale — do not; use
  `br update -d/--notes`. Then field-diff the tracked JSONL before committing and read the
  changes — resolving its path rather than assuming it, with
  `br where --json | jq -er .jsonl_path`. `.beads/issues.jsonl` is only the default:
  `.beads.jsonl` and `<name>.beads.jsonl` are supported too, and a hardcoded path diffs
  nothing on those — a false all-clear in the direction that loses text. Detail and
  recovery:
  [orchestrating-with-rb-lite](../orchestrating-with-rb-lite/SKILL.md) step 11.


The rules above are what closes a *phase*. The fuller set on not lying about *edits* —
`sed -i` succeeding on zero matches, `&` silently doubling a replacement — lives in the
discipline block this skill installs at Phase 0, and applies to every agent in the repo.

### Guard 2 — Scope budget (the overengineering brake)

Declare before entering BUILD, in the task file:

- exact file list (file-lock — forbid all others from round 1), **plus a standing
  exemption for `DRIVE.md` and the beads JSONL**. Guard 4 rewrites `DRIVE.md` at every
  transition and LAND runs `br close`, so a lock that forbids them forbids the
  bookkeeping this skill requires. Exempt them; do not spend budget on them. The exemption
  is from the **budget**, not from review — they ride the same branch, the same panel and
  the same bots as everything else (`references/phases.md` § LAND).
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

### Guard 4 — Durable state (`DRIVE.md` + the volatile store)

State splits by **lifetime**, and the split is the whole design. Facts that stay true get
committed; facts true only of this checkout never do.

**`DRIVE.md`, committed, at the repo root.** Rewritten at every phase transition, before
starting the next one. It exists so a fresh session resumes without re-deriving anything,
and so "status?" is already answered.

```markdown
# DRIVE — <goal, one line>

**Scope:** epic acme-M2 (beads acme-40..acme-49) — the ONLY beads this drive may take
**Phase:** BUILD · **Bead:** acme-42 · **Branch:** acme-42-retry-budget
**Pending:** —
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

**Three states override even a valid record**, each announced in the output: a `HARDEN`
record with fresh clearance becomes derived LAND; a `DONE` record on a branch that still
has unmerged commits becomes HARDEN, because that record describes the world after its PR
lands rather than this checkout; and a `DONE` record with an unmerged `Pending:` PR becomes
`WAITING_FOR_MERGE`.

**`Phase:` never reads `LAND`.** LAND is *derived* — from `cleared == tip`, a base still
an ancestor of that tip, that base still being the one the panel reviewed
(`cleared_base`), and a clean worktree. All four: edits made after clearance leave
`HEAD` untouched, so the marker still matches while the commit a merge takes does not
contain them. A commit cannot honestly record that its own SHA was reviewed, because writing the
record changes the SHA — so the record does not try. `Phase:` simply never names LAND;
it is computed. This is why there is no write-ahead, no "leave the line alone during re-review"
rule, and no downgrade path for an unproven LAND: nothing can claim LAND falsely because
nothing claims it at all. (ADR 0002.)

**The volatile store, never committed, at `$(git rev-parse --git-path drive/state)`.**
Two facts matter: which tree a panel cleared, and which base it diffed that tree against.
A marker carrying only the first is refused — retargeting a PR to an older ancestor grows
the reviewed surface without moving `HEAD`, so `cleared` alone still matches:

```text
cleared=4456b8c0b8f1e2d3...
cleared_base=9f2a1c77e30b4d55...
```

Under the git dir, not the worktree, so it needs no `.gitignore` entry and survives
`checkout`/`reset --hard` (ADR 0001).

**Do not write it from here.** The moment a panel reports clean is precisely when the tree
is *dirty* — `multi-reviewer-loop` leaves its fixes uncommitted — so writing `HEAD` at that
instant records a commit the panel never saw. The guarded snippet in
`references/phases.md` § HARDEN has the four preconditions; use it.

A fresh clone has narrative but no clearance. That is correct: clearance is a claim about
a panel run in *this* checkout. Re-run the panel.

**`Pending: metadata PR owner/repo#N` stays committed**, because it is the one fact that
must reach a fresh clone: it is how a reader learns DONE is conditional on a PR. A record
reading `DONE` with a `Pending:` PR means "DONE once that PR merges" — query it. Qualify it
with the repository: a bare `#N` is ambiguous on a fork, where the same number names a
different PR in the parent and in the fork. `references/phases.md` § LAND covers the
ordering.

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
