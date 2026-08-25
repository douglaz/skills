# DRIVE — execute the open skills safety and correctness backlog

**Scope:** exactly the 29 GitHub issues in the #30–#66 set enumerated by
`docs/specs/backlog-execution-plan.md`; the Beads graph is the only work. Current focus is
E3 (`skills-dhm`).
**Scope-Label:** `drive-open-issues`
**Phase:** BUILD · **Bead:** `skills-dhm`
· **Branch:** `feat/skills-dhm-native-close-implementation`
**Pending:** hand off the verified uncommitted E3 delta; the coordinator owns the separate
Beads-body metadata transaction and subsequent review/PR flow
**Gate:** `./check.sh` · repository-gate environment: GNU Bash 5.3.15 (non-POSIX),
Git 2.55.0, installed `br` 0.2.19; last green 2026-08-23 on this E3 implementation tree
under the protected AGENTS wrapper (146 resolver, 55 installer, 124 bot-gate, 91
drive-status, 41 native-close, and 43 closure-consumer fixtures; 500 total, `EXIT=0` with
zero gate stderr bytes). The separate exact-`v0.3.2` Linux probe is one-time evidence, not
this gate.

## Done

- Merged the reviewed native-`br` SHAPE/graph amendment as PR #72 at `93c5155`;
  closed superseded wrapper PR #71. Current-tip Codex, Opus, CodeRabbit, bot-gate, the exact
  v0.3.2 probe, and post-merge `./check.sh` all passed. Repointed the durable `skills-dhm`
  reservation to `feat/skills-dhm-native-close-implementation` from clean merged master.
- Pivoted away from the 40-commit repository-side closure wrapper without
  deleting its preserved branch or PR history. Freshly fetched
  `douglaz/skills@master` is exactly `00b6bf0`.
- Checked current upstream `Dicklesworthstone/beads_rust`: release `v0.3.2` is the
  exact required release. The separate disposable Linux probe observes blocked-close
  non-mutation, successful reason+transition-comment, and strict explicit flush/retry; the
  internal atomic transaction/lock boundary and default best-effort auto-flush split are
  source-verified, not inferred from the probe.
  Exact invocation:
  `env -i PATH=/run/current-system/sw/bin:/bin:/usr/bin:/nix/var/nix/profiles/default/bin
  LC_ALL=C TZ=UTC /run/current-system/sw/bin/bash --noprofile --norc
  docs/specs/e3-native-br-v0.3.2-probe.sh /tmp/br-v0.3.2-bin/br
  /tmp/br-v0.3.2-bin/br-0.3.2-linux_x86_64.tar.gz
  /home/master/p/skills-e3-native-br/.beads/issues.jsonl`; re-run clean on 2026-08-23 with
  the `database_path`, DB-absent `version --json`, `in_progress`, scoped-deferred, and
  `show --json` row-payload scenarios and the selector's deferral-counting `list` argv,
  it exits 0 with 3,194 stdout bytes,
  zero stderr bytes, and stdout SHA-256
  `7bce21ba9fd63dc9d4bc1191e21660826dea7aa8440b769017dc4886a6f90685`
  under Bash 5.3.15, Git 2.55.0, Python 3.14.6, Linux 7.1.6 x86_64. Two consecutive clean
  runs produced byte-identical stdout. Like every other measurement here, this pair moves
  with the next probe edit: re-run the recorded invocation rather than trusting it.
  Internal lock/transaction boundaries were separately reviewed in pinned upstream source.
- Generated this reviewed graph amendment in disposable standalone clone
  `/tmp/e3-shape-graph.fgOHwe/repo` from exact `00b6bf0` using the exact v0.3.2 binary:
  import-only, five no-auto description updates (plus the E3 title), and strict flush all
  exited 0 with empty stderr. Base SHA-256 was
  `d4b37bc7de43067c2a700c27286cd6ea380d35c6be27357637c489c4d1b2471d`; generated candidate
  SHA-256 is `7269d4e17a3be4b19f957b4084001e0f529db7453cf667fef84b6e89a85a98eb`.
  Machine comparison proved no added/removed IDs and exactly `skills-dhm`
  title/description/updated_at plus descriptions/updated_at for dta/qmi/rrk/xfd.
- Re-fetched both upstreams immediately before finalization: skills `origin/master` remains
  `00b6bf0dbf5d1575396510923399e87f77539c0c`; beads-rust `origin/main` remains
  `bba322dafba04f713c72627ac8515cb4c285226c`, and `v0.3.2` remains the latest release at
  `4104c31e79bf806f53e2eba0a4cd2ba6c594f8b9`. Post-tag main changes workspace discovery,
  inherited-context/search display, doctor checks, dependency pins, and CI metadata—not the
  pinned native close/strict-flush primitive.
