---
name: multi-reviewer-loop
description: >-
  Runs an iterative multi-reviewer review/fix/re-review loop on the current
  branch: detects a review base, runs a two-reviewer panel (`codex review` plus
  Claude Fable at high effort) in parallel each pass, merges and dedupes their
  findings, treats findings as credible until disproven, fixes accepted items,
  validates the changed code, and repeats until both reviewers are clean or the
  pass limit is reached. Use when the user asks to "review loop",
  "multi-reviewer loop", "codex review loop", "review and fix", "review until
  clean", "get a second reviewer on this", "let's get this PR clean", "fix what
  the reviewers found", or right before opening a PR or shipping. Also suggest
  proactively after substantial implementation work or when a single review pass
  surfaced issues. Does not commit, open a PR, or reject findings without
  concrete evidence.
argument-hint: "[max-passes] [--reviewers codex|fable|codex,fable] [focus instructions]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# multi-reviewer-loop

Drive a tight two-reviewer review loop without bloating the agent's own context.

Two reviewers with different failure modes catch more than either alone, and
their *disagreements* carry information a single reviewer can't give you: a
finding both raise is worth fixing first; a finding only one raises still needs
your own judgment; a reviewer that keeps going quiet while the other ratchets is
telling you the change is done.

## Tool dependencies

The default panel is two reviewers, run in parallel every pass:

| Reviewer | Command | Notes |
|---|---|---|
| `codex` | `codex review --base "$DIFF_BASE" -c 'model="gpt-5.6-sol"' -c 'model_reasoning_effort="xhigh"'` | Diff-scoped, structured `[P*]` output |
| `fable` | `claude -p "<review prompt>" --model fable --effort high --output-format json` | Repo-aware, reads beyond the diff |

Both CLIs must be on `PATH` and authenticated. `jq` is needed to unwrap the
Claude reviewer's JSON.

- If **both** are missing, stop and tell the user to install them.
- If **one** is missing or unauthenticated, run the loop with the survivor and
  label every pass `DEGRADED` — a degraded loop can reach `CLEAN_DEGRADED`, never
  plain `CLEAN`.
- Default to `gpt-5.6-sol` at `xhigh` for codex and `fable` at `--effort high`
  for Claude. If the user or repo pins different models, honor that. If
  `gpt-5.6-sol` is unavailable, retry once with the environment default model and
  note the fallback. If a flag is not recognized, retry without it and note the
  incompatibility; both CLIs change between versions.
- Web search is enabled by default in current Codex CLI releases, so do not pass
  `--enable web_search_cached`.

Exact invocations, the Claude reviewer prompt, and per-reviewer failure handling
live in [references/reviewer-panel.md](references/reviewer-panel.md). Read that
file before the first pass.

Persist full reviewer output to files, keep chat summaries short, and only ask
the user when a finding needs a real product or architecture decision.

This skill may be suggested proactively, but do not start running it unless the
user explicitly asked for it or clearly agreed.

Default stance: treat findings from either reviewer as review hypotheses that
deserve verification, not mandates. The goal is to resolve or properly escalate
findings, not to win an argument with a reviewer — and not to credulously
implement every one. A finding can be valid *as stated* yet not worth building
(over-specification): the loop only ever pushes toward *adding*, so you supply
the counter-pressure toward simplicity. Two reviewers push twice as hard in that
direction, so this matters more here than with one. Accepting every finding for
several passes, or a loop that keeps spawning new findings as fast as it fixes
them, is a signal to step back, not to keep going.

## Inputs

Parse the user's request for arguments. In Claude Code, these arrive via
`$ARGUMENTS`; in Codex, extract them from the text surrounding the
`$multi-reviewer-loop` mention.

Parse in this order, so a flag never leaks into the focus text:

1. **`--reviewers <list>`** anywhere in the arguments: pin the panel to
   `codex`, `fable`, or `codex,fable`, and remove both tokens from what remains.
   Default is `codex,fable`. A single-reviewer run by explicit user request is
   not "degraded" — report it as a pinned panel.
2. **A leading positive integer** in what's left: use it as `MAX_PASSES` and
   remove it.
3. **Everything still remaining** is focus text (possibly empty).

So `/multi-reviewer-loop 3 --reviewers codex fix the retry path` means three
passes, codex only, focused on the retry path — and `--reviewers codex` must not
end up in the focus string.

