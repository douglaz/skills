---
name: orchestrating-with-ralph-burning
description: >-
  Uses `ralph-burning` to turn an implementation request into a structured
  requirements, project, and run workflow with durable state. Use when the user
  says "use ralph", "use ralph-burning", "implement this with ralph", "bootstrap
  a run", "orchestrate this", "set up a project for this", or when a feature
  request is complex enough that a resumable, auditable workflow is safer than
  ad hoc coding — roughly anything that would take more than a few files of
  changes. Also use when the user wants to resume a failed or paused run, or
  check on ralph project status. Prefer `ralph-burning` over legacy `ralph`
  unless the user explicitly asks for v1 or `multibackend-orchestration`. Do
  not use for tiny direct edits, pure explanations, or when the user explicitly
  wants manual coding without orchestration.
compatibility: Requires `ralph-burning` on `PATH` or `nix run github:douglaz/ralph-burning -- ...`.
---

Use `ralph-burning` as the default orchestration path for substantial work, not
as an afterthought.

## Tool dependencies

This skill requires `ralph-burning`. Resolution order: first `command -v
ralph-burning`, then `nix run github:douglaz/ralph-burning --`. The nix fallback
works but is slower on first invocation due to download/build. If subcommands
fail with unexpected errors, check whether the CLI version matches the expected
signatures in the command recipes reference — flag version mismatches to the user
rather than guessing at alternative syntax.

## Use this skill when

- the user explicitly asks to use `ralph` or `ralph-burning`
- the request is large enough that you would otherwise produce a long plan
- resumability, auditability, backend routing, or structured review matter
- you want a more reliable path than a long ad hoc coding session

## Do not use this skill when

- the task is a tiny direct patch or a quick factual answer
- the user explicitly wants manual edits without orchestration
- the work is purely exploratory and not ready to become a project/run
- `ralph-burning` is unavailable both on `PATH` and through the public nix run path

## Required outputs

1. A clear choice: use `ralph-burning`, or explain why not.
2. The selected flow and entry path.
3. The project ID and run status when a project or run was created.
4. A concise next-step summary grounded in `ralph-burning` state.

## Default stance

- Prefer `ralph-burning` over legacy `ralph`.
- Treat bare "ralph" requests as `ralph-burning` unless the user clearly means
  v1 or `multibackend-orchestration`.
- Prefer durable state over chat-only planning.
- Prefer `run resume` over restarting failed or paused work.

## Workflow

1. Reread the local `AGENTS.md` chain and confirm the request is orchestration-sized.
2. Resolve the binary before doing anything else.
   - First try `command -v ralph-burning`.
   - If that fails, prefer invoking through
     `nix run github:douglaz/ralph-burning --`.
   - If none of those paths works, stop and explain that the tool is
     unavailable.
3. Confirm the workspace state.
   - If `.ralph-burning/` is missing, run the resolved `ralph-burning` binary
     with `init`.
   - If you expect to start work soon, run the resolved binary with
     `backend check`.
4. Choose the flow up front.
   - `minimal` **(default)**: plan_and_implement + final_review only — ideal
     for focused beads and the most common choice. This is the default if
     `--flow` is omitted.
   - `quick_dev`: scoped code change, low coordination cost
   - `standard`: larger or riskier multi-stage implementation
   - `docs_change`: docs-only work
   - `ci_improvement`: CI or automation work
5. Choose the entry path.
   - Raw idea, no stable prompt: `project bootstrap --idea ...`
   - Need clarification rounds and a stronger seed: `requirements draft --idea ...`
   - Stable prompt file already exists: `project create --prompt ... --id ... --name ...`
   - Existing failed or paused run: `run resume`
   - Orphaned/stale run: `run stop` then `run resume`
6. Keep the orchestration state authoritative.
   - Use `run status`, `run history`, and `run tail` instead of inferring from
     loose artifacts or memory.
   - Use `project show` when you need the canonical project record.
7. Report back briefly.
   - Say which binary you used.
   - Say which flow and entry path you chose.
   - Give the resulting project ID and current run status.
   - Give the next command or next state transition.

## Writing prompt files

When creating a prompt file for `project create`, always include these sections:

1. **Problem description** — what needs to change and why
2. **Implementation hints** — where to look in the codebase, patterns to follow
3. **Orchestration state exclusion** — always include this block:

