# Backlog execution plan

## Status

Returned to SHAPE after GRAPH polish on 2026-08-12. The first pinned Codex xhigh
review at `bceb919` reported no P0/P1 findings, but translation exposed missing
API, failure, recovery, and fixture detail in later rows. Those gaps are amended
below and await a new pinned review before the graph is updated. This plan covers
the 29 GitHub issues that were open in `douglaz/skills` on 2026-08-11. GitHub
remains the external source of issue identity; Beads holds the executable
dependency graph.

## Goal

Turn the current flat issue list into a sequenced, testable delivery program that:

1. closes admission-gate and user-state safety defects before lower-risk polish;
2. replaces repeated prose transactions with tested mechanisms;
3. keeps each implementation branch bounded to one coherent invariant;
4. uses rb-lite for Codex-heavy implementation/review loops;
5. preserves a GitHub issue URL on every execution bead; and
6. leaves no umbrella issue closed merely because some of its children landed.

## Current facts

- Repository: `douglaz/skills`, default branch `master`.
- Open GitHub issues: 29; open pull requests: none; no open issue has a label,
  assignee, or milestone. Priorities in this plan are inferred from failure
  impact and evidence in the issue bodies. Measured on 2026-08-11:

  ```text
  $ gh --version >/tmp/gh-version.stdout 2>/tmp/gh-version.stderr
  $ gh_version_rc=$?; cat /tmp/gh-version.stdout
  gh version 2.97.0 (nixpkgs)
  https://github.com/cli/cli/releases/tag/v2.97.0
  $ cat /tmp/gh-version.stderr; printf 'EXIT=%s\n' "$gh_version_rc"
  EXIT=0

  $ gh issue list --state open --limit 200 \
      --json number,labels,assignees,milestone \
      --jq '{count:length,numbers:(map(.number)|sort),
             with_labels:(map(select(.labels|length>0))|length),
             with_assignees:(map(select(.assignees|length>0))|length),
             with_milestones:(map(select(.milestone != null))|length)}' \
      >/tmp/gh-issues.stdout 2>/tmp/gh-issues.stderr
  $ gh_issues_rc=$?; cat /tmp/gh-issues.stdout
  {"count":29,"numbers":[30,31,32,33,34,35,38,41,42,43,44,47,48,49,50,51,53,54,55,56,57,58,59,60,61,62,63,65,66],"with_assignees":0,"with_labels":0,"with_milestones":0}
  $ cat /tmp/gh-issues.stderr; printf 'EXIT=%s\n' "$gh_issues_rc"
  EXIT=0

  $ gh pr list --state open --limit 200 --json number \
      --jq '{count:length,numbers:(map(.number)|sort)}' \
      >/tmp/gh-prs.stdout 2>/tmp/gh-prs.stderr
  $ gh_prs_rc=$?; cat /tmp/gh-prs.stdout
  {"count":0,"numbers":[]}
  $ cat /tmp/gh-prs.stderr; printf 'EXIT=%s\n' "$gh_prs_rc"
  EXIT=0
  ```
- Beads was not initialized when SHAPE began. The following 2026-08-11
  transcript is the historical baseline:

  ```text
  $ br --version >/tmp/br-version.stdout 2>/tmp/br-version.stderr
  $ br_version_rc=$?; printf 'STDOUT:\n'; cat /tmp/br-version.stdout
  $ printf 'STDERR:\n'; cat /tmp/br-version.stderr
  $ printf 'EXIT=%s\n' "$br_version_rc"
  STDOUT:
  br 0.2.19
  STDERR:
  EXIT=0

  $ br --no-auto-flush --no-auto-import where \
      >/tmp/br-where.stdout 2>/tmp/br-where.stderr
  $ br_where_rc=$?; printf 'STDOUT:\n'; cat /tmp/br-where.stdout
  $ printf 'STDERR:\n'; cat /tmp/br-where.stderr
  $ printf 'EXIT=%s\n' "$br_where_rc"
  STDOUT:
  STDERR:
  Error: Beads not initialized: run 'br init' first
  Hint: Run: br init
  EXIT=2

  $ bd --version >/tmp/bd-version.stdout 2>/tmp/bd-version.stderr
  $ bd_version_rc=$?; printf 'STDOUT:\n'; cat /tmp/bd-version.stdout
  $ printf 'STDERR:\n'; cat /tmp/bd-version.stderr
  $ printf 'EXIT=%s\n' "$bd_version_rc"
  STDOUT:
  bd version 0.44.0 (dev)
  STDERR:
  EXIT=0

  $ bd where >/tmp/bd-where.stdout 2>/tmp/bd-where.stderr
  $ bd_where_rc=$?; printf 'STDOUT:\n'; cat /tmp/bd-where.stdout
  $ printf 'STDERR:\n'; cat /tmp/bd-where.stderr
  $ printf 'EXIT=%s\n' "$bd_where_rc"
  STDOUT:
  STDERR:
  Error: no beads database found
  Hint: run 'bd init' to create a database in the current directory
        or use 'bd --no-db' to work with JSONL only (no SQLite)
        or set BEADS_DIR to point to your .beads directory
  EXIT=1
  ```
- GRAPH initialized the current `.beads` store with prefix `skills`, transferred
  the 33 table rows, and flushed 22 edges before polish returned this drive to
  SHAPE. After this amended plan passes review, update that existing graph in
  place with `br`; do not rerun `br init`, delete the database, recreate IDs, or
  hand-edit the JSONL.
- The previous `DRIVE.md` described PR #64 after it had already merged. This plan
  replaces that stale record rather than continuing its HARDEN phase.
- Exact issue scope:
  `#30, #31, #32, #33, #34, #35, #38, #41, #42, #43, #44, #47, #48,
  #49, #50, #51, #53, #54, #55, #56, #57, #58, #59, #60, #61, #62,
  #63, #65, #66`.
- Repository gate for branches in this plan:

  ```bash
  ./check.sh
  ```

  An `executor-skills` bead may add a narrower red/green command, but the
  aggregate gate still runs before clearance and landing. F2 uses the upstream
  gate specified in its section. Human-authority beads require a decision or
  publication record rather than the skills gate.

## Tracker contract

GitHub owns external issue identity, discussion, and closure. Beads owns local
execution state and dependencies.

- The initial transfer initialized Beads only after the first SHAPE review.
  Subsequent reviewed amendments update the existing store in place and preserve
  all generated IDs.
- Create only the bounded execution and decision beads in the complete table.
  Do not create root/workstream epics or parent beads: normal `br` parent
  semantics make a completed umbrella ready, and the branch drain would mistake
  it for implementation work.
- Put `GitHub: https://github.com/douglaz/skills/issues/N` in every bead.
- Label every bead `drive-open-issues` and add exactly one executor label:
  `executor-skills`, `executor-rb-lite`, or `authority-human`.
- A Beads close never closes a GitHub issue automatically.
- Close a GitHub umbrella only after every accepted child is merged or explicitly
  rejected with evidence.
- Never hand-edit the exported JSONL. Use `br` and require an explicit
  `br sync --flush-only`.

The flat graph and separate executor queries are pinned by this disposable-repo
probe on `br 0.2.19`. Each `br` command captured stdout and stderr separately:

```text
$ T=$(mktemp -d); git -C "$T" init -q; cd "$T"
$ br init --prefix zz >/tmp/init.out 2>/tmp/init.err; init_rc=$?
$ br create --silent -t epic -p P3 \
    -l drive-open-issues,executor-skills 'tracking parent' \
    >/tmp/parent.out 2>/tmp/parent.err; parent_rc=$?
$ parent=$(cat /tmp/parent.out)
$ br create --silent -t task -p P1 \
    -l drive-open-issues,executor-skills --parent "$parent" 'child work' \
    >/tmp/child.out 2>/tmp/child.err; child_rc=$?
$ child=$(cat /tmp/child.out)
$ br create --silent -t task -p P2 \
    -l drive-open-issues,executor-skills 'both labels' \
    >/tmp/both.out 2>/tmp/both.err; both_rc=$?
$ br create --silent -t task -p P2 -l drive-open-issues 'one label' \
    >/tmp/one.out 2>/tmp/one.err; one_rc=$?
$ br ready --json --limit 0 \
    >/tmp/before.out 2>/tmp/before.err; before_rc=$?
$ jq -c 'map(.title) | sort' /tmp/before.out
["both labels","child work","one label"]

$ br ready --json --limit 0 -l drive-open-issues -l executor-skills \
    >/tmp/and.out 2>/tmp/and.err; and_rc=$?
$ jq -c 'map(.title) | sort' /tmp/and.out
["both labels","child work"]

$ br close "$child" >/tmp/close.out 2>/tmp/close.err; close_rc=$?
$ br sync --flush-only >/tmp/sync.out 2>/tmp/sync.err; sync_rc=$?
$ br ready --json --limit 0 \
    >/tmp/after.out 2>/tmp/after.err; after_rc=$?
$ jq -c 'map(.title) | sort' /tmp/after.out
["both labels","one label","tracking parent"]

$ printf 'init=%s parent=%s child=%s both=%s one=%s before=%s and=%s close=%s sync=%s after=%s\n' \
    "$init_rc" "$parent_rc" "$child_rc" "$both_rc" "$one_rc" \
    "$before_rc" "$and_rc" "$close_rc" "$sync_rc" "$after_rc"
init=0 parent=0 child=0 both=0 one=0 before=0 and=0 close=0 sync=0 after=0

$ wc -c /tmp/{init,parent,child,both,one,before,and,close,sync,after}.err
0 /tmp/init.err
0 /tmp/parent.err
0 /tmp/child.err
0 /tmp/both.err
0 /tmp/one.err
0 /tmp/before.err
0 /tmp/and.err
0 /tmp/close.err
0 /tmp/sync.err
0 /tmp/after.err
0 total
```

