---
name: pr-with-codex-bot-review
description: >-
  How to open and land a pull request through GitHub's `chatgpt-codex-connector` review bot
  (the one that auto-comments "Codex Review" on PRs), gating also on `coderabbitai[bot]`
  when it is configured on the repo. Covers writing the PR body, running local gates, a
  local Claude Fable pre-review before push so bot rounds start from the good diff, the
  codex bot's actual behavior — auto-fires on substantive code PRs, often silent on
  docs-only PRs, line-level findings live in PR review comments not the review body —
  re-triggering with `@codex review`, addressing findings via amend + force-push, knowing
  when to merge despite bot silence, and the squash-merge + branch-reset pattern. Use
  this skill whenever the user asks to open a PR, "ship this", "merge it", "let the bot
  review", "land the change", or right after substantial code work that's ready for
  review. Also when the user asks why the bot "isn't reviewing" or how to interpret what
  it left behind.
argument-hint: "[pr-number-or-branch]"
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
---

# pr-with-codex-bot-review

Drive a PR through CI and the `chatgpt-codex-connector` review bot to a clean merge,
without bouncing off the bot's quirks.

## When this applies

The bot is `chatgpt-codex-connector[bot]` on GitHub. It runs as part of OpenAI's Codex
GitHub integration: pulls each PR diff, runs a Codex review pass against it, leaves a
boilerplate "💡 Codex Review" pull-request review plus zero or more **line-level review
comments** carrying the actual findings. It triggers automatically on PR open, on draft
mark-ready, and on `@codex review` comments (per the bot's own boilerplate).

Use this skill when you're about to open a PR, just opened one and are wondering why
the bot is quiet, or got findings back and need to address them.

## What "the bot reviewed" actually means on GitHub

The bot communicates approval and findings through **three distinct channels**, all on
the same PR:

1. **Reaction on the PR body** — `eyes` (👀) when the bot picks up the PR for review,
   `+1` (👍) when it approves with no concerns. **This is the authoritative approval
   signal.** Check it before assuming silence:

   ```bash
   gh api repos/<owner>/<repo>/issues/<N>/reactions \
     | jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]") | {content, created_at}'
   ```

   When the bot has finished and is happy, you'll see `{"content": "+1", ...}`. That's
   the explicit "approved" signal — don't wait further. (This is what the bot's own
   boilerplate means by "otherwise it will react with 👍.")

2. **Pull-request review** with `state: COMMENTED` — usually just boilerplate:

   ```
   ### 💡 Codex Review
   Here are some automated review suggestions for this pull request.
   **Reviewed commit:** `<sha>`
   ```

   The body of this review carries no findings. It's a wrapper that anchors the
   review to a specific commit SHA.

3. **Line-level review comments** — where actual findings live, separate API:

   ```bash
   gh api repos/<owner>/<repo>/pulls/<N>/comments      # actual findings
   ```

When checking whether the bot has weighed in, query reactions FIRST (cheapest signal,
authoritative for approval), then line comments (for findings if any). Findings are
encoded with markdown priority badges:

```markdown
**<sub><sub>![P1 Badge](https://img.shields.io/badge/P1-orange?style=flat)</sub></sub>  Title**
```

`P0`, `P1`, `P2`, `P3` priorities map to severity. Treat them like the bot is a reviewer
giving credible hypotheses — verify before agreeing or rejecting.

## CodeRabbit (parallel reviewer bot, when configured)

Many repos also have `coderabbitai[bot]` enabled. It runs on the same PR as the codex
bot but communicates differently — never assume codex's `+1` reaction means CodeRabbit
is also done. CodeRabbit's signals:

1. **Status check on the PR** — `CodeRabbit` shows up in the check rollup with
   `SUCCESS`, `FAILURE`, or `PENDING`. This is the cheapest gating signal:

   ```bash
   gh pr view <N> --json statusCheckRollup \
     --jq '.statusCheckRollup[] | select(.context == "CodeRabbit") | "\(.state) at \(.startedAt)"'
   ```

   `SUCCESS` is not the same as "reviewed". CodeRabbit also returns `SUCCESS` when it
   **skips** — on a rate limit, or when it judges the diff similar to previous changes —
   and names what it skipped in a "Files skipped from review" list in the walkthrough
   comment. Read that list before treating the check as a pass:

   ```bash
   gh api repos/<owner>/<repo>/issues/<N>/comments \
     --jq '.[] | select(.user.login == "coderabbitai[bot]") | .body' \
     | grep -A20 -i 'skipped from review'
   ```

   A skip on files this PR does not meaningfully change is fine. A rate-limit skip, an
   unexplained one, or one covering files central to the change means **nobody reviewed
   them** — `@coderabbitai review` to re-trigger and wait. Say which reason applied;
   "the check was green" is not a review.

