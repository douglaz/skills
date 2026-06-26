---
name: codex-review-beads-ralph-loop
description: >-
  Drive an iterative harden-until-clean loop on the current branch: run `codex
  review` against the base, translate each real finding into a beads_rust (`br`)
  bead, solve every bead via a `ralph-burning` minimal run (one bead per
  feature branch, merged and closed with evidence), then re-run `codex review`
  and repeat until no real findings remain. Use this whenever the user asks to
  "harden the branch with codex+beads+ralph", "review-and-solve until clean",
  "codex then beads then ralph", "ship the branch via ralph", "keep running
  review+fix passes until it's clean", or anything that combines Codex review
  with `br` bead tracking and `ralph-burning` execution. Prefer this over the
  plain `codex-review-loop` when the user wants durable bead-tracked work with
  per-issue branches/PRs instead of direct inline edits. Invoke even if the
  user only names one or two of the three tools — this skill is what tying them
  together actually looks like.
license: MIT
domain: engineering-workflow
role: orchestrator
scope: operations
output-format: commands
triggers:
  - codex review loop
  - review and solve until clean
  - harden the branch
  - ship this branch
  - codex beads ralph
  - codex to beads
  - beads from codex
  - ralph-burning from codex review
metadata:
  version: 0.2.0
---

<!-- TOC: Tool Dependencies | Core Loop | Iteration | Finding → Bead | Bead → Ralph Run | Merge & Close | Stop Conditions | Guardrails | References -->

# codex-review-beads-ralph-loop

Run a harden-until-clean loop that combines three skills into one durable
workflow:

1. `codex review` finds problems.
2. `br` (beads_rust) captures each problem as a tracked bead with acceptance
   criteria.
3. `ralph-burning` drives a real implementation for each bead on its own
   branch, through PR and merge.

After every batch of merges, re-run `codex review` and repeat. Stop when the
review is clean (or when progress stalls — see **Stop conditions**).

This skill exists because treating Codex findings as ephemeral inline edits
loses traceability and history. Beads preserve the *why*, `ralph-burning`
preserves the implementation audit trail, and the loop closes cleanly when
everything is either fixed or disproven with evidence.

## Tool dependencies

All of these must be available. If any is missing, stop and tell the user what
to install.

| Tool | Resolution |
|------|------------|
| `codex` | Must be on `PATH` and authenticated. Default to `-c model="gpt-5.4" -c model_reasoning_effort="xhigh"` for reviews; fall back to env default if `gpt-5.4` is unavailable and note the fallback. Codex auth can break mid-session (401) — see pitfall #8 in references/orchestration-pitfalls.md. |
| `br` | Must be on `PATH`, **version ≥ 0.1.45** (built from the `beads_rust` repo or installed via `install.sh`). Older versions have a DB corruption bug where `br update`/`br close` return `ISSUE_NOT_FOUND` after branch resets; `br show`/`br list` still work, which masks it. `br where` must point at a `.beads/` workspace. |
| `ralph-burning` | Resolve in order: `command -v ralph-burning`, then `nix run github:douglaz/ralph-burning --`. Needs to support the `iterative_minimal` flow (see flow selection below). |
| `gh` | Authenticated (`gh auth status`). Used for PRs. |
| `git` | Clean branch selection. The workflow creates per-bead feature branches; the user's working branch stays the base for merges. |

Also confirm: you know which branch is the *work branch* (the one being
hardened) and which is the *review base* (usually `main` or the default
branch, but sometimes an intermediate branch like `replacement-v1-beads`).
Ask once if either is unclear; the loop runs many subcommands and silent
misconfiguration is expensive.

The work branch must be a **disposable hardening branch**, not the default or
protected branch. This loop creates per-bead feature branches, force-resets the
work branch back to origin after each merge, and may reopen the same finding in
later iterations. If the user points at `main`/`master` or another shared
branch, stop and create a dedicated hardening branch first.

Before iteration 1, resolve and export the loop variables once:

```bash
export PATH="$HOME/.local/bin:$PATH"
ACTOR="${BR_ACTOR:-assistant}"
WORK_BRANCH="<branch being hardened>"
REVIEW_BASE="<review base>"
DEFAULT_BRANCH="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"

if [ -n "$DEFAULT_BRANCH" ] && [ "$WORK_BRANCH" = "$DEFAULT_BRANCH" ]; then
  echo "Refusing to harden the default branch directly; create a dedicated work branch first."
  exit 1
fi

if command -v ralph-burning >/dev/null 2>&1; then
  RALPH=(ralph-burning)
else
  RALPH=(nix run github:douglaz/ralph-burning --)
fi
```

