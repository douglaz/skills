# Reviewer Panel

Exact invocations for the two default reviewers, the Claude reviewer's prompt,
and what to do when one of them fails. Load this before the first pass.

## Why two

`codex review` and the Claude reviewer fail in different directions, which is
the whole reason to pay for both:

| | `codex review` | Claude Fable (`--effort high`) |
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

## Setup, once per pass

```bash
PASS_ID=$(printf '%02d' "$N")
CODEX_OUT="$REVIEW_DIR/pass-${PASS_ID}.codex.txt"
CODEX_ERR="$REVIEW_DIR/pass-${PASS_ID}.codex.stderr.txt"
FABLE_RAW="$REVIEW_DIR/pass-${PASS_ID}.fable.raw.json"
FABLE_OUT="$REVIEW_DIR/pass-${PASS_ID}.fable.txt"
FABLE_ERR="$REVIEW_DIR/pass-${PASS_ID}.fable.stderr.txt"
PASS_MERGED="$REVIEW_DIR/pass-${PASS_ID}.merged.md"
PASS_NOTES="$REVIEW_DIR/pass-${PASS_ID}.notes.md"
FABLE_PROMPT_FILE="$REVIEW_DIR/fable-prompt.txt"
```

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
} >"$FABLE_PROMPT_FILE"
```

The `if` form (rather than `[ -n ... ] && printf`) is deliberate: the `&&` form
returns non-zero when `FOCUS` is unset, which aborts the whole group under
`set -e`.

## Running the panel

Both reviewers start together and neither sees the other's output.

```bash
codex review --base "$DIFF_BASE" \
  -c 'model="gpt-5.6-sol"' -c 'model_reasoning_effort="xhigh"' \
  </dev/null >"$CODEX_OUT" 2>"$CODEX_ERR" &
CODEX_PID=$!

claude -p "$(cat "$FABLE_PROMPT_FILE")" \
  --model fable \
  --effort high \
  --output-format json \
  --tools "Bash,Read,Glob,Grep" \
  --allowedTools "Bash,Read,Glob,Grep" \
  --disallowedTools "Edit,Write,NotebookEdit" \
  </dev/null >"$FABLE_RAW" 2>"$FABLE_ERR" &
FABLE_PID=$!