The second query shows repeated label filters are ANDed. The final query shows
that a tracking parent becomes ready after its last child closes. Both behaviors
are load-bearing: the scheduler must query executor lanes separately, and the
graph must not contain non-executable parents.

## Priority definitions

- **P0:** a trust boundary can admit unreviewed work or destroy/misapply user
  state.
- **P1:** a demonstrated correctness defect in a normal supported workflow.
- **P2:** bounded correctness, compatibility, or diagnostic defect.
- **P3:** maintenance or wording with no demonstrated unsafe outcome.

## Global delivery rules

1. One coherent invariant per branch and PR.
2. Write a failing regression fixture before changing a demonstrated behavior.
3. For shell snippets presented as executable mechanisms, test the mechanism
   rather than relying on review of the prose.
4. Do not patch multiple duplicated consumers independently after a second
   consumer appears. Assign one fact owner or extract a tested helper.
5. Run Codex-heavy work through `orchestrating-with-rb-lite`; use
   `testing-with-rb-lite` when the deliverable itself is a test or live gate.
6. A reviewer finding is a hypothesis. Reproduce it before accepting it.
7. Do not run two implementers against the same worktree or file ownership lane.

## Workstream A — merge and admission integrity

### A1. Tip-scope bot review objects — issue #42

**Priority:** P0. **Effort:** medium.

**Likely files**

- `skills/pr-with-codex-bot-review/scripts/bot-gate`
- `skills/pr-with-codex-bot-review/scripts/bot-gate.test`
- `skills/pr-with-codex-bot-review/SKILL.md` only if the observable contract changes
- `docs/adr/0004-the-bot-gate-claims-absence-of-evidence-not-clearance.md`

**Deliverable**

Add a normal-push fixture showing that a review object anchored to a prior tip
cannot satisfy request coverage for the current tip, then restrict ordinary
coverage anchors accordingly. Preserve explicitly documented degraded-forge
behavior. Amend ADR 0004's rejected tip-scoping discussion so the durable
decision record distinguishes the old all-anchor proposal from A1's
normal-push/current-tip rule and no longer recommends restoring prior-tip review
objects.

**Done when**

- the new fixture fails against the unfixed gate for the intended assertion;
- it passes after the implementation;
- all existing `bot-gate.test` cases pass; and
- ADR 0004 states the same anchor rule as the gate; and
- the aggregate repository gate exits 0.

### A2. Traceable review-thread disposition — issue #66

**Priority:** P1. **Effort:** medium. **Depends on:** A1.

**Likely files**

- `skills/pr-with-codex-bot-review/scripts/bot-gate`
- `skills/pr-with-codex-bot-review/scripts/bot-gate.test`
- `skills/pr-with-codex-bot-review/SKILL.md`

**Deliverable**

Expose unresolved thread IDs plus enough first-comment context or URL to read
each finding. Document the `resolveReviewThread` mutation. Require a fresh query
after every push and disposition per thread rather than driving a count to zero.

First reproduce the reported same-count/different-ID case with logged IDs and
bodies. Add a content digest only if the reproduction proves ID plus URL is
insufficient.

### A3. Remaining merge-evidence findings — issue #65

**Effort:** three small beads, not one PR. **Depends on:** A1.

**A3a, P1 — preserve first degraded exit-4 evidence.** Own
`skills/pr-with-codex-bot-review-merge/SKILL.md` plus new extracted-snippet
fixture
`skills/pr-with-codex-bot-review-merge/scripts/merge-evidence.test`. On first
exit 4, create the incident file exclusively under the Git directory and retain
its exact path. Re-entry must not truncate, replace, or recertify that file; a
different body at the same logical incident is a nonzero conflict. The fixture
runs degraded re-entry twice, changes the second JSON, proves the original bytes
and mode remain unchanged, and covers create/read/write failure. Run it and
`./check.sh`. Do not absorb A3b or A3c.

**A3b, P1 — private post-merge evidence.** Own the post-merge capture in
`skills/pr-with-codex-bot-review-merge/SKILL.md` and the separate post-merge cases
in `merge-evidence.test`. Create a unique mode-0600 file inside a mode-0700
directory with checked `mktemp`, checked write, and an explicit path carried
into the report. Never use a predictable `${TMPDIR}/merge-evidence-N.json`,
follow a pre-created symlink, or continue after capture/read/cleanup failure.
Fixtures cover hostile TMPDIR entries, create/write/read failure, and two
concurrent captures. Run them and `./check.sh`. Do not absorb A3a or A3c.

**A3c, P1 — exclude closure PRs from work-PR resume.** Own both matching query
copies in `skills/rb-lite-backlog-drain/SKILL.md` and add executable
`skills/rb-lite-backlog-drain/scripts/resume-query.test`. Before applying
OPEN/MERGED work-PR state rules, reject a body carrying the exact
`bead-closure: <id>` marker; retain the boundary-safe ordinary bead-ID match and
fork/parent URL identity. The fixture uses one work PR and one closure PR with
the same ID in OPEN and MERGED permutations and proves only work PRs reach the
resume state. Run it and `./check.sh`. Do not absorb A3a or A3b.

### A4. Bounded plan-format follow-ups — issue #65

**Effort:** two extra-small beads, separate from admission logic.

**A4a, P3 — routing wording.** Own only the folded description in
`skills/drive/SKILL.md` and the existing
`skills/drive/evals/trigger-evals.json`. Replace the broad question exclusion
with `general informational question`, explicitly retaining project-status and
resume as Drive triggers. Run the existing trigger evaluation command documented
by that skill before and after and require identical outcomes; this is not a
red/green production behavior change. Then run `./check.sh`.

**A4b, P3 — fenced moved examples.** Own the two indented merge/reset examples
in `skills/rb-lite-backlog-drain/SKILL.md` and add their exact extraction check
to `install.test`. Convert only block style, asserting fenced structure and
byte-identical command text before/after. Do not execute the examples or add the
G2 harness here. Run `./install.test` and `./check.sh`.

## Workstream B — delegated-edit state integrity

### B0. Dirty-state preservation decision — issues #41, #43, #34, #65

**Priority:** P0. **Effort:** human decision record.

Record the human choice from `DRIVE.md` as a Beads decision bead. Recommendation:
refuse unsupported dirty delegated paths and use a disposable worktree. B1d
stays blocked until this bead records the answer; the bead never treats silence
as approval.

B0 may close only if the human accepts the planned fail-closed refusal boundary.
If the human chooses full dirty in-scope preservation, leave B0 open, return the
drive to SHAPE, specify and review that larger preservation mechanism, then amend
the scope of B1d and re-audit the graph. The choice never makes B1d or B1 ready
against the current plan.

### B1d. Delegated-edit isolation design and fixtures — issues #41, #43, #34, #65

**Priority:** P0. **Effort:** medium design. **Depends on:** B0.

Write `docs/specs/delegated-edit-isolation.md` with the exact helper API, path
state matrix, refusal contract, patch/apply transaction, file/LOC budget, and one
named future red fixture for each of these classes:

- non-ASCII and newline-containing pathnames;
- rename plus intent-to-add;
- skip-worktree and assume-unchanged;
- ambient Git configuration;
- gitlinks/submodules;
- out-of-allowlist writes;
- untracked and deleted descendants;
- restore/apply failure;
- source HEAD/index/allowed-path drift while the implementer runs; and
- a second cooperating writer attempting to edit while the transaction lock is
  held.

The design must state each fixture's setup, pre-fix failure assertion, preserved
user bytes/state, and post-fix acceptance assertion. Review the design with:

```bash
codex review --base master -c 'model="gpt-5.6-sol"' \
  -c 'model_reasoning_effort="xhigh"'
```

