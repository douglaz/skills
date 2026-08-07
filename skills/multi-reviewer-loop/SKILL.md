---
name: multi-reviewer-loop
description: >-
  Runs an iterative multi-reviewer review/fix/re-review loop on the current
  branch: detects a review base, runs a two-reviewer panel (`codex review` plus
  Claude Fable at high effort) in parallel each pass, merges and dedupes their
  findings, treats findings as credible until disproven, fixes accepted items,
  validates the changed code, and repeats until both reviewers are clean on the
  current diff. A final consistency pass then checks that the changed files still
  agree with each other and with the docs describing them; a clean diff alone does
  not finish the loop. Stops early at the pass limit. Use when the user asks to "review loop",
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
Claude reviewer's JSON, and GNU `timeout` — named `timeout`, or `gtimeout` from
Homebrew coreutils; resolve it once with `command -v` — to bound each reviewer — both CLIs can hang indefinitely, writing nothing and never exiting.

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
   - PR base branch from `gh pr view`. **On a fork clone this needs the upstream and the
     head-label selector**, or it silently finds nothing and falls through to the next
     candidate — which on a fork is `origin/<feature>`, i.e. HEAD itself, so the pass
     reviews an empty diff and reports "Nothing to review" on a branch full of changes:

     ```bash
     # Probe both, do not force the parent: a fork can host its own PR, and forcing
     # `.parent` makes it invisible. ENUMERATE both — the same branch can have an open PR
     # in the parent AND in the fork, two separately reviewed surfaces with two merge
     # targets, and taking the first found reviews one of them by iteration order. A HEAD
     # match is the tiebreak when it singles one out; otherwise refuse, the same
     # double-match rule bot-gate enforces. A failed parent lookup is UNKNOWN, not "not a
     # fork": guessing "self" there reviews against the fork's base on a real fork.
     SELF=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
     # SELF empty means gh cannot see this checkout at all (no gh, no auth, non-GitHub
     # remote): no PR is findable, so fall through to the ladder below. A failed PARENT
     # lookup on a repo gh CAN see is different — that is unknown, and refuses here.
     PARENT=""
     if [ -n "$SELF" ]; then
       PARENT=$(gh repo view --json parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else "" end') \
         || { echo "cannot resolve the fork parent — do not guess the review base"; exit 1; }
     fi
     BR=$(git branch --show-current)
     HEAD_OID=$(git rev-parse HEAD)
     _GH_ERR=$(mktemp); trap 'rm -f "$_GH_ERR"' EXIT   # both scripts do this; the snippets leaked it || { echo "mktemp failed"; exit 1; }
     UP="$SELF"; SEL="$BR"; PRNUM=""; _M=0; _HM=0
     for _c in ${PARENT:+"$PARENT"} "$SELF"; do
       # Skips a degenerate candidate: a PARENT that duplicates SELF, and — load-bearing —
       # the SELF="" case above, where PARENT is empty too, so the lone "" iteration is
       # skipped, no `gh pr view -R ""` ever runs, and the ladder below resolves the base.
       [ "$_c" = "$SELF" ] && [ "$PARENT" = "$SELF" ] && continue
       _s="$BR"; [ "$_c" != "$SELF" ] && _s="${SELF%%/*}:$BR"    # gh matches the head LABEL
       # "No such PR" and "the query failed" share an exit code, so absence is read out of
       # gh's own error text. A transient failure read as absence erases one candidate —
       # and with it the double-match refusal below — so the pass reviews against
       # whichever PR the outage left visible. PullRequest-level not-found only: both
       # candidates are repos the API just named, so a Repository-level "could not
       # resolve" or an HTTP 404 is lost access, not absence.
       if ! _j=$(gh pr view "$_s" -R "$_c" --json number,state,headRefOid \
              -q 'select(.state=="OPEN") | "\(.number) \(.headRefOid)"' 2>"$_GH_ERR"); then
         grep -qiE 'could not resolve to a pullrequest|no pull requests found' "$_GH_ERR" \
           || { echo "cannot query $_c for $BR's PR — absence not established; do not guess the review base"; exit 1; }
         _j=""
       fi
       [ -n "$_j" ] || continue
       _M=$((_M+1))
       if [ "${_j#* }" = "$HEAD_OID" ]; then
         _HM=$((_HM+1)); UP="$_c"; SEL="$_s"; PRNUM="${_j%% *}"
       elif [ -z "$PRNUM" ]; then
         UP="$_c"; SEL="$_s"; PRNUM="${_j%% *}"
       fi
     done
     if [ "$_M" -ge 2 ] && [ "$_HM" -ne 1 ]; then
       echo "branch $BR has an OPEN PR in BOTH $PARENT and $SELF and HEAD singles neither out"
       echo "  — two review surfaces, two merge targets. Close one, or pin the intended repo"
       echo "  in every -R before reviewing; do not let iteration order pick."
       exit 1
     fi
     # OPEN only, and an empty PRNUM means "no PR" — fall through to candidate 2, do not
     # abort. The first HARDEN panel runs BEFORE any PR exists (that is the prescribed
     # ordering), so aborting here stops the panel in its most common state. And an
     # abandoned CLOSED PR must not win: `gh pr view` falls back to the most recent closed
     # or merged PR on the branch, which may have targeted a different base entirely.
     # But once a PR IS found, a failed base read is FATAL, not a fall-through: the PR's
     # base is knowable, and the ladder below substitutes the repo default — so a release
     # or stacked PR would silently get reviewed against the wrong diff. Same rule as the
     # fetch below.
     BASE_NAME=""
     if [ -n "$PRNUM" ]; then
       BASE_NAME=$(gh pr view "$SEL" -R "$UP" --json baseRefName \
                     -q .baseRefName 2>/dev/null) && [ -n "$BASE_NAME" ] \
         || { echo "PR $PRNUM exists but its base cannot be read — do not review against a guess"; exit 1; }
     fi
     # FETCH IT. The name alone is not a reviewable ref: on a fork clone `origin` is your
     # fork, so `origin/$BASE_NAME` is stale or absent — and when it is absent the ladder
     # falls through to the branch's own upstream, which IS HEAD. The panel then reviews an
     # empty diff and reports clean on a branch full of changes. Fetch the PR's real base
     # repository into a ref of its own and review against that.
     if [ -n "$BASE_NAME" ]; then
       # A PR exists, so its base is knowable and a failure to fetch it is fatal — that is
       # different from having no PR at all, which is candidate 2's job.
       BASE_REMOTE=$(gh api "repos/$UP/pulls/$PRNUM" --jq .base.repo.clone_url)
       git fetch -q "$BASE_REMOTE" "+refs/heads/$BASE_NAME:refs/remotes/prbase/$BASE_NAME" \
         || { echo "PR $PRNUM exists but its base cannot be fetched — do not review against a guess"; exit 1; }
       DIFF_BASE="refs/remotes/prbase/$BASE_NAME"
     fi
     # else: no open PR — leave DIFF_BASE unset and try the next candidate.
     # ...EXCEPT on a fork. The prescribed ordering runs the first HARDEN panel BEFORE any
     # PR exists, and every candidate the ladder below can reach — @{upstream}, the fork's
     # origin/HEAD, a bare `gh repo view` default — lives in the FORK. When the parent's
     # default branch has a different name (or its tip has moved), those candidates review
     # the wrong diff, and drive's post-panel OID check (phases.md § HARDEN pins the
     # PARENT's base via `base_repo`) then rejects every rerun with "different base commit"
     # — a deadlock whose remedy re-reviews the same wrong base. Resolve and fetch the
     # parent's own default here, exactly as the PR path above fetches the PR's base.
     if [ -z "${DIFF_BASE:-}" ] && [ -n "$PARENT" ]; then
       P_DEFAULT=$(gh repo view "$PARENT" --json defaultBranchRef \
                     -q .defaultBranchRef.name 2>/dev/null) && [ -n "$P_DEFAULT" ] \
         || { echo "fork with no PR: cannot resolve $PARENT's default branch — do not review against the fork's"; exit 1; }
       PARENT_URL=$(gh repo view "$PARENT" --json url -q .url 2>/dev/null) \
         || { echo "cannot resolve the parent clone URL — base unknown"; exit 1; }
       git fetch -q "$PARENT_URL.git" \
           "+refs/heads/$P_DEFAULT:refs/remotes/prbase/$P_DEFAULT" \
         || { echo "cannot fetch $PARENT $P_DEFAULT — do not review against a guess"; exit 1; }
       DIFF_BASE="refs/remotes/prbase/$P_DEFAULT"
     fi
     ```

   **The feature branch's OWN tracking ref is INELIGIBLE, by NAME and regardless of what
   it points at — skip that ref and keep going down the ladder.** On a pushed feature
   branch `@{upstream}` is `origin/<feature>`: when it equals HEAD, `git diff` against it
   is empty and both reviewers return clean having read nothing; when HEAD is AHEAD of it,
   the diff covers only the unpushed commits while clearance still covers the whole tip,
   which is worse. Neither is a valid base. But OID equality alone cannot disqualify a
   candidate, and neither can being the upstream: a branch cut from and tracking its
   *target* (`git checkout -b feat origin/release`) has `@{upstream}` = `origin/release`,
   which equals HEAD exactly when the whole review surface is staged, unstaged, or
   untracked work — and that is the correct base, not a degenerate one. What identifies
   the degenerate ref is its *name*: it is this branch's own remote counterpart. Skip
   only that.

   Only when the ladder is EXHAUSTED with no eligible candidate is it a resolution
   failure. Say so and stop then; do not review air.

   ```bash
   UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo "")
   ORIGIN_HEAD=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo "")
   FORGE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "")
   FORGE_DEFAULT=""
   if [ -n "$FORGE_BRANCH" ]; then
     git rev-parse --verify --quiet "origin/$FORGE_BRANCH" >/dev/null 2>&1 \
       && FORGE_DEFAULT="origin/$FORGE_BRANCH" || FORGE_DEFAULT="$FORGE_BRANCH"
   fi
   for c in "${DIFF_BASE:-}" "$UPSTREAM" "$ORIGIN_HEAD" "$FORGE_DEFAULT" \
            origin/main main origin/master master; do
     [ -n "$c" ] || continue
     git rev-parse --verify --quiet "$c" >/dev/null 2>&1 || continue
     # Only the branch's OWN remote counterpart (`origin/<this-branch>`), by NAME — not by
     # OID. A HEAD-equal upstream under another name (origin/release, tracked as the target,
     # with the surface still uncommitted) is a legitimate base, and the name test already
     # tells the two apart; adding an OID test on top broke the case it was meant to cover.
     # When the branch is AHEAD of its own push ref, the OID differs, the guard stopped
     # firing, and `origin/<this-branch>` became the base — so the panel reviewed only the
     # unpushed commits while clearance still covered the whole tip. Every earlier commit on
     # the branch went unread, which is the partial-diff-full-clearance failure this file
     # exists to prevent.
     if [ -n "$UPSTREAM" ] && [ "$c" = "$UPSTREAM" ] \
        && [ "${UPSTREAM#*/}" = "$(git branch --show-current)" ]; then
       continue   # the branch's own push ref is never the base, however far HEAD has moved
     fi
     DIFF_BASE="$c"; break
   done
   [ -n "${DIFF_BASE:-}" ] || { echo "no eligible base candidate resolves"; exit 1; }
   ```
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
   two backgrounded calls; in Codex, the shell will wait naturally. **Backgrounding
   removes the harness's own timeout, so wrap each reviewer in `timeout` yourself** —
   an unbounded reviewer can hang with no output and no exit, and a backgrounded one
   has nothing left to reap it. The full
   command block, including the Claude reviewer prompt, is in
   [references/reviewer-panel.md](references/reviewer-panel.md). The shape is:

   ```bash
   set -m          # each reviewer in its own process group; the escape hatch needs it.
                   # `set -m`, not `setsid` — that is util-linux and absent on macOS,
                   # which this skill supports. See references/reviewer-panel.md.
   PASS_ID=$(printf '%02d' "$N")
   TO=$(command -v timeout || command -v gtimeout) \
     || { echo "no GNU timeout — see references/reviewer-panel.md"; exit 1; }
   "$TO" --kill-after=60 1500 codex review --base "$DIFF_BASE" \
     -c 'model="gpt-5.6-sol"' -c 'model_reasoning_effort="xhigh"' \
     </dev/null >"$REVIEW_DIR/pass-${PASS_ID}.codex.txt" 2>"$REVIEW_DIR/pass-${PASS_ID}.codex.stderr.txt" &
   CODEX_PID=$!
   "$TO" --kill-after=60 1500 \
     claude -p "$(cat "$FABLE_PROMPT_FILE")" --model fable --effort high --output-format json \
     --tools "Bash,Read,Glob,Grep" --allowedTools "Bash,Read,Glob,Grep" \
     --disallowedTools "Edit,Write,NotebookEdit" \
     </dev/null >"$REVIEW_DIR/pass-${PASS_ID}.fable.raw.json" 2>"$REVIEW_DIR/pass-${PASS_ID}.fable.stderr.txt" &
   FABLE_PID=$!
   # `|| VAR=$?` — a timeout kill returns 124/137, and under `set -e` the bare
   # `; VAR=$?` form terminates the shell before the status is ever captured.
   CODEX_RC=0; wait "$CODEX_PID" || CODEX_RC=$?
   FABLE_RC=0; wait "$FABLE_PID" || FABLE_RC=$?
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

   **Do not edit the repo until both `wait`s have returned.** An edit made to a
   tracked file while `codex review` is in flight is silently destroyed, and the
   commit that should have carried it prints `nothing to commit, working tree
   clean` with the content absent from the file and from `HEAD`. Backgrounding
   both reviewers is exactly what puts this loop in the hazard window: codex's
   findings are readable while Fable is still running, and acting on them there
   is how the work disappears. If you must edit sooner, kill **both** reviewers by the
   PIDs you captured at launch and **then reap them** — `kill` only *sends* SIGTERM
   and returns immediately, so the wrapper and the reviewer are still shutting
   down when it comes back, and an edit right after is still inside the window:

   ```bash
   # BOTH reviewers, not just codex. The hatch abandons the pass, and this section's own
   # rule is that every reviewer has exited before you edit — leaving Fable alive holds a
   # Bash-capable process against the tree you are about to change, and unreaped besides.
   for _p in "$CODEX_PID" "$FABLE_PID"; do
     kill "$_p" 2>/dev/null || true        # never `pkill -f`; already-exited is fine
   done
   # Bounded escalation. Signalling the `timeout` wrapper from outside forwards TERM but does
   # NOT start its --kill-after timer, so a reviewer that ignores TERM leaves wrapper and
   # child alive and the waits below block until the original 1500s deadline — which is
   # exactly the hung-reviewer case this hatch exists for. Give it a few seconds, then KILL
   # the process group.
   sleep 5
   for _p in "$CODEX_PID" "$FABLE_PID"; do
     kill -0 "$_p" 2>/dev/null && kill -KILL -- "-$_p" 2>/dev/null || true
   done
   CODEX_RC=0; wait "$CODEX_PID" || CODEX_RC=$?   # reaping is what closes the window
   FABLE_RC=0; wait "$FABLE_PID" || FABLE_RC=$?
   ```

   Both `||`s are load-bearing under `set -e`, and they guard different moments.
   `kill` fails if codex exited on its own between your decision and the signal —
   a race you cannot exclude — so an unguarded `kill` exits the shell before the
   `wait`. And `wait` on a TERM-killed process returns **143**, so an unguarded
   `wait` exits it before the edit this hatch exists for. Either way Fable is left
   running unreaped. § 2's own `wait`s carry the same `|| VAR=$?` for the same
   reason.

   Then accept the lost pass. Full detail, the commit-time assertion, and the
   probe that gives a false all-clear are in
   [references/reviewer-panel.md](references/reviewer-panel.md).

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
     output. **Exit 124 or 137 is the timeout** and counts here — a reviewer that ran
     out of time reviewed nothing. (137 is the `--kill-after` path, used when the
     reviewer ignored TERM.) Record it, drop that reviewer from this pass, and mark
     the pass `DEGRADED`. See the recovery rules in the reviewer-panel reference.

4. Merge the two finding lists into `pass-NN.merged.md`. Dedupe on *claim*, not
   wording: same file, same code path, same defect = one merged finding. Tag each
   merged finding with its source — `BOTH`, `CODEX`, `FABLE`, or `CONFLICT` when the two
   reviewers explicitly disagree about the same code (§ 3.4 — those rows are the
   highest-value ones in the pass) — and keep both
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

6. **If this pass produced findings, do not stop here — go straight to § 3.** The summary
   below belongs to a pass that is *finished*, and a pass with findings is not: the fixes,
   the validation, and the next pass's launch all still have to happen. Emitting it now
   ends the turn at the pre-fix boundary, which is the same stall § 3.6 exists to prevent,
   one step earlier. § 3.7 is where a findings pass reports, and by then the next pass is
   already running.

   Show this only when the pass was clean (so § 3 has nothing to do) or when a § 4 stop
   condition fires — the cases where stopping is the correct outcome rather than a lapse:

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

**Entry condition: every reviewer has exited.** Not "codex has finished and I can
see its findings" — both `wait`s returned. Editing a tracked file while `codex
review` is still running destroys the edit silently (§ 2), so the first fix of
this phase cannot legally start until the last reviewer of the previous one is
dead. This is an ordering rule, not a preference; the skill tells you to run the
reviewers in parallel, which is precisely what makes the early-start tempting.

If every panel reviewer is clean, go to § 4b (the consistency pass) — not
straight to "Finish". A clean diff is the entry condition for that phase, not
the end of the loop.

Otherwise:

0. **Consider delegating the EDIT to a fresh implementer — see § 3a.** You still
   decide what is real; you do not have to be the one who types the fix. On a long
   loop this is usually the higher-leverage split.

1. Work the merged list, not two separate lists. Group related findings before
   editing and prefer fixing the root cause once over patching each comment
   independently — including when the two reviewers describe the same root cause
   from different angles.

   **A finding names a class, not a line.** This is the single highest-leverage
   habit in the loop, and skipping it is what makes a run take six passes instead
   of two. A reviewer cites the one site it happened to read; the same mistake is
   usually elsewhere too. Before you mark a finding fixed, search the repo for
   every other instance of that class and fix them in the same edit:

   - a rule stated in one file is usually restated in two or three others — grep a
     distinctive phrase from it, not just the file you were pointed at
   - a snippet with a bug (`echo` where it needed `exit 1`, a missing flag, an
     unbounded command) usually has siblings that were copied from it
   - a fact corrected in one place (an exit code, a condition, a command name)
     leaves every other statement of it stale, and the stale ones now *contradict*
     the fixed one — a worse state than before you started

   Measured on one real run: findings per pass went 13 → 7 → 11 → 7 → 6 → 8 → 6,
   and **most findings after pass 2 were drift introduced by the previous pass's
   fixes** — a rule updated at the cited site and left stale two files over. Rising
   or flat counts late in a loop usually mean fixes are being applied line-by-line.

   **Prefer a guard keyed on the condition over one keyed on named cases.** A check
   written as "suppress this when the phase came from *X*" silently re-breaks the
   moment someone adds state *Y*; the same check written as "suppress this unless
   the record actually won" covers *Y* and everything after it. When a finding says
   "you handled case X but not case Y", that is the tell — do not add Y to the list,
   replace the list with the property the cases share.

   After the edits, spend one command confirming the class is gone repo-wide
   (`grep -rn '<the stale phrasing>' .`) rather than re-reading the file you just
   changed. Quote that check in the pass summary.

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

   **When the finding is that a behavior is untested — or when your fix adds or
   changes a test — a green suite is not evidence the fix landed.** Invert the
   code the test is supposed to pin, confirm the test FAILS, then revert. A test
   written in answer to "nothing catches this" is worthless if it also passes
   against the defect, and running it green proves only that it runs. This is the
   one validation step that separates a test that *pins* a behavior from one that
   merely *exercises* it.

   Mutate the **code**, never the test's expected value — flipping the oracle
   turns any assertion red, including one that never reaches the behavior at all,
   so it proves nothing. Check that the failure names the assertion you meant to
   pin, and run **one mutation per property** the test claims: reddening the first
   of two leaves the second untested while looking verified.

   **Protect the fix before you invert it.** Your fix is uncommitted at this point, so
   `git restore <file>` / `git checkout -- <file>` to undo the mutation restores the
   *pre-fix* version and discards the fix along with it. The green run happened before that
   revert and nothing re-runs after it, so a later source-only pass can still report
   `CLEAN` over a tree missing the fix. **Mutate in a scratch copy, or save a patch of the
   fix first — those two only.** A green re-run is not a third option: when the fix and its
   new test live in the same file, restoring that file removes both, and the pre-existing
   suite then passes precisely because the test that would have caught the loss is gone
   too. If you must verify by re-running, diff the restored tree against the saved fix
   rather than trusting the green.

   **Isolate the run if the code under test touches anything live.** A fix on a
   money, data-loss or infrastructure path may be validated by a test that drives a
   real database, service or balance, and the inverted build can perform the harmful
   operation before the assertion notices — the mutation is not a dry run. Disposable
   environment, non-destructive mutation, or say the red run could not be done safely.

   Keep the trigger narrow — a coverage finding, or a test you touched — not
   every fix. It is one edit, one targeted test run, one revert. It earns its
   cost exactly where reading cannot help: a mapping, an ordering, a clock or
   lock choice, whose absence changes no test outcome. **If the mutation changes
   nothing, you have not verified the fix — you have found a second finding.**

   **And it blocks `CLEAN`.** Neither reviewer executes the test, so the panel cannot
   see this and § 5's verdict would otherwise be computed from their silence: the loop
   would report `CLEAN` and offer to ship a test unable to detect the behavior it claims
   to pin. Repair it and observe both runs — red against the inverted code, green against
   the correct code — or report the pass as **not** clean and say which test is unpinned.
   A verdict the panel is structurally blind to is one you have to enforce yourself.

6. **Launch the next pass before you write the summary.** Not after — before. Go back to
   § 2 with `N+1`, start the reviewers, and only then write up what this pass did.

   Writing a report to the user is the most turn-ending act available, so putting it last
   in a loop iteration reliably ends the loop instead of advancing it. Measured on a real
   run of this skill: every boundary whose final act was a summary stalled and needed a
   human "continue"; every boundary whose final act was a tool call did not. An explicit
   don't-stop instruction was already in place for both stalls and prevented neither — the
   failure is sequencing, not resolve, so inverting the order removes the failure state
   rather than asking you to resist it.

   Two things fall out: the reviewers work for 10-15 minutes while you write, and the
   summary becomes a fact ("pass 3 is running, task X") rather than a promise. Name the
   running task in it — a turn that ends with a pass running and one that ends with a pass
   merely announced read identically otherwise.

   The exceptions are § 4's stop conditions and § 4a/§ 4b, where the loop is deliberately
   not continuing.

7. Print a brief disposition summary in chat:

   ```text
   PASS N ACTIONS
   Next pass: <launched, task/PID> | <not launched — why>
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

