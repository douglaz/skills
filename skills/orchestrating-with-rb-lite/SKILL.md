---
name: orchestrating-with-rb-lite
description: >-
  Uses `rb-lite` to drive lightweight implement → review loops in the current
  git repo. Covers both one self-contained task on a branch and a serialized
  `br` backlog drain where each ready bead becomes one branch, one rb-lite
  run, one PR, one squash merge, and one bead closure. Use when the user says
  "rb-lite", "use rb-lite", "run the rb-lite loop", "iterate on this with
  rb-lite", "implement this with codex + claude until clean", "review-and-fix
  loop on this branch", "drain the bead backlog with rb-lite", "solve beads
  one by one with rb-lite", or asks for an iterative codex+claude review/fix
  cycle. Prefer `rb-lite` when you want "code → review → fix → repeat → JSON
  summary" without a full `ralph-burning` project. Do NOT use for durable
  cross-project orchestration, planner/flow staging, or tiny one-shot edits.
compatibility: Requires `rb-lite` on `PATH` or `nix run github:douglaz/rb-lite -- ...`. rb-lite has no default implementer — pass `--implementer` with one preset or a comma-separated cycle (default to `--implementer claude,codex`), or `--implement-cmd`. Both `codex` and `claude` CLIs must be installed and authenticated for the default reviewer panel and the implementer presets. Backlog-drain mode also requires `br`, `gh`, and the repo's normal local verification tools.
---

Use `rb-lite` as the default lightweight implement → review loop for
single-branch, single-task work in the current repo. Also use it as the
execution engine for draining an existing `br` backlog: `br ready` supplies
the work list, and each bead gets one focused rb-lite run.

## What rb-lite is, in one paragraph

`rb-lite` is a Bash CLI that loops a chosen implementer preset
(`--implementer claude,codex`, a comma-separated cycle, or a single
`codex`/`claude`; there is no default) until the git diff stabilizes, then
runs `codex review` and `claude -p` in parallel against the diff, feeds
P0/P1/P2 findings back to the implementer for another round, and stops when
reviewers go clean, the implementer refuses to keep changing things, or a
budget cap is hit. With a comma-separated list, round N uses
`list[(N-1) mod len]`: each review round with findings hands the feedback
to the next implementer in the cycle. Every exit emits
a single JSON line on stdout summarizing the run. No daemons, no state DB,
just a script and the per-run artifact directory.

## Use this skill when

- The user explicitly asks for `rb-lite` or "the rb-lite loop."
- The user wants codex + claude to iterate on the current branch until a
  panel review is clean, on a self-contained task.
- The user wants to drain, clear, or work through an existing `br` backlog
  with rb-lite, solving beads one by one.
- The change is bigger than a one-shot edit but small enough that managing
  it as a `ralph-burning` project would be overhead the user doesn't want.
- The user wants a parseable summary of what happened (JSON line on stdout)
  rather than free-form prose.
- The user just wants a "review-and-fix" pass before opening a PR.

## Do NOT use this skill when

- The work spans multiple branches/projects, needs durable resumable state,
  or wants the planner/implementer/reviewer/final_review staging that
  `ralph-burning` provides — defer to `orchestrating-with-ralph-burning`.
  Serialized bead draining is the exception: `br`, branches, PRs, and CI are
  the durable state, while rb-lite only runs one bead at a time.
- The user explicitly wants direct manual edits without an orchestration
  loop, or a single quick patch.
- The codebase has no `codex` or `claude` available and the user can't
  install them — the default panel won't work.
- The user wants a *one-shot* code review without any fix loop — `codex
  review` directly is simpler.
- The user explicitly asks for `ralph-burning`; use
  `orchestrating-with-ralph-burning` instead.

## Tool dependencies

Resolution order, in this order:

1. `command -v rb-lite` — installed binary on PATH.
2. `nix run github:douglaz/rb-lite -- ...` — public flake; works on first
   run after a short build, cached afterwards.

