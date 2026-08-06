---
name: orchestrating-with-rb-lite
description: >-
  Uses `rb-lite` to drive lightweight implement → review loops in the current
  git repo. Covers one self-contained task on a branch, a serialized `br`
  backlog drain where each ready bead becomes one branch, one rb-lite run, one
  work PR, one squash merge, and one bead closure, and a harden-until-clean drive
  that reviews a whole branch with a codex + Claude Fable panel, mints beads
  from the findings, drains them, and re-reviews until clean. Use when the user
  says "rb-lite", "use rb-lite", "run the rb-lite loop", "iterate on this with
  rb-lite", "implement this with codex + claude until clean", "review-and-fix
  loop on this branch", "drain the bead backlog with rb-lite", "solve beads
  one by one with rb-lite", "harden this branch", "review and solve until
  clean", "review findings into beads", or asks for an iterative codex+claude
  review/fix cycle. Prefer `rb-lite` when you want "code → review → fix →
  repeat → JSON summary" without a durable project orchestrator. When the
  deliverable IS a test or verification gate — a smoke, integration/regression/
  property test, or a live end-to-end gate that must actually run green rather
  than merely be reviewed — use `testing-with-rb-lite` instead (it authors the
  test with rb-lite and then independently RUNS it, since the panel only reads
  the test's source). Do NOT use for cross-project orchestration, open-ended
  planning, or tiny one-shot edits.
compatibility: Requires `rb-lite` on `PATH` or `nix run --refresh github:douglaz/rb-lite -- ...` (use `--refresh` at least once per session so Nix does not reuse an hour-stale cached revision). rb-lite itself has no default implementer, so pass `--implementer` with one preset or a comma-separated cycle, or use `--implement-cmd`; this skill defaults to `--implementer claude,codex` unless the user pins another choice. `codex` and `claude` must be installed and authenticated; the default Claude reviewer needs `jq`, and normal timeout-enabled runs need a compatible `timeout`, either from the host shell for source installs or from the Nix wrapper for Nix installs. This skill's reviewer panel is codex + claude only, set by writing `.rb-lite-reviewers` before the run; rb-lite's built-in default additionally runs Gemini through `npx`, which this skill does not use. Backlog-drain mode also requires `br` (>= 0.1.45), `gh`, and the repo's normal local verification tools; harden-until-clean mode additionally needs `codex` and `claude` for the outer review panel.
---

Use `rb-lite` as the default lightweight implement → review loop for
single-branch, single-task work in the current repo. Also use it as the
execution engine for draining an existing `br` backlog: `br ready` supplies
the work list, and each bead gets one focused rb-lite run. When the work list
does not exist yet and the goal is a clean branch, the harden-until-clean drive
generates it from a review panel and feeds the same drain.

## What rb-lite is, in one paragraph

`rb-lite` is a Bash CLI that loops a chosen implementer preset
(`--implementer claude,codex`, a comma-separated cycle, or a single
`codex`/`claude`; there is no default) until the git diff stabilizes, then
runs the reviewer panel in parallel (codex and claude+`jq`, set via
`.rb-lite-reviewers`), feeds P0/P1/P2 findings back to the implementer for
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

**This skill's panel is two reviewers: `codex` and `claude`.** rb-lite's own built-in
default is three — it adds a Gemini reviewer invoked through `npx -y @google/gemini-cli`
— and that command lives inside the rb-lite binary, so the only way to change it is to
point rb-lite at a two-reviewer file. Write it to a TEMP path and pass
`--reviewers-file`, rather than `cat >.rb-lite-reviewers` in the repo root: that
redirection destroys an existing custom panel if the repo has one, and creates an
untracked file if it does not — which then trips the clean-tree gate LAND derives from, or
gets committed outside the task's scope.

```bash
RB_REVIEWERS=$(mktemp)
cat >"$RB_REVIEWERS" <<'RBEOF'
codex review --base "$BASE" -c 'model="gpt-5.6-sol"'
set -o pipefail; claude -p "Read AGENTS.md if present, then review the diff vs $BASE. Before asserting the diff violates or overstates an invariant, or any claim about behavior in code the diff does not show, verify it by reading that code and cite file:line, else mark it a QUESTION not a finding. Tag findings P0/P1/P2/P3. Output 'No findings.' if clean. Do not modify, create, or delete any file." --model claude-opus-5 --permission-mode plan --output-format json --allowedTools "Bash,Read,Glob,Grep" --disallowedTools "Edit,Write,NotebookEdit" | jq -er 'if .is_error then error(.result // "claude reviewer returned is_error") else (.result // empty) end'
RBEOF
# ...then add --reviewers-file "$RB_REVIEWERS" to the rb-lite run, and rm it afterwards.
```

The Claude reviewer is READ-ONLY on purpose: `Edit`/`Write` plus `acceptEdits` would let it
mutate the worktree while the codex reviewer is reading it, so the two would review
different trees — and any edit it made would bypass the implementer loop entirely. It is
also told to read `AGENTS.md`, which is how a repo's own invariants reach the panel when
this runs under `drive`; without it half the panel reviews without them.

"Customizing the panel" below shows the same two commands alongside OPTIONAL extras — a
skeptical third reviewer and a `my-linter --json | wrap-as-p-tags` placeholder — which are
illustrative, not prerequisites. Pasting that block wholesale puts a command-not-found
reviewer in the panel and every round carries its failure.

Dropping Gemini is the point, not a side effect. `npx -y` installs and executes whatever
the registry serves at that moment, in a checkout with credentials present and (in
rb-lite's default line) `--approval-mode yolo`. Pinning a version narrows that door;
removing the reviewer closes it, and removes the `npx` dependency altogether. Two
reviewers with different failure modes is also what the outer `multi-reviewer-loop` runs,
and the reason is the same — a third opportunistic voice that fails open when credentials
are missing was never carrying much of the panel's weight.

`codex` and `claude` must be on PATH and authenticated. The Claude reviewer needs `jq`,
and normal rb-lite runs need a `timeout` binary supporting `--kill-after` because both
implementer and reviewer timeouts are enabled by default. If rb-lite is resolved through
`nix run --refresh github:douglaz/rb-lite --` or a Nix-profile wrapper, do not reject the
setup just because the host shell cannot find `jq` or GNU `timeout`; the upstream wrapper
supplies those to the rb-lite process. For source/path installs, check the host shell.

If you skip the file, you get rb-lite's built-in three-reviewer default, unpinned Gemini
included. That is a choice, not a default this skill endorses — make it deliberately.

Backlog-drain mode additionally needs `br` for bead selection/state and `gh`
for PR creation/checks/merge. Require **`br` ≥ 0.1.45**: older builds corrupt
their DB after branch resets, so `br update`/`br close` start returning
`ISSUE_NOT_FOUND` while `br show`/`br list` keep working — which hides the
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
  fmt/clippy) on the landed diff; for high-stakes work add a **separate
  adversarial result-review** (e.g. `codex exec` over the committed diff) — the
  panel's `clean` is one input, not the gate. See "Verify the landed diff."
- In backlog-drain mode, one bead equals one branch and one **work** PR. Do not batch
  unrelated beads into one rb-lite run. The final closure/metadata PR (step 11) is not a
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
   `jq` if available; otherwise grep the line. The schema is in the
   "Exit codes and JSON schema" section below.

10. **Diagnose by exit code.** Don't pattern-match on the human-readable
    line; match on the JSON `status` and `exit_code`. The mapping is
    fixed (see the table below).

10.5 **Verify the landed diff yourself (do not skip).** rb-lite's `clean` is
    the reviewer panel's verdict, not ground truth — and the panel is often
    degraded in practice. Before trusting a run: (a) `git status` / `git diff`
    — the accepted diff sits **uncommitted in the working tree**, so confirm
    what actually changed and that no throwaway/debug files snuck in, then
    commit it yourself; (b) check `log.txt` for `K of M reviewers succeeded` —
    a `clean` resting on 1-of-3 (e.g. a dead/unauthenticated reviewer) is one
    opinion, not a panel consensus; (c) re-run the repo's own gates on the
    landed diff (tests, goldens/digests, fmt/clippy); (d) invert one
    load-bearing behavior the diff introduces and confirm a gate can actually go
    red, since re-running an already-green suite cannot tell you whether the
    behavior is pinned at all; (e) for high-stakes work, add a separate
    adversarial result-review (e.g. `codex exec` over the committed diff). See
    "Verify the landed diff" below.

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

The single most important habit when driving rb-lite for real work: **`clean`
means "no surviving reviewer raised a P0/P1/P2," not "correct."** Five things
dogfooding made concrete:

- **The diff is uncommitted.** rb-lite leaves the final accepted changes in the
  working tree (it does not commit on your behalf). Always inspect with `git
  status` / `git diff` and commit the intentional changes yourself — and watch
  for stray scratch files (e.g. a `tmp_*` debug test the implementer created and
  forgot to remove).
- **The panel degrades silently.** The panel succeeds with as few as one exit-0
  reviewer (a missing CLI, an expired/free-tier auth, or an 1800s reviewer
  timeout drops the others). So a `clean` run can rest on a single reviewer's
  read. Confirm the real panel strength in `log.txt` (`round N review panel
  proceeded with partial failures: K of M reviewers succeeded`) and the
  `review-round-*.md` status headers. The thinner the panel, the more the next
  two steps matter.
- **Independent verification is the gate, not the panel.** Re-run the project's
  own contract (its test suites, byte-identical golden/digest checks,
  `fmt`/`clippy`) on the landed diff yourself. For high-stakes or finding-shaped
  work, also run a **separate adversarial result-review** with a second model
  over the committed diff — phrased to attack: *is the result genuine, was
  anything tuned to pass the panel, is the claim honestly scoped?* Treat the
  panel's `clean` as one input into your own PASS decision.
- **Verify the comments, not just the code.** Agent loops can *corrupt a correct
  comment* to placate a reviewer: read every load-bearing correctness/safety/
  invariant comment in the landed diff and confirm each is TRUE per the code —
  following the invariant across files when its guarantee lives outside the diff.
  Then reconcile the **commit message's claims against the shipped comments** (a
  commit that says "conservative lower bound" over a comment that says the opposite
  is a tell). Observed: a reviewer asserted a false out-of-diff fee premise, the
  implementer rewrote a correct invariant docstring to agree, and two more
  reviewers then echoed the corrupted comment — a self-reinforcing loop that only
  broke on reading the unchanged cap code. Tests passing does not catch this;
  reading the claims against the code does.