- Started this replacement branch directly from that latest skills master and moved
  the existing `skills-dhm` executor reservation to it.
- The first exact Codex/Opus pass confirmed the native primitive but found the
  linked-worktree redirect, stale Drive state, unowned version pin, runner bypasses,
  and three smaller KISS contradictions. The remediation now requires a standalone
  clone and E1 runners, pins the embedded release commit, records an executable
  one-time probe, removes live reconciliation from the closure path, and maps
  authority-release evidence without inventing a work PR. A focused read-only
  re-review returned PASS with no P0–P2 findings.
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
  --json` schema. That historical plan revision added the edge and then-current
  `br 0.2.19` measurement; the present E3 SHAPE replacement supersedes its closure design.
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
- Started E1's exclusive closure transaction from merged `master`: saved exact
  clean JSONL hash
  `276f9a16e6bc62aa49e1ae5faf494d152b5b32a55d32b81ae6447c5ee99c1ff6`,
  required the pinned typed sync-status fields and matching hash, closed only
  `skills-iog` with auto import/flush disabled, explicitly flushed once, and
  proved the ID set unchanged with only E1 `status`, `closed_at`,
  `close_reason`, and `updated_at` differing. `./check.sh` then passed all 386
  fixtures on the exclusive two-file closure tree under that same recorded
  Bash/Git/`br`/uid environment.

- The complete replacement branch changes exactly five Beads rows. `skills-dhm` changes
  `title`, `description`, and `updated_at`; `skills-qmi`/`skills-rrk` synchronize F2/F2r's
  native post-merge closure handoff through `description`/`updated_at`; `skills-dta`
  (A4b) and `skills-xfd` (B0) link no-change/decision closure to the canonical Step 11
  owner through `description`/`updated_at`. No other row or field differs from master.

- **Adjudicated the E3 SHAPE/KISS scope on 2026-08-23 (user decision, not an inference).**
  (1) LOC budgets cover production implementation only. Tests and fixtures are excluded,
  because a test budget is met by deleting coverage — the opposite of the property the
  budget protects. E3's production budgets stand (350 consumer lines, 450 selector lines,
  `drive-status` collection/`infer()` counted against the first); the 1,600-line
  deterministic-test hard stop is removed from `docs/specs/backlog-execution-plan.md`, and
  `skills/drive/SKILL.md` Guard 2, `skills/drive/references/autonomy-contract.md` § 4, and
  `skills/orchestrating-with-rb-lite/SKILL.md` now say the same thing for future Drive and
  rb-lite tasks. Tests still ride the same review, panel, bots, and gate, and must be
  relevant, maintainable, and mutation-sensitive. Measured against those production stops:
  `select-bead-lanes` is 450 lines — at its stop, not over it, after the deferral-counting
  argv and its three-line rationale — and the consumer set is these twelve paths, named rather
  than summarized so the next reader can re-measure the same set: `skills/drive/SKILL.md`,
  `skills/drive/references/phases.md`, `skills/rb-lite-backlog-drain/SKILL.md`,
  `skills/orchestrating-with-rb-lite/SKILL.md`,
  `skills/orchestrating-with-rb-lite/references/harden-until-clean.md`,
  `docs/adr/0003-bead-closure-stays-post-merge.md`, `README.md`,
  `skills/beads-jsonl-path/SKILL.md`, `skills/beads-jsonl-path/scripts/resolve-beads-jsonl`,
  `skills/drive/scripts/drive-status`, `skills/drive/references/autonomy-contract.md`, and the
  `check.sh` wiring. Re-measured on the current tree, `git diff --numstat origin/master` over
  exactly those twelve reports 1,239 added against 1,033 deleted, net +206 — two embedded locator copies came out of
  `skills/drive/SKILL.md` and `skills/drive/references/phases.md`. It clears 350 on net and
  on the delta the branch leaves behind; counting raw added lines (1,239) instead would not,
  so the reading is recorded here rather than left for the next reader to pick. This figure
  moves with every later production edit, so it is the tree's current number, not a frozen
  one: re-measure the same twelve paths rather than trusting this line.
  (2) The closure block keeps its fourth **internal** classification `generic-unlabeled`.
  It is not a Beads label and is never written to the graph; it names a row the reviewed
  generic selector returned, which by that mode's contract carries no recognized Drive
  metadata. Without it the generic drain can start ordinary unlabeled backlog work and
  cannot finish it. It is checked rather than trusted: the target must carry none of
  `drive-open-issues`, `executor-skills`, `executor-rb-lite`, or `authority-human`, and an
  unlabeled row is still refused under a named lane. The plan and the implementation docs
  and tests now describe exactly that; the coordinator amends the compact `skills-dhm`
  Beads body separately through a reviewed metadata transaction.

- Closed the continuation review findings without broadening E3: the selector now removes
  its private workspace before publishing the buffered routing object; the native-close
  block removes its proof snapshot only after structural proof, exact read-back, and the
  literal review diff all succeed; selected `in_progress` work retains that exact pre-close
  status through resume classification; and `drive-status` reaches its lane helper through
  a trusted Bash bootstrap while accepting only the literal `drive-open-issues` scope.
  One-property production mutants made the corresponding fixtures fail for premature
  selector output, skipped success cleanup, discarded failure recovery state, rejected
  `in_progress` first-entry/resume state, caller-PATH Bash execution, and a delegated
  nonliteral scope. The restored tree passes all focused suites and the 482-fixture gate.

- Closed the second continuation round the same way. Backlog step 2 now reads the selected
  id through step 1's retained pinned prefix with `--no-db`, so the body a task file is
  written from cannot come from a stale cache or a caller-redirected store; the native-close
  cleanup removes its artifacts by name rather than globbing a caller-supplied directory;
  the selector's remaining helper calls contain their own stderr so a refusal stays one
  fixed line; and `drive-status` drops the bootstrap's exported `POSIXLY_CORRECT` instead of
  handing POSIX mode to every `git`/`gh` it runs — which also left the lane block's
  conditional save/restore permanently taking its unset branch, dead weight the convergence
  entry below removes. Reverting each of the four made its new fixture fail.
  Two findings were recorded as rejected in `/tmp/rb-skills-dhm-continuation/challenges-round-2.md`:
  an extra machine-readable scope-membership set (the `Scope-Label:` field already is the
  machine half of `Scope:`), and the LOC-budget/policy edits, which are this task's
  explicitly assigned scope and the user's 2026-08-23 adjudication.

- Closed the third continuation review's three actionable findings. Native close now takes
  `database_path` from the pinned v0.3.2 `where --json`, requires its canonical parent inside
  the standalone clone, records the exact path, and uses it for first-entry and resume
  sidecar classification; the rb-lite overview no longer advertises a bare unpinned `ready`;
  and the `drive-status` bootstrap marker is accepted only under privileged Bash. The new
  tests first failed against the unfixed production paths: native-close reported 34 passed /
  2 failed (outside configured database accepted; custom in-clone cache misclassified),
  drive-status reported 85/1 (direct marker exited 0), and closure-consumers reported 37/1
  (bare overview selector). Restored production then produced 36/0, 86/0, and 38/0. No
  finding was rejected, so round 4 needs no challenge file. Its production accounting is
  superseded by the adjudication figure above, which is re-measured on the current tree and
  therefore the later of the two; the selector was 446 lines then and is 450 now. Both
  production budgets remain within the user-adjudicated limits.

- Closed the fourth continuation review's three demonstrated gaps. Retained-clone entry now
  admits the printed snapshot path before any output redirection: it must be a canonical
  owner-held mode-0700 directory outside the clone, and every known artifact is absent or an
  owner-held regular single-link file. Symlinked directory/artifact, nonregular artifact,
  hard-linked outside alias, inside-worktree directory, and non-private-directory fixtures all
  refuse before one pinned call, and a first entry prints the canonical spelling of the
  directory it just made so a resume can hand back the one form the admission accepts. The exact
  v0.3.2 probe now asserts `where --json.database_path` equals the absolute configured DB while
  absent, proves `version --json` creates no cache in the fresh clone, closes the seeded
  `in_progress` row, and pins its changed-field set to
  `close_reason`, `closed_at`, `comments`, `status`, and `updated_at`. That round measured the
  probe as it then stood at 1,838 stdout bytes / SHA-256 `b150fc7c…`; the probe has since
  gained the scoped-deferred and `show --json` row-payload scenarios and the deferral-counting
  count argv, so the live figure is the one in the Done bullet above.

- Failure-first evidence for those gaps, one production mutation per property, each read for
  the assertion it reddened (native-close is 38/0 restored):
  deleting the retained-directory admission chain → 37/1, "a symlinked retained directory was
  followed; a non-private retained directory reached execution"; deleting the inside-clone
  containment `case` → 37/1, "an inside-worktree retained directory reached execution";
  deleting the per-artifact symlink rejection → 37/1, "a symlinked retained artifact was
  followed"; replacing the artifact single-link requirement with `true` → 37/1, "a hard-linked
  retained artifact alias was overwritten"; deleting the first-entry canonicalization → 37/1,
  "a first entry prints the canonical private directory when its parent spelling is a symlink".
  The nonregular-artifact case is guarded twice (`-f` and the link count), so no single
  mutation reddens it alone. The released `br v0.3.2` binary cannot be mutated, so the probe's
  two new assertions were checked by inverting the expectation instead: a wrong expected
  `database_path` exits 1 with "where did not report the production database_path", and an
  `in_progress` field set expecting an extra `started_at` exits 1 with "unexpected in-progress
  close field set".

- Rejected two round-4 hardening hypotheses under the user-approved cooperative threat model.
  A verified-fd launcher would address only a malicious same-uid process swapping bytes in the
  fresh mode-0700 tool directory between `hash-object` and exec. The procedure does not publish
  that path in routing output, the coordinator reservation excludes cooperative mutation, and
  `resolve-beads-jsonl` revalidates the canonical single-link executable and exact OID immediately
  before every invocation (`skills/beads-jsonl-path/scripts/resolve-beads-jsonl:358-390`); omitting
  a new launcher leaves no correctness, security, or data-loss break inside the admitted model.
  Likewise, an immutable-copy query engine or graph lock would address only an ABA writer that
  violates serialized scheduling, changes the clean tracked JSONL during the bounded reads, and
  restores the exact bytes before the final hash. Every query uses `_sbl_query`'s pinned no-DB
  invocation and selection requires matching pre/post clean path and OID
  (`skills/rb-lite-backlog-drain/scripts/select-bead-lanes:220-283`); omitting another lock leaves
  the supported cooperative serialization contract intact. The detailed dispositions are in
  `/tmp/rb-skills-dhm-continuation/challenges-round-4.md`.

- Recovered the tree after the follow-on implementer timed out at four hours mid-edit. That
  run had kept going past the four demonstrated gaps and added a self-directed review loop's
  worth of extra mechanism: a whole-graph resume divergence engine (`list --status all --all
  --deferred --limit 0`, an enumerated cache ID set, multi-ID `show` in both modes, and a
  hoisted `NC_PROOF`/`nc_same_graph` comparison), a Step-1 selector-admission block duplicating
  what `drive-status` already does, a `drive-status` strict-argument grammar, a resume
  `DB_PRESENT` semantics change, an unwritable-stream guard pair, and a probe `list`/multi-ID
  cache proof. None of that is on the demonstrated-obligation list and each expands the
  reviewed threat model, so the executable content of the closure block is now exactly the
  round-4 reviewed text plus the retained-directory admission above. Its accompanying fixtures
  went with it. `drive-status` keeps only the two cross-file corrections that ADR 0003's
  carry-forward withdrawal made necessary. The reasoning is in
  `/tmp/rb-skills-dhm-recover/challenges-round-1.md`.

- The 64 KiB Tau skill-source bound is the binding constraint on
  `skills/rb-lite-backlog-drain/SKILL.md`: the round-4 reviewed text, reconstructed from the
  round-4 reviewer transcript's own `git diff` of that file, measures 65,507 of the 65,536
  bytes, so the retained-directory admission does not fit beside it verbatim. Step 11's
  explanatory prose and block comments were therefore compressed — every operative claim kept,
  no assertion or invariant weakened — and the redundant `## Contents` navigation list removed.
  The file is 65,430 bytes on the current tree — 106 under the bound — and `install.test`
  proves it, failing the gate on the byte the file goes over. Like the numstat above this is
  a measurement of the tree as it stands, not a fixed property; re-run
  `LC_ALL=C wc -c < skills/rb-lite-backlog-drain/SKILL.md` rather than trusting it. Every
  later edit to it has to buy its space back:
  the scoped-closure check in the last entry below was paid for by compressing the recap
  sentence beside it, not by leaving the file over the limit.

