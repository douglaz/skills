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

- `minimal` **(default)**: plan_and_implement + final_review only — best for
  focused beads and single-concern tasks. This is the default when `--flow`
  is omitted.
- `quick_dev`: contained feature, bugfix, or refactor
- `standard`: substantial feature, risky change, or work that benefits from
  explicit planning, QA, review, completion, and resume boundaries
- `docs_change`: docs-only request
- `ci_improvement`: CI, automation, or workflow hardening

If the user says only "use ralph", prefer `ralph-burning` plus one of the flows
above. Do not default back to v1.

## 4. Bootstrap from an idea

Fast path (uses default `minimal` flow):

```bash
$RALPH project bootstrap --idea "$IDEA"
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
  --prompt "$PROMPT_FILE"
```

Note: `--flow` is optional — defaults to `minimal`.

Then:

```bash
$RALPH project select "$PROJECT_ID"
$RALPH run start
```

### Prompt file template

Always include the orchestration state exclusion and nix build criteria:

```markdown
# Title of the change

## Problem
What needs to change and why.

## Implementation hints
Where to look in the codebase, patterns to follow.

## IMPORTANT: Exclude orchestration state from review scope
Files under `.ralph-burning/` are live orchestration state and MUST NOT be
reviewed or flagged. Only review source code under `src/`, `tests/`, `docs/`,
and config files.

## Acceptance Criteria
- Description of what done looks like
- cargo test && cargo clippy -- -D warnings && cargo fmt --check pass
- nix build passes on the final tree
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

## 8. Stop and resume

For orphaned/stale runs (process died, terminal closed):

```bash
$RALPH run stop         # detects stale process, transitions to failed
$RALPH run resume       # picks up from where it left off
```

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

### Detecting orchestration state loops

If the same `.ralph-burning/run.json` or `.ralph-burning/journal.ndjson`
amendment keeps appearing every round, the Codex reviewers are flagging the
run's own live state. This never converges because the implementer can't
modify the running orchestration state. Solutions:

1. Stop the run, add the orchestration state exclusion to the prompt, resume
2. Stop the run and ship — the code changes are already well-reviewed

The Claude reviewer typically does NOT flag orchestration state; this is
a Codex-specific behavior.

### Checking amendment sources

```bash
grep "amendment_queued" .git/ralph-burning-live/projects/<id>/journal.ndjson | \
  python3 -c "
import json, sys
for line in sys.stdin:
    e = json.loads(line)
    d = e['details']
    sources = d.get('reviewer_sources', [])
    who = ', '.join(s['model_id'] for s in sources)
    is_rb = '.ralph-burning' in d.get('body','')
    print(f'{d[\"amendment_id\"]} by={who} orchestration_state={is_rb}')
    print(f'  {d[\"body\"][:120]}')
    print()
"
```

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

### Model at capacity

```
ERROR: Selected model is at capacity.
```

Transient GPT API overload. Recovery:

```bash
$RALPH run stop
$RALPH run resume
```

### Claude auth failure (401)

```
API Error: 401 ... Invalid authentication credentials
```

API key or session expired. The user must re-authenticate first (e.g.
`/login` in Claude Code), then:

```bash
$RALPH run stop
$RALPH run resume
```

### Backend credit exhaustion

```
BackendExhausted: usage limit / quota exceeded
```

Non-retryable. Final review panels degrade gracefully by proceeding with
remaining backends (e.g. if codex-spark exhausts, gpt-5.4 and claude
continue). If ALL backends are exhausted, the stage fails. Check status
with `backend check`.

### Orphaned/stale run

The orchestrator process died but `run status` still shows `running`:

```bash
$RALPH run stop     # detects stale process, transitions to failed
$RALPH run resume   # continues from checkpoint
```

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

# 3. Create project and run
$RALPH project create --id <proj-id> --name "..." --prompt /tmp/prompt.md
$RALPH project select <proj-id>
$RALPH run start    # runs in background

# 4. Monitor until complete (see section 9)

# 5. Verify locally (all three must pass)
nix develop -c cargo test
nix develop -c cargo clippy -- -D warnings
nix develop -c cargo fmt --check

# 6. Push and PR
git push -u origin feat/<bead-id>-short-description
gh pr create --title "..." --body "..."

# 7. Wait for CI green, then merge
gh pr checks <pr-number> --watch    # or poll manually
gh pr merge --squash --delete-branch

# 8. Reset local master (squash merge diverges local history)
git checkout master
git fetch origin master
git reset --hard origin/master

# 9. Close the bead
br update <bead-id> -s closed

# 10. Rebuild and start next bead
nix develop -c cargo build --release
nix build   # verify nix sandbox passes
```

**Important:** After a squash merge, `git pull` will fail with
"not possible to fast-forward" because the checkpoint commits on the feature
branch are different from the squashed merge commit. Always use
`git fetch origin master && git reset --hard origin/master` instead.

## 13. Verification checklist

Before shipping any bead, verify all of these pass:

```bash
nix develop -c cargo test           # unit + integration tests
nix develop -c cargo clippy -- -D warnings  # no clippy warnings
nix develop -c cargo fmt --check    # formatting
nix build .                         # nix sandbox (authoritative gate)
```

`nix build` is the authoritative verification gate. The nix sandbox differs
from the local dev environment — no real tmux, no network, limited binaries.
Tests that pass locally may fail in the sandbox. Do not claim "all tests pass"
unless `nix build` succeeds.

## 14. Good operator summary

After using `ralph-burning`, report these four things:

1. Which binary you used.
2. Which flow and entry path you chose.
3. Which project ID and run status now exist.
4. What the next command or next state transition is.

Example:

```text
Using target/release/ralph-burning (local build).
Created project xyz-1 with default minimal flow.
Run started: plan_and_implement cycle 1 round 1.
Next: monitor with run status, ship when complete.
```
