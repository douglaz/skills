# Dedupe Heuristics

Load this file during the duplicate pass.

## Exact duplicate signals

Two beads are probably duplicates if most of these are true:

- they own the same deliverable or acceptance signal
- they affect the same subsystem or workflow slice
- they cover the same failure path or operator obligation
- one adds no meaningful extra rationale, constraints, or tests

## Near-duplicate signals

Two beads may need merging or re-scoping if:

- one is a thin slice of the other with no independent claim value
- both own the same verification obligation
- both depend on the same predecessors and unblock the same successors
- the distinction is title-deep but not execution-deep

## Survivor selection rules

Keep the canonical survivor with the best combination of:

- richer rationale
- richer testing specs
- clearer verification
- better dependency placement
- more precise scope boundaries
- correct priority

Merge anything worth keeping from the loser into the survivor before closing the loser.

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
