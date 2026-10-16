---
name: delegate-to-manager
description: >-
  Act as the owner's assistant and run a project through a fresh "manager" subagent that does the
  actual work: grilling, triage, panels, rloop Runs, spec edits, reviews and PRs. The assistant relays
  in both directions, filters noise and mechanical detail, watches long jobs, and starts a clean
  manager at each phase boundary. The owner keeps every real decision. Use this whenever the owner
  says "be my assistant", "launch the manager", "delegate this", "spawn a manager", or "run the next
  bead through a manager". Also use it when they want work driven "without filling my context" or say
  their workflow is too repetitive to steer by hand, and when resuming a delegation that is already
  running.
argument-hint: "[first task, e.g. 'triage the next bead']"
---

# Delegate to a manager

Three roles:

| Role | Who | Does |
|---|---|---|
| **Owner** | the human | makes the decisions |
| **Assistant** | you, the main session | keeps the brief, relays, filters, watches waits, decides boundaries, writes memory |
| **Manager** | a fresh background subagent | all the repo work: reads, grills, triages, runs panels and rloop, edits, reviews, PRs |

The point is context hygiene and less repetitive steering. Every phase starts in an empty manager
context, so it reasons sharply. Your own context stays thin because file dumps, gate logs and
skill bodies land in the manager's window, not yours. If you catch yourself reading spec files or
running gates in the repo, stop and hand the work to the manager instead.

## 1. Set up

1. **Orient lightly.** Find the repo, its tracker, its `AGENTS.md`, and the owner's memory entries
   for the project (grep `MEMORY.md`). Don't read large files yourself.
2. **Write the brief.** Fill in [references/manager-brief-template.md](references/manager-brief-template.md)
   and save it to your scratchpad as `manager-brief.md`.
   - Keep it lean. It points to files and never inlines them. Memory files are read **per activity**
     through the table in the template, not all up front. A manager told to read every memory file up
     front used about 110k tokens before it started work.
   - Copy the project's **hard safety lines** verbatim from memory or CLAUDE.md: production systems
     not to touch, what must be redacted from public repos, how credentials are fetched, and who merges.
3. **Spawn the manager.** Use the Agent tool with `subagent_type: general-purpose`, `model: opus` and
   `run_in_background: true`. The prompt says: read the brief first and follow it all session, then
   gives the task in one or two sentences. Use a fresh agent, not a fork: a fork inherits your whole
   context, which defeats the purpose.
4. Tell the owner in a few lines how the split works, then wait for the notification. Never predict
   or invent what the manager will report.

## 2. Relay loop

The manager ends each turn with exactly one of three things: a **question**, a **report**, or a
**wait**.

**A question.** Before you put it to the owner:
- **Already settled?** If a recorded decision answers it (an ADR, a memory feedback rule, the standing
  workflow, an earlier answer in this session), answer it yourself. Tell the owner in one line which
  source settled it, so they can overrule you.
- **Technical, but no panel yet?** If the question turns on technical mechanics (how requirements
  interact, crash or concurrency semantics, the formal model, wire or schema shape, what a text
  actually forces), send it back to the manager and have it run the panel first. Questions of
  preference, scope, priority or cost go straight to the owner.
- **Otherwise, put it to the owner:**
  1. a short story in plain terms of what goes wrong;
  2. then `AskUserQuestion`, with the recommended option first;
  3. then the IDs it rests on.

  Leave out SHAs, gate output and retries unless something failed.
- **Panel results:** relay them faithfully, never polished. Give which option each reader picked and
  its strongest argument, plus any claim of yours or the manager's that a reader broke.

**A report.** Summarise it for the owner in a few lines: what changed, what's next, and what they
must decide. Update the brief's "Current state" section, and the project memory if durable state
changed. You own memory writes; the manager only suggests them.

**A new standing rule from the owner** (for example "always panel technical questions first"): send
it to the live manager now, add it to the brief so the next manager inherits it, and save it to memory.

