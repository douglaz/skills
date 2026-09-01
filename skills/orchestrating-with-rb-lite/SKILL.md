---
name: orchestrating-with-rb-lite
description: >-
  Drive `rb-lite` implement-review-fix loops in the current git repo. Use for one
  self-contained branch task, a serialized `br` backlog drain (one bead, branch,
  rb-lite run, PR, merge, and closure at a time), or a harden-until-clean branch
  drive that turns codex + Claude findings into beads and drains them. Trigger on
  "rb-lite", "codex + claude until clean", "review-and-fix loop", "drain the bead
  backlog", "solve beads one by one", "harden this branch", or "review findings
  into beads". Use `testing-with-rb-lite` instead when the deliverable is a test or
  live verification gate that must be independently executed. Do not use for
  cross-project orchestration, open-ended planning, or tiny one-shot edits.
compatibility: Requires `rb-lite` on `PATH` or `nix run --refresh github:douglaz/rb-lite -- ...` (use `--refresh` at least once per session so Nix does not reuse an hour-stale cached revision). rb-lite itself has no default implementer, so pass `--implementer` with one preset or a comma-separated cycle, or use `--implement-cmd`; this skill defaults to `--implementer claude,codex` unless the user pins another choice. `codex` and `claude` must be installed and authenticated; the default Claude reviewer needs `jq`, and normal timeout-enabled runs need a compatible `timeout`, either from the host shell for source installs or from the Nix wrapper for Nix installs. This skill uses rb-lite's built-in panel (codex + a claude defect reviewer + a claude skeptic) and does NOT write `.rb-lite-reviewers`; requires rb-lite >= 0.3.0 for the skeptic, the per-round disposition counts, and `--max-production-lines`; >= 0.5.0 for declared skeptics and the separate `.rb-lite-skeptics` axis (the built-in skeptic is advisory from 0.4.0). Backlog-drain mode also requires `br` (>= 0.1.45), `gh`, and the repo's normal local verification tools; harden-until-clean mode additionally needs `codex` and `claude` for the outer review panel.
---

Use `rb-lite` as the default lightweight implement → review loop for
single-branch, single-task work in the current repo. Also use it as the
execution engine for draining an existing `br` backlog: `"$BEADS_JSONL_RESOLVER" --run-br ready` supplies
the work list, and each bead gets one focused rb-lite run. When the work list
does not exist yet and the goal is a clean branch, the harden-until-clean drive
generates it from a review panel and feeds the same drain.

## What rb-lite is, in one paragraph

`rb-lite` is a Bash CLI that loops a chosen implementer preset
(`--implementer claude,codex`, a comma-separated cycle, or a single
`codex`/`claude`; there is no default) until the git diff stabilizes, then
runs the reviewer panel in parallel (codex, a claude defect reviewer, and a
claude skeptic — all built in), feeds P0/P1/P2 findings back to the implementer for
another round, and stops when reviewers go clean, the implementer refuses to
keep changing things, or iteration limits (`--max-rounds` / `--max-iters`) are
hit. With a comma-separated list, round N uses
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
- The user wants a branch **hardened until review is clean** with a durable
  audit trail — findings become beads, beads become PRs — rather than fixed
  inline. See "Harden-until-clean drive" below.
- The change is bigger than a one-shot edit but small enough that managing
  it as a durable multi-stage project would be overhead the user doesn't want.
- The user wants a parseable summary of what happened (JSON line on stdout)
  rather than free-form prose.
- The user just wants a "review-and-fix" pass before opening a PR.

## Do NOT use this skill when

- The work spans multiple branches/projects, needs durable resumable state,
  or is still open-ended planning. Convert the plan into beads or a clearer
  spec first, then run rb-lite on one bounded unit at a time. Serialized bead
  draining is the exception: `br`, branches, PRs, and CI are the durable state,
  while rb-lite only runs one bead at a time.
- The user explicitly wants direct manual edits without an orchestration
  loop, or a single quick patch.
- The environment has no `codex` or `claude`, or a non-Nix rb-lite install has
  no `jq` or compatible `timeout`, and the user can't install them — the
  default panel won't work as intended.
- The user wants a *one-shot* code review without any fix loop — `codex
  review` directly is simpler.

## Tool dependencies

Resolution order, in this order:

1. `command -v rb-lite` — installed binary on PATH.
2. `nix run --refresh github:douglaz/rb-lite -- ...` — public flake; works on
   first run after a short build, cached afterwards.