Focus text is applied to the **Claude reviewer's prompt only**. `codex review`
cannot take a prompt alongside `--base` (see § 2), so codex always reviews the
whole diff. That asymmetry is fine — and arguably useful, since one reviewer
staying unfocused is how the loop still catches what you weren't looking for —
but report it rather than implying both reviewers were focused.

Clamp `MAX_PASSES` to `1..15`. Six is the default because most real review
loops converge within 1-3 passes; beyond six, repeated findings usually mean an
unresolved root cause, missing validation, a false positive, a larger design
issue, or a loop that is generating new findings as fast as it fixes them (each
fix adds review surface). The last case is a cue to run a skeptical audit
(§ 4a), not to keep spending passes.

Two reviewers cost roughly twice as much per pass as one. That is the point —
but if the user asks for a cheap check, `--reviewers codex` or
`--reviewers fable` is the honest way to give it to them, not silently dropping
a reviewer.

## Workflow

### 1. Preflight

1. Confirm this is a git repo and check both reviewer CLIs (`codex`, `claude`)
   plus `jq`. Record which reviewers are actually available; that set is the
   panel for every pass.

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
   `DIFF_BASE` ref you will review against. Both reviewers must get the same
   base — a panel comparing different bases produces incomparable findings.

3. Create a unique review directory:

   ```bash
   _PROJECT=$(basename "$(git rev-parse --show-toplevel)")
   _BRANCH=$(git branch --show-current 2>/dev/null | tr '/ ' '__')
   _TS=$(date -u +%Y%m%dT%H%M%SZ)
   REVIEW_DIR="/tmp/review-${_PROJECT}-${_BRANCH:-detached}-${_TS}"
   mkdir -p "$REVIEW_DIR"
   ```

   Store each pass separately, one file per reviewer:
   - `pass-01.codex.txt` / `pass-01.codex.stderr.txt`
   - `pass-01.fable.txt` / `pass-01.fable.raw.json` / `pass-01.fable.stderr.txt`
   - `pass-01.merged.md` — the deduped finding table for that pass
   - `pass-01.notes.md` — dispositions and evidence
   - `summary.md`

4. Check whether there is anything to review.
   Treat these as reviewable changes:
   - committed branch diff vs `DIFF_BASE`
   - staged changes
   - unstaged changes
   - untracked source files

   If all are empty, stop: "No changes detected against `<DIFF_BASE>`.
   Nothing to review."

5. **Make untracked source files visible to codex, or the panel reviews two
   different things.** Measured behavior of `codex review --base`: it covers
   committed *and* uncommitted changes to **tracked** files, but **not untracked
   files** — and `--uncommitted` (which does cover them) cannot be combined with
   `--base`. The Claude reviewer is told to read untracked files, so on a tree
   with new files the two reviewers silently review different content.

   Before the first pass, if `git status --short` shows untracked source files:

   ```bash
   git add -N <each untracked source file>   # intent-to-add: shows in git diff, stages nothing
   ```

   `git add -N` makes them appear in `git diff` and in codex's base review without
   committing or staging content. If you can't or won't do that, say so in the
   pass summary and **never report `CLEAN` from a codex-only panel while
   unreviewed untracked files exist** — nothing looked at them.

6. If the working tree is dirty, continue, but say so explicitly.
   Do not clean, reset, or overwrite unrelated user changes. Only edit files
   tied to real findings.

### 2. Run one review pass

For each pass `N` from `1` to `MAX_PASSES`:

1. Run every panel reviewer **in parallel** and write full output to that pass's
   files. A pass can take 10-15 minutes. In Claude Code the Bash tool's timeout
   caps at 600000 ms, so either run the block in background mode or split it into
   two backgrounded calls; in Codex, the shell will wait naturally. The full
   command block, including the Claude reviewer prompt, is in
   [references/reviewer-panel.md](references/reviewer-panel.md). The shape is:

   ```bash
   PASS_ID=$(printf '%02d' "$N")
   codex review --base "$DIFF_BASE" \
     -c 'model="gpt-5.6-sol"' -c 'model_reasoning_effort="xhigh"' \
     </dev/null >"$REVIEW_DIR/pass-${PASS_ID}.codex.txt" 2>"$REVIEW_DIR/pass-${PASS_ID}.codex.stderr.txt" &
   CODEX_PID=$!
   claude -p "$(cat "$FABLE_PROMPT_FILE")" --model fable --effort high --output-format json \
     --tools "Bash,Read,Glob,Grep" --allowedTools "Bash,Read,Glob,Grep" \
     --disallowedTools "Edit,Write,NotebookEdit" \
     </dev/null >"$REVIEW_DIR/pass-${PASS_ID}.fable.raw.json" 2>"$REVIEW_DIR/pass-${PASS_ID}.fable.stderr.txt" &
   FABLE_PID=$!
   wait "$CODEX_PID"; CODEX_RC=$?
   wait "$FABLE_PID"; FABLE_RC=$?
   ```

   **Do not pass focus text as a `codex review` argument.** `codex review` rejects
   a `[PROMPT]` argument together with `--base` (`error: the argument '[PROMPT]'
   cannot be used with '--base <BRANCH>'`), so a focused run would fail arg
   parsing and silently degrade the panel to one reviewer. Focus reaches the panel
   through the Claude reviewer's prompt, which is where it belongs anyway. Say so
   in the pass summary: codex reviewed the whole diff, Fable reviewed it with the
   focus applied.

   Never run them sequentially just to read the first one's output — the panel's
   value is two *independent* reads. Feeding codex's findings into the Claude
   reviewer's prompt collapses it into an echo chamber.

2. Unwrap the Claude reviewer's JSON into a plain findings file with `jq`, and
   parse findings from both reviewers with the shared pattern in
   [references/reviewer-panel.md](references/reviewer-panel.md) § Parsing findings.
   Keep per-priority counts **per reviewer**.

   **Do not tighten that pattern to "the severity tag is the first token."** Only
   the Claude reviewer is prompted, so only it obeys a format you dictate; `codex
   review` cannot take a prompt alongside `--base` and emits markdown bullets
   (`- [P1] …`). A first-token rule silently scores every codex pass as zero
   findings — which § 4 then treats as *ambiguous twice in a row* and aborts the
   loop while codex was working perfectly.

3. Detect clean vs ambiguous vs failed, per reviewer:
   - **Clean**: exit 0, zero findings, and output explicitly says there are none
     (`No findings.` for the Claude reviewer).
   - **Findings present**: one or more `[P*]` items.
   - **Ambiguous**: exit 0, no `[P*]` items, no explicit clean signal. Do not
     treat as clean — surface the log.
   - **Failed**: non-zero exit, `is_error: true` in the Claude JSON, or empty
     output. Record it, drop that reviewer from this pass, and mark the pass
     `DEGRADED`. See the recovery rules in the reviewer-panel reference.

4. Merge the two finding lists into `pass-NN.merged.md`. Dedupe on *claim*, not
   wording: same file, same code path, same defect = one merged finding. Tag each
   merged finding with its source — `BOTH`, `CODEX`, or `FABLE` — and keep both
   reviewers' phrasings when they differ in what they'd have you do about it.
   Cross-reviewer agreement rules are in
   [references/disposition-rules.md](references/disposition-rules.md).

5. Append a short entry to `summary.md` with:
   - pass number
   - commands used, and each reviewer's exit status
   - counts by priority, per reviewer, plus merged/deduped totals
   - agreement counts (`BOTH` / `CODEX`-only / `FABLE`-only)
   - tokens line from stderr, if present
   - log file paths

6. In chat, show only a compact summary:

   ```text
   PASS N/MAX  [DEGRADED if a reviewer failed]
   Base: <DIFF_BASE>
   codex: P0=W P1=X P2=Y P3=Z  (ok|failed|ambiguous)
   fable: P0=W P1=X P2=Y P3=Z  (ok|failed|ambiguous)
   Merged: Total=T  (both=A codex-only=B fable-only=C)
   Logs: <REVIEW_DIR>/pass-NN.*
   ```

   Quote only the specific findings you are about to act on. Do not paste full
   reviewer output into the conversation unless the user asks.

### 3. Fix and validate

If every panel reviewer is clean, skip to "Finish".

Otherwise:

1. Work the merged list, not two separate lists. Group related findings before
   editing and prefer fixing the root cause once over patching each comment
   independently — including when the two reviewers describe the same root cause
   from different angles.