## Proactive suggestion

Suggest this skill when the user is about to ship a branch with substantial
changes, when a single `codex review` surfaced several real findings, or when
the user says they want the branch "clean" or "hardened" in an audited way.
Do not start running it without explicit agreement — a full loop can take
hours.

## Core loop (high level)

```
loop:
  findings = codex_review(work_branch, base=review_base)
  if no_real_findings(findings): break                  # DONE
  beads = [create_bead(f) for f in findings]
  sync_and_commit(beads, work_branch)
  for bead in beads_ordered_by_priority(beads):
    run_ralph_burning(bead)                             # iterative_minimal flow
    merge_and_close(bead)                               # one PR per bead
```

The loop is intentionally sequential per bead. Ralph-burning runs can be long
(minutes to hours) and produce large diffs; running two at once on the same
branch would guarantee merge conflicts.

**Expected duration.** A real hardening loop on a substantial branch takes
10–20 iterations and dozens of merged PRs. Set expectations: this is hours,
possibly a full day, of mostly-autonomous work. Most iterations will find
2–4 findings, and the majority of iter-2+ findings will be regressions
introduced by earlier fixes (see **Regression chain awareness** below).
That is the feature, not a failure mode.

## Flow selection — prefer `iterative_minimal`

Ralph-burning offers two flows that fit this skill: `minimal` and
`iterative_minimal`. Default to **`iterative_minimal`** unless the repo's
`AGENTS.md` or the user says otherwise.

Empirically on a 16-iteration run through ~40 beads on a single work branch:

| Metric | `minimal` | `iterative_minimal` |
|---|---|---|
| mean rounds | 3.4 | 2.4 |
| median amendments | 1 | 1 |
| mean amendments | 4.2 | 2.2 |
| converged in ≤2 rounds | 67% | 84% |
| worst case | 16 rounds / 38 amendments (runaway) | 9 rounds (genuinely hard policy problem) |

`iterative_minimal` runs an in-round implementer stabilization pass before
final review fires, so more reviewer feedback lands as cheap in-round fixes
rather than cross-round amendments. Net effect: fewer runaways, faster
median convergence. Use `minimal` only if `iterative_minimal` is unavailable
on the installed ralph-burning.

## Iteration N

### 1. Run codex review

Run `codex review --base <review_base>` from inside the work tree. Persist the
full output to `/tmp/codex-review-<project>-<branch>-<ts>/pass-NN.review.txt`
and only quote findings you are about to act on into chat.

Findings are lines that start with `[P0]`, `[P1]`, `[P2]`, or `[P3]`. Record
per-priority counts.

**Triage each finding before creating a bead.** A finding is "real" if either:

- it identifies a concrete defect (broken path, unauth endpoint, data race,
  missing test assertion, etc.), or
- it identifies a plausible concern the user cares about that cannot be ruled
  out in under a minute of code reading.

Reject a finding in-chat (do not create a bead) only when you can point at
code or existing tests that disprove it. When in doubt, create the bead —
ralph-burning's review panel will either confirm or reject it with evidence.

**Sibling sweep.** When a finding names one instance of a class —
"`runtime_monday_*` routes lack authentication" — immediately grep the
same file for the pattern. If there are sibling handlers with the same
shape that Codex didn't call out (it looks at the diff, not the whole
file), create beads for those too. Six separate auth-gap beads became
one sweep after we stopped pretending Codex would catch every sibling.
The following classes repeat on real branches:

- Auth gating on newly-added route handlers (grep the file for every
  `async fn` taking a path param and check which ones call an
  `authenticated_*` helper).
- Owner-claim gates on invite-session branches (if one predicate
  checks `machine_has_claimed_owner_invite`, every sibling predicate
  on the same object should).
- Entropy / length caps on user-visible identifiers (if the dashboard
  cap changed, the CLI cap almost certainly didn't; same for the
  server validator).
- Redaction on response payloads (if one status endpoint filters
  owner-scoped fields, every sibling returning the same struct
  needs the same filter).
- Scheme / domain / host scoping on cookies and redirect URLs (a fix
  that tightens one write site needs to cover every other write site
  of the same cookie).

Creating the sibling beads up front avoids 2–3 future iterations.

### 2. Translate findings into beads

For every real finding, create one bead with `br`:

