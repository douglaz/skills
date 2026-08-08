# DRIVE — sweep the rules that reached one sibling site and not the other

**Scope:** the sites named below, and nothing else. Issues #30/#31/#32/#33/#35 are
separate PRs and are NOT in scope. New scripts are NOT in scope — this sweep exists
because the rules already exist and simply did not travel.
**Phase:** BUILD · **Bead:** n/a (direct-edit tier, doc-only) · **Branch:** sibling-site-sweep
**Pending:** —
**Gate:** `./install.test && ./skills/pr-with-codex-bot-review/scripts/bot-gate.test && ./skills/drive/scripts/drive-status.test`
· last green 2026-08-08 (12 / 124 / 70, exit 0)

## Done
- #37 merged (291a6ce): install.sh's two uninstall aborts, plus `install.test`.

## Now
Seven mechanical edits. Budget: ~7 files, ~120 changed lines. Every one is a rule this
repo already established at one site and failed to carry to its sibling — the defect
class #34 counts as its most frequent, and the reason this is a sweep rather than
seven judgement calls.

1. `drive/references/phases.md:43` — `$_chk` is used three times, never assigned. The
   other three copies of this recipe all open with `_chk=$(mktemp)`. (#34 batch 3)
2. Three **byte-identical** fail-open `br where` paragraphs → checked assignment:
   `bead-polish-loop/SKILL.md:47`, `plan-to-beads-transfer/SKILL.md:39`,
   `orchestrating-with-rb-lite/references/harden-until-clean.md:192`. The correct form
   already existed in six other files, including line 240 of that same file. (#34 batch 7)
3. `multi-reviewer-loop/SKILL.md:756` — `--no-renames` on the § 3a status capture.
   `reviewer-panel.md:512-549` already uses it. (#34 batch 1)
4. Group-kill probe at **both** sites — `SKILL.md:420`, `reviewer-panel.md:187`.
   (#34 batch 6)
5. `mktemp -d` at both review-dir creations — exclusive, 0700. NOT the `(umask 077;
   mkdir -p)` form #29 suggested: `-p` keeps a pre-created directory's mode, and a
   subshell umask expires before the files are written. `second-model-bead-audit`
   already had this right; the sweep initially copied the wrong sibling. (#29)
6. § 3a capture/replay/restore: one pinned `git` over an enumerated key set, in a
   single place, rather than a prose sentence per flag. (#34 batch 10 class closure)
7. `bot-gate` header + `pr-with-codex-bot-review` § 7: asking for a review BEFORE the
   tip has a wrapper costs a round. Not "every push costs a round" — when the auto
   round lands its own wrapper first that anchors the next request, which
   `bot-gate.test` pins at exit 0. (#39)

Do NOT build: new scripts, new test fixtures, per-flag prose for config knobs the class
closure already covers, or any rewording of a site that is already correct.

## Next
Backlog PRs 2-4: drive Guard 2 (#30/#31), read-what-you-delegate (#33/#35),
`verify-commit` (#32).

## Open questions for the human
- `AGENTS.md` is still absent. It has a real addressee now — this branch — but installing
  it would double this PR's review surface and issue #33 is open precisely about
  `agents-md` writing a block that contradicts the repo's own agreement. Deferred to the
  #33 PR, which is where that conflict gets resolved rather than inherited.
