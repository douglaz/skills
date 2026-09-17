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
