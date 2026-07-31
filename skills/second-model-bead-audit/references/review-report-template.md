# Bead Audit Panel Report Template

Load this file when merging the panel's findings and writing the final verdict.

````markdown
# Bead Graph Audit

## Panel
- Quality: FULL PANEL | DEGRADED | PINNED PANEL | BLOCKED
- Codex: <model/effort> — <healthy | failed | unavailable | not requested> — <INDEPENDENT | BUILDER-LINEAGE | UNKNOWN>
- Fable: <model/effort> — <healthy | failed | unavailable | not requested> — <INDEPENDENT | BUILDER-LINEAGE | UNKNOWN>
- Graph authorship: <known model lineage or UNKNOWN>
- Independent vote present: yes | no | unknown
- Graph snapshot: <fingerprint>
- Scope: <plan-backed bead roots/epics and dependency closure>
- Degraded/blocked reason: <reason or none>

## Launch verdict
- FAIL | CONDITIONAL PASS | PASS | PASS (DEGRADED) | PASS (PINNED PANEL) |
  PASS (<quality>, NO INDEPENDENT VOTE) | NONE (panel BLOCKED)
- <one-sentence reason>
- Reviewer votes: Codex=<vote or n/a>, Fable=<vote or n/a>

## Blocking findings
- [B1][BOTH | CODEX | FABLE | CONFLICT] <finding>
  - Evidence: <plan section and bead IDs>
  - Why it blocks:
  - Recommended bead-level fix:

## Important conditions
- [I1][BOTH | CODEX | FABLE | CONFLICT] <finding>
  - Evidence: <plan section and bead IDs>
  - Why it matters:
  - Recommended bead-level fix:

## Optional nits
- [N1][BOTH | CODEX | FABLE] <finding>
  - Evidence:
  - Suggested cleanup:

## Coverage and scope notes
- Missing or weakly represented plan elements
- Beads with no clear plan backing

## Dependency and frontier notes
- Incorrect, missing, reversed, or over-constraining dependencies
- Bottlenecks, cycles, or unhealthy ready-frontier shape

## Verification and operations notes
- Missing or weak unit/integration/e2e/acceptance obligations
- Missing diagnostics, logging, rollout, or recovery obligations

## Reconciliation
- <single-source or disputed claim> — upheld / rejected / reframed, per <plan section and bead IDs>
- <direct contradiction> — Codex right / Fable right, per <plan section and bead IDs>

## Suggested br actions
```bash
# exact commands only when they can be stated safely
```

## Logs
- Codex: <path>
- Fable: <path>
- Merged: <path>
````

## Severity rules

- **Blocking**: implementation or the intended launch shape should not start yet.
- **Important condition**: fix and re-audit before implementation starts.
- **Nit**: low-leverage cleanup that does not affect execution safety.

## Merge rules

- Merge duplicate claims and tag the result `BOTH`; do not count two phrasings as
  two defects.
- Keep a single-source finding unless concrete evidence disproves it. The other
  reviewer's silence is not evidence.
- Mark direct reviewer contradictions `CONFLICT` until the orchestrator settles
  them from the plan and graph.
- List rejected findings and the concrete counter-evidence; do not silently omit
  them from the merged report.
- Treat suggested `br` commands as untrusted prose until the orchestrator checks
  the installed CLI syntax and shell quoting.
- Drop empty sections, but never drop the panel quality, reviewer health,
  independence, verdict, or logs.
