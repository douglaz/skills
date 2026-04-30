---
name: drain-bead-backlog-via-ralph
description: >-
  Drain an existing `br` pending-beads backlog via `ralph-burning`: repeatedly
  choose the highest-priority ready bead, run one focused `iterative_minimal`
  task per branch/PR, verify local gates, push, wait for CI, squash-merge,
  reset master, build, close the bead, and continue. Capture dogfood findings
  as beads and interrupt for P0/P1 issues. Use when the user asks to drain,
  work through, or clear pending beads with ralph; solve beads one by one; use
  ralph for the bead queue; or dogfood ralph-burning while shipping real work.
  Prefer this over `codex-review-beads-ralph-loop` when beads already exist,
  and over `orchestrating-with-ralph-burning` when chaining multiple beads
  rather than running one task.
license: MIT
domain: engineering-workflow
role: orchestrator
scope: operations
output-format: commands
triggers:
  - drain the bead backlog
  - solve beads one by one
  - work through pending beads
  - ralph the backlog
  - dogfood ralph-burning
  - keep solving beads until done
  - iterative minimal on the backlog
  - ralph and beads together
  - use ralph for the bead queue
  - br ready and ralph
  - clear the beads
compatibility: >-
  Requires `ralph-burning` (on PATH or via `nix run github:douglaz/ralph-burning
  --`), `br` (the beads_rust CLI, typically `~/.local/bin/br`), `gh`, `git`,
  and `nix` for the canonical build gate. Designed for the ralph-burning
  source repository itself, but the structure works for any project that uses
  `br` for bead tracking and ralph-burning for execution.
---

Use this skill when the user wants to *clear* a pending-beads backlog using
ralph-burning — not when they want to plan one task, not when they want codex
to discover findings, but when they explicitly want to chain through beads and
ship each one as its own PR.

## Why this is its own skill

Two adjacent skills exist; pick this one when the framing matches:

- **`orchestrating-with-ralph-burning`** covers the *inner mechanics* of one
  ralph-burning run — flow choice, entry path, monitoring, recovery. Use it
  for *one* task. Use *this* skill when there is a queue of beads to work
  through and the per-run mechanics are subordinate to a longer workflow.

- **`codex-review-beads-ralph-loop`** covers the *discovery* shape — run
  `codex review` against a branch, file findings as fresh beads, solve each
  via ralph, re-review until clean. The premise is "harden one branch." Use
  *this* skill when the bead backlog already exists in `br` (filed by
  planning, prior runs, dogfooding, or a teammate) and the user just wants
  it drained.

The defining trait of this loop: *the beads are the input.* Codex is not
producing the work list; `br ready` is. The user is asking for a long
session of "solve this, ship it, take the next one, ship it," not a single
task and not a fresh discovery pass.

## Default stance

- One bead per branch. One bead per PR. Squash-merge.
- `iterative_minimal` is the default flow. It usually converges in 3–10
  rounds. It can hit `max_completion_rounds` and force-complete; that is
  documented as an acceptable outcome.
- After every merge, `git reset --hard origin/master` (squash-merge makes
  local master diverge from origin), then `nix build`, then start the next
  bead. Never carry checkpoint commits across beads.
- File dogfood findings as fresh beads the moment they show up. Don't keep
  them as memory or chat-only notes — the value compounds when the next
  ralph run benefits from your fix.
- Pre-existing backlog beads are immutable input. If a backlog bead is
  ambiguous, ask the user; don't silently re-scope.

## The loop

1. **Pick.** Run `br ready --limit 10`. Take the top P0 first; if none,
   the lowest-numbered P1; only descend to P2 if the user says so or the
   P1 list is empty / oversized.
2. **Read.** `br show <id>`. If the bead's acceptance criteria are vague,
   pause and ask the user before writing a prompt. A weak prompt
   produces a weak run.
3. **Branch.** `git checkout -b feat/<bead-id>-<short-slug>`. One bead =
   one branch. Don't pile beads onto a working branch.
4. **Prompt.** Write a focused prompt file at the repo root with the
   sections from the prompt template below. Save it as `prompt-<id>.md`
   so the run record points at a stable file.