2. Order by confidence, then priority: `BOTH` findings first (two independent
   reads agree), then single-source findings by priority. Agreement is a
   prioritization signal, not a license to skip verification, and it is *not* a
   substitute for the over-specification test — two reviewers can both ask you to
   build something neither the code nor the threat model needs.

3. Classify each merged finding as `FIX`, `DEFER`, `REJECT`, or `CUT/SIMPLIFY`
   using the rules in
   [references/disposition-rules.md](references/disposition-rules.md).
   The key principle: `FIX` is the default, `REJECT` requires concrete
   counter-evidence (the finding is wrong), `DEFER` is for plausible findings
   that need broader work, and `CUT/SIMPLIFY` is for findings that are valid as
   stated but add mechanism no real correctness/security/data-loss requirement
   needs — apply the over-specification test there before building.

   **The other reviewer's silence is not counter-evidence.** The two reviewers
   have different visibility (codex is diff-scoped; the Claude reviewer reads the
   wider repo), so one missing what the other caught is expected. Rejecting a
   `CODEX`-only or `FABLE`-only finding still takes the same concrete evidence
   any rejection takes.

4. When the reviewers **directly contradict** each other — one asserts a defect,
   the other explicitly says that same code is correct — do not average them and
   do not default to the more alarming read. Go read the code yourself and decide
   with `file:line` evidence, recording which reviewer was right in
   `pass-NN.notes.md`. These are the highest-value moments in the loop: a
   contradiction means at least one confident reviewer is wrong about code you
   are about to ship.

5. After edits, run the narrowest useful verification you can find from repo
   guidance:
   - nearby tests for touched behavior
   - targeted lint/typecheck commands for touched files
   - project-specific verification from `CLAUDE.md`, `AGENTS.md`, repo docs, or
     existing scripts

   Do not launch the next review pass with known failing validation unless the
   failure is pre-existing and unrelated. If you cannot find a meaningful
   verifier, say that explicitly in the pass summary.

   If the diff is non-trivial and the repo has a standard cheap verification
   command, run it once before declaring the loop clean.

   Passing validation supports a fix, but it does not by itself prove that a
   rejected finding was false.

6. Print a brief disposition summary in chat:

   ```text
   PASS N ACTIONS
   Fixed:
   - [P1][BOTH] <what changed>
   Deferred:
   - [P2][FABLE] <why it remains open>
   Rejected with evidence:
   - [P3][CODEX] <why it is disproven>
   Cut/simplified (over-specification):
   - [P2][BOTH] <what was not built or shrunk, and what already covers the case>
   Contradictions resolved:
   - <claim> — codex right / fable right, per <file:line>
   Validation: <command/result or "no targeted verifier found">
   ```

### 4. Stop conditions

Stop early and surface the issue if any of these happen:

- the same materially identical finding survives two genuine fix attempts
- a reviewer's output is ambiguous or empty twice in a row
- both reviewers fail in the same pass (nothing reviewed the code)
- a finding remains plausible but fixing it would require a larger architectural
  rewrite or product decision
- validation fails and the cause is unclear
- max passes reached

Stop normal passes and run a **skeptical audit** (§ 4a) instead when the loop
stops converging:

- findings stay roughly constant or rise across passes, and each pass's findings
  are clearly *ripples of the previous pass's fixes* (a new mechanism you added
  last pass now has its own flagged edge cases) — a fractal tail, not progress
- you have made many fixes with **zero `REJECT` and zero `CUT`** — a sign you are
  implementing every hypothesis credulously
- findings are getting more peripheral / deeper into edge-case handling while the
  core has been clean for several passes
- **one reviewer has gone clean and stayed clean for two or more passes while the
  other keeps producing findings** — the panel's own convergence signal. The
  quiet reviewer is evidence the core is done and the loud one is mining the tail

More normal passes will not converge these; they grow the change. The audit is
the corrective.

### 4a. Skeptical audit (the inverted pass)

When § 4's convergence signals fire, run one inverted review instead of another
normal pass. Point a reviewer at the *opposite* question: not "what's wrong?" but
"what here is **not required for correctness** and could be cut, simplified, or
deferred?" A useful prompt names the load-bearing core to leave alone and asks
the reviewer to hunt over-specification aggressively, with, per item: what it is,
why it isn't strictly required (what already covers the case), and a
recommendation of CUT / SIMPLIFY / MARK-OPTIONAL.

