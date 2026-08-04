# douglaz/skills

Shared agent skills for [Claude Code](https://claude.com/claude-code) and
[OpenAI Codex](https://github.com/openai/codex). The repo collects the
workflows I reach for most: multi-reviewer review loops, beads planning, rb-lite
orchestration, Lightning ops, code simplification, and writing checks.

Each skill sticks to the shared agent-skills format, so the same source can be
installed into both tools.

## Available skills

### drive

The meta-skill: it drives a project through its whole lifecycle and sequences the
other skills. It implements nothing itself — it works out which phase the project
is in, runs the right specialist skill for that phase, demands evidence that the
phase actually closed, records the transition in `DRIVE.md`, and enters the next
phase without waiting to be told.

```text
/drive take the M1b milestone from spec to merged
/drive drain the ready beads
/drive                          # orient only: where are we, what's next
```

The phase machine, and the skill each phase delegates to:

| Phase | Skill | Exit gate |
|---|---|---|
| SHAPE | `planning-workflow`, `grill-with-docs`, `spec` | spec committed, codex xhigh clean of P0/P1 |
| GRAPH | `plan-to-beads-transfer` → `bead-polish-loop` → `second-model-bead-audit` | audit PASS, a scoped `br ready` bead exists |
| BUILD | `orchestrating-with-rb-lite` | rb-lite clean **and** you ran the gate yourself |
| PROVE | `testing-with-rb-lite` | the gate ran green at a real exit code |
| HARDEN | `multi-reviewer-loop` + a final pinned `codex review --base` | `multi-reviewer-loop` reports `CLEAN` (reviewers **and** consistency pass), then the cleared SHA is recorded |
| LAND | `pr-with-codex-bot-review` | no evidence of a pending bot round on the tip, base still an ancestor of it, squash-merged; closure lands via a reviewed path |
| DONE | — | the scope is empty and any `Pending:` closure PR has merged |

Four guards automate what previously took a human nudge: **evidence** (run the real
gate, never piped through `tail`, make new tests fail first), **scope budget** (a
file-lock and a do-NOT-build list up front, hard brake at 2× budget or round 4),
**transitions fire their own gates** (commit/push/review are part of the transition,
not a separate request), and **durable state** split by lifetime — `DRIVE.md` at the repo
root carries the committed narrative, while per-checkout facts (which tree the panel
cleared) live under the git dir and are correctly absent from a fresh clone.

LAND is *derived*, never recorded: a commit cannot honestly say its own SHA was reviewed,
because writing the record changes the SHA. `Phase:` never records LAND — it is computed
from `cleared == tip`, the current base still being the one the panel reviewed, that base
still being fresh enough that the squash lands the reviewed tree, and a clean worktree — post-clearance edits are not in the commit a merge would take. See `docs/adr/` for that decision and two others.

A short stop-list still ends a turn. It does not cover landing the drive's own work —
its branch, its PR, `--force-with-lease` on that branch, the squash-merge once gates are
green — which the goal authorizes. It covers anything leaving the repo or unrecoverable: a design
fork on a money/consensus/data-loss path, the cross-cutting tell (a second review round
adding another consumer of the same concept), a blown scope budget, or a goal that
turned out to be wrong. The rationale for each rule, with the transcript evidence
behind it, is in `references/autonomy-contract.md`.

Ships with `scripts/drive-status`, a read-only detector that prints branch, gate command,
bead counts, PR state, specs, the cleared SHA, and an inferred phase (`--json` for
scripting). It also flags the failures that are otherwise invisible: a base that advanced
after clearance (a squash merge would then land a tree nobody reviewed, while every SHA
still matches), and a `DONE` record that names a closure PR — it reports `WAITING_FOR_MERGE` and hands
you the number to query, deliberately not calling the forge itself.

### agents-md

Maintains one managed block in a repo's `AGENTS.md` carrying the portable rules
that keep an agent honest — verified edits, unpiped gates, evidence instead of
assertion — and delegates the beads workflow to `br agents`. Everything outside
the markers stays human-owned and untouched.

```text
/agents-md              # add or refresh the block in this repo
/agents-md --check      # report what is there without writing
```

`AGENTS.md` is the only place a working agreement travels: it is committed, so it
reaches every clone and every machine, and both Claude Code and Codex read it. A
lesson recorded in a local config is lost the moment someone works on another box.

Rules earn a place in the block only if they apply to essentially any repo, an
agent gets them wrong by default, and you can name the incident that produced
them — it is copied everywhere, so bloat gets the whole thing ignored.

### multi-reviewer-loop

Runs an iterative multi-reviewer review/fix/re-review loop on your current branch. Detects a review base, runs two reviewers in parallel — `codex review` (`gpt-5.6-sol` at `xhigh`) and Claude Fable at high effort — merges and dedupes their findings, treats findings as credible until disproven, fixes accepted items, validates the changed code, and repeats until both reviewers are clean on the current diff. A final consistency pass then reads the changed files — plus the untouched docs that describe them — as one artifact and asks whether they still agree — the class of defect a diff-scoped loop structurally cannot see, such as a summary table that no longer matches the behaviour it describes, or a rule in one file that forbids what another file requires. `CLEAN` requires both.

```
/multi-reviewer-loop              # up to 6 passes (default), both reviewers
/multi-reviewer-loop 3            # up to 3 passes
/multi-reviewer-loop 5 focus on error handling  # 5 passes, focused review
/multi-reviewer-loop --reviewers codex          # pin a single reviewer
```

Two reviewers with different scopes — codex sees the diff, Fable reads out into the repo — catch more than either alone, and their disagreements are the highest-signal moments in the loop. Findings both raise get fixed first; a finding only one raises still gets the full evidence bar, because the other reviewer's silence is not counter-evidence. If one reviewer is unavailable the loop runs degraded and says so; it never reports a one-reviewer pass as clean.

Best fit: Claude Code explicit invocation. This skill shells out to both `codex`
and `claude` and is most natural when run as a slash command from Claude Code.

Renamed from `codex-review-loop` when the second reviewer landed. Rerun
`install.sh` to drop the stale symlink.

### complexity-reducer

Reduces code complexity by deleting, collapsing, inlining, and simplifying code
while preserving behavior. Rust-first, with guidance that also applies to Bash
and other languages.

Claude Code:

```text
/complexity-reducer simplify this Rust module without changing behavior
```

Codex:

```text
Use the complexity-reducer skill to reduce ceremony in this code while preserving behavior.
```

### voice-dna

Checks and rewrites public-facing prose against a direct, human writing style:
short paragraphs, concrete verbs, contractions, and no AI-shaped filler.

Claude Code:

```text
/voice-dna check this README section
```

Codex:

```text
Use the voice-dna skill to check this announcement draft.
```

### lnd-payments

Operates a Kubernetes-hosted lnd node through `kubectl exec` and `lncli` for
Lightning invoice decode, receive, pay dry-run/send, watch, and payment tracking
workflows. Node-specific selectors live outside the public skill in XDG config
or environment variables.

Claude Code:

```text
/lnd-payments pay this invoice lnbc...
```

Codex:

```text
Use the lnd-payments skill to decode this invoice and dry-run payment.
```

### plan-to-beads-transfer

Translates a stable spec, PRD, or markdown plan into actual `br` beads with
self-contained descriptions, explicit dependencies, and verification
obligations.

Claude Code:

```text
/plan-to-beads-transfer docs/PLAN.md
```

Codex:

```text
Use the plan-to-beads-transfer skill on docs/PLAN.md.
```

### bead-polish-loop

Runs repeated bead-graph refinement rounds for coverage, deduplication,
dependency repair, sizing, priority, and verification completeness until the
graph converges. For every non-trivial graph, normal completion runs the
`second-model-bead-audit` reviewer panel before implementation; a failed or
conditional audit feeds accepted findings back into another focused polish round.

Claude Code:

```text
/bead-polish-loop
```

Codex:

```text
Use the bead-polish-loop skill on the current bead graph.
```

### second-model-bead-audit

Provides the default final audit of a polished bead graph against the plan, with
blocking findings first and exact bead-level fixes when obvious. It runs a
read-only reviewer panel in parallel — Codex `gpt-5.6-sol` at `xhigh` plus Claude
Fable at high effort — then merges findings as `BOTH`, `CODEX`, `FABLE`, or
`CONFLICT` and reconciles them against the plan and graph. One unavailable
reviewer produces a clearly labeled degraded audit; with neither external
reviewer available, the audit is blocked rather than silently replaced by a
self-review.

Claude Code:

```text
/second-model-bead-audit docs/PLAN.md
/second-model-bead-audit docs/PLAN.md --reviewers fable  # explicitly pin one reviewer
```

Codex:

```text
Use the second-model-bead-audit skill and give me a launch verdict.
```

### testing-with-rb-lite

Uses `rb-lite` to **author** a test or verification gate, then independently **runs**
it — because rb-lite's reviewer panel reads the test's source and never executes the
gate, so a clean run means "no reviewer objected", not "the test passes". Reach for it
when the deliverable *is* the test: a smoke, an integration or property test, or a live
end-to-end gate that has to go green against real infrastructure.

Claude Code:

```text
/testing-with-rb-lite write a smoke test that proves the retry budget holds
```

Codex:

```text
Use the testing-with-rb-lite skill to build and verify an end-to-end gate for this flow.
```

Front-loads the six ways a test reports PASS without proving anything — stale binaries,
substring assertions, assertion-weakening to force green, fake setup, false PASS on a
hang, and editing the code under test — as hard constraints in the task file, then checks
for each in the result. A test that falsely reports PASS is worse than no test.

### orchestrating-with-rb-lite

Uses `rb-lite` as the lightweight implement/review loop for self-contained work
on the current repo. It also drains an existing `br` backlog by running one
focused rb-lite loop per ready bead, with one branch, one PR, one squash merge,
and one bead closure per item.

Claude Code:

```text
/orchestrating-with-rb-lite review and fix this branch before PR
/orchestrating-with-rb-lite drain the ready br backlog with rb-lite
```

Codex:

```text
Use the orchestrating-with-rb-lite skill to run rb-lite until this branch is clean.
Use the orchestrating-with-rb-lite skill to clear the ready br backlog one bead at a time.
```

It also runs a **harden-until-clean drive**: a codex + Claude Fable panel
reviews the whole branch, every real finding becomes a bead labeled with the
reviewer that found it, the beads drain one rb-lite run at a time, and the panel
runs again over everything that merged — until both reviewers are clean.

```text
/orchestrating-with-rb-lite harden this branch against main until review is clean
```

Best fit: you want implementation/review convergence without a durable
multi-stage project. For backlog draining, the durable state comes from `br`,
Git branches, PRs, and CI; rb-lite only handles one bead's inner loop at a
time. Reach for the harden-until-clean drive when you want durable,
bead-tracked regression sweeps with one PR per finding instead of the
inline-edit style of `multi-reviewer-loop`.

(This mode replaces the retired `codex-review-beads-ralph-loop` skill, which
drove the same loop through `ralph-burning`.)

### pr-with-codex-bot-review

Opens and lands GitHub pull requests through the `chatgpt-codex-connector`
review bot, with guidance for CodeRabbit when it is configured. Covers PR body
drafting, local gates, a local Claude Fable pre-review before push so the bots
review the good version of the diff, bot re-triggers, review comment handling,
force-push amends, and squash-merge cleanup.

Claude Code:

```text
/pr-with-codex-bot-review ship this branch
```

Codex:

```text
Use the pr-with-codex-bot-review skill to open this PR and handle the bot review.
```

Best fit: you want a GitHub PR carried from local changes through review-bot
feedback and merge.

Ships with `scripts/bot-gate`, which reports whether anything says the review bots are
still working on the *current* tip, or have left findings nobody dispositioned: a submitted
review naming this tip, no `eyes` reaction newer than it, and zero unresolved threads from
either gated bot. It fails closed on any API error or missing tool — exit 0, 1 blocked,
2 usage, 3 cannot determine, and "cannot determine" is never clearance.

CodeRabbit's status is printed and ignored. It is a PR-level signal, not evidence about a
tree: measured on this repo, CodeRabbit stamped `success`/"Review completed" on a commit
75 seconds after it was pushed while its own reviews were paused. Its review threads still
gate; its green does not.

Exit 0 says `NO_PENDING_EVIDENCE`, not "cleared", and the distinction is the point:
neither bot emits a round-terminal signal, so every conclusion is drawn from absence over a
bounded observation window, which the JSON reports both ends of. It is a stop sign, not a
green light — where the forge can enforce a rule server-side, put it there instead.
`scripts/bot-gate.test` exercises it against a stubbed `gh` — forty-five cases, each one
a defect found in review, each shown to go red against the real bug.

### galtland-architecture

Applies or reviews a Rust async architecture: platform-split crates (a
wasm-buildable core with transports, spawners, and storage injected) plus
channel-based actor/command concurrency — command enums whose variants carry
`oneshot` replies, a single event loop owning `!Sync` state, pending-id maps
bridging callback APIs to async/await, two-tier event fan-out with admission
control, and per-resource daemon actors with panic-safe lifecycles. Has an
apply mode and a review mode with a checklist.

Claude Code:

```text
/galtland-architecture design the concurrency for this daemon
/galtland-architecture review the architecture of this workspace
```

Codex:

```text
Use the galtland-architecture skill to review this project's crate layout and concurrency.
```

Best fit: designing or reviewing a Rust async/networked service, or wrapping an
event-driven / `!Sync` API (libp2p, FFI, GUI loop, device handle).

### galtland-code-style

Applies or reviews Rust code-style conventions: anyhow-based errors with
layered `Result`s and invariant-asserting context, enum-variant-path-prefixed
logging keyed by actionability, `XxxInfo` parameter objects, Client/daemon
naming pairs, scoped consts, module-granular import formatting, and
TODO/FIXME/`todo!()` discipline. Also knows which habits are legacy quirks not
to replicate.

Claude Code:

```text
/galtland-code-style review the style and error handling of this crate
/galtland-code-style write this actor in my usual conventions
```

Codex:

```text
Use the galtland-code-style skill to review this crate for convention conformance.
```

Best fit: writing Rust that should match these conventions, or reviewing a
crate for style, error handling, and logging quality.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/douglaz/skills/master/install.sh | bash
```

Or clone and run manually:

```bash
git clone https://github.com/douglaz/skills.git
cd skills
./install.sh
```

By default, `install.sh` clones this repo into
`~/.local/share/douglaz-skills` and installs skills into both
`~/.claude/skills` and Codex. Codex installs go to `~/.codex/skills` on
current setups, with fallback to the legacy `~/.agents/skills` layout when
that is the only Codex skills directory present. Use `--target claude` or
`--target codex` to install into only one tool.

Installer-managed symlinks whose source no longer exists in the repo (a skill
renamed or removed upstream, such as `codex-review-loop` →
`multi-reviewer-loop`) are pruned on every install. Only dangling links pointing
into the install directory are touched.

If a target skill path already exists as a plain directory instead of a
symlink, the installer now treats that as a conflict and exits non-zero after
reporting the partial install. When the directory looks like a copied skill
from this repo, rerun with `--migrate-existing` to rename it to
`<skill>.backup.<timestamp>` and replace it with a symlink.

Install specific skills:

```bash
./install.sh multi-reviewer-loop
./install.sh --target claude multi-reviewer-loop
./install.sh --target codex plan-to-beads-transfer bead-polish-loop second-model-bead-audit orchestrating-with-rb-lite
./install.sh plan-to-beads-transfer bead-polish-loop second-model-bead-audit orchestrating-with-rb-lite
./install.sh --target codex --migrate-existing plan-to-beads-transfer bead-polish-loop second-model-bead-audit
./install.sh --target codex complexity-reducer orchestrating-with-rb-lite
./install.sh --target both voice-dna pr-with-codex-bot-review
```

## Uninstall

```bash
./install.sh --uninstall
./install.sh --target both --uninstall
./install.sh --target codex --uninstall
```

`--uninstall` removes installer-managed symlinks. It does not remove backup
directories created by `--migrate-existing`.

## Prerequisites

- [Claude Code](https://claude.com/claude-code) for Claude installation targets
- [OpenAI Codex CLI](https://github.com/openai/codex) for Codex installation targets
- `codex` on `PATH` for the `multi-reviewer-loop` panel, the
  `second-model-bead-audit` panel,
  `orchestrating-with-rb-lite` harden-until-clean panel, and the default
  `orchestrating-with-rb-lite` reviewer panel
- `claude` on `PATH` for the Claude Fable reviewer in `multi-reviewer-loop`,
  `second-model-bead-audit`,
  `orchestrating-with-rb-lite` harden-until-clean mode, and
  `pr-with-codex-bot-review`, and for the default `orchestrating-with-rb-lite`
  implementer cycle and reviewer panel.
  When both reviewers are requested, either CLI alone runs the loops degraded;
  with both missing they stop. An explicitly pinned reviewer produces
  `PINNED PANEL` when healthy and `BLOCKED` when it fails.
- `jq` on `PATH` to build `second-model-bead-audit` graph snapshots and unwrap
  Claude reviewer JSON in `multi-reviewer-loop`, `second-model-bead-audit`,
  `orchestrating-with-rb-lite`, and `pr-with-codex-bot-review`; Nix-wrapped
  rb-lite supplies its own for the default panel
- SHA-256 tooling (`sha256sum` or `shasum`) for
  `second-model-bead-audit` snapshot integrity
- GNU `timeout` with `--kill-after` support (named `timeout`, or `gtimeout` from
  Homebrew coreutils) to bound each reviewer in `multi-reviewer-loop` — both CLIs can
  hang with no output and no exit, and a backgrounded one has nothing to reap it —
  and for `second-model-bead-audit` and normal `orchestrating-with-rb-lite` runs when
  using a source/path rb-lite install; Nix-wrapped rb-lite supplies GNU coreutils
- `npx` plus Gemini credentials to enable the optional third default
  `orchestrating-with-rb-lite` reviewer
- `rb-lite` on `PATH`, or `nix run --refresh github:douglaz/rb-lite -- ...`
  (the `--refresh` avoids running an hour-stale cached revision), for
  `orchestrating-with-rb-lite`
- `br` (≥ 0.1.45) and `bv` on `PATH`, plus a repo that uses `.beads/`, for
  `plan-to-beads-transfer`, `bead-polish-loop`, `second-model-bead-audit`, and
  `orchestrating-with-rb-lite` backlog-drain and harden-until-clean modes.
  Older `br` corrupts its DB after the branch resets those modes depend on
- `gh` authenticated for `orchestrating-with-rb-lite` backlog-drain and
  harden-until-clean modes (PR creation, checks, merge) and
  `pr-with-codex-bot-review`
- `drive` orchestrates the other skills, so it inherits every prerequisite above
  for whichever phases a given project actually reaches. Its own
  `scripts/drive-status` detector needs nothing — it degrades to `n/a`/`unknown` and exits
  0 without `br`, `jq`, or `gh` — but its bead counts and PR state stay blank
  until those are present.
- `drive`'s SHAPE phase delegates to planning skills that are **not** in this
  repo: `planning-workflow`, `spec`, `grill-me`, `grill-with-docs`,
  `plan-eng-review`, and `plan-ceo-review`. Install them separately (several ship
  with gstack) or substitute your own — the
  phase only requires that a reviewed, buildable spec exists at its exit gate,
  not that any particular skill produced it.
- `drive`'s self-continuation section uses `/goal`, a Claude Code built-in with
  no Codex equivalent. Under Codex the skill relies on its continuation contract
  alone.

## License

MIT