**Always pass `--refresh` on the first `nix run` of a session.** Without it,
Nix reuses the GitHub revision it resolved earlier (`tarball-ttl`, one hour by
default) and silently runs a stale rb-lite — which is how you end up debugging
"unknown run option" errors against a binary that was fixed upstream days ago.
`--refresh` costs one extra ref lookup; the build itself is still cached when
the revision hasn't moved. Once you've refreshed, later invocations in the same
session can drop the flag.

If neither path works, stop and tell the user to install `rb-lite` (e.g.
`nix profile install github:douglaz/rb-lite`) or expose it on PATH.

**Preflight, once per run:** `rb-lite --version` must be >= 0.3.0 (older builds have no
skeptic and reject `--max-production-lines` as an unknown flag — with the Nix fallback, pass
`--refresh`). And check for an existing `.rb-lite-reviewers` in the repo root: rb-lite loads
it automatically, so a file left over from an earlier run silently replaces the gating
panel. Rename it aside for the run. On 0.5.0+ also check `.rb-lite-skeptics`, and if the
stale reviewers file carries a skeptic line, move it there — listed as a gating reviewer it
starts rounds. rb-lite warns when it spots one, but only after the run has begun.

**Use rb-lite's built-in panel.** The default is `codex review`, a `claude` defect reviewer,
and a `claude` **skeptic** that hunts over-specification and tags findings `CUT` / `SIMPLIFY`
/ `DEFER`. The skeptic is the only panel member that can argue for removing something; the
other two structurally can only argue for adding.

Skeptics are **advisory** — they inform rounds the defect reviewers keep alive and never
start one. On rb-lite 0.3.x the skeptic's hardcoded `P2` against a `P2` floor could not let a
run converge at all: one 2026-08 drive went clean in 0 of 8 runs, every one ending at
max-rounds and escalating to a human.

From **0.5.0 the panel is two files**, because rb-lite cannot tell a skeptic from a defect
reviewer by looking at it — both are opaque shell commands emitting severity-tagged lines,
so the role has to be declared:

| file | role | findings |
| --- | --- | --- |
| `.rb-lite-reviewers` | gating | start rounds |
| `.rb-lite-skeptics` | advisory | inform rounds that happen; never start one |

Each falls back to its built-in default when absent or empty, so **overriding the gating
panel keeps your counter-pressure**, and a skeptic you declare is advisory exactly like the
built-in one. On 0.3.x/0.4.x one file held both: `--reviewers-file` deleted the skeptic with
the panel, and carrying one back in made it *gating*, which drove runs with clean defect
reviewers to `consensus_failure` (13). If you are on those versions, that trade is still
live — check `rb-lite --version` before overriding.

To override, write to a `mktemp` path passed via `--reviewers-file` / `--skeptics-file` —
never `cat >.rb-lite-reviewers` in the repo root, which destroys an existing panel or leaves
an untracked file that trips LAND's clean-tree gate. Commands are in
[references/reviewer-panel.md](references/reviewer-panel.md).

Every reviewer must be READ-ONLY: `Edit`/`Write` plus `acceptEdits` would let one panel
member mutate the worktree while another reads it, so the two review different trees, and
any edit made that way bypasses the implementer loop entirely. Each must also read
`AGENTS.md`, which is how a repo's own invariants reach the panel when this runs under
`drive`; without it that reviewer reviews without them.

### Convergence guards (rb-lite >= 0.3.0)

Three things now happen mechanically that this skill previously asked you to notice:

- **Decisions are counted.** The implementer records one line per finding in
  `challenges-round-$ROUND.md` (`ACCEPTED` / `DECLINED` / `DEFERRED`); rb-lite reports the
  per-round totals in the log and the summary (`rejections_total`, `rejections_by_round`).
- **Zero rejections warns by itself.** After three consecutive rounds declining nothing while
  the panel keeps reporting, the log carries a one-time warning. You no longer have to watch
  for it — you have to *act* on it. It is a signal, not a stop.
- **The budget is enforced.** Pass `--max-production-lines N`, 3x the `Baseline:` in
  `DRIVE.md` (Guard 2). Exit `14` names the largest contributors; test and fixture paths are
  excluded, since a budget counting tests is met by deleting coverage. It is a **stop, not a
  retry target** — re-shape the work, never relaunch with a bigger number.

### Do not hand-roll this loop

