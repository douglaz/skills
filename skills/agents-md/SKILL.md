---
name: agents-md
description: >-
  Create or update a repo's AGENTS.md so agents working in it inherit the
  discipline that keeps them honest — verified edits, unpiped gates, evidence
  instead of assertion — plus the repo's beads workflow when it uses one. Use
  this when setting up a new repo for agent work, when onboarding a project that
  has no AGENTS.md, when asked to "add agent instructions", "set up AGENTS.md",
  "document the conventions for agents", or to propagate a lesson learned on one
  machine to every repo and every machine. Also use it when an agent has just
  made a mistake that a standing instruction would have prevented, since the
  point of AGENTS.md is that the fix travels with the repository instead of
  living in one machine's local config. Not for project-specific architecture
  notes, which belong outside the managed block and are written by a human.
argument-hint: "[--check] [path to repo]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# agents-md

`AGENTS.md` is the only place a working agreement can live that actually travels
— it is committed to the repo, so it reaches every machine, every clone, and both
Claude Code and Codex without anyone syncing dotfiles. A lesson recorded in a
local `CLAUDE.md`, a settings file, or an agent's memory is lost the moment
someone works on another box.

This skill maintains **one managed block** in that file and touches nothing else.

## The contract

Three regions, three owners:

| Region | Owner | Who writes it |
|---|---|---|
| `<!-- agent-discipline-v1 -->` … `<!-- end-agent-discipline -->` | this skill | portable rules that apply to any repo |
| `<!-- br-agent-instructions-v1 -->` … `<!-- end-br-agent-instructions -->` | `br agents` | the beads workflow |
| everything else | humans | architecture, commands, project conventions |

Never edit outside your markers. A project's `AGENTS.md` is usually the most
carefully written file in the repo, and clobbering it to insert boilerplate is a
much worse outcome than not running at all.

## Workflow

### 0. Resolve the target repo

Locate this installed skill's directory and set `SKILL_DIR` to its absolute path
before changing directories; its references are not relative to the target repo.
Default to the current repo. If the user named a path, `cd` there first and confirm
the repository root. Work at that root for the steps below.

```bash
[ -n "$TARGET" ] && cd "$TARGET"
git rev-parse --show-toplevel || { echo "not a git repository"; exit 1; }
```

### 1. Read what is already there

```bash
[ -f AGENTS.md ] && wc -l AGENTS.md || echo "no AGENTS.md yet"
grep -n '<!--' AGENTS.md 2>/dev/null        # which managed blocks exist
```

Inspect the existing markers and the project guidance relevant to gates,
verification, safety and ownership. Choose the sections needed to check for
conflicts; no full-file reading or read ledger is required. Report an unresolved
conflict rather than inserting a competing rule.

Some repos put this content in `CLAUDE.md` instead, and a few have both. If both
exist, put the block in `AGENTS.md` and leave `CLAUDE.md` alone: Codex reads only
the former, and duplicating rules across two files is how they drift apart.

### 2. Resolve the gate

Use the project's documented gate and CI configuration as the source. Check that
the named script, recipe or package-manager command exists and covers the checks
the project requires. Do not choose `just check`, `npm test`, a Cargo command or a
Nix wrapper from the presence of a manifest alone. Preserve an existing gate only
after checking it against the current project guidance.

Set `GATE` to the verified command, or to an empty string when none is known.
Omit the gate line when empty and report the gap. Finding the command is not a
claim that it has run or passed; do not run expensive project gates merely to
edit this documentation unless the task requires it.

### 2a. `--check` stops here

`--check` is read-only. Report which blocks exist, whether the discipline block
matches the current canonical text, and what the detected gate is — then stop. Do
not fall through into the write steps below; an inspection that edits the file is
worse than one that refuses to run.

### 3. Write or update the block

The canonical text is in
[references/discipline-block.md](references/discipline-block.md). Extract it from
the installed skill directory and substitute literally. For example:

```bash
GATE="$GATE" python3 -B - "$SKILL_DIR/references/discipline-block.md" <<'PY' > /tmp/block.md
import os, sys
from pathlib import Path
source = Path(sys.argv[1]).read_text()
marker = "<!-- BLOCK-START -->"
assert source.count(marker) == 1
text = source.split(marker, 1)[1]
gate = os.environ["GATE"]
assert text.count("{{GATE}}") == 1
if not gate:
    text = text.replace("Gate for this repo: `{{GATE}}`\n", "")
text = text.replace("{{GATE}}", gate)
assert "{{GATE}}" not in text
assert gate in text if gate else "Gate for this repo:" not in text
sys.stdout.write(text)
PY
```

- **No block yet** → append it at the end of `AGENTS.md`, or create the file with
  a `# AGENTS.md` heading if there is none.
- **Block already present** → replace everything between the markers, inclusive
  of neither marker. Do not append a second copy.

Before replacing a block, require exactly one opening marker and one closing
marker, in that order. If only one exists, or either is duplicated, stop without
writing and report the malformed region. Use your harness's edit tool or an
asserted replacement. Confirm both markers occur once afterwards and the diff
changes only the intended region.

### 4. Delegate the beads block

If the repo uses beads (`.beads/` exists), do not hand-write anything about it —
`br` owns that block and keeps it current:

```bash
br agents --check              # what state is it in
br agents --add --dry-run      # preview
br agents --add                # or --update if the block is stale
```

Its markers (`br-agent-instructions-v1`) are separate from yours, so the two
blocks coexist and each can be regenerated independently.

### 5. Verify, then report the diff

```bash
grep -c 'agent-discipline-v1\|end-agent-discipline' AGENTS.md   # expect 2
git diff --stat AGENTS.md
```

Show the user what changed. If `AGENTS.md` was already substantial, say
explicitly that you only touched the managed region.

## Adding a rule to the block

The block is copied into every repo, so every line costs attention everywhere. A
new rule earns its place only if:

1. **It applies to essentially any repo.** Language- and tool-specific guidance
   goes outside the markers, written by a human who knows the project.
2. **An agent gets it wrong by default.** Not "write tests" — something an
   otherwise competent agent will do wrong because the failure is invisible.
3. **You can name the incident.** Every current rule traces to a specific failure
   that a standing instruction would have prevented. If you cannot describe the
   failure in one sentence, it is a preference, not a rule.

When a rule graduates — enough repos need it, or it grows beyond a paragraph —
move it to its own skill and leave a pointer, the way beads guidance lives in
`br agents` rather than here.

The block's rule on behavioural claims is the worked example: the paragraph in the
block is the whole rule, and the incident behind it, the transcripts showing what a
sufficient record looks like, and the observing-versus-explaining distinction live in
[references/behavioural-claims.md](references/behavioural-claims.md). Note where the
pointer is — here, not in the block. A reference in the copied text would be a dangling
link in every downstream `AGENTS.md`, since the block travels and this repo does not.

## When not to use this

- The repo has a carefully maintained `AGENTS.md` and the user wants
  *project-specific* guidance written. That is human work; this skill only owns
  the portable block.
- The user wants a machine-local preference recorded. That belongs in their own
  config, not in a file every contributor sees.
- A single file needs one correction. Just fix it.
