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
- Beads is not initialized: there is no `.beads` directory, database, or JSONL;
  both `br where` and `bd where` fail with not-initialized errors.
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

  A bead may add a narrower red/green command, but the aggregate gate still runs
  before clearance and landing.

## Tracker contract

GitHub owns external issue identity, discussion, and closure. Beads owns local
execution state and dependencies.

- Initialize Beads only after this plan passes its SHAPE review.
- Create one plan epic and bounded child beads, not one bead per checkbox in an
  issue when several checkboxes enforce the same invariant.
- Put `GitHub: https://github.com/douglaz/skills/issues/N` in every bead.
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

**Priority:** P1. **Effort:** small beads, not one PR. **Depends on:** A1.

Separate beads must:

- preserve the first degraded exit-4 response across re-entry;
- create post-merge evidence through a unique private file with checked writes;
  and
- exclude closure PRs from the work-PR resume query.

### A4. Bounded plan-format follow-ups — issue #65

**Priority:** P3. **Effort:** extra small, separate from admission logic.

- Clarify Drive's project-status/resume routing exception without changing its
  trigger-evaluation outcomes.
- Convert the moved backlog examples to fenced Markdown.

## Workstream B — delegated-edit state integrity

### B1. Delegated-edit isolation mechanism — issues #41, #43, #34, #65

**Priority:** P0. **Effort:** large design/build.

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

Split from B1:

- unsafe red evidence must report INCOMPLETE/BLOCKED rather than land;
- file-level inversion must not destroy colocated tests;
- panel shutdown/escape behavior needs a tested owner;
- `grep ... || true` must not convert execution errors to success; and
- post-flush comparison must use saved pre-flush bytes, not `HEAD`.

## Workstream C — reviewer runner reliability and isolation

### C1. Bounded panel correctness — issues #53–#58 and #60

**Priority:** P1/P2. **Effort:** medium as one shared mechanism.

**Likely files**

- `skills/multi-reviewer-loop/references/reviewer-panel.md`
- `skills/second-model-bead-audit/references/reviewer-panel.md`
- `skills/orchestrating-with-rb-lite/references/harden-until-clean.md`
- `skills/pr-with-codex-bot-review/SKILL.md`
- a tested shared runner/helper if review identifies a stable owner

**Order**

1. #55: distinguish missing `jq` from an exhausted model ladder.
2. #57: require `.is_error == false` and a non-empty string result.
3. #58: guard launch, wait, and unwrap as one region when no model resolves.
4. #54: preserve requested versus effective panel state.
5. #53: declare/check the host GNU `timeout` requirement.
6. #60: create probe helpers only inside a private temporary directory.
7. #56: re-record the `if` transcript or narrow the claim to the command run.

### C2. rb-lite reviewer model bounding — issue #51

**Priority:** P1. **Effort:** small/medium plus possible upstream change.

Generate a reviewer file using the resolved model or add upstream reviewer
bounding. Remove stale local guidance without waiting for the larger controller.

### C3. Enforced reviewer isolation — issue #59

**Priority:** P1. **Effort:** large design. **Depends on:** C1.

Choose an enforced boundary—OS sandbox or disposable review copy/worktree—and
implement it through the single runner from C1. Prompt text and
`--disallowedTools` while granting Bash do not satisfy this issue.

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

**Priority:** P1/P2. **Effort:** medium. **Depends on:** D1 test harness.

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

**Priority:** P1/P2. **Effort:** medium after split.

Separate:

- semantic review or omission of a generated `br agents` session protocol that
  contradicts branch/review gates;
- noninteractive prompt behavior;
- exit-143 and parallel-panel diagnostic corrections; and
- the skeptic-convergence observation, which belongs with F1 fact ownership.

### E3. Exact closure command — issue #65

Align harden-until-clean with the canonical fail-closed closure command and
explicit flush behavior.

## Workstream F — Drive/rb-lite controller and convergence

### F1. Deduplication and fact ownership — issue #47

**Priority:** P2. **Effort:** medium. Can land before F2.

Add DEDUPE/fact-owner disposition and panel self-diagnosis. Do not use
delta-only review or defer all P3 findings as the remedy for duplicated facts.

### F2. Synchronous checkpoint seam — issue #48 upstream portion

**Priority:** P1. **Effort:** large/external dependency.

Open and land the minimal rb-lite checkpoint hook and release it. The child must
own its lifecycle and quiescent boundary. Do not implement #30's log-tail
sidecar.

### F3. Foreground Drive controller — issues #48, #30, #31, #35

**Priority:** P1. **Effort:** extra large. **Depends on:** C1 and F2.

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

**Priority:** P2. **Effort:** large. **Depends on:** G1 where reusable.

Extract and run executable examples in a disposable environment, and
experimentally validate the harness's own claims.

### G3. Managed-block length decision — issue #50

**Priority:** P3. **Effort:** small. **Depends on:** G1/G2.

Reassess whether the 183-word behavioral-claims rule can shrink once mechanisms
own its detail. Leaving it intact is an acceptable evidence-based disposition.

## Dependency and parallelism summary

First ready lanes after graph approval:

1. A1 (#42 bot-gate tip scope).
2. D1 (#61/#38 installer compatibility).
3. E1 (#44/#65 JSONL path ownership).
4. B1 design and fixture specification, without parallel edits to its files.
5. F2 upstream checkpoint design may proceed while local lanes build.

Constraints:

- A2 follows A1.
- C3 follows C1.
- F3 follows C1 and F2.
- D2 follows D1's compatibility harness.
- G2 follows G1 when it reuses verification primitives.
- Only one owner edits the delegated-edit or panel-runner file set at a time.

## Beads graph to create

After review, transfer this plan into:

- one epic covering the exact 29-issue scope;
- seven workstream parent beads A–G;
- one child bead per numbered deliverable above;
- explicit dependency edges from the summary;
- GitHub URLs and named gate commands in every child; and
- P0/P1 priorities before P2/P3 maintenance.

The first scoped `br ready` result must contain A1. D1 and E1 may also be ready.
B1 begins with a design/fixture bead rather than direct prose edits. F2 must
record its upstream issue/PR URL before it can become in progress.

## Completion

The drive is complete only when:

1. every accepted child is merged through its own reviewed branch;
2. each aggregate issue (#34, #48, #65) has every child merged or rejected with
   evidence;
3. the scoped Beads graph has no open item;
4. the aggregate repository gate exits 0 on final `master`; and
5. GitHub issue closure and Beads closure records agree.

## Known unknowns

- Bash 4.0–4.3 availability for #61's live compatibility gate.
- The portable isolation boundary for #59.
- The exact upstream rb-lite checkpoint API and release for #48.
- Whether #66 requires content digests after stable-ID reproduction.
- Whether B1 can safely support dirty in-scope delegation; refusal is preferred
  until fixtures prove preservation.
