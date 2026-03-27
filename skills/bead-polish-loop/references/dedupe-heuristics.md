# Dedupe Heuristics

Load this file during the duplicate pass.

## Exact duplicate signals

Two beads are probably duplicates if most of these are true:

- same deliverable or same acceptance signal
- same affected files or same subsystem
- same user workflow and same failure path
- one adds no meaningful extra rationale or constraints

## Near-duplicate signals

Two beads may need merging or re-scoping if:

- one is a thin slice of the other with no independent claim value
- both own the same test obligation
- both depend on the same predecessor and unblock the same successor
- the distinction is title-deep but not execution-deep

## Survivor selection rules

Keep the canonical survivor that has the best combination of:

- richer rationale
- clearer verification
- better dependency placement
- more precise scope boundaries
- correct priority

Merge missing strengths from the loser into the survivor before closing the
loser.

## When not to merge

Do not merge merely because two beads are related. Keep them separate when:

- they can be claimed independently
- they land on different dependency tracks
- they protect different user or operator outcomes
- merging would create a vague umbrella bead

## Good closure pattern

If bead B is merged into bead A:

1. enrich bead A with anything worth keeping from B
2. close B with a clear reason
3. update dependencies that pointed at B
4. rerun the frontier check
