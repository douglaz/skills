# Backlog execution plan

## Status

SHAPE cleared again on 2026-08-12 after the first post-amendment GRAPH polish.
The first pinned Codex xhigh
review at `bceb919` reported no P0/P1 findings, but translation exposed missing
API, failure, recovery, and fixture detail in later rows. After those amendments,
a fresh pinned Codex review found two inherited-signal defects in the canonical
gate wrapper; both are fixed and covered at `16e1775`. A user-requested Fable
review then read the complete specification inventory and reported two plan P1s:
the missing B2d→B2c edge and an unattested E3 `sync --status --json` schema. Both
corrections are incorporated and the status schema is measured; the only unreviewed
material is the KISS close–flush–prove amendment below. On the final reviewed tree
at `9965c24`, pinned `gpt-5.6-sol`/xhigh Codex reported no P0/P1 and Fable/high
reported `NO BLOCKING FINDINGS`; `./check.sh` exited 0 with 26 installer, 124
bot-gate, and 70 drive-status fixtures under GNU Bash 5.3.3, non-POSIX mode.
GRAPH then updated the 33 rows and 24
edges exactly, but five fresh polish passes found that the P0 E1→E3 bootstrap was
only prose, E1/E3 closure metadata was not fully landed between stages, and a few
shared owners/acceptance commands remained implicit. The plan now encodes the
bootstrap barrier as edges, serializes skills/metadata lanes, and incorporates
the accepted sizing, ownership, and command findings. On `ec076e9`, Fable/high
reported `NO BLOCKING FINDINGS`, pinned `gpt-5.6-sol`/xhigh Codex reported no
P0/P1 (one non-blocking P2 about orphan cleanup in a startup-timeout test path),
and `./check.sh` exited 0 with 26 installer, 124 bot-gate, and 70 drive-status
fixtures under GNU Bash 5.3.3, non-POSIX mode. GRAPH updated the existing store
to the 37-edge target at `7d88c46`; exact field/body, lint, cycle, sync-health,
and frontier audits passed. After that prior clean review evidence, the failed E3
implementation and reviews led the user to choose the KISS close–flush–prove
amendment below; those prior clean reviews did not cover this amendment. This plan covers the 29 GitHub
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
  SHAPE. The later updates modified that existing graph in place with `br`; they
  did not rerun `br init`, delete the database, recreate IDs, or hand-edit the
  JSONL. The first amendment added F2→E3 and B2d→B2c, reaching 24
  edges at `c921749`. The final polish amendment added the executable E1→E3 bootstrap
  barrier and A3a→A3b content ordering, removed the unsupported E2c→E2a and
  G2→G1 constraints, and the 37-edge graph was applied at `7d88c46`.
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

This 2026-08-12 transcript records current evidence from installed `br 0.2.19`
against the initialized, clean skills graph before the two amended edges were
applied:

```text
$ br --no-auto-flush --no-auto-import sync --status --json \
    >/tmp/br-sync-status.json 2>/tmp/br-sync-status.err
$ br_sync_status_rc=$?
$ jq -c '{dirty_count,jsonl_newer,db_newer,workspace_health,
          reliability_health:.reliability_audit.health,
          anomaly_count:.reliability_audit.anomaly_count,
          jsonl_content_hash,
          git_available:.git_export.available,
          git_tracked:.git_export.tracked,
          worktree_clean:.git_export.worktree_clean,
          index_clean:.git_export.index_clean}' /tmp/br-sync-status.json
{"dirty_count":0,"jsonl_newer":false,"db_newer":false,"workspace_health":"healthy","reliability_health":"healthy","anomaly_count":0,"jsonl_content_hash":"3e0b401a0a7093b57d41a5f86ec9200cd1f721cc9a2caa06291edcda435fe4ad","git_available":true,"git_tracked":true,"worktree_clean":true,"index_clean":true}
$ br --no-auto-flush --no-auto-import where --json \
    >/tmp/br-where.json 2>/tmp/br-where.err
$ br_where_rc=$?
$ BEADS_JSONL=$(jq -er .jsonl_path </tmp/br-where.json)
$ br_where_jq_rc=$?
$ printf 'WHERE_EXIT=%s JQ_EXIT=%s\n' "$br_where_rc" "$br_where_jq_rc"
WHERE_EXIT=0 JQ_EXIT=0
$ sha256sum "$BEADS_JSONL"
3e0b401a0a7093b57d41a5f86ec9200cd1f721cc9a2caa06291edcda435fe4ad  /home/master/p/skills/.beads/issues.jsonl
$ wc -c /tmp/br-sync-status.err /tmp/br-where.err
0 /tmp/br-sync-status.err
0 /tmp/br-where.err
0 total
$ printf 'EXIT=%s\n' "$br_sync_status_rc"
EXIT=0
```

E1 owns the locator and clean-tracked-JSONL proof. The fixture-owned coordinator
procedure and E3's private preflight reuse that installed-companion provenance
and this measured `0.2.19` status schema; neither exposes it as an E3 API.

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
7. Run at most one `executor-skills` bead at a time, regardless of how many the
   ready query returns. Before selecting it, atomically create a lane reservation
   directory under the Git common directory containing the exact bead ID, branch,
   coordinator identity, and start time; an existing live or unknown reservation
   blocks dispatch, and stale recovery requires explicit evidence rather than PID
   age. Hold that reservation through work-PR merge or explicit abandonment and
   verified cleanup, including the corresponding closure metadata PR merge. The
   external `executor-rb-lite` lane may run concurrently
   once ready because it owns another repository; authority beads are reported,
   never implemented speculatively. This serialization is intentional: current
   ready rows share installer, reviewer-panel, and skill files in ways that are not
   faithfully representable as semantic dependency edges.
8. Bootstrap the P0 Beads safety owners before normal scheduling. GRAPH may perform
   its reviewed in-place update as one coordinator-owned, serialized transaction:
   save the exact clean JSONL, use only
   `"$BEADS_JSONL_RESOLVER" --run-br --no-auto-flush --no-auto-import` mutations,
   explicitly flush once, and field-diff every ID against the saved bytes allowing
   only the reviewed graph changes. GRAPH remains on its existing `br >=0.1.45`
   contract; it does not consume E3's measured status schema. The graph encodes this
   barrier: E1 is the sole initial root, E3 depends on E1, and every otherwise
   dependency-free row depends on E3. After that update, dispatch E1 first. E1's
   already-completed dedicated metadata closure used the pre-E3
   saved-bytes/explicit-flush/diff manual path and required neither E3 nor an E3
   preflight. Merge that metadata PR, refresh clean `master`, and dispatch E3; do
   not require E3's private predicate before that dispatch. Only E3's own and later
   closures use the E3 helper. After E3's work PR merges, each of those closures
   follows the caller-owned status-equality procedure below, invokes the helper,
   and merges before the next clean-`master` refresh. That procedure repeats E1's
   clean-tracked-JSONL proof immediately after its caller-owned import and before
   status or lane reads. It does not make lane reads an E3 API or add an E3 lock,
   probe, or automatic recovery.