One review round on a change is fine. The second is rb-lite's job: if you would feed a
reviewer's findings back to an implementer, run rb-lite rather than spawning your own agents
and relaying between them. A hand-rolled loop has no round cap, no rejection accounting, no
skeptic, no budget, and no `consensus_failure` stop — it produced 96 agents and 38
consecutive `fix:` commits on 2026-08-18, on a design replaced three days later.

**The same prohibition binds you.** An edit made to a tracked file while `codex review`
is running is silently destroyed, and rb-lite runs `codex review` inside every review
round — so for the length of a run the repo is not yours to touch. The loss surfaces as
`nothing to commit, working tree clean` on a commit you expected to carry work, with the
content absent from the file *and* from `HEAD`. Wait for the run to exit before editing
anything, then commit by the procedure in
[references/verifying-the-diff.md](references/verifying-the-diff.md): a clean `git status`
is not a check — it reads identically whether the work was committed or reverted
underneath you.

[references/reviewer-panel.md](references/reviewer-panel.md) shows the same two commands
alongside OPTIONAL extras — a
skeptical third reviewer and a `my-linter --json | wrap-as-p-tags` placeholder — which are
illustrative, not prerequisites. Pasting that block wholesale puts a command-not-found
reviewer in the panel and every round carries its failure.

`codex` and `claude` must be on PATH and authenticated. The Claude reviewer needs `jq`,
and normal rb-lite runs need a `timeout` binary supporting `--kill-after` because both
implementer and reviewer timeouts are enabled by default. If rb-lite is resolved through
`nix run --refresh github:douglaz/rb-lite --` or a Nix-profile wrapper, do not reject the
setup just because the host shell cannot find `jq` or GNU `timeout`; the upstream wrapper
supplies those to the rb-lite process. For source/path installs, check the host shell.

Skipping both files is the simplest path: you get codex, the claude defect reviewer, and
the skeptic, all pinned, with no `npx`. On 0.5.0+ writing a reviewers file no longer costs
you the skeptic — it is a separate axis. On 0.3.x/0.4.x it does, and carrying one back into
the reviewers file makes it gating, so on those versions the honest choice is to keep the
built-in panel.

**Companion unavailable: stop, rerun the same installer command once, reload it, and do
not improvise this procedure.** This applies to every exact companion handoff below.

Backlog-drain mode additionally needs `br` for bead selection/state, `gh`
for PR creation/checks/merge, and **`jq` in the HOST shell**. That last one is not
covered by the Nix-wrapper exemption above: the wrapper supplies `jq` to rb-lite, not
to you. Load exact companion skill `rb-lite-backlog-drain` for
[step 11's collateral-damage check and recovery](../rb-lite-backlog-drain/SKILL.md#backlog-step-11),
which resolve the graph's real path through exact companion
`beads-jsonl-path/scripts/resolve-beads-jsonl` — its default clean-state mode before the
first write, `--allow-dirty` for the structurally tracked post-write field diff, and
`--recovery` only when naming the damaged artifact. Without that owner a drain can run `"$BEADS_JSONL_RESOLVER" --run-br update`
and flush — silently reverting unrelated bead bodies — and only then fail at the command
that would have located the damage. Check it before the first bead, not after. Require **`br` ≥ 0.1.45**: older builds corrupt
their DB after branch resets, so `"$BEADS_JSONL_RESOLVER" --run-br update`/`"$BEADS_JSONL_RESOLVER" --run-br close` start returning
`ISSUE_NOT_FOUND` while `"$BEADS_JSONL_RESOLVER" --run-br show`/`"$BEADS_JSONL_RESOLVER" --run-br list` keep working — which hides the
failure until bead state is already lost. Both drain modes reset branches after
every merge, so they hit that bug hard. It should use the repo's documented local gates;
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

To update: `nix run --refresh github:douglaz/rb-lite -- ...` for the nix
fallback, `nix profile upgrade` for a Nix-profile install, or `git pull` plus a
rebuild for a source/path install. Retry the rejected flag after updating
before you fall back to the older calling convention — a stale flake cache is
the most common cause of these "predates X" errors.

## Required outputs

When you finish a run on the user's behalf, report:

1. The binary you used (`rb-lite` from PATH, or `nix run --refresh
   github:...`).
2. The exit code and the `status` field from the JSON summary.
3. Rounds completed and the final reviewer state (clean, consensus
   failure, max-rounds, etc.).
4. The run artifact directory path so the user can inspect logs.
5. The independent verification you ran on the landed diff, and whether it
   passed.
6. If the run failed (codes 10/11/12/13/70), a one-sentence diagnosis
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
- Default to the **simplest correct implementation for the milestone**, and bound
  every task with non-goals + a size budget — overengineering via the reviewer
  ratchet is a primary failure mode (see "Guard against overengineering").
- Read the JSON summary line, don't paraphrase. The schema is stable and
  parseable.
- **Treat `clean` as "no panel objections," not "verified correct."** rb-lite
  leaves the final accepted diff **uncommitted in the working tree** (it does
  not commit on your behalf) — always `git status` / `git diff` to see what
  actually landed, then commit it yourself. And the panel may be **degraded**:
  it succeeds with as few as one exit-0 reviewer, so a `clean` verdict can rest
  on a single surviving reviewer (check `log.txt` for the `K of M reviewers
  succeeded` line and the `review-round-*.md` status headers). Before trusting a
  run, **independently re-run the repo's own gates** (tests, goldens/digests,
  fmt/clippy) on the landed diff — and, because those gates were already green
  before the run, **invert each load-bearing behavior it introduces and confirm
  the assertion pinning that behavior goes red**; for high-stakes work add a
  **separate adversarial result-review** (e.g. `codex exec` over the committed
  diff) — the panel's `clean` is one input, not the gate. See "Verify the landed
  diff."
