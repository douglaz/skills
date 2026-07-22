---
name: second-model-bead-audit
description: >-
  Audits a bead graph against the plan with an independent second opinion,
  checking coverage gaps, duplicate ownership, weak descriptions, dependency
  mistakes, and missing verification obligations before implementation starts.
  Use when another agent already created or polished the beads and you want a
  launch verdict with exact fixes, or when the user says "sanity check the
  beads", "audit the graph", "give me a second opinion on these beads", "are
  the beads ready to build?", or "review the bead graph before we start". Also
  works as a self-audit when no second model is available. Prefer read-only
  review unless the user explicitly asks for bead edits.
compatibility: Requires br and bv on PATH and a repo that uses .beads/. The
  second model is whichever of `codex` / `claude` you are not currently running
  in; either CLI on PATH enables a genuine cross-model audit, and the skill also
  works as a self-audit without them.
---

Provide a second-model audit of the bead graph without inheriting the first
model's blind spots.

## Tool dependencies

This skill requires `br` (beads_rust) and `bv` (bead viewer) on `PATH`.
If either command is missing, stop and tell the user. If commands fail with
unexpected errors, check whether the CLI version matches the expected subcommand
signatures in the command palette below — flag version mismatches to the user
rather than guessing at alternative syntax.

## Who the second model is

"Second model" means *a different model from the one that built the graph*, not
merely a second pass. A model re-reading its own work inherits the assumptions
that produced the gaps.

Pick the auditor from **who built the graph**, not from which CLI you happen to
be sitting in. Auditing a Claude-built graph with Claude is a self-audit even
when a different session runs it.

| Graph was built by | Auditor to invoke |
|---|---|
| Claude | `codex exec` (default `gpt-5.6-sol` at `model_reasoning_effort="xhigh"`) |
| Codex | `claude -p "<audit prompt>" --model fable --effort high --output-format json` |
| Unknown | Ask, or check the bead history (`br show <id> --json` actor fields). If it stays unknown, run the audit anyway and mark independence `UNKNOWN` |
| The other CLI is unavailable | Self-audit — say so explicitly in the verdict |

Concretely, from a Codex session:

```bash
set -o pipefail   # else jq's failure is masked and an empty audit reads as a thin one
claude -p "$(cat /tmp/bead-audit-prompt.txt)" \
  --model fable --effort high --output-format json \
  --tools "Bash,Read,Glob,Grep" --allowedTools "Bash,Read,Glob,Grep" \
  --disallowedTools "Edit,Write,NotebookEdit" \
  | jq -er 'if .is_error then error(.result // "auditor returned is_error")
            else (.result // empty) end'
```

A non-zero exit means the auditor never ran (auth, rate limit, overload) — fall
back to a `SELF-AUDIT` and label it, rather than reporting a thin audit as an
independent one. Keep `--disallowedTools`: this skill is read-only by default,
and an auditor that edits beads has stopped being a second opinion.

The audit prompt should carry the plan path, the `br`/`bv` commands from the
command palette below, the audit categories, and the report template — the second
model has none of this session's context, and that ignorance is exactly what you
are buying.

Two rules that keep this honest:

- **Do not hand the second model your own conclusions.** Give it the plan and the
  graph, not your assessment of them. An auditor shown the answer grades the
  answer.
- **Reconcile, don't rubber-stamp in reverse.** Its findings are hypotheses too.
  Where it disagrees with you about the graph, go read the beads and the plan and
  decide with citations — and record which of you was right in the report.

A self-audit is still worth running when no second CLI is available. Label it
`SELF-AUDIT` in the verdict so the user knows the independence claim is weaker.

## Default posture

Stay in read-only audit mode unless the user explicitly asks you to apply fixes.

## Use this skill when

- Claude or another agent already created/refined beads and the user wants Codex,
  Claude Fable, or another model to review them
- the project is important enough that a second-model check is worth the time
- the graph feels plausible but you want an independent launch verdict

## Do not use this skill when

- there is no real bead graph yet
- the user wants implementation instead of review
- the request is actually a planning task, not a bead audit

## Required outputs

1. A launch verdict: fail, conditional pass, or pass.
2. Which model performed the audit, and whether it was independent or a
   `SELF-AUDIT`.
3. A structured report with blocking findings first.
4. Exact bead-level fixes or proposed `br` actions where possible.
5. Clear distinction between hard blockers, important improvements, and optional nits.
6. Any place the auditor and you disagreed, and the citation that settled it.

## Workflow

1. Reread `AGENTS.md`, then read the relevant plan/spec and current bead graph.
2. Ground in reality:
   - `br list --limit 0 --json -a`
   - `bv --robot-triage`
   - `bv --robot-plan`
   - `bv --robot-suggest`
   - optionally `bv --robot-insights`, `bv --robot-priority`, and `br show <id> --json`
3. Re-derive the judgment independently. Do not assume the existing graph is correct because another strong model made it.
4. Audit the graph across these categories:
   - plan coverage
   - duplicate or overlapping ownership
   - vague or under-specified beads
   - dependency correctness and frontier health
   - priority and sequencing fit
   - verification obligations, including unit/integration/e2e and useful diagnostics where relevant
   - user-visible and operator-visible risks that are still unowned
5. Use the template in [references/review-report-template.md](references/review-report-template.md).
6. If you are asked to apply fixes, mutate only the clearly justified ones with `br`, then flush with `br sync --flush-only`.

## Review standards

A good audit is not a rubber stamp. It should be willing to say:

- the graph is missing work even though it looks large
- two beads should merge even though their titles differ
- one bead is overloaded and should split
- the graph is not launch-ready because testing or failure-handling is still implicit

## Command palette

```bash
br list --limit 0 --json -a
br show <id> --json
bv --robot-triage
bv --robot-plan
bv --robot-suggest
bv --robot-insights
bv --robot-priority
```

## Common failure patterns to avoid

- praising the graph without independently checking plan coverage
- nitpicking style while missing missing-work risks
- collapsing all findings into one severity bucket
- suggesting implementation changes when the graph itself is the problem
- editing beads by default when the user asked for a review

## Pipeline context

This skill is the **final check** in the bead lifecycle:

1. **plan-to-beads-transfer** — create beads from a stable plan
2. **bead-polish-loop** — refine the graph through iterative review rounds
3. **second-model-bead-audit** (you are here) — independent launch-readiness verdict

Before using this skill, the graph should already have been through at least one
round of polishing (via `bead-polish-loop` or manual review). Auditing a raw,
unpolished transfer will produce a long list of issues that polishing would have
caught — use `bead-polish-loop` first in that case.

After the audit:
- **Pass**: proceed to implementation.
- **Conditional pass**: fix the noted conditions (often via a quick
  `bead-polish-loop` round), then proceed.
- **Fail**: return to `bead-polish-loop` to address blocking findings before
  re-auditing.

## Additional resources

- For the report structure, see [references/review-report-template.md](references/review-report-template.md).