until it has no P0/P1, then run `./check.sh`. B1d authors the reviewed spec and
fixture contract, not the fixtures or helper: do not edit production skill prose
or implement the helper in B1d. The separation matters because delegated edits
against unsupported dirty/index states can corrupt or misapply user work before
the caller notices.

### B1. Delegated-edit isolation mechanism — issues #41, #43, #34, #65

**Priority:** P0. **Effort:** large build. **Depends on:** B1d.

**Likely files**

- `skills/multi-reviewer-loop-delegating-edits/SKILL.md`
- `skills/multi-reviewer-loop/references/reviewer-panel.md`
- a new tested helper under `skills/multi-reviewer-loop/scripts/`, if review
  confirms that a shell helper is the smallest fact owner

**Required behavior**

Prefer a disposable clean worktree or copy:

1. classify unsupported dirty/index states before delegation;
2. refuse delegated paths with intent-to-add, skip-worktree, assume-unchanged,
   filters, or unsupported submodule/gitlink state unless a fixture proves safe
   preservation;
3. snapshot with raw NUL-delimited path handling;
4. run the implementer away from the real worktree;
5. compare every staged, unstaged, and untracked path to the exact allowlist;
6. generate a binary-safe patch;
7. run `git apply --check`; and
8. acquire the repository's delegated-edit transaction lock, re-read and require
   exact equality with the original source token (HEAD, raw index entries and
   index tree, staged/unstaged/untracked path sets, modes, and content digests),
   rerun `git apply --check`, and apply while holding that lock; and
9. before releasing the lock, prove the index and every pre-existing
   out-of-allowlist path remain byte-for-byte unchanged and every allowed result
   equals the reviewed isolated result.

The transaction lock is an atomically created directory under the Git common
directory, owned by the tested helper and used by every cooperating delegated
editor in this repository. An existing live/unknown lock is a refusal; stale-lock
recovery is explicit and never PID-age guessing. Capture the source token before
launch and revalidate it only after acquiring the lock, immediately before
application. Drift before lock acquisition applies nothing. A process that
honors the same lock must block/refuse until application finishes. If
uncoordinated drift is detected during the post-apply proof, report BLOCKED,
retain the original/result/patch recovery bundle, and do not blindly restore
over bytes that may belong to that writer.

Use separate reads for the no-renames restore list and the rename-aware refusal
decision. Do not revive #34's retracted PGID-reuse sentinel.

Before BUILD, stop for the human design decision recorded in `DRIVE.md`.
Recommendation: refuse unsupported dirty delegated paths and use the disposable
worktree path. Full dirty in-scope preservation is a separate, larger mechanism
and must not be inferred from this plan.

**Required fixtures**

- non-ASCII and newline-containing pathnames;
- rename plus intent-to-add;
- skip-worktree and assume-unchanged;
- ambient Git configuration;
- gitlinks/submodules;
- out-of-allowlist writes;
- untracked and deleted descendants;
- restore/apply failure;
- source HEAD/index/allowed-path drift while the implementer runs; and
- a second cooperating writer attempting to edit while the transaction lock is
  held.

### B2. Remaining #34 safety children

Split from B1 with one priority per child:

**B2a, P1 — unsafe red evidence.** Own
`skills/testing-with-rb-lite/SKILL.md` and new executable
`skills/testing-with-rb-lite/scripts/unsafe-red.test`. When neither a disposable
environment nor a non-destructive mutation exists, return
INCOMPLETE/BLOCKED, preserve the reason, and make the land/clear path
unreachable. The fixture reaches the unsafe branch and asserts no commit, push,
merge, or success report. Run it and `./check.sh`.

**B2b, P0 — preserve colocated tests.** Own the testing-with-rb-lite task
template/inversion instructions and add
`skills/testing-with-rb-lite/scripts/inversion-restore.test`. Save a private
mode-0600 patch or full-file recovery copy before a file-level mutation, restore
production bytes without removing the newly authored colocated test, and retain
the recovery copy until exact verification succeeds. On restore failure, report
BLOCKED with the recovery path and do not land. A fixture uses a Rust-like
colocated test module and proves the pre-fix file restore deletes it, then proves
the accepted transaction preserves both test and original production bytes.
Run it and `./check.sh`.

- **B2c, P2:** after C1 lands, add the #34 consumer-integration regression in
  `skills/multi-reviewer-loop/references/reviewer-panel.md`: timeout, signal, and
  escape must be reachable from the running invocation without a second shell,
  use C1 for bounded shutdown/reaping/status, and prevent a late result write.
  Add executable
  `skills/multi-reviewer-loop/scripts/reviewer-shutdown-integration.test`, wire
  it into `check.sh`, and do not duplicate C1 lifecycle code or re-test its
  internal unit surface.

**B2d, P2 — preserve verification execution errors.** After G1 lands, replace
the occurrence-count `grep ... || true` consumer in
`skills/multi-reviewer-loop/references/reviewer-panel.md` with G1's exact
literal/count API. Add the missing/unreadable verifier-input cases to G1's test
and a consumer extraction assertion to the B2c integration test. Exit 1 means a
checked mismatch; exit 2+ remains an execution failure and may not become count
zero or success. Run both tests and `./check.sh`.

**B2e, P0 — compare flush against saved bytes.** Own
`skills/second-model-bead-audit/SKILL.md` and
`skills/second-model-bead-audit/references/reviewer-panel.md`; add executable
`skills/second-model-bead-audit/scripts/postflush-preservation.test`. Before a
flush, save the exact JSONL to a mode-0600 file in a mode-0700 directory and
compare every post-flush ID/field/body against that file, not `HEAD`. Retain
recoverable bytes and fail with reverted IDs/fields on read/comparison/cleanup
failure; never continue to staging or audit. The fixture makes HEAD older, the
index damaged, and the worktree good, then proves the pre-fix comparison passes
incorrectly and the accepted comparison blocks with recovery bytes intact. Run
it and `./check.sh`.

## Workstream C — reviewer runner reliability and isolation

### C1. Bounded panel correctness — issues #53–#58 and #60

**Priority:** P1. **Effort:** large as one shared mechanism.

**Likely files**

- `skills/multi-reviewer-loop/references/reviewer-panel.md`
- `skills/second-model-bead-audit/references/reviewer-panel.md`
- `skills/orchestrating-with-rb-lite/references/harden-until-clean.md`
- `skills/pr-with-codex-bot-review/SKILL.md`
- new exact companion owner:
  `skills/claude-reviewer-runner/SKILL.md`
- required implementation and tests:
  `skills/claude-reviewer-runner/scripts/claude-reviewer-runner`
  and
  `skills/claude-reviewer-runner/scripts/claude-reviewer-runner.test`
- aggregate gate owner: `check.sh`
- `install.sh` and `install.test`

**Required owner/API**

The runner is a mandatory deliverable, not an optional refactor. It provides:

```text
claude-reviewer-runner probe --models <comma-list>
claude-reviewer-runner run --model <name> --prompt-file <path> \
  --timeout-seconds <n> --result-file <private-path> \
  --tool-policy <auditor-readonly|panel-legacy-shell|panel-no-shell> \
  [--working-directory <path>] [--add-dir <private-bundle-path>]
```

`probe` prints exactly one selected model and exits 0, exits 3 when no candidate
answers, and uses a distinct non-3 failure for missing dependencies or malformed
probe output. `run` requires a non-empty model, bounds the child, writes only the
caller-provided private result path, and propagates a categorized status.
The fixed process statuses are 0 for a complete valid result, 3 for reviewer
unavailable/exhausted, 124 for timeout, 128+signal for HUP/INT/QUIT/TERM, 125 for
forced-kill or child-reaping failure, 2 for invocation/dependency/capability
failure, and 1 for malformed/error reviewer output or result-file
create/write/finalize/cleanup failure. Write results to a mode-0600 sibling
temporary file, wait for the complete child process group, validate, atomically
rename to `--result-file`, and never modify that path after returning; no failure
may leave a valid-looking final result. Timeout/signal handling performs bounded
TERM/CONT/KILL and does not return until descendants are reaped.

`probe` writes the selected model plus one trailing newline to stdout and no
stdout on failure. `run` writes no stdout. Its final file is exactly one compact
UTF-8 JSON object plus a trailing newline:

```json
{"model":"<effective>","is_error":false,"result":"<non-empty reviewer text>"}
```

Reject a pre-existing result path, invalid UTF-8, extra JSON values, any
`.is_error` other than `false`, an empty/non-string result, or a model that does
not equal the requested effective model. Diagnostics and categorized child
stderr go to stderr without emitting prompt/result content; raw child stdout and
stderr remain in caller-private sibling artifacts until validated cleanup.
Callers consume only this normalized schema and never unwrap raw Claude output.

