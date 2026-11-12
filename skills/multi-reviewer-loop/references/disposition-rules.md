# Finding Disposition Rules

Load this file when classifying findings during the fix-and-validate phase.

Classify the **merged** findings, one disposition per real defect. If both
reviewers raised the same defect, that is one finding with one disposition, not
two.

## Classification

Before editing, re-rate every finding P0–P3 on the Reviewer rubric. The
orchestrator judges: a Reviewer's tag is evidence, not a verdict. Lowering a
Reviewer's P0/P1 needs a one-line reason with file:line evidence; raising a rating
to P0/P1 names the applicable clause in one line.

P0 is critical: data or money loss, a secret exposed, a security hole, a crash or
corruption of core function, or the deliverable fundamentally fails its brief.
P1 blocks acceptance: wrong behaviour in a supported case, a brief requirement
unmet, a test or gate that cannot fail or fails for the wrong reason, or a
requirement made false or contradictory (following it would behave wrongly, or
two requirements cannot both hold). Any reachable money-loss, misdirected-money,
secret-exposure or data-corruption defect is at least P1. P2 is a real defect
that does not block; P3 changes neither behaviour, requirements nor a check's
ability to catch a defect. A false requirement is P1 if following it would behave
wrongly, otherwise at least P2; a false code comment is P3. The former
"no cosmetic beads" bar now separates P2 from P3, not filed from unfiled.

Only P0/P1 defects introduced by the whole change since `DIFF_BASE`, or leaving
the brief unmet, send work back. Classify each finding as `FIX`, `FILE`, `DEFER`,
`REJECT`, or `CUT/SIMPLIFY`.

- **FIX**: default for an introduced or brief-blocking P0/P1 only. The finding
  is plausible, in scope, and can be addressed safely in this loop. A `FIX` for an *untested-behavior* finding is
  not complete until a mutation has failed **for every property the test claims**
  — invert each one in turn and watch *that property's assertion* go red, not
  merely something. A test that stays green against the very defect it was
  written for has closed nothing; one that reddens on an unrelated panic has
  proved nothing either; and one red run across a test asserting two independent
  properties leaves the second untested while looking verified.
- **FILE**: every verified P2/P3 and every older P0/P1 that predates the change
  and is outside its brief. Keep it as a follow-up; never repair a P2/P3 in this
  change, even alongside a P0/P1 repair or when its fix touches the same lines.
  Older P0/P1 findings are also named in the report and do not hold this work.
- **DEFER**: an introduced or brief-blocking P0/P1 whose safe fix needs a broader
  refactor, product decision, policy call, or cross-team coordination. Keep it
  open and stop for that decision. Do not call it a false positive.
- **REJECT**: allowed only when you have direct counter-evidence from code,
  tests, docs, or the diff. (The finding is *wrong*.)
- **CUT/SIMPLIFY**: the finding may be correct *as stated*, but implementing it
  (or the proposed shape of it) adds mechanism, handling, config, abstraction,
  or hardening that no real correctness, security, or data-loss requirement
  needs. Don't build it as asked — skip it, build a smaller version, or mark it
  optional/deferred. This is a *scope* decision, not a claim the finding is
  false, so it doesn't need REJECT's counter-evidence — but it must pass the
  over-specification test below. (The finding is *not worth building*.)

## Cross-reviewer signals

Each merged finding carries a source tag: `BOTH`, `CODEX`, `CLAUDE`, or
`CONFLICT`. The tag changes *ordering and attention*, never the evidence bar.

It names the **slot**, not the model that filled it. A mid-run fallback must not
split one slot's findings across two tag names: `BOTH` would then be reachable from
a single slot reviewed twice, and the one thing the tag is for — two *independent*
reads agreeing — is exactly what that would not be.

- **`BOTH`** — two independent reads found the same defect. Among P0/P1 repairs, fix these first.
  Agreement raises confidence that the defect is real; it says nothing about
  whether the proposed remedy is right, so the over-specification test still
  applies. Two reviewers can both talk you into building something no
  requirement needs.
- **`CODEX` / `CLAUDE` only** — normal disposition, normal evidence bar. The
  reviewers have different visibility: `codex review` sees the diff against the
  base, while the Claude reviewer reads out into the repo. Each one routinely
  catches things the other structurally cannot see. A single-source P1 is still
  a P1.
- **`CONFLICT`** — one reviewer asserts a defect the other explicitly calls
  correct. Resolve by reading the code yourself and citing `file:line`. Do not
  split the difference, do not defer to the more alarming read, and do not defer
  to the reviewer that was right last time. Record which one was right; a
  reviewer that is confidently wrong about the changed code is worth knowing
  about for the rest of the loop.

**Silence is not counter-evidence.** "The other reviewer didn't flag it" is not
on the REJECT evidence list below and never becomes one. One reviewer missing a
defect is the expected case — it is why there are two.

