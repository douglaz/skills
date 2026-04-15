# Plan-to-Beads Coverage Matrix Template

Load this file during transfer audits and later polishing passes.

Use a simple table or checklist like this while translating the plan:

| Plan element | Kind | Why it matters | Covered by bead IDs | Status | Notes |
|---|---|---|---|---|---|
| Upload success path | Workflow | Core user flow | br-101, br-104 | Covered | Parser and UI split across two beads |
| Upload failure handling | Failure path | Operator visibility | br-102 | Covered | Includes retry surface |
| Auth boundary | Constraint | Security-critical | br-107 | Partial | Need explicit admin-only acceptance checks |
| E2E coverage | Verification | Ship gate requirement | br-111 | Covered | Must include logging |

Typical `Kind` values:

- workflow
- operator flow
- failure path
- constraint
- migration / rollout
- verification
- docs / enablement

## What must appear in the matrix

- primary user workflows
- admin/operator workflows
- failure, retry, and recovery paths
- constraints, non-goals, and security boundaries
- migration, rollout, compatibility, or docs obligations
- test, logging, diagnostics, and observability obligations

## Decision rules

- If one plan element maps to no bead, add or rewrite beads until it does.
- If one bead maps to no approved plan element or approved delta, challenge the bead.
- If one bead owns too many unrelated plan elements, split it.
- If two beads map to the same narrow obligation, inspect for duplication.
- If coverage only exists implicitly, enrich the bead description until the connection is obvious to a fresh agent.
