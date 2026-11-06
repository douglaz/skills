# Opt-in native manager pilot

Load only when the brief explicitly names `Manager context pilot: lean-native-r2`,
records the owner's approval and exact repository scope, and points to the pilot's
preregistration and state manifest. A mention in history is not activation. Match
the current repository to that approved scope before starting a fresh manager.
Do not migrate an existing manager or opt other projects in. This pilot adds no
merge, launch or outward-action authority; preserve the brief's existing gates.

Keep the owner's native Opus manager model/effort, interactive 150000 window, and
TTL settings. No global configuration, model-default switch, raised window,
upgrade, standalone-manager arm or background-session supervisor is authorized.

## Before starting

Read the local preregistration for comparable phase types, acceptance checks and
the recoverable historical baseline. The supervising session registers an attempt
in the local state manifest **before** spawning work; a failed or abandoned attempt
still counts. Each fresh manager or retry starts another attempt; resuming the
same manager within its registered phase does not. A checkpoint replacement closes
the old attempt as `stopped` and retains the phase ID on its successor. Use one
manager per worktree. Record exclusive ownership and the
manager's turn start/end intervals, including tool waits within a running turn and
excluding time between turns waiting for the owner. Set the attempt's UTC window
and inventory every manager, reader, summary and handoff transcript needed for its
accounting. Keep all raw evidence and paths outside the repository.
First check the existing manifest's admission result, then register the new
running attempt before its initial spawn. Do not use its own `still_running` result
to launch a second manager or to skip the initial admission check.
One supervising session owns this manifest and admission/registration. Concurrent
supervisors are outside this pilot; stop if that exclusive ownership is uncertain.

The four ceilings are **five accepted comparable phases, ten total attempts,
$100 API-equivalent recurring cost, and eight cumulative manager active hours**,
whichever arrives first. Setup cost is separate. These are sampled scope ceilings,
not hard billing caps. Do not start at a ceiling; do not automatically extend an
inconclusive pilot. Missing usage or an unpriced model is unknown, not zero.

## During an attempt

- Each independent reader writes its own `BEGIN CARD` / `END CARD` section of at
  most 250 words: vote, strongest source evidence, blockers/dissent and pointers
  into its full answer. Keep immutable full answers and hashes outside manager
  context. Check with `python3 <skill>/scripts/pilot_meter.py card <answer>`; ask the
  author to revise a failed card, never silently truncate it. Count production and
  revision cost. Read cards first, then the original evidence whenever a claim,
  disagreement, acceptance decision or suspected omission requires it. Avoid
  repeated wholesale answer dumps just to recover context after compaction.
- Summarize gates with the actual command, exit status and actionable failure
  detail; retain the complete logs. A summary never substitutes for a required
  gate or independent original-source review.
- Plan a checkpoint at a natural phase boundary starting at **90–100k actual
  manager input**. Under the investigated 150k setting, the nominal compaction
  threshold was 117k, so the ordinary section 3 “near 150k” advice is too late for
  this opt-in. Do not force a clear during unresolved reasoning. Preserve pending
  decisions, citations, ownership and job watchers. Confirm that the previous
  manager and action-capable descendants cannot act, or explicitly transfer their
  outstanding jobs, before replacement. Restarts may increase cost.
- Keep independent reviewers in separate processes with their normal provider,
  model and effort. For Claude readers use
  `env -u CLAUDE_CODE_AUTO_COMPACT_WINDOW claude -p ... </dev/null`; other providers
  keep their existing launch commands. Do not constrain readers to 150k or replace required readers with
  summaries. Existing unit memory, swap and supervision requirements still apply.
- Meter source/answer/log reads through the helper below. Record bypassed or
  truncated reads as incomplete coverage rather than reporting zero rereads.
  Do not use that source-reading command on transcripts, secrets or credentials.

## Repeatable accounting

`scripts/pilot_meter.py` uses the sibling token-ledger price snapshot, or an
explicit `--prices FILE`. Check its date/rates before quoting dollars. It reads
transcript usage/compaction metadata, never message bodies, prompts or tool inputs.
Per-call Codex usage records take precedence over cumulative fallback events;
response IDs deduplicate copies. Finalized usage is preserved across stale copies,
and conflicting copies without a clear finalized record fail closed.
It does not infer that cache tokens are source rereads. Raw standalone scans cannot
recover rereads, phase acceptance, quality or active turn time; those stay unknown.
They show the fixed ceilings but no pilot admission; use `report` with the attempt
manifest to compute running totals. Never treat a successful raw scan as admission.

```bash
# A transcript, or repeat --transcript for every participating role:
python3 <skill>/scripts/pilot_meter.py scan --transcript <manager.jsonl> \
  --since <UTC-start> --until <UTC-exclusive-end>
# Or an explicit bounded transcript directory (repeat --root for both providers):
python3 <skill>/scripts/pilot_meter.py scan --root <project-transcripts> \
  --since <UTC-start> --until <UTC-exclusive-end>
# Emit the exact source byte range and journal its hash/range; no synthesis:
python3 <skill>/scripts/pilot_meter.py read --source <answer-or-source> \
  --start <byte-offset> --bytes <byte-count> --journal <reads.jsonl> --attempt <id>
# Recompute attempts and all four ceilings; inspect next_attempt/stop_reasons:
python3 <skill>/scripts/pilot_meter.py report <state.json> > <fresh-report.json>
```

