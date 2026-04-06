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

- `minimal`: plan_and_implement + final_review only — best for focused beads
  and single-concern tasks where QA and separate review stages add overhead
  without value
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
$RALPH project bootstrap --idea "$IDEA" --flow quick_dev
```

Safer multi-stage path:

```bash
$RALPH project bootstrap --idea "$IDEA" --flow standard
```

Add `--start` only when the user clearly wants execution to begin immediately.

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

## 9. Monitoring a running project

```bash
# Quick status check
$RALPH run status

# Journal + runtime logs
$RALPH run tail --logs

# Live polling (every 2s)
$RALPH run tail --follow

# Recent events only
$RALPH run tail --last 5
```

### Tracking convergence

Each completion round produces amendments from final_review. Track the count
per round to judge convergence:

```bash
# Parse amendment counts from the live journal
cat .git/ralph-burning-live/projects/<id>/journal.ndjson | \
  python3 -c "
import json, sys
count = 0; round_num = 1
for line in sys.stdin:
    d = json.loads(line.strip())
    if d.get('event_type') == 'amendment_queued': count += 1
    elif d.get('event_type') == 'completion_round_advanced':
        print(f'R{round_num}: {count}'); count = 0; round_num += 1
"
```

A healthy trend: 7→5→3→1→0 (converging). An oscillating pattern like
4→2→4→3→4 means reviewers disagree and the run will likely hit
`max_completion_rounds` and force-complete — this is acceptable.

### Detecting stuck backends

If `run tail` shows no new events for 50+ minutes and a Codex process is at
0% CPU, the GPT API is likely hung. The 1-hour timeout will fire automatically.
After it does, just `run resume`.

## 10. Failure recovery recipes

### Schema validation failure (most common)

```
backend invocation failed ... missing field `change_summary`
```

Claude did the work but returned text instead of JSON. Retries usually fix
this because on retry Claude sees the code is already done and outputs the
JSON quickly. Let the retry loop handle it — no operator action needed unless
all 3 attempts fail, in which case `run resume` starts a fresh attempt.

### Codex API timeout

```
outcome=failed duration_ms=3600032
```

Codex hung for 1 hour with no output. The run fails. Recovery:

```bash
$RALPH run resume
```

### Backend credit exhaustion

```
BackendExhausted: usage limit / quota exceeded
```

Non-retryable. Final review and completion panels degrade gracefully by
proceeding with remaining backends. If ALL backends are exhausted, the stage
fails. Check status with `backend check`.

### General recovery rule

Always prefer `run resume` over `run start`. Code changes survive failures —
the backend edits files directly in the working tree. Resume picks up from
the last checkpoint with all prior work intact.

## 11. Backend configuration

```bash
# Full config with value sources
$RALPH config show

# Change a workspace-level setting
$RALPH config set workflow.max_completion_rounds 25
$RALPH config set final_review.max_restarts 25

# Check which backend/model resolves for each role
$RALPH backend show-effective

# Verify all backends are reachable
$RALPH backend check
```

Key settings:

| Setting | Default | Purpose |
|---------|---------|---------|
| `workflow.max_completion_rounds` | 25 | Max plan→review round trips |
| `final_review.max_restarts` | 25 | Max restarts within one final_review |
| `workflow.max_review_iterations` | 3 | Max review→fix cycles per round |
| `workflow.max_qa_iterations` | 3 | Max QA→fix cycles per round |

Per-project overrides: `.ralph-burning/projects/<id>/config.toml`

## 12. Git workflow (bead lifecycle)

One bead per branch, complete the full lifecycle before starting the next:

```bash
# 1. Start clean
git checkout master && git pull

# 2. Create feature branch
git checkout -b feat/<bead-id>-short-description

# 3. Claim the bead
br update <bead-id> --status in_progress

# 4. Create project and run
$RALPH project create --id <bead-id> --name "..." --prompt /tmp/prompt.md --flow minimal
$RALPH project select <bead-id>
$RALPH run start --backend claude

# 5. Monitor until complete (see section 9)

# 6. Push and PR
git push -u origin feat/<bead-id>-short-description
gh pr create --title "..." --body "..."

# 7. Wait for CI green, then merge
gh pr checks <pr-number>   # repeat until pass
gh pr merge --squash

# 8. Close the bead
br close <bead-id> --reason "..."

# 9. Prepare for next bead
git checkout master && git pull
nix build
```

## 13. Good operator summary

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