- **A green suite does not prove the diff is covered.** Re-running gates that
  already passed cannot tell you whether the loop shipped a behavior no test
  pins. For each load-bearing behavior the diff *introduces* — a new invariant,
  an ordering, a clock or lock choice — **invert it in the working tree, confirm
  a test FAILS, then revert.** If nothing fails, the loop wrote code the panel
  described and the suite ignores. Observed: a nine-round run ended `clean` with
  every gate green — `fmt`, `clippy -D warnings`, 685 workspace tests, three
  demos, a 16/16 adversarial suite, and CI on a dedicated runner — and swapping a
  single argument at one call site (the mapping anchoring a security deadline)
  still left all 498 lib tests passing. Nine rounds of reading missed it; one
  mutation found it. Keep it scoped to the handful of behaviors the diff
  introduces — each check is one edit, one targeted test, one revert — and treat
  it as the cheapest thing that separates "tests pass" from "tests would notice."

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
   `nix run --refresh github:douglaz/rb-lite --`.

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

9. **CI.** Capture the head *before* waiting, then wait for green:

    ```bash
    # Persisted to a file, not just a shell variable. Steps 9 and 10 usually run as
    # separate tool calls, so a variable set here is gone by the merge — and the guard
    # there would then abort a correct drain with "local HEAD moved". Under the git dir,
    # so it is per-checkout and never committed (ADR 0001).
    # Probe both repositories: a fork can host its own PR, and a colliding number in the
    # parent can otherwise make the drain watch checks for somebody else's tree.
    # Guarded: a failed parent lookup is not "not a fork" — it silently drops the one
    # candidate whose same-number PR the ambiguity refusal below exists to catch.
    SELF=$(gh repo view --json nameWithOwner -q .nameWithOwner) \
      || { echo "cannot resolve this repository"; exit 1; }
    PARENT=$(gh repo view --json parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else "" end') \
      || { echo "cannot resolve the parent repository — a PR there would be invisible"; exit 1; }
    LOCAL_HEAD=$(git rev-parse HEAD)
    # Both repos matching is ambiguous, not a tiebreak: the same branch can be opened as a
    # PR against the parent AND the fork, and picking the parent silently can watch and
    # merge a PR the drain never gated. Refuse; pin the intended repo in every -R instead.
    # And a FAILED query is not a miss: "no such PR" is read out of gh's own error text,
    # because a transient failure treated as absence erases one candidate — and with it
    # the refusal — leaving the drain watching whichever PR the outage left visible.
    # PullRequest-level not-found only: both candidates are repos the API just named, so
    # a Repository-level "could not resolve" or an HTTP 404 is lost access, not absence.
    _GH_ERR=$(mktemp); trap 'rm -f "$_GH_ERR"' EXIT   # both scripts do this; the snippets leaked it || { echo "mktemp failed"; exit 1; }
    R=""; _M=0
    for _r in ${PARENT:+"$PARENT"} "$SELF"; do
      if ! _h=$(gh pr view <pr> -R "$_r" --json headRefOid -q .headRefOid 2>"$_GH_ERR"); then
        grep -qiE 'could not resolve to a pullrequest|no pull requests found' "$_GH_ERR" \
          || { echo "cannot query PR <pr> in $_r — absence not established"; exit 1; }
        _h=""
      fi
      if [ "$_h" = "$LOCAL_HEAD" ]; then _M=$((_M+1)); [ -n "$R" ] || R="$_r"; fi
    done
    [ "$_M" -le 1 ] || { echo "PR <pr> matches this head in BOTH $PARENT and $SELF — ambiguous"; exit 1; }
    [ -n "$R" ] || { echo "cannot find PR <pr> for local HEAD"; exit 1; }
    MERGING_SHA=$(gh pr view <pr> -R "$R" --json headRefOid -q .headRefOid)
    [ -n "$MERGING_SHA" ] || { echo "cannot resolve the PR head"; exit 1; }
    printf '%s\n' "$MERGING_SHA" > "$(git rev-parse --git-path rb-lite-merging-sha)"
    # Bind it to the commit that was actually reviewed. The remote head is only the right
    # thing to merge if it IS your local HEAD — the tree rb-lite ran on and step 7's gates
    # passed on. If the branch moved since step 8, green CI would otherwise merge code no
    # panel and no gate ever saw.
    [ "$MERGING_SHA" = "$(git rev-parse HEAD)" ] \
      || { echo "PR head $MERGING_SHA is not the reviewed local HEAD — re-run the panel"; exit 1; }
    gh pr checks <pr> -R "$R" --watch
    ```

   Capture first, because the SHA is what makes the pin mean anything. Reading it
   *after* the checks pass adopts whatever is there then — so a force-push landing
   between green CI and the merge gets pinned to itself and sails through the very
   guard meant to catch it. Pinning the pre-CI SHA makes GitHub reject the merge
   instead; rerun the checks against the new head and try again.

   On known-flaky CI, rerun failed jobs via `gh run rerun <id> --failed`; do not
   keep changing product code just to dodge a flake.

