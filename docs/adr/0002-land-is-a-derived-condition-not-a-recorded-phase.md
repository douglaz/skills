# LAND is a derived condition, not a recorded phase

LAND must merge exactly the tree the review panel cleared, so any commit after clearance
invalidates it — including the commit that records the transition into LAND. We resolved
this by not recording LAND at all. `Phase` stays committed and honest, stopping at HARDEN;
LAND is admitted by computing `Cleared == tip` against the volatile store, together with
a base still an ancestor of that tip and a clean worktree.

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
