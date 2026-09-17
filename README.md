# douglaz/skills

Shared agent skills for [Claude Code](https://claude.com/claude-code) and
[OpenAI Codex](https://github.com/openai/codex). The repo collects the
workflows I reach for most: multi-reviewer review loops, beads planning, PR
landing, Lightning ops, code simplification, and writing checks.

Each skill sticks to the shared agent-skills format, so the same source can be
installed into both tools.

## Available skills

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

Runs an iterative multi-reviewer review/fix/re-review loop on your current branch. Detects a review base, runs two reviewers in parallel — `codex review` (`gpt-5.6-sol` at `xhigh`) and a Claude reviewer at high effort — merges and dedupes their findings, treats findings as credible until disproven, fixes accepted items, validates the changed code, and repeats until both reviewers are clean on the current diff. A final consistency pass then reads the changed files — plus the untouched docs that describe them — as one artifact and asks whether they still agree — the class of defect a diff-scoped loop structurally cannot see, such as a summary table that no longer matches the behaviour it describes, or a rule in one file that forbids what another file requires. `CLEAN` requires both.

```
/multi-reviewer-loop              # up to 6 passes (default), both reviewers
/multi-reviewer-loop 3            # up to 3 passes
/multi-reviewer-loop 5 focus on error handling  # 5 passes, focused review
/multi-reviewer-loop --reviewers codex          # pin a single reviewer
```

Two reviewers with different scopes — codex sees the diff, the Claude reviewer reads out into the repo — catch more than either alone, and their disagreements are the highest-signal moments in the loop. Findings both raise get fixed first; a finding only one raises still gets the full evidence bar, because the other reviewer's silence is not counter-evidence. If one reviewer is unavailable the loop runs degraded and says so; it never reports a one-reviewer pass as clean.

The Claude slot is a role, not a model: a bounded probe picks the first reachable model down a ladder (`fable`, then `opus`) before the first pass, because a model you cannot reach *hangs* rather than erroring — the bounded probe had to kill it at 90 seconds, and an unbounded call in the same state was still running eight minutes later — and discovering that inside a real pass costs the whole 25-minute reviewer timeout. A pin replaces the ladder rather than heading it, so a model you name by hand fails rather than being silently substituted. A fallback is a full panel with a substitute, not a degraded one, and every report names the model that actually ran.

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
workflows, plus a proof-of-payment certificate (HTML with in-browser preimage
check, or PNG) for settled sends. Node-specific selectors live outside the
public skill in XDG config or environment variables.

Claude Code:

```text
/lnd-payments pay this invoice lnbc...
```

Codex:

```text
Use the lnd-payments skill to decode this invoice and dry-run payment.
```

### flight-search

Searches and compares flights on Google Flights through the gstack `browse`
headless daemon: itineraries, the nearby-dates price grid, and who sells each
fare. Infers the origin airport from memory or the machine's location, looks up
event dates when the user only names a conference, recommends one itinerary,
and hands the choice to an airline booking skill (`copa-booking` for Copa).

Claude Code:

```text
/flight-search I want to go to Atlanta for TABConf, find me flights
```

Codex:

```text
Use the flight-search skill to compare ASU to MIA round trips around Nov 3-10.
```

### copa-booking

Books a Copa Airlines itinerary on copaair.com up to the payment page by
driving the user's real Google Chrome over the DevTools protocol. The site's
bot protection blocks automation browsers, so the user clears the challenge and
logs into ConnectMiles once in a dedicated Chrome profile; the skill then runs
the booking-panel search, reads the full fare matrix from Copa's plan API,
selects fare families, auto-fills the passenger from the profile, declines
paid extras, and stops on the card form. `references/copa-site-notes.md`
records the site's routes, element ids, and quirks.

Claude Code:

```text
/copa-booking book CM 296 / CM 880 out Oct 8, CM 891 / CM 291 back Oct 17, Economy Classic
```

Codex:

```text
Use the copa-booking skill to start a Copa booking ASU-PTY Dec 12-19 with a checked bag.
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
read-only reviewer panel in parallel — Codex `gpt-5.6-sol` at `xhigh` plus a Claude
reviewer at high effort — then merges findings as `BOTH`, `CODEX`, `CLAUDE`, or
`CONFLICT` and reconciles them against the plan and graph. One unavailable
reviewer produces a clearly labeled degraded audit; with neither external
reviewer available, the audit is blocked rather than silently replaced by a
self-review.

Claude Code:

```text
/second-model-bead-audit docs/PLAN.md
/second-model-bead-audit docs/PLAN.md --reviewers claude  # explicitly pin one reviewer
```

Codex:

```text
Use the second-model-bead-audit skill and give me a launch verdict.
```

### pr-with-codex-bot-review

Opens and lands GitHub pull requests through the `chatgpt-codex-connector`
review bot, with guidance for CodeRabbit when it is configured. Covers PR body
drafting, local gates, a local Claude pre-review before push so the bots
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
review naming this tip, no PENDING review, no `@codex review` request left unanswered (one
newer than the wrapper has not reported; one older only counts as answered when a completed
round separates it from any earlier round-start, since the wrapper after a request can
otherwise be an already-running round's submission), no `eyes` reaction newer than the
wrapper, no base mutation lacking such a provably-fresh later review request (a retarget
grows the diff without moving the head), and zero unresolved threads from either gated bot. It fails closed on any API error or missing tool **in the signals that feed those six** —
a CodeRabbit query failure is reported and does not block, deliberately. Exit 0, 1 blocked,
2 usage, 3 cannot determine, and 4 `BLOCKED_UNATTRIBUTED`. Exits 1 and 4 both refuse the
merge; exit 4 means a round finished without evidence naming its tree, so waiting may not
help. "Cannot determine" is never clearance.

CodeRabbit's status is printed and ignored. It is a PR-level signal, not evidence about a
tree: measured on this repo, CodeRabbit stamped `success`/"Review completed" on a commit
75 seconds after it was pushed while its own reviews were paused. Its review threads still
gate; its green does not.

Exit 0 says `NO_PENDING_EVIDENCE`, not "cleared", and the distinction is the point:
neither bot emits a round-terminal signal, so every conclusion is drawn from absence over a
bounded observation window, which the JSON reports both ends of. It is a stop sign, not a
green light — where the forge can enforce a rule server-side, put it there instead.
`scripts/bot-gate.test` exercises it against a stubbed `gh` — each case
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

## Archived

`drive`, `orchestrating-with-rb-lite`, `rb-lite-backlog-drain`, and
`testing-with-rb-lite` live under `archive/` with their ADRs, specs, and last drive
record. They are not installed and not gated; they grew too complex to keep honest,
and a replacement approach has not been decided. See `archive/README.md`.

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

Repository validation intentionally requires each frontmatter description to use one
single-paragraph `description: >-` block. Tau accepts more YAML scalar forms, but this
narrow authoring convention lets `install.test` enforce its 1,024-byte limit without a
runtime YAML dependency.

Some large workflows are split into exact-name companion skills so Tau can discover
the continuation through its normal skill loader without exposing a source filesystem
path. Their descriptions mark them as internal companions: load them only when the
owning or an explicitly compatible sibling workflow names them, not as standalone
workflow selectors. They remain model-loadable by exact name but are hidden from direct
user invocation. A selective install
automatically includes every required companion of the named skills. After updating the
shared clone, the installer also repairs direct missing companions beside already-managed
referring skills inside each selected target; it does not recursively add newly exposed
standalone workflows or copy an existing skill from one target to another.

One-time upgrade note: an installer process from before companion support cannot change
the code already running in its shell after `git pull`. If that old process performed a
selective update, run the same install command once more so the updated installer adds the
new companion links. Current installers re-exec updated bytes automatically.

Install specific skills:

```bash
./install.sh multi-reviewer-loop
./install.sh --target claude multi-reviewer-loop
./install.sh --target codex plan-to-beads-transfer bead-polish-loop second-model-bead-audit
./install.sh plan-to-beads-transfer bead-polish-loop second-model-bead-audit
./install.sh --target codex --migrate-existing plan-to-beads-transfer bead-polish-loop second-model-bead-audit
./install.sh --target codex complexity-reducer
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
- `codex` on `PATH` for the `multi-reviewer-loop` and `second-model-bead-audit`
  panels
- `claude` on `PATH` for the Claude reviewer in `multi-reviewer-loop`,
  `second-model-bead-audit`, and `pr-with-codex-bot-review`.
  When both reviewers are requested, either CLI alone runs the loops degraded;
  with both missing they stop. An explicitly pinned reviewer produces
  `PINNED PANEL` when healthy and `BLOCKED` when it fails.
- `jq` on `PATH` to build `second-model-bead-audit` graph snapshots and unwrap
  Claude reviewer JSON in `multi-reviewer-loop`, `second-model-bead-audit`,
  and `pr-with-codex-bot-review`
- SHA-256 tooling (`sha256sum` or `shasum`) for
  `second-model-bead-audit` snapshot integrity
- GNU `timeout` with `--kill-after` support (named `timeout`, or `gtimeout` from
  Homebrew coreutils) to bound each reviewer in `multi-reviewer-loop` — both CLIs can
  hang with no output and no exit, and a backgrounded one has nothing to reap it —
  and for `second-model-bead-audit` unconditionally
- `br` (≥ 0.1.45) and `bv` on `PATH`, plus a repo that uses `.beads/`, for
  `plan-to-beads-transfer`, `bead-polish-loop`, and `second-model-bead-audit`.
  Older `br` corrupts its DB after branch resets
- `gh` authenticated for `pr-with-codex-bot-review`
- [gstack](https://github.com/garrytan/gstack) with its `browse` skill built
  (`gstack/browse/dist/browse` under one of the skills roots, or `BROWSE_BIN`)
  for `flight-search`; the headless daemon renders Google Flights
- `google-chrome` (or Chromium via `CHROME_BIN`), a desktop session to show its
  window, `node`, and `playwright-core` (found via `require`, or from gstack's
  bundled copy) for `copa-booking`; `node` is also needed by `./check.sh`,
  which runs `copa-booking`'s offline test

## License

MIT
