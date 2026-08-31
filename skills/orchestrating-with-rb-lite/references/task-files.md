# Task files: template, scope guards, and bounding a bead

Read this when authoring a `--task-file`, and before launching any bead that sits next to
modules the implementer could rewrite. The template's scope guard is load-bearing: without
it, reviewer rounds ratchet into adjacent beads and into rb-lite's own run artifacts.

## Backlog task template

The task file for a bead should be self-contained and narrow:

```markdown
# Bead <id>: <one-line goal>

## Problem description
<2-4 paragraphs explaining what and why; reference the bead's acceptance
criteria.>

## Required changes
<Numbered list of concrete edits: paths, functions, behaviors, expected
shape of the change.>

## Tests
<3-7 specific test cases the implementer should add or update. Use behavior
phrases like "X happens when Y", not only test function names.>
- Test through the REAL code path. A test that exercises a test-only shortcut
  (env-gated early return, fake injected above the seam being fixed) stays green
  whether or not the fix works. Inject fakes *below* the seam you care about.
- The new test must actually RUN under the repo's default test command. Verify
  by running it and grepping the output for the new test name — a test file
  outside the runner's glob is dead coverage that reads as a gate.

## Scope guard
- Do not refactor unrelated code.
- Do not broaden this bead into adjacent backlog items.
- Build the SIMPLEST correct thing for this bead. Do NOT build: <non-goals —
  defensive edge cases beyond the threat model, config knobs, new abstractions,
  retry/scheduling machinery>. Target ~N lines / one focused module; if you are
  writing materially more, stop and simplify.
- Do not run `rb-lite` itself, send signals to your own process tree, or
  otherwise interfere with the surrounding orchestration.
- Treat `.rb-lite/`, `.ralph-burning/`, `.git/ralph-burning-live/`, and
  `.beads/` as orchestration/state directories, not product code to review.
  That is a *reviewing* scope rule, not an editing licence — nobody, implementer
  or operator, hand-edits `.beads/issues.jsonl`; bead text is written with
  `"$BEADS_JSONL_RESOLVER" --run-br update <id> --description "<full body>"` or it gets silently reverted by the next flush
  ([exact companion skill `rb-lite-backlog-drain`, step 11](../../rb-lite-backlog-drain/SKILL.md#backlog-step-11)).
  This does NOT forbid ordinary git usage: **`git add` any new SOURCE file you
  create** so it appears in the reviewed diff (`git diff <base>` omits untracked
  files — an unstaged new module reads to reviewers as "missing, won't compile").
  Staging a source file is not the prohibited editing of `.git/` internals.
- **Never weaken, invert, or delete a correctness/safety/invariant comment or
  assertion to satisfy a review finding without first verifying it against the
  actual code and citing `file:line`.** A correctness-comment edit is NOT a cheap
  doc fix — it carries the same evidence burden as a behavior change. If a reviewer
  says an invariant claim is wrong, either prove it (fix code + comment together)
  or refute the finding with code evidence and keep the comment. Be especially wary
  of findings about invariants whose guarantee lives in a file the diff does not
  show.

## Acceptance criteria
- <Acceptance criteria copied from `"$BEADS_JSONL_RESOLVER" --run-br show <id>`.>
- <What must KEEP working — name the legitimate cases the change must preserve.
  Criteria that only describe what to block get signed off, and the breakage
  they cause comes back as its own bead later.>
- The repo's local gate set passes on the final tree.
```

The scope guard is load-bearing. Without it, reviewer rounds can ratchet into
adjacent beads or rb-lite's own run artifacts.

## Bounding a high-blast-radius bead

Some beads invite sprawl: the core is genuinely hard, or it sits next to several
modules the implementer could "helpfully" rewrite. Left unbounded, the loop treats
every adjacent file as fair game. One real run ballooned to 25 rounds and a
3600-line module that also rewrote four already-merged files — it had to be
discarded wholesale. Bound these from the **first** run, not after they blow up:

