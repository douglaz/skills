---
name: codex-review-loop
description: >-
  Runs an iterative Codex review/fix/re-review loop on the current branch:
  detects a review base, runs `codex review`, treats findings as credible until
  disproven, fixes accepted items, validates the changed code, and repeats
  until clean or the pass limit is reached. Use when the user asks to "codex
  review loop", "review and fix", "review until clean", "iterate on codex
  review", "let's get this PR clean", "fix what codex found", "run codex and
  fix everything", or right before opening a PR or shipping. Also suggest
  proactively after substantial implementation work or when a single codex
  review surfaced issues. Does not commit, open a PR, or reject findings
  without concrete evidence.
argument-hint: "[max-passes] [focus instructions]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# codex-review-loop

Drive a tight Codex review loop without bloating the agent's own context.

## Tool dependencies

This skill requires the `codex` CLI on `PATH`. If the binary is missing, stop
and tell the user to install it. The skill uses `codex review` with flags like
`--base`, `-c 'model_reasoning_effort="xhigh"'`, and `--enable web_search_cached`.
If a flag is not recognized, retry without it and note the incompatibility — the
Codex CLI may have changed between versions.
Persist full Codex output to files, keep chat summaries short, and only ask the
user when a finding needs a real product or architecture decision.

This skill may be suggested proactively, but do not start running it unless the
user explicitly asked for it or clearly agreed.

Default stance: treat Codex findings as review hypotheses that deserve
verification. The goal is to resolve or properly escalate findings, not to win
an argument with the reviewer.

## Inputs

Parse the user's request for arguments. In Claude Code, these arrive via
`$ARGUMENTS`; in Codex, extract them from the text surrounding the
`$codex-review-loop` mention.

- No arguments: run up to 6 passes.
- First token is a positive integer: use it as `MAX_PASSES` and treat the rest as focus text.
- Otherwise: use 6 passes and treat all arguments as focus text.

Clamp `MAX_PASSES` to `1..15`. Six is the default because most real review
loops converge within 1-3 passes; beyond six, repeated findings usually mean an
unresolved root cause, missing validation, a false positive, or a larger design
issue.

## Workflow

### 1. Preflight

1. Confirm this is a git repo and the `codex` binary exists.
   If `codex` is missing, stop and tell the user to install or expose it on
   `PATH`.

2. Resolve `DIFF_BASE` in this order. Use the first candidate that resolves to a
   commit:
   - PR base branch from `gh pr view --json baseRefName -q .baseRefName`
   - current branch upstream from `git rev-parse --abbrev-ref --symbolic-full-name @{upstream}`
   - remote default branch from `git symbolic-ref refs/remotes/origin/HEAD`
   - repo default branch from `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`
   - `main`
   - `master`

   Prefer `origin/<branch>` when it exists locally. Otherwise use the matching
   local branch name. Print both the chosen branch name and the exact
   `DIFF_BASE` ref you will review against.

3. Create a unique review directory:

   ```bash
   _PROJECT=$(basename "$(git rev-parse --show-toplevel)")
   _BRANCH=$(git branch --show-current 2>/dev/null | tr '/ ' '__')
   _TS=$(date -u +%Y%m%dT%H%M%SZ)
   REVIEW_DIR="/tmp/codex-review-${_PROJECT}-${_BRANCH:-detached}-${_TS}"
   mkdir -p "$REVIEW_DIR"
   ```

   Store each pass separately:
   - `pass-01.review.txt`
   - `pass-01.stderr.txt`
   - `pass-01.notes.md`
   - `summary.md`

4. Check whether there is anything to review.
   Treat these as reviewable changes:
   - committed branch diff vs `DIFF_BASE`
   - staged changes
   - unstaged changes

   If all three are empty, stop: "No changes detected against `<DIFF_BASE>`.
   Nothing to review."

5. If the working tree is dirty, continue, but say so explicitly.
   Do not clean, reset, or overwrite unrelated user changes. Only edit files
   tied to real findings.

### 2. Run one review pass

For each pass `N` from `1` to `MAX_PASSES`:

1. Run Codex review and write full output to that pass's files. Allow up to
   5 minutes for the command to complete (in Claude Code, set a 300000 ms
   tool timeout; in Codex, the shell will wait naturally).

   Define the pass-specific files first:

   ```bash
   PASS_ID=$(printf '%02d' "$N")
   PASS_OUT="$REVIEW_DIR/pass-${PASS_ID}.review.txt"
   PASS_ERR="$REVIEW_DIR/pass-${PASS_ID}.stderr.txt"
   PASS_NOTES="$REVIEW_DIR/pass-${PASS_ID}.notes.md"
   ```

   Default command:

   ```bash
   codex review --base "$DIFF_BASE" -c 'model_reasoning_effort="xhigh"' --enable web_search_cached >"$PASS_OUT" 2>"$PASS_ERR"
   ```

   If focus text exists:

   ```bash
   codex review "$FOCUS" --base "$DIFF_BASE" -c 'model_reasoning_effort="xhigh"' --enable web_search_cached >"$PASS_OUT" 2>"$PASS_ERR"
   ```

   If `--enable web_search_cached` is not supported, retry once without it.

