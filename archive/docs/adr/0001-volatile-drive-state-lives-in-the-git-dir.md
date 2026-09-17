# Volatile drive state lives in the git dir, not the worktree

`DRIVE.md` accumulated seven fields with three incompatible storage semantics — committed
narrative, a field written ahead of the event it records, and a deliberately-uncommitted
marker inside a tracked file. Four rounds of review findings all landed on the seams
between them. We split by lifetime: `DRIVE.md` keeps the committed narrative, and
per-checkout facts move to `$(git rev-parse --git-path drive/state)`.

## Considered Options

A gitignored `.drive/state` in the worktree was the obvious candidate and is wrong: the
`.gitignore` entry is itself a repo mutation, which under this skill's own rules must ride
a reviewed PR before the first drive can start. An untracked file is worse — measured, it
flips phase inference from SHAPE to BUILD, because the detector classifies any non-doc,
non-bead path as code.

Keeping everything in `DRIVE.md` and documenting the three semantics was the status quo
made honest. Rejected: it preserves every workaround, and the next field added inherits
the same seam.

## Consequences

A path under the git dir needs no ignore entry, is invisible to `git status`, survives
`checkout`, `reset --hard` and `clean -xdf`, and is naturally per-worktree.

The cost is that volatile state is invisible to a human reading the repo, and a stale file
fails quietly rather than as a visible diff. Mitigated by `drive-status` printing the
marker and treating a mismatch as invalidation rather than fact.

A fresh clone has narrative but no clearance. That is correct, not a regression: clearance
is a claim about a panel run in a particular checkout, and a commit cannot record that its
own SHA was reviewed without changing that SHA.