Latch the first terminal cause. Invocation/capability failure before launch is
2; once launched, a received caller signal yields 128+that signal and a timeout
yields 124 even if bounded cleanup escalates to KILL. Status 125 is reserved for
an otherwise unclassified supervisor/reaping failure with no latched
signal/timeout. Only after lifecycle success may malformed/error output yield 1
or a valid result yield 0. Direct fixtures pin that precedence, the exact file
bytes, empty stdout, redacted stderr, target-exists refusal, and no late write.

By default `run` inherits the caller's working directory and passes no
`--add-dir`. `panel-no-shell` requires both explicit path options, verifies that
the working directory is inside the same caller-owned private bundle root and
that `--add-dir` names that root, then passes exactly that one `--add-dir`.
Other policies reject those options so no caller can accidentally broaden its
current view. C3 owns creating and validating the bundle bytes; C1 owns only the
fixed launch/lifecycle boundary.

For `panel-no-shell`, canonicalize through already-open directory descriptors,
not a string-prefix check. The bundle root and every existing ancestor below its
private parent must be non-symlink directories owned by the current effective
UID; the root must be mode 0700. `--add-dir` must be exactly that canonical root,
and the working directory must be that root or a descendant reached without a
symlink. Ownership, mode, containment, swapped-symlink, and non-directory
fixtures all fail before Claude launches.
Callers retain both requested and effective panel state and use the runner for
launch, wait, and unwrap. Policies are fixed enums rather than caller-provided
tool strings:

- `auditor-readonly` preserves the bead auditor's current `Read,Glob,Grep`
  policy;
- `panel-legacy-shell` preserves the existing multi-reviewer permissions only
  until C3 migrates that caller; and
- `panel-no-shell` is C3's enforced `Read,Glob,Grep` policy with Bash denied.

The runner must not broaden a caller's policy or edit the reviewed worktree.
Its direct test must be executable and wired into `check.sh`; acceptance runs
the runner test directly, `./install.test`, then `./check.sh`. Treat this as one
large shared-mechanism branch, not the earlier medium estimate: set a reviewed
hard stop of 1,200 production lines and 1,800 fixture lines. Stop and return to
SHAPE rather than silently exceeding either budget or splitting lifecycle
ownership between half-migrated callers.

Every caller resolves the executable from the exact installed
`claude-reviewer-runner` companion path across Claude, Codex, and Agents targets,
then falls back to the checkout path only when no installation resolves.
`companion_dependencies()` must install this companion for selective installs
of `multi-reviewer-loop`, `second-model-bead-audit`,
`pr-with-codex-bot-review`, and `orchestrating-with-rb-lite`; transitive
dependency expansion keeps a selective Drive install covered. `install.test`
must exercise each direct selective install on both Claude and Codex targets,
upgrade repair, a missing companion, and a wrong declared companion name. It
must also run explicit legacy-only `~/.agents/skills` selective-install,
upgrade-repair, and missing-companion fixtures with no modern Claude/Codex target
present.

**Order**

1. #55: distinguish missing `jq` from an exhausted model ladder.
2. #57: require `.is_error == false` and a non-empty string result.
3. #58: guard launch, wait, and unwrap as one region when no model resolves.
4. #54: preserve requested versus effective panel state.
5. #53: declare/check the host GNU `timeout` requirement.
6. #60: create probe helpers only inside a private temporary directory.
7. #56: re-record the `if` transcript or narrow the claim to the command run.

### C2. rb-lite reviewer model bounding — issue #51

**Priority:** P1. **Effort:** small/medium.

Keep C2 in this repository. Resolve the model before rb-lite starts, generate a
private reviewers file that uses that exact model and a finite timeout, and pass
it through rb-lite's existing `--reviewers-file` interface. Do not choose the
upstream implementation option in #51. Remove stale local hardcoded-model
guidance without waiting for the larger controller.

Ownership is `skills/orchestrating-with-rb-lite/SKILL.md`, its exact reviewer
configuration reference, and new executable fixture
`skills/orchestrating-with-rb-lite/scripts/reviewer-model.test`.

Use C1's categorized probe contract. Probe exit 3, malformed/empty output,
missing dependencies, reviewers-file create/write/chmod failure, and cleanup
failure all stop before rb-lite launches with a categorized stderr diagnostic.
Create the reviewers file in a caller-owned mode-0700 directory, require the
file to be mode 0600, never print its contents, and remove it after the bounded
run. Diagnostics name the requested candidates and effective model, not prompt
or credential content. A focused fixture must use a fake C1 runner and fake
rb-lite to prove the exact resolved model plus finite timeout arrive through
`--reviewers-file`, every preflight failure launches zero rb-lite children, and
cleanup failure cannot be reported as success. Run that fixture and
`./check.sh`.

### C3. Enforced reviewer isolation — issue #59

**Priority:** P0. **Effort:** large design. **Depends on:** C1.

Use a portable no-shell reviewer boundary through the single runner from C1:

1. remove `Bash` from `--allowedTools` and include it in
   `--disallowedTools`; require `--no-session-persistence`, `--safe-mode`,
   `--strict-mcp-config`, `--mcp-config '{"mcpServers":{}}'`, and an exact
   built-in `Read,Glob,Grep` tool list; pass only the private bundle through
   `--add-dir`; if the installed CLI lacks any isolation flag, mark the reviewer
   unavailable/degraded before launch;
2. have the orchestrator build a review bundle in a private 0700 temporary
   directory outside the worktree before launch;
3. require a caller-supplied NUL-delimited allowlist of intended untracked paths
   whenever untracked files exist; enumerate with
   `git ls-files --others --exclude-standard -z`, compare byte-for-byte, and
   refuse the panel before any external launch if an untracked path is outside
   the allowlist or the allowlist names a path that is no longer untracked;
4. materialize a sanitized snapshot under that directory from the NUL-safe raw
   index path/mode set (`git ls-files --stage -z`) plus the current worktree
   bytes; first inspect `git ls-files -v -z` and refuse every
   assume-unchanged or skip-worktree entry; copy regular files byte-for-byte,
   preserve Git-relevant executable mode, and omit only paths proven to be
   tracked deletions; refuse all tracked symlinks and gitlinks rather than risk a
   target escaping the snapshot; also fail closed on sparse/missing paths that
   are not deletions, unmerged index stages, or any path/mode/digest mismatch;
   do not use `git archive` or a checkout operation that honors `export-ignore`,
   `export-subst`, or smudge filters;
5. copy only the allowlisted untracked regular files into both their snapshot
   paths and numbered bundle paths; do not copy `.git`, ignored files, or any
   unrelated untracked path;
6. generate a
   tested JSON manifest containing its JSON-escaped original path, numbered copy,
   type, Git-relevant mode (`100755` when executable, otherwise `100644`), and
   content digest; use `git hash-object --no-filters` on both the original and
   copy and require equality; fail closed on a non-regular type or any
   enumerate/copy/digest/manifest error;
7. before copying, refuse any tracked file larger than 16 MiB or a tracked
   snapshot larger than 256 MiB, and refuse any untracked file larger than
   1 MiB or an aggregate untracked bundle larger than 8 MiB;
8. before materializing the diff, enumerate both old and new blob IDs for every
   base-to-worktree change, reject any base-side/deleted blob larger than 16 MiB
   or aggregate old/new blob material larger than 256 MiB, then generate the
   diff into the private bundle with configured external diff helpers and
   text-conversion disabled (`--no-ext-diff --no-textconv`) and reject it above
   64 MiB;
9. launch the reviewer with the sanitized snapshot—not the original worktree—as
   its working directory; give it snapshot-local diff and manifest paths and
   retain `Read,Glob,Grep` so it can inspect surrounding tracked files and every
   numbered untracked copy; the prompt must say that both sources form the
   reviewed change; and
10. if a supported Claude CLI cannot enforce the denied Bash tool, mark that
   reviewer unavailable/degraded—never silently regrant Bash.

This is the Linux/macOS boundary; do not add `bwrap` or `sandbox-exec`.
Prompt text while granting Bash does not satisfy this issue.
Keep the boundary in one bead despite its size: first implement and test the
bundle builder without treating it as enforcement, then integrate the fixed
no-shell runner policy and callers, and only then call the boundary enforced.
No intermediate helper-only commit may close the bead. Use a reviewed hard stop
of 1,500 production lines and 2,500 fixture lines; crossing it returns to SHAPE
for an explicit split rather than improvising extra graph rows.
Required bundle fixtures include an untracked executable whose content is
identical at modes 100644 and 100755; the manifest and reviewer input must
distinguish them. Additional fixtures cover an unrelated untracked credential,
a stale allowlist entry, an ignored `.env`, the 1 MiB per-file boundary, and the
8 MiB aggregate boundary. Tracked fixtures with `export-ignore`,
`export-subst`, and a smudge filter must appear byte-identical to the current
worktree in the snapshot. Further pre-launch refusal fixtures cover
assume-unchanged, skip-worktree, an absolute symlink, a relative escaping
symlink, the 16 MiB tracked-file boundary, and the 256 MiB tracked aggregate.
A staged-deletion fixture covers the 16 MiB base-side boundary and a separate
fixture covers the 64 MiB generated-diff boundary. A hostile Git configuration
fixture installs both `diff.external` and an attribute-backed textconv driver
and proves neither helper executes and the native diff is bundled. The ignored
file must be absent from the snapshot, and no refusal case may launch the
reviewer.