**Agreement is not validation either.** Both reviewers reading the same diff can
share the same wrong assumption about code neither opened. When a `BOTH` finding
rests on a claim about behavior outside the diff, verify that claim before
fixing, exactly as you would for a single-source finding.

## REJECT evidence bar

The bar for `REJECT` is high. Reject only when you can point to specific
evidence for at least one of these:

- the issue is already handled by current code or tests
- the behavior is explicitly intended by user instructions, repo docs, or
  nearby code comments
- the finding depends on an outdated or incorrect assumption about the
  framework, API, or code path

## Invalid rejection reasons

Do not reject a finding for any of these reasons:

- it is "only" P2 or P3 — it is `FILE` instead
- you could not reproduce it quickly
- the fix feels inconvenient, noisy, or higher churn than you want
- the change might be intentional, but you have no proof
- CI, lint, typecheck, or tests might catch it later
- unrelated validation passed after your edits
- only one reviewer raised it, or the other reviewer stayed silent about it

These are invalid for `REJECT` *and* for `CUT/SIMPLIFY`. `CUT` is not "this is
annoying to write" — that's churn, and churn is not a reason. `CUT` is "omitting
this leaves no real hole." The two are different claims; keep them separate.

## The over-specification test (for CUT / SIMPLIFY)

Apply to any finding that proposes new mechanism, handling, hardening, config,
or abstraction. Ask: **if I simply don't do this, what actually breaks — a real
correctness / security / data-loss / broken-trust problem, or merely an
operational inconvenience or a not-strictly-needed nicety?**

- Real correctness / security / data-loss / trust break → rate it, then `FIX`
  (or `DEFER` if the safe fix needs a decision) only for an introduced or
  brief-blocking P0/P1; otherwise `FILE`.
