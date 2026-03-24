# codex-review-loop

A [Claude Code](https://claude.com/claude-code) skill that runs an iterative Codex review/fix/re-review loop on your current branch.

It detects a review base, runs `codex review`, treats findings as credible until disproven, fixes accepted items, validates the changed code, and repeats until clean or the pass limit is reached.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/douglaz/codex-review-loop/master/install.sh | bash
```

Or clone and run manually:

```bash
git clone https://github.com/douglaz/codex-review-loop.git
cd codex-review-loop
./install.sh
```

## Uninstall

```bash
./install.sh --uninstall
```

## Usage

In Claude Code:

```
/codex-review-loop              # up to 6 passes (default)
/codex-review-loop 3            # up to 3 passes
/codex-review-loop 5 focus on error handling  # 5 passes, focused review
```

## Prerequisites

- [Claude Code](https://claude.com/claude-code)
- [OpenAI Codex CLI](https://github.com/openai/codex) (`codex` binary on PATH)
- A git repository with changes to review

## How it works

1. **Preflight** - Detects the diff base (PR base, upstream, default branch)
2. **Review** - Runs `codex review` against the base
3. **Classify** - Each finding is classified as FIX, DEFER, or REJECT (with evidence)
4. **Fix & validate** - Applies fixes, runs targeted verification
5. **Repeat** - Loops until clean or max passes reached

Findings are treated as credible by default. Rejection requires concrete counter-evidence from code, tests, or docs.

## License

MIT