9. Permit at most one outstanding tracked-Beads-JSONL-changing branch/PR
   (closure, graph, or bootstrap). It starts from latest clean `master`, owns the
   matching evidence/status and `DRIVE.md` transition, and remains exclusive through
   merge, abandonment, or explicit human-reviewed repair. This serializes the
   current body amendment as well as later metadata work; it is the only
   cross-command serialization for the tracked JSONL. During a closure, that
   coordinator ownership also prohibits every external/caller skills-store
   `ready`, `list`, `show`, and lane read from immediately before helper invocation
   until the helper returns and the closure metadata state is settled. The helper's
   own named status/show/flush proof remains permitted; this is caller discipline,
   not a helper lock or API.

**Caller-owned coordinator status equality (fixture-owned; not an E3 API).**
After each clean-`master` refresh, before any lane read and before the F2 or F2r
closure path, the coordinator runs E1's canonical locator only through its
`BEADS_GIT_RUNNER=` assignment and stops before the final clean-mode
`BEADS_JSONL=$("$BEADS_JSONL_RESOLVER")` call, exactly as E1's existing write
guidance already permits. With that validated locate-only resolver it: (1)
before any store-touching normal resolver/status/import operation, captures
`"$BEADS_JSONL_RESOLVER" --run-br --no-auto-flush --no-auto-import --version`
in a selector-clean environment
with separated streams and requires exact stdout bytes `br 0.2.19\n`, empty
stderr, and status 0; a mismatch launches no normal E1 proof, `where`, status, or
import; (2) captures exactly one `br where --json` object in the caller's
supported original location context and requires each of `.path`,
`.database_path`, and `.jsonl_path` to be a nonempty absolute string without
CR/LF, retaining `.path` as `BEADS_STORE_DIR`; (3) requires
`.database_path == "$BEADS_STORE_DIR/beads.db"`; (4) runs E1's normal resolver
in that same original context to prove the clean tracked JSONL and requires its
returned path to equal the captured `.jsonl_path` byte-for-byte; (5) establishes
one selector-clean context containing only `BEADS_DIR="$BEADS_STORE_DIR"` and
`BEADS_JSONL="$BEADS_JSONL"` for every remaining caller Beads operation; (6)
recaptures one `br where --json` object in that context and requires the entire
`.path`/`.database_path`/`.jsonl_path` triple to equal the retained triple
byte-for-byte; (7) captures the output of
`"$BEADS_JSONL_RESOLVER" --run-br --no-auto-flush --no-auto-import sync --status --json`,
calculates that JSONL's plain SHA-256 as below, and runs the exact predicate below
with `--argjson require_synced false`; (8) only after that predicate has refused
dirty or DB-newer state, immediately runs
`"$BEADS_JSONL_RESOLVER" --run-br --no-auto-flush --no-auto-import sync --import-only`;
(9) immediately repeats E1's normal clean-tracked-JSONL proof in the same
selector-clean context and requires the same retained path before any status or
lane read; (10) captures the output of
`"$BEADS_JSONL_RESOLVER" --run-br --no-auto-flush --no-auto-import sync --status --json`;
(11) uses the already validated existing
`"$BEADS_GIT_RUNNER" run-audit-tool python3 -I` and only stdlib
`hashlib` to calculate the plain SHA-256 of that exact JSONL; and (12) passes the
captured status transcript and hash to E1's
`"$BEADS_JSONL_RESOLVER" --run-jq -se --arg hash "$hash" --argjson require_synced true`
predicate. Both jq calls use `-s` to slurp the transcript, require exactly one
JSON document, and apply the predicate to `.[0]`:

```jq
def clean_git:
  (.git_export | type == "object" and
    (.available | type == "boolean" and . == true) and
    (.tracked | type == "boolean" and . == true) and
    (.worktree_clean | type == "boolean" and . == true) and
    (.index_clean | type == "boolean" and . == true));
def synced:
  (.jsonl_newer == false) and
  (.workspace_health | type == "string" and . == "healthy") and
  (.reliability_audit | type == "object" and
    (.health | type == "string" and . == "healthy") and
    (.anomaly_count | type == "number" and . == 0)) and
  (.jsonl_content_hash | type == "string" and . == $hash);
def importable_jsonl_newer:
  (.jsonl_newer == true) and
  (.workspace_health | type == "string" and . == "degraded") and
  (.reliability_audit | type == "object" and
    (.health | type == "string" and . == "degraded") and
    (.anomaly_count | type == "number" and . == 1) and
    (.anomalies | type == "array" and length == 1 and
      .[0].code == "jsonl_newer" and
      .[0].severity == "degraded" and
      (.[0].message | type == "string"))) and
  (.jsonl_content_hash | type == "string");
length == 1 and
(.[0] |
  type == "object" and
  (.dirty_count | type == "number" and . == 0) and
  (.jsonl_newer | type == "boolean") and
  (.db_newer | type == "boolean" and . == false) and
  clean_git and
  (if $require_synced then synced else (synced or importable_jsonl_newer) end))
```

Missing, additional/ambiguous JSON values, or a type/value mismatch refuses the
path. Python 3 is required. The fixture owns this procedure and its strict
predicate, including the measured `git_export` cleanliness fields. Thus the
pre-import status either already satisfies the strict synced state or reports
exactly the one measured `jsonl_newer` degraded anomaly; it can never authorize
import over dirty or DB-newer state or another anomaly. Post-import status must
satisfy the strict synced state, including current JSONL hash equality. The
helper performs the same slurped predicate privately with
`require_synced == true` before its mutation; this
coordinator procedure is neither a public E3 check nor a public
status/fingerprint interface.

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
**Depends on:** A1 and A3a; A3a creates the shared fixture this child extends,
so these two rows must not be dispatched together.

**A3c, P1 — exclude closure PRs from work-PR resume.** Own the duplicated matching
query consumers in `skills/rb-lite-backlog-drain/SKILL.md` and
`skills/drive/references/phases.md` § LAND, or extract one tested fact owner both
reference. Add executable
`skills/rb-lite-backlog-drain/scripts/resume-query.test`. Before applying
OPEN/MERGED work-PR state rules, reject a body carrying the exact
`bead-closure: <id>` marker; retain the boundary-safe ordinary bead-ID match and
fork/parent URL identity. The fixture extracts and exercises the query from each
consumer (or the one shared owner) with one work PR and one closure PR carrying
the same ID in OPEN and MERGED permutations, and proves only work PRs reach the
resume state. Run it and `./check.sh`. Do not absorb A3a or A3b.

### A4. Bounded plan-format follow-ups — issue #65

**Effort:** two extra-small beads, separate from admission logic.

**A4a, P3 — routing wording.** Own only the folded description in
`skills/drive/SKILL.md` and the existing
`skills/drive/evals/trigger-evals.json`. Replace the broad question exclusion
with `general informational question`, explicitly retaining project-status and
resume as Drive triggers. Run the documented manual live-model measurement three
times each for the affected project-status/resume positives and the informational
negative, and record the before/after routing rates plus raw stream artifacts.
Because the skill's invocation contract explicitly treats auto-triggering as
stochastic bonus behavior, do not require byte-identical runs or turn a single
miss into a red gate; the deterministic acceptance check is the exact folded
description and unchanged `should_trigger` routing assertions in the eval file.
This is not a red/green production behavior change. Then run `./check.sh`.