- Only operational, defense-in-depth, or "would be nicer" → `CUT`, `SIMPLIFY`,
  or `MARK-OPTIONAL`. Name what already covers the case (an existing path, a
  simpler choice, the user's stated threat model) or why the case doesn't
  matter, and record it like a rejection. An accepted suggestion is listed once
  in the report, not filed. If it is actually a P0–P3 defect, use that finding's
  disposition; `CUT` cannot bypass `FILE` for a verified P2/P3.

Watch the asymmetry: a review loop almost always pushes toward *adding*. Nothing
in it pushes back toward simplicity unless you do. A finding that is "valid" yet
grows the change without earning its keep is still over-specification, and
shipping it makes the result worse, not better — more to build, test, and keep
correct.

When a `FIX` is warranted but the proposed remedy is heavier than the problem,
`SIMPLIFY`: make the smallest change that closes the real hole, not the largest
the finding implies. That is about the *weight* of the mechanism, not its reach —
it still applies at every site of the class, per the per-finding workflow below.

## Meta-signals across passes

- **Zero `REJECT` and zero `CUT` across many findings is a red flag.** A healthy
  loop disputes some findings. If you have accepted everything for several
  passes, you are probably being too credulous — re-read your recent fixes for
  over-specification before running another pass.
- **Each fix is new review surface.** Fixing a finding by *adding* a mechanism
  creates that mechanism's own edge cases, which the next pass will dutifully
  flag. If the loop keeps generating roughly as many findings as it resolves and
  they are getting more peripheral, that is a fractal tail, not convergence.
  Stop adding. Run a skeptical / over-specification audit (an inverted pass that
  hunts what to *cut*, not what to add) and reconcile, rather than spending more
  normal passes.
- **The other cause of a flat count is line-by-line fixing, and it needs the
  opposite correction.** If the new findings are mostly "this rule is stale in a
  file you did not edit" or "the snippet you fixed has a sibling that still has the
  bug", you are not over-building — you are under-sweeping. Cutting would remove
  correct material and leave the drift. Go back and close each finding as a class
  (see the per-finding workflow above). Diagnose by asking whether a finding is
  about something the last pass *added* (audit) or *failed to update* (sweep).
- **A reviewer going quiet is a convergence signal, not a broken reviewer.** If
  one reviewer has reported clean for two or more consecutive passes while the
  other keeps producing findings, the quiet one is telling you the core is done
  and the loud one is mining the tail. Check the loud reviewer's recent findings
  for the fractal-tail pattern before spending another pass on them. (First rule
  out the boring explanation: confirm the quiet reviewer actually ran and exited
  0 rather than failing silently.)
- **Whose findings you accept, tracked across passes, is worth a glance.** If
  every accepted finding for several passes came from one reviewer while every
  finding from the other was rejected or cut, either that reviewer is
  mis-tuned for this repo, or you have stopped reading its findings on their
  merits. Both are worth a moment before the next pass.

## Priority guidance

- **P0/P1**: fix unless disproved when introduced by the change or leaving its
  brief unmet; older P0/P1 outside the brief are `FILE` (`review-preexisting`).
- **P2**: `FILE` (`review-followup`).
- **P3**: `FILE` (`review-nit`).
- A P2/P3 is `FILE` even in a pass that fixes a P0/P1, even on the same lines.
- **Subjective style-only feedback** can be skipped only when no project rule,
  concrete bug risk, or user preference supports it.
- Missing validation, missing tests for changed behavior, unhandled enum or
  state cases, missing error handling, and missing guards are not "subjective"
  just because they are lower priority.

## Filing follow-ups

Keep the accepted FILE list across passes and supply it to prompted reviewers
under "Follow-ups (filed when the work ends; do not fix, do not report again)".
A listed follow-up is not a finding again unless rated P0/P1 with a reason.
Recheck before each next brief or prompted pass and at the workflow's finish;
keep only follow-ups that still hold in the repository with the accepted work.
The owning skill specifies the reference state. Report items a later repair removed as
resolved, not filed.

First search open issues. File one issue per distinct defect: only the same
defect already covered by an open issue of equal or higher priority becomes a
comment on that issue. Sharing a requirement or code path is not enough. Two
distinct P3s are two beads.

Each filed item carries what is wrong, file:line evidence at the commit where it
was seen (identify uncommitted evidence too), the Reviewers that raised it, its
severity and a one-line reason it is not higher, the smallest fix and how to
verify it, and its source task, Run Directory or PR.

| Kind | Priority | Type | Label | Link |
|---|---|---|---|---|
| P2 | 2 | `task` | `review-followup` | `related` to source bead |
| P3 | 3 | `task` | `review-nit` | `related` to source bead |
| Older P0/P1 outside the brief | 0 or 1, its own | `task` | `review-preexisting` | `related` to source bead |

For beads writes, load [`beads-jsonl-path`](../../beads-jsonl-path/SKILL.md),
resolve and check the JSONL before writing, review every write and flush through
that companion. Drains skip `review-nit` unless the owner asks
(`br ready --exclude-label review-nit`); a delegated drain also excludes
`review-followup` until the owner names it. No drain excludes `review-preexisting`.
Without beads use the repository's tracker; without any tracker, put the list in
the report or PR body. Do not create a tracker for this purpose.

## Per-finding workflow

For each finding you `FIX` (a `DEFER` stops before editing):

1. Read the referenced code and nearby context
2. Inspect any claimed safeguard, test, or doc before deciding
3. Make the smallest fix that closes the **whole class** — not the smallest fix to
   the cited line. Small in mechanism, complete in coverage: a reviewer cites the
   one site it read, and the same rule, snippet, or corrected fact usually appears
   in two or three other places that are now stale, or outright contradicting the
   site you just fixed. Grep a distinctive phrase before moving on.
4. Re-read the edited code, and `grep -rn` the stale phrasing repo-wide to confirm
   the class is gone — not just the one file
5. Note the disposition, the source tag, and the evidence in `"$PASS_NOTES"`

For each `CONFLICT`:

1. Read the disputed code yourself and decide with `file:line` evidence
2. Record the winner and the evidence in `"$PASS_NOTES"` — this is the one
   disposition always worth surfacing in chat, because a confident reviewer was
   wrong about code you are shipping
3. Dispose of the surviving claim normally (`FIX` / `FILE` / `DEFER` / `REJECT` / `CUT`)

For each finding you `REJECT`:

1. Record a one-line rationale plus concrete file or test evidence in
   `"$PASS_NOTES"`
2. Mention it in chat only if it affects the pass outcome

If you cannot point to concrete evidence, do not reject it. Leave it as
`FIX` or `DEFER` for an introduced or brief-blocking P0/P1; verify other
findings and `FILE` them when upheld.

For each finding you `FILE`:

1. Verify and record its evidence, rating, source and proposed smallest fix in
   `"$PASS_NOTES"`; keep it in the follow-up list for later prompted passes.
2. Do not edit it. At the finish, apply the filing procedure above.

For each finding you `CUT/SIMPLIFY`:

1. Record the over-specification test result in `"$PASS_NOTES"`: what would
   break if omitted (nothing real), and what already covers the case.
2. If you `SIMPLIFY` an introduced or brief-blocking P0/P1 remedy, make the
   minimal change and note why the smaller shape is sufficient. P2/P3 remain
   FILE; accepted suggestions are only listed, not implemented.
3. Surface cuts in the finish report alongside rejections, so the user can see
   what was deliberately not built.

## Recurrence rule

If a materially identical finding reappears on the next pass after you
rejected it, assume your rejection may have been wrong. Re-verify from
scratch before calling it a persistent false positive.

**A rejected finding that comes back from the *other* reviewer is stronger
evidence than a repeat from the same one.** A reviewer repeating itself may just
be reading the same code the same wrong way; a second, independent reviewer
arriving at the claim you disproved means your counter-evidence probably does not
say what you thought it said. Re-verify that one before anything else in the
pass.