## Workstream D — installer and upgrade correctness

### D1. Old-Bash and empty discovery — issues #61 and #38

**Priority:** P2. **Effort:** medium.

**Files**

- `install.sh`
- `install.test`

Establish a Bash 4.0–4.3 execution strategy, guard empty argv, and make empty
skill discovery emit no phantom skill. The matching #65 empty-array checkbox is
the same implementation, not a second patch.

### D2. Re-exec provenance — issue #62 and #65 marker diagnostic

**Priority:** P0. **Effort:** medium. **Depends on:** D1 test harness.

Continue re-exec for piped installs and a pulled installer at the same canonical
install path. A readable installer from another checkout must continue executing
its own bytes. An absent, non-regular, or unreadable re-exec marker is a
categorized nonzero failure on stderr; do not fall back to another checkout or
execute bytes whose provenance was not established.

Ownership is `install.sh` and `install.test`. Focused fixtures cover a piped
install, a pulled installer re-executing the same canonical path, empty argv,
another readable checkout retaining its own bytes, and every marker failure.
Each fixture records which sentinel bytes executed and proves no fallback bytes
ran. Run `./install.test` and `./check.sh`. This protects the user's requested
installer provenance: running bytes from another checkout can install a tree the
user did not invoke.

### D3. YAML-equivalent companion names — issue #63

**Priority:** P2. **Effort:** small/medium.

Parse the minimal YAML scalar spellings Tau accepts: plain, single-quoted,
double-quoted, and valid trailing comments. Continue rejecting malformed
frontmatter, duplicate keys, and real mismatches without adding a heavyweight
dependency.

## Workstream E — Beads and generated workflow safety

### E1. Fail-closed JSONL path ownership — issue #44 and issue #65

**Priority:** P0. **Effort:** medium.

Create exact companion owner:

- `skills/beads-jsonl-path/SKILL.md`;
- `skills/beads-jsonl-path/scripts/resolve-beads-jsonl`; and
- `skills/beads-jsonl-path/scripts/resolve-beads-jsonl.test`.

`resolve-beads-jsonl` runs the following resolution, additionally verifies that
the result is inside the current Git worktree, and prints only that absolute path
on success. Sweep every executable block, prose instruction, and comment that
resolves the Beads JSONL to use the exact installed companion path, falling back
to the checkout owner only when no installed target resolves. Require:

```bash
_bw=$(br where --json) ||
  { echo "cannot resolve the beads workspace" >&2; exit 1; }
BEADS_JSONL=$(
  printf '%s' "$_bw" |
    jq -ers '
      if length == 1 and
         ((.[0] | type) == "object") and
         ((.[0].jsonl_path | type) == "string") and
         ((.[0].jsonl_path | length) > 0) and
         ((.[0].jsonl_path | contains("\u0000")) | not) and
         ((.[0].jsonl_path | test("[\r\n]")) | not)
       then .[0].jsonl_path
       else error("expected exactly one non-empty string jsonl_path")
       end
     '
) || { echo "cannot resolve exactly one beads JSONL" >&2; exit 1; }
```

or one tested fact owner with equivalent fail-closed behavior.

The displayed shell pins the JSON cardinality and rejects NUL/CR/LF before
command substitution can strip or misrepresent path bytes; the companion owns
the remaining byte-safe inspection. It canonicalizes the current worktree root
and resolved parent without following the final path, requires the path to be
inside that root, and reads raw NUL-delimited `git ls-files --stage -z`,
`git ls-files -v -z`, and `git ls-tree -z HEAD` records. Success requires exactly
one stage-0 tracked regular-file entry, mode `100644`, tag `H` (not lowercase
assume-unchanged or `S` skip-worktree), the same regular mode in HEAD, and a
non-symlink regular worktree file. It reads the HEAD blob, index blob, and
worktree bytes without filters and requires all three byte strings to be
identical before printing the path. It therefore refuses staged, unstaged,
mode-only, hidden-index-flag, unmerged, missing, ignored/untracked, symlink,
gitlink, and wrong-worktree states rather than trusting porcelain visibility.

Likely consumers include Drive, plan transfer, bead polish, rb-lite backlog
drain, and orchestration guidance. Add this companion to their selective-install
dependencies and wire its direct test into `check.sh`.

The owner must print a useful stderr diagnostic and exit nonzero for: `br where`
returning nonzero after emitting valid JSON; missing, null, empty, or non-string
`jsonl_path`; zero or multiple JSON documents; malformed JSON; missing/failing
`jq`; NUL/CR/LF path values; and a resolved path outside the current worktree.
Focused fixtures prove that each failure performs no Beads mutation or flush.
Further fixtures cover staged-only, unstaged-only, staged-plus-unstaged,
mode-only, assume-unchanged, skip-worktree, unmerged, symlink, gitlink,
ignored/untracked, missing, and nonregular JSONL state, plus a path inside a
different worktree; each is refused before any mutation or flush. This is P0
because the
first `br` write after an ambiguous resolution can export a stale cache over the
tracked JSONL and silently destroy unstaged bead bodies.

E1 owns resolution and clean-worktree inspection only. It updates every
consumer, including harden-until-clean, to use that fact owner; E3 separately
owns the exact close-plus-flush transaction after resolution succeeds.

### E2. Generated agent protocol conflict — issue #33

**Effort:** split into bounded children.

Create:

- **E2a, P0:** replace unconditional delegation with a fail-closed semantic
  preview. Read the complete `br agents --add --dry-run` output against the
  existing AGENTS branch, review, gate, and closure contract. If its session
  commit/push protocol conflicts, omit the entire generated Beads block and
  report the exact conflicting clauses; do not reconcile, partially copy, or
  claim that separate markers imply semantic compatibility. Install the block
  only when the preview is semantically compatible. An `install.test` fixture
  covers a branch-and-PR agreement and proves no generic session block is
  installed or human-owned Beads text changed; a compatible minimal repository
  fixture proves the full generated block may be installed unchanged.
- **E2b, P2:** use `br agents --add --force` (or `--update --force`) only after
  E2a accepts the preview, so compatible generation is bounded without a TTY.
  Fixtures cover EOF/noninteractive success after acceptance, noninteractive
  omission after conflict, and no prompt hang.
- **E2c, P2:** own the “When the loop misbehaves” guidance in
  `skills/orchestrating-with-rb-lite/SKILL.md` plus executable prose extraction
  fixture `skills/orchestrating-with-rb-lite/scripts/diagnostic-guidance.test`.
  Before attributing exit 143/137 to collateral `pkill`, require reading reviewer
  JSON `terminal_reason`, `subtype`, and errors plus the disconfirming check for
  non-rb-lite process deaths. Remove “almost always.” A single failed concurrent
  panel is not evidence that parallel review is broken and must not recommend
  serialization. Fixtures feed an API abort, an actual signal, and one failed
  parallel round and assert the bounded diagnosis text/outcome. Run it and
  `./check.sh`.

The skeptic-convergence observation is not a fourth E2 bead; F1 owns it together
with #47's fact-ownership policy.

### E3. Exact closure command — issue #65

**Priority:** P0. **Effort:** extra small.

Align harden-until-clean with the canonical fail-closed closure command and
explicit flush behavior. Create exact companion owner:

- `skills/beads-close-transaction/SKILL.md`;
- `skills/beads-close-transaction/scripts/beads-close-transaction`; and
- `skills/beads-close-transaction/scripts/beads-close-transaction.test`.

Its API is:

```text
beads-close-transaction --check-recovery
beads-close-transaction close --id ID --reason-file PATH
```

Every scoped scheduler calls `--check-recovery` before `br ready`, `br list`, or
any mutation. The owner atomically acquires one recovery/transaction lock under
the resolved Beads directory, runs E1, saves a private pre-close JSONL and
material `br show` state, then performs the exact close and explicit flush:

