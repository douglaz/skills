# Harden-until-clean drive

The outer loop that wraps the backlog drain: review the whole branch, turn the
findings into beads, drain them one rb-lite run at a time, re-review, repeat
until the reviewers are clean.

Load this when the user wants a branch *hardened* rather than a known backlog
*drained*. Plain backlog-drain mode takes an existing bead list as input; this
mode generates that list from a review of the branch, then hands off to it.

## Why an outer loop at all, when rb-lite already reviews

rb-lite's panel reviews **the current run's diff**. On a per-bead feature branch
that means "this bead's edits" — which is the right scope for judging whether
the bead was implemented well, and the wrong scope for noticing what the bead
*broke somewhere else*.

| Reviewer | Diff base | Sees |
|---|---|---|
| rb-lite's panel, inside a run | that bead's branch point | just this bead's edits |
| the outer panel, here | `$REVIEW_BASE` (usually `origin/main`) | every merged bead + the original branch work |

So when bead A tightens a server-side auth predicate, rb-lite signs off — it
cannot see the clients that just became mismatched. The next outer pass sees
both and flags them. **Later iterations mostly find regressions from earlier
fixes, and that is the loop earning its keep**, not evidence that you are
introducing bugs.

## The loop

```
loop:
  codex_findings, claude_findings = review_panel(work_branch, base=review_base)  # parallel
  findings = merge_and_dedupe(...)                     # tagged BOTH / CODEX / CLAUDE
  if no_real_findings(findings): break                 # DONE
  beads = [create_bead(f) for f in triage(findings)]
  sync_and_commit(beads)
  drain(beads)          # the skill's Backlog-drain workflow, one bead per rb-lite run
```

## Preconditions

- The work branch is a **disposable hardening branch**, never `main`/`master` or
  anything shared. This loop resets it to origin after every merge and may
  reopen the same finding in a later iteration.
- You know both refs: the *work branch* being hardened and the *review base*
  (usually the default branch). Ask once if either is unclear — the loop runs
  many subcommands and a silent misconfiguration is expensive.
- **`jq` is on the HOST `PATH`.** Not a backlog-drain-only prerequisite: section 3 runs
  `br create` and flushes before anything resolves the graph's path, and that resolution
  is `br where --json | jq` in *your* shell — the Nix wrapper supplies jq to rb-lite, not
  to you. Without it this loop mutates the graph and only then fails at the command that
  would have located the damage. Check before section 3, not after.
- `br` is **≥ 0.1.45**. Older versions corrupt their DB after branch resets:
  `br update`/`br close` start returning `ISSUE_NOT_FOUND` while `br show` and
  `br list` keep working, which hides the problem until you have lost bead state.
  This loop resets branches constantly, so it hits that bug hard.

Set up once, before iteration 1:

```bash
WORK_BRANCH="<branch being hardened>"
REVIEW_BASE="origin/main"          # whatever you are comparing against
ACTOR="${BR_ACTOR:-assistant}"
DEFAULT_BRANCH="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
if [ -n "$DEFAULT_BRANCH" ] && [ "$WORK_BRANCH" = "$DEFAULT_BRANCH" ]; then
  echo "Refusing to harden the default branch; create a dedicated work branch first."
  exit 1
fi

# `mktemp -d` for exclusive creation at 0700 — same reason as multi-reviewer-loop § 1.3:
# this directory holds full reviewer output quoting the code under review, a plain
# `mkdir -p` leaves it 0755 under the usual umask, and `-p` on a path someone else
# pre-created silently keeps their mode.
REVIEW_DIR=$(mktemp -d "/tmp/harden-$(basename "$(git rev-parse --show-toplevel)")-$(echo "$WORK_BRANCH" | tr '/ ' '__')-$(date -u +%Y%m%dT%H%M%SZ).XXXXXX") \
  || { echo "cannot create a private review directory"; exit 1; }
PROMPT_FILE="$REVIEW_DIR/claude-prompt.txt"
```

**Resolve the Claude reviewer's model before the first iteration**, into
`$CLAUDE_MODEL`, with the bounded probe in
[multi-reviewer-loop/references/reviewer-panel.md](../../multi-reviewer-loop/references/reviewer-panel.md)
§ Resolving the Claude reviewer's model. That file owns the ladder, the probe and
the evidence; this loop just uses the resolved `$CLAUDE_MODEL`, and treats an exhausted
ladder as a reviewer it does not have.
Do not hardcode a model here — an unreachable one hangs rather than erroring. With the
bound added below it at least *ends*: 25 minutes gone and no findings, but exit 124,
which the status capture there treats as a reviewer failure and never as clean.
Unbounded it is the dangerous shape, because a reviewer that never exits produces no
status to read at all. The probe turns the 25-minute version into a 90-second one.

