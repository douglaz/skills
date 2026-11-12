# Skills

A collection of Claude Code and Codex skills, installed by symlink into both tools.
Each skill is a `SKILL.md` plus optional `references/` and `scripts/`.

## Language

The lifecycle vocabulary (drive, phase, record, scope) went to `archive/` with the
`drive` skill; see `archive/README.md`.

### Review and admission

**Panel**:
Two or more independent reviewers reading the same tree in parallel, whose findings are
merged before any are acted on.
_Avoid_: review, reviewer, pass

**Severity**:
A finding's P0–P3 rating measures what the defect does, not where it sits. P0 is
critical (data or money loss, secrets, security, core crash/corruption, brief
fundamentally failed). P1 blocks acceptance: wrong supported behaviour, unmet
brief, a test/gate that cannot fail or fails for the wrong reason, or false or
contradictory requirements. Reachable money-loss/misdirection, secret-exposure or
data-corruption defects are at least P1. P2 is a real non-blocking defect; P3
changes neither behaviour, requirements nor a check's ability to catch defects.
The judge re-rates; lowering P0/P1 needs file:line evidence, raising to P0/P1
names the clause. Only introduced or brief-blocking P0/P1 sends work back.
_Avoid_: bead priority (a separate scheduling field), reviewer verdict

**Follow-up**:
An accepted P2/P3, or older P0/P1 outside the brief, filed when the work ends, if it still holds then.
Each skill names its filing reference state. P2/P3 are never repaired in the same
change, even alongside P0/P1 repairs. One issue per distinct defect, deduped only
against the same defect open at equal or higher priority: P2 priority 2
`review-followup`, P3 priority 3 `review-nit`, older P0/P1 its own priority
`review-preexisting`. Drains skip `review-nit` unless asked; delegated drains also
exclude `review-followup` until named. An accepted suggestion is reported once,
not filed, unless judged a P0–P3 defect. No tracker means a list in the report or
PR body. See the [filing rules](skills/multi-reviewer-loop/references/disposition-rules.md#filing-follow-ups)
for required evidence and deduplication.
_Avoid_: repair, blocker, suggestion

**Clearance**:
A panel having found nothing on a specific tree. Attaches to that tree alone — a later
commit does not inherit it.
_Avoid_: approval, sign-off, green

**No pending evidence**:
The strongest thing a forge review bot's behaviour can establish: over a bounded window of
observation, nothing indicated an unfinished bot round or a finding left undispositioned.
Strictly weaker than Clearance — it is the absence of a signal, not the presence of a
verdict, and it says nothing about the moment after the window closes.
_Avoid_: clearance, cleared, approved, green, bot sign-off

**Gate**:
A command that proves the repo is healthy, judged by its real exit code.
_Avoid_: check, build, CI

**PR-level signal**:
A bot state attached to a pull request rather than to a tree. It moves to whatever head
exists when the bot posts it, so it may describe work done on a different commit — or no
work at all. Never evidence about a tree, however green it looks.
_Avoid_: green, passing, the check, bot approval

**Bot round**:
One cycle of a forge review bot examining a pushed head and the author answering it.
Distinct from a panel: bots review what was pushed, panels review what is about to be.
A round has no observable end — the bots emit no terminal signal — so its completion is
inferred, never read. See No pending evidence.
_Avoid_: review round, CI round

**Evidence**:
A command and its exit code, or a quoted line of output. The only thing that closes a
phase; an assertion that something passed is not evidence.
_Avoid_: verification, proof, confirmation
