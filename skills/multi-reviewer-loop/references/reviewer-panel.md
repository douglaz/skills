# Reviewer Panel

Exact invocations for the two default reviewers, the Claude reviewer's prompt,
and what to do when one of them fails. Load this before the first pass.

## Why two

`codex review` and the Claude reviewer fail in different directions, which is
the whole reason to pay for both:

| | `codex review` | the Claude reviewer (`--effort high`) |
|---|---|---|
| Scope | The diff against `--base` | The diff *plus* whatever repo code it decides to read |
| Untracked files | **Not seen** (`--uncommitted` covers them but conflicts with `--base`) | Seen — the prompt tells it to read them |
| Custom prompt | Not with `--base` (mutually exclusive) | Yes — you control the rubric |
| Output | Structured `[P*]` findings | Whatever the prompt asks for; the prompt below pins `[P*]` |
| Typical blind spot | Out-of-diff invariants and callers it never opened | Drifting into repo-wide commentary if the prompt doesn't fence it |

Because codex cannot take a custom prompt alongside `--base`, it cannot be given
the verify-before-asserting rule. The Claude reviewer can, and does below. That
asymmetry is worth knowing when the two disagree about code the diff doesn't
show: codex is guessing there, the Claude reviewer was told to go read it.

The untracked-file row is not theoretical. On the very change that introduced
this file, codex reviewed the modified tracked files but reported the new
reference file as "absent from the requested base diff" — while the Claude
reviewer had read it in full. Run `git add -N` on new source files before the
first pass (see the skill's preflight) or the panel is comparing notes on two
different diffs.

## Resolving the Claude reviewer's model

**The Claude slot is a role, not a model.** Resolve which model fills it once per
run, before the first pass, into `$CLAUDE_MODEL`; every invocation below uses that
variable and none hardcodes a name. The ladder is the user's pin, then `fable`,
then `opus`.

**Probe it — do not discover it inside a real pass.** A model you cannot reach does
not fail fast, it *hangs*: measured below, `--model fable` on a host whose Fable
access was exhausted wrote **zero bytes to both streams for over eight minutes** and
never exited on its own. Inside a pass that costs the whole `RC_TIMEOUT` (25 minutes)
and yields a truncated review that is not clean and not ambiguous, just gone. The
probe is one trivial prompt, bounded at 90s, and it cost **$0.032** on the model that
answered and **$0.0006** on the one that did not.

```bash
TO=$(command -v timeout || command -v gtimeout) \
  || { echo "no GNU timeout (nor gtimeout) — cannot bound the probe"; exit 1; }
# Unquoted on purpose: this is a space-separated ladder and the split IS the loop.
CLAUDE_MODEL_LADDER="${CLAUDE_REVIEWER_MODELS:-fable opus}"
CLAUDE_MODEL=""
_pj=$(mktemp) || { echo "cannot create the probe scratch file"; exit 1; }
trap 'rm -f "$_pj"' EXIT
for _m in $CLAUDE_MODEL_LADDER; do
  _rc=0
  "$TO" --kill-after=15 90 claude -p 'Reply with exactly: PANEL_OK' \
    --model "$_m" --output-format json \
    --tools "Read" --allowedTools "Read" --disallowedTools "Edit,Write,NotebookEdit" \
    </dev/null >"$_pj" 2>/dev/null || _rc=$?
  # All three conjuncts, because each catches what the others miss: the exit code
  # catches the hang (124, or 137 via --kill-after), `.is_error` catches a fast
  # refusal that still exits 0, and a non-empty `.result` catches a "success" that
  # came back with nothing in it.
  if [ "$_rc" -eq 0 ] \
     && jq -e '(.is_error | not) and ((.result // "") != "")' <"$_pj" >/dev/null 2>&1; then
    CLAUDE_MODEL="$_m"; break
  fi
  echo "claude reviewer: '$_m' did not answer (exit $_rc) — trying the next candidate"
done
# The loop exits 0 whether or not anything answered, so CHECK. An empty $CLAUDE_MODEL
# reaches the invocations below as `--model ""`, and a panel that never asked the CLI
# for a valid model is not the same as one whose reviewer came back clean.
[ -n "$CLAUDE_MODEL" ] \
  || echo "no ladder candidate answered — the Claude slot is EMPTY; run DEGRADED on codex"
```

Run verbatim, under `set -euo pipefail`, on a host whose first ladder entry was
unreachable:

```console
$ bash ladder.sh ; echo "LADDER_EXIT=$?"        # the block above, byte for byte
claude reviewer: 'fable' did not answer (exit 124) — trying the next candidate
CLAUDE_MODEL=opus
LADDER_EXIT=0
```

The `|| _rc=$?` and the `if` are what make that exit 0 rather than an errexit abort on
the first candidate. Measured on the same shape with `timeout 1 sleep 5` standing in
for an unreachable model, two candidates in the ladder:

```console
$ ( set +e ; bash -c 'set -euo pipefail; M=""; for m in a b; do _rc=0
>     timeout 1 sleep 5 || _rc=$?                       # guarded
>     [ "$_rc" -eq 0 ] && { M=$m; break; }
>     echo "candidate $m failed ($_rc)"
>   done; echo "M=${M:-<none>} reached_end=yes"' ; echo "exit=$?" )
candidate a failed (124)
candidate b failed (124)
M=<none> reached_end=yes
exit=0
$ ( set +e ; bash -c 'set -euo pipefail; ... timeout 1 sleep 5; _rc=$? ...' ; echo "exit=$?" )
exit=124                                                # unguarded: died on candidate a,
                                                        # printed nothing, never tried b
```

The unguarded form does not merely skip a candidate — it takes the whole shell down
before the second one is tried and before anything is printed, so on a host where the
*second* entry was reachable the operator sees a silent non-zero exit rather than a
working panel.

**Do not key this on stderr.** The measured failure wrote **0 bytes** there — an
"auth error in stderr" rule, which is what the failure table below used to say for
this case, never fires on it. Everything diagnostic arrived as JSON on *stdout*,
including from the run that was killed mid-stream.

```console
$ ( set +e ; TO=$(command -v timeout)
>   probe() { local m=$1 rc=0
>     "$TO" --kill-after=15 90 claude -p 'Reply with exactly: PANEL_OK' \
>       --model "$m" --output-format json \
>       --tools "Read" --allowedTools "Read" --disallowedTools "Edit,Write,NotebookEdit" \
>       </dev/null >"p.$m.json" 2>"p.$m.err" || rc=$?
>     echo "=== $m: status=$rc stderr_bytes=$(wc -c <"p.$m.err") ==="
>     jq -c '{is_error, subtype, terminal_reason, result, out_tokens: .usage.output_tokens,
>             models: (.modelUsage // {} | keys), cost: .total_cost_usd}' <"p.$m.json" ; }
>   probe opus ; probe fable )
=== opus: status=0 stderr_bytes=0 ===
{"is_error":false,"subtype":"success","terminal_reason":"completed","result":"PANEL_OK",
 "out_tokens":9,"models":["claude-haiku-4-5-20251001","claude-opus-5"],"cost":0.0320075}
=== fable: status=124 stderr_bytes=0 ===
{"is_error":true,"subtype":"error_during_execution","terminal_reason":"aborted_streaming",
 "result":null,"out_tokens":0,"models":["claude-haiku-4-5-20251001"],"cost":0.000579}
# claude 2.1.226, jq 1.8.2, GNU timeout/wc 9.11, bash 5.3.9. The JSON is one line each;
# wrapped here for width. Which model is exhausted is an account fact, not a property of
# the CLI — on your host the two rows may swap, and what must reproduce is the shape:
# the reachable model answers with is_error false and a non-empty result, the unreachable
# one does not.
```

Note `modelUsage` on the failed row: **only the small side model** appears, and
`out_tokens` is 0 — the requested model never ran at all. That is why the § "Unwrapping"
check on `modelUsage` below is load-bearing rather than a nicety.

The observation is that the unreachable model did not answer. *Why* it was unreachable
— exhausted credits, a plan that excludes it, an outage — is not something this probe
measures, and the ladder does not care: the same three conjuncts fall through for all of
them.

**A fallback panel is not a degraded panel.** `codex` + `opus` is still two
independent reviewers from two vendors, so it can reach plain `CLEAN`. What it must
not do is *hide* the substitution: name the resolved model in the pass header, in
`summary.md`, and in the final report. `DEGRADED` is for a slot that ended up
**empty** — every candidate in the ladder failed.

**One re-resolution per run, mid-flight.** If the probe passed but a real pass then
returns 124/137 or `is_error`, re-run the ladder once and switch for the remainder of
the run, noting the pass it changed at. If the ladder still yields the same model, or
the run has already re-resolved once, treat it as a failed reviewer and mark that pass
`DEGRADED` — do not let a flapping model spend the loop's passes on retries.

## Setup, once per pass

```bash
PASS_ID=$(printf '%02d' "$N")
CODEX_OUT="$REVIEW_DIR/pass-${PASS_ID}.codex.txt"
CODEX_ERR="$REVIEW_DIR/pass-${PASS_ID}.codex.stderr.txt"
CLAUDE_RAW="$REVIEW_DIR/pass-${PASS_ID}.claude.raw.json"
CLAUDE_OUT="$REVIEW_DIR/pass-${PASS_ID}.claude.txt"
CLAUDE_ERR="$REVIEW_DIR/pass-${PASS_ID}.claude.stderr.txt"
PASS_MERGED="$REVIEW_DIR/pass-${PASS_ID}.merged.md"
PASS_NOTES="$REVIEW_DIR/pass-${PASS_ID}.notes.md"
CLAUDE_PROMPT_FILE="$REVIEW_DIR/claude-prompt.txt"
```

The artifacts are named for the **slot** (`claude`), not the model, and the model is
recorded *inside* `summary.md` and each pass header. A file named `pass-01.fable.txt`
holding a review some other model wrote is a hand-labelled provenance claim of exactly
the kind this repo's discipline block forbids — and after a mid-run fallback that is
precisely what a model-named file would be.

`$PASS_NOTES` is where dispositions and evidence go — the disposition rules
reference it by name.

## The Claude reviewer prompt

Write it to a file once per run and pass it with `"$(cat ...)"`. Building this
string inline in the shell invites quoting bugs that silently truncate the
rubric.

Interpolate `$DIFF_BASE` and `$FOCUS` with `printf`, and keep the static rubric
in a **quoted** heredoc (`<<'EOF'`). An unquoted heredoc would expand `$` and
backticks inside the focus text — and focus text quoting code (`focus on the
\`retry\` path`) is exactly the case you'd want to support.

```bash
{
  printf 'Review the changes on this branch against the base ref %s.\n\n' "$DIFF_BASE"
  printf 'Scope:\n'
  printf -- '- `git diff %s` covers committed, staged, and unstaged changes.\n' "$DIFF_BASE"
  printf -- '- Untracked source files do NOT appear in that diff. List them with\n'
  printf -- '  `git status --short` and read any that are real source files.\n'
  printf -- '- Read CLAUDE.md / AGENTS.md and nearby code when a finding depends on them.\n'
  if [ -n "${FOCUS:-}" ]; then printf '\nFocus for this pass: %s\n' "$FOCUS"; fi
  cat <<'EOF'

Report real defects in the CHANGED code: correctness bugs, security holes, data
loss, concurrency hazards, missing error handling, unhandled cases, resource
leaks, broken or missing tests for changed behavior, and violations of this
repo's documented conventions.

Rules:
- Before asserting the diff violates or overstates an invariant, or making any
  claim about behavior in code the diff does not show, verify it by reading that
  code and cite file:line. If you cannot verify it, mark it a QUESTION, not a
  finding.
- One finding per item. Start each finding on its own line with the severity tag
  in square brackets as the first token, then file:line, then a one-line claim:
    [P1] src/foo.rs:42 - <claim>
  Then indented detail lines: why it is wrong, and the concrete failure it
  causes (inputs or state -> wrong result).
- Severity: P0 catastrophic (data loss, security break, guaranteed corruption);
  P1 serious defect in the changed path; P2 real but narrow or lower impact;
  P3 nit.
- Do not propose new mechanism, config, abstraction, or hardening that no real
  correctness, security, or data-loss requirement needs. Report defects, not a
  wishlist. Style opinions with no rule behind them are not findings.
- Do not modify, create, or delete any file. This is a read-only review.
- If you find nothing, output exactly: No findings.
EOF
} >"$CLAUDE_PROMPT_FILE"
```

The `if` form (rather than `[ -n ... ] && printf`) is deliberate: the `&&` form
returns non-zero when `FOCUS` is unset, which aborts the whole group under
`set -e`.

## Running the panel

Both reviewers start together and neither sees the other's output.

```bash
# Job control ON, before the launches. It puts each backgrounded reviewer in its OWN
# process group, which is what lets the escape hatch below signal the group rather than
# one pid. Verified: with `set -m` the child's PGID equals its PID and `kill -- -$PID`
# succeeds; without it the child inherits this shell's group and the same kill fails with
# "No such process" — swallowed by the hatch's `|| true`, so it looks like it escalated.
#
# `set -m`, NOT `setsid`: this skill supports macOS (that is what the `gtimeout` fallback
# is for) and `setsid` is util-linux, absent there — prefixing the launches with it would
# exit 127 before either reviewer starts, on a machine meeting every documented dependency.
set -m
RC_TIMEOUT=1500   # 25 min; a normal pass is 5-15
# Homebrew coreutils installs GNU timeout as `gtimeout`; hardcoding `timeout` makes both
# reviewers exit command-not-found on macOS and the loop can never reach clean.
TO=$(command -v timeout || command -v gtimeout) \
  || { echo "no GNU timeout (nor gtimeout) — bound the pass another way; see below"; exit 1; }

"$TO" --kill-after=60 "$RC_TIMEOUT" \
  codex review --base "$DIFF_BASE" \
  -c 'model="gpt-5.6-sol"' -c 'model_reasoning_effort="xhigh"' \
  </dev/null >"$CODEX_OUT" 2>"$CODEX_ERR" &
CODEX_PID=$!

"$TO" --kill-after=60 "$RC_TIMEOUT" \
  claude -p "$(cat "$CLAUDE_PROMPT_FILE")" \
  --model "$CLAUDE_MODEL" \
  --effort high \
  --output-format json \
  --tools "Bash,Read,Glob,Grep" \
  --allowedTools "Bash,Read,Glob,Grep" \
  --disallowedTools "Edit,Write,NotebookEdit" \
  </dev/null >"$CLAUDE_RAW" 2>"$CLAUDE_ERR" &
CLAUDE_PID=$!

# `|| VAR=$?`, not `; VAR=$?`. A timeout kill makes `wait` return 124/137, and under
# `set -e` — which this file assumes at line 99 — the bare form terminates the shell right
# there: CODEX_RC is never assigned, the Claude reviewer is never reaped, and the degraded-pass and
# two-consecutive-timeout handling below never runs. The `||` keeps errexit off the hook.
CODEX_RC=0; wait "$CODEX_PID" || CODEX_RC=$?
CLAUDE_RC=0; wait "$CLAUDE_PID" || CLAUDE_RC=$?
```

**The `set -m` above is load-bearing**, not decoration: it is what makes the escape hatch's
group-kill able to reach anything. Without it a TERM-ignoring reviewer keeps the `wait`
blocked for the full 1500 seconds — the exact case the hatch exists for — and the failed
group-kill is swallowed by its `|| true`, so it looks like it worked.

**Do not drop the `timeout`.** Either reviewer can hang indefinitely — no output, no
exit, no error. Measured: an unbounded consistency pass ran **6h20m and wrote zero
bytes** while comparable calls finished in 5-15 minutes; nothing reaped it, and the
loop reported "still running" the whole time because an empty output file is
indistinguishable from a slow one. `--kill-after` matters too: a process ignoring
`TERM` needs the follow-up `KILL`.

Exit **124 — and 137** are reviewer failures, never clean and never ambiguous. 124 is the
TERM path; a reviewer that ignores TERM is killed by `--kill-after` and returns **137**,
which is the very case that flag exists for. Counting only 124 lets the loop spend another
full timeout on the same hung reviewer. Record it, drop
that reviewer from the pass, and mark the pass `DEGRADED` — the same as any other
non-zero exit.

### Do not touch the repo while `codex review` is running

**An edit made to a tracked file while `codex review` is in flight is silently
destroyed.** Both reviewers must have exited — `wait` returned for each PID —
before you change a single file. If you must edit sooner, kill **both** reviewers **by
the exact PIDs captured at launch, then reap them**, and accept the lost pass:

```bash
# BOTH reviewers, not just codex. The hatch abandons the pass, and this section's own
# rule is that every reviewer has exited before you edit — leaving the Claude one alive holds a
# Bash-capable process against the tree you are about to change, and unreaped besides.
for _p in "$CODEX_PID" "$CLAUDE_PID"; do
  kill "$_p" 2>/dev/null || true        # never `pkill -f`; already-exited is fine
done
# Bounded escalation. Signalling the `timeout` wrapper from outside forwards TERM but does
# NOT start its --kill-after timer, so a reviewer that ignores TERM leaves wrapper and
# child alive and the waits below block until the original 1500s deadline — which is
# exactly the hung-reviewer case this hatch exists for. Give it a few seconds, then KILL
# the process group.
sleep 5
for _p in "$CODEX_PID" "$CLAUDE_PID"; do
  # Signal the GROUP unconditionally, never `kill -0 "$_p"` first: that probes the former
  # group LEADER, and a wrapper that exits on TERM while a TERM-ignoring child keeps its
  # PGID leaves the leader dead and the child running — the probe fails, the group KILL is
  # skipped, and `wait` returns with that child still writing to the worktree. KILL on an
  # already-empty group is harmless, so there is nothing for the probe to save.
  kill -KILL -- "-$_p" 2>/dev/null || true
done
CODEX_RC=0; wait "$CODEX_PID" || CODEX_RC=$?   # reaping is what closes the window
CLAUDE_RC=0; wait "$CLAUDE_PID" || CLAUDE_RC=$?
```

The `wait` is not decoration. `kill` returns as soon as SIGTERM is delivered, so
the `timeout` wrapper and the reviewer beneath it are still tearing down when it
does — and an edit made in that gap is inside the very window the kill was meant
to close.

Neither `||` is decoration, and they guard different moments. `kill` fails when
codex exited on its own between your decision and the signal — a race you cannot
exclude — so an unguarded `kill` exits the shell before the `wait` ever runs. And
`wait` on a TERM-killed process returns **143**, so an unguarded `wait` exits it
before the edit this hatch exists for. Either way the Claude reviewer is left running unreaped.
Same rule as the `wait`s under "Running the panel".

Not `pkill -f "codex review"` either: that matches your own shell and other
sessions' reviewers running the same command, per the rule below.

This loop is the most exposed skill in the repo to it: § 2 backgrounds both
reviewers *by design*, and § 3 is entirely about editing. An agent that starts on
codex's findings while the Claude reviewer is still running is inside the hazard window with
no warning.

What the loss looks like is a commit whose *message* reads like a no-op:

```console
$ git add -A && git commit -m "fix the retry path"
nothing to commit, working tree clean
```

That text is indistinguishable from "already committed", `git status` is clean,
and the content is gone from both the working file and `HEAD`. Observed twice on
a money-path branch, both times after the edits had been applied, verified on
disk with `grep -c`, and compiled green (clippy clean, 867 tests passing). Gates
that passed *before* the loss are not evidence.

**The prose lies; the exit code does not.** `git commit` with nothing staged
exits **1**, so check it — an unchecked `git add -A && git commit` inside a
larger block is how the message gets believed and the failure walks:

```bash
git add -- <every path this change touched>   # not `git add -A`: on a dirty tree it
git diff --cached                            # sweeps in unrelated work — and READ this,
                                             # since staging a path that was already
                                             # dirty takes the other agent's hunks too
git commit -m "<msg>" || { echo "commit produced nothing"; exit 1; }
git show --stat --format= HEAD               # all the paths you meant, and only those
```

Then confirm the *content* landed, per file, by the check that fits it — a file that
gained content must contain a distinctive new phrase; a file you removed lines from must
still exist **and** hold the expected remaining count of the deleted phrase; a deleted path
must be absent. A file that BOTH gained and lost content needs both of the first two — the
added phrase passing says nothing about whether the removal survived. One does not
substitute for another, and each has a way to
lie: `grep` defaults to regex (use `-Fq --`), `git show ... | grep` returns 141 under
`pipefail` when grep exits early (capture to a file first), `grep -c` counts lines rather
than occurrences, and demanding *zero* occurrences rejects a correct partial removal.

```bash
_chk=$(mktemp) || { echo "cannot create the scratch file — do NOT report the commit verified"; exit 1; }
trap 'rm -f "$_chk"' EXIT
# ...the three loops, using `grep -Fq --` / `grep -Fo | wc -l || true` on a captured file.
```

A clean `git status` is neither check. It is equally consistent with the edits
having been reverted underneath you.

**If you re-test this, do not plant the marker first.** An edit made *before* the
review starts survives: it disappears mid-run and comes back at the end. Only
edits made *during* the run are lost. A probe planted early returns a null result
and would tell the next reader the tool is safe — a worse error than the original.
Plant it with the review confirmed running (`ps -eo pid,args | grep '[c]odex
review'`), then re-check on disk before the run ends:

```
planted mid-run                  count=1
t=125s, still inside the review  count=0
```

The mechanism is not established. `git stash list`, `git reflog` and `git
worktree list` show no trace, and codex's own 1.4 MB transcript contains only
`git diff` and `git show` — no stash, checkout, reset, or worktree. "Restores a
snapshot taken at start" fits every observation but was never confirmed at the
implementation level. The rule above does not depend on which mechanism is right.

### When a pass looks stuck

Check elapsed time against the 5-15 minute norm before assuming progress:

```bash
ps -eo pid,etime,args | grep -E '[c]odex review|[c]laude -p'
```

`etime` (`[[dd-]hh:]mm:ss`), not `etimes` (raw seconds): `etimes` is a GNU extension and
macOS `ps` rejects it with a keyword error — on the platform the `gtimeout` fallback
exists to support.

An empty output file is not evidence of work. If a reviewer is far past the norm,
kill it **by exact PID** — never `pkill -f`, which matches your own shell and other
sessions' reviewers running the same command — then relaunch that reviewer alone.

Notes on the flags:

- **Close stdin on both reviewers (`</dev/null`).** These are non-interactive
  batch commands; neither should ever read the launching shell's stdin. Without
  the redirect, a reviewer that decides to read stdin (observed with `codex` in
  some releases: it prints `Reading additional input from stdin...` and blocks)
  hangs until the outer `timeout` kills it — which then looks like a slow review,
  not a stuck one. `</dev/null` gives an immediate EOF so the command proceeds on
  its arguments alone. Harmless when the tool never reads stdin, decisive when it
  does. (Backgrounding with `&` does not reliably detach stdin from a tty.)
- **No focus argument on `codex review`.** `codex review [PROMPT]` and `--base`
  are mutually exclusive at the CLI level — passing both exits immediately with
  `error: the argument '[PROMPT]' cannot be used with '--base <BRANCH>'`, before
  any review runs. Focus text goes into the Claude reviewer's prompt only (the
  `if [ -n "${FOCUS:-}" ]` block above). For a *focused* codex pass you need `codex exec`
  with your own prompt instead, which gives up `codex review`'s structured
  output — usually not worth it inside the loop.
