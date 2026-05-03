---
name: orchestrating-with-rb-lite
description: >-
  Uses `rb-lite` to drive a small, dependency-free implement → review loop
  on the current git repository: codex as the implementer, codex + claude as
  a parallel reviewer panel, automatic stop conditions for review-clean,
  reviewer-vs-implementer consensus failure, P3-only nit ratchet, and
  budget-cap exhaustion. Use when the user says "rb-lite", "use rb-lite",
  "run the rb-lite loop", "iterate on this with rb-lite", "implement this
  with codex + claude until clean", "review-and-fix loop on this branch", or
  asks for an iterative codex-and-claude review/fix cycle scoped to the
  current branch. Also use when the user wants a quick way to harden a
  feature branch before opening a PR without setting up a full ralph-burning
  project. Prefer `rb-lite` for single-branch, single-task work where you
  just want "code → review → fix → repeat → JSON summary." Do NOT use for
  cross-project orchestration, durable run state, multi-flow stages,
  resumable failed runs across sessions — for those, prefer
  `ralph-burning`. Do NOT use for tiny direct edits, pure explanations, or
  one-shot patches the user could apply themselves in less time than a
  single rb-lite round.
compatibility: Requires `rb-lite` on `PATH` or `nix run github:douglaz/rb-lite -- ...`. Both `codex` and `claude` CLIs must be installed and authenticated for the default reviewer panel.
---

Use `rb-lite` as the default lightweight implement → review loop for
single-branch, single-task work in the current repo. Prefer it over ad hoc
"please review and fix this" prompts when the work is meaningful enough that
a real reviewer pass adds value, but small enough that a full
`ralph-burning` project would be overkill.

## What rb-lite is, in one paragraph

`rb-lite` is a Bash CLI that loops `codex exec` (the implementer) until
the git diff stabilizes, then runs `codex review` and `claude -p` in
parallel against the diff, feeds P0/P1/P2 findings back to the implementer
for another round, and stops when reviewers go clean, the implementer
refuses to keep changing things, or a budget cap is hit. Every exit emits
a single JSON line on stdout summarizing the run. No daemons, no state DB,
just a script and the per-run artifact directory.

## Use this skill when

- The user explicitly asks for `rb-lite` or "the rb-lite loop."
- The user wants codex + claude to iterate on the current branch until a
  panel review is clean, on a self-contained task.
- The change is bigger than a one-shot edit but small enough that managing
  it as a `ralph-burning` project would be overhead the user doesn't want.
- The user wants a parseable summary of what happened (JSON line on stdout)
  rather than free-form prose.
- The user just wants a "review-and-fix" pass before opening a PR.

## Do NOT use this skill when

- The work spans multiple branches/projects, needs durable resumable state,
  or wants the planner/implementer/reviewer/final_review staging that
  `ralph-burning` provides — defer to `orchestrating-with-ralph-burning`.
- The user explicitly wants direct manual edits without an orchestration
  loop, or a single quick patch.
- The codebase has no `codex` or `claude` available and the user can't
  install them — the default panel won't work.
- The user wants a *one-shot* code review without any fix loop — `codex
  review` directly is simpler.

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

## Required outputs

When you finish a run on the user's behalf, report:

1. The binary you used (`rb-lite` from PATH, or `nix run github:...`).
2. The exit code and the `status` field from the JSON summary.
3. Rounds completed and the final reviewer state (clean, consensus
   failure, max-rounds, etc.).
4. The run artifact directory path so the user can inspect logs.
5. If the run failed (codes 10/11/12/13/70), a one-sentence diagnosis
   pointing at which artifact to look at.

## Default stance

- Run from the user's current branch in their current working directory.
  Don't `git switch` unless the user asks for a feature branch
  (`--branch NAME`).
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

## Workflow

1. **Confirm the work is rb-lite-shaped.** Reread the user's request. If
   it's a one-shot edit or a multi-project initiative, redirect.

2. **Resolve the binary.** `command -v rb-lite` first; otherwise plan to
   prefix every invocation with `nix run github:douglaz/rb-lite --`. Note
   the resolved invocation in your plan so the user knows what's running.

3. **Confirm prerequisites.** `command -v codex` and `command -v claude`.
   If either is missing, stop and tell the user — the default panel won't
   work, and silently substituting a single-reviewer panel would change
   the loop's behavior.

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
| `2` | `usage_error` | Bad CLI args | Fix the invocation; the JSON line is still emitted with `run_dir: null` |
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
  --task "Address any review-worthy issues on this branch. Smoke tests must still pass." \
  --base origin/main
```

**Convert a TODO into shipped code:**

```bash
rb-lite run \
  --task "Implement the TODO at src/foo.rs:42 per the comments above it. Do not refactor unrelated code." \
  --base origin/main \
  --branch dogfood/foo-todo
```

**Run with a custom panel that disables the codex reviewer:**

```bash
echo 'claude -p "<...>" --permission-mode acceptEdits --allowedTools "Bash,Read,Grep,Glob,Edit"' >.rb-lite-reviewers
rb-lite run --task "..." --base origin/main
```

(remove the file when done)