- Closed the recovery review's three new findings without reopening the rejected mechanisms.
  BUILD now states that every bead closure gets its own standalone metadata PR, and LAND
  commits the proven closure before rerunning typed selection: a positive unresolved count
  retains the nonterminal routed phase, while only exact zero writes `DONE` with a pending
  metadata PR. Two focused consumer assertions failed against the prior text and the restored
  suite passes 41/0. The C1, C3, and F2r fixture budgets were restored because those rows are
  outside E3's ownership; E3's production-only budget and the reusable Drive/rb-lite budget
  policy remain unchanged.

- Closed three review findings and refused a fourth with measurements. (1) `--run-br
  --pinned-br PATH OID …` left the prefix unconsumed, so the admission owner fell through to
  its ordinary PATH lookup and executed the caller's unadmitted `br` with the prefix as argv
  — reproduced against a sentinel on PATH, `rc=9`, no diagnostic. A prefix in the second
  position now refuses, and the two fixtures that pin it fail without the guard. (2) Scoped
  closure required only the exact lane label, so a target carrying that lane but not
  `drive-open-issues` — a row scoped selection never returns — was closed; the red run shows
  the unfixed block mutating that row's status. (3) The recorded skill byte count and the
  twelve-path numstat were both stale and are re-measured above. (4) Rejected "include
  deferred beads in `unresolved_count`": measured on the installed `br` 0.2.19, a bead
  deferred the way `br` defers (`update --defer <date>`) keeps `status: open`, so it is
  already inside `list --status open --all` and outside `ready` — exactly the empty-lanes,
  positive-unresolved GRAPH case `skills/drive/references/phases.md` describes. The
  finding's premise, a `deferred` *status*, is one arbitrary spelling of a free-text field:
  the same `br` accepted `update --status bogusstatus`. Details in
  `/tmp/rb-skills-dhm-final-two/challenges-round-2.md`. **The conclusion held but that step
  did not**: `--deferred` is a filter the `status` value says nothing about, and a later
  reviewer was right to say so. The `list` membership is now measured directly on the pinned
  release rather than inferred, and every count query carries the flag — see the last entry
  below.