### 3a. Delegating the edit

**The agent that wrote the text is the worst available editor of it.** After a few
passes you stop reading what is on the page and start reading what you meant. Measured
on one long documentation loop: the orchestrator fixing its own artifact introduced
roughly one to two *new* defects per fixing pass across eleven passes — the same claim
corrected in one file and left standing in its twin (ten times), replacements spliced
into the middle of a sentence without re-reading (breaking a list and duplicating a
clause), and absolutes that outran the code. Handed the same kind of findings, a fresh
implementer applied five of them with zero self-inflicted defects and proactively swept
eight sibling occurrences the orchestrator had not been asked about.

Treat that as one trial, not a law — by then the artifact was already much cleaner and
the findings were unusually well specified. The mechanism is probably **freshness plus a
written finding list**, not the particular model: delegating forces you to state each
finding precisely enough for someone else to act on, which by itself kills the vague ones.

**The split that works:**

- **You adjudicate.** Verify each finding against source first. Never hand over a finding
  you have not checked — you would be outsourcing the judgment, not the typing.
- **The implementer edits**, in a fresh context. A fresh context is also an *ignorant*
  one: everything it must not do has to be in the prompt, because none of it is in the
  air. Carry all of:
  - **The scope, named.** The exact paths it may touch and the tools it may use. An
    implementer told only "fix these findings" will range further than you meant, and
    you cannot review what you did not bound.
  - **Verify before fixing.** Findings are hypotheses; one may be wrong. Say so, or a
    fresh agent will treat your list as a work order.
  - **Sweep by concept, not by phrase.** After each fix, search the whole artifact for
    the same claim stated differently.
  - **Read back every passage you splice into** — the whole sentence and its
    neighbours, not the replaced span.
  - **Use the harness edit tool, not `sed -i` or `str.replace`**, which report success
    on zero matches. If an edit must be scripted, assert the target exists before
    replacing, then grep the file for both the new text and the *absence* of the old.
    This is the repo's standing edit contract (`agents-md`), and it does not travel to
    a fresh context on its own.
  - **Add no *unrequested* mechanism** — not "nothing new". A verified finding may
    genuinely require a lock, a validation, or a transaction; what is forbidden is
    anything beyond the finding. Scope conflicts come back to you to adjudicate, not
    resolved by the implementer.
  - Plus your environment guards.
