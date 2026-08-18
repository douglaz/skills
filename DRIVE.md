# DRIVE — execute the open skills safety and correctness backlog

**Scope:** the 29 GitHub issues enumerated in
`docs/specs/backlog-execution-plan.md` (#30–#66, exact set in that plan); the
Beads graph created from the reviewed plan will be the ONLY work this drive may
take.
**Phase:** SHAPE · **Bead:** `skills-dhm` (E3)
· **Branch:** `feat/skills-dhm-beads-close-transaction`
**Pending:** exact-tree review and PR for the KISS E3 amendment plus its three
aligned Beads bodies
**Gate:** `./check.sh`
· last green 2026-08-14 on the E1 closure tree (exit 0; 139 resolver,
53 installer, 124 bot-gate, and 70 drive-status fixtures passed under GNU Bash
5.3.15, non-POSIX mode, Git 2.55.0, `br` 0.2.19, and uid 1000).

## Done

- Queried all 29 open GitHub issues and confirmed that this repository has no
  initialized Beads store.
- Reconciled umbrellas, overlaps, priorities, dependencies, and parallel work
  lanes.
- Replaced the stale PR #64 drive record with this newly authorized goal.
- Installed the portable working agreement for subsequent implementers and
  panels.
- Passed the SHAPE hard stop: `codex review --base master` with
  `gpt-5.6-sol`/`xhigh` reported no P0/P1 findings at `bceb919`. Its two P2
  hardening observations (startup-watchdog group cancellation and defensive
  fixture orphan cleanup) remain non-blocking follow-up evidence for the
  admission-integrity stream.
- Ran the repository gate at `bceb919`: `./check.sh` exited 0 (26 installer,
  124 bot-gate, and 66 drive-status fixtures passed under GNU Bash 5.3.3,
  non-POSIX mode).
- Initialized Beads and transferred all 33 reviewed rows with 22 dependency
  edges; the first transfer audit found the exact expected labels, priorities,
  URLs, bodies, and ready A1 (`skills-ro5`).
- GRAPH polish then found that several lower workstream rows copied real intent
  but not enough API, failure, recovery, or fixture detail to be executable by a
  fresh agent. Per the GRAPH escalation rule, returned to SHAPE rather than
  encoding implementation guesses downstream.
- Repeated pinned Codex xhigh reviews drove the canonical gate wrapper to
  fail-closed process-group, output, cleanup, and inherited-signal behavior.
  `./check.sh` exited 0 on the `10c0288` tree (26 installer, 124 bot-gate, and 70
  drive-status fixtures passed under GNU Bash 5.3.3, non-POSIX mode).
- Called Fable at high effort to review the complete `docs/specs` inventory. It
  read all 33 rows and found two blocking plan gaps: B2d lacked its B2c
  serialization/artifact edge, and E3 relied on an unattested `br sync --status
  --json` schema. The plan now adds that edge, pins the measured `br 0.2.19`
  schema/hash, and incorporates the valid lower-severity corrections.
- Cleared the repeated SHAPE hard stop on `9965c24`: pinned
  `gpt-5.6-sol`/xhigh Codex reported no P0/P1 findings (one non-blocking P2 about
  the pre-supervisor ignored-signal startup window), Fable/high reported
  `NO BLOCKING FINDINGS`, and `./check.sh` exited 0 (26 installer, 124 bot-gate,
  and 70 drive-status fixtures under GNU Bash 5.3.3, non-POSIX mode).
- Updated all 33 existing beads in place at `c921749`, preserving IDs and
  producing the reviewed 24-edge graph; exact field/body, label, cycle, and ready
  audits passed.
- Ran five fresh read-only polish passes. Coverage mapping passed, while the
  critical-path passes found that E1/E3 bootstrap ordering was not encoded in the
  graph, closure metadata needed an explicit merge between bootstrap stages, E3
  was materially undersized, and several shared owners/acceptance commands were
  implicit. Returned to SHAPE and accepted those corrections.
- Cleared the second SHAPE hard stop on `ec076e9`: Fable/high reported
  `NO BLOCKING FINDINGS`; pinned `gpt-5.6-sol`/xhigh Codex reported no P0/P1
  findings (one non-blocking P2 on fixture-only startup-timeout orphan cleanup);
  and `./check.sh` exited 0 with 26 installer, 124 bot-gate, and 70 drive-status
  fixtures under GNU Bash 5.3.3, non-POSIX mode.
- Updated all 33 beads in place to the final reviewed 37-edge graph at
  `7d88c46`, preserving every generated ID. Exact field/body, lint, cycle,
  sync-health, and frontier audits passed: E1 (`skills-iog`) is the sole ready
  bead.
- Completed the independent second-model bead audit against immutable JSONL
  snapshot
  `481a8b9192717cbf2df26a08d1c76bdf4d3910875f9f1c3dee810ed2a3c0de44`.
  Pinned `gpt-5.6-sol`/xhigh and Fable/high both read all 33 bodies and voted
  PASS with no blocking or important findings. Fable's two optional nits do
  not change the graph: exact tests already exist in the five cited bodies,
  and keyword-driven `bv` executor-label suggestions conflict with the
  authoritative one-lane contract.
- Reran `./check.sh` on `7d88c46` under GNU Bash 5.3.3, non-POSIX mode; it
  exited 0 and all 220 fixtures passed.
- PR #68 review found and fixed two additional fail-open shell-shim paths plus
  two specification/body defects: the gate wrapper now clears startup variables
  and exported functions before either Python launch; E3 reads only immutable
  helper-private evidence snapshots; E2b permits only the measured initial
  `br agents --add --force` path and verifies the installed block bytes instead
  of trusting `--update`'s false zero-status no-op. Fable's convergence pass
  caught the two sibling beads that also embed the E2 section; the corrected
  contract is now present in E2a, E2b, and E2c. Focused mutations made each new
  gate fixture fail for its intended assertion before the production fix.
- The PR's final startup-timeout finding reproduced: killing only the fixture's
  Python supervisor orphaned its independently grouped gate. The bounded fixture
  cleanup now reaps both without re-signalling an observed-dead/reused PID, all
  analogous timeout paths use it, and a fresh read-only reviewer voted PASS.
- A subsequent current-tip review reproduced scheduler-latency failure in the
  fixture readiness polls. All analogous setup handshakes now allow a bounded
  ten seconds while the behavior deadlines remain two seconds; the aggregate
  fixture's missing-marker branch is also bounded and fail-closed. A final
  diff-based reviewer voted PASS.
- On the resulting `4317460` tree, `./check.sh` under GNU Bash 5.3.15,
  non-POSIX mode, exited 0 with 26 installer, 124 bot-gate, and 70 drive-status
  fixtures; stderr was empty and no fixture gate process survived.
- Called Fable/high again after all specification/body corrections. It reread
  the full specification, all 33 bodies, `AGENTS.md`, `DRIVE.md`, and linked
  owners and reported `NO BLOCKING FINDINGS`.
- Closed the final current-tip gate supervision findings at `ad5fe0b`: a
  privileged-Bash preflight now rejects an exported `command` trust-anchor
  function before any artifact is created; the Linux supervisor reaps adopted
  children on normal completion; and the behavior fixtures use one childless
  watchdog with pidfd-pinned deadline targets rather than orphanable Bash
  `sleep` timers. Full-wrapper normal-orphan coverage and hostile-command
  coverage both fail against their isolated regressions. `./check.sh` then
  exited 0 with 26 installer, 124 bot-gate, and 70 drive-status fixtures;
  stderr was empty.
- CodeRabbit's current-tip pass found that the new Python-watchdog readiness
  poll still used a two-second setup budget. Commit `8844eaa` aligns it with
  the other ten-second startup handshakes without changing the watchdog's
  two-second behavior deadline; the full gate passed with the same 26/124/70
  counts and empty stderr.
- Codex's next current-tip pass found that a non-exported local `command`
  function could still swallow the final supervisor `exec`. Commit `eab5c53`
  removes that function before the first normal-shell `command`; the new
  source-in-current-shell fixture fails against the isolated regression, and
  the full gate again passed 26/124/70 with empty stderr.
- A subsequent Codex pass combined hostile local `builtin` and `command`
  functions. Commit `2c74bb0` closes the class rather than adding another
  trust anchor: POSIX special-builtin precedence removes the local
  `unset`/`exec` path, `exec` replaces the caller with a privileged clean Bash,
  and that shell rejects remaining raw exported-function entries. Disabling
  POSIX precedence makes the combined fixture fail 25/1; the corrected full
  gate passed 26/124/70 with empty stderr.
- Independent review then found alias expansion and a caller-controlled `BASH`
  path on the outer trust path. Commit `3df315b` backslash-suppresses the
  special-builtin words, resolves Bash through `command -p`, and narrows the
  inherited-ignored-signal claim to the post-supervisor boundary. The combined
  alias plus hostile-`BASH` regression fails 25/1; the full gate passed
  26/124/70 with empty stderr.
- Codex then found that pidfd-only fixture deadlines made the repository gate
  fail on portable supervisors. Commit `b8e2ae7` detects pidfd capability,
  keeps all portable wrapper/output/cleanup/subreaper assertions active, and
  skips only the Linux identity-safe external signal/deadline group. Both the
  normal full gate and forced-no-pidfd installer run pass 26/0 with empty
  stderr; the aggregate gate remains 26/124/70.
- Codex's next pass found that the supervisor merged gate stderr into stdout,
  contradicting the evidence rule that stream placement remain observable.
  Commit `37f0e8e` buffers both streams privately and replays each to its
  corresponding descriptor only after completion. Re-merging them makes the
  new streams fixture fail 25/1; normal and forced-no-pidfd installer runs pass
  26/0, and the full gate passes 26/124/70 with empty stderr.
- Codex then found alias expansion on the trusted `command -p` Bash lookup.
  Commit `4f26161` backslash-suppresses that command word and extends the
  combined alias fixture; removing the suppression fails 25/1, while the full
  gate passes 26/124/70 with empty stderr.
- Codex's next pass found the pidfd watchdog killed only the gate-group
  leader. Commit `4e9db0d` holds the leader pidfd to pin its numeric PGID while
  issuing one group-wide `SIGKILL`, then kills the wrapper through its pidfd.
  A dedicated leader-plus-descendant deadline fixture fails 25/1 against the
  leader-only regression. Normal and forced-no-pidfd installer runs pass 26/0;
  the full gate passes 26/124/70 with empty stderr.
- Codex's next pass found the exec-failure watchdog could delete a slowly
  launching supervisor, and found C1's atomic rename could overwrite a result
  path created during review. Commit `803ec9d` ties cleanup to the owner-process
  handoff instead of a fixed timer and specifies same-directory exclusive-link
  publication for C1 in both plan and bead. A three-second launch passes; the
  old two-second timer fails 25/1. Normal and forced-no-pidfd installers pass
  26/0, and the full gate passes 26/124/70 with empty stderr.
- The next current-tip review found serial replay could let a blocked stdout
  consumer starve stderr, cleanup diagnostics could be lost to a full
  nonblocking stderr pipe, two deadline fixtures lacked explicit setup
  assertions, and C3's result rename could replace a path raced into existence.
  Commit `da82ec0` adds fair selector-based stream replay, restores stderr
  blocking before cleanup diagnostics, makes both fixture preconditions
  explicit, and specifies same-directory mode-0600 exclusive-link publication
  for C3 in both plan and bead. The two focused replay/cleanup regressions each
  fail 25/1 against their mutants; normal and forced-no-pidfd installer runs
  pass 26/0, and the full gate passes 26/124/70 with empty stderr.
- Re-audited the current 33-bead, 37-edge graph at immutable JSONL snapshot
  `276f9a16e6bc62aa49e1ae5faf494d152b5b32a55d32b81ae6447c5ee99c1ff6`
  after the C3 body correction. On the independent retry, pinned
  `gpt-5.6-sol`/xhigh and Fable/high both returned semantic PASS. Fable's two
  optional nits were this now-completed gate-evidence refresh and cosmetic
  sibling B2 source-section duplication; neither changes the graph.
- The current-tip Codex pass then reproduced inherited pipe flag corruption:
  setting `O_NONBLOCK` on the supervisor's stdout/stderr descriptors changed
  the shared open-file descriptions for unrelated writers. Commit `0236179`
  instead forks one independently killable replay worker per stream without
  changing inherited flags, supports initially blocking and nonblocking
  descriptors, polls both workers fail-fast, and kills/reaps every outstanding
  worker under the managed-signal mask. Fixtures preserve and verify both
  streams' flags and exact bytes, pin both workers across TERM, and force one
  worker to fail while its sibling is blocked. Flag mutation, missing EAGAIN
  retry, and sequential-wait mutants each fail 25/1 at their intended
  assertion; three consecutive installer runs pass 26/0, the forced-no-pidfd
  run passes 26/0, an independent focused reviewer reported no P0–P2 findings,
  and the full gate passes 26/124/70 with empty stderr.
- Codex's next pass found that the cancellation fixture discovered replay
  workers through an optional procfs `children` entry even though its
  capability gate tested only pidfds. Commit `bd3a883` generates a
  fixture-local wrapper that publishes both exact worker PIDs after both forks;
  the inspector opens pidfds from that explicit handshake, with no procfs
  dependency. Three consecutive installer runs pass 26/0, and the full gate
  passes 26/124/70 with empty stderr.
- Implemented E1 (`skills-iog`) in PR #69 and squash-merged it as `a70670d`.
  The installed `beads-jsonl-path` owner now resolves the tracked JSONL
  fail-closed, isolates all Git/Beads/audit execution boundaries, and migrates
  every consumer. The current-tip Codex gate returned
  `NO_PENDING_EVIDENCE` for reviewed tip `20905d8`; CodeRabbit succeeded; all
  review threads were dispositioned; and independent focused reviewers passed.
- Refreshed clean `master` after PR #69 and reran `./check.sh` under GNU Bash
  5.3.15, non-POSIX mode, Git 2.55.0, `br` 0.2.19, and uid 1000; all 139
  resolver, 53 installer, 124 bot-gate, and 70 drive-status fixtures passed.
  The generic `nix build` placeholder is not this repository's gate and
  correctly reported that the checkout has no `flake.nix`.
- Completed E1's exclusive closure transaction from merged `master` through the
  pre-E3 manual saved-bytes/explicit-flush/diff path: it closed only
  `skills-iog` with auto import/flush disabled and proved the ID set unchanged
  with only E1 `status`, `closed_at`, `close_reason`, and `updated_at`
  differing. That already-completed bootstrap required neither E3 nor an E3
  status preflight. `./check.sh` then passed all 386 fixtures on the exclusive
  two-file closure tree under the recorded Bash/Git/`br`/uid environment.
- After the failed E3 implementation and reviews, the user chose the KISS
  close–flush–prove amendment. Pinned Codex xhigh and Claude Opus max were used
  as advisory reviewers while resetting the one-helper specification, but those
  early invocations did not retain separated streams and are not admission
  evidence. Commit `0615222` records that two-document reset; only the final
  combined-tree commands recorded below determine whether this SHAPE boundary
  may land.
- Completed the required saved-bytes/import/flush/diff bootstrap for exactly
  `skills-dhm`, `skills-qmi`, and `skills-rrk` using merged E1 and installed
  `br 0.2.19`. The initial tracked JSONL SHA-256 was
  `d4b37bc7de43067c2a700c27286cd6ea380d35c6be27357637c489c4d1b2471d`;
  the caller-owned import left those bytes unchanged, and the final comparison
  proves the 33-ID set unchanged with only `description` and `updated_at`
  differing on those three rows.
- The first combined-tree review required the bodies to carry the exact status
  predicate, restored E3's umbrella guardrail, required pre-mutation raw-NUL
  refusal, and removed the completed bootstrap instruction. The corrected body
  rerun used installed `br 0.2.19` through
  `resolve-beads-jsonl --run-br --no-auto-flush --no-auto-import`: each of the
  three `update ID --description PAYLOAD` commands exited 0 with respectively
  54/57/57 stdout bytes and zero stderr bytes, and `sync --flush-only` exited 0
  with 97 stdout bytes (`33 issues`, `37 dependencies`, `66 labels`, `0 comments`,
  `3 issues` cleared) and zero stderr bytes. A Python-3 exact-field comparison
  against the saved initial JSONL then exited 0: all 33 IDs remained, and only
  `description` and `updated_at` differed on those three IDs.
- The next exact-tree Codex pass reproduced three remaining bounded failures:
  import could precede dirty/DB-newer refusal, `br 0.2.19` accepts unique ID
  prefixes, and the final comparison retained a pre-flush path. The contract and
  all three bodies now run the typed status predicate before import, require the
  shown row's full ID byte-for-byte, and revalidate the post-flush JSONL through
  E1 `--allow-dirty`. The final body rerun again recorded 0 for all three updates
  and the one flush with stderr empty, and the saved-initial-to-final comparator
  again reported exactly 33 IDs and only the same three
  `description`/`updated_at` pairs.
- The following Codex pass found that safe pre-import reconciliation also needs
  to admit the one expected `jsonl_newer` degraded state and that locator trust
  logic needed one fact owner. In a disposable clean Git clone using exact
  `br 0.2.19`, `br --no-auto-flush --no-auto-import sync --status --json`
  exited 0 with 792 stdout bytes and zero stderr bytes for that state: `dirty_count=0`,
  `jsonl_newer=true`, `db_newer=false`, and exactly one degraded
  `jsonl_newer` anomaly. Each predicate probe used
  `resolve-beads-jsonl --run-jq -se --arg hash HASH --argjson require_synced MODE -f PREDICATE`
  with its status transcript on stdin and separated output files: synced/`true`
  exited 0 with 5 stdout/0 stderr bytes; JSONL-newer/`false` exited 0 with
  5/0; JSONL-newer/`true` exited 1 with 6/0; and the
  `db_newer=true` mutation/`false` exited 1 with 6/0. The helper skill now owns
  one canonical locator block, and all four consumers point to that owner rather
  than copying its trust logic.
- The next Codex pass found that discarding E1 location context could select a
  same-ID default-store decoy and that caller import preceded the pinned-version
  check. Caller and helper preflights now require exact `br 0.2.19` bytes and
  status in a selector-clean environment before any normal E1 proof, `where`,
  status, import, or mutation. The caller uses E1's already documented
  locate-only truncation before its final clean-mode resolver call; per-command
  launch-counter fixtures pin that ordering.
- Codex and Opus then independently found that `BEADS_JSONL` alone relabels the
  export path but does not bind the database store. In a disposable directory,
  `BEADS_JSONL=PATH br --no-auto-flush --no-auto-import where --json` exited 0
  with 146 stdout/0 stderr bytes and reported `/tmp/.beads/beads.db`; adding
  `BEADS_DIR=${PATH%/*}` exited 0 with 210/0 and reported that parent's
  `beads.db` plus the exact JSONL. Because a supported export may sit below its
  database directory, the caller now retains the original validated `where`
  triple instead of inferring the store from the JSONL parent. Both caller and
  helper receive that exact `BEADS_DIR`/`BEADS_JSONL` pair, recapture
  `.path`/`.database_path`/`.jsonl_path`, and require byte identity before any
  status/import or closure mutation.
- The final location review measured that `br 0.2.19` cannot close an export
  outside its retained `BEADS_DIR`. In a disposable clone with both selectors
  explicit, `sync --status --json`, `show skills-dhm --json`, and
  `close skills-dhm --reason probe` each exited 7; their separated stdout/stderr
  byte counts were respectively 316/0, 303/0, and 0/181. E3 therefore supports
  nested exports only when the JSONL is a strict descendant of the retained
  store and refuses an external path before status/import or closure.
- The next Codex pass found two executable-prose omissions: the locate-only flow
  had not explicitly assigned the clean resolver result to `BEADS_JSONL`, and a
  valid JSON prefix could be parsed after its producer exited nonzero. The caller
  now assigns and byte-checks that sole path before constructing selectors.
  Every caller/helper resolver, `where`, status, and show capture requires status
  0 and empty stderr before parsing; valid JSON plus nonzero status or stderr is
  a required refusal fixture.
- Opus then found the helper's second E1 proof lacked the same explicit
  status/stderr/path acceptance, while Codex found the import command itself
  lacked a success gate and the caller preflight still had four prospective
  owners. The second proof and import now require status 0 and empty stderr
  before flush/continuation. `beads-close-transaction/SKILL.md` owns one
  canonical locator block and one canonical caller-preflight block; all four
  consumers point to those owners, and the plan/bead mirrors are byte-pinned
  self-contained scheduler records rather than executable copies.
- Released the completed `skills-iog`/`feat/skills-iog-beads-jsonl-path`
  `executor-skills` reservation and atomically handed it to
  `skills-dhm`/E3 on `feat/skills-dhm-beads-close-transaction`; that exact E3
  reservation is current.

## Now

The KISS E3 SHAPE specification and its three aligned Beads bodies are complete.
Run one exact-tree pinned Codex xhigh plus Claude Opus max review, rerun
`./check.sh`, and land the bounded amendment PR without beginning BUILD.

## Next

After the amendment PR lands, refresh clean `master`, verify the installed
revision and bytes, and start E3 BUILD as a separate branch/lifecycle. Only E3's
own and later closures use the merged installed helper from the coordinator's
outside-worktree skills clone; do not require an E3 preflight before dispatching
E3. Continue with A1 only after E3 lands.

## Open questions for the human

- Before B1 BUILD: choose between refusing unsupported dirty delegated paths
  (recommended: disposable worktree plus fail-closed refusal) and supporting
  dirty in-scope preservation through the larger snapshot mechanism. This is a
  user-state/data-loss design checkpoint.
- Before F2 release: authorize publishing the required upstream rb-lite release.
  Opening and reviewing its branch/PR may proceed; publishing the release may not.
  Once authorized, the coordinating skills agent performs and verifies the
  mechanical publication—human authority does not require the human to run the
  release commands.