```
## IMPORTANT: Exclude orchestration state from review scope
Files under `.ralph-burning/` are live orchestration state and MUST NOT be
reviewed or flagged. Only review source code under `src/`, `tests/`, `docs/`,
and config files.
```

This prevents reviewers from flagging the run's own `run.json` as a finding,
which causes infinite amendment loops (the Codex reviewers in particular
treat the diff literally and don't distinguish orchestration state from
application code).

4. **Acceptance criteria** — always include:
   - `nix build` passes on the final tree (this is the authoritative gate,
     not just `cargo test` — the nix sandbox differs from the local dev
     environment)
   - `cargo test && cargo clippy -- -D warnings && cargo fmt --check` pass

## Entry-path rules

### 1. Raw idea -> fast start

Use `project bootstrap` when the user wants execution momentum and the idea is
already good enough for a quick requirements pass.

- Default flow is `minimal` (no need to pass `--flow minimal` explicitly).
- Add `--start` only when the user clearly wants execution now.

### 2. Raw idea -> higher certainty

Use `requirements draft` when the request is important enough to justify
clarification rounds and a stronger project seed.

After answers are collected and the requirements run completes:

- create the project with `project create --from-requirements <run-id>`
- then `run start` if execution should begin now

### 3. Stable prompt/spec already exists

Use `project create` directly when a durable prompt file already exists and the
user does not need the requirements pipeline first.

### 4. Existing project/run

If the workspace already contains the relevant project:

- `project select <id>`
- `run start` only for `not_started`
- `run resume` for `failed` or `paused`
- `run stop` for orphaned/stale runs (process died but status still `running`)

## Final review panel

The final review panel has three phases:

1. **Proposals** (parallel): All reviewers independently read the implementation
   diff and propose amendments (0 or more findings each).
2. **Voting** (parallel, only if amendments exist): If any reviewer proposed
   amendments, all reviewers vote ACCEPT or REJECT on each amendment. This
   requires a quorum (threshold=0.66, so 2/3 agreement).
3. **Arbiter** (only on split votes): If votes are tied, the arbiter breaks
   the tie.

If all reviewers propose 0 amendments, the panel completes immediately —
no voting or arbiter needed. This is the fast path for clean implementations.

After voting, accepted amendments get queued, the completion round advances,
and control returns to plan_and_implement for fixes. Then the cycle repeats
until convergence (0 amendments) or `max_completion_rounds` is reached.

**Common reviewer patterns:**
- `gpt-5.4-xhigh` is the most thorough but slowest (~5 min proposals, ~2 min
  votes). It finds real issues the others miss but can also be overzealous.
- `claude-opus-4-6` is moderate speed (~2-3 min) and good at understanding
  context — it rarely flags orchestration state.
- `gpt-5.3-codex-spark` is the fastest (~30s) but has lower quota limits and
  often exhausts credits.

## Monitoring a run

Once a run starts, monitor it periodically rather than blocking on it:

- `run status` for a quick snapshot (stage, cycle, round).
- `run tail --logs` for the durable journal plus runtime log entries.
- `run tail --follow` to poll for new events every 2 seconds.
- `run tail --last 5` to see only the most recent events.

**Convergence tracking.** Each completion round produces amendments from
reviewers. Track the amendment count per round — a healthy run trends toward
zero. If counts oscillate (e.g. 4→2→4→3→4) for many rounds, the reviewers may
be disagreeing in a loop and the run will likely hit `max_completion_rounds`
and force-complete, which is an acceptable outcome.

**Orchestration state loops.** If the same amendment about `.ralph-burning/`
files (especially `run.json`) keeps appearing every round, the reviewers are
flagging the run's own live state as a code issue. This will never converge.
Stop the run, add the orchestration state exclusion to the prompt (see
"Writing prompt files" above), and resume. Or stop and ship — the code
changes are fine, only the review is looping.

**Typical timing.** A single round (plan_and_implement + final_review) takes
roughly 10–20 minutes. A full run with the `minimal` flow usually completes
in 30 minutes to 3 hours depending on complexity and amendment convergence.

**Detecting stuck backends.** If a Codex process shows 0% CPU for 50+ minutes
while `run tail` shows no new events, the GPT API is likely hung. The 1-hour
timeout will eventually fire and the run will fail — just resume afterward.

## Failure recovery

