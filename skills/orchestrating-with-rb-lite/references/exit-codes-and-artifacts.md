# Exit codes, JSON schema, and run artifacts

Lookup material. Consult the table when diagnosing a specific exit, the schema when parsing
the summary line, and the artifact list when hunting for the file that explains a run.

## Exit codes and JSON schema

| Code | Status | Meaning | What to do |
|---|---|---|---|
| `0` | `clean` | Reviewers had no P0/P1/P2 findings (P3-only is also clean by default) | Verify the landed diff yourself, rerun the repo's gates, then ship if they pass; check `latest reviewer message in run-dir` for any leftover P3 nits worth addressing |
| `2` | `usage_error` | Bad CLI args, incl. no implementer selected (`--implementer` and `--implement-cmd` both absent) | Fix the invocation; the JSON line is still emitted with `run_dir: null` |
| `3` | `env_error` | Not in a git repo, missing tool, unsupported `timeout`, branch creation failure, run-dir setup failure | Fix the env; rerun |
| `10` | `implementer_failed` | Implementer subprocess returned non-zero (incl. timeout 124/137) or hit max-iters before stabilizing | Look at `implementer-round-N-iter-K.stderr` for the most recent iter |
| `11` | `review_panel_failed` | No **defect** reviewer exited 0 — either none succeeded, or only the skeptic did (it cannot report defects, so its lone vote is not a review) | Check `reviewer-round-N-K.stderr` for all reviewers; usually missing CLI/auth or `jq` failure |
| `12` | `max_rounds_hit` | Burned all `--max-rounds` without convergence | Inspect the latest review files; either bump `--max-rounds` or address the remaining findings manually. Do **not** raise `--min-findings-severity` to skip nits — it filters out the skeptic, which tags every finding `P2` |
| `13` | `consensus_failure` | Implementer kept declining to act on findings for `--max-noop-rounds` consecutive rounds | Read the latest review **and the implementer's recorded reasons** — it's signaling it disagrees. If its rejections are evidence-backed (false positives or over-specification), this is a legitimate stop, not a failure. Apply the fix manually if you side with reviewers, or accept the run if you side with the implementer |
| `14` | `budget_exceeded` | Added production lines passed `--max-production-lines` | Stop and re-shape the change, or re-derive the baseline with the user. Never relaunch with a bigger number — the run has told you the change is wrong-shaped |
| `70` | `internal_error` | Internal invariant violation or unhandled shell failure | Read `log.txt` and the most recent stderr files; this is rare |

The JSON schema (every exit, last stdout line):

```json
{
  "run_dir": "string | null",
  "exit_code": "integer",
  "status": "clean | usage_error | env_error | implementer_failed | review_panel_failed | max_rounds_hit | consensus_failure | budget_exceeded | internal_error",
  "rounds": "integer",
  "implementer_iterations": "integer",
  "noop_rounds_streak": "integer",
  "findings_accepted": "integer",
  "findings_declined": "integer",
  "findings_deferred": "integer",
  "rejections_total": "integer",
  "rejections_by_round": "array of integer",
  "production_lines_added": "integer",
  "duration_secs": "integer",
  "config": {
    "max_rounds": "integer",
    "max_iters": "integer",
    "max_noop_rounds": "integer",
    "max_production_lines": "integer | null",
    "min_findings_severity": "string",
    "implement_timeout_secs": "integer | null",
    "reviewer_timeout_secs": "integer | null"
  }
}
```

## Run artifacts to know

Inside `<run-dir>/`:

- `log.txt` — timestamped status lines (round/iter/panel transitions).
- `implementer-round-N-iter-K.{stdout,stderr}` — every implementer call.
- `reviewer-round-N-K.{stdout,stderr}` — raw output from each reviewer.
- `review-round-N-K.md` — per-reviewer markdown the implementer reads
  on the next round (with status header and stderr-tail for failed
  reviewers).
- `challenges-round-N.md` — the round's decision record: one line per finding, each
  starting `ACCEPTED`, `DECLINED`, or `DEFERRED`. rb-lite counts these; read them when the
  summary shows rejections, and when it shows none for several rounds.
- `skeptic-diff-round-N.patch` — the diff handed to the skeptical reviewer.

When something looks off, read these in order: `log.txt` → the latest
`review-round-*.md` files → the relevant `*.stderr`.