2. **Issue comment** — `coderabbitai[bot]` posts an auto-summary / walkthrough as a
   regular PR comment (the `issues/<N>/comments` endpoint, NOT the `pulls/<N>/comments`
   one). The first such comment is usually `<!-- review in progress -->` and gets
   replaced once CodeRabbit finishes:

   ```bash
   gh api repos/<owner>/<repo>/issues/<N>/comments \
     | jq -r '.[] | select(.user.login == "coderabbitai[bot]") | .body | split("\n") | .[0:3] | join(" / ")'
   ```

3. **Line-level review comments** — same `pulls/<N>/comments` endpoint as the codex
   bot, but authored by `coderabbitai[bot]`. Filter by user when triaging findings:

   ```bash
   gh api repos/<owner>/<repo>/pulls/<N>/comments \
     | jq -r '.[] | "[\(.user.login) @ \(.commit_id[0:8])] \(.body | split("\n")[0])"'
   ```

CodeRabbit interactions: `@coderabbitai review` to (re-)trigger, `@coderabbitai resolve`
to ack findings, `@coderabbitai pause` to silence on a draft. CodeRabbit's findings
don't carry P0/P1/P2/P3 badges; severity is conveyed in the prose. Treat them like a
human reviewer's comments — verify, don't reflexively agree.

If the repo doesn't have CodeRabbit enabled at all, the status check simply won't
appear in the rollup; nothing to wait on. Skip this section.

## Workflow

### 1. Local gates before push

The point of running local gates is to fail fast before CI burns minutes. Use the
exact commands CI uses (without `--all-targets` for clippy unless CI does):

```bash
nix develop -c cargo fmt --check
nix develop -c cargo clippy --locked -- -D warnings    # match CI flags exactly
nix develop -c cargo test --features test-stub --locked
nix build                                              # authoritative gate
```

If the project uses a feature flag for stub backends (common pattern: `test-stub`), pass
it. Forgetting it can produce phantom test failures in tests that exercise mocked
backends. CI's exact command lives in the workflow file (`.github/workflows/`); copy it.

If clippy fails on `clippy::items-after-test-module` only when `--all-targets` is set,
that's a pre-existing artifact and CI doesn't use that flag — confirm against CI before
reformatting code to fix it.

### 2. Local second reviewer before you push

The GitHub bots are the *last* reviewers to see the diff, and they're the slowest
(5–30 min) and the most expensive to iterate against — every round costs a
force-push and a re-trigger. Running one local reviewer first turns findings you
would have collected over three bot rounds into edits you make before the PR
exists.

Claude Fable at high effort is the default local reviewer here: it reads the repo
around the diff, so it catches the out-of-diff callers and siblings the bots
routinely miss.

```bash
BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
RD=$(mktemp -d "/tmp/pr-review-$(basename "$(git rev-parse --show-toplevel)")-XXXXXX")
cat >"$RD/prompt.txt" <<EOF
Review the changes on this branch against origin/${BASE}, as a pre-PR review.

Scope: \`git diff origin/${BASE}\` plus untracked source files from
\`git status --short\` (they are not in the diff). Read CLAUDE.md / AGENTS.md and
the surrounding code when a finding depends on them.

Report real defects in the changed code: correctness, security, data loss,
concurrency, error handling, missing tests for changed behavior, and violations
of this repo's documented conventions. Before asserting any claim about behavior
in code the diff does not show, read that code and cite file:line; if you cannot
verify it, mark it a QUESTION, not a finding. One finding per line starting with
[P0]/[P1]/[P2]/[P3], then file:line, then the claim, then indented detail. Do not
propose mechanism no correctness/security/data-loss requirement needs. Do not
modify any file. Output exactly "No findings." if clean.
EOF

claude -p "$(cat "$RD/prompt.txt")" \
  --model fable --effort high --output-format json \
  --tools "Bash,Read,Glob,Grep" --allowedTools "Bash,Read,Glob,Grep" \
  --disallowedTools "Edit,Write,NotebookEdit" \
  >"$RD/fable.json" 2>"$RD/fable.stderr"
CLAUDE_RC=$?

jq -er 'if .is_error then error(.result // "reviewer returned is_error")
        else (.result // empty) end' \
  <"$RD/fable.json" >"$RD/fable.txt"
JQ_RC=$?
```

