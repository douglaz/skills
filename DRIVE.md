# DRIVE — fix install.sh's uninstall path and give it a test suite

**Scope:** `install.sh` + `install.test` only. The backlog plan (issues #29–#35) is
NOT in scope for this drive — it is queued behind it as separate PRs.
**Phase:** HARDEN · **Bead:** n/a (direct-edit tier) · **Branch:** installer-uninstall-abort
**Pending:** —
**Gate:** `./install.test && ./skills/pr-with-codex-bot-review/scripts/bot-gate.test && ./skills/drive/scripts/drive-status.test`
· last green 2026-08-08 (12 / 124 / 70, exit 0)

## Done
- BUILD: two `set -e` aborts on `--uninstall` fixed — a partial uninstall that fired only
  when the removal succeeded, and a `read` EOF that made every non-interactive run report
  failure. Both reproduced against the real installer before any edit.
- BUILD: `install.test` added, the repo's third suite. Each defect gets its own fixture,
  because either alone yields exit 1 and a combined test cannot say which fired.
- Bot round 1 on `61792be` found a real defect **in the fix**: `|| answer=""` discards an
  unterminated `y`. Fixed in `c3e3074` with its own fixture; thread resolved with evidence.
- Bot round 2 on `c3e3074`: clean (`NO_PENDING_EVIDENCE`).

## Now
HARDEN: local codex + fable panel on `origin/master..HEAD`. Bot approval is not clearance
— LAND is admitted by the local `cleared` marker, which this checkout does not have.

## Next
LAND #37 (squash, delete branch) → then backlog PR 1, the sibling-site sweep: the
uninitialized `$_chk` in `drive/references/phases.md:43`, the three byte-identical
fail-open `br where` paragraphs, `--no-renames` on the § 3a status capture, the group-kill
probe, `umask 077` (#29), and the batch-10 ambient-git-config class.

## Open questions for the human
- `AGENTS.md` is absent. Phase 0 wants it installed once per repo, but adding it here
  would make a PR about the installer also about repo-wide agent policy — and issue #33 is
  open precisely about `agents-md` installing a block that contradicts the repo's own
  agreement. Deferred to backlog PR 1, which is a real branch that will exist, not a
  branch that never will. Stated rather than silently skipped.
