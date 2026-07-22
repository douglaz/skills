# Second-Model Bead Audit Report Template

Load this file when writing the final review.

```markdown
# Bead Graph Audit

## Auditor
- Model: <e.g. claude fable (high effort) | codex gpt-5.6-sol (xhigh)>
- Independence: INDEPENDENT (different model than built the graph) | SELF-AUDIT | UNKNOWN (graph authorship not determined)

## Launch verdict
- Fail / Conditional pass / Pass
- One-sentence reason

## Blocking findings
- [B1] Finding
  - Why it matters
  - Affected bead IDs
  - Recommended fix

## Important improvements
- [I1] Finding
  - Why it matters
  - Affected bead IDs
  - Recommended fix

## Optional nits
- [N1] Finding
  - Suggested cleanup

## Coverage notes
- Plan elements still weakly represented or missing
- Any beads with no clear plan backing

## Dependency notes
- Incorrect, missing, or over-constraining dependencies
- Bottlenecks, cycles, or frontier-shape issues

## Verification notes
- Missing or weak unit/integration/e2e obligations
- Missing diagnostics or logging where they are needed

## Disagreements with the auditor
- <auditor's claim> — upheld / overruled, per <bead id or plan section>

## Suggested br actions
```bash
# exact commands when you can state them confidently
```
```

Drop the disagreements section on a self-audit; there is no second opinion to
disagree with, and an empty heading implies independence you did not have.

## Severity rules

- Blocking = do not start implementation yet.
- Important = should be fixed before a large swarm launch, but might not block a tiny scoped effort.
- Nit = nice cleanup with low leverage.
