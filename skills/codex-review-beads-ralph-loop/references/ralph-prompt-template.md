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
- Missing *Scope — in/out* fence → the run wanders into unrelated
  refactors. The worst real case was a one-line "fix default credentials"
  bead that produced a 5100-line diff across 126 files because the
  prompt had no scope fence and no reviewer pushed back. Always include
  an explicit out-of-scope list.
- Missing *what must keep working* → the fix narrows something legitimate,
  the next iteration's codex review finds the over-correction, and you
  spend an extra bead fixing your fix. Always include the legitimate
  cases the narrow must preserve.

## Template

```markdown
# <Short title (matches the bead title closely)>

## Problem
<One to three paragraphs.
Restate what is broken, the user-visible symptom, and the concrete file:line
anchors from the Codex finding. Explain *why* it breaks — e.g. "the helper
only handles X, not Y" — so the implementer can reason about edge cases.>

Bead: `<bead-id>` (<priority and type>).

## Scope — keep it narrow

**In scope:**
- <Function / file / module the fix lives in, by name>
- <Tests directly on that function / module>
- <Shared helper you intend to reuse, if any>

**Out of scope:**
- <Sibling files / modules you might be tempted to refactor>
- <Anything unrelated to the finding's root cause>
- <Adding new types, traits, or shared helpers unless the change literally
  cannot land otherwise>

Target diff size: <rough LOC estimate, e.g. "under 300 lines including
tests">. If reviewers push for wider refactors, push back and ship the
narrow fix — cleanups are easier as separate beads.

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
- <Regression guards: what must still work — name the legitimate cases
  explicitly. Narrowing-for-security fixes that forget this line produce
  over-correction findings in the next iteration.>
- <Named test cases: at least one unit/integration test for the happy path
  and one for the rejection/failure path>
- <Test plumbing: the new test file must actually run under the repo's
  default test command (`npm test`, `cargo test`, `nix flake check` —
  whatever the repo's CI uses). A test file that exists but is outside
  the runner's glob is dead. Verify by running the command and looking
  for the new tests in its output.>
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
