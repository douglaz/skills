# Bead closure stays post-merge

`br close` runs after the squash merge, and the resulting bookkeeping reaches the default
branch through a reviewed path — carried into the next bead's branch, or via a small
metadata PR when the scope is empty. It does **not** run on the feature branch before the
review panel.

This is recorded because the opposite is highly attractive and was proposed by a reviewer
with a compelling argument: `.beads/issues.jsonl` is a tracked file, so a closure committed
on a branch looks transactional — canonical only on merge, dead if the PR is abandoned.
That argument is wrong, and expensive to re-derive.

## Why

Verified against the `br` implementation (`beads_rust`), not from documentation:

- `br close` writes the JSONL immediately. `auto_flush` runs after every mutating command
  (`src/main.rs:322`); there is no daemon and no timer.
- Import is per-issue last-write-wins on `updated_at`. `determine_action` returns
  `Skip { "Existing is newer" }` when the incoming record is older
  (`src/sync/mod.rs:2933`).
- So after `git checkout <default>`, the default branch's older OPEN record loses to the
  DB's newer closure. The DB says closed, the branch's JSONL says open, and nothing errors.
  Reads on the default branch report the bead closed, and the next full export writes that
  into its JSONL.
- There is one SQLite DB per `.beads/` directory, shared by every branch. Nothing in the
  storage or sync layer consults git; `sync.branch` exists as a config key with no consumer
  (`src/config/mod.rs:2790`).
- There is no git merge driver. `br sync --merge` is an explicit CLI operation and never
  runs during `git merge`.

Only `--force` makes the JSONL win over a newer DB row, so even an explicit
`br sync --import-only` after checkout does not undo the leak.

## Consequences

Branch-local closure remains possible with strict hygiene — commit the JSONL before any
checkout, and run `br sync --import-only --force` after every checkout before any other
mutation, plus a compensating `br reopen` on every abandoned PR. Rejected: its correctness
depends on an ordering rule that must never once be forgotten, and its failure mode is a
silently wrong graph. The post-merge path is uglier, but a stranded closure is visible.

`Pending:`, the metadata PR, and carry-into-next-branch therefore stay.

Revisit if `br` gains branch awareness in the storage layer; the atomic-land option reopens
immediately if it does.
