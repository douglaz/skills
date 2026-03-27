# Plan-to-Beads Coverage Matrix Template

Load this file during the transfer audit.

Use a simple table or checklist like this while translating the plan:

| Plan element | Why it matters | Covered by bead IDs | Gap? | Notes |
|---|---|---|---|---|
| Upload success path | Core user flow | br-101, br-104 | No | Parser and UI split across two beads |
| Upload failure handling | Operator visibility | br-102 | No | Includes retry surface |
| Auth boundary | Security-critical constraint | br-107 | Maybe | Need explicit admin-only acceptance checks |
| E2E coverage | Ship gate requirement | br-111 | No | Must include logging |

## What must appear in the matrix

- primary user workflows
- admin/operator workflows
- error and retry paths
- constraints and security boundaries
- migration or rollout obligations
- test and diagnostics obligations

## Decision rules

- If one plan element maps to no bead, add or revise a bead.
- If one bead maps to no approved plan element or approved delta, challenge the bead.
- If one bead owns too many unrelated plan elements, split it.
- If two beads map to the same narrow obligation, inspect for duplication.