```bash
br close "$bead_id" --reason "$merge_evidence" --no-auto-flush ||
  { verify_still_open_or_retain_lock; echo "cannot close $bead_id" >&2; exit 1; }
if br sync --flush-only; then
  verify_db_and_jsonl_closed_or_retain_lock
else
  echo "closure not persisted for $bead_id; compensating" >&2
  br reopen "$bead_id" --reason "rollback: closure export failed" \
    --no-auto-flush || retain_lock_and_require_recovery
  br sync --flush-only || retain_lock_and_require_recovery
  verify_reopened_or_retain_lock
  exit 1
fi
```

`bead_id` must be the exact claimed finding ID and `merge_evidence` must contain
the reviewed work-PR URL and merge SHA. Do not use `br update ... -s closed`,
continue after either failure, or report closure before the explicit flush.

The helper cannot make SQLite plus JSONL one filesystem transaction, so it owns
verified compensation. If close fails, prove the bead remains open. If flush
fails after SQLite closes, immediately run `br reopen "$bead_id"
--reason "rollback: closure export failed" --no-auto-flush`, retry the explicit
flush, and verify the bead is open, its material fields/dependencies match the
saved state, and no dependent remains newly ready. A successful compensation
returns nonzero but removes the scheduler lock only after that proof. If reopen,
re-flush, or verification fails, retain the lock and private recovery bundle,
emit `BEADS_RECOVERY_REQUIRED` plus its path, and make all compliant scheduler
queries refuse until explicit recovery. On success, verify both DB and JSONL say
closed before removing the lock.

Add the companion to every scheduler/closure consumer's selective dependencies
and wire its test into `check.sh`.
`skills/orchestrating-with-rb-lite/scripts/harden-closure.test` is the focused
consumer extraction fixture. Direct and consumer fixtures cover close failure;
disabled auto-flush plus forced flush failure and successful compensation;
reopen/re-flush failure retaining the recovery lock; exact-ID selection;
dependents never escaping during compensation; and successful close. Run both
tests, `./install.test`, and `./check.sh`.

## Workstream F — Drive/rb-lite controller and convergence

### F1. Deduplication and fact ownership — issue #47

**Priority:** P2. **Effort:** medium. Can land before F2.

Own `skills/multi-reviewer-loop/references/disposition-rules.md` and the
fractal-tail/convergence sections in `skills/multi-reviewer-loop/SKILL.md`.
Add executable
`skills/multi-reviewer-loop/scripts/disposition-convergence.test`, wired into
`check.sh`. The disposition record gains:

```text
DEDUPE owner=<path-or-generated-command> copies=<NUL-safe path set>
       action=<delete copies|replace with references|derive mechanically>
```

When a finding concerns a checkable fact stated in multiple places, require one
owner and delete/reference/derive every other copy in the same round. A
wording-only tail remains a normal disposition; checkable numbers, statuses, or
commands are never waived merely for arriving late. Do not use delta-only review
or defer all P3 findings as the remedy.

Also own #33's skeptic-convergence observation: when the coordinator cannot
distinguish substantive convergence from review tail, give the same panel the
round-by-round finding/disposition history and ask independently for
LAND/CONTINUE plus the class the loop is systematically missing. Record both
answers and disagreement; panel advice is diagnostic evidence, never authority
to bypass the gate or unresolved findings. Fixtures cover a finding about a
newly duplicated fact becoming DEDUPE with one named owner, a wording-only tail
that does not hide a checkable false fact, and split panel advice that remains
visible. The fixture exercises DEDUPE with one owner and multiple copies,
wording tail versus a checkable false fact, skeptic withdrawal under recorded
rationale, and split panel advice. Run it and `./check.sh`.

### F2. Synchronous checkpoint seam — issue #48 upstream portion

**Priority:** P1. **Effort:** large/external dependency. **Depends on:** C2.

**Executor:** `executor-rb-lite`.

Run this bead through a separately spawned agent whose current repository is
`/home/master/p/rb-lite`; do not hand it to the skills-repository backlog drain.
That agent must read `/home/master/p/rb-lite/AGENTS.md`, create
`feat/drive-checkpoint-hook` from current `origin/main`, and use
`orchestrating-with-rb-lite` in that checkout for the Codex-heavy implementation.
Run all three upstream gates even when an earlier one fails, capture each real
status separately, and require all three to be zero. Put the following
self-contained body between the delimiter lines of the exact canonical gate
wrapper in the skills repository's managed `AGENTS.md`; do not introduce a
second trap, temporary-log owner, or cancellation lifecycle:

```bash
just_test_rc=0
nix_build_rc=0
flake_check_rc=0
if just test; then :; else just_test_rc=$?; fi
if nix build; then :; else nix_build_rc=$?; fi
if nix flake check; then :; else flake_check_rc=$?; fi
printf 'just_test=%s nix_build=%s flake_check=%s\n' \
  "$just_test_rc" "$nix_build_rc" "$flake_check_rc"
test "$just_test_rc" -eq 0 &&
  test "$nix_build_rc" -eq 0 &&
  test "$flake_check_rc" -eq 0
```

Open and land the minimal rb-lite checkpoint-hook PR through the upstream
repository's branch workflow. The child must own its lifecycle and quiescent
boundary. It must also expose a stable machine-readable capability probe,
`rb-lite capabilities --json`, whose successful checkpoint-capable result
contains `"synchronous_checkpoint":1`. Pin that command and malformed/missing
capability cases in upstream tests. Do not implement #30's log-tail sidecar.

The upstream interface is fixed for F2:

```text
rb-lite run ... --checkpoint-cmd CMD --checkpoint-timeout-seconds N
```

- invoke `CMD` synchronously with stdin closed and no implementer/reviewer child
  alive at `post_implementer` after each successful implementer
  iteration/fingerprint and at `post_review` after every reviewer joins but
  before the panel result is acted on;
- provide `RB_LITE_CHECKPOINT`, `BASE`, `RUN_DIR`, `ROUND`, and `ITERATION`, plus
  `REVIEW_PANEL_RESULT=clean|findings|failed` at `post_review`;
- save checkpoint stdout, stderr, and status in `RUN_DIR`;
- require a positive finite timeout, run the hook in its own process group, and
  on expiry perform bounded TERM/CONT/KILL cleanup before returning;
- status 0 continues, status 20 preserves the diff/artifacts and returns a
  distinct `checkpoint_stopped` terminal status, and every other nonzero returns
  `checkpoint_failed`; timeout returns a third distinct
  `checkpoint_timed_out` status and fixed process exit code;
- include checkpoint name, round, iteration, and hook status in the single
  terminal JSON object, with fixed distinct rb-lite process exit codes for both
  terminal statuses.

Deterministic upstream tests must cover both boundaries, the stabilizing
iteration, actual joined-panel result, 0/20/other statuses, preserved artifacts,
timeout with a stopped/resistant descendant, and TERM/INT child reaping. The
terminal JSON records the configured deadline and whether cleanup escalated.
The hook does not parse a Drive contract, persist a
state database, poll logs, reset/cut the diff, or learn BUILD/HARDEN/LAND.

The coordinating skills agent verifies the upstream PR URL, merge SHA, and all
three gate exit codes. It then records and closes F2 only through the dedicated
reviewed metadata transaction: create `metadata/close-f2-checkpoint` from current
`master`; use E1 to prove the JSONL clean; make only the F2 evidence/closure JSONL
change plus the `DRIVE.md` Done/Now/Next update; push and open a PR whose body
contains `bead-closure: <F2-bead-id>`; once GitHub assigns `N`, amend `DRIVE.md`
to `Pending: metadata PR douglaz/skills#N`; rerun the skills gate and panel on
the amended tree; force-push with lease; and merge that PR. Do not combine this
metadata with another execution row or record DONE while other scoped rows
remain.

Do not mutate the skills Beads store from the rb-lite checkout, on an active
unrelated skills branch, or directly on skills `master`.

Here `F2` means the resolved generated bead ID, not the plan alias. The terminal
mutation is `br close <F2-bead-id>`—not `br update ... -s closed`—followed by
the checked explicit sync. The evidence is added to the bead before that close
with `br update <F2-bead-id> --notes ...` on the same reviewed closure branch.

Publishing the required upstream release is a separate human-authority
checkpoint recorded in `DRIVE.md`; local controller BUILD remains blocked until
that release exists.

### F2r. Publish the upstream checkpoint release — issue #48

**Priority:** P1. **Effort:** human-authority gate. **Depends on:** F2.

Record explicit human authorization, publish the release, and record its
immutable version/reference. This bead must not start or close merely because F2
merged.

F2r is a two-stage authority transaction within one bead. While awaiting
authorization it stays open, unclaimed, and is reported only through the
`authority-human` lane. Once the human records affirmative authorization, the
coordinating skills agent—not a generic implementation drain—claims F2r and
performs the mechanical release publication, probe, and reviewed metadata
record. The authority label remains because the prohibited action is still
governed by that record; it does not mean the human must execute release tooling.
Publication follows the rb-lite repository's release instructions and is the
only external side effect authorized by this bead.

