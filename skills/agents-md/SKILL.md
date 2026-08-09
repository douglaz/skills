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

Default to the current repo. If the user named a path, `cd` there first and confirm it is
a git repository — every step below reads and writes relative to the working directory, so
running them against the wrong repo is the one mistake that cannot be undone by re-running.

```bash
[ -n "$TARGET" ] && cd "$TARGET"
git rev-parse --show-toplevel || { echo "not a git repository"; exit 1; }
```

### 1. Read what is already there

```bash
[ -f AGENTS.md ] && wc -l AGENTS.md || echo "no AGENTS.md yet"
grep -n '<!--' AGENTS.md 2>/dev/null        # which managed blocks exist
```

If `AGENTS.md` exists, read it in full before writing. You need to know what the
humans said so the block you add does not contradict it — and if it *does*
contradict something, say so rather than silently adding a competing rule.

Some repos put this content in `CLAUDE.md` instead, and a few have both. If both
exist, put the block in `AGENTS.md` and leave `CLAUDE.md` alone: Codex reads only
the former, and duplicating rules across two files is how they drift apart.

### 2. Detect the gate

The block carries one project-specific line — the command that proves the repo is
healthy — because "run the gate" is useless advice without naming it.

```bash
GATE=""
if   [ -x ./check.sh ];                   then GATE="./check.sh"
elif [ -f justfile ] || [ -f Justfile ];  then GATE="just check"   # confirm the recipe exists
elif [ -f Cargo.toml ];                   then GATE="cargo clippy --all-targets -- -D warnings && cargo test"
elif [ -f package.json ];                 then GATE="npm test"     # confirm scripts.test is real
elif [ -f go.mod ];                       then GATE="go test ./..."
fi
# Only wrap a gate that exists. `nix develop -c bash -c ''` runs nothing and exits 0
# — a permanently green gate recorded in every future agent's instructions, which is
# the exact failure this block warns about.
if [ -n "$GATE" ] && [ -f flake.nix ] && command -v nix >/dev/null 2>&1; then
  GATE="nix develop -c bash -c '$GATE'"
fi
```

Verify the command actually exists before writing it in — a `justfile` without a
`check` recipe, or npm's default `"no test specified" && exit 1` scaffold, would
pin a permanently red gate into every future agent's instructions. If you cannot
find a real gate, drop the line and say so; a missing gate line is honest, a
wrong one is worse than nothing.

### 2a. `--check` stops here

`--check` is read-only. Report which blocks exist, whether the discipline block
matches the current canonical text, and what the detected gate is — then stop. Do
not fall through into the write steps below; an inspection that edits the file is
worse than one that refuses to run.

### 3. Write or update the block

The canonical text is in
[references/discipline-block.md](references/discipline-block.md). Substitute
`{{GATE}}` — but **not with `sed`**. In a `sed` replacement string `&` means "the
whole match", so a gate containing `&&` (which most do) silently expands into two
copies of the placeholder and the command is corrupted with no error. Use a
substitution that treats the replacement as a literal:

```bash
# Take only the canonical text — everything before <!-- BLOCK-START --> is
# commentary for the block's maintainer and must not land in a repo's AGENTS.md.
GATE="$GATE" python3 -c '
import os,sys
t=sys.stdin.read().split("<!-- BLOCK-START -->",1)[1]
sys.stdout.write(t.replace("{{GATE}}", os.environ["GATE"]))
' < references/discipline-block.md > /tmp/block.md
grep -F "$GATE" /tmp/block.md >/dev/null || { echo "substitution failed"; exit 1; }
grep -q 'canonical text' /tmp/block.md && { echo "commentary leaked into block"; exit 1; }
```

That `grep -F` is the point: it is the difference between substituting and
*believing* you substituted. Then:

- **No block yet** → append it at the end of `AGENTS.md`, or create the file with
  a `# AGENTS.md` heading if there is none.
- **Block already present** → replace everything between the markers, inclusive
  of neither marker. Do not append a second copy.

Use your harness's edit tool. If you script it instead, follow the block's own
rule: assert the markers exist, then read the file back and confirm both markers
still appear exactly once. This skill writes the rule about silent edit failures;
introducing one while doing so would be its own kind of comedy.

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