If neither path works, stop and tell the user to install `rb-lite` (e.g.
`nix profile install github:douglaz/rb-lite`) or expose it on PATH.

The default reviewer panel uses `codex review` and `claude -p`. Both must
be on PATH and authenticated. If only one is available, the user can
override the panel with a `.rb-lite-reviewers` file (see "Customizing the
panel" below) — but the default behavior assumes both.

Backlog-drain mode additionally needs `br` for bead selection/state and `gh`
for PR creation/checks/merge. It should use the repo's documented local gates;
for Rust/Nix repos, default to `cargo fmt`, `cargo clippy`, `cargo test`, and
`nix build` through `nix develop` where that is the established pattern.

**Implementer selection.** Recent `rb-lite` has **no default implementer**:
you must pass `--implementer` (or a raw `--implement-cmd`). Default to the
cycling form `--implementer claude,codex` unless the user pins a single
implementer — cycling alternates agents after every review round, so each
round's findings are addressed by a fresh pair of eyes. If the `rb-lite` on
PATH rejects the comma list with "--implementer must be one of claude,
codex", it predates cycling — fall back to a single preset (`--implementer
codex`) or update rb-lite. If it rejects `--implementer` itself with
"unknown run option", it predates implementer selection entirely — update
it (those oldest builds default to codex, so you can omit the flag there).

## Required outputs

When you finish a run on the user's behalf, report:

1. The binary you used (`rb-lite` from PATH, or `nix run github:...`).
2. The exit code and the `status` field from the JSON summary.
3. Rounds completed and the final reviewer state (clean, consensus
   failure, max-rounds, etc.).
4. The run artifact directory path so the user can inspect logs.
5. If the run failed (codes 10/11/12/13/70), a one-sentence diagnosis
   pointing at which artifact to look at.

For backlog-drain mode, also report the bead ids closed, PRs merged, the next
ready bead if the queue is not empty, and the exact reason the loop stopped.

## Default stance

- Run from the user's current branch in their current working directory.
  Don't `git switch` unless the user asks for a feature branch
  (`--branch NAME`). Backlog-drain mode always uses one fresh feature branch
  per bead.
- Use `--base` matching what the user is comparing against. If they don't
  say, default to `origin/main` (modern projects) or `main` if no remote
  is configured. Avoid `origin/master` unless the user's repo actually
  uses `master`.
- Default `--max-rounds` and `--max-iters` to rb-lite's own defaults (25
  each). Real loops converge in 1–7 rounds; the cap is a safety net.
- Trust rb-lite's stop conditions. The default `--min-findings-severity P2`
  means P3-only review rounds auto-stop the loop — that's intentional, do
  not lower it to `P3` unless the user wants to chase nits.
- Read the JSON summary line, don't paraphrase. The schema is stable and
  parseable.
- In backlog-drain mode, one bead equals one branch and one PR. Do not batch
  unrelated beads into one rb-lite run.
- Pre-existing backlog beads are immutable input. If a bead is ambiguous or
  its acceptance criteria are weak, ask the user before launching rb-lite.
- File rb-lite/tooling dogfood findings as fresh beads immediately. P0/P1
  dogfood beads interrupt the queue; P2 or lower can wait.

## Workflow

1. **Confirm the work is rb-lite-shaped.** Reread the user's request. If
   it's a one-shot edit or a multi-project initiative, redirect. If the user
   wants to clear an existing bead queue, use "Backlog-drain workflow" below
   after resolving the rb-lite binary and prerequisites.

2. **Resolve the binary.** `command -v rb-lite` first; otherwise plan to
   prefix every invocation with `nix run github:douglaz/rb-lite --`. Note
   the resolved invocation in your plan so the user knows what's running.

3. **Confirm prerequisites and choose the implementer.** `command -v codex`
   and `command -v claude`. If either is missing, stop and tell the user —
   the default panel won't work, and silently substituting a single-reviewer
   panel would change the loop's behavior. rb-lite has **no default
   implementer**: pass `--implementer` with a single preset or a
   comma-separated cycle (or a raw `--implement-cmd`). Default to
   `--implementer claude,codex` unless the user pins one — round 1 runs
   claude, and each review round with findings hands off to the next preset
   in the cycle (wrapping). Session reuse stays within a round, so cycling
   never resumes the other agent's session. Omitting all of these is a
   usage error (exit 2).

4. **Confirm the git state.** rb-lite refuses to run outside a git repo
   and ignores changes under `.rb-lite/`, `.ralph-burning/`, and
   `.git/ralph-burning-live/` (those are runtime state). If the working
   tree has unrelated dirty changes the user didn't mention, surface that
   before launching — they will be in scope for the implementer and
   reviewers.

5. **Pick a base ref.** Try in order: the explicit user choice, then
   `origin/main`, `origin/master`, `main`, `master`. Pick the first that
   resolves. Print the chosen ref in your plan.

6. **Decide on a feature branch.** If the user said "iterate on the
   current branch," don't pass `--branch`. If they said "do this on a
   new branch named X," pass `--branch X`. If unclear, ask.

7. **Construct the task argument.** rb-lite passes `--task TEXT` (or
   `--task-file PATH`) to the implementer's PROMPT. Keep the task
   self-contained: state the goal, list constraints, and explicitly
   forbid the implementer from running rb-lite itself or signaling its
   own process tree (this prevents an observed self-destruct failure
   mode where the implementer experiments on its own parent process).
   Avoid embedding literal `session id: <UUID>` strings or other tokens
   that rb-lite's own regexes might accidentally capture.

8. **Run rb-lite.** Foreground for short tasks (1–2 expected rounds);
   background with progress monitoring for longer ones. The script
   mirrors progress to stderr by default, so a foreground invocation
   shows live status without extra effort.

   ```bash
   rb-lite run \
     --implementer claude,codex \
     --task "<self-contained task instruction>" \
     --base origin/main \
     --run-dir /tmp/rb-<short-tag>-run
   ```

   The `--run-dir` argument is optional (default
   `.rb-lite/runs/<timestamp>-<pid>` in the repo). A `/tmp/...` run-dir
   is convenient when you don't want artifacts in the repo tree.

9. **Read the JSON summary.** rb-lite always prints a single-line JSON
   object as the last line of stdout, on success and failure. Pipe to
   `jq` if available; otherwise grep the line. The schema is in the
   "Exit codes and JSON schema" section below.

10. **Diagnose by exit code.** Don't pattern-match on the human-readable
    line; match on the JSON `status` and `exit_code`. The mapping is
    fixed (see the table below).

11. **Report concisely.** Tell the user what shipped, what didn't, where
    artifacts are, and whether anything needs manual follow-up. Don't
    paste the full review files — they're on disk.

## Backlog-drain workflow

Use this mode when the user wants to clear an existing `br` backlog with
rb-lite. The beads are the input; do not invent a fresh work list. Codex is
operating the queue and PR workflow, while rb-lite handles the inner
implement → review loop for each bead.

1. **Pick.** Run `br ready --limit 10`. Take the top P0 first; if none,
   the lowest-numbered P1; only descend to P2 if the user says so or the
   P1 list is empty / oversized.

2. **Read.** Run `br show <id>` (and `br show <id> --json` if structured
   fields help). If the acceptance criteria are vague, pause and ask the
   user before writing the task.

3. **Sync base and branch.** Confirm there is no unrelated dirty work, fetch
   the selected base, and start the bead from that clean base. Use one branch
   per bead, e.g. `feat/<bead-id>-<short-slug>`. Let rb-lite create/switch the
   branch with `--branch` unless the branch already exists and the user
   explicitly wants to resume it. Do not pile multiple beads onto one branch.

4. **Task file.** Write a focused task file, usually under
   `.rb-lite/tasks/bead-<id>.md`, using the template below. Keep it outside
   the committed source diff unless the repo intentionally tracks task
   files.

5. **Run rb-lite.**

   ```bash
   rb-lite run \
     --implementer claude,codex \
     --task-file .rb-lite/tasks/bead-<id>.md \
     --base origin/main \
     --branch feat/<bead-id>-<short-slug> \
     --run-dir /tmp/rb-lite-<bead-id>-run
   ```

   If using the nix fallback, prefix the same `run ...` arguments with
   `nix run github:douglaz/rb-lite --`.

6. **Read the JSON summary.** Exit `0` with status `clean` means the panel
   had no P0/P1/P2 findings. For exit `10`, `11`, `12`, `13`, or `70`, use
   the rb-lite diagnosis table below and inspect the run artifacts before
   deciding whether to rerun, fix manually, or file a dogfood bead.

7. **Run local gates.** Use the repo's own verification contract. In the
   Rust/Nix repos this skill was built for, the default gate set is:

   ```bash
   nix develop -c cargo fmt --check
   nix develop -c cargo clippy --locked -- -D warnings
   nix develop -c cargo test --locked --features test-stub
   nix build
   ```

   Treat real failures as part of the bead. Treat pre-existing flakiness as
   a separate bead; don't hand-tune the branch to hide a flaky CI failure.

8. **Commit, push, PR.** Add only intentional source/docs/config changes and
   any bead-state sync files the repo expects. Do not commit `.rb-lite/` run
   artifacts. Commit with a real message, push, and create a PR with a body
   that includes the bead id, rb-lite status/rounds, and local test plan.

9. **CI.** Use `gh pr checks <pr>` and wait for green. On known-flaky CI,
   rerun failed jobs via `gh run rerun <id> --failed`; do not keep changing
   product code just to dodge a flake.

10. **Merge and reset.** Squash-merge the PR, delete the branch, fetch the
    base branch, reset local state to the remote base, and rerun the
    authoritative build gate before taking the next bead:

    ```bash
    gh pr merge <pr> --squash --delete-branch
    git fetch origin main
    git reset --hard origin/main
    nix build
    ```

    Substitute `master` only when the repo actually uses `master`.

11. **Close the bead.** Run `br update <bead-id> -s closed` after the merged
    code is present on the base branch. If the repo requires a bead-state
    sync/flush step, run it and leave `.beads/` clean according to that repo's
    convention.

12. **Loop.** Return to `br ready --limit 10`. Stop when the queue is empty,
    the user says stop, a bead needs human product/security judgment, or a
    P0/P1 dogfood bead interrupts the queue.

## Backlog task template

The task file for a bead should be self-contained and narrow:

```markdown
# Bead <id>: <one-line goal>

## Problem description
<2-4 paragraphs explaining what and why; reference the bead's acceptance
criteria.>

## Required changes
<Numbered list of concrete edits: paths, functions, behaviors, expected
shape of the change.>

## Tests
<3-7 specific test cases the implementer should add or update. Use behavior
phrases like "X happens when Y", not only test function names.>

## Scope guard
- Do not refactor unrelated code.
- Do not broaden this bead into adjacent backlog items.
- Do not run `rb-lite` itself, send signals to your own process tree, or
  otherwise interfere with the surrounding orchestration.
- Treat `.rb-lite/`, `.ralph-burning/`, `.git/ralph-burning-live/`, and
  `.beads/` as orchestration/state directories, not product code to review.

## Acceptance criteria
- <Acceptance criteria copied from `br show <id>`.>
- The repo's local gate set passes on the final tree.
```

The scope guard is load-bearing. Without it, reviewer rounds can ratchet into
adjacent beads or rb-lite's own run artifacts.

## Backlog dogfooding

Running rb-lite across a queue exposes workflow bugs. Capture them as beads
while the evidence is fresh:

- If rb-lite fails for a reason unrelated to the bead (tool crash, reviewer
  panel failure, auth/config breakage, task parser bug, ignored-files problem,
  or implementer self-interference), file a fresh bead with
  `br create -t bug -p <0|1|2> -l dogfood,rb-lite "..." -d "..."`. Include
  observed behavior, repro trace, expected behavior, likely fix options, and
  acceptance criteria.
- If the dogfood bead is P0 or P1, interrupt the queue and fix it next. Since
  rb-lite is stateless, record the interrupted bead id, branch, run dir, and
  JSON status; after the dogfood fix lands, restart rb-lite on that bead with
  the same task file.
- If the dogfood bead is P2 or lower, file it and keep moving.

## Constructing a good task

The task you pass via `--task` becomes part of the implementer's PROMPT
each round. A few rules from observed dogfood failures:

- **State the goal once, clearly.** Not "implement X and Y and consider Z";
  one focused outcome per run.
- **List hard constraints up front.** "Roughly N lines added," "do not
  introduce new abstractions," "smoke tests must pass." Constraints in
  the task save reviewer rounds.
- **Forbid self-experimentation.** Add: "Do not run `rb-lite` itself,
  send signals to your own process tree, or otherwise interfere with the
  surrounding orchestration." This prevents the implementer from "testing"
  its work by killing its own parent.
- **No literal magic strings.** Don't put example UUIDs, tokens, or
  anything that matches rb-lite's own session-ID regex into the task
  text — codex echoes the prompt to its stderr, and rb-lite scans
  stderr.
- **Reference, don't paste.** If the task touches a spec or PRD, point
  at the file path; don't inline 200 lines of spec into `--task`.

## Customizing the panel

The default panel is `codex review` + `claude -p` in parallel. To
override, drop a `.rb-lite-reviewers` file in the repo root before
running, with one shell command per line:

```
# .rb-lite-reviewers
codex review --base "$BASE"
claude -p "Review the diff vs $BASE. Tag findings P0/P1/P2/P3. Output 'No findings.' if clean." --permission-mode acceptEdits --allowedTools "Bash,Edit,Write,Read,Glob,Grep"
my-linter --json | wrap-as-p-tags
```

Reviewer commands run **concurrently**, get `BASE`/`RUN_DIR`/`ROUND`/
`REVIEWER_INDEX` in env, and have stdin closed. The panel succeeds with
at least one exit-0 reviewer; failed reviewers are noted but don't abort
the run.

The reviewer contract is strict:
- Findings on stdout, prefixed near the start of the line with the
  severity tag (`P2:`, `[P2]`, `**P2**:`, `Issue 1 (P2):`, …).
- Exit 0 = real review; exit non-zero = tool failure (output may be
  partial). A linter that exits non-zero on findings must be wrapped:
  `mylinter || true`.

## Exit codes and JSON schema

| Code | Status | Meaning | What to do |
|---|---|---|---|
| `0` | `clean` | Reviewers had no P0/P1/P2 findings (P3-only is also clean by default) | Ship; check `latest reviewer message in run-dir` for any leftover P3 nits worth addressing |
| `2` | `usage_error` | Bad CLI args, incl. no implementer selected (`--implementer` and `--implement-cmd` both absent) | Fix the invocation; the JSON line is still emitted with `run_dir: null` |
| `3` | `env_error` | Not in a git repo, missing tool, run-dir setup failure | Fix the env; rerun |
| `10` | `implementer_failed` | Implementer subprocess returned non-zero (incl. timeout 124/137) | Look at `implementer-round-N-iter-K.stderr` for the most recent iter |
| `11` | `review_panel_failed` | Zero reviewers exited 0 | Check `reviewer-round-N-K.stderr` for both reviewers; usually missing CLI or auth |
| `12` | `max_rounds_hit` | Burned all `--max-rounds` without convergence | Inspect the latest review files; either bump `--max-rounds`, lower `--min-findings-severity` to skip nits, or address the remaining findings manually |
| `13` | `consensus_failure` | Implementer kept declining to act on findings for `--max-noop-rounds` consecutive rounds | Read the latest review; the implementer is signaling it disagrees. Apply the fix manually if you side with reviewers, or override `--max-noop-rounds` if you side with the implementer |
| `70` | `internal_error` | Internal invariant violation or unhandled shell failure | Read `log.txt` and the most recent stderr files; this is rare |

The JSON schema (every exit, last stdout line):

```json
{
  "run_dir": "string | null",
  "exit_code": "integer",
  "status": "clean | usage_error | env_error | implementer_failed | review_panel_failed | max_rounds_hit | consensus_failure | internal_error",
  "rounds": "integer",
  "implementer_iterations": "integer",
  "noop_rounds_streak": "integer",
  "duration_secs": "integer",
  "config": {
    "max_rounds": "integer",
    "max_iters": "integer",
    "max_noop_rounds": "integer",
    "min_findings_severity": "string",
    "implement_timeout_secs": "integer | null"
  }
}
```

## When the loop misbehaves

- **Reviewers keep finding nits past round 5.** That's reviewer ratchet.
  Check the latest review file: if findings are P3-only, something is
  wrong with the severity floor (it should have stopped). Otherwise,
  consider raising `--min-findings-severity P1` to ignore P2s, or stop
  manually and apply the remaining items.
- **Implementer "stabilized at iteration 1" repeatedly.** That's the
  implementer declining to act. The consensus-failure stop will catch
  it after `--max-noop-rounds` (default 2) — exit 13. Don't lower this
  unless you understand the trade-off.
- **Run hangs.** rb-lite has a default 14400s (4 hour) per-iteration
  timeout — far longer than any realistic iteration. If it actually
  needs to be lower, pass `--implement-timeout SECS`.
- **`nix run` fails with HTTP 404.** The repo went private, or the user
  doesn't have access. Confirm
  https://github.com/douglaz/rb-lite is public and try again.

## Run artifacts to know

Inside `<run-dir>/`:

- `log.txt` — timestamped status lines (round/iter/panel transitions).
- `implementer-round-N-iter-K.{stdout,stderr}` — every implementer call.
- `reviewer-round-N-K.{stdout,stderr}` — raw output from each reviewer.
- `review-round-N-K.md` — per-reviewer markdown the implementer reads
  on the next round (with status header and stderr-tail for failed
  reviewers).

When something looks off, read these in order: `log.txt` → the latest
`review-round-*.md` files → the relevant `*.stderr`.

## Quick recipes

**Harden a feature branch before PR:**

```bash
rb-lite run \
  --implementer claude,codex \
  --task "Address any review-worthy issues on this branch. Smoke tests must still pass." \
  --base origin/main
```

**Convert a TODO into shipped code:**

```bash
rb-lite run \
  --implementer claude,codex \
  --task "Implement the TODO at src/foo.rs:42 per the comments above it. Do not refactor unrelated code." \
  --base origin/main \
  --branch dogfood/foo-todo
```

**Run one bead from a backlog:**

```bash
br show <id>
rb-lite run \
  --implementer claude,codex \
  --task-file .rb-lite/tasks/bead-<id>.md \
  --base origin/main \
  --branch feat/<id>-<short-slug> \
  --run-dir /tmp/rb-lite-<id>-run
```

**Run with a custom panel that disables the codex reviewer:**

```bash
echo 'claude -p "<...>" --permission-mode acceptEdits --allowedTools "Bash,Read,Grep,Glob,Edit"' >.rb-lite-reviewers
rb-lite run --implementer claude,codex --task "..." --base origin/main
```

(remove the file when done)

**Pin a single implementer (no cycling):**

```bash
rb-lite run \
  --implementer codex \
  --task "..." \
  --base origin/main
```