```bash
export PATH="$HOME/.local/bin:$PATH"
ACTOR="${BR_ACTOR:-assistant}"

br create --actor "$ACTOR" "<Short, concrete title>" \
  --priority <0..4> \
  --type bug \
  --labels <area>,codex-review,<other-labels> \
  --description "<finding summary>

Acceptance criteria:
- <criterion 1>
- <criterion 2>
- cargo test && cargo clippy --all-targets -- --deny warnings && cargo fmt --check pass
- nix build passes (if this repo uses nix)

Source: codex review of <work_branch> vs <review_base> (<finding tag>)." \
  --json
```

Map Codex priorities to bead priorities:

| Codex tag | Bead priority | Notes |
|-----------|---------------|-------|
| `[P0]` | `0` (critical) | Catastrophic correctness, data-loss, or security break; always handle first |
| `[P1]` labeled security/auth | `0` (critical) | Security findings dominate priority regardless of Codex tag |
| `[P1]` non-security | `1` | |
| `[P2]` | `2` | |
| `[P3]` | `3` | |

After creating all beads:

```bash
br sync --flush-only
git add .beads/issues.jsonl
git commit -m "chore(beads): record codex review findings (iteration <N>)"
git push
```

See `references/bead-template.md` for a concrete bead description template.

### 3. For each bead, run ralph-burning

Order: priority ascending (0 → 4); within a priority, stable order from Codex.

For each bead:

#### 3a. Claim and branch

```bash
br update --actor "$ACTOR" <bead-id> --status in_progress --json
BRANCH_NAME="feat/<bead-id>-it<N>-<short-slug>"

git checkout "$WORK_BRANCH"
git pull --ff-only
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  git checkout "$BRANCH_NAME"
else
  git checkout -b "$BRANCH_NAME"
fi
```

Slug should be kebab-case, 3–6 tokens, derived from the bead title. Include
the iteration in the branch name so a repeated or reopened finding does not
collide with an earlier merged branch.

#### 3b. Write the prompt file

Save under `.ralph-burning/prompts/<bead-id>.md`. Every prompt MUST include:

- a **Problem** section (concrete, with file:line hints from Codex)
- an **Implementation hints** section (where to look, patterns to follow,
  which existing helper to reuse, any regression risk to avoid)
- the **Orchestration state exclusion** block (see below — this is
  load-bearing for ralph-burning; without it the review panel will flag its
  own run state in an infinite loop)
- **Acceptance criteria** including the exact validation commands the repo
  uses (`cargo test`, `cargo clippy --all-targets -- --deny warnings`,
  `cargo fmt --check`, `nix build` on rust-nix repos; adapt for other stacks)

The orchestration exclusion block:

```
## IMPORTANT: Exclude orchestration state from review scope
Files under `.ralph-burning/` are live orchestration state and MUST NOT be
reviewed or flagged. Only review source code under `src/`, `tests/`, `docs/`,
`dashboard/`, `scripts/`, and config files.
```

A full prompt template lives in
[references/ralph-prompt-template.md](references/ralph-prompt-template.md).

#### 3c. Create and run the ralph-burning project

```bash
PROJECT_ID="rb-<bead-id>-it<N>"

if ! "${RALPH[@]}" project select "$PROJECT_ID" >/dev/null 2>&1; then
  "${RALPH[@]}" project create \
    --id "$PROJECT_ID" \
    --name "<short descriptive name>" \
    --prompt .ralph-burning/prompts/<bead-id>.md \
    --flow iterative_minimal
  "${RALPH[@]}" project select "$PROJECT_ID"
  "${RALPH[@]}" backend check
  "${RALPH[@]}" run start
else
  "${RALPH[@]}" project select "$PROJECT_ID"
  "${RALPH[@]}" backend check
  # Existing project: use `run start` only if it has never been started,
  # `run resume` for failed/paused work, and leave it alone if already running.
  "${RALPH[@]}" run status
fi
```

Project IDs also include the iteration to avoid collisions with older runs for
the same bead. If the same finding reappears later and you intentionally want a
fresh run, increment `<N>` and create a new project ID; if you are recovering
the same in-flight bead after a backend or review-loop failure, reuse the same
`PROJECT_ID` and `BRANCH_NAME`.

For an existing project, choose the next step from `run status`:

- `Status: not_started` → `("${RALPH[@]}" run start)`
- `Status: failed` or `Status: paused` → `("${RALPH[@]}" run resume)`
- `Status: running` → do not restart it; just monitor