- **Tool-managed state is delegable too — through the tool, never the file.** A ticket
  tracker or database whose on-disk form is a single JSONL line per record is corrupted by
  hand-editing, so the instinct is to keep those findings yourself. Measured: that instinct
  cost more than it saved. The orchestrator's own shell command-substituted the backticks
  in a double-quoted update and silently blanked three field names in a record. Delegating
  the same work with one rule — *use the CLI, never edit the file* — landed clean and the
  database still parsed. Name the tool, forbid the file, and require a read-back.
- **Snapshot first — and non-destructively.** The implementer has write access, and
  § 1.6 explicitly permits running on a dirty tree, so plain `git` is *not* your undo:
  `git checkout .`, `git stash`, and `git reset --hard` would each discard the user's
  pre-existing unstaged work along with the delegated edit, which § 1.6 forbids. Capture
  the tree first, **in two layers**, and check that the capture *commands* succeeded
  before granting write access:

  ```bash
  git diff --cached --binary >"$REVIEW_DIR/pre-delegation.staged.patch"   || { echo "snapshot failed"; exit 1; }
  git diff          --binary >"$REVIEW_DIR/pre-delegation.unstaged.patch" || { echo "snapshot failed"; exit 1; }
  git status --porcelain     >"$REVIEW_DIR/pre-delegation.status"         || { echo "snapshot failed"; exit 1; }
  ```

  **Two patches, not one.** A single `git diff HEAD` flattens staged and unstaged into one
  HEAD-to-worktree delta, so restoring a path that was `MM` brings it back as ` M` — the
  user's staging selection is gone, and a later `git commit` then carries hunks they had
  deliberately left out.

  **`--binary` on both.** Without it a modified binary records only `Binary files a/x and
  b/x differ` — a patch with no payload, which `git apply` then refuses. Revert that path
  and the user's original bytes are unrecoverable, from a snapshot that looked like it
  worked.

  **Empty is a legitimate snapshot.** On a clean tree — the ordinary PR-review case — both
  patches are empty because the branch's commits are already recoverable from git. Require
  the commands to *succeed*, never the patches to be non-empty; a non-empty check would
  refuse to delegate on exactly the tidiest repositories.

  To roll back, revert only the paths you delegated and re-apply each layer's hunks for
  those paths — staged first, then unstaged — and leave every other path alone.

  **Then restore intent-to-add from the status file.** § 1.5 runs `git add -N` on untracked
  source files so codex can see them; such a file has an empty staged patch and its whole
  content in the unstaged one, so replaying patches alone brings it back as an ordinary
  `??`. That is not cosmetic: `git add -N` is prescribed only *before the first pass*, so a
  file demoted here silently drops out of every later `codex review --base` and half the
  panel stops seeing it. Intent-to-add shows in porcelain as `" A "` — a **leading space**,
  then `A` — not `"A "`, which is an ordinary staged addition you must not touch:

  ```bash
  grep '^ A ' "$REVIEW_DIR/pre-delegation.status" | cut -c4- \
    | while IFS= read -r f; do git add -N -- "$f"; done
  ```

  Neither diff captures **untracked** files at all, so copy any that matter into
  `$REVIEW_DIR` first, or accept that they sit outside the snapshot and say which you did.

