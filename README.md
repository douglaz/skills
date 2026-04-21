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

### orchestrating-with-ralph-burning

Uses `ralph-burning` as the default structured workflow for substantial
implementation work: requirements, project creation, flow selection, run
start/resume, and canonical status inspection.

Claude Code:

```text
/orchestrating-with-ralph-burning implement retry-safe daemon lease cleanup
```

Codex:

```text
Use the orchestrating-with-ralph-burning skill to implement this with ralph-burning.
```

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
./install.sh --target codex plan-to-beads-transfer bead-polish-loop second-model-bead-audit orchestrating-with-ralph-burning
./install.sh plan-to-beads-transfer bead-polish-loop second-model-bead-audit orchestrating-with-ralph-burning
./install.sh --target codex --migrate-existing plan-to-beads-transfer bead-polish-loop second-model-bead-audit
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
  `codex-review-beads-ralph-loop`
- `br` and `bv` on `PATH`, plus a repo that uses `.beads/`, for
  `plan-to-beads-transfer`, `bead-polish-loop`,
  `second-model-bead-audit`, and `codex-review-beads-ralph-loop`
- `ralph-burning` on `PATH`, or `nix run github:douglaz/ralph-burning -- ...`,
  for `orchestrating-with-ralph-burning` and
  `codex-review-beads-ralph-loop`
- `gh` authenticated for `codex-review-beads-ralph-loop` (PR creation and
  merge)

## License

MIT
