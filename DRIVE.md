# DRIVE — sweep the rules that reached one sibling site and not the other

**Scope:** the sites named below, and nothing else. Issues #30/#31/#32/#33/#35 are
separate PRs and are NOT in scope. New scripts are NOT in scope — this sweep exists
because the rules already exist and simply did not travel.
**Phase:** HARDEN · **Bead:** n/a (direct-edit tier, doc-only) · **Branch:** sibling-site-sweep
**Pending:** —
**Gate:** `./install.test && ./skills/pr-with-codex-bot-review/scripts/bot-gate.test && ./skills/drive/scripts/drive-status.test`
· last green 2026-08-08 (12 / 124 / 70, exit 0)

## Done
- #37 merged (291a6ce): install.sh's two uninstall aborts, plus `install.test`.

## Now
TRIMMED at the three-round stop-list. Four rules converged and ship here; three did not and were withdrawn to their own
issues rather than patched again. Rule 3 was in the shipping set until round 4 read it
against the refusal list — the trim rule applied twice, on the same evidence standard.

Shipping:
1. `_chk=$(mktemp) || exit 1` at all **four** recipe copies — `drive/references/phases.md`
   had no assignment at all (#34 batch 3), and the other three had an *unchecked* one, which
   round 5 showed fails open: an unusable `TMPDIR` leaves `_chk` empty and the removal
   check's `|| true` then reports count 0 as "phrase fully removed". A fifth site exists as
   commented-out text (`multi-reviewer-loop/SKILL.md:156`) → #44.
2. `br where` resolution in **two checked steps at all 10 CODE-BLOCK sites** across 8
   files — plus a checked `git status`, since a failed inspection also prints nothing.
   Prose and comments teaching the same one-liner are NOT converted → #44. The
   one-line form was fail-open everywhere, not just at the three sites #34 named: a
   pipeline reports only its LAST command's status, so `br where` can fail while emitting
   valid JSON and `jq` then succeeds. Reproduced at rc=0. (#34 batch 7, widened)
3. ~~`--no-renames` on the § 3a status capture~~ — **withdrawn on round 4 → #43.** It
   fixes batch 1's silent drop and simultaneously blinds the staged-rename refusal three
   paragraphs above it, since detecting a staged rename requires the detection the flag
   turns off. Needs two reads, not one flag.
4. Kill the process group unconditionally at both escape-hatch sites. (#34 batch 6)
5. `mktemp -d` for both review directories — exclusive at 0700. NOT the `(umask 077;
   mkdir -p)` form #29 suggested, which leaves a pre-created directory's mode alone;
   `second-model-bead-audit` had this right all along. (closes #29)

Withdrawn:
- § 3a ambient-config pinning → **#41**. Rounds 1 and 3 each found a key the "closing"
  set had missed (`diff.noprefix` via local config, then `diff.submodule`). An enumerated
  `-c` list is still per-flag, which is what batch 10's class closure predicted would not
  converge. Needs the tested helper (#34 batch 8), not more flags.
- The #39 post-push round paragraph → **#42**. It was wrong twice because it documents an
  inconsistency, not a rule: clean-comment anchors are tip-scoped, review-object anchors
  are not. That is a code decision on the merge gate, with fixtures.

## Next
Backlog PRs 2-4: drive Guard 2 (#30/#31), read-what-you-delegate (#33/#35),
`verify-commit` (#32).

## Open questions for the human
- `AGENTS.md` is still absent. It has a real addressee now — this branch — but installing
  it would double this PR's review surface and issue #33 is open precisely about
  `agents-md` writing a block that contradicts the repo's own agreement. Deferred to the
  #33 PR, which is where that conflict gets resolved rather than inherited.