- `--model "$CLAUDE_MODEL"` carries whatever the ladder resolved — never a literal
  model name at the call site, or a fallback silently reverts here while the rest of
  the run reports the substitute. `--effort high` is the reasoning tier this panel is
  tuned for. Drop to a lower effort only if the user asks for a cheaper pass, and say
  so in the summary.
- **The three tool flags do different jobs, and the reviewer needs all three.**
  `--tools` sets which tools exist at all — this is the one that makes a reviewer
  read-only; `--allowedTools` only *pre-approves* tools, removing none;
  `--disallowedTools` denies outright. Using `--tools` alone looks right and
  fails in practice: in print mode a tool call that would prompt is recorded as a
  denial instead, so the reviewer silently loses `Bash` calls mid-review.
  Measured on the same review, same prompt: `--tools` alone → 4 denied `Bash`
  calls, and the reviewer could not verify the CLI claims it was checking;
  `--tools` + `--allowedTools` → 0 denials. Keep `--disallowedTools` too: it is
  belt-and-braces if someone later widens `--tools`.
- Do **not** add `--permission-mode acceptEdits`. It auto-accepts edits, which is
  exactly what a reviewer must not be able to do, and with the flags above it
  buys nothing.
- `Bash` is still capable of writing files (`sed -i`, output redirection). The
  tool restriction closes the Edit/Write path; the prompt's "do not modify any
  file" is what covers the rest. If that matters for your repo, drop `Bash` and
  hand the reviewer a pre-computed diff on stdin instead.