Code changes survive backend failures — the backend edits files directly in
the working tree, and those edits persist even when the structured JSON output
fails validation. This means `run resume` is almost always the right recovery
action because it picks up where the code left off.

**Schema validation failures.** The most common failure: Claude does all the
implementation work but returns a text summary instead of the required JSON
(`missing field change_summary`). On retry, Claude sees the code is already
done and usually outputs the JSON correctly in a few minutes. These failures
resolve themselves — just let retries run.

**Codex API timeouts.** Codex sometimes hangs for 1 hour producing no output
(GPT API not responding). The run fails with `outcome=failed` and
`duration_ms=3600000+`. Recovery: `run resume`. The resume starts fresh
on the stage that failed.

**Model at capacity.** Codex may report "Selected model is at capacity".
This is transient — just `run stop` then `run resume` after a brief wait.

**Claude auth failures (401).** If Claude returns a 401 authentication error,
the API key or session has expired. The user needs to re-authenticate
(e.g. `/login`), then `run stop` and `run resume`.

**BackendExhausted (credits/quota).** When a backend hits credit limits or
persistent rate limits, it's classified as `BackendExhausted` (non-retryable).
Final review panels degrade gracefully — they proceed with the remaining
backends. If ALL backends are exhausted, the stage fails.

**Orphaned/stale runs.** If the orchestrator process dies (terminal closed,
OOM, crash), the run stays in `running` status but the process is gone. Use
`run stop` to cleanly transition it to `failed`, then `run resume`. The
`run stop` command detects stale processes automatically.

**General rule:** prefer `run resume` over `run start`. Resume preserves all
prior progress, rollback points, and session state. Only use `run start` when
you genuinely need a fresh run.

## Git workflow (bead lifecycle)

Complete one bead per branch through the full lifecycle before starting the
next. This keeps state clean and avoids cross-branch conflicts.

```
git checkout master && git pull
git checkout -b feat/<bead-id>-short-description
# ... ralph-burning run completes ...
# verify locally:
nix develop -c cargo test
nix develop -c cargo clippy -- -D warnings
nix develop -c cargo fmt --check
# push and PR:
git push -u origin feat/<bead-id>-short-description
gh pr create --title "..." --body "..."
# wait for CI green
gh pr merge --squash --delete-branch
git checkout master && git fetch origin master && git reset --hard origin/master
nix build
# close the bead
br update <bead-id> -s closed
# now start the next bead
```

Key points:
- One branch per bead, one bead at a time.
- Push, PR, wait CI green, merge — then reset master and rebuild before the
  next bead.
- ralph-burning creates checkpoint commits (`rb: checkpoint ...`) as it works.
  These are on the feature branch and get squashed on merge.
- After squash merge, local master diverges from origin — always use
  `git reset --hard origin/master` (not `git pull`) to sync.
- CI runs `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test`,
  and conformance tests. Pre-push hooks also run fmt and clippy locally.

## Backend configuration

Check and tune backend settings before or during runs:

```bash
$RALPH backend check          # verify all backends are reachable
$RALPH backend show-effective # show resolved backend per role with sources
$RALPH config show            # full config with sources
$RALPH config set <key> <val> # change a setting in workspace.toml
```

Key settings:
- `workflow.max_completion_rounds` (default 25): max plan→review round trips
- `final_review.max_restarts` (default 25): max restarts within a single
  final_review stage
- `workflow.max_review_iterations` (default 3): max review→fix cycles per round
- `workflow.max_qa_iterations` (default 3): max QA→fix cycles per round

Per-project overrides live in `.ralph-burning/projects/<id>/config.toml`.

## Reliability rules

- Never mix `.ralph` and `.ralph-burning` state in the same workflow.
- Do not guess a run state from artifacts when `run.json` or `run status`
  can answer it directly.
- Do not restart a run just because it failed once; inspect and prefer resume.
- Do not choose legacy `ralph` unless the user explicitly asks for v1 behavior.
- Keep the chat concise; let `ralph-burning` carry the durable context.
- The live orchestration state lives in `.git/ralph-burning-live/`, not
  `.ralph-burning/`. The `.ralph-burning/` directory contains the committed
  snapshot. When debugging run state, check both.

## Additional resource

- For flow selection, preflight, and command recipes, see
  [references/flow-and-command-recipes.md](references/flow-and-command-recipes.md).