**A4b, P3 — adjudicate moved examples.** Re-open the linked #65 review thread and
inspect every merge/reset example in `skills/rb-lite-backlog-drain/SKILL.md`.
The current file already places its shell examples in fenced blocks, so do not
churn those blocks merely to satisfy stale wording. If the linked finding
identifies a remaining indented example, own only that block plus its exact
new extraction check added to `install.test`; convert only block style and require
byte-identical command text before/after. Otherwise close this bead with the
thread URL, inspected ranges, and no-change evidence. Do not execute the examples
or add the G2 harness here. If any file changes, run `./install.test` and
`./check.sh`.

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
- exact helper `skills/multi-reviewer-loop/scripts/delegated-edit-isolation`
- exact direct test
  `skills/multi-reviewer-loop/scripts/delegated-edit-isolation.test`

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

Run `skills/multi-reviewer-loop/scripts/delegated-edit-isolation.test` and then
`./check.sh`, recording both real statuses and requiring zero; wire the direct
test into the aggregate gate.

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

**B2d, P2 — preserve verification execution errors.** After G1 and B2c land,
replace the occurrence-count `grep ... || true` consumer in
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
claude-reviewer-runner command-no-output --timeout-seconds <n> -- \
  <executable> [arg...]
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
publish without replacement by hard-linking that same-directory temporary file
to `--result-file` and then unlinking the temporary name; if the destination
appears after the initial check, the exclusive link must fail rather than
replace it. Never modify the final path after returning; no failure may leave a
valid-looking final result. Timeout/signal handling performs bounded
TERM/CONT/KILL and does not return until descendants are reaped.

`probe` writes the selected model plus one trailing newline to stdout and no
stdout on failure; invocation, dependency, or malformed-output failures use
status 2, while exhausted supported candidates remain status 3. `run` writes no
stdout. Its final file is exactly one compact
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
A pre-existing `--result-file` is an invocation refusal with status 2.

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

`command-no-output` is the non-reviewer reuse of that lifecycle boundary. It
executes the fixed argv directly—never through a shell—with stdin closed; rejects
an empty command or nonpositive deadline as status 2; requires both stdout and
stderr to be empty; and otherwise returns the child's exit status subject to the
same latched 124 timeout, 128+signal caller cancellation, and 125 reaping-failure
rules. It accepts no model, prompt, result-file, policy, working-directory, or
add-dir options. Direct fixtures cover argv metacharacters remaining literal,
nonempty-stream refusal, timeout with a stopped/resistant descendant, caller
signals, and complete reaping. F2r is its first non-reviewer consumer.

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

Ownership is `skills/orchestrating-with-rb-lite/SKILL.md`, specifically its
inline reviewers-file configuration section, and new executable fixture
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

Create exact companion owner:

- `skills/reviewer-isolation/SKILL.md`;
- `skills/reviewer-isolation/scripts/build-review-bundle`; and
- `skills/reviewer-isolation/scripts/reviewer-isolation.test`.

The builder's fixed API is:

```text
build-review-bundle --base REV --bundle-dir PATH --result-file PATH \
  [--untracked-allowlist0 PATH]
```

`--bundle-dir` and `--result-file` must not exist; their parents must be
caller-owned mode-0700 directories. The helper creates the bundle directory at
0700, accepts the optional allowlist as raw NUL-delimited paths (absence is valid
only when the repository has no untracked paths), and writes no stdout. It first
writes and validates exactly one compact UTF-8 JSON object plus newline in a
mode-0600 same-directory temporary, then publishes without replacement by
hard-linking it to `--result-file` and unlinking the temporary name. If the
destination appears after the initial check, the exclusive link fails rather
than replacing caller-owned evidence. The result schema is:

```json
{"bundle_root":"<absolute>","working_directory":"<absolute snapshot>","diff":"<absolute native diff>","manifest":"<absolute untracked manifest>"}
```

Every returned path is canonical, below `bundle_root`, and names a regular file
or directory the helper created without symlink traversal. Status 0 means the
entire bundle and result validated; 2 is invalid invocation/dependency/repository
input; 1 is a checked repository-state refusal or create/read/copy/digest/write/
finalize/cleanup failure. No failure leaves a valid-looking result, prints
reviewed content, or launches a reviewer.

Migrate the bundle/isolation call sites in
`skills/multi-reviewer-loop/references/reviewer-panel.md`,
`skills/second-model-bead-audit/references/reviewer-panel.md`,
`skills/orchestrating-with-rb-lite/references/harden-until-clean.md`, and
`skills/pr-with-codex-bot-review/SKILL.md`; callers resolve the exact installed
companion and do not duplicate bundle construction.
Wire `reviewer-isolation` as an exact selective-install companion of all four
callers in `companion_dependencies()`. `install.test` covers each direct caller
install and upgrade repair on Claude and Codex targets, legacy-only Agents
installation, missing companion, and wrong declared companion name.

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
4. capture a source token containing `HEAD`, the raw index entries/tree,
   tracked/untracked/deleted path sets, Git-relevant modes, and content digests;
   then materialize a sanitized snapshot under that directory from the NUL-safe
   raw index path/mode set (`git ls-files --stage -z`) plus the current worktree
   bytes. Open the worktree root and descend each path descriptor-relatively;
   open every copied tracked and untracked source with `O_NOFOLLOW`, require the
   `fstat` result to be a regular file owned by the effective UID, and stream
   copy/hash from that same descriptor. Never copy or hash by reopening the
   pathname: `git hash-object` on a path follows symlinks. First inspect
   `git ls-files -v -z` and refuse every
   assume-unchanged or skip-worktree entry; copy regular files byte-for-byte,
   preserve Git-relevant executable mode, and omit only paths proven to be
   tracked deletions; refuse all tracked symlinks and gitlinks rather than risk a
   target escaping the snapshot; also fail closed on sparse/missing paths that
   are not deletions, unmerged index stages, or any path/mode/digest mismatch;
   do not use `git archive` or a checkout operation that honors `export-ignore`,
   `export-subst`, or smudge filters;
5. copy only the allowlisted untracked regular-file descriptors into both their
   snapshot paths and numbered bundle paths; after every copy, recapture the
   complete source token and require byte-for-byte equality before publishing
   the result. Drift removes the incomplete bundle/result and refuses before any
   reviewer launch. Do not copy `.git`, ignored files, or any unrelated untracked
   path;
6. generate a
   tested JSON manifest containing its JSON-escaped original path, numbered copy,
   type, Git-relevant mode (`100755` when executable, otherwise `100644`), and
   content digest; feed the already-open source descriptor bytes and copied file
   bytes to `git hash-object --stdin --no-filters` and require equality; fail
   closed on a non-regular type or any
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
reviewer. Concurrent-swap fixtures replace a tracked path and an allowlisted
untracked path—with both regular-file and symlink variants—between enumeration,
open, copy, and final token validation; every variant must refuse without
bundling replacement/target bytes or publishing a result. A separate finalization
race creates `--result-file` after the initial nonexistence check and proves the
helper returns status 1 without replacing or modifying that path.

Wire `skills/reviewer-isolation/scripts/reviewer-isolation.test` into
`check.sh`; acceptance runs that test directly, `./install.test`, and
`./check.sh`, recording every real status and requiring all three to be zero.

## Workstream D — installer and upgrade correctness

### D1. Old-Bash and empty discovery — issues #61, #38, and #65

**Priority:** P2. **Effort:** medium.

**Files**

- `install.sh`
- `install.test`