- The `timeout` wrapper in the invocation above is **not optional** — see the note
  there. The guard `exit 1`s rather than warning: with `$TO` empty the invocation becomes
  `"" --kill-after=…`, i.e. exit 127 for both reviewers, which is a confusing way to
  discover a missing dependency. If the host genuinely has neither binary, bound the pass
  some other way and say so in the summary; an unbounded reviewer can hang the loop
  silently.

## Unwrapping the Claude reviewer's output

```bash
jq -er 'if .is_error then error(.result // "claude reviewer returned is_error")
        else (.result // empty) end' <"$CLAUDE_RAW" >"$CLAUDE_OUT"
JQ_RC=$?
```

Two cheap sanity checks worth running on the raw JSON:

```bash
jq -r '.modelUsage | keys[]' <"$CLAUDE_RAW"           # confirm $CLAUDE_MODEL actually ran
jq -r '.permission_denials[].tool_name' <"$CLAUDE_RAW" # WHICH tools were denied, not how many
```

**Read the denied tool names, not the count.** The two kinds mean opposite
things:

- `Edit` / `Write` / `NotebookEdit` denied → the read-only guard working as
  designed. The reviewer tried to "helpfully fix" something and was stopped.
  Expected. Not degraded. Worth one line in the pass notes, because a reviewer
  that keeps reaching for Edit is one you should watch for prompt drift.