Write the Claude reviewer's prompt once, into `$PROMPT_FILE`. Interpolate the base
with `printf` and keep the rubric in a **quoted** heredoc, so nothing in the text
gets shell-expanded:

```bash
{
  printf 'Review the changes on branch %s against the base ref %s.\n\n' "$WORK_BRANCH" "$REVIEW_BASE"
  printf -- '- `git diff %s` covers committed, staged, and unstaged changes.\n' "$REVIEW_BASE"
  printf -- '- Untracked source files are NOT in that diff; list them with `git status --short` and read them.\n'
  printf -- '- Read CLAUDE.md / AGENTS.md and nearby code when a finding depends on them.\n'
  cat <<'EOF'

Report real defects in the CHANGED code: correctness, security, data loss,
concurrency, error handling, unhandled cases, missing tests for changed
behavior, and violations of this repo's documented conventions.

Rules:
- Before asserting the diff violates an invariant, or making any claim about
  behavior in code the diff does not show, read that code and cite file:line.
  If you cannot verify it, mark it a QUESTION, not a finding.
- One finding per line, starting with [P0]/[P1]/[P2]/[P3], then file:line, then
  a one-line claim, then indented detail: why it is wrong and the concrete
  failure it causes.
- Do not propose mechanism, config, or hardening that no real correctness,
  security, or data-loss requirement needs. Report defects, not a wishlist.
- Do not modify, create, or delete any file. This is a read-only review.
- If you find nothing, output exactly: No findings.
EOF
} >"$PROMPT_FILE"
```

## 1. Review the branch

Both reviewers run **in parallel**, against the same base, neither seeing the
other's output. Feeding one reviewer the other's findings collapses the panel
into a single opinion.

```bash
PASS=$(printf '%02d' "$ITERATION")
# Bound BOTH reviewers. Either can hang with no output and no exit, and an unreachable
# model does exactly that — so without this the `wait` below never returns, the `jq`
# unwrap is never reached, and the "proceed with the survivor" handling further down
# never runs. That is a permanent stall, not a slow iteration, and it looks identical
# to a reviewer still thinking.
#
# This panel is a HOST-shell dependency, and that is a stronger requirement than the
# one SKILL.md states for rb-lite itself: under `nix run ... rb-lite --` the upstream
# wrapper supplies GNU timeout to the RB-LITE process, so SKILL.md rightly says not to
# reject that setup when the host shell lacks it. These two reviewers run outside that
# wrapper. Harden mode therefore needs GNU timeout on the host regardless of how
# rb-lite is resolved — or the panel below must be run inside the wrapped environment.
# Validate rather than merely locate: `command -v timeout` cannot tell GNU's from
# busybox's, and a busybox one fails every `--kill-after` invocation.
TO=""
for _c in timeout gtimeout; do
  if command -v "$_c" >/dev/null 2>&1 && "$_c" --kill-after=1s 1s true >/dev/null 2>&1; then
    TO=$(command -v "$_c"); break
  fi
done
[ -n "$TO" ] || { echo "harden mode needs GNU timeout on the HOST (see note above)"; exit 1; }
RC_TIMEOUT=1500

"$TO" --kill-after=60 "$RC_TIMEOUT" \
  codex review --base "$REVIEW_BASE" \
  -c 'model="gpt-5.6-sol"' -c 'model_reasoning_effort="xhigh"' \
  </dev/null >"$REVIEW_DIR/pass-$PASS.codex.txt" 2>"$REVIEW_DIR/pass-$PASS.codex.err" &
CODEX_PID=$!

"$TO" --kill-after=60 "$RC_TIMEOUT" \
  claude -p "$(cat "$PROMPT_FILE")" \
  --model "$CLAUDE_MODEL" --effort high --output-format json \
  --tools "Bash,Read,Glob,Grep" --allowedTools "Bash,Read,Glob,Grep" \
  --disallowedTools "Edit,Write,NotebookEdit" \
  </dev/null >"$REVIEW_DIR/pass-$PASS.claude.json" 2>"$REVIEW_DIR/pass-$PASS.claude.err" &
CLAUDE_PID=$!

# `|| VAR=$?` so a 124/137 timeout does not kill the shell under `set -e` before the
# other reviewer is reaped. Exit 124 (TERM) and 137 (the --kill-after KILL) are
# reviewer failures, never clean.
CODEX_RC=0; wait "$CODEX_PID" || CODEX_RC=$?
CLAUDE_RC=0; wait "$CLAUDE_PID" || CLAUDE_RC=$?

# `if`, not `jq ... ; JQ_RC=$?`. On a killed run the JSON is usually COMPLETE — measured
# in multi-reviewer-loop's § Resolving transcript, the 90s-killed probe wrote a full
# object — and it carries `is_error: true`, which is exactly what makes `jq -er` exit
# non-zero via `error()`. Under `set -e` that kills the iteration right here, before the
# survivor/DEGRADED handling below, turning the stall this timeout was added to prevent
# into an abort one line later. (A genuinely truncated write would fail too; it is just
# not the case the evidence shows.)
if jq -er 'if .is_error then error(.result // "claude reviewer returned is_error")
           else (.result // empty) end' \
     <"$REVIEW_DIR/pass-$PASS.claude.json" >"$REVIEW_DIR/pass-$PASS.claude.txt"; then
  JQ_RC=0
else
  JQ_RC=$?
fi
```

