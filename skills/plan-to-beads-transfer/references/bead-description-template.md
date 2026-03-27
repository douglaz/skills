# Bead Description Template

Load this file when you are creating or rewriting bead descriptions.

Use this structure when the bead is material enough that future agents could
misread its purpose. Shorter beads can compress the wording, but they should
still preserve the same information.

```markdown
## Outcome
What behavior, capability, or user-visible/system-visible result should exist
after this bead is done?

## Why this exists
Why does the project need this? What user, product, or operational goal does it
serve?

## Scope
What is in scope for this bead?

## Non-goals
What is explicitly not part of this bead?

## Key implementation notes
Important interfaces, data flows, sequencing assumptions, migration details, or
tricky constraints that the next agent must not miss.

## Dependencies / ordering
What must already exist, and what will this unblock?

## Verification
- Unit tests:
- Integration or e2e tests:
- Logging / observability / diagnostics:
- Acceptance signal:

## Spec refs
List the relevant plan sections, filenames, or approved deltas.
```

## Compression rules

You may compress headings into paragraphs for tiny beads, but never omit:

- outcome
- why
- dependencies or ordering
- verification

## Good writing rules

- Prefer concrete behavior over generic implementation verbs.
- Mention failure handling when the plan calls for it.
- Spell out the decisive test or validation signal.
- Include gotchas if a future agent would likely make the same mistake without
  them.