- `Bash` / `Read` / `Glob` / `Grep` denied → the reviewer was blocked from
  *looking*, so its findings rest on less than it wanted to see. Treat the pass
  as `DEGRADED` for that reviewer, fix the flags (usually a missing
  `--allowedTools`), and re-run before trusting a clean verdict.

A count alone cannot tell these apart, and using it will mark healthy passes
degraded — which, per the skill's finish rules, blocks a legitimate `CLEAN`.

## Parsing findings

Both reviewers tag findings `[P0]`–`[P3]`, but only the Claude reviewer is
**prompted**, so only it puts the tag first. `codex review` cannot take a prompt
alongside `--base`, so its format is whatever the CLI emits — currently markdown
bullets, `- [P1] src/foo.rs:42 - claim`. Parse both with one tolerant pattern:

```bash
FINDING_RE='^[[:space:]]*([-*+][[:space:]]+|[0-9]+[.)][[:space:]]+|#{1,6}[[:space:]]+)?([`*_]{0,2})(\[P[0-3]\]|P[0-3]:)'
grep -cE "$FINDING_RE" "$CODEX_OUT"
grep -cE "$FINDING_RE" "$CLAUDE_OUT"
# per-severity: swap [0-3] for the digit you want
```

It accepts bullets, numbered items, headings, and bold/backtick wrappers, and
requires an unambiguous tag (`[P1]` or `P1:`) so prose like `P10 items remain`,
`**P2** severity means…`, or `P1 findings are listed below` does not score.

**This is not a cosmetic nicety.** Measured across 7 real passes of this panel,
the old first-token rule `^\s*\[P[0-3]\]` matched **0 codex findings in every
pass** while codex had actually filed **43**; the tolerant pattern matched all 43
and every Claude-reviewer finding. A first-token rule cannot report codex as *clean* (the
ambiguity net catches that), but it under-reports codex to the user and trips § 4's
"ambiguous twice in a row" stop condition on a healthy reviewer. If codex's output
shape changes again, widen this pattern — do not narrow it.

Clean signals:

- codex: exit 0, zero findings under the pattern above, **and** the prose says so.
  It is not prompted, so its wording is not contractual — read the output and
  judge. Observed clean phrasings, to calibrate against (append as you see more):
  - `The diagnostic refactor preserves existing runtime behavior, and the runbook
    corrections align with the CLI and persisted error semantics. No actionable
    regressions were found.`

  Note the shape rather than the words: a one-line characterisation of what the
  diff does, then an explicit negative finding statement. A codex pass that
  summarises the diff and then stops *without* that negative statement is
  ambiguous, not clean.
- Claude reviewer: exit 0, `jq` succeeded, and the result is exactly
  `No findings.` (allow surrounding whitespace) — it *is* prompted, so this is
  contractual.

Anything else with zero findings is **ambiguous**, not clean. Surface the log.
Note the asymmetry: a broken parser plus an unpinned clean signal is what turns a
healthy codex pass into "ambiguous". Suspect the parser before the reviewer.

## Merging into `pass-NN.merged.md`

Dedupe on the claim, not the wording. Two findings are the same finding when
they name the same defect in the same code path, even if one says
`src/pay.rs:88` and the other says "the retry branch in `send_payment`".

```markdown
| # | Sev | Source | File:line | Claim | Disposition |
|---|-----|--------|-----------|-------|-------------|
| 1 | P1  | BOTH   | src/pay.rs:88 | Retry path double-charges on 409 | FIX |
| 2 | P2  | CLAUDE | src/db.rs:12  | Migration lacks rollback | DEFER |
| 3 | P2  | CODEX  | src/api.rs:40 | Unbounded response buffer | FIX |
```

When the two reviewers agree a defect exists but disagree about the remedy,
merge them into one row and keep both remedies in the detail below the table —
the disagreement is usually about scope, and the smaller remedy is usually the
right one.

Record contradictions (one reviewer explicitly says the other's target is
correct) as their own row with source `CONFLICT`, and resolve them by reading the
code yourself.

## When a reviewer fails

| Symptom | Read | Do |
|---|---|---|
| `codex` non-zero, auth error in stderr | `$CODEX_ERR` | Surface the exact error. Continue degraded on the Claude reviewer; tell the user to re-auth. |
| `codex` reports the model is unavailable | `$CODEX_ERR` | Retry once with the environment default model; note the fallback in the summary. |
| `jq` exits non-zero (`is_error: true`) | `.result` in `$CLAUDE_RAW` | Usually rate limit (429), overload (529), auth, or an exhausted model. Retry once after a short wait; if it fails again, re-resolve the ladder (§ Resolving) and re-run the pass on the next model. Degrade only once every candidate has failed. |
| The Claude reviewer's model is exhausted or unreachable mid-run | `$CLAUDE_RAW` on **stdout** — not stderr, which is empty | Re-resolve the ladder once and switch `$CLAUDE_MODEL` for the rest of the run, naming the pass it changed at. This is a substitution, not a degradation: the slot is still filled. |
| Claude reviewer returns prose but no `[P*]` and no `No findings.` | `$CLAUDE_OUT` | Ambiguous, not clean. Re-run once; if it repeats, the prompt file is likely truncated — rewrite it. |
| `.permission_denials` contains `Bash`/`Read`/`Glob`/`Grep` | `$CLAUDE_RAW` | The reviewer was blocked from looking. Confirm `--allowedTools` lists every tool in `--tools`, then re-run that reviewer. |
| `.permission_denials` contains only `Edit`/`Write`/`NotebookEdit` | `$CLAUDE_RAW` | Working as intended — the read-only guard fired. Not a failure; do not re-run. |
| Either reviewer times out (exit 124 **or 137**) | the partial output file | Treat as failed for that pass. Do not mine a truncated review for findings. 137 is the `--kill-after` path — counting only 124 spends another full timeout on the same hung reviewer. On the Claude side a timeout is also the signature of an unreachable model, so re-resolve the ladder once before concluding the reviewer is simply slow. |
| Both fail in the same pass | both raw output files | Stop the loop. Nothing reviewed the code; report `BLOCKED`. Read the JSON on stdout, not the stderr files — a Claude-side failure leaves stderr empty. |

A pass whose Claude slot fell through to the **next model in the ladder** is not
degraded — it is a full panel with a substitute, and it must name the substitute.
`DEGRADED` is for a pass that lost a reviewer outright: every ladder candidate failed,
or codex did. The loop can still fix what the survivor found, but it cannot finish
`CLEAN` — only `CLEAN_DEGRADED`, naming the reviewer that never weighed in.

## The inverted (skeptical) audit prompt

Used by § 4a of the skill, not in normal passes. Run it on the Claude reviewer:
it reads the whole repo, so it can tell you what already covers a case. Same
invocation as above, with this prompt:

```bash
cat >"$REVIEW_DIR/claude-audit-prompt.txt" <<EOF
Audit the changes on this branch against ${DIFF_BASE} for OVER-SPECIFICATION,
not for bugs. Another reviewer owns defects; you own scope.