Establish a Bash 4.0–4.3 execution strategy, guard empty argv, and make empty
skill discovery emit no phantom skill. The matching #65 empty-array checkbox is
the same implementation, not a second patch.
Run the focused old-Bash argv and empty-discovery cases in `./install.test`, then
run `./check.sh`; record both real statuses and require zero.

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
**Depends on:** D1 installer test harness.

Parse the minimal YAML scalar spellings Tau accepts: plain, single-quoted,
double-quoted, and valid trailing comments. Continue rejecting malformed
frontmatter, duplicate keys, and real mismatches without adding a heavyweight
dependency.
Run the plain/single-quoted/double-quoted/trailing-comment and
malformed/duplicate/mismatch cases in `./install.test`, then run `./check.sh`;
record both real statuses and require zero.

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
resolves the Beads JSONL to use the exact installed companion path. When no
installed target resolves, the operator may explicitly invoke the checkout owner's
resolver by its trusted absolute path; do not auto-execute a repository-relative
fallback. Installed resolver candidates and the fully canonical targets of
PATH-selected `br`/`jq` must be single-link regular files outside the driven
worktree so an external pathname cannot alias worktree-controlled proof code.
Installed candidates retain the canonical `#!/bin/sh` entry point, while
`br`/`jq` run with the implementation's POSIX utility path so a script cannot
resolve its interpreter or child utilities from the driven worktree.
Every later Beads command runs as
`"$BEADS_JSONL_RESOLVER" --run-br <args...>`; `--run-br` forwards those arguments
unchanged and injects no flags, while revalidating and launching the same `br`
through that clean environment rather than returning to a caller-shell function
or PATH lookup.
The companion's jq runner is likewise
`"$BEADS_JSONL_RESOLVER" --run-jq <args...>` and reuses the same validated
executable, provenance, and cross-root checks.
The installed companion also owns a validated `git-clean` sibling: caller-side
diff/add commands run through it so inherited `GIT*` selectors cannot
reappear after the resolver child exits; the runner pins trusted Git, disables
replacement objects and fsmonitor, and uses the POSIX utility path. Diff
consumers additionally disable external diff drivers and textconv filters, and
add consumers hash/stage the exact file bytes without repository clean filters.
When the documented transaction immediately commits and pushes that staged
JSONL, it stays inside the runner, with inherited transport selectors,
repository hooks, and signing disabled. Push additionally disables credential
helpers, askpass, SSH config commands, and interactive prompts while retaining
the caller's SSH agent. HTTPS re-enables only system/global credential helpers
after refusing a `HOME` or `XDG_CONFIG_HOME` inside the driven worktree.
Require:

```bash
_bw_file=$(mktemp) ||
  { echo "cannot create beads resolver input" >&2; exit 1; }
_bw_hex=$(mktemp) ||
  {
    command unlink "$_bw_file" 2>/dev/null || :
    echo "cannot create beads resolver scan" >&2
    exit 1
  }
_bw_cleanup() {
  for _bw_path in "$_bw_file" "$_bw_hex"; do
    command unlink "$_bw_path" 2>/dev/null || :
  done
}
trap _bw_cleanup EXIT
if ! br --no-auto-flush --no-auto-import where --json >"$_bw_file"; then
  echo "cannot resolve the beads workspace" >&2
  exit 1
fi
if ! LC_ALL=C command od -An -v -t x1 "$_bw_file" >"$_bw_hex"; then
  echo "cannot scan beads workspace JSON" >&2
  exit 1
fi
if command grep -Eq '(^|[[:space:]])00([[:space:]]|$)' "$_bw_hex"; then
  echo "beads workspace JSON contains a raw NUL byte" >&2
  exit 1
else
  _bw_grep_rc=$?
  if [ "$_bw_grep_rc" -ne 1 ]; then
    echo "cannot inspect beads workspace JSON" >&2
    exit 1
  fi
fi
BEADS_JSONL=$(
  jq -ers '
       if length == 1 and
         ((.[0] | type) == "object") and
         ((.[0].jsonl_path | type) == "string") and
         ((.[0].jsonl_path | length) > 0) and
         (.[0].jsonl_path | startswith("/")) and
         ((.[0].jsonl_path | contains("\u0000")) | not) and
         ((.[0].jsonl_path | test("[\r\n]")) | not)
       then .[0].jsonl_path
       else error("expected exactly one non-empty string jsonl_path")
       end
     ' <"$_bw_file"
) || { echo "cannot resolve exactly one beads JSONL" >&2; exit 1; }
command unlink "$_bw_file" &&
  command unlink "$_bw_hex" ||
  { echo "cannot remove beads resolver input" >&2; exit 1; }
trap - EXIT
```

or one tested fact owner with equivalent fail-closed behavior.

The displayed shell captures raw stdout to a private file and rejects a NUL at
the byte level before JSON parsing or command substitution; only validated jq
output enters a shell variable. It also pins JSON cardinality and rejects
relative or NUL/CR/LF-bearing decoded paths before jq emits one. The companion owns
the remaining byte-safe inspection. It canonicalizes the current worktree root
and resolved parent without following the final path, requires the path to be
inside that root, and reads raw NUL-delimited `git ls-files --stage -z`,
`git ls-files -v -z`, and
`git ls-tree -z HEAD -- "$BEADS_JSONL_REL"` records, where
`BEADS_JSONL_REL` is the validated worktree-relative path. Every Git inspection
uses that literal path with replacement objects and `core.fsmonitor` disabled;
disabling the monitor prevents a repository-configured executable hook from
running during this read-only proof. Success requires exactly one stage-0
tracked regular-file entry, mode `100644`, tag `H` (not lowercase
assume-unchanged or `S` skip-worktree), the same regular mode in HEAD, and a
non-symlink, single-link regular worktree file. It reads the HEAD blob, index blob, and
worktree bytes without filters and requires all three byte strings to be
identical before printing the path. It therefore refuses staged, unstaged,
mode-only, hidden-index-flag, unmerged, missing, ignored/untracked, symlink,
gitlink, and wrong-worktree states rather than trusting porcelain visibility.

The companion also exposes two explicit read-only modes required by existing
handoffs. `--allow-dirty` relaxes only the three-way byte-identity requirement;
it retains containment, one normally flagged tracked stage-0 `100644` index
entry that is not intent-to-add, a matching regular HEAD entry, and a
non-symlink regular `100644` worktree file before returning a path. Because
the resolver and every documented consumer force `core.fsmonitor=false`, a
stale monitor answer cannot hide the content difference this mode intentionally
permits from the consumer's own `git status` or `git diff HEAD`. `--recovery`
may name an absent or untracked path after byte-safe resolution and containment, but it still refuses
symlink, multiply linked, and nonregular occupants and every path equal to or below `$GIT_DIR`,
`--git-common-dir`, or `<worktree>/.git`. Recovery mode names an artifact for
restoration only and never authorizes a subsequent Beads query, mutation, or
flush.

Likely consumers include Drive, plan transfer, bead polish, rb-lite backlog
drain, and orchestration guidance. Add this companion to their selective-install
dependencies and wire its direct test into `check.sh`.