10. **Merge and reset.** Squash-merge the PR, delete the branch, then reset local state
    to *where the merge landed* — not to `origin`, which on a fork is your own copy — and rerun the
    authoritative build gate before taking the next bead:

    ```bash
    # Read the step-9 pin before resolving the host. Matching the PR against that SHA keeps
    # a same-number PR in the parent from winning when the real PR is owned by the fork.
    MERGING_SHA=$(cat "$(git rev-parse --git-path rb-lite-merging-sha)" 2>/dev/null || echo "")
    [ -n "$MERGING_SHA" ] || { echo "no pinned SHA — re-run step 9"; exit 1; }
    SELF=$(gh repo view --json nameWithOwner -q .nameWithOwner) \
      || { echo "cannot resolve this repository"; exit 1; }
    PARENT=$(gh repo view --json parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else "" end') \
      || { echo "cannot resolve the parent repository — a PR there would be invisible"; exit 1; }
    # Same ambiguity rule as step 9: both repos carrying PR <pr> at the pinned SHA means
    # two distinct PRs, and merging the parent's silently can land the one nobody gated.
    # Same absence rule too: only gh's own "no such PR" counts as a miss — a transient
    # failure treated as one hides the second match and merges the survivor. And only the
    # PullRequest-level text: a Repository-level "could not resolve" or an HTTP 404 on a
    # repo the API just named is lost access, not absence.
    _GH_ERR=$(mktemp); trap 'rm -f "$_GH_ERR"' EXIT   # both scripts do this; the snippets leaked it || { echo "mktemp failed"; exit 1; }
    R=""; _M=0
    for _r in ${PARENT:+"$PARENT"} "$SELF"; do
      if ! _h=$(gh pr view <pr> -R "$_r" --json headRefOid -q .headRefOid 2>"$_GH_ERR"); then
        grep -qiE 'could not resolve to a pullrequest|no pull requests found' "$_GH_ERR" \
          || { echo "cannot query PR <pr> in $_r — absence not established; do NOT merge"; exit 1; }
        _h=""
      fi
      if [ "$_h" = "$MERGING_SHA" ]; then _M=$((_M+1)); [ -n "$R" ] || R="$_r"; fi
    done
    [ "$_M" -le 1 ] || { echo "PR <pr> matches the pinned SHA in BOTH $PARENT and $SELF — ambiguous"; exit 1; }
    [ -n "$R" ] || { echo "cannot find PR <pr> for the pinned SHA"; exit 1; }
    PR_REFS=$(gh pr view <pr> -R "$R" --json baseRefName,headRefName) \
      || { echo "cannot resolve the PR branches"; exit 1; }
    BASE=$(printf %s "$PR_REFS" | jq -r '.baseRefName // ""')
    HEAD_BRANCH=$(printf %s "$PR_REFS" | jq -r '.headRefName // ""')
    [ -n "$BASE" ] && [ -n "$HEAD_BRANCH" ] \
      || { echo "cannot resolve the PR branches"; exit 1; }
    # Check the merge's exit status. `--delete-branch` makes gh switch branches as a side
    # effect, so a FAILED merge still leaves you somewhere plausible-looking — and step 11
    # then closes the bead for a merge that never happened, which is the exact state this
    # skill's reviewed-closure path exists to prevent.
    # The base moves while a bead is built and reviewed, and --match-head-commit pins only
    # the HEAD — a squash replays onto the CURRENT base, so a behind branch lands a
    # composition nobody reviewed while every SHA still matches. Fetch the live base and
    # test ancestry before merging, the same way pr-with-codex-bot-review § 8 does.
    # gh's own clone URL: `owner/repo` alone points at public github.com, which on GitHub
    # Enterprise either fails or resolves an unrelated public repo of the same name.
    R_URL=$(gh repo view "$R" --json url -q .url 2>/dev/null) \
  || { echo "cannot resolve the clone URL for $R — do NOT merge"; exit 1; }
    git fetch "$R_URL.git" "+refs/heads/$BASE:refs/remotes/upstream/$BASE" \
      || { echo "cannot fetch the merge target — base unknown, do NOT merge"; echo "  (on a private repo cloned over SSH this is usually missing git credentials for https, not a missing base)"; exit 1; }
    # Against $MERGING_SHA, not HEAD: that is the commit --match-head-commit pins and the
    # one GitHub will squash. A local rebase during CI that was never pushed would make
    # HEAD pass this test while the pinned remote SHA is still behind the base.
    [ "$MERGING_SHA" = "$(git rev-parse HEAD)" ] \
      || { echo "local HEAD moved since step 9 — re-run the panel and the checks"; exit 1; }
    git merge-base --is-ancestor "refs/remotes/upstream/$BASE" "$MERGING_SHA" \
      || { echo "REBASE FIRST — $BASE advanced since the review"; exit 1; }
    # LAST, immediately before the merge, for the reason pr-with-codex-bot-review § 8 gives
    # at the same spot: ancestry answers "did $BASE advance", never "is $BASE still the
    # target". A retarget points the PR at a different branch, leaving every check above
    # validating the old one while gh squashes onto the new one — and the head never moves,
    # so --match-head-commit stays satisfied. Read here, not earlier: each check between
    # this read and the merge widens the window. It cannot reach zero (GitHub has no base
    # pin), but it is one API call wide.
    BASE_NOW=$(gh pr view <pr> -R "$R" --json baseRefName -q .baseRefName) \
      || { echo "cannot re-read the merge target — do NOT merge"; exit 1; }
    [ -n "$BASE_NOW" ] && [ "$BASE_NOW" = "$BASE" ] \
      || { echo "the PR was retargeted ($BASE -> ${BASE_NOW:-unknown}) — the panel reviewed against $BASE; re-run the panel"; exit 1; }
    gh pr merge <pr> -R "$R" --squash --delete-branch --match-head-commit "$MERGING_SHA" \
      || { echo "merge did not land — do NOT close the bead"; exit 1; }

    # `gh pr merge` returning 0 means the PR was accepted for merging — which, in a repo with a
    # required merge queue, means ENQUEUED, not landed. Fetching now would read the still-old
    # base and any caller that closes a tracker item here would close it for a merge that has
    # not happened. Wait for the state to actually reach MERGED.
    _n=0
    while [ "$_n" -lt 60 ]; do
      _n=$((_n+1))
      _ST=$(gh pr view <pr> -R "$R" --json state -q .state 2>/dev/null || echo "")
      [ "$_ST" = "MERGED" ] && break
      [ "$_ST" = "CLOSED" ] && { echo "PR was closed without merging"; exit 1; }
      sleep 10
    done
    [ "$_ST" = "MERGED" ] || { echo "PR still not merged (state=$_ST) — do NOT proceed"; exit 1; }

    # Reset from where the merge LANDED. On a fork clone `origin` is your fork and does
    # not contain the upstream squash commit, so resetting to origin/$BASE silently starts
    # the next bead from a tree missing the one just merged — its PR then replays or
    # conflicts with it.
    # gh's own clone URL: `owner/repo` alone points at public github.com, which on GitHub
    # Enterprise either fails or resolves an unrelated public repo of the same name.
    R_URL=$(gh repo view "$R" --json url -q .url 2>/dev/null) \
  || { echo "cannot resolve the clone URL for $R — do NOT merge"; exit 1; }
    git fetch "$R_URL.git" "+refs/heads/$BASE:refs/remotes/upstream/$BASE" \
      || { echo "cannot fetch the merge target"; echo "  (on a private repo cloned over SSH this is usually missing git credentials for https, not a missing base)"; exit 1; }
    # `checkout -B` moves the branch ref unconditionally, and a clean worktree does not
    # protect committed work: any local commit on $BASE that upstream lacks becomes
    # unreachable. A same-name fork PR is different: local $BASE is the feature head, and
    # the squash commit cannot contain it. Allow only the verified, pinned PR head itself;
    # a later local commit still refuses the reset.
    if git show-ref --verify --quiet "refs/heads/$BASE" \
       && ! git merge-base --is-ancestor "$BASE" "refs/remotes/upstream/$BASE"; then
      if [ "$HEAD_BRANCH" != "$BASE" ] \
         || [ "$(git rev-parse "refs/heads/$BASE")" != "$MERGING_SHA" ]; then
        echo "local $BASE has commits upstream does not — refusing to reset; rebase or push them first"
        exit 1
      fi
    fi
    # Refuse a dirty worktree HERE, immediately before the reset: the merge-queue wait
    # above can run ten minutes, and `checkout -B` silently CARRIES any nonconflicting
    # tracked modification onto the fresh base — the build below then passes and the next
    # bead inherits work that was never on this branch. FULL status, untracked included:
    # checkout does not move an untracked file, but it does not remove it either, so a
    # file created during the wait sits in the "fresh" base worktree where the build and
    # the next bead's branch inherit it — unreviewed, and invisible to `-uno`.
    _WT=$(git status --porcelain) || { echo "cannot read the worktree — not resetting"; exit 1; }
    [ -z "$_WT" ] || { echo "worktree changed while waiting for the merge — resolve that before resetting to $BASE"; exit 1; }
    git checkout -B "$BASE" "refs/remotes/upstream/$BASE" \
      || { echo "cannot reset to the merge target"; exit 1; }
    nix build
    ```

    Substitute `master` only when the repo actually uses `master`.

