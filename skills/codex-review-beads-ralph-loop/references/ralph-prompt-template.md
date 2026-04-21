# Ralph-burning prompt template

Save one of these per bead at `.ralph-burning/prompts/<bead-id>.md`. The
sections here are not decoration — `ralph-burning`'s reviewer panel reads
this prompt, and missing sections lead to predictable failure modes:

- Missing *Implementation hints* → reviewer ends up re-deriving the whole
  finding from scratch each round, and convergence slows.
- Missing *Orchestration state exclusion* → reviewer flags `.ralph-burning/`
  files as findings on every round; the run never converges.
- Missing *Acceptance Criteria* → reviewer and implementer disagree on
  "done", amendments oscillate, `max_completion_rounds` hits.

## Template

```markdown
# <Short title (matches the bead title closely)>

## Problem
<One to three paragraphs.
Restate what is broken, the user-visible symptom, and the concrete file:line
anchors from the Codex finding. Explain *why* it breaks — e.g. "the helper
only handles X, not Y" — so the implementer can reason about edge cases.>

Bead: `<bead-id>` (<priority and type>).

## Implementation hints
- Name the functions and files the fix lives in (e.g. `runtime_monday_*`
  handlers in `src/control_plane.rs`).
- Point at an *existing* neighbor that already does the right thing so the
  fix can imitate it (same pattern, same error type, same helper). This
  matters more than any amount of prose.
- Call out regression risks: non-Hermes paths, the legitimate happy path,
  older callers that bypass the new check, etc.
- If there is a shared helper to reuse, name it. Divergent implementations
  are the single biggest source of review amendments.

## IMPORTANT: Exclude orchestration state from review scope
Files under `.ralph-burning/` are live orchestration state and MUST NOT be
reviewed or flagged. Only review source code under `src/`, `tests/`,
`docs/`, `dashboard/`, `scripts/`, and config files.

## Acceptance Criteria
- <User-visible behavior the fix must establish>
- <Every entry point that must be covered>
- <Regression guards: what must still work>
- <Named test cases: at least one unit/integration test for the happy path
  and one for the rejection/failure path>
- `cargo test && cargo clippy --all-targets -- --deny warnings && cargo fmt --check` pass.
- `nix build` passes on the final tree.                     # if applicable
- Dashboard typecheck passes (`cd dashboard && npx tsc -p tsconfig.json --noEmit`).  # if frontend touched
- <other repo-specific gates>

## Source
codex review of `<work_branch>` vs `<review_base>`, finding <Codex tag>.
```

## Notes on wording

- Use declarative imperatives in Implementation hints ("Reuse the
  `authenticated_*` helper that the neighboring routes use") rather than
  descriptive prose.
- The Acceptance Criteria section is contractual. `ralph-burning`'s review
  panel will treat anything named here as a gate. Do not list things you do
  not actually want to enforce.
- Keep the prompt to roughly one screenful. Long prompts bloat every
  reviewer call and rarely improve outcomes.
