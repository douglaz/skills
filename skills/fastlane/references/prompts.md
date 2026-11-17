# Fast-lane prompts

Two templates: the implementer's task file (`iN/task.md`) and the readers' review brief
(`iN/review-brief.md`). Keep both self-contained. Codex and the readers remember nothing from
earlier iterations; they only know what these files say and what they read in the repo.

## Task file (`iN/task.md`)

```markdown
# Task iN: <one-line goal>

## What the live test showed
- Step <n> of the journey (live-test.md): <what the user did>.
- What the user saw: <exact text or behaviour>. Expected: <what they should have seen>.
- Evidence: <paths to the driver log, screenshots, server logs>.
(First iteration from an inherited candidate: say what the candidate already does and what is left.)

## Diagnosis
<cause with file:line, if known; otherwise "unknown: find it first">

## Change
- <what to change, and where if known>
- Keep the change to what fixes the failures above. Don't refactor or tidy.

## Constraints
- Tests are suspended. Don't run, fix, edit or add tests, fixtures or test scripts.
- Don't commit, push, deploy, switch branches, stash, reset or touch any tracker.
- <project public-text rules, for example "no tool or model names in any committed text">
- <project hard limits that touch the code>

## Compile (what gets deployed)
- `<exact build command>`: must exit 0.
- `<bundle or packaging command>`: must exit 0.
Record each command, its exit code and its wall time in the handoff.

## Handoff
Write `<path>/handoff.md`: what changed, by file and why; each build command with its exit code;
anything left undone; anything that looked wrong but was out of scope.
```

## Review brief (`iN/review-brief.md`)

```markdown
# Review iN: <one-line goal>

Read-only review. Don't edit files, commit, or run builds or tests. Tests are suspended until the
live test passes, so don't ask for them.

## What the change is for
<the task's goal and the live failure it fixes, in plain words; link iN/task.md>

## Read
- The diff: `<abs path>/iN/diff.patch` (sha256 <sha>). It holds tracked changes plus new files.
- The repository at `<worktree>` for context. Read the callers and siblings of changed code.
- (Re-review) The earlier findings: `<path>`. Check whether each one is fixed, and look only at
  the new delta: `<path>`.
- (Re-review) Follow-ups already listed: `<path to followups.md>`. Don't report one again unless
  you rate it P0 or P1 and name the clause it meets.

## Report
One finding per line, most severe first:
`[P0|P1|P2|P3] [PRODUCT|TEST] file:line: claim`, then indented detail and evidence.
- P0: money or data loss, a secret, security, core function broken, or the brief fundamentally failed.
- P1: blocks acceptance: wrong behaviour in a supported case, a brief requirement unmet, a check that cannot
  fail, or a requirement made false. Any money, secret or data-loss defect on a reachable path is at least P1.
- P2: a real defect that does not block.
- P3: changes no behaviour, requirement or check.
- TEST marks a finding about tests only (unrun, broken fixture, missing coverage). It's deferred,
  not a blocker. Use PRODUCT for anything a real user could hit. The live-test driver and its
  checks aren't suspended tests: tag findings about them PRODUCT.
- Before claiming behaviour in code the diff doesn't show, read that code and cite it. If you
  can't verify a claim, write it as a QUESTION.
- Write exactly "No findings." if there are none.
```

## Spec-only variants

- **Task file:** replace "What the live test showed" with the scope still to write (sections, decisions to fold in,
  open questions). Drop "Compile".
- **Review brief:** readers check the text for contradictions, unmet scope, ambiguity an implementer would trip on,
  and claims the text doesn't support. PRODUCT then means "the spec text"; TEST still means deferred checks.