11. **Close the bead, through a reviewed path.** Run `br update <bead-id> -s closed`
    after the merged code is present on the base branch. That write lands in the
    tracked `.beads/*.jsonl`, so do **not** commit it straight to the default branch —
    it would reach the branch unreviewed. Carry the closure commit into the next bead's
    branch, where it rides that PR; when the queue is empty and there is no next branch,
    open one small metadata PR for it **and land it** — carry it through review and merge
    like any other. Opening it is not enough: until it merges, the closure never reaches
    the default branch and a fresh clone still shows the bead open, which is the failure
    this reviewed path exists to prevent. The drain is not done until that PR is merged. Do not leave it uncommitted either, or the next
    run starts from a dirty base and silently carries the previous closure into its diff.

    **Give the PR body a machine-readable marker line, one per bead it closes:**

    ```text
    bead-closure: <bead-id>
    ```

    Step 8 puts the bead id in every ordinary work PR body too, so the id alone cannot
    distinguish "the work merged" from "the closure merged" — and step 12's resume
    discovery depends on telling them apart. The marker is what it filters on.

    Verify it landed with a checked *explicit* sync: it propagates a real exit code, which
    the automatic flush after `br update` does not — that one swallows its error. The
    mutation is already in the shared DB, so the sync either writes it out or fails loudly,
    and nothing needs to inspect the file:

    ```bash
    br update <bead-id> -s closed || { echo "br update failed"; exit 1; }
    br sync --flush-only || { echo "not persisted"; exit 1; }
    ```

    Closing on the feature branch before the merge is **not** a safe shortcut, however
    transactional it looks — the beads DB is shared across branches with no git
    awareness, and import is last-write-wins, so the closure leaks. See
    `docs/adr/0003-bead-closure-stays-post-merge.md` for the code evidence.

