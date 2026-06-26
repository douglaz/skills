# skills

A collection of skills for [Claude Code](https://claude.com/claude-code) and
[OpenAI Codex](https://github.com/openai/codex).

The Flywheel bead skills in this repo intentionally stick to the shared
agent-skills format so they can work in both tools.

## Available skills

### codex-review-loop

Runs an iterative Codex review/fix/re-review loop on your current branch. Detects a review base, runs `codex review`, treats findings as credible until disproven, fixes accepted items, validates the changed code, and repeats until clean or the pass limit is reached.

```
/codex-review-loop              # up to 6 passes (default)
/codex-review-loop 3            # up to 3 passes
/codex-review-loop 5 focus on error handling  # 5 passes, focused review
```

Best fit: Claude Code explicit invocation. This skill shells out to `codex
review` and is most natural when run as a slash command from Claude Code.

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
graph converges.

Claude Code:

```text
/bead-polish-loop
```

Codex:

```text
Use the bead-polish-loop skill on the current bead graph.
```

### second-model-bead-audit

Provides an independent audit of an existing bead graph against the plan, with
blocking findings first and exact bead-level fixes when obvious.

Claude Code:

```text
/second-model-bead-audit docs/PLAN.md
```

Codex:

```text
Use the second-model-bead-audit skill and give me a launch verdict.
```

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

Best fit: you want implementation/review convergence without a durable
multi-stage project. For backlog draining, the durable state comes from `br`,
Git branches, PRs, and CI; rb-lite only handles one bead's inner loop at a
time.

### codex-review-beads-ralph-loop

Composes `codex review` + `br` beads + `ralph-burning` into a harden-until-clean
loop on a work branch. Each `codex review` finding becomes a tracked bead; each
bead gets solved via its own `ralph-burning` minimal run on a dedicated
feature branch, through PR and merge; after every batch of merges the
review is rerun. Stops when the review is clean or the same finding
survives two full iterations.

Claude Code:

```text
/codex-review-beads-ralph-loop harden this branch against main
```

Codex:

```text
Use the codex-review-beads-ralph-loop skill to drive codex+beads+ralph until this branch is clean.
```

Best fit: you want durable, bead-tracked regression sweeps with one PR per
finding, not the inline-edit style of `codex-review-loop`.

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

If a target skill path already exists as a plain directory instead of a
symlink, the installer now treats that as a conflict and exits non-zero after
reporting the partial install. When the directory looks like a copied skill
from this repo, rerun with `--migrate-existing` to rename it to
`<skill>.backup.<timestamp>` and replace it with a symlink.

Install specific skills:

```bash
./install.sh codex-review-loop
./install.sh --target claude codex-review-loop
./install.sh --target codex plan-to-beads-transfer bead-polish-loop second-model-bead-audit orchestrating-with-rb-lite
./install.sh plan-to-beads-transfer bead-polish-loop second-model-bead-audit orchestrating-with-rb-lite
./install.sh --target codex --migrate-existing plan-to-beads-transfer bead-polish-loop second-model-bead-audit
./install.sh --target codex complexity-reducer orchestrating-with-rb-lite
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
- `codex` on `PATH` for `codex-review-loop` and
  `codex-review-beads-ralph-loop`, and for the default `orchestrating-with-rb-lite`
  reviewer panel
- `claude` on `PATH` for the default `orchestrating-with-rb-lite` implementer
  cycle and reviewer panel
- `jq` on `PATH` for the default `orchestrating-with-rb-lite` Claude reviewer
  when using a source/path rb-lite install; Nix-wrapped rb-lite supplies it
- `timeout` with `--kill-after` support for normal `orchestrating-with-rb-lite`
  runs when using a source/path rb-lite install; Nix-wrapped rb-lite supplies
  GNU coreutils
- `npx` plus Gemini credentials to enable the optional third default
  `orchestrating-with-rb-lite` reviewer
- `rb-lite` on `PATH`, or `nix run github:douglaz/rb-lite -- ...`, for
  `orchestrating-with-rb-lite`
- `br` and `bv` on `PATH`, plus a repo that uses `.beads/`, for
  `plan-to-beads-transfer`, `bead-polish-loop`,
  `second-model-bead-audit`, `codex-review-beads-ralph-loop`, and
  `orchestrating-with-rb-lite` backlog-drain mode
- `ralph-burning` on `PATH`, or `nix run github:douglaz/ralph-burning -- ...`,
  for `codex-review-beads-ralph-loop`
- `gh` authenticated for `codex-review-beads-ralph-loop` (PR creation and
  merge) and `orchestrating-with-rb-lite` backlog-drain mode

## License

MIT
