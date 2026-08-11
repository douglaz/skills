# Backlog execution plan

## Status

Draft for review. This plan covers the 29 GitHub issues that were open in
`douglaz/skills` on 2026-08-11. GitHub remains the external source of issue
identity. Beads will hold the executable dependency graph once this plan passes
review.

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
- Open GitHub issues: 29.
- Open pull requests: none at plan creation.
- The open issues have no labels, assignees, or milestones. Priorities in this
  plan are inferred from failure impact and evidence in the issue bodies.
- Beads is not initialized: there is no `.beads` directory, database, or JSONL.
  This was measured on 2026-08-11 with stdout and stderr captured separately:

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
- The previous `DRIVE.md` described PR #64 after it had already merged. This plan
  replaces that stale record rather than continuing its HARDEN phase.
- Exact issue scope:
  `#30, #31, #32, #33, #34, #35, #38, #41, #42, #43, #44, #47, #48,
  #49, #50, #51, #53, #54, #55, #56, #57, #58, #59, #60, #61, #62,
  #63, #65, #66`.
- Repository gate for branches in this plan:

  ```bash
  ./install.test &&
  ./skills/pr-with-codex-bot-review/scripts/bot-gate.test &&
  ./skills/drive/scripts/drive-status.test
  ```

  An `executor-skills` bead may add a narrower red/green command, but the
  aggregate gate still runs before clearance and landing. F2 uses the upstream
  gate specified in its section. Human-authority beads require a decision or
  publication record rather than the skills gate.

## Tracker contract

GitHub owns external issue identity, discussion, and closure. Beads owns local
execution state and dependencies.

- Initialize Beads only after this plan passes its SHAPE review.
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

**Deliverable**

Add a normal-push fixture showing that a review object anchored to a prior tip
cannot satisfy request coverage for the current tip, then restrict ordinary
coverage anchors accordingly. Preserve explicitly documented degraded-forge
behavior.

**Done when**

- the new fixture fails against the unfixed gate for the intended assertion;
- it passes after the implementation;
- all existing `bot-gate.test` cases pass; and
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

Create:

- **A3a, P1:** preserve the first degraded exit-4 response across re-entry;
- **A3b, P1:** create post-merge evidence through a unique private file with
  checked writes; and
- **A3c, P1:** exclude closure PRs from the work-PR resume query.

### A4. Bounded plan-format follow-ups — issue #65

**Effort:** two extra-small beads, separate from admission logic.

- **A4a, P3:** clarify Drive's project-status/resume routing exception without
  changing its trigger-evaluation outcomes.
- **A4b, P3:** convert the moved backlog examples to fenced Markdown.

## Workstream B — delegated-edit state integrity

### B0. Dirty-state preservation decision — issues #41, #43, #34, #65

**Priority:** P0. **Effort:** human decision record.

Record the human choice from `DRIVE.md` as a Beads decision bead. Recommendation:
refuse unsupported dirty delegated paths and use a disposable worktree. B1 stays
blocked until this bead records the answer; the bead never treats silence as
approval.

B0 may close only if the human accepts the planned fail-closed refusal boundary.
If the human chooses full dirty in-scope preservation, leave B0 open, return the
drive to SHAPE, specify and review that larger preservation mechanism, then amend
the graph with a reviewed design bead that blocks B1. The choice never makes B1
ready against the current plan.

### B1. Delegated-edit isolation mechanism — issues #41, #43, #34, #65

**Priority:** P0. **Effort:** large design/build. **Depends on:** B0.

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
8. apply only after every guard succeeds.

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
- untracked and deleted descendants; and
- restore/apply failure.

### B2. Remaining #34 safety children

Split from B1 with one priority per child:

- **B2a, P1:** unsafe red evidence must report INCOMPLETE/BLOCKED rather
  than land.
- **B2b, P1:** file-level inversion must not destroy colocated tests.
- **B2c, P2:** panel shutdown/escape behavior must use C1's tested owner.
- **B2d, P2:** `grep ... || true` must not convert execution errors to
  success; use G1's verification owner.
- **B2e, P1:** post-flush comparison must use saved pre-flush bytes, not
  `HEAD`.

## Workstream C — reviewer runner reliability and isolation

### C1. Bounded panel correctness — issues #53–#58 and #60

**Priority:** P1. **Effort:** medium as one shared mechanism.

**Likely files**

- `skills/multi-reviewer-loop/references/reviewer-panel.md`
- `skills/second-model-bead-audit/references/reviewer-panel.md`
- `skills/orchestrating-with-rb-lite/references/harden-until-clean.md`
- `skills/pr-with-codex-bot-review/SKILL.md`
- new required owner:
  `skills/multi-reviewer-loop/scripts/claude-reviewer-runner`
- required tests:
  `skills/multi-reviewer-loop/scripts/claude-reviewer-runner.test`

**Required owner/API**

The runner is a mandatory deliverable, not an optional refactor. It provides:

