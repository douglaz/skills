# LAND is a derived condition, not a recorded phase

LAND must merge exactly the tree the review panel cleared, so any commit after clearance
invalidates it — including the commit that records the transition into LAND. We resolved
this by not recording LAND at all. `Phase` stays committed and honest and simply never names LAND;
LAND is admitted by computing `Cleared == tip` against the volatile store, together with
a base still an ancestor of that tip, that base still being the one the panel reviewed,
and a clean worktree. Four conditions — see the amendment below, which added the third
and is the reason this sentence names it rather than the three originally decided.

## Considered Options

Writing `Phase: LAND` *before* the final panel run was tried first. It works, but it costs
the record its self-sufficiency: a session that dies mid-panel leaves byte-identical state
to a cleared one, so the record had to be propped up with a clearance marker, a rule that
re-review rounds must not rewrite the line, and a detector that downgrades unproven LAND
back to HARDEN. Three mechanisms to make one dishonest field safe.

Moving `Phase` wholly into volatile state was the other candidate. Rejected: a fresh
session would lose the PROVE/HARDEN distinction, which git cannot express and which the
committed record exists to preserve.

## Consequences

Deleted outright: the write-ahead, the "re-review rounds leave the line alone" rule, the
unproven-LAND downgrade, the "nothing uncommitted except the marker" carve-out, and the
discard-the-marker-before-checkout step. Each of those existed only to contain the
dishonest field.

No record can now claim LAND falsely, because no record claims LAND at all.

The general rule this generalises to: a phase whose truth is a property of the current
checkout must be derived, never recorded. Recording it means the record can outlive the
fact.

---

## Amendment, 2026-08-05: a fourth condition

The derivation above lists three conditions. A fourth was added later: the current base
must still be the one the panel reviewed, recorded as `cleared_base` beside `cleared`.

Retargeting a PR to an older ancestor after clearance leaves `HEAD` untouched and the new
base still an ancestor of it, so `cleared == tip` and base-freshness both continue to hold
while the PR's diff has silently grown to include commits no panel read. Every SHA matches
and nothing else notices.

The decision this ADR records is unchanged — LAND is derived, never recorded. Only the set
of facts it is derived from grew.
