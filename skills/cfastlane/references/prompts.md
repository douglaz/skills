# Combined fast-lane prompts

Three templates: the session's task (`PKT/task.md`), a resume note, and the reviewer's brief
(`PKT/review-brief.md`). The session and the reviewer know only what these files say and what they
read in the repo, so keep each self-contained. Tokens are measured, never limited: don't write a cap,
a checkpoint or a "read sparingly" rule into any of them.

## Task (`PKT/task.md`)

```markdown
# <one-line goal>

You are one session doing this whole packet: plan it, write the code, build, and write the handoff.
There is no separate manager and no separate implementer. This page is your handoff; do not read any
brief, plan or earlier session. Owner approval: <path to the decision record>.

Packet folder (state, scratch, receipts): <PKT>. Worktree: <path>, branch <name>, based on the commit
in <PKT>/base. Read its AGENTS.md. Touch no other worktree.

## What you do not do
No commits, branch changes, push, PR, merge, review calls, sub-agents or other model launches, tracker
writes, root or sudo. A script commits your work; you do not judge review findings.
<the project's hard safety lines, verbatim>

## Starting point (reuse, don't redo)
<what already exists and settles decisions; the build command; the few source ranges worth reading>

## The change
<what must be true when you finish, in the owner's terms. If a plan or claim must be written first,
say where, cap its length, and say to continue without waiting once it is written.>
<One permitted narrowing, if any, and that anything else is a stop with one exact remaining goal.>

## Rules for the work
<what makes the result real rather than apparent: no stubs, no weakened checks, the live runner's
command contract, what must still pass>

## Named follow-ups
<only the ones the owner named, each with its id and what done means>

## Public-text rules
<what must never appear in a repo file, comment, document or commit message>

## Command rules
<the project's shell and state rules, restated in full>

## Handoff
Write <PKT>/handoff.md (at most 70 lines): changed files; what was achieved and whether the narrowing
was used; each evidence command with its exit and time; anything noticed but not fixed. Write <PKT>/commit-subject.txt (one line) and <PKT>/commit-body.txt. Leave the worktree
uncommitted. If you stop early, give ONE precise remaining goal. Final message: at most 10 lines,
ending with `HANDOFF: complete` or `HANDOFF: partial`.
```

## Resume note

```markdown
<Why the last turn ended, in one sentence, and whose doing it was.> Nothing else changed; the task in
<PKT>/task.md stands, including every rule in it.

<What is different now: the owner's answer, or the one verified finding to remove and the smallest
change that removes it.> Do not re-read what you already read. <Next step.>
```

A repair note names only verified P0/P1 findings. It does not pass on P2 or P3 findings, even ones on
the same lines.

## Review brief (`PKT/review-brief.md`)

```markdown
# Independent review: <one-line goal>

You are the independent reviewer of one small change. You are read-only: read files, run nothing,
edit nothing. Keep your reading narrow; this is not a whole-branch review.

## What to read
1. The exact diff: <PKT>/diff.patch (commit <sha> on base <sha>). The worktree is at that commit.
2. The plan or claim the author wrote before coding: <path>. Nobody has reviewed it; judge it.
3. The reproduction receipt, made by a script after the commit: <PKT>/manifest.json. Step outputs are
   under <path> if you need one.
4. <the few normative sources, with line ranges>
5. The author's handoff, <PKT>/handoff.md: claims to check, not facts.

## Questions
<five to seven, each answerable with file:line. Cover: does the change do what the task asked; is the
result real (no stub, no vacuous check); can the checks pass when they should fail; did a folded-in
follow-up weaken anything; the project's public-text rule.>

## Severity (the owner's rule, verbatim; rate every finding P0–P3)
- P0: money or data loss, a secret, security, core function broken, or the brief fundamentally failed.
- P1: blocks acceptance: wrong behaviour in a supported case, a brief requirement unmet, a check that
  cannot fail, or a requirement made false. Any money, secret or data-loss defect on a reachable path
  is at least P1.
- P2: a real defect that does not block.
- P3: changes no behaviour, requirement or check.

## Answer format
- Per question: at most 10 lines.
- `FINDINGS:` a numbered list, each with its rating, file:line and one sentence on what goes wrong.
- `LIMITS:` what you could not check.
- Last line, exactly one of: `VERDICT: GO`, `VERDICT: REVISE`, `VERDICT: STOP`.

Don't soften disagreement, and don't agree with a claim you did not check.
```

Keep the P0–P3 lines exactly as written: they are the owner's text, and a brief that rewords them
changes what blocks.