This is not `rb-lite`. That loop hands over the whole task and reviews the result; this
hands over *only the edit* for findings you have already verified.

### 4. Stop conditions

Stop early and surface the issue if any of these happen:

- the same materially identical finding survives two genuine fix attempts —
  but **check the current tree before you count a repeat**. A reviewer that
  re-reads a file often re-raises a finding it already got fixed, and a second
  sighting is not evidence the fix failed. Quote the line that closes it and
  reject; do not re-fix something already fixed.
- a reviewer's output is ambiguous or empty twice in a row
- a reviewer times out (exit 124 or 137) twice in a row — the hang is the finding; stop and
  say so rather than starting a third pass that may sit for an hour
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

**Two different causes produce that same rising-count symptom, and they need
opposite corrections — diagnose before you reach for the audit.** Read a sample of
the last pass's findings and ask what each one *is*:

- **New mechanism acquiring its own edge cases** (a check you added now needs its
  own error handling, a flag now needs a fallback) → over-specification. Run § 4a
  and cut.
- **The same rule stale in a file you didn't edit**, a snippet's sibling still
  carrying the bug you fixed, a fact corrected in one place and now contradicting
  its restatement elsewhere → not over-specification at all. That is line-by-line
  fixing, and the corrective is the class sweep in § 3.1, not cutting. Cutting here
  removes correct material and leaves the drift.