5. **Project + run.** Use the freshly-built `./result/bin/ralph-burning`
   (or `nix run github:douglaz/ralph-burning --` if the local copy is
   stale) to create a project from the prompt:
   ```
   ./result/bin/ralph-burning project create \
       --id <short-id> --name "<short-name>" \
       --prompt prompt-<id>.md \
       --flow iterative_minimal
   ./result/bin/ralph-burning project select <short-id>
   ./result/bin/ralph-burning run start &
   ```
   Run the start in the background; come back to monitor. The
   `iterative_minimal` flow loops the implementer until two consecutive
   no-change iterations and then runs `final_review`.
6. **Monitor (don't babysit).** Schedule poll intervals at ~30 minutes
   (each iteration takes ~10–25 min on default backends; faster checks
   burn the prompt cache for nothing). Look at `run status`, `run tail
   --last 6`, and the diff stat. Don't intervene unless something is
   actually broken — see the failure-recovery section.
7. **Gates.** When the run reaches `Status: completed`, run all gates
   locally:
   - `nix develop -c cargo fmt --check`
   - `nix develop -c cargo clippy --locked -- -D warnings`
   - `nix develop -c cargo test --locked --features test-stub`
   - `nix build`
   Treat any pre-existing flakiness as a separate issue; don't let it
   block a clean PR. CI will reveal whether the local pass was real.
8. **Push & PR.** `git add` only the files the run produced (plus the
   journal sync), commit with a real message, push, and `gh pr create`
   with a body that summarizes the change, the run convergence, and the
   test plan.
9. **CI.** `gh pr checks <pr>`. Wait for green. On a known-flaky CI test
   re-run via `gh run rerun <id> --failed`. Don't hand-tune the branch
   to make a flake go green.
10. **Merge.** `gh pr merge <pr> --squash --delete-branch`. Then:
    ```
    git fetch origin master
    git reset --hard origin/master
    nix build
    ```
    The `nix build` is mandatory here — the next bead's run will use
    that binary, and you want it to reflect everything you've shipped
    so far.
11. **Close the bead.** `br update <bead-id> -s closed`. Don't skip
    this — open beads in `br` are the work list for everyone.
12. **Loop.** Back to step 1.

## Embedded dogfooding

Running ralph-burning at scale exposes its own bugs. Capture them while
they're hot:

- If a run fails for a reason the bead didn't intend (transient backend
  error not retried, schema rejected by the model, lockfile corrupted,
  workspace.toml override out of sync, gitignored file leaked into a
  checkpoint), file a fresh bead via `br create -t bug -p <0|1|2> -l
  dogfood,<area> "..." -d "..."`. Include: observed behavior, repro
  trace, expected behavior, fix options, acceptance criteria. The full
  format used in this session's `usw`, `t7j`, `c2e` beads is a good
  template.
- If the dogfood bead is **P0 or P1**, *interrupt the queue* and fix it
  next. Every later bead in the backlog will benefit. Save the partly-
  done bead for after; ralph-burning's `run resume` makes this cheap.
- If the dogfood bead is **P2 or lower**, file it and keep moving.
- Track dogfood beads with the `dogfood` label so the operator can
  filter them later (`br list --label dogfood`).

The pattern from this session that proved this paid off: the run on
bead `9ni.8.5` failed because gpt-5.5 rejected an `allOf` in the
JSON schema; we filed and fixed `c2e` (dropped one allOf trigger) and
`c2e-followup` (inlined single-element allOfs in the strict-mode
post-processor) before resuming `9ni.8.5`. Without the interrupt, every
subsequent bead would have hit the same wall.

## Prompt template for each bead

The prompt that drives the ralph-burning run should always have these
sections:

```
# Bead <id>: <one-line goal>

## Problem description
<2–4 paragraph what + why; reference the bead's acceptance criteria>

## Required changes
<numbered list of concrete edits — file paths, function names, expected
shape of changes>

## Tests
<3–7 specific test cases the implementer should add, named in
imperative form: "X happens when Y", not "test_x_y">

## Scope guard
<bulleted list of what NOT to do — explicit out-of-scope items so
reviewers don't expand the diff>

## IMPORTANT: Exclude orchestration state from review scope
Files under `.ralph-burning/` are live orchestration state and MUST
NOT be reviewed or flagged. Only review source code under `src/`,
`tests/`, `docs/`, and config files. The same applies to `.beads/` —
that is durable bead state, not code.

## Acceptance criteria
- <bead's acceptance criteria, copied from `br show <id>`>
- `nix build` passes on the final tree (authoritative gate).
- `cargo fmt --check`, `cargo clippy --locked -- -D warnings`, and
  `cargo test --locked --features test-stub` all pass.
```

