# Flow and Command Recipes

Use these recipes as defaults. Adjust only when the repo's `AGENTS.md`,
workspace config, or user intent requires something else.

## 1. Resolve the binary

Preferred:

```bash
RALPH=$(command -v ralph-burning)
```

If that fails, prefer the public nix-run wrapper:

```bash
RALPH='nix run github:douglaz/ralph-burning --'
```

If none of those paths works, stop and tell the user the tool is unavailable.

## 2. Workspace preflight

Initialize only when the workspace does not exist yet:

```bash
$RALPH init
```

Check backend readiness before starting execution-heavy work:

```bash
$RALPH backend check
$RALPH backend show-effective
```

## 3. Flow selection

- `quick_dev`: contained feature, bugfix, or refactor
- `standard`: substantial feature, risky change, or work that benefits from
  explicit planning, QA, review, completion, and resume boundaries
- `docs_change`: docs-only request
- `ci_improvement`: CI, automation, or workflow hardening

If the user says only "use ralph", prefer `ralph-burning` plus one of the flows
above. Do not default back to v1.

## 4. Bootstrap from an idea

Fast path:

```bash
$RALPH project bootstrap --idea "$IDEA" --flow quick_dev --start
```

Safer multi-stage path:

```bash
$RALPH project bootstrap --idea "$IDEA" --flow standard --start
```

Use `--start` only when execution should begin immediately.

## 5. Run requirements first

Use this when the idea is still underspecified and you want a stronger seed.

Quick mode:

```bash
$RALPH requirements quick --idea "$IDEA"
$RALPH requirements show <run-id>
$RALPH project create --from-requirements <run-id>
```

Full staged mode with clarification rounds:

```bash
$RALPH requirements draft --idea "$IDEA"
$RALPH requirements show <run-id>
$RALPH requirements answer <run-id>
$RALPH requirements show <run-id>
$RALPH project create --from-requirements <run-id>
```

`project create --from-requirements` selects the created project automatically.

## 6. Create directly from a prompt file

Use this when a stable prompt/spec file already exists.

```bash
$RALPH project create \
  --id "$PROJECT_ID" \
  --name "$PROJECT_NAME" \
  --prompt "$PROMPT_FILE" \
  --flow standard
```

Then:

```bash
$RALPH project select "$PROJECT_ID"
$RALPH run start
```

## 7. Inspect and continue

Use canonical state, not artifact guesswork.

```bash
$RALPH project list
$RALPH project show
$RALPH run status
$RALPH run status --json
$RALPH run history --stage implementation
$RALPH run tail --last 20
```

If execution is already in progress and tmux mode is enabled:

```bash
$RALPH run attach
```

## 8. Resume instead of restarting

For failed or paused runs:

```bash
$RALPH run resume
```

Inspect first when needed:

```bash
$RALPH run status --json
$RALPH run history --verbose
```

## 9. Good operator summary

After using `ralph-burning`, report these four things:

1. Which binary you used.
2. Which flow and entry path you chose.
3. Which project ID and run status now exist.
4. What the next command or next state transition is.

Example:

```text
Using nix run github:douglaz/ralph-burning --.
Chose flow quick_dev via project bootstrap.
Created and selected project retry-safe-lease-cleanup; run is running in review.
Next useful check: nix run github:douglaz/ralph-burning -- run status --json
```