**Check both exit codes before believing the output.** `CLAUDE_RC != 0` or
`JQ_RC != 0` means the review never ran — auth, rate limit (429), or overload
(529) — and `$RD/fable.txt` will be empty. Do not pipe this straight
into `tee` and read the file: a failed reviewer and a clean reviewer both leave
you with no findings on stdout, and the difference is the whole point. The clean
signal is exit 0 plus exactly `No findings.`; empty output with exit 0 is
ambiguous, not clean.

If it failed, either re-run it or open the PR without a pre-review — but do not
tick the pre-review line in the PR body. Claiming a review that never ran is
worse than not running one.

Triage it exactly like a bot finding: credible hypothesis, verify before agreeing
or rejecting, fix what's real, and don't build mechanism no requirement needs.
Fix accepted findings *before* opening the PR so the bots review the good version
— the first diff the bots see is the one their reaction attaches to.

Two things worth saying out loud in the PR body afterwards: that a local review
ran, and what you deliberately did **not** change. When the codex bot later
raises something you already considered and rejected, a line in the body saying
so (with your evidence) is what keeps the next round from relitigating it.

This step is optional when the diff is trivial or docs-only. It earns its keep on
anything that touches auth, money, migrations, concurrency, or a public API — the
same classes where a bot round-trip hurts most. If `claude` isn't available, skip
it and say so rather than pretending the PR got a pre-review.

### 3. Push and open the PR with a structured body

Use a HEREDOC to keep the body readable. The structure that consistently works through
the bot:

```markdown
## Summary
<1-3 sentences: what the change does and why>

## Lineage / context
<for multi-PR sequences: link the chain. e.g., "Builds on #189 (...). Addresses
codex-review #193 P1 (...).">

## Trade-offs accepted
<be honest about what this fix doesn't solve. The bot rewards epistemic
honesty in commit messages with kinder reviews.>

## Test plan
- [x] `nix develop -c cargo test --features test-stub --locked` passes
- [x] `nix develop -c cargo clippy --locked -- -D warnings` clean
- [x] `nix develop -c cargo fmt --check` clean
- [x] `nix build` succeeds
- [x] Local review (claude fable, high effort): <N findings addressed / clean>
- [ ] CI green
- [ ] Codex bot review

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Open with `gh pr create --title "<imperative title under 70 chars>" --body "$(cat <<'EOF'
...
EOF
)" --head <branch>`.

### 4. Wait for CI

```bash
gh pr checks <N>     # one-shot status
```

Typical lag for a heavy conformance gate: ~7-8 min. While CI runs, work on
other things — don't sit on the pull. If CI fails on something unrelated to your diff
(common: signal-timing flakes, log-capture races), `gh run rerun <run-id> --failed`
and continue. Diagnose the flake into a follow-up bead/issue rather than blocking the
current PR.

### 5. Wait for the bot's reaction signal

The bot's reaction on the PR body is the authoritative status indicator. Don't fall
back to "wait some minutes and assume" when this is one API call away:

```bash
gh api repos/<owner>/<repo>/issues/<N>/reactions \
  | jq -r '.[] | select(.user.login == "chatgpt-codex-connector[bot]") | "\(.content) at \(.created_at)"'
```

| Reaction | Meaning | Action |
|---|---|---|
| (empty) | Bot hasn't picked up the PR yet | Wait or `@codex review` |
| `eyes` | Bot is reviewing | Wait |
| `+1` | Bot approves with no concerns — **of the tree it read**, which is not always the tip | Go to § 7; do not merge from here |