The load-bearing core of this change is: <name it in one or two sentences>.
Leave that alone. Everything else is fair game.

Flag every mechanism, error path, config knob, abstraction, or hardening step
that is NOT required for correctness, security, or data safety and could be cut,
simplified, or deferred. For each item give:
1. What it is (file:line).
2. Why it is not strictly required — name what already covers the case (an
   existing code path, a simpler choice, the stated threat model), or why the
   case does not matter here.
3. A recommendation, tagged: [P2] CUT / [P2] SIMPLIFY / [P2] MARK-OPTIONAL.

Do not flag missing behavior, bugs, or absent tests. Do not modify any file.
If the diff is already minimal for its goal, output exactly: No findings.
EOF
```

Reconcile its output through your own judgment. Accepting every cut is the same
credulity as accepting every finding, pointed the other way.

## The consistency pass prompt

Used by § 4b of the skill — after a panel pass comes back clean, and again after
every fix, until a panel pass and this pass are clean on the same tree. Normal
passes review `git diff <base>`, so they can only see defects inside changed
lines; this one reviews the changed files *and the files that document them* as a
single artifact, and asks whether they still agree. Run it on the Claude reviewer: it opens files
the diff does not show, which is exactly what cross-file agreement requires.

Build the file list from git's own path outputs, never from porcelain status
lines. `git status --porcelain | cut -c4-` looks equivalent and is not: a rename
comes out as the single non-path string `old.txt -> new.txt`, a path containing
whitespace or non-ASCII comes out C-quoted with the quotes attached, and a file
that is both committed-changed and currently dirty appears twice.

```bash
CONSISTENCY_OUT="$REVIEW_DIR/consistency.claude.txt"
CONSISTENCY_RC=0
CONSISTENCY_RAW="$REVIEW_DIR/consistency.claude.raw.json"