- In backlog-drain mode, one bead equals one branch and one **work** PR. Do not batch
  unrelated beads into one rb-lite run. The final closure/metadata PR
  ([exact companion skill `rb-lite-backlog-drain`, step 11](../rb-lite-backlog-drain/SKILL.md#backlog-step-11)) is not a
  second work PR and is not covered by this rule — it carries bookkeeping only.
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
   prefix every invocation with `nix run --refresh github:douglaz/rb-lite --`.
   Keep `--refresh` on at least the first invocation so you don't run an
   hour-stale cached revision. Note the resolved invocation in your plan so the
   user knows what's running.

3. **Confirm prerequisites and choose the implementer.** Always check
   `command -v codex` and `command -v claude`; if either is missing, stop and
   tell the user. For a source/path rb-lite install, also check `command -v jq`
   and `timeout --kill-after=1s 1s true`. For the
   `nix run --refresh github:douglaz/rb-lite --` invocation or a Nix-profile
   wrapper, skip
   host `jq`/`timeout` rejection because the wrapper supplies them inside
   rb-lite. If compatible `timeout` is genuinely unavailable for the resolved
   rb-lite invocation, stop unless the user explicitly accepts disabling both
   subprocess timeouts and you pass
   `--implement-timeout '' --reviewer-timeout ''` on every invocation. Check
   rb-lite has **no default
   implementer**: pass `--implementer` with a single preset or a comma-separated
   cycle (or a raw `--implement-cmd`). Default to `--implementer claude,codex`
   unless the user pins one — round 1 runs claude, and each review round with
   findings hands off to the next preset in the cycle (wrapping). Session reuse
   stays within a round, so cycling never resumes the other agent's session.
   Omitting all of these is a usage error (exit 2).

4. **Confirm the git state.** rb-lite refuses to run outside a git repo
   and ignores changes under `.rb-lite/`, `.ralph-burning/`, and
   `.git/ralph-burning-live/` (those are runtime state). If the working
   tree has unrelated dirty changes the user didn't mention, surface that
   before launching — they will be in scope for the implementer and
   reviewers. If the user intentionally wants rb-lite to operate on
   existing uncommitted work, save an explicit pre-run snapshot first
   (commit, stash, or patch file) so recovery can return to that exact
   state without deleting unrelated work.

5. **Pick a base ref.** Try in order: the explicit user choice, then
   `origin/main`, `origin/master`, `main`, `master`. Pick the first that
   resolves. Print the chosen ref in your plan and always pass it with
   `--base`; upstream rb-lite's own CLI default is still `origin/master`.

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

   **Long background runs — let your harness own the background lifecycle.**
   If your harness has a tracked-background primitive, launch rb-lite directly
   under it and stop it through that same primitive: the harness keeps the task
   alive across turns, captures its output, and reaps it cleanly — so you get
   the survival you want without fighting the tooling. (Claude Code: run it in
   the Bash tool's background mode and stop with TaskStop. Codex: the launch
   returns a session id you stop through. Other hosts: use whatever tracked-task
   stop your host provides.) Run the same command as above; nothing wraps it:

   ```bash
   rb-lite run \
     --implementer claude,codex \
     --task-file /tmp/rb-<short-tag>-task.md \
     --base origin/main \
     --run-dir /tmp/rb-<short-tag>-run
   ```

   **Don't detach it from the harness.** Backgrounding rb-lite in its own
   session — where the harness can no longer see it — buys nothing here: a
   tracked background task already survives across turns, and the survival
   guarantee was never the process boundary anyway. rb-lite is resumable and
   leaves its diff in the tree, and you verify the landed diff regardless (step
   10.5), so a mid-run kill costs time, not correctness. Detaching only costs
   you the harness's own tooling: no clean monitoring, no one-call stop through
   the harness, and PID-hunting — via the collateral-kill-prone `pkill -f
   rb-lite` (see "When the loop misbehaves") — to stop it.

9. **Read the JSON summary.** rb-lite always prints a single-line JSON
   object as the last line of stdout, on success and failure. Pipe to
   `jq` if available; otherwise grep the line. The schema is in
   [references/exit-codes-and-artifacts.md](references/exit-codes-and-artifacts.md).

10. **Diagnose by exit code.** Don't pattern-match on the human-readable
    line; match on the JSON `status` and `exit_code`. The mapping is
    fixed (see [references/exit-codes-and-artifacts.md](references/exit-codes-and-artifacts.md)).

10.5 **Verify the landed diff yourself (do not skip).** rb-lite's `clean` is the
    panel's verdict, not ground truth, and the panel is often degraded. The diff is
    left **uncommitted**; commit it yourself only after checking it. Work through
    "Verify the landed diff" below in full — five specific checks, and the mutation
    one is what a green suite cannot substitute for.

    **A mutation that stays green stops this workflow too**, exactly as it stops the
    backlog drain. Standalone use continues to **11. Report concisely** immediately
    below with the diff already committed at (a), so without a stop the uncovered behavior ships and the
    run reports success. Repair the test, observe both runs, and re-review the repair
    — or report the run as incomplete and name the unpinned behavior.

11. **Report concisely.** Tell the user what shipped, what didn't, where
    artifacts are, and whether anything needs manual follow-up. Don't
    paste the full review files — they're on disk.

## Long-run operator discipline

The old heavyweight project workflow carried useful habits that still matter
when rb-lite runs for more than a quick pass:

- **Use task files for nontrivial work.** Prefer `--task-file` with the same
  structure as the backlog template: problem description, implementation hints,
  required changes, tests, scope guard, and acceptance criteria. Keep large specs
  referenced by path rather than pasted into the prompt.
- **Treat git + run artifacts as the source of truth.** rb-lite is stateless; the
  durable state is the branch, the worktree, the run dir, any bead/PR state, and
  the final JSON line. Use `git status`, `git diff`, `log.txt`, and the latest
  `review-round-*.md` files instead of reconstructing state from memory.
- **Track convergence, not just completion.** Healthy runs trend toward fewer
  actionable findings and smaller diffs. If findings oscillate, new sibling
  findings keep appearing, or reviewers start debating scope, stop and re-scope
  or finish manually.
- **Do not restart blindly.** Before rerunning after a failure, record the branch,
  run dir, JSON status, and whether the worktree should be preserved, restored to
  the pre-run snapshot, or split into a smaller unit.

## Verify the landed diff

The single most important habit when driving rb-lite for real work: **`clean` means "no
surviving reviewer raised a P0/P1/P2," not "correct."** The diff is left **uncommitted**;
commit it yourself only after checking it.

Five checks, in [references/verifying-the-diff.md](references/verifying-the-diff.md) —
read it in full at step 10.5:

1. The diff is uncommitted — inspect it, and watch for stray scratch files.
2. The panel degrades silently — it succeeds on one exit-0 reviewer, so confirm real
   panel strength before trusting `clean`.
3. Independent verification is the gate, not the panel.
4. Verify the comments, not just the code — a loop can corrupt a correct invariant
   comment to placate a reviewer, and tests never catch it.
5. **A green suite does not prove the diff is covered.** Invert each load-bearing
   behavior the diff introduces and confirm the assertion pinning it goes red. Isolate
   the run first if the gate touches anything live — the mutation is not a dry run.

Check 5 is the one a green suite cannot substitute for: one observed nine-round run
ended `clean` with 685 tests, three demos, a 16/16 adversarial suite and CI all green,
and swapping a single argument at one call site still left all 498 lib tests passing.

That reference also carries the commit procedure — how to stage and confirm the content
actually landed, since `git commit` on a tree another agent touched can report success
while carrying only part of your change.

## Backlog-drain workflow

Load exact companion skill
[`rb-lite-backlog-drain`](../rb-lite-backlog-drain/SKILL.md) before starting this
mode. It owns the complete 12-step pick → branch → rb-lite → gate → PR →
merge → bead-close → resume procedure; the general rules in this file still apply.

## Harden-until-clean drive

Use this mode when the user wants a **branch hardened until review is clean**
and there is no backlog yet. It is the backlog drain with an outer loop bolted
on: a review panel generates the work list, the drain executes it, then the
panel runs again over everything that merged.

```
loop:
  findings = review_panel(work_branch, base=review_base)   # codex + claude reviewer, parallel
  if none: break                                           # DONE
  beads   = mint(triage(findings))                         # one bead per real defect
  drain(beads)                                             # the Backlog-drain workflow above
```

Triggers: "harden this branch", "review and solve until clean", "keep running
review+fix passes until it's clean", "turn the review findings into beads".

**Why bother, when rb-lite already reviews inside each run?** Different diff
bases. rb-lite's panel sees one bead's branch diff; the outer panel sees the
work branch against its base — every merged bead plus the original work. A bead
that tightens a server predicate passes its own review and breaks callers the
run never looked at. Only the outer pass catches that, which is why later
iterations mostly surface regressions from earlier fixes. That is the loop
working.

The full procedure — panel invocations and reviewer prompt, triage rules, the
sibling sweep, bead minting with `review-src:` labels and priority mapping, stop
conditions, and what to expect — is in
[references/harden-until-clean.md](references/harden-until-clean.md). Read it
before iteration 1.

The load-bearing points, if you read nothing else:

- **The work branch must be disposable.** Never `main`/`master` or a shared
  branch; the loop resets it to origin after every merge.
- **Run the two reviewers in parallel and never show one the other's findings.**
  Correlated reviewers are one reviewer at twice the price.
- **One defect, one bead.** Dedupe across reviewers before `"$BEADS_JSONL_RESOLVER" --run-br create`, or you
  build yourself a merge conflict out of two branches fixing the same line.
- **Every bead's acceptance criteria name what must KEEP working**, not only
  what is broken. Skip that and a security narrowing produces an over-correction
  bead next iteration.
- **Sweep for siblings yourself.** When a finding names one instance of a class,
  grep for the rest and mint those beads now — it collapses two or three future
  iterations into one.
- **Both reviewers clean ends the loop.** A reviewer that failed transiently gets
  rerun; one that is permanently unavailable ends the loop at `CLEAN_DEGRADED`,
  named. There is no pass limit here, so that exit is what keeps a
  single-reviewer machine from iterating forever.
- Expect **10–20 iterations and dozens of PRs** on a substantial branch. Say so
  before starting; do not begin without explicit agreement.

## Backlog task template

Nontrivial work goes in a `--task-file`, not a `--task` string. The template, its
load-bearing scope guard, how to bound a bead that could sprawl, and how to file
dogfood findings are in [references/task-files.md](references/task-files.md).

The parts that decide whether a run stays in its lane:

- **The scope guard is load-bearing.** Without it, reviewer rounds ratchet into
  adjacent beads and into rb-lite's own run artifacts.
- **Lock the files on a high-blast-radius bead.** Naming the exact file(s) the
  implementer may create or modify — and forbidding all others — is a far stronger
  brake than a generic "don't refactor unrelated code," because it names the boundary.
  One unbounded run reached 25 rounds and a 3600-line module that also rewrote four
  already-merged files, and had to be discarded wholesale.
- **Acceptance criteria name what must KEEP working**, not only what is broken.
  Criteria that only describe what to block get signed off, and the breakage comes
  back as its own bead later.
- **Watch the run.** Active supervision is the control; `--max-rounds` is a checkpoint
  to assess and relaunch, not a finish.

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
- **Keep the formatter scoped.** The implementer runs the project formatter
  (`cargo fmt`, `prettier`, …) each round. On a tree that isn't already
  format-clean it'll reformat the WHOLE workspace, burying the bead's real diff
  in unrelated churn (and dragging those files into the reviewers' scope). Before
  launch, run the repo's formatter check against the selected base. If it fails,
  land or isolate that formatting cleanup before starting the bead branch. Then add
  to the task: "run the formatter only on the files you changed; do not reformat
  unrelated files."
- **Lock the files on high-blast-radius beads.** If the bead sits next to modules
  the implementer might rewrite, name the exact file(s) it may create/modify and
  forbid all others — see [references/task-files.md](references/task-files.md).

## Guard against overengineering

The reviewer panel ratchets by design: each round surfaces deeper edge cases, so
relaying every finding back grows the change without bound — a "simple" bead can
balloon into thousands of lines of speculative hardening across several rounds.
Default to the **simplest correct implementation for the milestone**, and bound it
actively. This is a primary failure mode, not a nicety.

- **Every task carries a non-goals / "do NOT build" list and a rough size budget.**
  Name what to leave OUT — defensive edge cases beyond the milestone's threat
  model, config knobs, new abstractions, retry/scheduling machinery — and a target
  like "one focused module, ~N lines; if you're writing materially more, stop and
  simplify." Pin "done" to the specific named tests and nothing beyond them.
- **At the gate, judge each finding — don't reflexively relay or reflexively cut.**
  Genuine P0/P1 milestone blockers (money / secret / correctness) always go back.
  Real P2 polish is worth keeping too — relay it while it's improving the code. P3
  is inspection-only under the default P2 floor unless you intentionally lower the
  floor to chase nits. The judgment call is *when low-severity polish turns into
  gold-plating* (hardening past the goal, edge cases beyond the threat model): at
  that point stop feeding it and merge. A verified minimal bead beats an ever-deeper
  one. **Do not reach for `--min-findings-severity P1` to stop gold-plating**: it silences the
  defect reviewers' P2s, where real should-fix findings live, and buys nothing against
  over-building. rb-lite warns. Stop feeding the loop and merge instead, or `--no-skeptic`
  for no counter-pressure.
- **Proxies flag, analysis confirms.** A climbing **round count** and a **line count**
  far past comparable beads raise the alarm, but both mislead — a hard bead earns its
  rounds, a verbose module earns its lines. Treat them as the cue to **re-read the GOAL
  and compare it to what was actually built**: do the modules, abstractions, edge cases,
  and config surface match what the goal requires? When they diverge, cut back to the
  goal. The proxy is never the verdict.

## The fractal tail, and challenging the panel

The ratchet has a sharper failure mode than just "deeper edge cases." When the
implementer *fixes* a finding by **adding** a mechanism, that mechanism becomes
new review surface, so the next round flags *its* edge cases. The loop then
generates roughly as many findings as it resolves: a fractal tail, not
convergence. The tell is findings holding steady or rising while each round's
findings are visibly ripples of the last round's additions, and the core has
been clean for several rounds.

- **The implementer may challenge the panel, with evidence.** Reviewer findings
  are hypotheses, not orders. A finding can be a false positive, *or* valid as
  stated but not worth building (over-specification: it adds build/test surface
  without preventing a real correctness, security, or data-loss problem). Decline
  those instead of reflexively implementing, and record why, using the
  over-specification test: "if I don't do this, what actually breaks, a real
  correctness problem or only an operational inconvenience?" A round where the
  implementer declines findings *with documented reasons* is a legitimate stop
  (exit 13 `consensus_failure`), not a stall to override. Read the implementer's
  reasons before siding with the panel.
- **Zero rejections across many rounds is a red flag.** If the implementer has
  accepted every finding for several rounds, it's probably being too credulous
  and the change is over-built. That's the cue to run a skeptical pass.
- **Keep the skeptic in the panel.** Defect reviewers hunt *what's wrong*, which is
  to say *what to add*; the skeptic hunts *what's over-built*. From rb-lite 0.5.0 it
  survives a custom gating panel (separate file), so the only way to lose it is
  `--no-skeptic` — worth it only for a small, already-bounded bead. On 0.3.x/0.4.x a
  supplied `--reviewers-file` silently took it with them.
- **Periodic skeptical audit.** When the fractal tail shows up, or before merging
  a large run, stop relaying and run one inverted audit yourself: walk what the run
  added and label each mechanism *required-for-correctness* versus
  *defense-in-depth / operational*. Cut, simplify, or mark-optional the latter.
  Reconcile its output through your own judgment (accepting every cut is the same
  credulity in reverse), then re-verify the core is intact with no dangling
  references to anything you removed.

## Customizing the panel

rb-lite's built-in panel is `codex review` + a `claude` defect reviewer + a `claude`
skeptic, and this skill uses it as-is. Override only for a reason you can name. On 0.5.0+
`--reviewers-file` replaces only the **gating** reviewers and skeptics keep coming from
their own axis; on 0.3.x/0.4.x it replaces the whole panel, so overriding there silently
returns the loop to add-only pressure.

The reviewer commands, the OPTIONAL extras menu, the verify-before-asserting rule every
custom prompt needs, and the strict reviewer contract (findings on stdout with a severity
tag near the line start; exit 0 = real review, non-zero = tool failure; a linter that
exits non-zero must be wrapped `mylinter || true`) are in
[references/reviewer-panel.md](references/reviewer-panel.md).

Do not `cat >.rb-lite-reviewers` in the repo root — that destroys an existing panel or
leaves an untracked file that trips LAND's clean-tree gate. Write to a `mktemp` path and
pass `--reviewers-file`.

## Exit codes and JSON schema

The full table, the JSON summary schema, and the per-run artifact list are in
[references/exit-codes-and-artifacts.md](references/exit-codes-and-artifacts.md).
Match on the JSON `status` and `exit_code`, never on the human-readable line.

The ones you will actually meet: `0 clean` (verify it anyway), `11 review_panel_failed`
(no *defect* reviewer exited 0 — the skeptic's lone vote is not a review), `12
max_rounds_hit`, `13 consensus_failure` (the implementer is declining findings — read
its reasons before overriding; evidence-backed rejections make this a legitimate stop),
and `14 budget_exceeded` (a **stop, not a retry target** — re-shape the change, never
relaunch with a bigger number).

When something looks off, read `log.txt` → the latest `review-round-*.md` →
the relevant `*.stderr`.

## When the loop misbehaves

Symptom-to-cause list in [references/troubleshooting.md](references/troubleshooting.md):
nits past round 5, an implementer that keeps stabilizing at iteration 1, a dead
implementer (exit 10), a whole run killed by a stray signal, a ballooning bead, a hang,
`nix run` 404s, and flags rejected by a stale cached revision.

One rule worth carrying without looking it up: **never `pkill -f rb-lite`.** The pattern
matches your own shell — exit 144, self-kill — *and* every other session's run. Stop the
tracked background task, or SIGTERM the exact wrapper PID.

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
# First initialize BEADS_JSONL_RESOLVER with the installed companion procedure
# in references/harden-until-clean.md section 2.
"$BEADS_JSONL_RESOLVER" --run-br show <id>
rb-lite run \
  --implementer claude,codex \
  --task-file .rb-lite/tasks/bead-<id>.md \
  --base origin/main \
  --branch feat/<id>-<short-slug> \
  --run-dir /tmp/rb-lite-<id>-run
```

**Bound a high-blast-radius bead (file-locked, checkpoint rounds):**

```bash
# The task file pins EXACTLY the file(s) the implementer may create/modify and
# forbids all others (see references/task-files.md). --max-rounds is a
# CHECKPOINT to assess and (if the code is sound) relaunch — not a finish. Leave the
# default severity so real P2 polish lands; P3 is manual/inspection-only unless you
# deliberately lower the floor. Do NOT add --min-findings-severity P1 to curb
# gold-plating: it silences the defect reviewers' P2s, where real should-fix findings
# live. Watch each round as it lands.
rb-lite run \
  --implementer claude,codex \
  --task-file .rb-lite/tasks/bead-<id>.md \
  --base origin/main \
  --branch feat/<id>-<short-slug> \
  --run-dir /tmp/rb-lite-<id>-run \
  --max-rounds 6
```

**Run with a custom panel that disables the codex reviewer:**

```bash
# Requires rb-lite >= 0.5.0. On 0.3.x/0.4.x a reviewers file replaces the WHOLE panel, so
# this exact form would drop the skeptic silently — check `rb-lite --version` first.
RB_REVIEWERS=$(mktemp)   # never `cat >.rb-lite-reviewers` in the repo root
# Only the DEFECT reviewer goes here. The skeptic stays on its own axis and is still added
# from .rb-lite-skeptics (or the built-in one), so this disables codex without costing you
# counter-pressure. An EMPTY file is treated as no file at all, so rb-lite would fall back
# to the built-in panel and codex would NOT be disabled.
cat >"$RB_REVIEWERS" <<'EOF'
<defect reviewer line>
EOF
rb-lite run --implementer claude,codex --task "..." --base origin/main --reviewers-file "$RB_REVIEWERS"
rm -f "$RB_REVIEWERS"
```

**Pin a single implementer (no cycling):**

```bash
rb-lite run \
  --implementer codex \
  --task "..." \
  --base origin/main
```