The authorization record and immutable version/commit go in both the bead notes
and `DRIVE.md`. Publication is not complete until the released artifact itself
exists and passes. Record the GitHub release URL, immutable tag, and full commit.
Require `gh release view <tag> -R douglaz/rb-lite` to report a published,
non-draft release, and require both the tag ref and its peeled annotated-tag ref
(when present) from `git ls-remote` to resolve to the recorded commit. A mismatch,
lightweight/annotated ambiguity, moving tag, or absent release blocks closure.
Then probe the tag-qualified released artifact:

```bash
TAG="<immutable-tag>"
COMMIT="<immutable-commit>"
_release=$(
  gh release view "$TAG" -R douglaz/rb-lite \
    --json url,tagName,isDraft,isPrerelease
) || { echo "published rb-lite release is absent" >&2; exit 1; }
printf '%s' "$_release" |
  jq -e --arg tag "$TAG" \
    '.tagName == $tag and .isDraft == false' >/dev/null ||
  { echo "rb-lite release metadata does not match authorization" >&2; exit 1; }
_refs=$(git ls-remote --tags https://github.com/douglaz/rb-lite.git \
  "refs/tags/$TAG" "refs/tags/$TAG^{}") ||
  { echo "cannot resolve published rb-lite tag" >&2; exit 1; }
_tag_commit=$(printf '%s\n' "$_refs" |
  awk -v tag="refs/tags/$TAG" '
    $2 == tag { direct=$1; direct_n++ }
    $2 == tag "^{}" { peeled=$1; peeled_n++ }
    END {
      if (direct_n != 1 || peeled_n > 1) exit 1
      print (peeled_n == 1 ? peeled : direct)
    }
  ') || { echo "rb-lite tag resolution is ambiguous" >&2; exit 1; }
[ "$_tag_commit" = "$COMMIT" ] ||
  { echo "rb-lite release tag does not resolve to the authorized commit" >&2; exit 1; }
_caps=$(
  nix run "github:douglaz/rb-lite/$TAG" -- capabilities --json
) || { echo "published rb-lite is not runnable" >&2; exit 1; }
printf '%s' "$_caps" |
  jq -e '.synchronous_checkpoint == 1' >/dev/null ||
  { echo "published rb-lite lacks synchronous checkpoint capability" >&2; exit 1; }
_refs_after=$(git ls-remote --tags https://github.com/douglaz/rb-lite.git \
  "refs/tags/$TAG" "refs/tags/$TAG^{}") ||
  { echo "cannot recheck published rb-lite tag" >&2; exit 1; }
[ "$_refs_after" = "$_refs" ] ||
  { echo "rb-lite release tag moved during verification" >&2; exit 1; }
```

Replace every placeholder with the recorded values. Fixtures or a checked
release transcript cover lightweight and annotated tags, absent/draft releases,
tag/commit mismatch, and successful capability probing. Authorization without
a published, consumable, tag-and-commit-verified artifact does not close F2r;
F3 separately pins the verified commit as its immutable fallback rather than a
path-only, moving-tag, or version-text guess.
Run the tag-qualified capability command through the same 120-second
process-group deadline and bounded TERM/CONT/KILL cleanup required by F3; a
hanging release artifact is not consumable and cannot close F2r.

### F3. Foreground Drive controller — issues #48, #30, #31, #35

**Priority:** P1. **Effort:** extra large. **Depends on:** C1 and F2r.

Implement:

- resolve rb-lite candidates by capability, not path presence or version text:
  reject a PATH candidate unless `rb-lite capabilities --json` exits 0 and
  reports `"synchronous_checkpoint":1`; otherwise fall back to
  `nix run github:douglaz/rb-lite/<F2r-immutable-commit> --`, probe that exact
  command too, and fail preflight if neither qualifies. Bound each probe to a
  declared positive timeout (default 120 seconds), stdin closed and a private
  process group; timeout performs bounded TERM/CONT/KILL cleanup. A timed-out
  PATH candidate falls through to the immutable probe, while a timed-out
  immutable probe is a categorized preflight failure;
- declared round limits passed to rb-lite;
- separate production and test LOC budgets;
- validate the contract before launch so every allowed path belongs to exactly
  one production/test budget class or to an explicit unbudgeted exemption;
  overlapping or unclassified allowed paths are contract errors;
- at each checkpoint, return the controlled-stop status for every changed path
  outside the allowlist, outside all declared classes/exemptions, or over its
  class budget—no path may escape both counters;
- distinct churn and scope brake reasons;
- acceptance-criterion re-read before cutback;
- gate execution after a cutback;
- structured terminal result consumption;
- atomic BUILD-to-HARDEN continuation; and
- durable pass count and resume behavior.

Keep F3 as one controller bead because the resolver, checkpoint policy, and
resume state form one foreground transaction, but implement and review it in
three explicit internal stages: (1) immutable capability resolver/preflight;
(2) checkpoint allowlist, class budgets, brakes, cutback, and post-cutback gate;
and (3) structured terminal result, atomic phase continuation, pass count, and
resume. The owner is `skills/drive/scripts/drive-run` with a deterministic
`skills/drive/scripts/drive-run.test`, wired into `check.sh`. No stage is a
closable partial deliverable, and no test may launch a real model. Use a reviewed
hard stop of 1,500 production lines and 2,500 fixture lines; crossing it returns
to SHAPE for a graph split.

Close #30, #31, and #35 only after their observed failures are deterministic
fixtures. #47 remains an independent policy deliverable even if #48 tracks the
controller umbrella.

F3 fixtures must put a stale pre-checkpoint `rb-lite` first on PATH and prove
the resolver selects the immutable F2r fallback; a missing or malformed
capability response must fail closed rather than run the stale binary. A hanging
PATH probe with a resistant/stopped descendant must be reaped before the
fallback starts, and a hanging fallback must fail within its bound with no
descendant or model launch. Separate
fixtures must cover an outside-lock path, an allowed-but-unclassified path,
overlapping classes, an explicit unbudgeted exemption, and independent
production/test budget breaches.

## Workstream G — executable evidence and documentation

### G1. Read-only commit verifier — issue #32

**Priority:** P2. **Effort:** medium/large.

Create exact companion owner `skills/verify-commit/` with:

- `skills/verify-commit/scripts/verify-commit`;
- `skills/verify-commit/scripts/verify-commit.test`; and
- selective-install companion wiring for Drive, multi-reviewer-loop,
  second-model-bead-audit, and agents-md consumers.

The fixed argv API is:

```text
verify-commit [--rev REV]
  [--expect PATH LITERAL]...
  [--expect-count PATH LITERAL COUNT]...
  [--expect-absent PATH]...
  [--path PATH]... [--exact-paths]
```

`--expect` requires at least one byte-for-byte literal occurrence;
`--expect-count` counts non-overlapping byte occurrences, including multiple
occurrences on one line and zero; `--expect-absent` requires the path to be
absent from the commit; and `--exact-paths` requires the revision diff to contain
exactly the repeated `--path` values, compared as raw path bytes. `--rev`
defaults to `HEAD`; the compared path set is `REV^1..REV`, and a root commit uses
Git's empty tree as the parent. For a merge commit, only first-parent changes are
in scope and the diagnostic states that fact. Enumerate the path set with rename
detection disabled, so a rename is one deleted old path plus one added new path;
both endpoints are required. Use raw NUL-delimited Git output and explicitly
disable external diff, textconv, rename config, and pager behavior. A hostile
repository/global configuration must not change the set or execute a helper.

Reject empty literals, negative/non-decimal counts, binary blobs for literal
operations, an unborn/unreadable revision, ambiguous options, conflicting
expectations, or `--path` without `--exact-paths`. At least one repeated `--path`
is required with `--exact-paths`. Unix argv cannot represent NUL, so NUL-path
support is neither claimed nor tested. Fixtures pin adds/deletes/renames, root
and merge commits, hostile diff/textconv/rename configuration, empty literals,
and both invalid `--path` combinations.
Exit 0 means every expectation matched, 1 means a checked mismatch, and 2 means
invocation/dependency/repository/read failure; diagnostics on stderr name the
revision, path encoded unambiguously, and failed expectation without dumping
blob content.

The checker reads Git objects and diffs only: it never writes the worktree,
index, refs, config, or object database. Tests hash the index/worktree/ref state
before and after every success and failure. Set `GIT_NO_LAZY_FETCH=1` for every
Git object read; a missing promisor object is status 2 and may not contact a
remote or populate the object database. A partial-clone fixture installs a fake
promisor remote, leaves the required blob absent, and proves no remote marker or
new object appears. Cover the regression cases listed in
#32: metacharacters, leading dashes, multiple occurrences on one line, count
zero under `pipefail`, SIGPIPE/large-file early match, whole-file deletion,
accidental retained-file deletion, and unexpected paths. Run the direct test,
selective-install fixtures, and `./check.sh`.