# -z everywhere: NUL-delimited output is the only form that survives a path
# containing a newline or tab, which core.quotePath=false alone does not fix.
# cd to the repo root first: git prints root-relative paths, so `[ -e "$f" ]` run
# from a subdirectory would call every changed file "deleted" and tell the reviewer
# not to open it — a clean verdict over an artifact nobody read.
cd "$(git rev-parse --show-toplevel)" || exit 1
# --no-renames so a rename appears as delete+add: the OLD path then reaches DELETED,
# which is what lets the reviewer hunt untouched docs for stale references to it.
changed_z() {
  { git diff -z --no-renames --name-only "$DIFF_BASE...HEAD"
    git diff -z --no-renames --name-only                     # unstaged
    git diff -z --no-renames --name-only --cached            # staged
    git ls-files -z --others --exclude-standard              # untracked
  }
}
# No `sort -zu` here: -z is a GNU extension and BSD/macOS sort rejects it, which
# would empty EXISTING and DELETED and let the reviewer return clean having been
# handed no files at all. Read NUL-delimited (the part that must be exact), then
# ESCAPE each path onto one line with `printf '%q'` before the newline-delimited
# tools touch it. A bare `printf '%s\n'` here re-splits a path containing a newline
# into fragments — `sort -u`, the DELETED filter, and the prompt then all carry
# nonexistent names, and the reviewer skips the real file and reports it clean.
# `%q` leaves an ordinary path byte-identical and renders the pathological ones as
# shell quoting ($'a\nb'), which stays one line per path end to end.
_q() { while IFS= read -r -d "" f; do printf '%q\n' "$f"; done; true; }