```text
claude-reviewer-runner probe --models <comma-list>
claude-reviewer-runner run --model <name> --prompt-file <path> \
  --timeout-seconds <n> --result-file <private-path> \
  --tool-policy <auditor-readonly|panel-legacy-shell|panel-no-shell>
```

`probe` prints exactly one selected model and exits 0, exits 3 when no candidate
answers, and uses a distinct non-3 failure for missing dependencies or malformed
probe output. `run` requires a non-empty model, bounds the child, writes only the
caller-provided private result path, and propagates a categorized status.
Callers retain both requested and effective panel state and use the runner for
launch, wait, and unwrap. Policies are fixed enums rather than caller-provided
tool strings:

- `auditor-readonly` preserves the bead auditor's current `Read,Glob,Grep`
  policy;
- `panel-legacy-shell` preserves the existing multi-reviewer permissions only
  until C3 migrates that caller; and
- `panel-no-shell` is C3's enforced `Read,Glob,Grep` policy with Bash denied.

The runner must not broaden a caller's policy or edit the reviewed worktree.

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

### C3. Enforced reviewer isolation — issue #59

**Priority:** P1. **Effort:** large design. **Depends on:** C1.

Use a portable no-shell reviewer boundary through the single runner from C1:

1. remove `Bash` from `--allowedTools` and include it in
   `--disallowedTools`;
2. have the orchestrator build a review bundle in a private 0700 temporary
   directory outside the worktree before launch;
3. put the tracked diff in the bundle and enumerate untracked files with
   `git ls-files --others --exclude-standard -z`;
4. copy each untracked regular file to a numbered bundle path and generate a
   tested JSON manifest containing its JSON-escaped original path, numbered copy,
   type, and content digest; use `git hash-object --no-filters` on both the
   original and copy and require equality; fail closed on a non-regular type or
   any enumerate/copy/digest/manifest error;
5. give the reviewer the diff and manifest paths and retain `Read,Glob,Grep` so
   it can inspect surrounding tracked files and every numbered untracked copy;
   the prompt must say that both sources form the reviewed change; and
6. if a supported Claude CLI cannot enforce the denied Bash tool, mark that
   reviewer unavailable/degraded—never silently regrant Bash.

This is the Linux/macOS boundary; do not add `bwrap` or `sandbox-exec`.
Prompt text while granting Bash does not satisfy this issue.

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

**Priority:** P1. **Effort:** medium. **Depends on:** D1 test harness.

Continue re-exec for piped installs and a pulled installer at the same canonical
install path. A readable installer from another checkout must continue executing
its own bytes. Check a re-exec marker exists before reading it.

### D3. YAML-equivalent companion names — issue #63

**Priority:** P2. **Effort:** small/medium.

Parse the minimal YAML scalar spellings Tau accepts: plain, single-quoted,
double-quoted, and valid trailing comments. Continue rejecting malformed
frontmatter, duplicate keys, and real mismatches without adding a heavyweight
dependency.

## Workstream E — Beads and generated workflow safety

### E1. Fail-closed JSONL path ownership — issue #44 and issue #65

**Priority:** P1. **Effort:** medium.

Sweep every executable block, prose instruction, and comment that resolves the
Beads JSONL. Require:

```bash
_bw=$(br where --json) || exit
BEADS_JSONL=$(printf '%s' "$_bw" | jq -er .jsonl_path) || exit
```

or one tested fact owner with equivalent fail-closed behavior.

Likely consumers include Drive, plan transfer, bead polish, rb-lite backlog
drain, and orchestration guidance.

### E2. Generated agent protocol conflict — issue #33

**Effort:** split into bounded children.

Create:

- **E2a, P1:** semantic review or omission of a generated `br agents` session
  protocol that contradicts branch/review gates.
- **E2b, P2:** noninteractive prompt behavior.
- **E2c, P2:** exit-143 and parallel-panel diagnostic corrections.

The skeptic-convergence observation is not a fourth E2 bead; F1 owns it together
with #47's fact-ownership policy.

### E3. Exact closure command — issue #65

**Priority:** P2. **Effort:** extra small.

Align harden-until-clean with the canonical fail-closed closure command and
explicit flush behavior.

## Workstream F — Drive/rb-lite controller and convergence

### F1. Deduplication and fact ownership — issue #47

**Priority:** P2. **Effort:** medium. Can land before F2.

Add DEDUPE/fact-owner disposition and panel self-diagnosis. Do not use
delta-only review or defer all P3 findings as the remedy for duplicated facts.

### F2. Synchronous checkpoint seam — issue #48 upstream portion

**Priority:** P1. **Effort:** large/external dependency.

**Executor:** `executor-rb-lite`.

Run this bead through a separately spawned agent whose current repository is
`/home/master/p/rb-lite`; do not hand it to the skills-repository backlog drain.
That agent must read `/home/master/p/rb-lite/AGENTS.md`, create
`feat/drive-checkpoint-hook` from current `origin/main`, and use
`orchestrating-with-rb-lite` in that checkout for the Codex-heavy implementation.
The upstream gate is:

```bash
just test && nix build && nix flake check
```

