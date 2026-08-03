# Skills

A collection of Claude Code and Codex skills, installed by symlink into both tools.
Each skill is a `SKILL.md` plus optional `references/` and `scripts/`.

## Language

### Driving a project

**Drive**:
One goal pursued to completion through the software lifecycle, without returning to the
user between phases.
_Avoid_: run, session, pipeline

**Phase**:
A named stage of a drive with an entry condition and an exit gate. Only phases whose
completion is durably true may be recorded; conditions that are only true of the current
checkout are derived instead.
_Avoid_: step, stage, state

**Record**:
The committed narrative of a drive, in `DRIVE.md`. Durable, survives a fresh clone, and
answers "where are we" without re-deriving anything.
_Avoid_: state file, status file

**Volatile state**:
Facts true only of the current checkout — chiefly which tree a panel cleared. Never
committed, and correctly absent from a fresh clone.
_Avoid_: cache, scratch, local state

**Scope**:
The bead set a drive is authorized to take. The canonical boundary every phase reads; a
ready bead outside it is not this drive's work.
_Avoid_: milestone, epic, backlog

### Review and admission

**Panel**:
Two or more independent reviewers reading the same tree in parallel, whose findings are
merged before any are acted on.
_Avoid_: review, reviewer, pass

**Clearance**:
A panel having found nothing on a specific tree. Attaches to that tree alone — a later
commit does not inherit it.
_Avoid_: approval, sign-off, green

**Gate**:
A command that proves the repo is healthy, judged by its real exit code.
_Avoid_: check, build, CI

**Bot round**:
One cycle of a forge review bot examining a pushed head and the author answering it.
Distinct from a panel: bots review what was pushed, panels review what is about to be.
_Avoid_: review round, CI round

**Evidence**:
A command and its exit code, or a quoted line of output. The only thing that closes a
phase; an assertion that something passed is not evidence.
_Avoid_: verification, proof, confirmation