2. Parse findings from `"$PASS_OUT"` using lines whose first non-space token is
   `[P0]`, `[P1]`, `[P2]`, or `[P3]`. Keep separate counts for each priority
   and total.

3. Detect clean vs ambiguous output carefully:
   - Clean: zero findings and the output clearly says there are no findings.
   - Findings present: one or more `[P*]` items.
   - Ambiguous: no `[P*]` items and no explicit clean signal. Stop and surface
     the log instead of pretending it is clean.

4. Append a short entry to `summary.md` with:
   - pass number
   - command used
   - counts by priority
   - tokens line from stderr, if present
   - log file path

5. In chat, show only a compact summary:

   ```text
   PASS N/MAX
   Base: <DIFF_BASE>
   Findings: P0=W P1=X P2=Y P3=Z Total=T
   Log: <PASS_OUT>
   Tokens: <line from stderr or unknown>
   ```

   Quote only the specific findings you are about to act on. Do not paste the
   full review output into the conversation unless the user asks.

### 3. Fix and validate

If the pass is clean, skip to "Finish".

Otherwise:

1. Group related findings before editing. Prefer fixing the root cause once over
   patching each comment independently.

2. Classify each finding as `FIX`, `DEFER`, or `REJECT` using the rules in
   [references/disposition-rules.md](references/disposition-rules.md). The key
   principle: `FIX` is the default, `REJECT` requires concrete counter-evidence,
   and `DEFER` is for plausible findings that need broader work.

3. After edits, run the narrowest useful verification you can find from repo
   guidance:
   - nearby tests for touched behavior
   - targeted lint/typecheck commands for touched files
   - project-specific verification from `CLAUDE.md`, repo docs, or existing scripts

   Do not launch the next review pass with known failing validation unless the
   failure is pre-existing and unrelated. If you cannot find a meaningful
   verifier, say that explicitly in the pass summary.

   If the diff is non-trivial and the repo has a standard cheap verification
   command, run it once before declaring the loop clean.

   Passing validation supports a fix, but it does not by itself prove that a
   rejected finding was false.

4. Print a brief disposition summary in chat:

   ```text
   PASS N ACTIONS
   Fixed:
   - [P1] <what changed>
   Deferred:
   - [P2] <why it remains open>
   Rejected with evidence:
   - [P3] <why it is disproven>
   Validation: <command/result or "no targeted verifier found">
   ```

### 4. Stop conditions

Stop early and surface the issue if any of these happen:

- the same materially identical finding survives two genuine fix attempts
- Codex output is ambiguous or empty twice in a row
- a finding remains plausible but fixing it would require a larger architectural
  rewrite or product decision
- validation fails and the cause is unclear
- max passes reached

### 5. Finish

Report:

```text
CODEX REVIEW LOOP COMPLETE
Status: CLEAN | ISSUES_REMAIN | BLOCKED
Passes run: N/MAX
Base: <DIFF_BASE>
Review dir: <REVIEW_DIR>
Fixed: P0=W P1=X P2=Y P3=Z
Deferred: <count or none>
Rejected with evidence: <count or none>
Remaining: <count or none>
Validation run: <short summary>
```

Also provide:
- the latest pass log path
- the `summary.md` path
- a short list of any remaining findings
- any deferred items
- any rejected items with the evidence used

Keep `review.txt` as a copy of the latest pass for compatibility:

```bash
cp "$PASS_OUT" "$REVIEW_DIR/review.txt"
cp "$PASS_ERR" "$REVIEW_DIR/review-err.txt"
```

## When to ask the user

Only ask the user at the end, or when you hit a genuine decision boundary.
(In Claude Code, use the `AskUserQuestion` tool; in Codex, simply present the
options as text.)

If clean:
- A) Ship / open a PR
- B) Run one more Codex review pass
- C) Stop here

If issues remain or you are blocked:
- A) Continue with 3 more passes
- B) Stop and leave the remaining findings documented
- C) Stop here

## Proactive suggestion

Suggest this skill after a substantial implementation, after a single
`codex review` found issues, or right before opening a PR or shipping.

Suggested phrasing (adapt the invocation syntax to your environment):
"Want me to run the codex-review-loop and iterate until the review is clean or
the remaining items are fixed, deferred, or disproven with evidence?"

## Guardrails

- Fix issues yourself; do not turn this into a report-only workflow.
- Keep chat concise; the logs hold the full Codex output.
- Never commit, ship, stash, or reset automatically.
- Never edit unrelated files just because they are in the working tree.
- If you decide not to fix a finding, either defer it explicitly or cite the
  evidence that disproves it.
- If Codex auth or CLI errors occur, surface the exact problem and stop.
