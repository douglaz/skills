---
name: pr-with-codex-bot-review
description: >-
  How to open and land a pull request through GitHub's `chatgpt-codex-connector` review bot
  (the one that auto-comments "Codex Review" on PRs), gating also on `coderabbitai[bot]`
  when it is configured on the repo. Covers writing the PR body, running local gates, a
  local Claude pre-review before push so bot rounds start from the good diff, the
  codex bot's actual behavior — auto-fires on substantive code PRs, often silent on
  docs-only PRs, line-level findings live in PR review comments not the review body —
  re-triggering with `@codex review`, addressing findings via amend + force-push, knowing
  when to merge despite bot silence, and the squash-merge + branch-reset pattern. THE
  MERGE DECISION IS MADE BY THE BUNDLED `scripts/bot-gate`, NOT BY JUDGMENT — run it and
  quote its output; the manual reaction-and-comment procedure it replaced is gone, and
  was wrong three different ways before it was. Use this skill whenever the user asks to
  open a PR, "ship this", "merge it", "let the bot review", "land the change", or right
  after substantial code work that's ready for review. Also when the user asks why the
  bot "isn't reviewing", how to interpret what it left behind, or what to do when GitHub
  itself is degraded and no review can be attributed to the tree being merged.
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

> **If you are recalling this procedure rather than reading it now, stop and re-read the
> on-disk `SKILL.md` first.** The merge decision moved out of prose and into
> **`scripts/bot-gate`**. A copy of this skill loaded earlier in a session — or carried
> through a context summarisation — may still describe the manual procedure it replaced:
> `gh api .../reactions`, `gh api .../pulls/N/comments`, judge by hand. Following that
> from memory is not "a slightly older doc". `bot-gate`'s own header records that this
> logic *"was written three times as prose and was wrong three different ways"* — an
> unenforcing version, an unsatisfiable version, and one that broke past 100 comments —
> so remembered prose is one of three known-wrong gates. This has already cost a real
> merge: a PR landed on a `+1` and a human-pasted approval while the only wrapper the API
> held named the **parent** of the merged head. The gate would have blocked it; it was
> never run.
>
> The countermeasure is in § 8: a merge report must **quote `bot-gate`'s output**. An
> agent that skipped the gate cannot produce that quote, which is the point.

## When this applies