12. **Loop.** Return to `br ready --limit 10` — but **on a resumed drain, look for an
    in-flight closure PR before selecting work.** A closure lives on its metadata branch
    until it merges, so a fresh clone of the default branch sees the old JSONL with the
    bead still open and will happily rebuild and re-merge work that is already done. The
    queue cannot tell you this; only the forge can:

    ```bash
    SELF=$(gh repo view --json nameWithOwner -q .nameWithOwner) \
      || { echo "cannot resolve this repository — closure-PR discovery is incomplete"; exit 1; }
    PARENT=$(gh repo view --json parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else "" end') \
      || { echo "cannot resolve the parent repository — closure-PR discovery is incomplete"; exit 1; }
    CLOSURE_PRS=()
    for UP in ${PARENT:+"$PARENT"} "$SELF"; do
      # `url` is not decoration: this loop MERGES parent and fork results, and a bare
      # `number` is ambiguous across them — #42 exists in both. Acting on a parent hit with
      # the fork's `-R` opens an unrelated same-numbered PR. The url carries the repository.
      _PRS=$(gh pr list -R "$UP" --state all --limit 1000 --json number,state,headRefName,title,body,url) \
        || { echo "cannot query closure PRs in $UP — do not resume work from partial results"; exit 1; }
      CLOSURE_PRS+=("$_PRS")
      # 1000 is a CAP, not "all of them". With more newer PRs than that, the older closure
      # or work PR this recovery exists to find falls outside the snapshot, both filters
      # come back empty, and the drain rebuilds work that already merged. A saturated page
      # is the only case where anything can hide, so pay for the search only then.
      if [ "$(printf '%s' "$_PRS" | jq 'length')" -ge 1000 ]; then
        _MORE=$(gh pr list -R "$UP" --state all --limit 1000 --search "$BEAD_ID in:body" \
                  --json number,state,headRefName,title,body,url) \
          || { echo "closure search in $UP failed — do not resume from partial results"; exit 1; }
        CLOSURE_PRS+=("$_MORE")
      fi
    done
    printf '%s\n' "${CLOSURE_PRS[@]}" \
      | jq -s --arg id "$BEAD_ID" 'add | unique_by(.url) | .[] | select($id != "" and ((.body // "") | ascii_downcase
        | test("(^|\\r|\\n)[[:space:]]*bead-closure:[[:space:]]*" + ($id|ascii_downcase|gsub("\\.";"\\.")) + "[[:space:]]*(\\r|\\n|$)")))'
    # SAME shell, same snapshot: the bead's work PRs, MERGED **or still OPEN**. Consulted
    # whenever the marker query above is empty — see below. MERGED-only hid the third
    # resume state: a work PR opened but not yet landed carries the bead id and no
    # `bead-closure:` marker, so neither query saw it and the drain re-entered step 6 to
    # rebuild work that was already open for review. Run separately this would re-fetch,
    # and a fetch that failed here while the marker query succeeded would silently read as
    # "nothing merged", the exact collapse this query exists to close.
    printf '%s\n' "${CLOSURE_PRS[@]}" \
      | jq -s --arg id "$BEAD_ID" 'add | unique_by(.url) | .[] | select(.state=="MERGED" or .state=="OPEN")
          | select($id != "" and ((.body // "") | ascii_downcase
            | test("(^|[^a-z0-9._-])" + ($id|ascii_downcase|gsub("\\.";"\\.")) + "([^a-z0-9._-]|$)")))'
    ```

    `BEAD_ID` is the bead you are about to take — loop this query over each open bead from
    `br ready`/`br list` rather than assuming a variable survived the clone. Empty, the
    filter rejects everything and the closure PR this exists to find is missed.

    Keyed on the **`bead-closure:` marker plus the bead id**, not on the id alone: step 8
    puts the id in every ordinary work PR body, so an id-only filter returns the merged
    work PR for any bead whose work landed — which on a fresh clone looks exactly like
    closure history when no closure was ever opened, and defeats the guard. Not a
    branch-naming convention either — nothing mandates one. The raised `--limit` matters
    because `gh pr list` returns 30 by default — an older closure PR hides behind newer
    work PRs, which is the resume case this exists for.

    **An empty result from the marker query answers only "no closure PR was opened" — it
    is NOT evidence that nothing merged.** A drain that stops between step 10's merge and
    step 11's closure PR leaves exactly that state: the work merged, the bead still open
    in the JSONL, and no marker anywhere for the first query to find. Reading empty as
    "unfinished" there rebuilds and re-merges code already on the base. The second query
    in the block is what tells those apart: it asks the same snapshot whether the bead's
    WORK already merged.

    Read any hit before acting on it. **Take the repository from the hit's `url`, never
    from the number alone** — these results merge the parent's PRs with the fork's, and
    #42 exists in both; a parent hit acted on with the fork's `-R` lands you on an
    unrelated PR. Then **read its `state` — it names where to resume**. `MERGED`: a merged PR carrying the id is almost certainly the work PR, and
    the bead open in the default branch's JSONL beside it is precisely the interrupted
    state; do **not** rebuild the bead, its code is on the base — resume at step 11, close
    the bead and land the closure PR. `OPEN`: the work PR is up and has not landed, so
    resume *that* PR's review-and-merge flow at step 9 rather than rebuilding — a rebuild
    here races an open review and lands the bead twice.

    Only when *both* queries are empty does "not started" stand, which is a narrower claim
    than the "not started *or* not merged" this once read as — that phrasing quietly
    folded the OPEN work PR into the same answer. On a drain older than these markers and
    id-carrying bodies, even that needs the hits read by hand, because neither convention
    was in force when its PRs were written.

    An OPEN one: land it before taking another bead. A CLOSED-but-unmerged one is worse — the
    work PR already merged, the closure never did, and `--state open` cannot see it: reopen
    or replace it rather than rebuilding the bead. `drive`'s resume checklist does
    the same discovery for the same reason (`skills/drive/references/phases.md` § LAND).

    Stop when the queue is empty **and** any
    final metadata PR from step 11 has merged — an open closure PR means the drain is
    still in flight, however empty the queue looks. Also stop when
    the user says stop, a bead needs human product/security judgment, or a
    P0/P1 dogfood bead interrupts the queue.

