# Finding Disposition Rules

Load this file when classifying findings during the fix-and-validate phase.

## Classification

Before editing, classify each finding as `FIX`, `DEFER`, `REJECT`, or
`CUT/SIMPLIFY`.

- **FIX**: default outcome. The finding is plausible, in scope, and can be
  addressed safely in this loop.
- **DEFER**: the finding still looks real or plausible, but the safe fix needs
  a broader refactor, product decision, policy call, or cross-team
  coordination. Keep it open. Do not call it a false positive.
- **REJECT**: allowed only when you have direct counter-evidence from code,
  tests, docs, or the diff. (The finding is *wrong*.)
- **CUT/SIMPLIFY**: the finding may be correct *as stated*, but implementing it
  (or the proposed shape of it) adds mechanism, handling, config, abstraction,
  or hardening that no real correctness, security, or data-loss requirement
  needs. Don't build it as asked — skip it, build a smaller version, or mark it
  optional/deferred. This is a *scope* decision, not a claim the finding is
  false, so it doesn't need REJECT's counter-evidence — but it must pass the
  over-specification test below. (The finding is *not worth building*.)

## REJECT evidence bar

The bar for `REJECT` is high. Reject only when you can point to specific
evidence for at least one of these:

- the issue is already handled by current code or tests
- the behavior is explicitly intended by user instructions, repo docs, or
  nearby code comments
- the reported problem is pre-existing in `DIFF_BASE` and unrelated to this
  branch's changes
- the finding depends on an outdated or incorrect assumption about the
  framework, API, or code path

## Invalid rejection reasons

Do not reject a finding for any of these reasons:

- it is "only" P2 or P3
- you could not reproduce it quickly
- the fix feels inconvenient, noisy, or higher churn than you want
- the change might be intentional, but you have no proof
- CI, lint, typecheck, or tests might catch it later
- unrelated validation passed after your edits

These are invalid for `REJECT` *and* for `CUT/SIMPLIFY`. `CUT` is not "this is
annoying to write" — that's churn, and churn is not a reason. `CUT` is "omitting
this leaves no real hole." The two are different claims; keep them separate.

## The over-specification test (for CUT / SIMPLIFY)

Apply to any finding that proposes new mechanism, handling, hardening, config,
or abstraction. Ask: **if I simply don't do this, what actually breaks — a real
correctness / security / data-loss / broken-trust problem, or merely an
operational inconvenience or a not-strictly-needed nicety?**

- Real correctness / security / data-loss / trust break → `FIX` (or `DEFER` if
  the safe fix is broad).
- Only operational, defense-in-depth, or "would be nicer" → `CUT`, `SIMPLIFY`,
  or `MARK-OPTIONAL`. Name what already covers the case (an existing path, a
  simpler choice, the user's stated threat model) or why the case doesn't
  matter, and record it like a rejection.

Watch the asymmetry: a review loop almost always pushes toward *adding*. Nothing
in it pushes back toward simplicity unless you do. A finding that is "valid" yet
grows the change without earning its keep is still over-specification, and
shipping it makes the result worse, not better — more to build, test, and keep
correct.

When a `FIX` is warranted but the proposed remedy is heavier than the problem,
`SIMPLIFY`: make the smallest change that closes the real hole, not the largest
the finding implies.

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

## Priority guidance

- **P0/P1**: fix unless you can directly disprove the finding.
- **P2/P3**: fix when the issue is concrete and the remedy is low or medium risk.
  If the finding remains plausible but the fix is broader or riskier, mark it
  `DEFER` and surface it at the end instead of dismissing it.
- **Subjective style-only feedback** can be skipped only when no project rule,
  concrete bug risk, or user preference supports it.
- Missing validation, missing tests for changed behavior, unhandled enum or
  state cases, missing error handling, and missing guards are not "subjective"
  just because they are lower priority.

## Per-finding workflow

For each finding you `FIX` or `DEFER`:

1. Read the referenced code and nearby context
2. Inspect any claimed safeguard, test, or doc before deciding
3. Make the smallest correct fix when fixing
4. Re-read the edited code
5. Note the disposition and evidence in `"$PASS_NOTES"`

For each finding you `REJECT`:

1. Record a one-line rationale plus concrete file or test evidence in
   `"$PASS_NOTES"`
2. Mention it in chat only if it affects the pass outcome

If you cannot point to concrete evidence, do not reject it. Leave it as
`FIX` or `DEFER`.

For each finding you `CUT/SIMPLIFY`:

1. Record the over-specification test result in `"$PASS_NOTES"`: what would
   break if omitted (nothing real), and what already covers the case.
2. If you `SIMPLIFY` rather than skip, make the minimal change and note why the
   smaller shape is sufficient.
3. Surface cuts in the finish report alongside rejections, so the user can see
   what was deliberately not built.

## Recurrence rule

If a materially identical finding reappears on the next pass after you
rejected it, assume your rejection may have been wrong. Re-verify from
scratch before calling it a persistent false positive.