With the Claude reviewer unavailable — no ladder candidate answered — do not launch it,
and skip its `wait` and unwrap with it. That is the existing one-reviewer path, not a
new one: the survivor rule below already covers it.

Four things to know about these commands:

- **No prompt argument on `codex review`.** `[PROMPT]` and `--base` are mutually
  exclusive — passing both fails arg parsing before any review runs.
- **`codex review --base` does not see untracked files** (`--uncommitted` does,
  but cannot be combined with `--base`). Run `git add -N` on new source files
  first, or codex and the Claude reviewer are reviewing different diffs.
- **All three tool flags are needed.** `--tools` restricts the toolset,
  `--allowedTools` pre-approves it (without this, Bash calls are silently
  recorded as denials mid-review), `--disallowedTools` is belt-and-braces.
- **Read denied tool *names*, not the count.** `jq -r '.permission_denials[].tool_name'`
  — a denied `Edit`/`Write` is the read-only guard working; a denied
  `Bash`/`Read`/`Grep` means the reviewer was blocked from looking, and that pass
  is degraded for it.

Findings from both are lines starting with `[P0]`–`[P3]`. Count per reviewer,
then merge into one deduped list, each entry tagged `BOTH`, `CODEX`, or `CLAUDE`.
Dedupe on the claim, not the wording — the same defect described from two angles
is **one bead**, never two, or you will build yourself a merge conflict.

**Report the resolved model on every iteration, including clean ones.** The per-finding
templates below carry it, but a clean pass mints no beads and runs none of them — so a
fallback on the iteration that finally came back clean would leave no record anywhere
except the raw probe output, and the summary would say only that both reviewers were
clean. Name the model and where it came from (ladder default, pin, or fallback from
which model) in each iteration line and in the final report.

If the Claude reviewer fails **mid-run** — a 124/137 timeout, or `is_error` — re-resolve
the ladder once and rerun that iteration's reviewer on the next model before falling back
to the survivor. Degrading with an untried rung is the outcome the ladder exists to
prevent. If one reviewer fails, proceed with the survivor and label the iteration
`DEGRADED`, in chat and in the beads commit message.

## 2. Triage before minting anything

A finding is real if it names a concrete defect, or a plausible concern you
cannot rule out in under a minute of code reading. Reject it in chat — no bead —
only when you can point at code or tests that disprove it.

- **One reviewer's silence is not that evidence.** The two have different scopes;
  each routinely sees what the other structurally cannot.
- **When they contradict each other** (one calls the code a defect, the other
  calls it correct), read it yourself first. If the defect is real, put both
  readings plus your `file:line` evidence in the bead description — otherwise the
  implementer relitigates the same argument from scratch.
- When in doubt, create the bead. rb-lite's panel will confirm or kill it with
  evidence, which is cheaper than you guessing.

**Sibling sweep — the step that saves whole iterations.** When a finding names
one instance of a class ("these new routes lack auth"), grep the file for every
sibling with the same shape and mint beads for those too. Six separate auth-gap
beads collapsed into one sweep once this became explicit. The Claude reviewer
catches more siblings than codex does alone, because it reads whole files — but
it still chooses how far to read, so run the grep yourself. Classes that repeat:

- auth gating on newly-added route handlers
- owner/claim gates on sibling predicates over the same object
- entropy or length caps on user-visible identifiers (the dashboard cap moved;
  the CLI and server validators almost certainly did not)
- redaction on every sibling endpoint returning the same struct
- scheme/domain/host scoping at every write site of the same cookie