## Harden-until-clean drive

Use this mode when the user wants a **branch hardened until review is clean**
and there is no backlog yet. It is the backlog drain with an outer loop bolted
on: a review panel generates the work list, the drain executes it, then the
panel runs again over everything that merged.

```
loop:
  findings = review_panel(work_branch, base=review_base)   # codex + claude fable, parallel
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
- **One defect, one bead.** Dedupe across reviewers before `br create`, or you
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
- Test through the REAL code path. A test that exercises a test-only shortcut
  (env-gated early return, fake injected above the seam being fixed) stays green
  whether or not the fix works. Inject fakes *below* the seam you care about.
- The new test must actually RUN under the repo's default test command. Verify
  by running it and grepping the output for the new test name — a test file
  outside the runner's glob is dead coverage that reads as a gate.

## Scope guard
- Do not refactor unrelated code.
- Do not broaden this bead into adjacent backlog items.
- Build the SIMPLEST correct thing for this bead. Do NOT build: <non-goals —
  defensive edge cases beyond the threat model, config knobs, new abstractions,
  retry/scheduling machinery>. Target ~N lines / one focused module; if you are
  writing materially more, stop and simplify.
- Do not run `rb-lite` itself, send signals to your own process tree, or
  otherwise interfere with the surrounding orchestration.
- Treat `.rb-lite/`, `.ralph-burning/`, `.git/ralph-burning-live/`, and
  `.beads/` as orchestration/state directories, not product code to review.
  This does NOT forbid ordinary git usage: **`git add` any new SOURCE file you
  create** so it appears in the reviewed diff (`git diff <base>` omits untracked
  files — an unstaged new module reads to reviewers as "missing, won't compile").
  Staging a source file is not the prohibited editing of `.git/` internals.
- **Never weaken, invert, or delete a correctness/safety/invariant comment or
  assertion to satisfy a review finding without first verifying it against the
  actual code and citing `file:line`.** A correctness-comment edit is NOT a cheap
  doc fix — it carries the same evidence burden as a behavior change. If a reviewer
  says an invariant claim is wrong, either prove it (fix code + comment together)
  or refute the finding with code evidence and keep the comment. Be especially wary
  of findings about invariants whose guarantee lives in a file the diff does not
  show.

## Acceptance criteria
- <Acceptance criteria copied from `br show <id>`.>
- <What must KEEP working — name the legitimate cases the change must preserve.
  Criteria that only describe what to block get signed off, and the breakage
  they cause comes back as its own bead later.>
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
  forbid all others — see "Bounding a high-blast-radius bead."

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
  one. (Raising `--min-findings-severity P1` makes the loop itself ignore P2 nits —
  reach for it once the P2 stream has gone gold-plating, not from the start.)
- **Detecting it takes sharp eyes — proxies flag, analysis confirms.** Two cheap
  proxies raise the alarm: a high **review-round count** (the loop keeps finding
  ever-deeper edges) and a large **line count** versus comparable beads (a "simple"
  module returning at thousands of lines). But proxies only flag, and can mislead —
  a genuinely hard bead earns its rounds; a necessarily-verbose module earns its
  lines. The only way to be SURE is to **read the prompt's GOAL, then compare it to
  the COMPLEXITY of what was actually built**: do the modules, abstractions,
  edge-case handling, and config surface match what the goal truly requires, or has
  the implementation grown past it? When they diverge, cut back to the goal — and
  treat the proxies as the cue to run that comparison, not as the verdict itself.

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
- **Add a skeptical reviewer for counter-pressure.** Every default reviewer hunts
  *what's wrong*, which is to say *what to add*. None hunt *what's over-built*. For
  anything past a small bead, add a third reviewer to `.rb-lite-reviewers` that
  runs the inverted lens, so the panel pushes back against scope creep instead of
  only feeding it (see "Customizing the panel").
- **Periodic skeptical audit.** When the fractal tail shows up, or before merging
  a large run, stop relaying and run one inverted audit yourself: walk what the run
  added and label each mechanism *required-for-correctness* versus
  *defense-in-depth / operational*. Cut, simplify, or mark-optional the latter.
  Reconcile its output through your own judgment (accepting every cut is the same
  credulity in reverse), then re-verify the core is intact with no dangling
  references to anything you removed.

## Bounding a high-blast-radius bead

Some beads invite sprawl: the core is genuinely hard, or it sits next to several
modules the implementer could "helpfully" rewrite. Left unbounded, the loop treats
every adjacent file as fair game. One real run ballooned to 25 rounds and a
3600-line module that also rewrote four already-merged files — it had to be
discarded wholesale. Bound these from the **first** run, not after they blow up:

- **Lock the files.** Put a hard file constraint at the TOP of the task: "Create
  EXACTLY these file(s): `<paths>`. Do NOT modify any other file. If you believe you
  need to touch another file, the design is wrong — STOP and restructure to use the
  existing public seams as they are." This is the single most effective brake on
  cross-bead contamination — much stronger than the scope guard's generic "don't
  refactor unrelated code," because it names the boundary.
- **Keep the bead self-contained.** If the work needs a small piece of an adjacent
  module's behavior, have the task do that small piece inline against the existing
  public API — do NOT let it reach in and "factor out" a shared helper. Reaching
  across the seam is exactly how one bead's run ends up rewriting three other beads.
- **Watch the run; don't fire-and-forget.** Active supervision is the real control —
  the caps below are backstops, not the method. Tail each round's diff and review
  output as it lands (`git diff` on the branch, the latest `review-round-*.md`), and
  intervene the moment the code starts degrading: edits creeping outside the locked
  files, speculative abstractions, a "simple" module ballooning. Catching a bad round
  as it happens is far cheaper than discarding 25 of them.
- **Treat `--max-rounds` as a checkpoint, not a finish.** A low cap (e.g. `6`) forces
  a pause to assess rather than ending the work. At the checkpoint, read what actually
  changed: if the findings were legitimate and the code is sound and still converging,
  relaunch for another batch (6 or more) to finish; if it's sprawling or gold-plating,
  stop and re-scope instead. The cap buys you a decision point, not a verdict.
- **Don't pre-cap finding severity.** Leave the default (`P2`) so genuine P2 polish
  lands — those are often real improvements worth keeping. P3-only findings are not
  relayed by default; inspect them manually, or lower the floor to P3 only when the
  user explicitly wants to chase nits. Raise `--min-findings-severity P1` only
  *later*, once you've judged that the remaining P2 stream has crossed from useful
  polish into harmful gold-plating (hardening the code past the goal). Cutting it
  off from round 1 throws away good work.
- **Re-scope before re-running.** If a bead is too big to bound, it's too big — split
  the secondary concern into its own bead and run only the core. (One reconcile bead
  shed its "downtime credit" half into a separate bead; the core then fit a single
  ~800-line module that bounded cleanly.)

**The recovery playbook when one blows up anyway:** do NOT just relaunch the same
run unchanged — it will blow up the same way. (1) Discard the wreckage back to the
saved pre-run state (`git reset`/`checkout`/`clean`, or apply your pre-run snapshot).
(2) Re-scope: split off the secondary concern as its own bead. (3) Re-run with the
file-lock and a low `--max-rounds` checkpoint, watching each round — keep the default
severity so real P2 polish still lands, raising the floor only if remaining P2s turn
into gold-plating. (4) At each checkpoint, decide: if the remaining findings are legitimate
and the code is sound, relaunch for more rounds to finish; if only a P1 or two are
left and another full pass isn't worth it, apply those fixes yourself, re-run the
repo's gates, and commit. A bounded run not closing every finding in one go is
expected — finishing the last mile by hand or with one more batch is normal, not a
failure.

## Customizing the panel

rb-lite's built-in panel is `codex review` + `claude -p ... | jq ...` + Gemini via `npx`.
This skill runs **two** reviewers instead. The canonical file is the two-line one in
§ Tool dependencies; the block below shows those same two lines plus OPTIONAL extras, so
read it as a menu rather than a file to paste — the last two entries are a third reviewer
and a placeholder that does not exist on any PATH:

```bash
# .rb-lite-reviewers
codex review --base "$BASE" -c 'model="gpt-5.6-sol"'
set -o pipefail; claude -p "Review the diff vs $BASE. Before asserting the diff violates or overstates an invariant, or any claim about behavior in code the diff does not show, verify it by reading that code and cite file:line, else mark it a QUESTION not a finding. Tag findings P0/P1/P2/P3. Output 'No findings.' if clean." --model opus --permission-mode acceptEdits --output-format json --allowedTools "Bash,Edit,Write,Read,Glob,Grep,WebSearch,WebFetch,Task,TaskOutput,TaskStop,Monitor" | jq -er 'if .is_error then error(.result // "claude reviewer returned is_error") else (.result // empty) end'
# Skeptical reviewer: hunts over-specification instead of bugs, so the panel has counter-pressure against scope creep
set -o pipefail; claude -p "Review the diff vs $BASE for OVER-SPECIFICATION, not bugs. Flag any mechanism, handling, config, or abstraction that is NOT required for correctness, security, or data-safety and could be cut, simplified, or deferred. For each, give: what it is, why it isn't strictly required (what already covers the case), and a recommendation. Tag each finding 'P2: CUT', 'P2: SIMPLIFY', or 'P2: DEFER'. Do not flag missing behavior or bugs; another reviewer owns that. Output 'No findings.' if the diff is already minimal for its goal." --model opus --permission-mode acceptEdits --output-format json --allowedTools "Bash,Read,Glob,Grep" | jq -er 'if .is_error then error(.result // "skeptic reviewer returned is_error") else (.result // empty) end'
(my-linter --json || true) | wrap-as-p-tags
```

The skeptical reviewer is the practical form of "add a third reviewer for
counter-pressure" above: its `CUT` / `SIMPLIFY` / `DEFER` findings tell the
implementer to *remove* surface, balancing the two panel reviewers that only
ever push to add. Worth adding for any non-trivial bead; skip it for a tiny,
already-bounded one.

**Put the verify-before-asserting rule in every custom reviewer prompt**: *"Before
asserting the diff violates or overstates an invariant — or any claim about
behavior in code the diff does not show — verify it by reading that code and cite
`file:line`; if you cannot, mark it a QUESTION, not a finding."* Reviewers see only
the diff, so a confidently-wrong claim about an invariant guaranteed in an
unchanged file will otherwise get an implementer to corrupt a correct comment, then
echo through later rounds. The **claude** reviewer carries this
rule; **`codex review`** cannot — `codex review` rejects a custom
`[PROMPT]` together with `--base` (they are mutually exclusive), so codex stays
diff-blind to out-of-diff invariants. Lean on the implementer guard (do not weaken
invariant comments without code proof) and the landed-diff comment-truth check as
the backstop for codex's findings; or replace the default codex reviewer with a
`codex exec`-based one in `.rb-lite-reviewers` if you want the guard on it (at the
cost of `codex review`'s structured output).

Reviewer commands run **concurrently**, get `BASE`/`RUN_DIR`/`ROUND`/
`REVIEWER_INDEX` in env, and have stdin closed. The panel succeeds with
at least one exit-0 reviewer; failed reviewers are noted but don't abort
the run.

The reviewer contract is strict:
- Findings on stdout, prefixed near the start of the line with the
  severity tag (`P2:`, `[P2]`, `**P2**:`, `Issue 1 (P2):`, …).
- Successful reviewer stderr is treated as tool noise and is not fed back to
  the implementer; failed reviewer stderr gets a tail in that reviewer's
  markdown file.
- Exit 0 = real review; exit non-zero = tool failure (output may be
  partial). Findings detection ignores non-zero reviewers, and failed reviewer
  files are not included in `REVIEW_FILES` for the next implementer round. A
  linter that exits non-zero on findings must be wrapped: `mylinter || true`.

## Exit codes and JSON schema

| Code | Status | Meaning | What to do |
|---|---|---|---|
| `0` | `clean` | Reviewers had no P0/P1/P2 findings (P3-only is also clean by default) | Verify the landed diff yourself, rerun the repo's gates, then ship if they pass; check `latest reviewer message in run-dir` for any leftover P3 nits worth addressing |
| `2` | `usage_error` | Bad CLI args, incl. no implementer selected (`--implementer` and `--implement-cmd` both absent) | Fix the invocation; the JSON line is still emitted with `run_dir: null` |
| `3` | `env_error` | Not in a git repo, missing tool, unsupported `timeout`, branch creation failure, run-dir setup failure | Fix the env; rerun |
| `10` | `implementer_failed` | Implementer subprocess returned non-zero (incl. timeout 124/137) or hit max-iters before stabilizing | Look at `implementer-round-N-iter-K.stderr` for the most recent iter |
| `11` | `review_panel_failed` | Zero reviewers exited 0 | Check `reviewer-round-N-K.stderr` for all reviewers; usually missing CLI/auth or `jq` failure |
| `12` | `max_rounds_hit` | Burned all `--max-rounds` without convergence | Inspect the latest review files; either bump `--max-rounds`, raise `--min-findings-severity` to skip nits, or address the remaining findings manually |
| `13` | `consensus_failure` | Implementer kept declining to act on findings for `--max-noop-rounds` consecutive rounds | Read the latest review **and the implementer's recorded reasons** — it's signaling it disagrees. If its rejections are evidence-backed (false positives or over-specification), this is a legitimate stop, not a failure. Apply the fix manually if you side with reviewers, or accept the run if you side with the implementer |
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
    "implement_timeout_secs": "integer | null",
    "reviewer_timeout_secs": "integer | null"
  }
}
```