`card` returns the immutable full-answer hash and the card's byte start/count for
the subsequent metered `read`, including when the answer uses Unicode or CRLF.

`report` exits 0 within recorded limits, 3 when another attempt must not start, and
2 on invalid/unreadable accounting. Preserve the exit status before inspecting its
JSON. A `still_running` reason blocks a replacement, not continued sampling of the
registered manager; a cost/time ceiling or control failure stops current work too.
The attempt-count ceiling blocks an eleventh attempt; it does not abort an already
admitted tenth attempt. `stop_current` distinguishes cost/time/quality/accounting stops from
new-attempt admission. A transient partial live JSONL tail returns 2: wait for the
writer to finish and resample, without treating that failure as zero usage.

Byte ranges are measured bytes emitted to the manager, not semantic comprehension
or tokenizer counts. An overlapping byte range of the same content hash is a
reread; changed content is a new version. Log the full answer hash even when reading
only its card. Keep source access within the original task's authorized paths.
Repeated ranges carry across attempts of the same phase, including handoff rereads;
different phases are reported separately.

Minimal state shape (paths are relative to the manifest, or absolute):

```json
{
  "pilot": "lean-native-r2",
  "repository": "<owner-approved repository>",
  "setup_usd": null,
  "attempts": [{
    "id": "a01", "phase_id": "<same id across retries>",
    "phase_type": "<registered type>", "status": "running",
    "since": "<timezone-qualified start>", "until": null,
    "sources": [{"path": "manager.jsonl", "role": "manager"}],
    "read_journal": "reads.jsonl",
    "manager_activity": [{"since": "<turn start>", "until": null}],
    "coverage_complete": false,
    "metering_lag": "<last usage sample and any in-flight work>",
    "quality": {"rounds": null, "review_findings": null, "review_misses": null},
    "control_failures": []
  }]
}
```

Inventory every participating role in `sources`; do not infer ownership from an
entire mixed transcript. Assign non-overlapping attempt windows; split shared
handoff work consistently between adjacent attempts. A source may specify narrower
`since`/`until` timestamps for attributable handoff turns; unrelated calls in those
windows still require exclusion by using a dedicated transcript or incomplete
coverage, never guessed attribution. `coverage_complete` is an
explicit attestation that all attributable provider calls, read events, turn
intervals and late-arriving usage have been included. Do not set it just to make
the report green. The report also rejects missing files, duplicate call assignment,
unpriced models and missing journals/intervals. A running attempt blocks starting
another, not continued sampling of that same attempt. `WITHIN_RECORDED_LIMITS`
is an accounting result, not authorization to work or a quality verdict.
Coverage requires manager usage within its recorded turn intervals. A failed launch
before any provider call can instead set `zero_usage_verified: true` and point
`zero_usage_evidence` to a nonempty failure receipt, with no sources or manager
activity and an empty read journal. This is an explicit supervisor attestation;
missing evidence stays incomplete, and the failed attempt still counts.

Recompute at manager tool boundaries, before another costly batch, at every turn
end/handoff and after late usage arrives. Record the sampling lag; re-read the most
recent manager input count for checkpoint planning. No usage-sampling process gives
an atomic billing cap. Close attempts with an exclusive `until`, status `accepted`,
`failed`, `abandoned` or `stopped`, and the registered acceptance evidence. Record
review findings/misses, rounds, handoff failures and actual control checks. A
`quality.material_regression` flag, or any `control_failures` entry (ownership
overlap, missed hold, unauthorized action), stops the pilot.
Close only after all participating workers and their final usage have finished.
Dedicated manager/reader/summary usage appearing after a closed attempt blocks
coverage; reconcile it before another attempt. Do not reuse those dedicated
transcripts for later phases. Shared supervising transcripts need their explicit
attributable source windows and late-usage attestation; timing alone cannot prove
their attribution. Failed or truncated read commands invalidate read coverage even
if a journal entry exists; never simply attest them away.

Stop at the accepted-phase, cost or active-time ceiling or a material quality/control
failure; the attempt ceiling prevents starting another attempt. Incomplete metering
blocks additional work until accounted for; preserve the evidence and report the
gap. Count failed work in recurring cost per accepted phase and compare like phase
types. Report setup separately. A small observational sample cannot prove quality
non-inferiority, causal attribution or durable savings. One good phase or an
inconclusive result permits no default change.

Report completion to the owner. If repeated compaction persists before useful
phase boundaries, bring a new, separately scoped proposal for a same-harness
standalone Opus 150k versus 200k comparison, controlled TTL, independent uncapped
readers and tested peer-message/stop/hold semantics. 200k is an unvalidated future
test value. This pilot authorizes no such comparison or model substitution.