This is post-commit evidence and is not B1's delegated-edit isolation mechanism.

### G2. Executable-document harness — issue #49

**Priority:** P2. **Effort:** large. **Depends on:** G1.

Create exact companion owner:

- `skills/executable-docs/SKILL.md`;
- `skills/executable-docs/scripts/executable-docs`;
- `skills/executable-docs/manifests/behavioural-claims.json`; and
- `skills/executable-docs/scripts/executable-docs.test`.

Its fixed API is:

```text
executable-docs --document PATH --manifest PATH
```

The first and only registered document is
`skills/agents-md/references/behavioural-claims.md`. Give each of its five
`console` fences a stable adjacent HTML ID. The manifest pins the exact ordered
ID set, source digest, shell/version prerequisites, per-example timeout,
normalizers for random temporary paths and host binary/version prefixes, and
expected stdout, stderr, and status. The parser accepts only `$ ` command starts
and `> ` continuations, rejects duplicate/missing/unregistered IDs, malformed
prompt structure, unexpected fence drift, unsupported normalizers, and any
registered block whose transcript cannot be separated unambiguously.

Run each example in its own mode-0700 temporary directory and initialized
disposable Git repository, with private HOME/XDG/TMPDIR, stdin closed, credential
and agent environment removed, a fixed minimal PATH resolved before launch,
bounded process-group cleanup, and separated stdout/stderr/status artifacts.
The registered source digest and executable allowlist make this a harness for
reviewed examples, not an evaluator for arbitrary Markdown or untrusted shell.
Portable network sandboxing is a non-goal; no registered block may use a network
client, and the test rejects a manifest/source mutation that introduces one.
Cleanup or transcript-normalization failure is nonzero and preserves private
artifacts only when a diagnostic explicitly names their path.

Wire the harness test and the registered behavioural-claims run into
`check.sh`. Experimentally validate the apparatus with one mutation per defect:
late trap-variable expansion, unchecked `mktemp`, predictable temp output,
redirection bound to the wrong command, execution outside Git, `$?` captured
after substitution, unexported TMPDIR, inherited SHELLOPTS/BASH_ENV/function,
wrong expected stream, wrong status, and timeout with a descendant. Each
mutation fixture first updates the copied manifest's source digest so it reaches
execution rather than failing the generic drift guard, then must make the named
property assertion fail; assert the failure diagnostic names that property.
Then run `./check.sh`.

### G3. Managed-block length decision — issue #50

**Priority:** P3. **Effort:** small. **Depends on:** G1/G2.

Reassess whether the 183-word behavioral-claims rule can shrink once mechanisms
own its detail. Leaving it intact is an acceptable evidence-based disposition.

Record the decision in the bead notes and, if content changes, in the owning
document/commit. Inventory all four load-bearing sub-rules and measure the
managed paragraph with the repository's existing folded-description/word-count
conventions. Shrink only if every sub-rule remains actionable and the G2
registered examples still carry the removed operational detail; otherwise
retain it and record why. There is no required pre-fix red run for a legitimate
retain decision. Run G1/G2 evidence and `./check.sh` after any tracked edit; a
notes-only retain decision records the exact measurement commands and statuses
instead.

## Complete execution-bead table

The GRAPH transfer creates exactly one execution or decision bead per row. This
table is the authoritative priority and dependency source; prose above supplies
the body. Every row gets label `drive-open-issues`; B0 and F2r get
`authority-human`, F2 gets `executor-rb-lite`, and every other row gets
`executor-skills`.

| Bead | Priority | GitHub | Depends on | Deliverable |
|---|---:|---|---|---|
| A1 | P0 | #42 | — | Tip-scope bot review objects |
| A2 | P1 | #66 | A1 | Traceable per-thread disposition |
| A3a | P1 | #65 | A1 | Preserve first degraded exit-4 evidence |
| A3b | P1 | #65 | A1 | Private unique post-merge evidence |
| A3c | P1 | #65 | A1 | Exclude closure PRs from work-PR resume |
| A4a | P3 | #65 | — | Drive routing wording and trigger fixture |
| A4b | P3 | #65 | — | Fence moved backlog examples |
| B0 | P0 | #41, #43, #34, #65 | — | Record the human dirty-state decision |
| B1d | P0 | #41, #43, #34, #65 | B0 | Delegated-edit design and fixture contract |
| B1 | P0 | #41, #43, #34, #65 | B1d | Delegated-edit isolation implementation |
| B2a | P1 | #34 | — | Unsafe red evidence blocks completion |
| B2b | P0 | #34 | — | Preserve colocated tests during inversion |
| B2c | P2 | #34 | C1 | Tested panel shutdown/escape |
| B2d | P2 | #34 | G1 | Do not mask verification execution errors |
| B2e | P0 | #34 | — | Compare flush against saved bytes |
| C1 | P1 | #53–#58, #60 | — | Shared bounded Claude reviewer runner |
| C2 | P1 | #51 | C1 | Bound rb-lite reviewer model |
| C3 | P0 | #59 | C1 | Enforced reviewer isolation |
| D1 | P2 | #61, #38, #65 | — | Old-Bash argv and empty discovery |
| D2 | P0 | #62, #65 | D1 | Re-exec provenance and marker diagnostic |
| D3 | P2 | #63 | D1 | YAML-equivalent companion names |
| E1 | P0 | #44, #65 | — | Fail-closed JSONL path ownership |
| E2a | P0 | #33 | — | Resolve generated protocol conflict |
| E2b | P2 | #33 | E2a | Noninteractive generated behavior |
| E2c | P2 | #33 | E2a | Correct panel diagnostics |
| E3 | P0 | #65 | E1 | Exact fail-closed closure command |
| F1 | P2 | #47, #33 | — | Deduplication and fact ownership |
| F2 | P1 | #48 | C2 | Upstream synchronous checkpoint seam |
| F2r | P1 | #48 | F2 | Human-authorized release publication |
| F3 | P1 | #48, #30, #31, #35 | C1, F2r | Foreground Drive controller |
| G1 | P2 | #32, #34 | — | Read-only commit verifier |
| G2 | P2 | #49 | G1 | Executable-document harness |
| G3 | P3 | #50 | G1, G2 | Managed-block length decision |

Constraints:

- Only one owner edits the delegated-edit or panel-runner file set at a time.
- B2c remains a consumer-level #34 integration regression after C1 owns the
  lifecycle; E3 remains the exact harden-until-clean close/flush transaction
  after E1 owns resolution. Neither is a duplicate of its prerequisite.
- Retain the direct F3→C1 and G3→G1 edges even though each is also reachable
  transitively. F3 directly consumes C1's runner independently of the upstream
  release chain, and G3 directly uses G1 evidence independently of G2. The
  intermediate bead being rejected or re-scoped must not erase either direct
  prerequisite.
- B0 and F2r are explicit decision/authority beads. They remain blocked for
  human input even when their graph prerequisites are satisfied.
- The upstream F2 implementation/PR may proceed before F2r authorization.
- The scheduler queries each lane separately because repeated label filters use
  AND semantics:

  ```bash
  br ready -l drive-open-issues -l executor-skills
  br ready -l drive-open-issues -l executor-rb-lite
  br ready -l drive-open-issues -l authority-human
  ```

  The first lane runs in this repository, the second routes to the
  cross-repository procedure above, and the third is reported for human action
  but never sent to an implementer.

## Beads graph to update

After review, update the existing graph in place into:

- exactly one flat execution/decision bead per row in the complete
  execution-bead table, with no tracking parent or epic;
- every dependency edge in that table;
- GitHub URLs and named gate commands in every executor bead;
- the decision/publication evidence named for B0 and F2r instead of an
  implementation gate; and
- the exact priority and executor labels in the table.

The first scoped `br ready` result must contain A1. D1 and E1 may also be ready.
B1d must close before B1 can enter BUILD. F2 must record its upstream issue/PR
URL before it can become in progress.

## Completion

The drive is complete only when:

1. every accepted child is merged through its own reviewed branch;
2. for every GitHub issue referenced by multiple table rows—including #33, #34,
   #48, and #65—all matching rows are merged or rejected with evidence before
   that issue closes;
3. the scoped Beads graph has no open item;
4. the aggregate repository gate exits 0 on final `master`; and
5. GitHub issue closure and Beads closure records agree.

## Known unknowns

- Bash 4.0–4.3 availability for #61's live compatibility gate.
- The exact immutable rb-lite release reference remains pending F2r authority.
- Whether #66 requires content digests after stable-ID reproduction.
- The human B1 decision between refusal and dirty in-scope preservation.
- Human authorization to publish the F2 upstream release.