- The lifecycle round's first pass closed the four preceding findings; all four are verified
  present on this tree. Metadata branches record `HARDEN` from their first commit until the
  PR merges, never start the next bead there, and only a refreshed post-merge checkout may
  record `BUILD`, `GRAPH`, or `DONE` (`skills/drive/references/phases.md:659-669`). Native
  close publishes `CLOSURE_COMPLETE` before it removes the private snapshot best-effort, so
  an interruption after that line leaves the captured completion authoritative and one
  before it follows the documented resume-or-abandon matrix: incomplete snapshots and
  retained pre-close states abandon the clone and restart fresh; eligible closed states
  resume there. There is no recovery marker or new API
  (`skills/rb-lite-backlog-drain/SKILL.md:463-468,839-847`). `--pinned-br` is refused anywhere after
  its one valid leading position, scanned across all remaining argv
  (`skills/beads-jsonl-path/scripts/resolve-beads-jsonl:62-67`). And the retained probe
  proves `version --json` creates no cache inside the DB-absent workspace
  (`VERSION_NO_DB_RC=0 STDERR_BYTES=0 DB=absent`). That pass's failure-first evidence is in
  its own transcript; it was not re-run here.

- Closed the lifecycle review round itself. (1) Accepted the stale-record finding: the
  twelve-path numstat and the `skills/rb-lite-backlog-drain/SKILL.md` byte count above are
  re-measured on this tree, each now states in the line itself that it moves with the next
  production edit, and the round-3 entry no longer implies the adjudication figure is the
  older of the two. (2) Rejected "refuse generic routing while a Drive scope is active". The
  observation is correct — generic mode does not read `DRIVE.md` — but that is the specified
  behaviour: `docs/specs/backlog-execution-plan.md:1577-1580` defines generic mode's refusal
  condition exhaustively as the unresolved-row check, an earlier round already reverted
  exactly this hoist with a red run, `skills/drive/scripts/drive-status:188` hard-codes
  `--scoped` so it can never reach generic mode, and refusing on a declared `Scope-Label:`
  would make a generic drain
  impossible in every repository that keeps the committed record Drive is designed to keep.
  The one real gap was documentary: `skills/rb-lite-backlog-drain/SKILL.md:103-105` now says
  that the row check is the whole of what generic mode enforces and that choosing the mode is
  the caller's assertion. Details in
  `/tmp/rb-skills-dhm-lifecycle/challenges-round-2.md`.