Start the run in the background; ralph-burning will create rollback checkpoint
commits on the feature branch as it works. An `iterative_minimal` run takes
roughly 10 minutes (trivial cases, converges round 1) to 1–2 hours (several
amendment rounds; the 9-round worst case in practice is a genuinely hard
policy problem, not wheel-spinning). Do not block on it — schedule periodic
status checks with `"${RALPH[@]}" run status` and let the background task
notify you on completion.

While waiting, do not start the next bead's run. Parallel ralph-burning runs
on sibling branches is supported in principle but multiplies merge-conflict
risk; this skill deliberately serializes.

If amendments oscillate across many rounds (e.g. 4 → 2 → 4 → 3 → 4) or the
same `.ralph-burning/`-flagging amendment keeps recurring, stop the run, add
or strengthen the orchestration-state exclusion, and `run resume`. See
`references/orchestration-pitfalls.md` for more details.

#### 3d. Validate locally

After the run completes (`run status` reports `Status: completed`):

```bash
# Rust-nix repo baseline — adapt to the repo's conventions.
nix develop --command bash -c '
  cargo fmt --check &&
  cargo clippy --all-targets -- --deny warnings &&
  cargo test --no-fail-fast
'
nix build --no-link
```

If the bead touches frontend code, also run the repo's typecheck and any
dashboard-level node tests the prompt's acceptance criteria named.

Stop and investigate if any of these fail — do not push a failing tree.

**Flaky-test policy.** If `cargo test` fails once but a re-run passes, it
was flake; proceed, and note the flake + rerun in the PR body. If it fails
twice, treat as real and investigate before pushing.

**Post-run scope check.** Run a diff-stat on the branch against the work
branch:

```bash
git diff --stat "$WORK_BRANCH"..HEAD
```

Compare the touched files to the prompt's *In scope* list. If the run
edited more than ~300 lines outside the In-scope fence, or touched files
the prompt explicitly marked out-of-scope, stop and decide one of:

- **Abandon** the branch, tighten the prompt with stricter scope fences,
  and rerun. Cheap early; expensive once merged.
- **Inspect then decide.** Look at what changed outside scope; if it's
  incidental (a shared helper that legitimately needed an extra param),
  ship. If it's drift (a refactor the run did on its own), abandon.
