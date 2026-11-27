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
- Run every check the task names as required, in full, including its tests. Other tests are
  suspended: don't run, fix, edit or add them, their fixtures or their scripts.
- Don't commit, push, deploy, switch branches, stash, reset or touch any tracker.
- <project public-text rules, for example "no tool or model names in any committed text">
- <project hard limits that touch the code>

## Compile (what gets deployed)
- `<exact build command>`: must exit 0.
- `<bundle or packaging command>`: must exit 0.
Record each command, its exit code and its wall time in the handoff.

## Handoff
Write `<path>/handoff.md`: what changed, by file and why; each build and task-required check command
with its exit code;
anything left undone and the obstacle that stopped it; anything that looked wrong but was out of
scope. Do all of the Change before you stop: leave something undone only for a named obstacle
(evidence a requirement cannot be met as written, one specific step with what you tried and why
it failed, something reserved for the manager or the owner, the time limit), never because work
remains.
Report preexisting gaps or defects as observations and continue. Run a baseline before proposing a
requirement change to see whether the symptom predates this task. Route contradictions within the
brief to whoever owns the brief. For owner calls, finish independent work, look ahead for other
owner decisions and report them together with one recommendation and its evidence for each.
```

If the task needs its own stop condition, write it as a named obstacle, never as "if X cannot be
finished": an implementer reads that as leave to stop before trying.

## Review brief (`iN/review-brief.md`)

```markdown
# Review iN: <one-line goal>

Read-only review. Don't edit files, commit, or run builds or tests. Check the handoff for the
commands and exits of checks the task requires. Respect the task's suspension of other tests.
Do not read credential files or model config folders
`~/.claude`, `~/.codex`, `~/.grok`.

## What the change is for
<the task's goal and the live failure it fixes, in plain words; link iN/task.md>

## Read
- The diff: `<abs path>/iN/diff.patch` (sha256 <sha>). It holds tracked changes plus new files.
- The repository at `<worktree>` for context. Read the callers and siblings of changed code.
- The task and its handoff: `<paths>`. Check the handoff's claims against the evidence.
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
- TEST marks a finding only about suspended tests (unrun, broken fixture, missing coverage).
  Defer those findings. Use PRODUCT for anything a real user could hit, live-test driver
  findings and acceptance findings about checks the task requires.
- Before claiming behaviour in code the diff doesn't show, read that code and cite it. If you
  can't verify a claim, write it as a QUESTION.
- Write exactly "No findings." if there are none.
```

## Spec-only variants

- **Task file:** replace "What the live test showed" with the scope still to write (sections, decisions to fold in,
  open questions). Drop "Compile".
- **Review brief:** readers check the text for contradictions, unmet scope, ambiguity an implementer would trip on,
  and claims the text doesn't support. PRODUCT then means "the spec text"; TEST still means deferred checks.

## Follow-ups (`followups.md`)

Write one `##` heading per defect. Use the lane's assigned number before the severity when
several managers share the file. The `# Follow-ups` heading is optional.

```markdown
# Follow-ups

## P2 <short title>
Location: path/to/file:42

<What is wrong, observed commit, reviewers, why this severity, smallest fix, verification and source.>

## 601 P1 [preexisting] <short title>
Location: path/to/file:77
Existing: <bead ID if you verified an existing bead is the same defect>

<Evidence and disposition.>
```

Use `[preexisting]` for an older P0/P1 and `[cap]` for a P0/P1 left open by the round cap.
Omit the disposition on P2/P3. Omit the `Existing:` line unless naming a confirmed match.
Keep the body below a blank line and use `###` or deeper headings in prose.
Put literal lines starting with `## ` in a closed block with left-aligned fences.