## When the loop misbehaves

- **Reviewers keep finding nits past round 5.** That's reviewer ratchet.
  Check the latest review file: if findings are P3-only, something is
  wrong with the severity floor (it should have stopped). Otherwise,
  consider raising `--min-findings-severity P1` to ignore P2s, or stop
  manually and apply the remaining items.
- **Implementer "stabilized at iteration 1" repeatedly.** The implementer is
  declining to act. The consensus-failure stop catches it after
  `--max-noop-rounds` (default 2) — exit 13. Before overriding, read *why* it
  declined: a stuck implementer and one legitimately rejecting findings as false
  positives or over-specification both look like a no-op round, but only the first
  is a problem. If the latest `review-round-*.md` plus the implementer's own
  output show documented, evidence-backed rejections, exit 13 is the right
  outcome, not a failure to force past. Don't lower `--max-noop-rounds` unless you
  understand the trade-off.
- **Implementer dies (exit 10) — rogue self-terminate or transient API
  failure.** Two recurring causes: the implementer signals/kills its own
  process tree (exit 143 / SIGTERM, with a self-experimentation note in
  `implementer-round-*-iter-*.stderr` — the "self-destruct" mode the task's
  scope guard is meant to prevent), or a transient provider error (429
  rate-limit / 529 overload). Both leave a partial, unreliable working tree.
  Recovery: restore only to the saved pre-run state (reset/delete the rb-lite
  impl branch if it created one; otherwise apply the pre-run commit/stash/patch
  you made before launch). Do not blindly run `git checkout -- .` or remove all
  new files on a branch that may have had user work before rb-lite started.
  Then **relaunch leading with the OTHER implementer** — swap the round-1 preset
  (`--implementer claude,codex` ↔ `codex,claude`). A per-implementer failure
  (one provider overloaded, or one CLI's self-experiment habit) usually doesn't
  recur when the other leads round 1.
- **Whole run dies mid-round with a signal and ~no output (exit 143 / 137, status
  `internal_error`).** If you have more than one rb-lite run going (across sessions
  or projects), this is almost always *another* session's broad `pkill -f rb-lite`
  collateral-killing yours — not a fault in rb-lite, the box, or the task. Just
  relaunch the same run; it'll usually complete. (Distinct from the exit-10
  implementer self-terminate above: that's the implementer's own subprocess; this is
  your entire run getting a signal from outside.) **Corollary for stopping your OWN
  run:** never `pkill -f rb-lite` (or `-f <some-runword>`) — the pattern matches your
  own shell (exit 144 self-kill) AND every other session's run. Stop the tracked
  background task (TaskStop), or send SIGTERM to the exact wrapper PID
  (`pgrep`/`kill <pid>`). Current rb-lite forwards TERM/INT/HUP/QUIT to the active
  child process. If you used SIGKILL, or if implementer/reviewer children remain
  after TERM/INT/HUP/QUIT forwarding, kill the exact orphaned child PIDs separately.
  **No launch trick saves you from this case.** A `pkill -f rb-lite` matches
  rb-lite's own argv regardless of how it was launched. A resource scope
  (`systemd-run --scope`, a cgroup) can help with lifecycle and resource
  containment, but it is not protection from a same-user broad `pkill`, direct
  PID kill, or OOM kill. For a determined
  name/PID/OOM sweep, recoverability (relaunch — the run is resumable, the diff is
  in the tree) is the real defense; stronger isolation means a separate user, PID
  namespace/container, or tighter operational discipline.
