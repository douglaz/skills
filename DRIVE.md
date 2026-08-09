# DRIVE — make behavioural claims in prose carry the evidence code already has to

**Scope:** issue #45 only — the rule, in `agents-md`'s managed discipline block.
Issues #30/#31/#32/#33/#35/#38/#41/#43/#44 are separate PRs and NOT in scope.
**Phase:** HARDEN · **Bead:** n/a (direct-edit tier, doc-only) · **Branch:** prose-execution-rule
**Pending:** —
**Gate:** `./install.test && ./skills/pr-with-codex-bot-review/scripts/bot-gate.test && ./skills/drive/scripts/drive-status.test`
· run at a2e7893 on bash 5.3.9: `passed 12, failed 0` / `passed 124, failed 0` /
`passed 70, failed 0`, each exit 0. Re-runnable at that commit; this line records the
commit rather than a date, so a reader can reproduce it rather than trust it.

## Done
- #37 merged (291a6ce): install.sh's two uninstall aborts, plus `install.test`.
- #40 merged (fe5149e): four sibling-site rules — guarded `mktemp`, two-step `br where`
  resolution at 10 sites, unconditional group kill, `mktemp -d` review directories.
  Three further rules withdrawn to #41/#43/#44; #29 closed; #39 closed as superseded
  by #42, with the false-closure corrected on the issue.

## Now
One rule, in one file. Both panel reviewers independently picked #45 as the next PR, and
both said land it alone, then write #32 under it.

The evidence is #40's own history: 8 codex bot rounds (6 review objects plus 2 clean
wrappers — a clean round posts no review object, which is why the naive count reads 6),
5 panel passes, 13 corrections to land
four one-line rules — and the corrections were overwhelmingly to **sentences**, not code.
Five factual claims about tool behaviour shipped false, each beside a *correct* fix, three
of them introduced by the commit fixing the previous one. Every test suite was green
throughout, because suites do not read prose.

`skills/agents-md/references/discipline-block.md` is the home: it already carries the sibling
rule for edits (`sed -i` reports success when it matched nothing), and the block's own
admission bar — applies to every repo, agents get it wrong by default, every line traces
to a concrete failure — is met on all three counts.

**This PR must satisfy its own rule.** Every behavioural claim in it gets executed and the
run recorded, including the ones in the rule's own text.

Do NOT build a linter or script in THIS PR. Automation is possible — a doctest-style
runner could execute the ```console blocks and compare status and output, which is what
issue #49 proposes — but no *generic* script validates an arbitrary natural-language claim,
so reviewer-plus-recorded-run is the enforcement the rule can rely on today.
Do NOT retro-fit "Measured on" to existing sentences across the repo.
Do NOT edit any skill other than `agents-md`. retro-fitting "Measured on" to existing sentences
across the repo; or edits to any skill other than `agents-md`.

## Next
Issue #32 `verify-commit`, written under this rule. Then #30/#31 (drive Guard 2 — both
reviewers previously said decline the watcher script and use `--max-rounds`), #33/#35,
and the § 3a residue (#41, #43, #44).

## Open questions for the human
- `AGENTS.md` is still absent from this repo, so the block this PR edits is not installed
  here. Orthogonal — the block's purpose is to travel to other repos — but it does mean
  this repo does not yet hold itself to the rule it ships. Deferred to the #33 PR, where
  `agents-md` installation is the subject rather than a side effect.
