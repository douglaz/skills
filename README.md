# skills

A collection of [Claude Code](https://claude.com/claude-code) skills.

## Available skills

### codex-review-loop

Runs an iterative Codex review/fix/re-review loop on your current branch. Detects a review base, runs `codex review`, treats findings as credible until disproven, fixes accepted items, validates the changed code, and repeats until clean or the pass limit is reached.

```
/codex-review-loop              # up to 6 passes (default)
/codex-review-loop 3            # up to 3 passes
/codex-review-loop 5 focus on error handling  # 5 passes, focused review
```

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

Install a specific skill only:

```bash
./install.sh codex-review-loop
```

## Uninstall

```bash
./install.sh --uninstall
```

## Prerequisites

- [Claude Code](https://claude.com/claude-code)
- [OpenAI Codex CLI](https://github.com/openai/codex) (`codex` binary on PATH) for codex-review-loop

## License

MIT
