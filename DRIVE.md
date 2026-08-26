# DRIVE — execute the open skills safety and correctness backlog

**Scope:** exactly the 29 GitHub issues in the #30–#66 set enumerated by
`docs/specs/backlog-execution-plan.md`; the Beads graph is the only work. Current focus is
the E3a/E3b split replacing E3 (`skills-dhm`). GitHub #67 is deliberately OUT of this scope — it postdates the set and
is a bounded follow-on after F1, not a silent expansion of a fixed 29-issue drive.
**Scope-Label:** `drive-open-issues`
**Phase:** SHAPE · **Bead:** E3 split · **Branch:** `shape/e3a-e3b-split`
**Pending:** —
**Gate:** `./check.sh` · repository-gate environment: GNU Bash 5.3.15 (non-POSIX),
Git 2.55.0, installed `br` 0.2.19; last green 2026-08-25 on `master` at `935c3ac`
(139 resolve-beads-jsonl, 53 installer, 124 bot-gate, and 93 drive-status fixtures; exit 0). The
separate exact-`v0.3.2` Linux probe is one-time evidence, not this gate.

## Done

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
  /home/master/p/skills-e3-native-br/.beads/issues.jsonl`; exit 0, 1,574 stdout bytes, zero
  stderr bytes under Bash 5.3.15, Git 2.55.0, Python 3.14.6, Linux 7.1.6 x86_64.
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

## Now

SHAPE is splitting E3 into E3a exact `br` admission/typed lane selection and E3b
native closure/consumers. E3b retains `skills-dhm` and its 15 final-barrier
dependents; graph transfer will create P0 `executor-skills` E3a (closed E1
`skills-iog`, issue #65 fragment `#plan-row-e3a`) and make `skills-dhm` depend on
it. The 510 estimate is retired: it was neither reused nor divided.

- E3a fresh baseline/budget: resolver prefix/order/validation/dispatch 42;
  git-clean admit-executable 16; selector trusted entry/argv 34;
  sibling/temp/cleanup 24; identity/stable locator/OID helpers 32; query capture
  22; scoped validation/output 70; generic validation/output 42; final stream
  handling 14; drive-status no-br/inference 19; API/consumer/compatibility/plan/
  gate wiring 82 = 397 production lines; exact budget 1,191.
- E3b fresh baseline/budget: privileged clean-Bash entry 27;
  input/standalone/override/evidence guards 23; pinned execution/identity/dynamic
  where helpers 31; snapshot/import/target preflight 29; native close + strict
  flush 9; strict proof/no-DB show/literal diff 59; retained-clone resume
  classifier 37; Step-11 contract 28; three consumer amendments 9; versioned ADR
  15; E1 consumer note 3; concise plan/global/table update 15; gate wiring 1 =
  286 production lines; exact budget 858.

## Next

Transition reviewed spec → graph transfer. Create E3a only, transfer its E1 edge
and retained `skills-dhm`→E3a edge, leave all 15 existing `skills-dhm` dependents
unchanged, then confirm E3a alone is ready. Do not edit Beads during this SHAPE
pass or start normal scheduling between E3a and E3b.

## Standing decisions

- **Tests are not capped** (2026-08-23, reconfirmed 2026-08-25 — user decision, not an
  inference). LOC budgets cover production implementation only. A budget that counts tests
  is satisfied by deleting coverage, which is the opposite of the property the budget
  protects. Test and fixture paths are an explicit unbudgeted exemption, never a second
  budgeted class. Tests still ride the same review, panel, bots, and gate, and must be
  relevant, maintainable, and mutation-sensitive — they are simply not bounded by a number.
  Encoded in `skills/drive/SKILL.md` Guard 2, `references/autonomy-contract.md` § 4,
  rb-lite's `--budget-exclude` defaults, F3 (`skills-equ`), and this plan's F3 section.
- **A supplied rb-lite reviewers file must carry a skeptic** (2026-08-25). rb-lite 0.3.0's
  built-in panel includes a skeptical reviewer that reports over-specification only, and
  `--reviewers-file` replaces that panel wholesale. C2 (`skills-47i`) is amended to require
  one in its generated file, since otherwise building C2 would remove the loop's only
  counter-pressure against scope creep.

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
