# DRIVE — the Claude reviewer slot is a role, not a model, and it fails over

**Scope:** the reviewer-model fallback across every skill that calls `claude -p` as a
reviewer. Issues #30/#31/#32/#33/#35/#38/#41/#42/#43/#44/#47/#48/#49/#50 are separate
PRs and NOT in scope.
**Phase:** HARDEN · **Bead:** n/a (direct-edit tier, doc-only) · **Branch:** claude-reviewer-fallback
**Pending:** —
**Gate:** `./install.test && ./skills/pr-with-codex-bot-review/scripts/bot-gate.test && ./skills/drive/scripts/drive-status.test`
· run on this branch at bash 5.3.9: `passed 12, failed 0` / `passed 124, failed 0` /
`passed 70, failed 0`, each exit 0. Note what that does **not** cover: every file in
this change is prose, and no suite reads prose. The evidence for this change is the
recorded runs in the reference, not the suites.

## Done
- #37 merged (291a6ce): install.sh's two uninstall aborts, plus `install.test`.
- #40 merged (fe5149e): four sibling-site rules across 8 files.
- #46 merged (029bc8c): behavioural claims in prose need a run, not a recollection.
- `install.sh` run against the live install: fast-forwarded `a4bb5e1..029bc8c`,
  14 skills linked into `~/.claude/skills` and `~/.codex/skills`, exit 0.

## Now
Fable is out of credits, so every panel in this repo currently has one working
reviewer and does not know it. The measured failure is the reason this is a change
rather than a config tweak: an unreachable model does **not** error, it hangs. Two
separate runs, kept separate because they show different things — the *bounded* 90s
probe exits 124 having written valid JSON with `is_error: true`, a null `.result`, and
only the small side-model in `modelUsage`; an *unbounded* call in the same state was
observed still running after eight minutes with both output files at zero bytes, and
was killed by hand (no 124, no JSON — that is the whole point of the contrast). stderr
was empty in both, so every "read stderr for the auth error" rule in these skills was
unreachable for this case.

So: a `$CLAUDE_MODEL` ladder (`fable` → `opus`; a user pin *replaces* the ladder rather
than heading it, so a named model fails instead of being substituted), resolved once per
run by a bounded 90s probe, keyed on exit code **and** `is_error` **and** a non-empty
`.result`, and setting a `CLAUDE_SLOT` flag so an exhausted ladder never reaches the CLI
as `--model ""`.
Artifacts and source tags rename from the model (`fable`) to the slot (`claude`),
because after a fallback a file named `pass-01.fable.txt` is a false provenance claim —
the exact defect #46 landed a rule against.

Budget: 14 files, ~560 insertions. Round 3 of max 4 (panel rounds 1-2: 29 findings, all accepted).
Do NOT build: a retry/backoff policy, a model-capability matrix, per-pass re-probing,
or a shared shell library — these are five prose skills, not a program.

## Next
Issue #32 `verify-commit`. Then #30/#31 (drive Guard 2), #33/#35, and the § 3a
residue (#41, #43, #44).

## Open questions for the human
- The ladder's second rung is `opus`, which is also the model that usually *drives*
  these skills. `second-model-bead-audit` now says so and labels it
  `BUILDER-LINEAGE`, but the deeper fix — a non-Claude fallback so the second opinion
  stays genuinely independent — is a product decision, not a sweep.