The tell is whether a finding is about something the previous pass *added* (audit)
or something the previous pass *failed to update* (sweep).

**Falling severity is not the same as done.** P1 counts dropping pass over pass
feels like convergence, and usually is — but both reviewers are re-reading the
same diff each round, so what falls can just as easily be their depth. A run that
ends on `br blocked --limit 50` and JSON quote-escaping has converged *on the
diff*; it has said nothing about whether the artifact still hangs together. That
is what § 4b is for, and it is why a clean pass alone does not finish the loop.

**Expect your own fixes to generate the next pass's findings.** A fix changes the
shape of nearby code, and the next pass sees the new shape for the first time —
so a late pass turning up defects *introduced by the previous pass's fixes* is
the loop working, not the loop failing. Two consequences: never treat the last
fix round as unreviewed-but-probably-fine, and when you are at the pass limit
with fixes applied since the last review, say so rather than reporting the run as
clean. Those fixes have not been reviewed by anyone.

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

### 4b. The consistency pass (the artifact-level pass)

Every normal pass reviews `git diff <base>`. That frame can only see defects
*inside changed lines* — and a whole class of real defects lives in the
**relationships between** the things you changed, which no hunk contains:

- a summary table, README, or overview that still describes the behaviour you
  tightened three passes ago
- two call sites of the same helper that drifted apart (one hardened, one not)
- a rule in one file that forbids what a rule in another file requires
- an example, template, or schema that no longer matches the code it documents
- a claim in the docs (a flag, a path, a command) that no longer exists