The owner must print a useful stderr diagnostic and exit nonzero for: `br where`
returning nonzero after emitting valid JSON; missing, null, empty, or non-string
`jsonl_path`; zero or multiple JSON documents; malformed JSON; missing/failing
`jq`; NUL/CR/LF path values; and a resolved path outside the current worktree.
Focused fixtures prove that each failure performs no Beads mutation or flush.
Further fixtures cover staged-only, unstaged-only, staged-plus-unstaged,
mode-only, intent-to-add, assume-unchanged, skip-worktree, unmerged, symlink,
hard-link, gitlink,
ignored/untracked, missing, and nonregular JSONL state, plus a path inside a
different worktree and a Git administrative path; each is refused before any mutation or flush. This is P0
because the
first `br` write after an ambiguous resolution can export a stale cache over the
tracked JSONL and silently destroy unstaged bead bodies.

E1 owns resolution and clean-worktree inspection only. It updates every
consumer, including harden-until-clean, to use that fact owner; E3 separately
owns the exact close-plus-flush transaction after resolution succeeds.

### E2. Generated agent protocol conflict — issue #33

**Effort:** split into bounded children.

Create:

- **E2a, P0:** own `skills/agents-md/SKILL.md` § br-agent-instructions guidance
  plus its managed-block assertions in `install.test`; the guidance and test,
  not `install.sh`, host this decision mechanism. Replace unconditional
  delegation with a fail-closed semantic preview. Force plain non-TTY output with
  `NO_COLOR=1`, capture the complete
  `br agents --add --force --dry-run` output against the existing AGENTS branch,
  and fail unless it contains exactly one complete delimited generated block
  rather than only a rich summary. Review that full block against the branch,
  review, gate, and closure contract. If its session
  commit/push protocol conflicts, omit the entire generated Beads block and
  report the exact conflicting clauses; do not reconcile, partially copy, or
  claim that separate markers imply semantic compatibility. Install the block
  only when the preview is semantically compatible. An `install.test` fixture
  covers a branch-and-PR agreement and proves no generic session block is
  installed or human-owned Beads text changed; a compatible minimal repository
  fixture proves the full generated block may be installed unchanged.
- **E2b, P2:** use exactly `br agents --add --force` only after E2a accepts the
  preview, so compatible generation is bounded without a TTY. Do not substitute
  `--update --force` for this initial install: pinned `br 0.2.19` can report
  “already up to date” with status zero while the managed block is absent. After
  `--add --force` returns zero, reread `AGENTS.md` and require exactly one complete
  delimited block whose bytes equal the accepted preview before reporting success.
  Fixtures cover EOF/noninteractive success after acceptance with that exact
  byte/delimiter assertion, the zero-status `--update --force` no-op on a
  block-absent file, noninteractive omission after conflict, and no prompt hang.
- **E2c, P2:** own the “When the loop misbehaves” guidance in
  `skills/orchestrating-with-rb-lite/SKILL.md` plus executable prose extraction
  fixture `skills/orchestrating-with-rb-lite/scripts/diagnostic-guidance.test`.
  Before attributing exit 143/137 to collateral `pkill`, require reading reviewer
  JSON `terminal_reason`, `subtype`, and errors plus the disconfirming check for
  non-rb-lite process deaths. Remove “almost always.” A single failed concurrent
  panel is not evidence that parallel review is broken and must not recommend
  serialization. Fixtures feed an API abort, an actual signal, and one failed
  parallel round and assert the bounded diagnosis text/outcome. Run it and
  `./check.sh`. This row has no semantic dependency on E2a; both merely originate
  in issue #33 and the serialized `executor-skills` lane prevents concurrent file
  ownership.

The E2b noninteractive interface is pinned to installed `br 0.2.19` by this
disposable-repository measurement:

```text
$ br agents --help | grep -E -- '--add|--update|--dry-run|--force'
      --add                          Add beads workflow instructions to AGENTS.md
      --update                       Update beads workflow instructions to latest version
      --dry-run                      Preview changes without modifying files
  -f, --force                        Skip confirmation prompts
$ NO_COLOR=1 br agents --add --force --dry-run
Would add beads workflow instructions to: /tmp/<fixture>/AGENTS.md

--- Preview ---
<!-- br-agent-instructions-v1 -->
...
<!-- end-br-agent-instructions -->
$ add_rc=$?
$ br agents --update --force --dry-run
Beads workflow instructions are already up to date (v1).
$ update_rc=$?
$ printf 'add=%s update=%s\n' "$add_rc" "$update_rc"
add=0 update=0
```

The `update=0` result is negative compatibility evidence, not an installation
alternative: in this block-absent fixture it changed no bytes. E2b therefore pins
the initial write to `--add --force` and verifies the installed block itself
rather than treating either command's zero status as sufficient.

The skeptic-convergence observation is not a fourth E2 bead; F1 owns it together
with #47's fact-ownership policy.

### E3. Exact closure command — issue #65

**Priority:** P0. **Effort:** medium. **Depends on:** E1.

Create the installed companion:

- `skills/beads-close-transaction/SKILL.md`;
- `skills/beads-close-transaction/scripts/beads-close-transaction`; and
- `skills/beads-close-transaction/scripts/beads-close-transaction.test`.

Its only command is:

```text
"$BEADS_CLOSE_TRANSACTION" --id ID --reason-file PATH [--notes-file PATH]
```

That is the only argument API. At every call site, the caller passes its
already E1-validated retained path only as invocation context:

```text
BEADS_DIR="$BEADS_STORE_DIR" BEADS_JSONL="$BEADS_JSONL" \
  "$BEADS_CLOSE_TRANSACTION" --id ID \
  --reason-file PATH [--notes-file PATH]
```

`skills/beads-close-transaction/SKILL.md` owns one canonical locator block. Each
of the four migrated completion consumers points to and invokes that owner
rather than embedding an independently maintained copy. The canonical block
first verifies that the caller's already validated resolver path matches
`*/beads-jsonl-path/scripts/*`, then derives the target exactly as:

```bash
case $BEADS_JSONL_RESOLVER in
  */beads-jsonl-path/scripts/*) ;;
  *) echo "cannot derive closure helper from resolver" >&2; exit 1 ;;
esac
BEADS_CLOSE_TRANSACTION=${BEADS_JSONL_RESOLVER%/beads-jsonl-path/scripts/*}/beads-close-transaction/scripts/beads-close-transaction
```

The canonical locator validates that derived target exactly as the existing `git-clean`
sibling: it is executable, regular, non-symlink, has `nlink == 1`, and has
the canonical `#!/bin/sh` shebang; its canonical location is outside the driven
worktree; and its installed root is cross-root consistent with the validated E1
resolver. A failed strip match or any target validation failure stops with no
PATH or repository-relative fallback. `install.test` extracts and exercises that
single owner at all four boundaries and rejects any consumer that copies or
reimplements its trust logic; locator fixes therefore have one fact owner.
There is no public `check`, status schema or fingerprint, E1 workspace-paths or
Git-clean verb, helper-owned import, global lock, sidecar/recovery validation,
or automatic rollback, compensation, evidence copy, or recovery. The installed
companion has no PATH or repository-relative fallback and adds no E1 API.

At each serialized clean-`master` closure boundary, the caller has E1 prove the
tracked JSONL clean and completes the coordinator procedure, including its
caller-owned import and the repeated E1 proof immediately after that import.
After the status predicate passes, it invokes this helper without any
skills-store `ready`, `list`, `show`, or lane read until the helper returns and
closure metadata state is settled. That import and read prohibition are caller
workflow ownership, not E3 ownership. A helper refusal stops and reports the
closure; there is no retry loop.

