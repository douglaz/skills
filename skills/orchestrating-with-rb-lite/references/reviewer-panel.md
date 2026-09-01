# Customizing the reviewer panel

Read this **only** when overriding rb-lite's built-in panel for a reason you can name.
The default (codex + a claude defect reviewer + a claude skeptic) is the recommended path.
From rb-lite 0.5.0, `--reviewers-file` replaces only the **gating** reviewers; declare
advisory ones in `.rb-lite-skeptics` / `--skeptics-file`, where they stay advisory. Also
documents the reviewer contract every custom command must satisfy.

## Customizing the panel

rb-lite's built-in panel is `codex review` + a `claude` defect reviewer + a `claude`
skeptic, and this skill uses it as-is. Override only for a reason you can name. The block
below is a **menu**, not a file to paste — the last entry is a placeholder that exists on no
PATH. The skeptic line belongs in `.rb-lite-skeptics`, never in `.rb-lite-reviewers`; the
other two are gating reviewers. On 0.3.x/0.4.x there is no second file, and a pasted panel
that omits the skeptic returns the loop to add-only pressure:

```bash
# .rb-lite-reviewers  (gating: the codex and claude defect reviewers)
codex review --base "$BASE" -c 'model="gpt-5.6-sol"'
set -o pipefail; claude -p "Review the diff vs $BASE. Before asserting the diff violates or overstates an invariant, or any claim about behavior in code the diff does not show, verify it by reading that code and cite file:line, else mark it a QUESTION not a finding. Tag findings P0/P1/P2/P3. Output 'No findings.' if clean." --model claude-opus-5 --output-format json --allowedTools "Read,Glob,Grep" --disallowedTools "Edit,Write,NotebookEdit,Bash" | jq -er 'if .is_error then error(.result // "claude reviewer returned is_error") else (.result // empty) end'
# .rb-lite-skeptics  (advisory) -- hunts over-specification instead of bugs, so the panel has counter-pressure against scope creep
set -o pipefail; claude -p "Review the diff vs $BASE for OVER-SPECIFICATION, not bugs. Flag any mechanism, handling, config, or abstraction that is NOT required for correctness, security, or data-safety and could be cut, simplified, or deferred. For each, give: what it is, why it isn't strictly required (what already covers the case), and a recommendation. Tag each finding 'P2: CUT', 'P2: SIMPLIFY', or 'P2: DEFER'. Do not flag missing behavior or bugs; another reviewer owns that. Output 'No findings.' if the diff is already minimal for its goal." --model claude-opus-5 --output-format json --allowedTools "Read,Glob,Grep" --disallowedTools "Edit,Write,NotebookEdit,Bash" | jq -er 'if .is_error then error(.result // "skeptic reviewer returned is_error") else (.result // empty) end'
(my-linter --json || true) | wrap-as-p-tags
```

Put a skeptic in `.rb-lite-skeptics`, never in `.rb-lite-reviewers`. A skeptic listed as a
gating reviewer is treated as one: its findings start rounds, and with every defect reviewer
clean it drives the run to `consensus_failure` (13). On rb-lite 0.3.x/0.4.x there was no
second file and that was unavoidable — the reason the split exists.

The skeptical reviewer is the practical form of "add a third reviewer for
counter-pressure" above: its `CUT` / `SIMPLIFY` / `DEFER` findings tell the
implementer to *remove* surface, balancing the two panel reviewers that only
ever push to add. Worth adding for any non-trivial bead; skip it for a tiny,
already-bounded one.

**Put the verify-before-asserting rule in every custom reviewer prompt**: *"Before
asserting the diff violates or overstates an invariant — or any claim about
behavior in code the diff does not show — verify it by reading that code and cite
`file:line`; if you cannot, mark it a QUESTION, not a finding."* Reviewers see only
the diff, so a confidently-wrong claim about an invariant guaranteed in an
unchanged file will otherwise get an implementer to corrupt a correct comment, then
echo through later rounds. The **claude** reviewer carries this
rule; **`codex review`** cannot — `codex review` rejects a custom
`[PROMPT]` together with `--base` (they are mutually exclusive), so codex stays
diff-blind to out-of-diff invariants. Lean on the implementer guard (do not weaken
invariant comments without code proof) and the landed-diff comment-truth check as
the backstop for codex's findings; or replace the default codex reviewer with a
`codex exec`-based one in `.rb-lite-reviewers` if you want the guard on it (at the
cost of `codex review`'s structured output).

Reviewer commands run **concurrently**, get `BASE`/`RUN_DIR`/`ROUND`/
`REVIEWER_INDEX` in env, and have stdin closed. The panel succeeds with
at least one exit-0 **gating** reviewer — skeptics are advisory, so a panel carried only by
them is a failed panel (exit 11). Failed reviewers are noted but don't abort
the run.

The reviewer contract is strict:
- Findings on stdout, prefixed near the start of the line with the
  severity tag (`P2:`, `[P2]`, `**P2**:`, `Issue 1 (P2):`, …).
- Successful reviewer stderr is treated as tool noise and is not fed back to
  the implementer; failed reviewer stderr gets a tail in that reviewer's
  markdown file.
- Exit 0 = real review; exit non-zero = tool failure (output may be
  partial). Findings detection ignores non-zero reviewers, and failed reviewer
  files are not included in `REVIEW_FILES` for the next implementer round. A
  linter that exits non-zero on findings must be wrapped: `mylinter || true`.

## Measured: which panel each file combination produces

`AGENTS.md` requires a claim about tool behaviour to carry a run rather than a recollection,
so the fallback rules above are recorded rather than asserted. Measured 2026-09-01 against
`rb-lite 0.5.0` (`rb-lite --version`), in a throwaway git repo with every reviewer replaced
by a stub on `PATH` — `gate1`/`skep` print one line, the `claude` stub appends its argv to a
file outside the repo so the built-in skeptic's invocation is countable, and streams are
separated by redirection:

```bash
rb-lite run --task t --max-rounds 1 --max-iters 2 \
  --implement-cmd impl --base master --run-dir "$RUN" >"$RUN.out" 2>"$RUN.err"
# panel size:      grep -oE 'panel starting with [0-9]+' "$RUN/log.txt"
# built-in ran?:   grep -c OVER-SPECIFICATION "$CLAUDE_CALLS"
```

| `.rb-lite-reviewers` | `.rb-lite-skeptics` | exit | panel | built-in skeptic prompted |
| --- | --- | --- | --- | --- |
| absent | absent | 0 | 3 | 1 |
| present | absent | 0 | 2 | 1 |
| absent | present | 0 | 3 | 0 |
| present | present | 0 | 2 | 0 |
| present | empty | 0 | 2 | 1 |
| present | comments only | 0 | 2 | 1 |

Row 2 is the one that changed in 0.5.0: a supplied gating panel keeps its counter-pressure.
Rows 5 and 6 show the empty/comments-only fallback. What this does NOT show is *why* any row
behaves as it does, and it says nothing about 0.3.x/0.4.x, which were not run here — on those
versions a reviewers file replaces the whole panel.