**A wait** (rloop Run, panel, CI, bot round). The manager has launched the job and handed you a watch
condition. You do the mechanical watching (section 4).

Reply to the manager with `SendMessage`, using the agent ID from the spawn result. Keep the message
short:
- the decision, attributed ("The owner picked A");
- what to do now;
- what to end its turn with;
- what not to do, such as "don't push", "don't merge" or "don't implement yet".

## 3. Phase boundaries

When a phase ends (triage done, Run done, review done, PR merged), decide continue or clear. If the
owner uses the `ask-matt` skill, ask the manager to apply it. Have it read `ask-matt/SKILL.md` and its
`PHASE-BOUNDARIES.md`, then answer in three lines or fewer: the boundary option, the next step, and
anything the next manager needs that isn't already on the bead or branch.

- **Continue:** keep sending messages to the same agent.
- **Clear:** update the brief's state section, then spawn a **new** Agent with the same brief and the
  next task. A manager near ~150k tokens is due for a clear whatever the tree says.
- **Compact:** have the old manager write a summary file to your scratchpad, then spawn a new one
  pointed at it.
- When the answer is obvious (the context is full and the next phase is unrelated), skip the ask and
  tell the owner you skipped it.

**Keep going in an authorised lane.** If the standing workflow already authorises the next step (for
example, triage marked it ready-for-agent, so an rloop Run follows; or a review passed, so a PR
follows), start it, mention that you did, and offer to hold. **Merging always goes to the owner.**
Quote the merge gate's verdict line in the question.

## 4. Watching long jobs

- **One event** ("tell me when the exit file appears"): use a Bash `run_in_background` until-loop with
  its own deadline. Read any watch script the manager wrote before you run it.
- **Progress** (rloop rounds): use a Monitor with a tight filter. Show new rounds, failures and the
  exit, not every phase. Re-arm it on its 30-minute expiry.
- **Every terminal state needs a line,** including "unit gone, no exit file". Silence is not success.
- **Read the result from systemd when unsure.** If an exit file looks wrong, read the unit's result
  with `systemctl --user show <unit> -p LoadState -p Result -p ExecMainStatus` and from its `out`
  file. Trust `Result` only beside `LoadState=loaded`. A `--collect` unit is unloaded once it exits,
  and `show` then prints `LoadState=not-found`, `Result=success` and `ExecMainStatus=0`, even for a
  unit that failed. Then `out` and `err` are the only record.
- When the wait ends, send the manager the result line and the next instruction.
- The owner sees one short line per meaningful event. Report a round starting over, or an exit;
  don't narrate probes.

## 5. Owner-only skills

Some skills carry `disable-model-invocation: true`: the mattpocock `triage`, `grill-with-docs`,
`ask-matt`, `implement`, `to-spec`, `to-tickets`, `wayfinder` and `handoff`. The Skill tool refuses
them for any agent.
- Do **not** ask the owner to type them into your session. That loads the skill body into your
  context, and the owner rejected it because the phase must start in an empty context.
- When the owner asks for one, the manager finds its `SKILL.md` (for example with
  `find ~/.claude/plugins/cache ~/.claude/skills -path '*/<name>/SKILL.md'`) and follows it. The
  owner's request is the invocation. The brief says the manager never starts one on its own initiative.
- Skills without the flag (`grilling`, `domain-modeling`, `code-review`, `tdd`, the PR skills) are
  invoked normally with the Skill tool. `grill-with-docs` only wraps `grilling` and `domain-modeling`,
  so a manager can grill without it.

## 6. Don'ts

- **Don't edit the repo while the manager owns it.** Two writers on one worktree collide. Changes
  outside the repo that the owner asks you for directly are fine.
- **Don't let the manager talk to the owner.** It never uses `AskUserQuestion`. It ends its turn with
  one question; grilling skills that ask "the whole frontier" are overridden to one question per turn.
- **Don't relay a denied tool call as a workaround request.** If the manager reports a refusal, bring
  it to the owner.
- **Don't quote the manager's internal agent ID or transcript paths** to the owner.