The `Scope guard` block matters more than it looks like it should. Without
it, reviewers in the final-review panel will keep proposing amendments to
adjacent areas and you'll burn 25 rounds chasing them. The orchestration-
state exclusion block is also load-bearing — Codex reviewers will
otherwise treat the run's own `run.json` as a finding and propose
amendments to it, which never converges.

## Failure recovery patterns (drawn from the orchestrating-with-ralph-burning skill)

- **Schema validation failure (`missing field change_summary`).** The
  implementer did the work but returned text instead of JSON. Just `run
  resume`; on retry the model usually outputs JSON correctly because it
  sees the code is already done.
- **Codex API hang / timeout.** 1-hour timeout fires, run fails. `run
  resume` picks up at the failed stage.
- **Model at capacity.** Transient. `run stop`, brief wait, `run resume`.
- **All backends exhausted in final_review.** This usually means the
  panel is configured tight (e.g., one required reviewer, optional
  spark exhausted on credits) and the one live reviewer hit a transient
  error. After bead `usw` ships, this auto-retries; until then, `run
  resume` is the manual fix.
- **Reviewer keeps proposing the same finding for many rounds.** Either
  the prompt's scope guard is too loose (tighten it; restart) or the
  reviewer is asking for a separate bead's worth of work (add a
  classification of `covered_by_existing_bead` if the contract supports
  it; otherwise close-out by hitting `max_completion_rounds`).
- **`run.json` showing as a review finding.** Add the orchestration-state
  exclusion block to the prompt and `run resume`. Almost always the
  fix.
- **`max_completion_rounds=25` hit.** Run force-completes. The code is in
  place; the review just couldn't agree on a fixed point. Ship it. The
  next round of review on the PR by humans will catch anything truly
  broken.

## After a chore-level cross-cutting merge

Some merges affect every future run (e.g., bumping the default codex
model, removing a backend from `final_review.backends`, changing the
retry policy defaults). After such merges, do TWO additional things
beyond the normal loop:

1. **Update workspace overrides if any.** `config show | grep workspace.toml`
   surfaces operator-level overrides. If you're bumping `gpt-5.4` →
   `gpt-5.5` in defaults, you also need to bump the workspace.toml
   override or it will keep pinning the old value. The skill's
   experience: doing this *after* the merge (not during) is fine, but
   doing it *not at all* causes silent confusion when the next run
   produces "running on the old model" telemetry.
2. **First run on the new master is a smoke test.** Treat unusual
   convergence numbers (much faster, much slower, weird amendment
   patterns) as a signal to look at, not just noise.

## Useful one-shot commands

| Want | Command |
|------|---------|
| Top of the backlog | `br ready --limit 10` |
| Bead detail | `br show <id>` |
| Bead detail as JSON | `br show <id> --json` |
| Filter by priority | `br list --priority 0 --status open` |
| Filter dogfood beads | `br list --label dogfood` |
| Live run status | `./result/bin/ralph-burning run status` |
| Recent run events | `./result/bin/ralph-burning run tail --last 10` |
| Stuck process check | `cat .git/ralph-burning-live/projects/<id>/runtime/backend/active-processes.json` and `ps -o pid,etime -C node` |
| What changed on branch | `git diff --stat origin/master..HEAD` (filter `\.ralph-burning/\|\.beads/` to see only code) |

## What this skill is NOT

- It is not a way to bypass code review. Each PR still gets human
  attention before merge, even if CI is green.
- It is not a way to auto-create beads. New beads come from the
  user's planning, codex review, or dogfooding observation. This skill
  files dogfood beads but does not invent feature beads.
- It is not a daemon mode. The user is in the loop; check-ins are
  ~30 min, not seconds. Ralph-burning isn't fast enough to babysit.

## Closing the loop

The skill ends when one of:

- The backlog is empty (`br ready` returns no items).
- The user says "stop" or pivots to something else.
- A bead requires human judgment that ralph-burning can't substitute
  for (architectural decision, product call, security review).

When closing, leave the workspace clean: master is pristine,
`./result` points at the latest binary, no stale branches, dogfood
beads filed but not necessarily closed.