These survive any number of diff passes precisely because each individual hunk is
correct. They also get *created* by a long loop: you tighten a behaviour in one
file per pass and never re-read the file that summarises it.

**Entry:** a normal panel pass came back clean.

**Who runs it:** a reviewer that accepts a custom prompt. Fable by default — it
opens files the diff does not show, which is what cross-file agreement needs. On
a `--reviewers codex` pinned run use `codex exec --sandbox read-only` with the
same prompt (it takes one; `codex review --base` does not — and the sandbox flag
matters, since `codex exec` is a general coding agent that may try to *fix* a
contradiction and mutate the tree during the final check). If no available
reviewer can take a prompt, the pass cannot run: finish `CLEAN_DIFF_ONLY` and say
consistency was never checked — not `CLEAN_DEGRADED`, which is about a *panel*
reviewer being unavailable and has to name which one.

**Scope:** the changed files *plus any file that documents them* — a README or
overview that was never touched is exactly where this drift hides, so an
unchanged file contradicting a changed one is in scope and is a finding.

**Loop:** fix what it finds, then **re-run both the panel and this pass** on the
new diff. A consistency fix is a code change like any other and gets reviewed
like one. Repeat until a panel pass and a consistency pass are both clean on the
same tree. These re-runs count against `MAX_PASSES`; if the limit is already
exhausted, finish `ISSUES_FIXED_UNCONFIRMED` and offer more passes rather than
quietly calling it clean.