The helper validates its inputs, canonicalizes its own installed script path,
and derives its private E1 resolver and `git-clean` sibling paths from that
path. It validates both derived siblings as the caller validates this helper:
executable, regular, non-symlink, `nlink == 1`, canonical `#!/bin/sh` shebang,
outside the driven worktree, and cross-root consistent with its own installed
root. Before any store-touching private E1 operation, it runs its private
resolver's `--run-br --no-auto-flush --no-auto-import --version` in a
selector-clean environment and requires status 0, exact stdout bytes
`br 0.2.19\n`, and empty stderr; a mismatch launches no normal E1 proof,
`where`, status, or mutation. It then requires both the caller's `BEADS_DIR` and
`BEADS_JSONL` contexts to be nonempty absolute paths without CR/LF, retains them
as the expected store and JSONL paths, and defines the expected database as
`<expected-store>/beads.db`. It launches every later private E1 child with
only `BEADS_DIR=<expected-store>` and `BEADS_JSONL=<expected-path>`, discarding
every other inherited `BEADS_*` and `BR_*` selector and exporting neither
derived sibling path. Before any status or mutation it captures exactly one
`br where --json` object and requires `.path` to equal the expected store,
`.database_path` to equal `<expected-store>/beads.db`, and `.jsonl_path` to
equal the expected path, all byte-for-byte; then its first private E1 resolution
must also return that expected path. Merely observing an echoed `jsonl_path` is
not store-identity proof. Thus a nested/default same-ID decoy cannot receive the
mutation, while a caller with an export below or outside its supported
in-worktree `BEADS_DIR` remains bound to the original validated database and
exact E1-validated JSONL.
Before any mutation it requires the reason and optional notes
payloads to be valid UTF-8 and rejects every raw NUL byte; a POSIX shell/argv
cannot preserve NUL, so such input is unsupported rather than silently altered.
The reason must be nonempty. With only those private derived siblings, it has E1's default
resolver prove and return the clean tracked JSONL path, snapshots it, and then
runs the status preflight. Every helper `br` invocation uses its private resolver's
`--run-br --no-auto-flush --no-auto-import` form, including `--version`,
`where --json`, `sync --status --json`, the target `show`, optional notes `update`, `close`,
the one explicit `sync --flush-only`, and the final `show`.
Using the same trusted derived `git-clean` sibling to run `python3 -I` and stdlib
`hashlib`, it calculates the plain SHA-256 of its own snapshot (Python 3 is
required). Through that resolver's jq runner with
`-se --argjson require_synced true`, it slurps the status transcript, requires
exactly one JSON document, and applies the exact caller-owned predicate above
to `.[0]`, including a string `jsonl_content_hash` equal to that
helper-calculated hash and the measured `git_export` cleanliness fields. It
rejects absent, mistyped, or ambiguous transcript fields. E1 does
not emit a plain SHA-256 content hash: `git hash-file` is a Git blob OID, not
that hash. This minimal private preflight directly refuses stale or DB-newer
caches before mutation; it adds no fingerprint, sidecar, recovery, import, or
public E3 mode. The helper shows exactly one nonclosed target row and requires
that row's `.id` to equal the supplied `--id` byte-for-byte; `br` accepts unique
prefixes, but this helper does not. It then optionally updates notes and closes
that exact target. It immediately reruns E1's default resolver as the second E1
proof immediately before its one explicit runner-mediated flush. After the
flush it reruns E1's existing resolver in `--allow-dirty` mode, requires the
same expected returned JSONL path, and uses that newly validated regular tracked path
for its post-show and final comparison. The final ID set is exact; every
non-target row is byte- and field-identical; and the target differs only in
`status`, `closed_at`, `close_reason`, `updated_at`, and optional `notes`.
Reason and notes must preserve their exact UTF-8 bytes. It returns zero only
after that complete proof. Required commands and options must be present or the
build fails closed.

Any failure returns nonzero and the coordinator stops. Before the first DB
mutation it uses an ordinary nonzero diagnostic. From the first DB mutation,
final stderr begins `CLOSURE_INCOMPLETE`; the helper stops and performs no
recovery. The coordinator manually uses E1's existing `--allow-dirty` plus clean
Git diff/show tools to inspect HEAD-versus-JSONL and the target. If exact final
one-target closure proof is already present, it may continue the closure metadata
PR; otherwise it requires explicit human repair. This is an
alert only, not a rollback, automatic recovery, or evidence claim. Use normal
foreground cancellation only; do not add a process supervisor, helper mode, or
state.

Migrate only four completion/delegation boundaries to this command: Drive LAND,
`rb-lite-backlog-drain` step 11, harden-until-clean's closure delegation, and
the Drive Guard 1 pointer. Each boundary invokes the canonical locator owner and
owns the caller import/status procedure; do not migrate scheduler reads, copy
the locator validation, or add `check`.
Wire selective install and `check.sh` for the companion. E3 and all four routed
completion consumers require exact installed `br 0.2.19` and use only the
advertised `--version`, `where`, `close`, `update`, `show`, and `sync` surface through
the E1 runner.
BUILD records `closure path exact br 0.2.19` at its real end-state sites:
the `skills/orchestrating-with-rb-lite/SKILL.md` declarations,
the harden-until-clean reference precondition,
`skills/drive/SKILL.md` compatibility, this backlog, and the README closure
path. Preserve the existing `br >=0.1.45` floors for non-closure and GRAPH uses;
do not collapse those compatibility claims. Those are BUILD changes, not changes
to those files in this amendment.

The helper tests wired into `check.sh` are stub-only. A disposable real-`0.2.19`
happy-path and refusal run is BUILD/PR evidence outside the mandatory gate.
Tests cover stubbed helper faults, exact input/newline fidelity plus pre-mutation
raw-NUL refusal, exact-ID/prefix refusal, complete target delta and bystander
preservation, successful import from the exact measured single-`jsonl_newer`
degraded state, pre-import dirty/DB-newer/other-anomaly refusal, the second E1
proof immediately before flush, post-flush `--allow-dirty` path revalidation,
custom-location binding where retained `BEADS_DIR` differs from the JSONL parent,
with a same-ID nested/default-store decoy plus mutations of each `where` identity
field, and locate-only version mismatch before the locator's final normal proof
or any caller/helper normal E1 proof, `where`, status, or import (with
per-command launch counters);
tests also cover pre- and post-mutation failures, slurped
single-document status parsing, all four consumer boundaries, and selective
install. In BUILD, red-mutate each
claimed property before its passing run. Keep helper production near 350 lines,
excluding the one canonical locator block at roughly 40 lines, and fixtures near
700; exceeding either budget returns E3 to SHAPE.

The saved-bytes/flush/diff bootstrap has amended exactly `skills-dhm`,
`skills-qmi`, and `skills-rrk`; `DRIVE.md` records its evidence. The next step is
exact-tree review and merge of this SHAPE/body amendment, not another bootstrap.
Start E3 BUILD only from refreshed clean `master`. E3 self-closure uses the
merged installed helper from the coordinator's outside-worktree skills clone.

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

**Priority:** P1. **Effort:** large/external dependency. **Depends on:** C2 and
E3.

**Executor:** `executor-rb-lite`.

