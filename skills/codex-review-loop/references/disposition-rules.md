# Finding Disposition Rules

Load this file when classifying findings during the fix-and-validate phase.

## Classification

Before editing, classify each finding as `FIX`, `DEFER`, or `REJECT`.

- **FIX**: default outcome. The finding is plausible, in scope, and can be
  addressed safely in this loop.
- **DEFER**: the finding still looks real or plausible, but the safe fix needs
  a broader refactor, product decision, policy call, or cross-team
  coordination. Keep it open. Do not call it a false positive.
- **REJECT**: allowed only when you have direct counter-evidence from code,
  tests, docs, or the diff.

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

## Recurrence rule

If a materially identical finding reappears on the next pass after you
rejected it, assume your rejection may have been wrong. Re-verify from
scratch before calling it a persistent false positive.