wait "$CODEX_PID"; CODEX_RC=$?
wait "$FABLE_PID"; FABLE_RC=$?
```

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
- `--model fable` resolves to the current Fable model; `--effort high` is the
  reasoning tier this panel is tuned for. Drop to a lower effort only if the user
  asks for a cheaper pass, and say so in the summary.
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
- If `timeout` is available, wrapping each reviewer (`timeout 900 ...`) bounds a
  hung pass. Treat exit 124 as a reviewer failure, not as clean.

## Unwrapping the Claude reviewer's output

```bash
jq -er 'if .is_error then error(.result // "claude reviewer returned is_error")
        else (.result // empty) end' <"$FABLE_RAW" >"$FABLE_OUT"
JQ_RC=$?
```

Two cheap sanity checks worth running on the raw JSON:

```bash
jq -r '.modelUsage | keys[]' <"$FABLE_RAW"           # confirm a fable model actually ran
jq -r '.permission_denials[].tool_name' <"$FABLE_RAW" # WHICH tools were denied, not how many
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
grep -cE "$FINDING_RE" "$FABLE_OUT"
# per-severity: swap [0-3] for the digit you want
```

It accepts bullets, numbered items, headings, and bold/backtick wrappers, and
requires an unambiguous tag (`[P1]` or `P1:`) so prose like `P10 items remain`,
`**P2** severity means…`, or `P1 findings are listed below` does not score.

**This is not a cosmetic nicety.** Measured across 7 real passes of this panel,
the old first-token rule `^\s*\[P[0-3]\]` matched **0 codex findings in every
pass** while codex had actually filed **43**; the tolerant pattern matched all 43
and every Fable finding. A first-token rule cannot report codex as *clean* (the
ambiguity net catches that), but it under-reports codex to the user and trips § 4's
"ambiguous twice in a row" stop condition on a healthy reviewer. If codex's output
shape changes again, widen this pattern — do not narrow it.

Clean signals:

- codex: exit 0, zero findings under the pattern above, **and** the prose says so.
  Its exact clean wording is not pinned here because it is not prompted and no
  clean codex pass has been observed to quote — so read the output and judge, and
  when you do see one, record the phrasing here.
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
| 2 | P2  | FABLE  | src/db.rs:12  | Migration lacks rollback | DEFER |
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
| `jq` exits non-zero (`is_error: true`) | `.result` in `$FABLE_RAW` | Usually rate limit (429), overload (529), or auth. Retry once after a short wait; if it fails again, continue degraded on codex. |
| Claude reviewer returns prose but no `[P*]` and no `No findings.` | `$FABLE_OUT` | Ambiguous, not clean. Re-run once; if it repeats, the prompt file is likely truncated — rewrite it. |
| `.permission_denials` contains `Bash`/`Read`/`Glob`/`Grep` | `$FABLE_RAW` | The reviewer was blocked from looking. Confirm `--allowedTools` lists every tool in `--tools`, then re-run that reviewer. |
| `.permission_denials` contains only `Edit`/`Write`/`NotebookEdit` | `$FABLE_RAW` | Working as intended — the read-only guard fired. Not a failure; do not re-run. |
| Either reviewer times out (exit 124) | the partial output file | Treat as failed for that pass. Do not mine a truncated review for findings. |
| Both fail in the same pass | both stderr files | Stop the loop. Nothing reviewed the code; report `BLOCKED`. |

A pass that lost a reviewer is `DEGRADED`. The loop can still fix what the
survivor found, but it cannot finish `CLEAN` — only `CLEAN_DEGRADED`, naming the
reviewer that never weighed in.

## The inverted (skeptical) audit prompt

Used by § 4a of the skill, not in normal passes. Run it on the Claude reviewer:
it reads the whole repo, so it can tell you what already covers a case. Same
invocation as above, with this prompt:

```bash
cat >"$REVIEW_DIR/fable-audit-prompt.txt" <<EOF
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
single artifact, and asks whether they still agree. Run it on Fable: it opens files the diff does
not show, which is exactly what cross-file agreement requires.

Build the file list from git's own path outputs, never from porcelain status
lines. `git status --porcelain | cut -c4-` looks equivalent and is not: a rename
comes out as the single non-path string `old.txt -> new.txt`, a path containing
whitespace or non-ASCII comes out C-quoted with the quotes attached, and a file
that is both committed-changed and currently dirty appears twice.

```bash
CONSISTENCY_OUT="$REVIEW_DIR/consistency.fable.txt"
CONSISTENCY_RAW="$REVIEW_DIR/consistency.fable.raw.json"

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
# dedupe with plain `sort -u` once the paths are already newline-delimited.

# Split into files that still exist and files this change deleted. `|| true` on the
# loop keeps a trailing deleted path from leaving status 1 and aborting under `set -e`.
EXISTING=$(changed_z | { while IFS= read -r -d "" f; do [ -e "$f" ] && printf '%s\n' "$f"; done; true; } | sort -u)
DELETED=$( changed_z | { while IFS= read -r -d "" f; do [ -e "$f" ] || printf '%s\n' "$f"; done; true; } | sort -u)

cat >"$REVIEW_DIR/fable-consistency-prompt.txt" <<EOF
Do not hunt for bugs — another pass owns those. You own INTERNAL AGREEMENT.

Read these files as one artifact:
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
claude -p "$(cat "$REVIEW_DIR/fable-consistency-prompt.txt")" \
  --model fable --effort high --output-format json \
  --tools "Bash,Read,Glob,Grep" --allowedTools "Bash,Read,Glob,Grep" \
  --disallowedTools "Edit,Write,NotebookEdit" \
  </dev/null >"$CONSISTENCY_RAW" 2>"$REVIEW_DIR/consistency.fable.stderr.txt"
jq -er 'if .is_error then error(.result // "err") else (.result // empty) end' \
  <"$CONSISTENCY_RAW" >"$CONSISTENCY_OUT"
```

On a `--reviewers codex` pinned run, use
`codex exec --sandbox read-only "$(cat ...)"` with the same prompt instead —
`codex review --base` cannot take one. The `--sandbox read-only` is not optional:
`codex exec` is a general coding agent, and if the local config is
workspace-writable it may try to *fix* a contradiction, mutating the tree during
the final check so that any `CLEAN` no longer describes the reviewed tree. Re-runs after a fix
overwrite these files; keep the round in the name (`consistency-02.*`) if you
want the history.

Fix findings the same way as any other: verify first, and prefer correcting
whichever side is genuinely wrong over editing both until they match — matching
two wrong things is still wrong.
