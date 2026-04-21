# Bead description template

Use this shape when translating a Codex finding into a `br create` call. The
point is to make the bead executable by a fresh agent without reopening the
Codex output.

## Title

One concrete, assertive line describing the broken behavior or the action.
Imperative or declarative both work. Avoid vague titles like "fix publish"
— the title is what shows up in `br ready` and triage views.

Examples:
- `Monday runtime routes bypass authentication`
- `Publish does not start managed apps: runtime sync is not triggered`
- `Dashboard forwards stale invite-session cookie across account switches`

## Description body

```
<One-paragraph problem statement.
Include concrete file:line hints from the Codex finding, because the next
agent will need them and they decay as the branch moves.
Explain *why* this is broken, not just what.>

Acceptance criteria:
- <User-visible behavior the fix must establish>
- <Every entry point that must be covered>
- <Regression guards: what must still work>
- <At least one named test case (unit, integration, or e2e)>
- cargo test && cargo clippy --all-targets -- --deny warnings && cargo fmt --check pass
- nix build passes on the final tree         # if applicable
- <other repo-specific gates>

Source: codex review of <work_branch> vs <review_base> (<codex tag, e.g. P1 security>).
```

## Priority mapping

| Codex tag | Bead priority | When to bump |
|-----------|---------------|--------------|
| `[P1]` + security/auth keywords | `0` | Always — security findings take precedence |
| `[P1]` | `1` | |
| `[P2]` | `2` | |
| `[P3]` | `3` | |
| `[P3]` style/docs only | `4` | If it is genuinely cosmetic |

## Labels

Always include `codex-review`. Always include the area label(s) the finding
touches (`control-plane`, `dashboard`, `runtime-sync`, `auth`, etc.) —
triage and stale-queries key off these.

## What NOT to put in the description

- Full Codex output. Link to the pass log or quote the 1–3 relevant lines.
- Orchestration state chatter (which agent wrote what when).
- Ephemeral debugging. The bead is for the next agent; it is not a scratchpad.