- Closed the next lifecycle review without expanding native-close recovery. The real
  durability gap is now finite: after the closure metadata PR merges, a nonterminal phase
  rides the next normal reviewed branch, while zero unresolved gets one status-only PR
  created from refreshed default. That PR carries no bead closure, routes `HARDEN` until
  merge through the existing `drive-status` rule, and leaves durable `DONE` on default.
  The consumer assertion first exited 1 at 41/1 against the missing procedure, then 0 at
  42/0 with the procedure present. The proposed whole-cache pre-flush engine and cache-file
  symlink/hard-link admission were rejected as repeat hardening outside the exclusive
  cooperative clone model; neither can publish `CLOSURE_COMPLETE`, and the complete retained
  pre-close graph survives for repair. Detailed dispositions are in
  `/tmp/rb-skills-dhm-lifecycle/challenges-round-3.md`. Focused restored suites exit 0 at
  146 resolver, 40 native-close, 90 drive-status, and 42 closure-consumer fixtures. The exact
  recorded v0.3.2 probe was also rerun this round and exited 0 with zero stderr bytes at the
  then-current 1,838-byte stdout, including `VERSION_NO_DB_RC=0 STDERR_BYTES=0 DB=absent`.

- Closed the next lifecycle round: three findings implemented, two hypotheses rejected
  without new mechanism.
  (1) `drive-status`'s outer bootstrap now clears the loader namespace — `LD_*`, `DYLD_*`,
  `LIBPATH`, `SHLIB_PATH`, `GCONV_PATH`, `LOCPATH` — beside the shell-startup one it already
  cleared. It was the only script on this authorization path that did not: `resolve-beads-jsonl`,
  `git-clean`, and `select-bead-lanes` all clear exactly that list, and the selector's own
  `/bin/sh` is one of the processes launched from here, so it did its clearing only after
  inheriting whatever the caller set. Its own interpreter stays the caller obligation
  `beads-jsonl-path` § Resolve before writing states; the comment beside it now says which half
  is discharged and which is not. The new fixture plants eighteen sentinel values, swaps the
  companion for an admissible stub that dumps the environment it was exec'd with, and reads
  that — no object is built and no worktree code runs. Deleting the added list reddens it alone
  (90/1, "18 survived: LD_PRELOAD …"); restored, the suite is 91/0.
  (2) `README.md`'s one-line `drive-status` summary no longer advertises bead counts: it records
  that the no-argument form reports every count `n/a` because it makes no `br` call, and that the
  typed `--select-bead-lanes-json` mode is the one door onto authoritative Beads routing —
  matching `skills/drive/SKILL.md:118-121` and the compatibility section.
  (3) "Deferred beads are invisible to every selector query, so a deferred-only backlog reports
  DONE" was first measured, then closed in argv by user adjudication on 2026-08-23. The probe
  seeds a seventh scoped row, defers it the way this release defers (`update --defer
  2099-01-01`), and issues the selector's own `list` argv both with and without the flag. The
  row is genuinely deferred — absent from lane `ready` (1), returned by
  `ready --include-deferred` (2) — and on this build the flag changes neither count query at
  all (`list-open` 4 = `list-open-deferred` 4, `progress-all` 1 = `progress-all-deferred` 1).
  Every `list` that feeds `unresolved_count` nonetheless now carries `--deferred` in both
  scoped and generic mode: deferred open work is inside those counts on this pinned build
  either way, so a deferred-only backlog cannot report `DONE`. The two `--status in_progress`
  forms take the flag together and the probe pins their exact ID arrays as a partition, so a
  one-sided flag fails there rather than at the selector's own partition check. `ready`
  deliberately keeps no `--include-deferred`: a deferred row is counted, never routed. Since
  the binary cannot be mutated, each probe expectation was inverted one property at a time —
  expecting the progress control to disagree exits 1 with "unexpected deferred-row
  visibility", dropping a lane from the partition union exits 1 with "the lane in-progress
  arrays do not partition the global one", and mis-pinning the lane in-progress count exits 1
  with "unexpected selector envelope: progress-skills-deferred". The consumer suite asserts the
  flag on every parsed `list` in both modes: removing it from the scoped open query alone
  reddens only the scoped assertion (42/1), and from the generic one alone only the generic
  assertion (42/1); restored, the suite is 43/0.
  (4) Rejected "encode Drive scope membership beyond `Scope-Label:`". `**Scope-Label:**` is the
  machine-readable declaration of actual Drive membership, parsed with Bash builtins so no
  caller-PATH tool can manufacture it; the `Scope:` prose beside it is descriptive. For this
  Drive they agree exactly, measured rather than asserted: every row in `.beads/issues.jsonl`
  carries `drive-open-issues` — 33 of 33 — and those 33 execution beads are the whole graph for
  the declared #30–#66 set. The 29 in the `Scope:` line counts GitHub issues, not rows;
  `docs/specs/backlog-execution-plan.md:33-35` keeps those registers separate ("GitHub remains
  the external source of issue identity; Beads holds the executable dependency graph"), so one
  issue may carry several beads. The label selects no row outside the declared scope.
  Implementing the finding means inventing a second subset language and parser, then
  reconciling two sources that can disagree; the "unrelated bead" it describes is one a human
  labelled in, and un-labelling it is one command.
  (5) Rejected "refuse closure when the selected bead's generation has drifted", after checking
  the concrete paths rather than the threat model. The cooperative model reserves the selected
  bead — one bead at a time (`skills/rb-lite-backlog-drain/SKILL.md:85-86`), and no in-contract
  writer mutates the graph across its work and closure interval. The drain's twelve steps issue
  exactly one graph mutation — step 11's `close` plus `sync --flush-only`
  (`skills/rb-lite-backlog-drain/SKILL.md:652-657`); steps 1–10 read only. `harden-until-clean`
  mints beads in § 3 and drains them in § 4 under "Do not start bead B's run while bead A is
  open" (`skills/orchestrating-with-rb-lite/references/harden-until-clean.md:620-621`). The
  `update --description` guidance is addressed to the bead-writing skills, which are separate
  phases. And first-entry closure resolves the **clean** tracked JSONL with no `--allow-dirty`
  (`skills/rb-lite-backlog-drain/SKILL.md:617-618`), so the only body it can certify against is
  one committed and clean, never a mid-flight edit. The one in-contract amendment to a reserved
  row is the coordinator's reviewed metadata transaction, which exists to make the body match
  the adjudicated work — a generation check would refuse the closure it is meant to enable.
  Detailed dispositions are in `/tmp/rb-skills-dhm-lifecycle/challenges-round-4.md` and
  `challenges-round-5.md` beside it, the latter recording the adjudicated reversal on (3).
  Restored focused suites exit 0 at 146 resolver, 40 native-close, 91 drive-status, and 43
  closure-consumer fixtures, and the re-measured probe exited 0 with the then-current 2,204
  stdout bytes and zero stderr bytes across two byte-identical consecutive runs. The whole `./check.sh` gate, run
  through the `AGENTS.md` supervisor rather than a pipeline, exits 0 with zero stderr bytes at
  146 resolver, 55 install, 124 bot-gate, 91 drive-status, 40 native-close, and 43
  closure-consumer fixtures.

- Re-verified the round rather than re-implementing it: the three adjudicated fixes and both
  rejections above are present on this tree, and every number recorded here still measures as
  recorded — the exact probe exited 0 at the then-current 2,204 stdout bytes, zero stderr
  bytes, stdout SHA-256
  `36fce505bba6544faff3a8c3a3659900c1812feffb2e38e0e2a3e9c2fe9bdbe3`; the selector is 450
  lines; `skills/rb-lite-backlog-drain/SKILL.md` is 65,381 bytes; the twelve-path numstat is
  1,241 added / 1,033 deleted, net +208; and `./check.sh` under the `AGENTS.md` supervisor
  exits `EXIT=0` with zero stderr bytes at 146 resolver, 55 install, 124 bot-gate, 91
  drive-status, 40 native-close, and 43 closure-consumer fixtures. Every `file:line` citation
  in this record was opened against the current tree; one no longer named its claim.
  `skills/drive/scripts/drive-status:174` is the companion-containment `case`, not the line
  that fixes the mode; the `exec … --scoped` hard-code is at `:188`. The generic-routing
  rejection now cites `:188` and says what that line does. Anchors move like the counts do —
  re-open them rather than trusting them.

- Re-ran the same measurements a round later and corrected the one number that did not hold.
  Unchanged: the exact probe exited 0 at the then-current 2,204 stdout bytes, zero stderr
  bytes, stdout SHA-256
  `36fce505bba6544faff3a8c3a3659900c1812feffb2e38e0e2a3e9c2fe9bdbe3` — byte-identical to the
  retained round-7 stdout; the selector is 450 lines; `rb-lite-backlog-drain/SKILL.md` is
  65,381 bytes; the twelve-path numstat is 1,241 added / 1,033 deleted, net +208; the focused
  suites are 146 resolver, 91 drive-status, 40 native-close, 43 closure-consumer, all 0 failed;
  `./check.sh` under the `AGENTS.md` supervisor exits `EXIT=0` with zero stderr bytes at
  146/55/124/91/40/43; and all four trust-path scripts (`drive-status`, `resolve-beads-jsonl`,
  `git-clean`, `select-bead-lanes`) clear a byte-identical eighteen-variable loader list.
  Corrected: rejection (4) called the scope a "29-row" set. The store holds 33 rows, all 33
  labelled `drive-open-issues` — 29 is the GitHub issue count from the `Scope:` line, and the
  plan keeps issue identity and graph rows in separate registers. The rejection now states the
  measured membership, which is what makes it exact rather than approximately right. Counting
  the wrong register is how a scope claim goes stale without anyone editing it.

- Closed the deferred round's three findings, two of them by measuring what had been argued.
  (1) The selector's own comment claimed `--deferred` was what kept deferred open work inside
  `unresolved_count` — refuted by the controls in the same tree, which measure the flag as a
  no-op on both count queries. Since the selector re-proves exact `v0.3.2` before any query,
  it cannot be forward-insurance for another release either. The argv is kept, because it is
  what the probe pins and what the three lane `in_progress` forms are measured with, but the
  claim beside it now states the measurement: the deferred row is inside
  `list --status open --all` with the flag and without it, so a deferred-only backlog is
  GRAPH either way. `select-bead-lanes:255-257`, the consumer suite's assertion rationale at
  `closure-consumers.test:489-493`, and the plan and this record now all say that instead of
  attributing the property to the flag.
  (2) Step 11 routes on three `show --json` fields — `labels` in the pre-close preflight,
  `comments[].text` and `close_reason` in the resume classifier in BOTH `--no-db` and cache
  mode, `close_reason` in the read-back — and the probe pinned only `[0].status`. Their shape
  came from a fixture stub that returns whole JSONL rows by construction. The probe now
  creates an eighth, deliberately unlabelled row and pins the payload itself in every mode a
  decision reads it from. Both hypothesized failures measured **false**: the closed row
  carries `comments` and `close_reason`, with the exact reason and the order-independent
  three-text comment set, identically in `--no-db` and cache mode — so the resume matrix's two
  closed states are reachable, not dead. What the measurement did change is the reading of
  the absence-tolerant reads: this release **omits** `labels`, `comments`, and `close_reason`
  rather than emitting them empty, so an unlabelled row is proved by the missing key. The
  generic lane's "carries no recognized Drive label" gate is therefore measuring a real
  absence, and requiring the key — the obvious "hardening" — would refuse every genuinely
  unlabelled row. The binary cannot be mutated, so each new expectation was inverted one
  property at a time: the unlabelled row's `labels`-key presence and the closed row's
  `close_reason` and comment set each exit 1 with "unexpected show --json row payload", and
  pointing the cache-mode read at a different bead exits 1 with "show --json did not return
  exactly the requested row: show-closed-db".
  (3) `skills/drive/evals/trigger-evals.json` had its `fixture` and `measurement_note`
  rewritten to describe typed lane selection while `last_measured` stayed at 2026-08-10 —
  before this branch existed, and before `drive-status` stopped deriving the phase from
  unpinned `br` counts. Both strings are restored verbatim as the version-scoped record of
  what was actually run, and a new `measurement_scope` says plainly that every rate below it
  is UNMEASURED against the current routing path, with the date to move when someone re-runs.
  A fourth change was written and then removed rather than kept: a paragraph mirroring (2)
  into `skills/rb-lite-backlog-drain/SKILL.md` took that file to 65,926 bytes, past
  `install.test`'s 64 KiB Tau skill-source gate at 65,536 — the gate caught it, and the
  measurement lives in the probe and `docs/specs/backlog-execution-plan.md` instead.
  Measured after all of it: the extended probe exits 0 with 3,194 stdout bytes, zero stderr
  bytes, and stdout SHA-256
  `7bce21ba9fd63dc9d4bc1191e21660826dea7aa8440b769017dc4886a6f90685`; the selector is still
  450 lines; `skills/rb-lite-backlog-drain/SKILL.md` is still 65,381 bytes; the twelve-path
  numstat is still 1,241 added / 1,033 deleted, net +208; the focused suites are 146 resolver,
  91 drive-status, 40 native-close, 43 closure-consumer, all 0 failed; and `./check.sh` under
  the `AGENTS.md` supervisor exits `EXIT=0` with zero stderr bytes at 146/55/124/91/40/43.
  The retained dispositions are in `/tmp/rb-skills-dhm-deferred/challenges-round-3.md`.

- Converged the tree for handoff: two adjudicated changes plus one accepted review finding.
  (1) The interruption guarantee in `skills/rb-lite-backlog-drain/SKILL.md:463-468` promises
  recovery through the documented resume-or-abandon matrix rather than a same-clone resume —
  an incomplete printed snapshot or a retained pre-close state abandons this clone and
  restarts fresh, and only the eligible closed states resume here. The matrix itself is
  unchanged; `docs/specs/backlog-execution-plan.md:1455-1458` and the lifecycle entry above
  carry the same wording. (2) `skills/drive/evals/trigger-evals.json` is restored byte-for-byte
  to `origin/master`: the path was outside the authorized E3 set, so item (3) of the entry
  directly above describes a `measurement_scope` key this tree no longer carries. (3) The
  lane block in `skills/drive/scripts/drive-status` saved and conditionally restored
  `POSIXLY_CORRECT` after line 62 had already unset it on every path into that block, so the
  saved marker was always empty and the restore branch was unreachable — verified on the file,
  which assigns the variable nowhere between the two. The branch is gone, its unset is now
  unconditional, and the two records that claimed the unset made that save/restore *live* are
  corrected here and in the script comment. Both forms are byte-identical before and after the
  removal — same directory, same argv, `--json` and lane mode, stdout, stderr, and exit.
  The six rejected findings are recorded in
  `/tmp/rb-skills-dhm-convergence/challenges-round-1.md`. Measured after all of it: the
  selector is still 450 lines; `skills/rb-lite-backlog-drain/SKILL.md` is 65,430 bytes; the
  twelve-path numstat is 1,239 added / 1,033 deleted, net +206; the focused suites are 146
  resolver, 91 drive-status, 41 native-close, 43 closure-consumers, all 0 failed with zero
  stderr bytes; and `./check.sh` under the `AGENTS.md` supervisor exits `EXIT=0` with zero
  stderr bytes at 146/55/124/91/41/43.

## Now

Preserve the verified uncommitted E3 delta for coordinator handoff. It pins native
`br v0.3.2` identity, migrates the four live consumers and ADR 0003, adds the bounded E1
pinned prefix and shared selector, and retains the one-time exact-release evidence. Keep
the `skills-dhm` reservation on this branch through the work PR and closure metadata PR.

## Next

Land the E3 work PR, then close E3 through the standalone-clone native metadata procedure.
Merge that closure PR and refresh clean master before any normal scheduler read; surface the
newly ready B0 authority decision before automated routing resumes.

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