Open and land the minimal rb-lite checkpoint-hook PR through the upstream
repository's branch workflow. The child must own its lifecycle and quiescent
boundary. Do not implement #30's log-tail sidecar.

The coordinating skills agent verifies the upstream PR URL, merge SHA, and all
three gate exit codes. It then records and closes F2 only through a reviewed
skills-repository path:

- carry the evidence update, `br close <F2-bead-id>`, and the explicit
  `br sync --flush-only` into the next `executor-skills` branch after first
  confirming the JSONL is clean against `HEAD`; or
- if no next skills branch exists, create a dedicated metadata branch from
  current `master`, make only the evidence/closure JSONL change, run the skills
  gate and panel, and merge that PR.

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

### F3. Foreground Drive controller — issues #48, #30, #31, #35

**Priority:** P1. **Effort:** extra large. **Depends on:** C1 and F2r.

Implement:

- declared round limits passed to rb-lite;
- separate production and test LOC budgets;
- distinct churn and scope brake reasons;
- acceptance-criterion re-read before cutback;
- gate execution after a cutback;
- structured terminal result consumption;
- atomic BUILD-to-HARDEN continuation; and
- durable pass count and resume behavior.

Close #30, #31, and #35 only after their observed failures are deterministic
fixtures. #47 remains an independent policy deliverable even if #48 tracks the
controller umbrella.

## Workstream G — executable evidence and documentation

### G1. Read-only commit verifier — issue #32

**Priority:** P2. **Effort:** medium/large.

Create a tested `verify-commit` owner for literal expectations, occurrence
counts, absent paths, and optional exact path sets. Cover the regression cases
listed in #32, including metacharacters, leading dashes, multiple occurrences on
one line, count zero under `pipefail`, SIGPIPE, file deletion, and unexpected
paths.

This is post-commit evidence and is not B1's delegated-edit isolation mechanism.

### G2. Executable-document harness — issue #49

**Priority:** P2. **Effort:** large. **Depends on:** G1.

Extract and run executable examples in a disposable environment, and
experimentally validate the harness's own claims.

### G3. Managed-block length decision — issue #50

**Priority:** P3. **Effort:** small. **Depends on:** G1/G2.

Reassess whether the 183-word behavioral-claims rule can shrink once mechanisms
own its detail. Leaving it intact is an acceptable evidence-based disposition.

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
| B1 | P0 | #41, #43, #34, #65 | B0 | Delegated-edit isolation |
| B2a | P1 | #34 | — | Unsafe red evidence blocks completion |
| B2b | P1 | #34 | — | Preserve colocated tests during inversion |
| B2c | P2 | #34 | C1 | Tested panel shutdown/escape |
| B2d | P2 | #34 | G1 | Do not mask verification execution errors |
| B2e | P1 | #34 | — | Compare flush against saved bytes |
| C1 | P1 | #53–#58, #60 | — | Shared bounded Claude reviewer runner |
| C2 | P1 | #51 | C1 | Bound rb-lite reviewer model |
| C3 | P1 | #59 | C1 | Enforced reviewer isolation |
| D1 | P2 | #61, #38, #65 | — | Old-Bash argv and empty discovery |
| D2 | P1 | #62, #65 | D1 | Re-exec provenance and marker diagnostic |
| D3 | P2 | #63 | D1 | YAML-equivalent companion names |
| E1 | P1 | #44, #65 | — | Fail-closed JSONL path ownership |
| E2a | P1 | #33 | — | Resolve generated protocol conflict |
| E2b | P2 | #33 | E2a | Noninteractive generated behavior |
| E2c | P2 | #33 | E2a | Correct panel diagnostics |
| E3 | P2 | #65 | E1 | Exact fail-closed closure command |
| F1 | P2 | #47, #33 | — | Deduplication and fact ownership |
| F2 | P1 | #48 | — | Upstream synchronous checkpoint seam |
| F2r | P1 | #48 | F2 | Human-authorized release publication |
| F3 | P1 | #48, #30, #31, #35 | C1, F2r | Foreground Drive controller |
| G1 | P2 | #32, #34 | — | Read-only commit verifier |
| G2 | P2 | #49 | G1 | Executable-document harness |
| G3 | P3 | #50 | G1, G2 | Managed-block length decision |

Constraints:

- Only one owner edits the delegated-edit or panel-runner file set at a time.
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

## Beads graph to create

After review, transfer this plan into:

- exactly one flat execution/decision bead per row in the complete
  execution-bead table, with no tracking parent or epic;
- every dependency edge in that table;
- GitHub URLs and named gate commands in every child; and
- the exact priority and executor labels in the table.

The first scoped `br ready` result must contain A1. D1 and E1 may also be ready.
B1 begins with a design/fixture bead rather than direct prose edits. F2 must
record its upstream issue/PR URL before it can become in progress.

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
- The exact upstream rb-lite checkpoint API and release for #48.
- Whether #66 requires content digests after stable-ID reproduction.
- The human B1 decision between refusal and dirty in-scope preservation.
- Human authorization to publish the F2 upstream release.