# Split into files that still exist and files this change deleted.
# Ask GIT which paths were deleted, not the filesystem. `[ -e "$f" ]` is false for a path
# missing from a sparse checkout and for a present-but-dangling symlink — neither of which
# was deleted — and the prompt below tells the reviewer not to open anything in DELETED.
# That is a clean verdict over part of the artifact nobody read.
# Deletion is a property of the FINAL state, not of any one view. A path deleted in a
# committed commit and RECREATED in the index or worktree appears in the committed diff's
# D-list while its replacement is live — and since EXISTING subtracts DELETED, the live
# file was dropped from the review list and the prompt below told the reviewer not to open
# it. That is the same clean-verdict-over-unread-content this block exists to prevent, one
# level in. So subtract what git says is live NOW: index entries plus untracked files,
# minus any whose worktree copy is gone (an unstaged `rm` leaves the entry in the index).
_LIVE=$( { git ls-files -z --cached
           git ls-files -z --others --exclude-standard
         } | _q | sort -u)
_GONE=$(git ls-files -z --deleted | _q | sort -u)
[ -n "$_GONE" ] && _LIVE=$(printf '%s\n' "$_LIVE" \
                           | { grep -vxF -f <(printf '%s\n' "$_GONE") || true; })
DELETED=$( { git diff -z --no-renames --diff-filter=D --name-only "$DIFF_BASE...HEAD"
             git diff -z --no-renames --diff-filter=D --name-only
             git diff -z --no-renames --diff-filter=D --name-only --cached
           } | _q | sort -u \
           | { [ -n "$_LIVE" ] && { grep -vxF -f <(printf '%s\n' "$_LIVE") || true; } || cat; })