Fix findings the same way as any other — verify first, and prefer correcting
whichever side is actually wrong over "updating both to match".

**There is no "too small to need this."** A single-file change can still be
contradicted by an untouched README or overview — that is the incident this pass
exists for. The trigger is whether anything *documents* what you changed, not how
many files you touched. If you skip it anyway, the run is `CLEAN_DIFF_ONLY`, not
`CLEAN`.

The prompt, invocation, and output filenames are in
[references/reviewer-panel.md](references/reviewer-panel.md) § The consistency
pass prompt.

### 5. Finish

The loop is `CLEAN` only when, **on the same tree**, every reviewer in the panel
ran successfully and reported no findings, and the § 4b consistency pass came back
clean. Fixing something after either pass means that tree was never reviewed —
re-run both, do not round up.

If the final pass was degraded — a
reviewer failed, timed out, or was never available — report `CLEAN_DEGRADED` and
name which reviewer never weighed in. Do not round that up to clean; the user is
deciding whether to ship on it.

Two ways a run gets reported clean when it is not, both worth checking by name:

- **Fixes applied after the last review.** If you hit the pass limit, fixed the
  findings, and stopped, the diff you are shipping is one nobody reviewed. That
  is `ISSUES_FIXED_UNCONFIRMED`, not `CLEAN` — say which fixes are unreviewed and
  offer a confirmation pass.