- **Lock the files.** Put a hard file constraint at the TOP of the task: "Create
  EXACTLY these file(s): `<paths>`. Do NOT modify any other file. If you believe you
  need to touch another file, the design is wrong — STOP and restructure to use the
  existing public seams as they are." This is the single most effective brake on
  cross-bead contamination — much stronger than the scope guard's generic "don't
  refactor unrelated code," because it names the boundary.
- **Keep the bead self-contained.** If the work needs a small piece of an adjacent
  module's behavior, have the task do that small piece inline against the existing
  public API — do NOT let it reach in and "factor out" a shared helper. Reaching
  across the seam is exactly how one bead's run ends up rewriting three other beads.
- **Watch the run; don't fire-and-forget.** Active supervision is the real control —
  the caps below are backstops, not the method. Tail each round's diff and review
  output as it lands (`git diff` on the branch, the latest `review-round-*.md`), and
  intervene the moment the code starts degrading: edits creeping outside the locked
  files, speculative abstractions, a "simple" module ballooning. Catching a bad round
  as it happens is far cheaper than discarding 25 of them.
- **Treat `--max-rounds` as a checkpoint, not a finish.** A low cap (e.g. `6`) forces
  a pause to assess rather than ending the work. At the checkpoint, read what actually
  changed: if the findings were legitimate and the code is sound and still converging,
  relaunch for another batch (6 or more) to finish; if it's sprawling or gold-plating,
  stop and re-scope instead. The cap buys you a decision point, not a verdict.
- **Don't pre-cap finding severity.** Leave the default (`P2`) so genuine P2 polish
  lands — those are often real improvements worth keeping. P3-only findings are not
  relayed by default; inspect them manually, or lower the floor to P3 only when the
  user explicitly wants to chase nits. `--min-findings-severity P1` is not the tool for
  gold-plating — it also filters out the skeptic, which tags every finding `P2`. Stop
  feeding the loop and merge instead.
- **Re-scope before re-running.** If a bead is too big to bound, it's too big — split
  the secondary concern into its own bead and run only the core. (One reconcile bead
  shed its "downtime credit" half into a separate bead; the core then fit a single
  ~800-line module that bounded cleanly.)

**The recovery playbook when one blows up anyway:** do NOT just relaunch the same
run unchanged — it will blow up the same way. (1) Discard the wreckage back to the
saved pre-run state (`git reset`/`checkout`/`clean`, or apply your pre-run snapshot).
(2) Re-scope: split off the secondary concern as its own bead. (3) Re-run with the
file-lock and a low `--max-rounds` checkpoint, watching each round — keep the default
severity so real P2 polish still lands, raising the floor only if remaining P2s turn
into gold-plating. (4) At each checkpoint, decide: if the remaining findings are legitimate
and the code is sound, relaunch for more rounds to finish; if only a P1 or two are
left and another full pass isn't worth it, apply those fixes yourself, re-run the
repo's gates, and commit. A bounded run not closing every finding in one go is
expected — finishing the last mile by hand or with one more batch is normal, not a
failure.

## Backlog dogfooding

Running rb-lite across a queue exposes workflow bugs. Capture them as beads
while the evidence is fresh:

- If rb-lite fails for a reason unrelated to the bead (tool crash, reviewer
  panel failure, auth/config breakage, task parser bug, ignored-files problem,
  or implementer self-interference), file a fresh bead with
  `"$BEADS_JSONL_RESOLVER" --run-br create -t bug -p <0|1|2> -l dogfood,rb-lite "..." -d "..."`. Include
  observed behavior, repro trace, expected behavior, likely fix options, and
  acceptance criteria.
- If the dogfood bead is P0 or P1, interrupt the queue and fix it next. Since
  rb-lite is stateless, record the interrupted bead id, branch, run dir, and
  JSON status; after the dogfood fix lands, restart rb-lite on that bead with
  the same task file.
- If the dogfood bead is P2 or lower, file it and keep moving.