**Run the audit on the Claude Fable reviewer when it is available.** It reads the
whole repo rather than just the diff, so it can see what already covers a case —
which is exactly the judgment a cut decision needs. `codex review` takes no
custom prompt alongside `--base` (they are mutually exclusive), so an inverted
codex pass needs `codex exec` instead. The audit prompt is in
[references/reviewer-panel.md](references/reviewer-panel.md).

Then **reconcile, don't obey** — accepting every cut is the same credulity in
reverse. Run the audit's recommendations through your own judgment and the
over-specification test, push back where a flagged mechanism is actually
load-bearing, and apply the agreed cuts/simplifications. If a real product or
architecture trade-off rides on how aggressively to cut, ask the user (the
choice changes what the artifact *is*). Re-verify after the cuts that the core is
intact and no dangling references to removed mechanisms remain.

### 5. Finish

The loop is `CLEAN` only when **every reviewer in the panel ran successfully and
reported no findings in the same pass**. If the final pass was degraded — a
reviewer failed, timed out, or was never available — report `CLEAN_DEGRADED` and
name which reviewer never weighed in. Do not round that up to clean; the user is
deciding whether to ship on it.

Report:

```text
MULTI-REVIEWER LOOP COMPLETE
Status: CLEAN | CLEAN_DEGRADED | ISSUES_REMAIN | BLOCKED
Panel: codex (<ok|failed|not available>), fable (<ok|failed|not available>)
Passes run: N/MAX
Base: <DIFF_BASE>
Review dir: <REVIEW_DIR>
Fixed: P0=W P1=X P2=Y P3=Z
Agreement: both=A codex-only=B fable-only=C
Deferred: <count or none>
Rejected with evidence: <count or none>
Cut/simplified (over-specification): <count or none>
Contradictions resolved: <count or none>
Remaining: <count or none>
Validation run: <short summary>
```

Also provide:
- the latest pass log paths, per reviewer
- the `summary.md` path
- a short list of any remaining findings, each tagged with its source reviewer
- any deferred items
- any rejected items with the evidence used
- any cut/simplified items with the over-specification rationale
- any reviewer contradictions and how you resolved them

Keep a copy of the latest pass under stable names:

```bash
cp "$REVIEW_DIR/pass-${PASS_ID}.codex.txt" "$REVIEW_DIR/review.codex.txt" 2>/dev/null || true
cp "$REVIEW_DIR/pass-${PASS_ID}.fable.txt" "$REVIEW_DIR/review.fable.txt" 2>/dev/null || true
cp "$REVIEW_DIR/pass-${PASS_ID}.merged.md" "$REVIEW_DIR/review.merged.md" 2>/dev/null || true
```

## When to ask the user

Only ask the user at the end, or when you hit a genuine decision boundary.
(In Claude Code, use the `AskUserQuestion` tool; in Codex, simply present the
options as text.)

If clean:
- A) Ship / open a PR
- B) Run one more review pass
- C) Stop here

If issues remain or you are blocked:
- A) Continue with 3 more passes
- B) Stop and leave the remaining findings documented
- C) Stop here

If the final pass was degraded:
- A) Retry the failed reviewer (fix auth / rerun) before deciding
- B) Accept the single-reviewer result and ship
- C) Stop here

## Proactive suggestion

Suggest this skill after a substantial implementation, after a single review
found issues, or right before opening a PR or shipping.

Suggested phrasing (adapt the invocation syntax to your environment):
"Want me to run the multi-reviewer-loop — codex and Claude Fable reviewing in
parallel — and iterate until both are clean or the remaining items are fixed,
deferred, or disproven with evidence?"

## Guardrails

- Fix issues yourself; do not turn this into a report-only workflow.
- Run the reviewers independently and in parallel. Never show one reviewer the
  other's findings — correlated reviewers are one reviewer.
- Keep chat concise; the logs hold the full reviewer output.
- Never commit, ship, stash, or reset automatically.
- Never edit unrelated files just because they are in the working tree.
- If you decide not to fix a finding, either defer it explicitly or cite the
  evidence that disproves it. The other reviewer's silence is not evidence.
- Never report a degraded pass as clean, and never silently drop a reviewer that
  failed — say which one and why.
- If a reviewer's auth or CLI errors out, surface the exact problem. Continue
  degraded if the other reviewer is healthy; stop if both are down.