- **Consistency pass never run** — you skipped it, or no reviewer could take a
  prompt. Diff-clean is not artifact-clean. Report `CLEAN_DIFF_ONLY` and name what
  it means: the changed lines are clean, and nothing checked whether the files
  still agree with each other.

When more than one status fits, report the **first** that applies:
`BLOCKED` → `ISSUES_REMAIN` → `ISSUES_FIXED_UNCONFIRMED` → `CLEAN_DEGRADED` →
`CLEAN_DIFF_ONLY` → `CLEAN`. A degraded panel that also never ran § 4b is
`CLEAN_DEGRADED`, and the report's consistency line carries the rest.

Report:

```text
MULTI-REVIEWER LOOP COMPLETE
Status: CLEAN | CLEAN_DIFF_ONLY | CLEAN_DEGRADED | ISSUES_FIXED_UNCONFIRMED | ISSUES_REMAIN | BLOCKED
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
Consistency pass (§ 4b): <ran, N findings | not run — why>
Fixes since last review: <none | N, unreviewed>
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

If the status is `CLEAN_DIFF_ONLY` (diff clean, consistency never checked):
- A) Run the § 4b consistency pass now
- B) Accept diff-only and ship
- C) Stop here

If the status is `ISSUES_FIXED_UNCONFIRMED` (fixes applied after the last review):
- A) Run one confirmation pass over the fixes (recommended — this is where
     fix-induced regressions show up)
- B) Ship the unreviewed fixes
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

- Never turn this into a report-only workflow: every finding ends as fixed, deferred, or
  disproven. You may delegate the EDITING (§ 3a) — that is not report-only — but the
  adjudication stays yours.
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
