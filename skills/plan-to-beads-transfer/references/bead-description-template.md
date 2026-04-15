# Bead Description Template

Load this file when creating or rewriting material beads.

Use this structure whenever a future agent might otherwise need to reopen the original plan.

```markdown
## Outcome
Describe the concrete behavior, capability, or operator-visible result that should exist after completion.

## Why this exists
State the user, product, architectural, or operational reason.

## Scope
List what this bead owns.

## Non-goals
State what this bead explicitly does not own.

## Critical constraints and failure handling
Record interfaces, data boundaries, migrations, security rules, rollout notes, retry/recovery paths, operator hooks, or edge cases that must survive transfer from the plan.

## Dependencies / ordering
State what must exist first, what this bead depends on, and what it unblocks.

## Verification
- Unit tests:
- Integration / e2e:
- Logging / observability / diagnostics:
- Acceptance signal:

## Spec refs
List the relevant plan sections, files, or approved deltas.
```

## Compression rules

You may compress headings into paragraphs for tiny beads, but never omit:

- outcome
- why
- dependencies or ordering
- verification

For user-facing or operationally sensitive work, keep constraints and failure handling explicit too.

## Writing rules

- Prefer concrete outcomes over vague implementation verbs.
- Spell out the decisive test or ship gate.
- Include the important "future self" context, not every detail from the plan.
- If one concept spans multiple beads, make one bead the canonical concept carrier and let dependents point back to it.