Run this bead through a separately spawned agent whose current repository is
`/home/master/p/rb-lite`; do not hand it to the skills-repository backlog drain.
That agent must read `/home/master/p/rb-lite/AGENTS.md`, create
`feat/drive-checkpoint-hook` from current `origin/main`, and use
`orchestrating-with-rb-lite` in that checkout for the Codex-heavy implementation.
Run all three upstream gates even when an earlier one fails, capture each real
status separately, and require all three to be zero. When running those gates in
the rb-lite checkout, invoke the canonical wrapper defined by the skills
repository's managed `AGENTS.md` working agreement and substitute the following
self-contained body at its `<gate>` placeholder; do not edit either repository's
`AGENTS.md` or introduce a second trap, temporary-log owner, or cancellation
lifecycle:

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
  terminal JSON object, with three fixed, mutually distinct rb-lite process exit
  codes for `checkpoint_stopped`, `checkpoint_failed`, and
  `checkpoint_timed_out`, none equal to the success code or a signal-derived
  status.

Deterministic upstream tests must cover both boundaries, the stabilizing
iteration, actual joined-panel result, 0/20/other statuses, all three exact
terminal process codes, preserved artifacts,
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

Here `F2` means the resolved generated bead ID, not the plan alias. At the
serialized clean-`master` closure boundary, the terminal mutation is one E3 call:

```text
BEADS_DIR="$BEADS_STORE_DIR" BEADS_JSONL="$BEADS_JSONL" \
  "$BEADS_CLOSE_TRANSACTION" --id <F2-bead-id> \
  --reason-file <merge-evidence-file> --notes-file <upstream-evidence-file>
```