EXISTING=$(changed_z | _q | sort -u \
           | { [ -n "$DELETED" ] && grep -vxF -f <(printf '%s\n' "$DELETED") || cat; })

cat >"$REVIEW_DIR/claude-consistency-prompt.txt" <<EOF
Do not hunt for bugs — another pass owns those. You own INTERNAL AGREEMENT.

Read these files as one artifact — one path per line, shell-quoted where a name
contains unusual characters (a line like $'a\nb' names ONE file):
${EXISTING}

These paths were DELETED by this change. Do not try to open them; instead check
whether anything above still refers to them:
${DELETED:-(none)}

Then go and find the files that DOCUMENT the ones above but were NOT changed — a
README, overview, or summary table that nobody edited is exactly where this drift
hides, and it appears in no diff. Search the repo for references to these paths
and names, and use judgment about which hits are real documentation rather than
incidental mentions. A contradiction between one of those and a changed file IS a
finding, and is the most valuable thing this pass returns.

Report only contradictions:
1. A summary, table, README, or frontmatter that no longer matches the behaviour
   it describes (common after a rule was tightened over several rounds).
2. Two places stating the same rule that have drifted apart — one updated, one not.
3. A constraint in one file that forbids what another file requires.
4. An example, template, or schema that no longer matches what it documents.
5. A documented flag, path, command, section number, or field that does not exist.

For each: both locations (file:line), the exact contradiction, and which side you
believe is correct and why.

Do not propose new features or mechanism. Do not modify any file.
If they are consistent with each other, output exactly: No findings.
EOF
```

Note the **three-dot** `$DIFF_BASE...HEAD` when listing changed files: two dots
compares the two tips, so once the base advances past the fork point it reports
upstream files this branch never touched, and the reviewer wastes the pass on
code that is not yours.

Run it with the same invocation as the panel's Claude reviewer (same model,
effort, and the three tool flags), pointing at this prompt file and these output
files:

```bash
TO=$(command -v timeout || command -v gtimeout) \
  || { echo "no GNU timeout — see the panel invocation above"; exit 1; }
"$TO" --kill-after=60 1500 \
  claude -p "$(cat "$REVIEW_DIR/claude-consistency-prompt.txt")" \
  --model "$CLAUDE_MODEL" --effort high --output-format json \
  --tools "Bash,Read,Glob,Grep" --allowedTools "Bash,Read,Glob,Grep" \
  --disallowedTools "Edit,Write,NotebookEdit" \
  </dev/null >"$CONSISTENCY_RAW" 2>"$REVIEW_DIR/consistency.claude.stderr.txt" \
  || CONSISTENCY_RC=$?   # `||`, so a 124/137 timeout under `set -e` does not kill the
                         # shell before the status is captured — and captured BEFORE any
                         # pipeline replaces it
[[ "$CONSISTENCY_RC" -eq 0 ]] \
  || { echo "consistency reviewer exited $CONSISTENCY_RC (124/137 = timeout) — NOT clean"; exit 1; }
jq -er 'if .is_error then error(.result // "err") else (.result // empty) end' \
  <"$CONSISTENCY_RAW" >"$CONSISTENCY_OUT"
```

A timed-out reviewer can still leave syntactically valid JSON on disk — killed during
teardown, say — and `jq` succeeding on it would replace the 124/137 with 0. Capture the
reviewer's own status first; a pass that did not finish is never clean.

On a `--reviewers codex` pinned run, use
`codex exec --sandbox read-only "$(cat ...)" </dev/null` with the same prompt instead
(the `</dev/null` for the same reason as the panel invocations above — a reviewer that
decides to read stdin blocks until the timeout kills it, which looks like a slow review
rather than a stuck one) —
`codex review --base` cannot take one. The `--sandbox read-only` is not optional:
`codex exec` is a general coding agent, and if the local config is
workspace-writable it may try to *fix* a contradiction, mutating the tree during
the final check so that any `CLEAN` no longer describes the reviewed tree. Re-runs after a fix
overwrite these files; keep the round in the name (`consistency-02.*`) if you
want the history.

Fix findings the same way as any other: verify first, and prefer correcting
whichever side is genuinely wrong over editing both until they match — matching
two wrong things is still wrong.
