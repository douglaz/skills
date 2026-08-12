# Backlog execution plan

## Status

Reviewed and accepted for GRAPH transfer on 2026-08-12. The pinned Codex xhigh
review at `bceb919` reported no P0/P1 findings. This plan covers the 29 GitHub
issues that were open in `douglaz/skills` on 2026-08-11. GitHub remains the
external source of issue identity; Beads holds the executable dependency graph.

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
  ./check.sh
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
named red fixture per state class below. Review that design with pinned Codex
xhigh until it has no P0/P1. Do not edit production skill prose or implement the
helper in B1d.

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
- new exact companion owner:
  `skills/claude-reviewer-runner/SKILL.md`
- required implementation and tests:
  `skills/claude-reviewer-runner/scripts/claude-reviewer-runner`
  and
  `skills/claude-reviewer-runner/scripts/claude-reviewer-runner.test`
- `install.sh` and `install.test`

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

### C3. Enforced reviewer isolation — issue #59

**Priority:** P1. **Effort:** large design. **Depends on:** C1.

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
BEADS_JSONL=$(
  printf '%s' "$_bw" |
    jq -ers '
      if length == 1 and
         ((.[0] | type) == "object") and
         ((.[0].jsonl_path | type) == "string") and
         ((.[0].jsonl_path | length) > 0)
      then .[0].jsonl_path
      else error("expected exactly one non-empty string jsonl_path")
      end
    '
) || exit
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
rb-lite run ... --checkpoint-cmd CMD
```

- invoke `CMD` synchronously with stdin closed and no implementer/reviewer child
  alive at `post_implementer` after each successful implementer
  iteration/fingerprint and at `post_review` after every reviewer joins but
  before the panel result is acted on;
- provide `RB_LITE_CHECKPOINT`, `BASE`, `RUN_DIR`, `ROUND`, and `ITERATION`, plus
  `REVIEW_PANEL_RESULT=clean|findings|failed` at `post_review`;
- save checkpoint stdout, stderr, and status in `RUN_DIR`;
- status 0 continues, status 20 preserves the diff/artifacts and returns a
  distinct `checkpoint_stopped` terminal status, and every other nonzero returns
  `checkpoint_failed`;
- include checkpoint name, round, iteration, and hook status in the single
  terminal JSON object, with fixed distinct rb-lite process exit codes for both
  terminal statuses.

Deterministic upstream tests must cover both boundaries, the stabilizing
iteration, actual joined-panel result, 0/20/other statuses, preserved artifacts,
and TERM/INT child reaping. The hook does not parse a Drive contract, persist a
state database, poll logs, reset/cut the diff, or learn BUILD/HARDEN/LAND.

The coordinating skills agent verifies the upstream PR URL, merge SHA, and all
three gate exit codes. It then records and closes F2 only through a reviewed
skills-repository path:

- carry the evidence update, `br close <F2-bead-id>`, and the explicit
  `br sync --flush-only` into the next `executor-skills` branch after first
  confirming the JSONL is clean against `HEAD`; or
- if no next skills branch is immediately available, run the canonical metadata
  closure transaction: create `metadata/close-f2-checkpoint` from current
  `master`; make the evidence/closure JSONL change plus the `DRIVE.md`
  Done/Now/Next update; push and open a PR whose body contains
  `bead-closure: <F2-bead-id>`; once GitHub assigns `N`, amend `DRIVE.md` to
  `Pending: metadata PR douglaz/skills#N`; rerun the skills gate and panel on the
  amended tree; force-push with lease; and merge that PR. Do not record DONE
  while other scoped rows remain.

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

- resolve rb-lite candidates by capability, not path presence or version text:
  reject a PATH candidate unless `rb-lite capabilities --json` exits 0 and
  reports `"synchronous_checkpoint":1`; otherwise fall back to
  `nix run github:douglaz/rb-lite/<F2r-immutable-commit> --`, probe that exact
  command too, and fail preflight if neither qualifies;
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

Close #30, #31, and #35 only after their observed failures are deterministic
fixtures. #47 remains an independent policy deliverable even if #48 tracks the
controller umbrella.

F3 fixtures must put a stale pre-checkpoint `rb-lite` first on PATH and prove
the resolver selects the immutable F2r fallback; a missing or malformed
capability response must fail closed rather than run the stale binary. Separate
fixtures must cover an outside-lock path, an allowed-but-unclassified path,
overlapping classes, an explicit unbudgeted exemption, and independent
production/test budget breaches.

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
| B1d | P0 | #41, #43, #34, #65 | B0 | Delegated-edit design and fixture contract |
| B1 | P0 | #41, #43, #34, #65 | B1d | Delegated-edit isolation implementation |
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
| F2 | P1 | #48 | C2 | Upstream synchronous checkpoint seam |
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