Typical bot timing: 5-30 minutes from open. On docs-only or tiny PRs the bot still
reacts (saw `+1` on PR #191's pure-docs change about 20 min after open) — there's
no class of PR the bot reliably skips, only PRs you didn't wait long enough on.

To explicitly trigger or re-trigger (after a force-push, or if the bot appears
stuck):

```bash
gh pr comment <N> --body "@codex review"
```

After a force-push, the bot's prior review and reaction reference the old SHA. The
bot often re-reviews automatically on a new push, but re-comment `@codex review` if
you don't see a new reaction or review after ~10 min.

If reaction is `+1`, also check line comments — the bot can approve on the latest
SHA while older line comments from a prior round are still attached and outdated.
Look at each comment's `commit_id` to see whether it's against the current head:

```bash
gh api repos/<owner>/<repo>/pulls/<N>/comments \
  | jq -r '.[] | "\(.commit_id[0:8]) \(.body | split("\n")[0])"'
```

**`+1` plus green CI is not the merge condition — § 7 is.** This section only tells you
the bot is *finished*; § 7 decides whether it finished on the tree you are about to merge.
Two things checked nowhere in this section can each make a `+1` misleading: the reaction
carries no SHA, so after a force-push it may belong to the previous head, and CodeRabbit
returns `SUCCESS` when it *skips* a review entirely. Read § 7 before merging, always.

### 6. Address findings, if any

For each P-badge finding:

- **Verify, don't reflexively agree.** The finding is a credible hypothesis. Read the
  code referenced. If the bot misread the diff, write a follow-up comment with
  evidence rather than capitulating.
- **If accepted, fix it AND add a regression test that pins the new behavior.** The
  test serves as a counter-claim if the bot raises the same concern next round.
- **Cite the finding in the commit message.** Future readers (and the next bot
  review) need to know which feedback this commit addressed. Use a phrase like
  "Addresses codex-review #194 P1 (first round)" — round number matters when the bot
  re-reviews after force-push.
- **Amend, don't stack commits, for one-shot fixes.** Cleaner squash-merge history.
  `git commit --amend --no-edit` then `git push --force-with-lease`. For larger
  follow-ups, separate commits are fine — the squash absorbs them.

### 7. Decide based on reaction, not on time

Merge when the reaction-based check passes:

- Codex bot reaction on PR body is `+1`, **and** the tree it reacted to is the tip. Pass
  that SHA as `--match-head-commit` when you merge, so a push landing between the check
  and the merge makes the merge refuse rather than take an unreviewed head. The
  reaction carries no SHA; its review wrapper does (`**Reviewed commit:** <sha>`). Compare
  that against the head — a `+1` left before your last force-push approves the old tree.
- CI is green.
- CodeRabbit status check is `SUCCESS` **and it was a review, not a skip** — check the
  "Files skipped from review" list per the query above. Absent from the rollup entirely
  (repo has no CodeRabbit) is still fine; there is nothing to wait for.
- No outstanding line comments against the current head SHA, from EITHER bot.

Don't merge when:

- Codex bot reaction is `eyes` (still reviewing) — wait, even if CI is green.
- Codex bot has unaddressed line comments (`P0`/`P1`/`P2`/`P3`) referencing the current head.
- Codex bot has no reaction yet — `@codex review` to wake it up; don't preemptively merge.
- CodeRabbit status is `PENDING` — wait, even if codex already approved.
- CodeRabbit status is `FAILURE` or it left unaddressed line comments on the current head — address.
- CodeRabbit returned `SUCCESS` by skipping files this change actually touches — re-trigger.
- CI failed and you haven't determined whether it's flaky or real.
- You force-pushed and reaction still references the old SHA — wait at least 10 min
  after the force-push, or `@codex review` (and `@coderabbitai review`) to re-trigger.

**The reaction is what matters; clock-time waits are a code smell that suggests
you're ignoring the actual signal.**

### 8. Squash-merge and clean up

```bash
[ -z "$(git status --porcelain)" ] || { echo "tree dirty — do NOT merge"; exit 1; }
gh pr merge <N> --squash --delete-branch --match-head-commit "$(git rev-parse HEAD)"
git checkout master
git fetch origin master && git reset --hard origin/master
nix build                                    # confirm master is healthy
```

`--match-head-commit` takes the **full 40-char OID** — pass `git rev-parse HEAD`, not the
wrapper's SHA, which may be abbreviated and would then make every merge refuse with no
hint why. The wrapper SHA is for the § 7 *comparison*; this pin is what makes the merge
itself refuse a head that changed underneath you.

Check before merging, and make it `exit 1` rather than print: a bare `git status
--porcelain` exits 0 either way, and `--delete-branch` makes `gh pr merge` switch branches
itself — so a dirty tree aborts *after* the squash has already landed. Stash if the change
matters; discard only after looking, because `git checkout -- .` is not recoverable.

`reset --hard` rather than `pull` because squash-merge rewrites history.

## Iteration patterns observed

### "Bot found a P1 you introduced while addressing a different P1"

Saw this on PR #194: pass-1 P1 said "add `additionalProperties: false` to the
injected subschema". I added it. Pass-2 P1 said "now your subschema is
unsatisfiable because the surrounding `items` schema requires more fields and you
forbid them." Both findings were correct — the second only became visible after
the first was fixed.

**Pattern**: when a fix changes the shape of nearby schemas/types, expect a
follow-up round. Run `@codex review` after force-push and read the new findings
fresh, not "by analogy" with the prior round.

### "Bot looks silent — but is actually `+1` already"

Saw this repeatedly across this session (PRs #186, #189, #191, #195). I was
checking `gh pr view --json reviews` (which only shows review wrappers, not
reactions) and `gh api .../pulls/<N>/comments` (which only shows line comments)
and concluding "no review yet" when the bot had already left `+1` on the PR
body.

PR #191 (a README docs PR) had `+1` from the bot 13 minutes BEFORE I merged.
I'd been waiting another full cycle for nothing.

**Always query `issues/<N>/reactions` first** — it's the cheapest signal and
the authoritative one for approval.

### "Force-pushing breaks the bot's auto-trigger"

Saw on PR #189 → after `git push --force-with-lease`, the bot stayed on the
prior commit's review. Comment `@codex review` to point it at the new SHA. The
bot's behavior is to lock onto a `Reviewed commit:` SHA in its review body —
force-pushing changes the SHA and the bot doesn't always notice automatically.

### "Body update fails with GitHub Projects classic deprecation warning"

`gh pr edit --title` and `--body` sometimes fail with a GraphQL warning about
the deprecated Projects classic API. The actual update *did* land in some cases
and not in others. If `gh pr view <N> --json title,body` shows the new content,
ignore the warning. If not, retry once. The squash-merge subject defaults to
the commit message anyway, so the PR title is mostly cosmetic.

## Anti-patterns

- **Don't `gh pr merge --merge`** when the project squashes — creates noise on
  master. Use `--squash` to match the project's convention.
- **Don't bypass CI with `--admin`** unless CI is genuinely broken in a way that
  isn't your fault. The bot review pass is a sanity check, not just bureaucracy.
- **Don't reply "no it's fine" to a P1 finding without evidence.** If you reject
  it, link to the specific code/test that disproves the concern.
- **Don't pile up multiple `@codex review` comments.** One ping is enough; spam
  doesn't move the bot faster and clutters the PR.
- **Don't merge while the bot is mid-review** (the boilerplate review is in
  `state: COMMENTED` but no line comments yet, less than 30 min after a fresh
  push). Findings often arrive in a second wave.
- **Don't use the PR as your first reviewer.** Opening a rough diff to "see what
  the bot says" spends 5–30 minutes per round on findings a local review would
  have handed you in one, and every round costs a force-push that resets the
  bot's SHA anyway.
- **Don't let the local reviewer become an extra ratchet.** It hunts defects, so
  it will always find *something* to add. Apply the same over-specification test
  you'd apply to a bot finding: if skipping it breaks nothing real, skip it.

## Reference: real PR examples from this session

| PR | What happened | Lesson |
|---|---|---|
| #186 | Small schema fix; bot reacted `+1` 4 min after merge (raced) | Reaction is the signal; check it before merging |
| #187 | 9ni.8.5 reconciliation; bot left review wrapper, no findings, no reaction in window | Sometimes the bot doesn't react at all on substantial PRs; line comments are then the source of truth |
| #189 | Issue #188 first attempt; bot left findings, addressed; final reaction `+1` | Standard happy-path flow |
| #190 | 9ni.8.6 parsimonious-creation; CI failed on rebase clippy, fixed with amend, second pass green; bot `+1` | Rebase before squash to catch lint regressions |
| #191 | README docs; bot reacted `+1` 13 min before I merged but I didn't check | I was looking at the wrong API; reactions are cheap |
| #192 | force-complete amendment loss; bot found P2 about empty-amendment status text → fixed → `+1` | P2 still worth addressing |
| #193 | Issue #188 reopen attempt; bot pass-2 found P1 about retry session; addressed → `+1` | Saw "addressing P1 introduces new P1" |
| #194 | `contains` injection; bot's two rounds both flagged subschema issues, merged anyway, then OpenAI rejected the schema in production → reverted | Bot can't catch what local tests don't catch; reality bites |
| #195 | Revert + replacement (codex-only enum narrowing), CI flake on rerun → green; bot `+1` | Distinguish flake from regression |
| #196 | Drop `--output-schema` entirely (architectural fix); bot reacted `+1` 30 min after open; I almost waited another cycle for nothing | The reaction signal would have saved a cycle |