The bot is `chatgpt-codex-connector[bot]` on GitHub. It runs as part of OpenAI's Codex
GitHub integration: pulls each PR diff, runs a Codex review pass against it, leaves a
boilerplate "💡 Codex Review" pull-request review plus zero or more **line-level review
comments** carrying the actual findings. It triggers automatically on PR open, on draft
mark-ready, and on `@codex review` comments (per the bot's own boilerplate).

Use this skill when you're about to open a PR, just opened one and are wondering why
the bot is quiet, or got findings back and need to address them.

## What "the bot reviewed" actually means on GitHub

The bot communicates approval and findings through **four distinct channels**, all on
the same PR:

1. **Reaction on the PR body** — `eyes` (👀) when the bot picks up the PR for review,
   `+1` (👍) when it approves with no concerns. Check it before assuming silence:

   ```bash
   gh api repos/<owner>/<repo>/issues/<N>/reactions \
     | jq '.[] | select(.user.login == "chatgpt-codex-connector[bot]") | {content, created_at}'
   ```

   The bot's own boilerplate says it reacts 👍 when it has nothing to report. **Do not
   build anything on that.** Measured across 19 rounds on this repo's PR #16, `+1` fired
   **zero** times — it appears only on a round that finds nothing, and this PR never had
   one. A gate that waits for it waits forever.

   **That sample contained no clean rounds, so it could not show what one looks like.**
   The conclusion drawn from it — that the clean case leaves nothing usable — was false,
   and it shaped a gate that could not pass on success. A clean round posts the § 3
   comment, which carries the sha. Gate on that; the reaction stays worthless because a
   reaction has no sha.

   **And when it does appear it approves the tree the bot read, which is not always the
   tip.** The reaction has a timestamp and no SHA, so after a force-push a surviving `+1`
   from the previous head looks identical to a fresh one — and GitHub allows one reaction
   per user per item, so the bot cannot refresh it even if it wanted to. Treat `eyes` as
   evidence a round is *running* and `+1` as evidence of nothing; § 7 has the check that
   establishes which tree was read.

2. **Pull-request review** with `state: COMMENTED` — usually just boilerplate:

   ```
   ### 💡 Codex Review
   Here are some automated review suggestions for this pull request.
   **Reviewed commit:** `<sha>`
   ```

   The body of this review carries no findings. It's a wrapper that anchors the
   review to a specific commit SHA.

3. **Issue comment on a CLEAN round** — when the bot finds nothing it posts **no
   pull-request review at all**. It comments on the issue thread instead:

   ```
   Codex Review: Didn't find any major issues. 👍
   **Reviewed commit:** `523eb0fee9`
   ```

   ```bash
   gh api repos/<owner>/<repo>/issues/<N>/comments \
     --jq '.[] | select(.user.login=="chatgpt-codex-connector[bot]") | .body'
   ```

   **This is SHA-bearing evidence**, and it is the only proof a clean round leaves that
   names a tree. The sha is abbreviated, so match it as a prefix of the tip. Reading only
   `pulls/<N>/reviews` makes success indistinguishable from a stalled bot — see § 7.

4. **Line-level review comments** — where actual findings live, separate API:

   ```bash
   gh api repos/<owner>/<repo>/pulls/<N>/comments      # actual findings
   ```

When checking whether the bot has weighed in, reactions are the cheapest signal to read —
but they are not a completion signal, and § 7 explains why you must not treat one as
approval of the current head. Line comments carry the findings, if any. Findings are
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

   `SUCCESS` is not the same as "reviewed", and there are two different ways it can lie.

   **A rate limit or a paused review means nobody reviewed anything.** The check is green
   because CodeRabbit never ran. `bot-gate` prints that and does **not** block on it — it
   stopped gating on CodeRabbit entirely (ADR 0004), so this is information for you, not a
   wait state. `@coderabbitai resume` (it auto-pauses on fast-moving branches) or
   `@coderabbitai review` if you want its opinion before merging.

   **A "Files skipped from review" list is a narrower claim**: CodeRabbit ran, judged some
   files trivial or similar to previous changes, and did not read them. Every file on that
   list is one this PR touches — it cannot skip a file the PR does not change — so do not
   go looking for whether the skip "covers files central to the change" as a gating test;
   that question can only be answered by reading it.

   ```bash
   gh api repos/<owner>/<repo>/issues/<N>/comments \
     --jq '.[] | select(.user.login == "coderabbitai[bot]") | .body' \
     | grep -A20 -i 'skipped from review'
   ```

   `bot-gate` prints this list and does not block on it: gating on it is equivalent to
   blocking on every skip, which deadlocks. It is a vendor's judgement call, so read it and
   re-trigger if you disagree. Say which reason applied; "the check was green" is not a
   review.

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

A Claude reviewer at high effort is the default local reviewer here: it reads the
repo around the diff, so it catches the out-of-diff callers and siblings the bots
routinely miss.

Resolve `$CLAUDE_MODEL` with the ladder probe in
[multi-reviewer-loop/references/reviewer-panel.md](../multi-reviewer-loop/references/reviewer-panel.md)
§ Resolving the Claude reviewer's model. It matters more here than anywhere else in
this skill, because this reviewer is optional: an unreachable model produces no
findings and no stderr, which is byte-identical to a reviewer that found nothing —
and the next step in this section is a PR body claiming a pre-review happened.

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
  --model "$CLAUDE_MODEL" --effort high --output-format json \
  --tools "Bash,Read,Glob,Grep" --allowedTools "Bash,Read,Glob,Grep" \
  --disallowedTools "Edit,Write,NotebookEdit" \
  >"$RD/claude.json" 2>"$RD/claude.stderr"
CLAUDE_RC=$?

jq -er 'if .is_error then error(.result // "reviewer returned is_error")
        else (.result // empty) end' \
  <"$RD/claude.json" >"$RD/claude.txt"
JQ_RC=$?
```

**Check both exit codes before believing the output.** `CLAUDE_RC != 0` or
`JQ_RC != 0` means the review never ran — auth, rate limit (429), overload
(529), or an unreachable model — and `$RD/claude.txt` will be empty. Do not pipe this straight
into `tee` and read the file: a failed reviewer and a clean reviewer both leave
you with no findings on stdout, and the difference is the whole point. The clean
signal is exit 0 plus exactly `No findings.`; empty output with exit 0 is
ambiguous, not clean.

If it failed, re-run it on the next ladder model, or open the PR without a
pre-review — but do not tick the pre-review line in the PR body. Claiming a review
that never ran is worse than not running one. The same goes for *which* reviewer:
name the model in the body, since "a local review ran" and "Fable reviewed it" stop
being the same sentence the moment the ladder falls through.

There is no `timeout` in the block above and this is the one place in the repo where
that is deliberate — it is a foreground, interactive step, so a hang is visible to
you rather than silent. If you background it or script it, bound it like every other
reviewer invocation.

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
- [x] Local review (claude/<model>, high effort): <N findings addressed / clean>
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

### 5. Wait for the bot to finish a round

Read the reaction as a **one-way** signal, and only in one direction: a fresh `eyes` means
a round is running, so wait. Its **absence means nothing** — the bot may never react at
all, and on this repo's PR #16 `+1` fired zero times across 19 rounds. Treating "no
reaction" as "not picked up" and waiting or retriggering is how landing stalls forever,
because the state you are waiting for may never arrive.

What actually advances the decision is the review wrapper naming the tip and `bot-gate`'s
verdict (§ 7). Don't fall back to "wait some minutes and assume" either — but check the
reaction to see whether to *hold*, not whether to *go*:

```bash
gh api repos/<owner>/<repo>/issues/<N>/reactions \
  | jq -r '.[] | select(.user.login == "chatgpt-codex-connector[bot]") | "\(.content) at \(.created_at)"'
```

| Reaction | Meaning | Action |
|---|---|---|
| (empty) | **Unknown.** The bot may not have started, or may have finished a round and simply not reacted — measured, `+1` fired zero times in 19 rounds | Go to § 7. Do not wait and do not retrigger: the signal you would be waiting for may never arrive, and a retrigger just starts a duplicate round |
| `eyes` | Bot is reviewing | Wait — this is the one row that means hold |
| `+1` | Bot approves with no concerns — **of the tree it read**, which is not always the tip | Go to § 7; do not merge from here |

Typical bot timing: 5-30 minutes from open. It does sometimes react on docs-only or tiny
PRs — `+1` landed on PR #191's pure-docs change about 20 minutes after open. Do not read
that as "wait longer and one will come": later measurement found `+1` firing **zero** times
across 19 rounds on PR #16, so no waiting period reliably produces one. The #191
observation is real; the rule once drawn from it — that silence only means impatience — is
not, and it is why § 7 decides on the wrapper instead.

To explicitly trigger or re-trigger (after a force-push, or if the bot appears
stuck):

```bash
gh pr comment <N> --body "@codex review"
```

After a force-push, the bot's prior review names the old SHA (and its reaction names
nothing at all). The
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
  test serves as a counter-claim if the bot raises the same concern next round — but
  only if it can fail. **Invert the fix and watch that test go red before you push**,
  then revert the inversion. A test written for "the bot found X" that also passes
  against X is not a counter-claim, it is a green check that proves nothing, and the
  bot cannot tell the difference on the next round. Three conditions on that red run,
  the same ones the testing skills enforce:
  - **Read the failure.** It must name the assertion pinning the behavior you inverted,
    not an unrelated panic or an initialization error.
  - **Preserve the fix before inverting it.** Your fix and its regression test are
    uncommitted and often in the same file, so a file-level `git restore` to undo the
    mutation discards both — and the green re-run then passes *because* the test that
    would expose the loss went with it, after which you amend and push the pre-fix tree.
    Save the patch or mutate in a scratch copy, and verify the restored tree against it.
  - **Then restore the fix and watch it go GREEN.** The red run alone is satisfied by a
    test that always fails or that its own cleanup broke, and a manual or live gate the
    ordinary CI suite never executes would carry that all the way to merge.
  - **One mutation per property.** A regression test answering a finding that had two
    parts needs two — reddening the first leaves the second untested while looking
    verified.
  - **Isolate it if the test touches anything live.** A regression test for a
    money-path or data-loss finding may drive a real database, service, or balance, and
    the inverted build can perform the harmful operation before the assertion notices.
    Disposable environment, non-destructive mutation, or say plainly that the red run
    could not be done safely — never a broken build against live state.
- **Cite the finding in the commit message.** Future readers (and the next bot
  review) need to know which feedback this commit addressed. Use a phrase like
  "Addresses codex-review #194 P1 (first round)" — round number matters when the bot
  re-reviews after force-push.
- **Amend, don't stack commits, for one-shot fixes.** Cleaner squash-merge history.
  `git commit --amend --no-edit` then `git push --force-with-lease`. For larger
  follow-ups, separate commits are fine — the squash absorbs them.

### 7. Decide based on the wrapper, not on time

Merge when the **wrapper**-based check passes — the reaction is corroboration, never the
condition:

- The codex bot has finished **this** round on **this** head. The reaction carries no
  SHA, only a timestamp, so it cannot establish that by itself; the review wrapper carries
  the SHA (`**Reviewed commit:** <sha>`) and is what binds the review to the tree.

  (Do not substitute a git timestamp for this. `git log -1 --format=%cI` is the commit's
  authored/amended time, not when it was pushed, so an amended commit can predate an old
  reaction and the comparison proves nothing.)

  ```bash
  # the wrapper for THIS head, and when it landed. Match `.commit_id` — the API's own
  # 40-char SHA — not seven hex characters scraped out of the body: 28 bits collides in a
  # large history and can be ground out deliberately, letting a stale wrapper stand in as
  # approval of the current tree.
  gh api --paginate --slurp repos/<owner>/<repo>/pulls/<N>/reviews \
    | jq -r --arg tip "$(git rev-parse HEAD)" '
        [.[][] | select(.user.login=="chatgpt-codex-connector[bot]" and .user.type=="Bot")
         | select(.commit_id==$tip)] | last | .submitted_at'
  # the +1 specifically — not `eyes`, which means the round is still running
  gh api repos/<owner>/<repo>/issues/<N>/reactions \
    --jq '.[] | select(.user.login=="chatgpt-codex-connector[bot]" and .user.type=="Bot")
          | select(.content=="+1") | .created_at'
  ```

  **The wrapper is the gate; the `+1` only corroborates.** Do not require the `+1` to
  post-date the wrapper — measured on a 7-round PR, the bot left **6 wrappers and zero
  reactions**, because `+1` appears only on a round it finds nothing in. GitHub also
  allows one reaction per user per item, so a `+1` from an earlier clean round may persist
  with its original `created_at` and never refresh. Requiring a fresh `+1` deadlocks both
  cases.

  What must hold before merging:

  1. A wrapper exists whose `Reviewed commit:` equals the tip. That is the bot stating,
     with a SHA, which tree it read.
  2. Run **`scripts/bot-gate <PR>`** and require exit 0. Six conditions: a *submitted* codex
     review naming this tip; no PENDING review from the bot on it (a rerun in flight); no
     `@codex review` request left unanswered — one newer than the wrapper has not reported,
     and one older than it only counts as answered when a completed round separates it from
     any earlier round-start (a trigger comment, a mark-ready, a head force-push since the
     bot often re-reviews a push, or a dated `eyes` reaction, which marks the moment a
     round began), because rounds carry no identity and the wrapper after a request can
     otherwise be an already-running round's submission — round *ends* are the bot's
     submitted wrappers on any commit, not just the tip's, EXCEPT when clearing a base
     mutation, where only a wrapper naming the current tip may anchor the gap: a prior-tip
     anchor implies a push since, and a normal push starts an automatic round that emits no
     timeline event at all, so the interval it would certify as quiet can contain exactly
     the round whose wrapper is then credited to the request; no `eyes` reaction
     post-dating the wrapper; no base mutation not followed by such a provably-fresh
     review request (the whole `base_ref_*` / `automatic_base_change_*` family; submission
     time alone cannot prove whether the bot read the diff before or after an in-flight
     mutation), and no `ready_for_review` event newer than the wrapper or unattributable to
     the wrapper that followed it — marking ready starts a round, so an older ready clears
     only when the PR was provably quiet at that moment (a first-ever mark-ready on a
     born-draft PR qualifies) or a later provably-fresh request completed; and zero
     unresolved review threads from either gated bot. It fails closed on any API error,
     missing tool, or unparseable response in the signals that feed all six — the timeline
     query behind the retarget check included. What the round-start list cannot see — a
     non-force push, and the round a non-draft PR starts at creation — is a documented
     residual: a push-started round reads the pushed tree itself, so the leak it permits is
     a duplicate round on an already-read diff.

     **CodeRabbit's status is not one of them, deliberately.** It is a PR-level signal — it
     lands on whatever head exists when the bot posts it and carries nothing binding it to
     a tree. Measured here: CodeRabbit auto-paused this PR and then stamped
     `success`/"Review completed" on a commit 75 seconds after it was pushed, with none of
     its comments anchored there. The gate prints its state, its rate-limit and paused
     markers, and its skipped-files list, and lets you decide. Its review *threads* still
     gate, because those are head-anchored and carry disposition. See ADR 0004.

     **Know what exit 0 claims, because it is weaker than "the bots cleared this."** The
     verdict is `NO_PENDING_EVIDENCE`, and it means: across API reads finishing at a
     reported time, nothing indicated an unfinished round on this tip or an undispositioned
     bot finding on it. That is an inference from absence. Neither bot emits a
     round-terminal signal — measured across 19 rounds on this repo's PR #16, the codex
     bot's review state is always `COMMENTED`, never `APPROVED`, and its `+1` fired zero
     times — so there is no field that says "done" and no query that can synthesize one.
     The honest primitive would be a bot-owned CheckRun bound to `head_sha` with
     `status=completed`, made a required check; neither bot emits one.

     So treat this as a stop sign, not a green light: it tells you when to wait, and a
     human still owns the merge. **Where the forge can enforce a rule server-side — required
     status checks, required conversation resolution — put it there instead.** Those are
     decidable; this is not, and a rule in branch protection cannot be skipped by forgetting
     to run a script.

     Resolve it from the installed skill directory, the same way `drive` resolves
     `drive-status` — skill commands run from the *driven* repo, which has no
     `scripts/bot-gate`, so a bare relative path fails with "No such file or directory"
     and blocks LAND:

     ```bash
     for d in "$HOME/.claude/skills/pr-with-codex-bot-review" \
              "${CODEX_HOME:-$HOME/.codex}/skills/pr-with-codex-bot-review" \
              "$HOME/.agents/skills/pr-with-codex-bot-review"; do
       [ -x "$d/scripts/bot-gate" ] && { BOT_GATE="$d/scripts/bot-gate"; break; }
     done
     # Guard the resolution. Unset, `"$BOT_GATE" 42` runs an empty command and its non-zero
     # status reads as "the gate blocked this PR" when the gate was never found.
     [ -n "${BOT_GATE:-}" ] || { echo "bot-gate not found — see below"; exit 1; }
     "$BOT_GATE" 42 || exit 1
     ```

     If none resolve you are running from a checkout: invoke it by its path there.

     **Do not chain this straight into `gh pr merge`.** It is tempting — `bot-gate 42 &&
     gh pr merge 42 …` — and it merges on a condition the gate never checked: the gate
     reasons about the *head*, and says nothing about whether the base branch advanced
     while the bot rounds were running. A behind branch squash-merges into a composition
     no reviewer saw. § 8 is the merge sequence and it checks that; run it, don't inline a
     shorter version of it here.

     `scripts/bot-gate.test` runs it against a stubbed `gh` with canned API responses —
     one case per defect a reviewer actually found — the suite prints its own count, so
     it is not repeated here to go stale: a forged wrapper
     login, a `[bot]`-suffix filter that matched nothing, an unrelated app's unresolved
     thread holding the merge, a CodeRabbit rate-limit skip, an API failure. Run it after
     touching the gate; every case has been shown to go red against the real bug.

     **Two clauses were deliberately removed. Do not restore them without new evidence.**

     - A *settle window* — sample the unresolved count, sleep 120s, sample again, require
       the wrapper to have aged past the window. It defended against the wrapper landing
       before its own line comments, which was then measured not to happen: on PR #16 every
       round's comments carry the wrapper's timestamp to within a second. The bot submits a
       round atomically, and the apparent gap was an artifact of polling two endpoints in
       sequence. No finite window can exclude a later comment anyway, so it was never a
       proof — only a two-minute delay that felt like one.
     - An *intersection of CodeRabbit's skip list against the changed files*. A "Files
       skipped from review" list enumerates files of the PR being reviewed, by construction;
       CodeRabbit cannot skip a file the PR does not touch. So the intersection was
       non-empty whenever a skip existed — identical to the blanket "any skip blocks" rule
       that had deadlocked every permitted skip — and the only way to empty it was a
       truncated changed-files response, i.e. the fail-open direction. The skip list is now
       printed and not gated.

     It is a script, not a snippet here, because this logic was written three times as
     prose and was wrong three different ways: it enforced nothing (a trailing `echo`
     returns 0), then it was unsatisfiable (counting every comment on the tip never
     reaches zero — § 6 tells you to *answer* a misread finding, and both it and your
     reply stay anchored), then it broke past 100 comments (`--paginate` with `--jq`
     emits one result per page). Shell embedded in documentation cannot be run, so none
     of those were caught by reading.

     Exit codes:

     | Code | Verdict | Means |
     |---|---|---|
     | 0 | `NO_PENDING_EVIDENCE` | not clearance — see above |
     | 1 | `BLOCKED` | a conjunct is unmet; usually **wait** |
     | 2 | — | usage error |
     | 3 | — | cannot determine, and that is never clearance |
     | 4 | `BLOCKED_UNATTRIBUTED` | a round finished; nothing says which tree it read |

     **Exit 4 refuses the merge exactly as 1 does** — any caller doing `bot-gate <PR> &&
     gh pr merge` is unaffected. It exists for a caller that *loops*: exit 1 usually means
     wait, exit 4 means waiting **may** not help, because the signal that would attribute
     the round is the one that is missing. It fires only when every other conjunct already
     holds, the bot's `+1` post-dates the tip's commit, and no `eyes` reaction is at or
     after that `+1`. Per the bot's own about-box — *"if Codex has suggestions, it will
     comment; otherwise it will react with 👍"* — a 👍 is a completed round, attached to
     the PR and never to a commit. A 👍 older than the tip provably belongs to an earlier
     tree and leaves a plain exit 1. See § 8b.

     **Try `@codex review` before treating exit 4 as an outage.** Three honesty notes:

     - **The bound is a lower one, and it admits a false positive.** The honest boundary is
       when the tip became the PR head, and nothing reports that — GitHub's timeline
       carries `head_ref_force_pushed` but not an ordinary push, the same gap the
       round-start list already documents. So: commit locally, the bot thumbs the *old*
       remote head, then you push. The 👍 survives (one reaction per user per item, so the
       bot cannot refresh or remove it) and satisfies the comparison though nothing read
       this tip. It is kept because the failure is one-directional — it can only turn a
       block into a differently-worded block — and § 8b's first instruction, confirm a real
       incident on the status page, is exactly what disproves it.
     - **It has never met live traffic.** Derived from the bot's documented contract, not
       from an observation here: this repo's own 19-round sample on PR #16 saw the `+1` fire
       zero times.
     - **A failed reactions read leaves the plain exit 1**, not 3. The reaction can only
       make an already-blocking answer *more specific*, so refusing a decidable PR because a
       warning could not be refined would be the wrong trade.

     `--no-coderabbit` is gone, and rejected as an unknown option with exit 2 rather than
     accepted and ignored. It existed to assert a fact no query could establish — whether
     the app is installed at all, given it can be enabled org-wide with no repo config and "absent"
     looks identical to "not started yet" on a fresh PR. Nothing depends on that fact now.

     A `BLOCKED` with `wrapper 0` used to be explained as "a clean round signalled with
     only a `+1`, so nothing proves which tree it read". That was **wrong**, and the advice
     that followed from it ("get a wrapper with `@codex review`") could never work: a
     re-run on a clean tree produces another clean round, which again posts no review
     object. A clean round DOES leave SHA-bearing evidence — the issue comment in § 3 — and
     the gate reads both channels now. If `wrapper 0` persists, the bot genuinely has not
     reported on this tip.
  3. If a `+1` exists, it is consistent with (1) and (2); if it does not, that is normal
     on a PR the bot has ever had findings on, and is not a reason to wait.

  Filter reactions on `content=="+1"` when you do read them: a fresh `eyes` means the bot
  is *still reviewing*, and an unfiltered query counts it as approval-shaped activity.

  Then pin the merge to **the tip this gate just checked** — § 8 captures it from the
  gate's own JSON. Re-reading `git rev-parse HEAD` at merge time looks equivalent and is
  not: it re-adopts whatever is current, so an amend landing in between gets pinned to
  itself and GitHub *accepts* it. The pin only guards when it names the reviewed tree.
- CI is green.
- CodeRabbit's status is **read, not required** — the gate does not act on it. A `SUCCESS`
  beside a rate-limit or paused marker means nobody reviewed anything, and the gate prints
  that rather than blocking, because its green says nothing about this tree either way.
  If you want its opinion on what you are about to merge, `@coderabbitai resume` (it
  auto-pauses on fast-moving branches) or `@coderabbitai review`, and wait for comments
  anchored to this head.
  A "Files skipped from review" list is different: it names files CodeRabbit judged
  trivial and chose not to read. The gate prints that list and does not block on it —
  read it and disagree if you want to, but it is a vendor's judgement call, not a failure.
  Absent from the rollup entirely is reported and nothing more. It used to block until the
  operator asserted `--no-coderabbit`, because on a fresh PR "absent" and "installed but
  not started yet" are indistinguishable — a real problem that stopped mattering once the
  status stopped counting.
- No unresolved review threads from **either gated bot** — `chatgpt-codex-connector` or
  `coderabbitai`. Not "any account GitHub types as a Bot": counting those let an unrelated
  app hold the merge over something this skill has no opinion about, with no way for the
  author to clear it.

Don't merge when:

- Codex bot reaction is `eyes` (still reviewing) — wait, even if CI is green.
- Codex bot has unaddressed line comments (`P0`/`P1`/`P2`/`P3`) referencing the current head.
- No wrapper for the current tip yet — `@codex review` to wake it up. (A missing *reaction*
  is not itself a blocker; see the merge conditions above.)
- CodeRabbit left unresolved review threads on the current head — those DO gate, because
  a thread is head-anchored and carries your disposition.
- (CodeRabbit's *status* — `PENDING`, `FAILURE`, or a `SUCCESS` nobody earned because it
  was rate-limited or paused — does **not** gate, and is not on this list. It is a
  PR-level signal that lands on whatever head exists when the bot posts it, so waiting on
  it can deadlock a PR that is otherwise ready: on a repo where CodeRabbit stays paused,
  that wait never ends. `bot-gate` prints the state; you decide. ADR 0004.)
- CI failed and you haven't determined whether it's flaky or real.
- You force-pushed and no wrapper names the new tip yet — wait, or `@codex review` (and
  `@coderabbitai review`) to re-trigger. Reactions carry no SHA, so the wrapper is the
  only thing that can tell you which tree was read.

**The wrapper is what matters; clock-time waits are a code smell that suggests you're
ignoring the actual signal.**

### 8. Squash-merge and clean up

```bash
# Two checks, because a FAILED `git status` also prints nothing: a corrupt index would
# read as a clean tree, in the merging direction.
_ST=$(git status --porcelain) || { echo "cannot read the worktree — do NOT merge"; exit 1; }
[ -z "$_ST" ] || { echo "tree dirty — do NOT merge"; exit 1; }
# Resolve by matching HEAD, not by preferring the parent. A fork can host its own PRs, and
# both repos can carry PR number N — so parent-first targets a missing or unrelated PR and
# the real one can never be landed. `bot-gate` resolves the same way for the same reason.
# BOTH matching is ambiguous, not a tiebreak: the same branch can be opened as a PR against
# the parent AND the fork, and the two PRs were gated separately — silently merging the
# parent's can land a PR whose reviews nobody checked. Refuse and make the caller say
# which repo.
# Guarded, because a failed lookup is not an answer: an unguarded SELF empties the loop's
# only sure candidate, and a failed parent lookup silently reads as "not a fork" — dropping
# the very candidate whose second PR the ambiguity refusal below exists to catch.
SELF=$(gh repo view --json nameWithOwner -q .nameWithOwner) \
  || { echo "cannot resolve this repository — do NOT merge"; exit 1; }
UP=$(gh repo view --json parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else "" end') \
  || { echo "cannot resolve the fork parent — a PR there would be invisible; do NOT merge"; exit 1; }
# "No such PR" and "the query failed" share an exit code, so absence is read out of gh's
# own error text; any other failure may be hiding the second match. bot-gate makes the
# same split, but this loop picks the repo the MERGE targets, so it cannot lean on that.
# PullRequest-level not-found only: both candidates are repos the API just named, so a
# Repository-level "could not resolve" or an HTTP 404 is lost access, not absence.
_GH_ERR=$(mktemp); trap 'rm -f "$_GH_ERR"' EXIT   # both scripts do this; the snippets leaked it || { echo "mktemp failed"; exit 1; }
R=""; _M=0
for _c in ${UP:+"$UP"} "$SELF"; do
  if ! _h=$(gh pr view <N> -R "$_c" --json headRefOid -q .headRefOid 2>"$_GH_ERR"); then
    grep -qiE 'could not resolve to a pullrequest|no pull requests found' "$_GH_ERR" \
      || { echo "cannot query PR <N> in $_c — absence not established; do NOT merge"; exit 1; }
    _h=""
  fi
  if [ "$_h" = "$(git rev-parse HEAD)" ]; then
    _M=$((_M+1)); [ -n "$R" ] || R="$_c"
  fi
done
[ "$_M" -le 1 ] || { echo "PR <N> matches this head in BOTH $UP and $SELF — ambiguous; re-run with the intended repo pinned in every -R"; exit 1; }
[ -n "$R" ] || { echo "no PR <N> whose head is this tree in ${UP:+$UP or }$SELF"; exit 1; }
PR_REFS=$(gh pr view <N> -R "$R" --json baseRefName,headRefName) \
  || { echo "cannot resolve the PR branches"; exit 1; }
BASE=$(printf %s "$PR_REFS" | jq -r '.baseRefName // ""')
HEAD_BRANCH=$(printf %s "$PR_REFS" | jq -r '.headRefName // ""')
[ -n "$BASE" ] && [ -n "$HEAD_BRANCH" ] \
  || { echo "cannot resolve the PR branches"; exit 1; }

# Check the exit status. `--delete-branch` makes gh switch branches as a side effect, so a
# FAILED merge still leaves you somewhere plausible-looking; without this the steps below
# "confirm $BASE is healthy" on a tree where nothing landed, and any caller that closes a
# tracker item after this block closes it for a merge that never happened.
# $REVIEWED_TIP is the SHA bot-gate checked in § 7, not a fresh `git rev-parse HEAD`.
# Re-reading HEAD here re-adopts whatever is current — a late amend or concurrent
# automation that pushed after the gate returned — and pins the merge to that, so GitHub
# ACCEPTS the unreviewed head instead of refusing it. The pin is only a guard if it names
# the tree that was actually reviewed.
# Run the gate and REQUIRE its exit status. A command substitution swallows it: bot-gate
# prints its JSON — `tip` included — before exiting 1 on BLOCKED, so `$(... | jq -r .tip)`
# yields a perfectly good SHA from a run that said do not merge, and jq's own exit 0 hides
# it. An amend landing between § 7 and here then produces a BLOCKED gate whose tip is the
# new head, the equality check compares the new head to itself and passes, and the merge
# takes the unreviewed tree — the exact outcome this pin exists to refuse.
# Re-resolved here: this block re-derives $R and $BASE so it can run standalone, and an
# unset $BOT_GATE would execute an empty command and report "do NOT merge" for a gate that
# was merely not found.
for d in "$HOME/.claude/skills/pr-with-codex-bot-review" \
         "${CODEX_HOME:-$HOME/.codex}/skills/pr-with-codex-bot-review" \
         "$HOME/.agents/skills/pr-with-codex-bot-review"; do
  [ -x "$d/scripts/bot-gate" ] && { BOT_GATE="$d/scripts/bot-gate"; break; }
done
[ -n "${BOT_GATE:-}" ] || { echo "bot-gate not found — resolve it as in § 7"; exit 1; }
GATE_JSON=$("$BOT_GATE" <N> --json) || { echo "bot-gate says do NOT merge"; exit 1; }
[ "$(printf %s "$GATE_JSON" | jq -r .verdict)" = "NO_PENDING_EVIDENCE" ] \
  || { echo "gate verdict is not NO_PENDING_EVIDENCE"; exit 1; }
REVIEWED_TIP=$(printf %s "$GATE_JSON" | jq -r .tip)
# The forge's own clone URL, not a hardcoded github.com one. `$R` is only `owner/repo`,
# so on GitHub Enterprise the literal host either fails or — worse — resolves an unrelated
# PUBLIC repo of the same name and validates ancestry against a stranger's branch.
R_URL=$(gh repo view "$R" --json url -q .url 2>/dev/null) \
  || { echo "cannot resolve the clone URL for $R — do NOT merge"; exit 1; }
R_URL="$R_URL.git"
# Fetch the base AFTER the potentially slow bot gate. Fetching it before the API sweep lets
# the merge target advance during the gate, making the ancestry result stale at merge time.
git fetch "$R_URL" "+refs/heads/$BASE:refs/remotes/upstream/$BASE" \
  || { echo "cannot fetch the merge target — base unknown, do NOT merge"; echo "  (on a private repo cloned over SSH this is usually missing git credentials for https, not a missing base)"; exit 1; }
git merge-base --is-ancestor "refs/remotes/upstream/$BASE" HEAD \
  || { echo "REBASE FIRST — $BASE advanced since the review"; exit 1; }
[ "$REVIEWED_TIP" = "$(git rev-parse HEAD)" ] \
  || { echo "local HEAD moved since the gate ran — re-run § 7"; exit 1; }
# LAST, immediately before the merge. Ancestry answers "did $BASE advance"; it cannot
# answer "is $BASE still the target". A RETARGET points the PR at a different branch
# entirely: $BASE then names the old one, everything above validates that one, and
# `gh pr merge` squashes onto whatever the PR points at now — with the head unmoved, so
# --match-head-commit stays satisfied. Read it here rather than beside the gate because
# every check between the read and the merge widens the window. The window is not zero and
# cannot be: GitHub offers no base pin to match --match-head-commit. It is now one API call
# wide instead of a fetch plus two checks, and a retarget is one click.
BASE_NOW=$(gh pr view <N> -R "$R" --json baseRefName -q .baseRefName) \
  || { echo "cannot re-read the merge target — do NOT merge"; exit 1; }
[ -n "$BASE_NOW" ] && [ "$BASE_NOW" = "$BASE" ] \
  || { echo "the PR was retargeted ($BASE -> ${BASE_NOW:-unknown}) — the panel reviewed a diff against $BASE; re-run § 7"; exit 1; }
gh pr merge <N> -R "$R" --squash --delete-branch --match-head-commit "$REVIEWED_TIP" \
  || { echo "merge did not land — do NOT proceed"; exit 1; }

# `gh pr merge` returning 0 means the PR was accepted for merging — which, in a repo with a
# required merge queue, means ENQUEUED, not landed. Fetching now would read the still-old
# base and any caller that closes a tracker item here would close it for a merge that has
# not happened. Wait for the state to actually reach MERGED.
_n=0
while [ "$_n" -lt 60 ]; do
  _n=$((_n+1))
  _ST=$(gh pr view <N> -R "$R" --json state -q .state 2>/dev/null || echo "")
  [ "$_ST" = "MERGED" ] && break
  [ "$_ST" = "CLOSED" ] && { echo "PR was closed without merging"; exit 1; }
  sleep 10
done
[ "$_ST" = "MERGED" ] || { echo "PR still not merged (state=$_ST) — do NOT proceed"; exit 1; }

# Keep $GATE_JSON: the merge report has to QUOTE it (see below). Do not re-run the gate to
# produce the quote — the PR is merged by now, so a fresh run describes a different world.
printf '%s\n' "$GATE_JSON" > "${TMPDIR:-/tmp}/merge-evidence-<N>.json"

# Re-fetch after the merge: the ref above predates the squash commit. Reset from where the
# merge actually landed — `origin` is your fork and may not contain it at all. Fetch before
# checkout, because in a single-branch fork clone neither a local `$BASE` nor `origin/$BASE`
# exists, so `git checkout "$BASE"` fails and an unguarded reset then runs against whatever
# branch is still checked out.
git fetch "$R_URL" "+refs/heads/$BASE:refs/remotes/upstream/$BASE" \
  || { echo "cannot fetch the merge target"; exit 1; }
# `checkout -B` repoints the branch ref unconditionally, and a clean worktree does not
# protect COMMITTED work: a local bead closure or DRIVE.md update on $BASE awaiting its
# metadata PR — a state this skill's own LAND flow produces — becomes unreachable except
# via reflog. The exception is a same-name fork PR: local $BASE is the verified feature
# head, and a squash commit does not descend from it. Matching the reviewed OID distinguishes
# that head from later local-only commits, which must still stop the reset.
if git show-ref --verify --quiet "refs/heads/$BASE" \
   && ! git merge-base --is-ancestor "$BASE" "refs/remotes/upstream/$BASE"; then
  if [ "$HEAD_BRANCH" != "$BASE" ] \
     || [ "$(git rev-parse "refs/heads/$BASE")" != "$REVIEWED_TIP" ]; then
    echo "local $BASE has commits upstream does not — refusing to reset; push or rebase them first"
    exit 1
  fi
fi
# Re-check the worktree HERE, not only at the top of this block: the merge-queue wait
# above can run ten minutes, and `checkout -B` silently CARRIES any nonconflicting tracked
# modification made meanwhile onto the fresh base — the build below then "confirms" a tree
# that is not the branch tip. FULL status, untracked included: the top-of-block check ran
# BEFORE the wait, so it cannot vouch for a file created during it — and checkout does not
# remove an untracked file, so it sits in the "fresh" base worktree where the build and
# whatever branches from here inherit it, unreviewed and invisible to `-uno`.
_ST=$(git status --porcelain) || { echo "cannot re-read the worktree — not resetting"; exit 1; }
[ -z "$_ST" ] || { echo "worktree changed while waiting for the merge — resolve that, then reset to $BASE by hand"; exit 1; }
git checkout -B "$BASE" "refs/remotes/upstream/$BASE" \
  || { echo "cannot reset to the merge target — do NOT treat what follows as a check of it"; exit 1; }
nix build                                    # confirm the base is healthy
```

`--match-head-commit` takes the **full 40-char OID**, which is why the snippet pins
`$REVIEWED_TIP` from the gate's JSON: it is already the full SHA, and it is the tip the
gate actually checked. Do not substitute `git rev-parse HEAD` here — that re-reads the
current head, so an amend after the gate ran gets pinned to itself and merges unreviewed.
Nor the wrapper's body SHA, which may be abbreviated and would make every merge refuse
with no hint why.

Check before merging, and make it `exit 1` rather than print: a bare `git status
--porcelain` exits 0 either way, and `--delete-branch` makes `gh pr merge` switch branches
itself — so a dirty tree aborts *after* the squash has already landed. Stash if the change
matters; discard only after looking, because `git checkout -- .` is not recoverable.

`checkout -B` rather than `pull` because squash-merge rewrites history — the branch is
repointed at the merge target, not merged with it.

### 8a. The merge report must quote the gate

Whatever you report after merging — to the user, in a `DRIVE.md` entry, in a comment —
**quote `bot-gate`'s actual output**: the `verdict`, the `tip`, and the observation window.

```text
merged <N> at <REVIEWED_TIP>
gate: NO_PENDING_EVIDENCE  (observed 2026-08-06T20:43:04Z .. 2026-08-06T20:43:08Z)
```

This is not paperwork. It is the only part of the procedure an agent that **skipped the
gate cannot fake without lying outright** — every other step leaves an artifact the agent
could plausibly reconstruct after the fact, and "I checked the reactions and it looked
fine" is exactly the report that preceded the merge described at the top of this file. If
you cannot produce the quote, you did not run the gate, and the merge is unevidenced
regardless of how it turned out.

Report the verdict you actually got. `BLOCKED_UNATTRIBUTED` merged under § 8b is a
legitimate outcome to report; laundering it into `NO_PENDING_EVIDENCE` is not.

### 8b. When the forge itself is degraded

`bot-gate`'s first condition is *a wrapper exists whose reviewed commit equals the tip*.
During a GitHub incident that condition can be **unsatisfiable no matter how long you
wait** — not because the bot disapproves, but because the forge is not answering. Observed:
the checks rollup showed only CodeRabbit while two CI jobs never appeared at all, and the
review wrapper for the merged head never became visible, though one naming its *parent*
did.

**First, tell the two apart.** Waiting is the right move for one and useless for the other:

| Gate says | Means | Do |
|---|---|---|
| `BLOCKED`, wrapper 0, no other signal | the bot has not reviewed this tip | wait, or `@codex review` |
| `BLOCKED_UNATTRIBUTED` (exit 4) | a round *completed* — its 👍 post-dates the tip — but nothing says which tree it read | `@codex review` first; if no wrapper comes, go on |

Exit 4 is still a refusal. It changes what you do next, never whether the gate approved.
And it is not proof of an outage: the 👍 is sticky and bounded only by the tip's local
commit time, so it can also be an *older* head thumbed after you committed (§ 7). That is
precisely why the next step is to confirm the incident rather than assume it.

**Second, confirm it is actually an incident**, not a quiet bot. Check
<https://www.githubstatus.com> and say what you saw. "The wrapper is missing" is not
evidence of an outage; a degraded component on the status page, or CI jobs absent from a
rollup that should list them, is.

**Locally-run CI can substitute — with what it substitutes recorded.** Running the repo's
own gates yourself is strictly stronger evidence than a green check mark, because you
watched it. What makes it admissible is the record, and it must pin the tree:

- the **exact commands**, each with its real exit code (never piped through `tail`/`grep`)
- the **head SHA they ran against**, and that it equals the SHA you are merging — a local
  run on an earlier head proves nothing about the tree that lands
- **which jobs the forge would have run that you did not**, named

Local CI substitutes for **CI**. It does not substitute for the **review**, which is a
different claim: no local command tells you what a reviewer would have said.

**A human-relayed bot verdict is admissible only for the part you can check.** A pasted
*"Reviewed commit: `<sha>`"* is a claim about a message you cannot see — but the SHA in it
is verifiable against your local head, and a mismatch settles it immediately. So:
cross-check the SHA and say you did; treat the relay as evidence about **which tree** was
read, and the human as the party attesting that it was read at all. A relay with no SHA,
or one whose SHA does not match, advances nothing.

**Record it as a degraded merge.** Write down, in the report § 8a asks for: the gate's real
verdict and exit code, what you ran locally with which SHA, what the status page said, and
who attested to what. The failure this section exists to prevent is not merging during an
outage — that is sometimes correct — it is **improvising a merge policy during one and
leaving no trace of the trade you made.**

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

**Reactions look like the cheapest completion signal, and are not one.** The `+1` fired
zero times across 19 rounds on PR #16, and GitHub permits one reaction per user per item,
so an old one may never refresh. Evidence about *this* head is the § 7 check: a review
whose `.commit_id` equals the tip, with no unresolved threads from either gated bot. Do not
require the reaction to post-date anything — § 7 explains why that deadlocks.

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

These are observations from real PRs, kept as history. Where a lesson here reads as
advice about *reactions*, § 5 and § 7 supersede it: reactions were the doctrine when
these were written, and measuring 19 rounds later showed `+1` firing zero times. The
events are still accurate; the conclusions drawn from them at the time were not.

| PR | What happened | Lesson |
|---|---|---|
| #186 | Small schema fix; bot reacted `+1` 4 min after merge (raced) | The merge beat the round. A reaction cannot tell you this — it carries no SHA; § 7's wrapper check is what would have caught it |
| #187 | 9ni.8.5 reconciliation; bot left review wrapper, no findings, no reaction in window | Sometimes the bot doesn't react at all on substantial PRs; line comments are then the source of truth |
| #189 | Issue #188 first attempt; bot left findings, addressed; final reaction `+1` | Standard happy-path flow |
| #190 | 9ni.8.6 parsimonious-creation; CI failed on rebase clippy, fixed with amend, second pass green; bot `+1` | Rebase before squash to catch lint regressions |
| #191 | README docs; bot reacted `+1` 13 min before I merged but I didn't check | I was looking at the wrong API. Cheap to read — but a `+1` is not the merge condition, and later measurement found it fires on almost no round at all |
| #192 | force-complete amendment loss; bot found P2 about empty-amendment status text → fixed → `+1` | P2 still worth addressing |
| #193 | Issue #188 reopen attempt; bot pass-2 found P1 about retry session; addressed → `+1` | Saw "addressing P1 introduces new P1" |
| #194 | `contains` injection; bot's two rounds both flagged subschema issues, merged anyway, then OpenAI rejected the schema in production → reverted | Bot can't catch what local tests don't catch; reality bites |
| #195 | Revert + replacement (codex-only enum narrowing), CI flake on rerun → green; bot `+1` | Distinguish flake from regression |
| #196 | Drop `--output-schema` entirely (architectural fix); bot reacted `+1` 30 min after open; I almost waited another cycle for nothing | Do not wait on a cycle you cannot observe. Running § 7 answers it; waiting for a reaction that may never come is the stall this table used to recommend |