Before it, F2 follows the existing Drive LAND pointer to E3's canonical locator
owner rather than creating another locator. E1 proves the tracked JSONL clean,
and the coordinator completes the fixture-owned caller status-equality procedure
above. A helper
refusal stops and reports; do not retry. Do not run a raw `br update`, raw `br
close`, or separate flush after the helper.

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
Then probe the commit-qualified released artifact. The coordinating agent invokes
C1's already-landed `claude-reviewer-runner command-no-output
--timeout-seconds 900 -- <executable> [arg...]` lifecycle boundary. It runs one
fixed argv vector with stdin closed, no shell, model, prompt, or result, and
succeeds only when the child exits 0 with empty stdout/stderr. Its bounded
TERM/CONT/KILL, timeout status 124, caller-signal status, and reaping contract
are exactly C1's. The displayed block is written to a private mode-0700
directory as an executable wrapper and passed as the single executable argv to
that supervisor; it must not be invoked directly:

```bash
#!/usr/bin/env bash
TAG="<immutable-tag>"
COMMIT="<immutable-commit>"
PROBE_DIR=${0%/*}
PROBE_LOG="$PROBE_DIR/release-probe.stderr"
umask 077
: >"$PROBE_LOG" || exit 1
_probe_fail() {
  printf '%s\n' "$1" >>"$PROBE_LOG"
  exit 1
}
_release=$(
  gh release view "$TAG" -R douglaz/rb-lite \
    --json url,tagName,isDraft,isPrerelease 2>>"$PROBE_LOG"
) || _probe_fail "published rb-lite release is absent"
printf '%s' "$_release" |
  jq -e --arg tag "$TAG" \
    '.tagName == $tag and .isDraft == false and .isPrerelease == false' \
    >/dev/null 2>>"$PROBE_LOG" ||
  _probe_fail "rb-lite release metadata does not match authorization"
_refs=$(git ls-remote --tags https://github.com/douglaz/rb-lite.git \
  "refs/tags/$TAG" "refs/tags/$TAG^{}" 2>>"$PROBE_LOG") ||
  _probe_fail "cannot resolve published rb-lite tag"
_tag_commit=$(
  printf '%s\n' "$_refs" |
  awk -v tag="refs/tags/$TAG" '
    $2 == tag { direct=$1; direct_n++ }
    $2 == tag "^{}" { peeled=$1; peeled_n++ }
    END {
      if (direct_n != 1 || peeled_n > 1) exit 1
      print (peeled_n == 1 ? peeled : direct)
    }
  ' 2>>"$PROBE_LOG"
) || _probe_fail "rb-lite tag resolution is ambiguous"
[ "$_tag_commit" = "$COMMIT" ] ||
  _probe_fail "rb-lite release tag does not resolve to the authorized commit"
_store=$(
  nix build --no-link --print-out-paths \
    "github:douglaz/rb-lite/$COMMIT" 2>>"$PROBE_LOG"
) || _probe_fail "published rb-lite cannot be realized"
case $_store in
  ''|*$'\n'*|*$'\r'*) _probe_fail "rb-lite realization is ambiguous" ;;
esac
[ -x "$_store/bin/rb-lite" ] ||
  _probe_fail "realized rb-lite executable is absent"
_caps=$(
  "$_store/bin/rb-lite" capabilities --json 2>>"$PROBE_LOG"
) || _probe_fail "published rb-lite is not runnable"
printf '%s' "$_caps" |
  jq -es '
    length == 1 and
    ((.[0] | type) == "object") and
    (.[0].synchronous_checkpoint == 1)
  ' >/dev/null 2>>"$PROBE_LOG" ||
  _probe_fail "published rb-lite lacks synchronous checkpoint capability"
_refs_after=$(git ls-remote --tags https://github.com/douglaz/rb-lite.git \
  "refs/tags/$TAG" "refs/tags/$TAG^{}" 2>>"$PROBE_LOG") ||
  _probe_fail "cannot recheck published rb-lite tag"
[ "$_refs_after" = "$_refs" ] ||
  _probe_fail "rb-lite release tag moved during verification"
```

Replace every placeholder with the recorded values. Fixtures or a checked
release transcript cover lightweight and annotated tags, absent/draft releases,
tag/commit mismatch, and successful capability probing. Authorization without
a published, consumable, tag-and-commit-verified artifact does not close F2r;
F3 separately pins the verified commit as its immutable fallback rather than a
path-only, moving-tag, or version-text guess.
The release/tag checks establish published identity; probe the already verified
commit-qualified artifact so a transient tag rewrite cannot change executed
bytes. A timeout, signal, descendant leak, or nonempty unexpected stream from the
landed supervisor blocks closure. Nix realization progress is expected on a cold
host, so the wrapper redirects all child stderr to its mode-0600 `PROBE_LOG`,
captures the one output path, and probes that realized executable; it never
requires Nix itself to be silent. Preserve and cite the private log on failure,
and remove the private wrapper directory only after successful metadata capture.

After publication and the supervised probe succeed, record F2r through a dedicated
reviewed skills metadata transaction. Create `metadata/close-f2r-release` from
current `master`; use E1 to prove the JSONL clean; make only the F2r
authorization/release evidence and closure JSONL change plus the `DRIVE.md`
Done/Now/Next update; successfully run
the fixture-owned caller status-equality procedure above. F2r reuses the
existing Drive LAND pointer to E3's canonical locator owner rather than creating
another locator, then invokes exactly:

```text
BEADS_DIR="$BEADS_STORE_DIR" BEADS_JSONL="$BEADS_JSONL" \
  "$BEADS_CLOSE_TRANSACTION" --id <F2r-bead-id> \
  --reason-file <publication-evidence-file> --notes-file <release-evidence-file>
```

Helper refusal stops and reports; do not retry. Push and open a PR whose body contains `bead-closure: <F2r-bead-id>`; once GitHub
assigns `N`, amend `DRIVE.md` to `Pending: metadata PR douglaz/skills#N`; rerun
`./check.sh` and the independent panel on the amended tree; force-push with lease;
then merge. Do not mutate directly on `master`, combine this metadata with F3, or
make F3 ready before this reviewed closure lands.

### F3. Foreground Drive controller — issues #48, #30, #31, #35

**Priority:** P1. **Effort:** extra large. **Depends on:** C1 and F2r.

Implement:

- resolve rb-lite candidates by capability, not path presence or version text:
  reject a PATH candidate unless `rb-lite capabilities --json` exits 0 and
  reports `"synchronous_checkpoint":1`; otherwise fall back to
  `nix run github:douglaz/rb-lite/<F2r-immutable-commit> --`, probe that exact
  command too, and fail preflight if neither qualifies. Bound each probe to a
  declared positive timeout (default 120 seconds for PATH; 900 seconds for the
  cold immutable Nix fallback), stdin closed and a private
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

### G1. Read-only commit verifier — issues #32 and #34

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
absent from REV's tree (not merely absent from its changed-path set); and
`--exact-paths` requires the revision diff to contain
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

**Priority:** P2. **Effort:** large. **Depends on:** E3 bootstrap only.

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
G2 does not consume G1; G3 independently consumes both owners.

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
retain decision. After any tracked edit run
`skills/verify-commit/scripts/verify-commit.test`,
`skills/executable-docs/scripts/executable-docs.test`,
`skills/executable-docs/scripts/executable-docs --document
skills/agents-md/references/behavioural-claims.md --manifest
skills/executable-docs/manifests/behavioural-claims.json`, and `./check.sh`,
recording all real statuses and requiring zero. A notes-only retain decision
records the exact inventory and word-count commands plus their real statuses
instead.

## Complete execution-bead table

The GRAPH transfer creates exactly one execution or decision bead per row. This
table is the authoritative priority and dependency source; prose above supplies
the body. Every row gets label `drive-open-issues`; B0 and F2r get
`authority-human`, F2 gets `executor-rb-lite`, and every other row gets
`executor-skills`.

| Bead | Priority | GitHub | Depends on | Deliverable |
|---|---:|---|---|---|
| A1 | P0 | #42 | E3 | Tip-scope bot review objects |
| A2 | P1 | #66 | A1 | Traceable per-thread disposition |
| A3a | P1 | #65 | A1 | Preserve first degraded exit-4 evidence |
| A3b | P1 | #65 | A1, A3a | Private unique post-merge evidence |
| A3c | P1 | #65 | A1 | Exclude closure PRs from work-PR resume |
| A4a | P3 | #65 | E3 | Drive routing wording and trigger fixture |
| A4b | P3 | #65 | E3 | Adjudicate moved backlog examples |
| B0 | P0 | #41, #43, #34, #65 | E3 | Record the human dirty-state decision |
| B1d | P0 | #41, #43, #34, #65 | B0 | Delegated-edit design and fixture contract |
| B1 | P0 | #41, #43, #34, #65 | B1d | Delegated-edit isolation implementation |
| B2a | P1 | #34 | E3 | Unsafe red evidence blocks completion |
| B2b | P0 | #34 | E3 | Preserve colocated tests during inversion |
| B2c | P2 | #34 | C1 | Tested panel shutdown/escape |
| B2d | P2 | #34 | G1, B2c | Do not mask verification execution errors |
| B2e | P0 | #34 | E3 | Compare flush against saved bytes |
| C1 | P1 | #53–#58, #60 | E3 | Shared bounded Claude reviewer runner |
| C2 | P1 | #51 | C1 | Bound rb-lite reviewer model |
| C3 | P0 | #59 | C1 | Enforced reviewer isolation |
| D1 | P2 | #61, #38, #65 | E3 | Old-Bash argv and empty discovery |
| D2 | P0 | #62, #65 | D1 | Re-exec provenance and marker diagnostic |
| D3 | P2 | #63 | D1 | YAML-equivalent companion names |
| E1 | P0 | #44, #65 | — | Fail-closed JSONL path ownership |
| E2a | P0 | #33 | E3 | Resolve generated protocol conflict |
| E2b | P2 | #33 | E2a | Noninteractive generated behavior |
| E2c | P2 | #33 | E3 | Correct panel diagnostics |
| E3 | P0 | #65 | E1 | Exact fail-closed closure command |
| F1 | P2 | #47, #33 | E3 | Deduplication and fact ownership |
| F2 | P1 | #48 | C2, E3 | Upstream synchronous checkpoint seam |
| F2r | P1 | #48 | F2 | Human-authorized release publication |
| F3 | P1 | #48, #30, #31, #35 | C1, F2r | Foreground Drive controller |
| G1 | P2 | #32, #34 | E3 | Read-only commit verifier |
| G2 | P2 | #49 | E3 | Executable-document harness |
| G3 | P3 | #50 | G1, G2 | Managed-block length decision |

Constraints:

- Only one owner edits the delegated-edit or panel-runner file set at a time.
- The direct E3 edges on otherwise-root rows are deliberate bootstrap barriers,
  not semantic implementation prerequisites. Retain them until E3 is closed; they
  make the tracked scheduler agree with global rule 8 instead of relying on a
  prose exception to `br ready`/`bv` recommendations.
- B2c remains a consumer-level #34 integration regression after C1 owns the
  lifecycle; E3 remains the exact harden-until-clean close/flush proof after E1
  owns resolution. Neither is a duplicate of its prerequisite.
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
  "$BEADS_JSONL_RESOLVER" --run-br --no-auto-flush --no-auto-import \
    ready --limit 0 -l drive-open-issues -l executor-skills
  "$BEADS_JSONL_RESOLVER" --run-br --no-auto-flush --no-auto-import \
    ready --limit 0 -l drive-open-issues -l executor-rb-lite
  "$BEADS_JSONL_RESOLVER" --run-br --no-auto-flush --no-auto-import \
    ready --limit 0 -l drive-open-issues -l authority-human
  ```

  The first lane runs in this repository, the second routes to the
  cross-repository procedure above, and the third is reported for human action
  but never sent to an implementer. These scheduler reads remain outside E3:
  after each clean-`master` refresh the coordinator performs the runner-mediated
  import and same status-equality preflight in global rule 8 before these reads.
  This is explicit coordinator workflow, not an E3 public API, lock, or recovery.

## Beads graph to update

After review, update the existing graph in place into:

- exactly one flat execution/decision bead per row in the complete
  execution-bead table, with no tracking parent or epic;
- every dependency edge in that table;
- GitHub URLs and named gate commands in every executor bead;
- the decision/publication evidence named for B0 and F2r instead of an
  implementation gate; and
- the exact priority and executor labels in the table.

Before any execution state changes, the exact scoped ready set is only E1 in the
`executor-skills` lane; both other lanes are empty. After E1's work and closure
metadata PRs merge, only E3 is ready. After E3's work and closure metadata PRs
merge, the normal frontier opens to A1, A4a, A4b, B0, B2a, B2b, B2e, C1, D1,
E2a, E2c, F1, G1, and G2 in their table lanes; rule 7 still permits only one
active `executor-skills` bead. Every later table row must appear when all its
prerequisites close. B1d must close before B1 can enter BUILD. F2 must record
its upstream issue/PR URL before it can become in progress.

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