**Before the first `br` write, check the JSONL for divergence.** Any `br` mutation
auto-flushes the cache over the tracked file, so an unstaged hand-edit is erased by your
first write — and since neither the index nor `HEAD` holds it, every later diff shows only
your intended changes and the loss becomes *undetectable*. Resolve the path in its own
checked steps, and check the inspection too — embedded in a `git status` argument the
resolution's exit code is swallowed, and two of those failures are **silent** rather than
loud. Measured on git 2.54.0 / jq 1.8.2:

- `br where` exiting non-zero *after* emitting valid JSON. The pipeline reports only its
  last command's status, so `jq` succeeds and the assignment returns 0.
- `br where` emitting JSON without the key: `jq -er .jsonl_path` exits 1 **and prints
  `null`**, so the substitution yields the literal pathspec `null` and
  `git status --porcelain -- null` exits 0 printing nothing.

(A genuinely empty pathspec is *not* the hazard — `git status --porcelain -- ""` fails
loudly with `fatal: empty string is not a valid pathspec`, exit 128, on the version stated
above. Behavior may differ on older git — unmeasured here; if you must support one,
measure there.)

And `git status` itself can fail — a JSONL resolved outside this worktree exits 128
(`fatal: … is outside repository`) — printing nothing on **stdout**, so gating on stdout
emptiness alone reads a failed inspection as a clean tree right before the destructive
first flush:

```bash
_bw=$(br where --json) || { echo "cannot resolve the beads JSONL"; exit 1; }
BEADS_JSONL=$(printf '%s' "$_bw" | jq -er .jsonl_path) || { echo "cannot resolve the beads JSONL"; exit 1; }
_st=$(git status --porcelain -- "$BEADS_JSONL") \
  || { echo "cannot read the worktree — do NOT write"; exit 1; }
printf '%s' "$_st"
```

If it is not empty, resolve it first — recovery
case (a) in [orchestrating-with-rb-lite](../SKILL.md) step 11. After the first flush the choice
is gone.

**Start a replay manifest before minting.** Section 3 runs one `br create` per finding,
each auto-flushing, and the damage check comes after all of them. If it fires, step 11's
recovery deletes the cache and requires every intended mutation replayed — so record the
`br` commands with their generated ids and field values as you go. Without it, restoring
the good JSONL discards the whole iteration's legitimate bead additions.

## 3. Mint one bead per real finding

```bash
br create --actor "$ACTOR" "<short, concrete title>" \
  --priority <0..4> \
  --type bug \
  --labels <area>,code-review,review-src:<both|codex|claude> \
  --description "<finding summary, with file:line anchors>

Acceptance criteria:
- <user-visible behavior the fix must establish>
- <every entry point that must be covered>
- <what must KEEP working — name the legitimate cases explicitly>
- <at least one named test for the happy path and one for the rejection path>
- <the repo's gate set passes on the final tree>

Source: <codex | claude/$CLAUDE_MODEL | both reviewers> review of $WORK_BRANCH vs $REVIEW_BASE, iteration <N>." \
  --json
```

Priority mapping: `[P0]` → 0; `[P1]` touching security/auth → 0; other `[P1]` →
1; `[P2]` → 2; `[P3]` → 3. When the two reviewers rate the same defect
differently, **take the higher tag** — the one that rated it higher usually saw a
failure mode the other never described, and that mode belongs in the description
either way. Do *not* bump priority just because both reviewers raised it;
priority tracks blast radius, not vote count.

**The "what must keep working" line is not optional.** A fix that narrows access
for security, with acceptance criteria that only describe the narrowing, gets
signed off — and the next iteration finds the over-correction that broke a
legitimate caller. Naming the cases the narrow must preserve is what stops that
extra round trip.

Then flush and commit — `br` never touches git, that part is yours:

```bash
br sync --flush-only || { echo "findings not persisted"; exit 1; }
_bw=$(br where --json) || { echo "cannot resolve the beads JSONL"; exit 1; }
BEADS_JSONL=$(printf '%s' "$_bw" | jq -er .jsonl_path) || { echo "cannot resolve the beads JSONL"; exit 1; }
git diff HEAD -- "$BEADS_JSONL" || { echo "cannot diff the JSONL — do NOT stage"; exit 1; }
```

**Stop the block here and read that diff.** This is a real split, not a comment: run the
lines above, read the output, and continue below only once you have. Pasted as one block —
or run non-interactively, where the pager never pauses — the diff scrolls past and the very
next line stages, commits and pushes the collateral damage, which is the loss this check
exists to catch. Prose underneath a `git add` cannot stop a shell.