- **Ship with an explicit note in the PR body** about the scope overrun,
  so future readers (and the next iteration's codex review) see it.

The `-425` precedent on the author's real branch: a one-line "fix default
credentials" prompt produced a 5100-line diff across 126 files. It passed
all validation and was shipped after a deliberate user call, but it also
means a smaller review surface for every iteration afterwards is more
work than it should be. Catching scope drift at this gate saves
iterations downstream.

#### 3e. Commit leftover journal, push, PR, merge

Ralph-burning typically leaves its final journal uncommitted. Stage it and
commit as a plain `rb: final journal snapshot for <bead-id> run` before
pushing, so the branch tree is clean.

```bash
git add ".ralph-burning/projects/$PROJECT_ID/journal.ndjson"
git commit -m "rb: final journal snapshot for <bead-id> run"
git push -u origin "$BRANCH_NAME"

gh pr create --base "$WORK_BRANCH" --title "<conventional-commit-style title> (<bead-id>)" --body "$(cat <<EOF
## Summary
- <1–3 bullets>
- Implemented via \`ralph-burning\` (\`iterative_minimal\` flow, <N> rounds; amendments <trend>).

## Test plan
- [x] cargo fmt --check
- [x] cargo clippy --all-targets -- --deny warnings
- [x] cargo test (<count> passed)
- [x] nix build
- <other gates as relevant>

Closes bead \`<bead-id>\`.
EOF
)"
```

If the repo has CI, wait for it green. If it does not (`gh pr checks`
reports "no checks"), squash-merge directly — but say so explicitly in chat.

```bash
gh pr merge <n> --squash --delete-branch
git checkout "$WORK_BRANCH"
git fetch origin
git reset --hard "origin/$WORK_BRANCH"
```

#### 3f. Close the bead with commit evidence

```bash
br close --actor "$ACTOR" <bead-id> --reason "Implemented in commit <sha> (#<pr-n>). <one-line-what-changed>. Validated: cargo fmt --check, cargo clippy --all-targets -- --deny warnings, cargo test (<count> passed), nix build." --json

br sync --flush-only
git add .beads/issues.jsonl
git commit -m "chore(beads): close <bead-id> after PR #<n> merge"
git push
```

Evidence must name the merge commit SHA and the PR number. "Done" is not
evidence.

### 4. Re-run codex review

After all beads from iteration N are closed and merged, repeat from step 1
with a fresh review pass. Increment the iteration counter in chat and in
commit messages so the history is readable later.

## Regression chain awareness (why the loop keeps finding things)

The outer Codex review and ralph-burning's inner final_review have
different *diff bases*, and that is the entire point of the outer loop:

| Reviewer | diff base | surface |
|---|---|---|
| ralph's final_review | this bead's branch point | just this bead's edits |
| outer `codex review` | `$REVIEW_BASE` (usually `main`) | every merged bead + original branch work |

When bead A changes a server auth predicate, ralph's final_review sees
only the server diff and cannot see the clients that are now
mismatched. The next iteration's codex review sees both, and flags the
clients. This is not a bug in either reviewer — they have genuinely
different jobs.

The practical implication: **later iterations will mostly find
regressions from earlier fixes**. Auth-tightening fixes (bead A adds a
gate) produce client-mismatch findings (bead B forwards auth). Scope-
narrowing fixes (bead C rejects X in Y's case) produce
over-correction findings (bead D: X was also legitimate in Z's case).
Expect this; it is the loop earning its keep. Do not interpret it as
"we keep introducing bugs."

To minimize the regression chain length:

- **Acceptance criteria must list what must keep working**, not just
  what's broken. A fix that narrows access for security should
  explicitly call out the legitimate cases the narrow is still
  supposed to allow. Otherwise ralph's final_review signs off on the
  narrow, and iteration N+1 finds the over-correction.
- **Sibling sweep** (see Iteration 2) turns 4 iterations into 1 PR.
- **Tighter scope fences** (see Post-run scope check) reduce the
  surface of each bead's diff, which reduces the surface of the next
  iteration's regression findings.

## Stop conditions

End the loop and surface status to the user when any of these trigger:

- Latest `codex review` reports zero findings. **Done.**
- All remaining findings are rejected with concrete evidence (rare; prefer to
  create the bead and let ralph-burning's panel decide).
- The same materially identical finding survives two full iterations (bead →
  ralph → merge → re-review still shows it). Stop and escalate — either the
  fix is wrong or the finding is a false positive neither side is
  disproving.
- A *finding class* (e.g. "auth gap on a new handler") reappears three
  iterations in a row with new siblings each time. The loop is working, but
  a one-time manual sweep would be faster than N more iterations; pause and
  do a broad grep with the user.
- Backends are exhausted in a way that cannot be recovered within the session
  (see [references/orchestration-pitfalls.md](references/orchestration-pitfalls.md)
  for recovery patterns).
- The user asks to pause.

## Guardrails

- **One bead per branch, serialized.** Do not start bead B's ralph-burning
  run while bead A is still open. Merging two long-lived ralph branches into
  the same base is where conflicts live.
- **Harden only a disposable work branch.** If the requested work branch is
  `main`/`master`, protected, or shared with other humans, stop and create a
  dedicated hardening branch first.
- **Never skip validation.** "It converged" is not enough — rust-nix repos
  especially have a delta between `cargo test` and `nix build`.
- **Evidence-first closure.** Closing a bead without a merge SHA means the
  next iteration's Codex run can still see the problem; you will end up
  reopening it.
- **Respect the `br` rules.** Always pass `--actor`, always use `--json`,
  never run bare `bv`, and remember that `br` never touches git — commits
  are your job. These rules come from the `br` skill and they do not change
  here.
- **Orchestration state is not code.** Always include the exclusion block in
  every ralph prompt, and keep `.ralph-burning/` out of code-quality
  assertions.
- **Destructive actions need confirmation.** Squash-merge and force-reset on
  the work branch are fine within this loop because the loop itself is
  authorized by the user, but if CI is red or tests are failing, stop and
  ask.

## When to defer to sibling skills

This skill intentionally composes other skills. Reach for them directly when
the shape of the task does not match this loop:

| Situation | Skill |
|-----------|-------|
| Review-and-fix inline without beads or PRs | `codex-review-loop` |
| Translate a finished markdown plan into beads once | `plan-to-beads-transfer` |
| Refine existing beads before implementation | `bead-polish-loop` |
| Audit a bead graph before launching work | `second-model-bead-audit` |
| Self-contained implementation/review run without bead-tracked hardening | `orchestrating-with-rb-lite` |

## References

| Topic | File |
|-------|------|
| Bead description template | [references/bead-template.md](references/bead-template.md) |
| Ralph-burning prompt template | [references/ralph-prompt-template.md](references/ralph-prompt-template.md) |
| Orchestration pitfalls (oscillation, review-loops-on-own-state) | [references/orchestration-pitfalls.md](references/orchestration-pitfalls.md) |