- **A run balloons — many rounds, a huge module, edits sprawling into other files.**
  This bead was high-blast-radius and ran unsupervised. Don't keep relaying findings;
  discard and apply the re-scope + file-lock + watch-each-round recovery playbook in
  "Bounding a high-blast-radius bead." (Better: catch it live next time — watch the
  rounds and intervene before it balloons.)
- **Run hangs.** rb-lite has a default 14400s (4 hour) per-iteration
  timeout — far longer than any realistic iteration. If it actually
  needs to be lower, pass `--implement-timeout SECS`. (Reviewers have their
  own 1800s timeout; a timed-out reviewer is dropped from the panel — see
  "Verify the landed diff" on degraded panels.)
- **`nix run` fails with HTTP 404.** The repo went private, or the user
  doesn't have access. Confirm
  https://github.com/douglaz/rb-lite is public and try again.
- **rb-lite rejects a flag the docs say exists.** You're on a cached revision.
  Rerun with `nix run --refresh github:douglaz/rb-lite -- ...` (or
  `nix profile upgrade`) before concluding the build predates the feature.

## Run artifacts to know

Inside `<run-dir>/`:

- `log.txt` — timestamped status lines (round/iter/panel transitions).
- `implementer-round-N-iter-K.{stdout,stderr}` — every implementer call.
- `reviewer-round-N-K.{stdout,stderr}` — raw output from each reviewer.
- `review-round-N-K.md` — per-reviewer markdown the implementer reads
  on the next round (with status header and stderr-tail for failed
  reviewers).
- `gemini-policy.toml` — only appears if you ran rb-lite's built-in default panel
  rather than the two-reviewer `.rb-lite-reviewers` above; it is that panel's Gemini
  policy file.

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

**Bound a high-blast-radius bead (file-locked, checkpoint rounds):**

```bash
# The task file pins EXACTLY the file(s) the implementer may create/modify and
# forbids all others (see "Bounding a high-blast-radius bead"). --max-rounds is a
# CHECKPOINT to assess and (if the code is sound) relaunch — not a finish. Leave the
# default severity so real P2 polish lands; P3 is manual/inspection-only unless you
# deliberately lower the floor. Add --min-findings-severity P1 only later, once the
# remaining P2 stream turns into gold-plating. Watch each round as it lands.
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
cat >.rb-lite-reviewers <<'EOF'
set -o pipefail; claude -p "<...>" --permission-mode acceptEdits --output-format json --allowedTools "Bash,Read,Grep,Glob,Edit,Task,TaskOutput,TaskStop" | jq -er 'if .is_error then error(.result // "claude reviewer returned is_error") else (.result // empty) end'
EOF
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