```bash
# The split above is a real gate, not a suggestion: an automated runner executing block
# after block reaches `git add` regardless of what the diff showed. Require the reviewer
# to record what they saw before anything is staged.
# Bind the acknowledgement to THIS pass. The loop runs in one shell, so a value set in
# iteration 1 would satisfy every later iteration and let an unreviewed diff stage,
# commit and push — the gate passing on the strength of a decision about a different
# graph. Unset it before the diff, and record the pass it belongs to.
unset BEADS_DIFF_REVIEWED
# ...print and read the diff, then:
: "${BEADS_DIFF_REVIEWED:?read THIS pass's diff, then set it to \"pass $ITERATION: <what you found>\"}"
git add -- "$BEADS_JSONL"
git commit -m "chore(beads): record review findings (iteration <N>, codex+claude/<model>)"
git push
```

Do not stage that file unread. The flush re-exports **every** bead from the
gitignored `.beads/beads.db` cache over the tracked JSONL, so a body the cache
holds a stale copy of is reverted here — silently, at exit 0, and once committed
the loss looks like an ordinary bead-state sync. Minting findings as beads is
when bodies are longest, so this iteration is when the loss costs most. Check the
field-level changes: a full re-serialization with every id on both sides is
normal; ids on only one side, or a `description` this iteration did not write, is
the tell. Never hand-edit the JSONL — that is what makes the cache stale, since a
hand edit does not advance `updated_at`. Recovery is in
[SKILL.md](../SKILL.md) step 11.

If the iteration ran degraded, say which reviewer was missing in that commit
message. Months later it explains why iteration N looks thin.

## 4. Drain the beads

Hand off to the **Backlog-drain workflow** in the main skill and follow it
exactly: one bead, one branch, one rb-lite run, local gates, one **work** PR, one
squash merge, one `br close`. (Closing the last bead in a scope needs its own small
metadata PR — that is bookkeeping, not a second work PR, and the rule still holds.) Nothing about draining changes here.

Two rules from the drain workflow matter more in this mode than usual:

- **Serialize.** Do not start bead B's run while bead A is open. Two long-lived
  branches merging into the same base is where conflicts live.
- **Evidence-first closure.** The closure has to say which merge satisfied the bead:
  put the merge SHA and PR number in the **closure commit message**. `br close` also
  takes `--reason`, but the drain path closes with `br update <id> -s closed` for the
  flush behaviour the main skill explains — so the commit message is where this
  evidence reliably lands. A bead closed without the merged fix just reappears in the
  next review, and you will not know why.
  The `bead-closure: <bead-id>` marker is a SEPARATE obligation and does not move here:
  step 12's recovery query reads each PR's `.body` and nothing else, so a marker left
  only in the commit message is invisible to a fresh clone — which is the state that
  rebuilds merged work. Evidence in the commit message, marker in the PR body, both.

## 5. Re-review and repeat

Increment the iteration, go back to step 1. Expect **regressions from earlier
fixes** to dominate later iterations — that is the diff-base asymmetry at the top
of this file, not a sign the work is going badly.

Watch the per-reviewer counts across iterations, not just the total. One reviewer
going clean and staying clean while the other keeps producing findings is the
panel telling you the core is done and the loud reviewer is mining the tail —
check those findings against the over-specification test before minting another
round of beads. (Rule out the boring explanation first: confirm the quiet
reviewer actually ran and exited 0.)

## Stop conditions

- **Both reviewers ran and both report zero findings. Done.**
- One clean, the other *transiently* failed (auth, 429/529, timeout): rerun the
  failed reviewer before declaring anything.
- One clean, the other **permanently unavailable** (not installed, no
  credentials, user can't fix it): stop at `CLEAN_DEGRADED` and name the missing
  reviewer. This loop has no pass limit, so without this exit a single-reviewer
  machine iterates forever waiting for an opinion that is never coming.
- Both reviewers fail in the same iteration: stop and report it. Nothing reviewed
  the code; do not merge on an empty pass.
- The same materially identical finding survives two full iterations (bead →
  rb-lite → merge → re-review still shows it). Escalate: either the fix is wrong
  or the finding is a false positive neither side is disproving. A finding you
  rejected that returns from the *other* reviewer deserves a fresh look first.
- A finding *class* reappears three iterations running with new siblings each
  time. The loop is working, but a one-time manual grep with the user beats three
  more iterations.
- The user asks to pause.

## What to expect

A real hardening loop on a substantial branch runs **10–20 iterations and dozens
of merged PRs** — hours, possibly a full day, of mostly-autonomous work. Most
iterations find 2–4 findings. Say this up front; do not start without explicit
agreement.
