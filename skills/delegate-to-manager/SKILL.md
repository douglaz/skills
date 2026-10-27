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
     not to touch, what must be redacted from public repos, and how credentials are fetched.
   - Set the **merge lane**. At the start of every session, ask the owner whether to run the drain
     lane (section 3), with "off" as the first option. Skip the question on a project in production:
     the lane stays off unless the owner asks for it. If memory records a rule about who merges,
     quote it in the question. The answer lasts for this session only: put it in the brief, never
     in memory, and never carry it over from an earlier session.
3. **Spawn the manager.** There is no default manager. If the owner named one in this session, or a
   memory rule records their standing choice for this project, use it and say which in one line.
   Otherwise ask with `AskUserQuestion`, no option marked recommended: an Opus subagent or a sol
   manager (section 7). If the project runs rloop, settle its Manager (`--manager`,
   `--manager-model`) the same way. Put the choices in the brief.
   For an Opus manager, use the Agent tool with `subagent_type: general-purpose`, `model: opus`,
   `effort: high` and `run_in_background: true`. Pass the effort explicitly: left out, the manager
   inherits the session's default, which may be `xhigh`. The prompt says: read the brief first and follow it all session, then
   gives the task in one or two sentences. Use a fresh agent, not a fork: a fork inherits your whole
   context, which defeats the purpose. For a sol manager, spawn it as section 7 says.
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
- what not to do, such as "don't merge" or "don't implement yet".

## 3. Phase boundaries

When a phase ends (triage done, Run done, review done, PR merged), decide continue or clear. If the
owner uses the `ask-matt` skill, ask the manager to apply it. Have it read `ask-matt/SKILL.md` and its
`PHASE-BOUNDARIES.md`, then answer in three lines or fewer: the boundary option, the next step, and
anything the next manager needs that isn't already on the bead or branch.

- **Continue:** keep sending messages to the same agent.
- **Clear:** update the brief's state section, then spawn a **new** Agent as in section 1 step 3,
  with the same brief and the next task. A manager near ~150k tokens is due for a clear whatever the tree says.
- **Compact:** have the old manager write a summary file to your scratchpad, then spawn a new one
  pointed at it.
- When the answer is obvious (the context is full and the next phase is unrelated), skip the ask and
  tell the owner you skipped it.

**Keep going in an authorised lane.** If the standing workflow already authorises the next step (for
example, triage marked it ready-for-agent, so an rloop Run follows), start it, mention that you did,
and offer to hold. **Push and PR are always authorised:** once work is committed and reviewed, the
manager pushes its branch and opens the PR without asking, and you report the link afterwards. Never
hold that step for a yes. **Merging goes to the owner** unless the drain lane is on. Quote the merge
gate's verdict line in the question.

**Drain lane.** On a greenfield or pre-production project draining a bead backlog, the owner can
delegate merging too. The lane is off unless the owner turned it on when this session started
(section 1). The owner's go-ahead is the human merge decision `pr-with-codex-bot-review` asks for.
The manager takes each bead from base to merged PR, then ends its turn. It stops early on the
conditions in the brief's "Drain lane" section. After each merge, you:
- give the owner one line with the PR, the bead, and `bot-gate`'s verdict, tip and observation
  window, quoted as the manager reported them;
- clear, and spawn a new manager on the next ready bead in the drain scope. That scope is what the
  owner asked for (an epic, a label, a list of beads), or every ready bead if they named none;
- don't ask in between.

A stop condition pauses the lane until the owner answers. The lane ends when the scope is empty,
when the session ends, or when the owner says "hold merges". On "hold merges", first set the brief's
lane to `owner` and delete its "Drain lane" section, then tell the live manager. The manager
re-reads the lane line before it starts each merge, so the hold stops every merge not yet started.
A merge sequence that is already running can still land. Check the PR's state and tell the owner
if it did.

## 4. Watching long jobs

- **One event** ("tell me when the exit file appears"): use a Bash `run_in_background` until-loop with
  its own deadline. Read any watch script the manager wrote before you run it.
- **Progress** (rloop rounds): use a Monitor with a tight filter. Show new rounds, failures and the
  exit, not every phase. Re-arm it on its 30-minute expiry.
- **Arm a wakeup past the usage-limit reset.** When a turn arrives with a "Usage limit reached" grace
  notice, arm one wakeup that outlives the reset before you end the turn. This cheap poll is the one
  exception to the notice's "don't start long work". Use a Bash `run_in_background` loop that polls
  `claude -p "/usage" </dev/null` every few minutes until its `Current session` line (the 5-hour
  window, not the weekly ones) reads under 100% used, or use a scheduled wakeup. On Claude Code
  2.1.293 that call exits 0 with the line on stdout and nothing on stderr, and it still answers while
  the session is capped. Take the reading, not the advertised reset time, which has come back hours
  early. A 30-minute Monitor or a 2-hour waiter can expire inside the limit, so re-arm the wakeup on
  every expiry until the poll sees the drop. Stop re-arming six hours after the notice (one window
  plus margin) and report the last reading. One night several sessions wrapped up under the notice
  with nothing armed, and sat idle about 12 hours past the reset until the owner typed.
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
- **Don't quote the manager's internal agent ID, thread id or transcript paths** to the owner.

## 7. A sol manager

When the owner chooses a sol manager (section 1 step 3), it is codex `gpt-6.1-sol` at
`model_reasoning_effort=xhigh`, run through the codex CLI, because the Agent tool only runs Claude
models.

**Every turn is a `systemd-run --user` unit.** A turn can take hours, and a Bash
`run_in_background` command is stopped at its timeout and with the session. Use one directory and
one unit per turn, and give every turn on a thread the same `<repo>` working directory:

```bash
# First write the turn's prompt to <scratchpad>/turn-prompt with your file-writing tool.
C=$(command -v codex); mkdir -p /var/tmp/manager-units
D=$(mktemp -d /var/tmp/manager-units/<repo>-$(date -u +%m%dT%H%M)-XXXXXX); echo "$D"
cp <scratchpad>/turn-prompt $D/prompt
systemd-run --user --unit=manager-$(basename $D) --collect --expand-environment=no \
  --working-directory=<repo> -E PATH -p KillMode=mixed -p TimeoutStopSec=120 \
  -p MemoryMax=16G -p MemorySwapMax=0 -p OOMPolicy=continue \
  -p "StandardOutput=file:$D/out" -p "StandardError=file:$D/err" \
  -p "ExecStopPost=/bin/sh -c 'printenv SERVICE_RESULT EXIT_CODE EXIT_STATUS | xargs > $D/exit.tmp && mv $D/exit.tmp $D/exit'" \
  "$C" exec <resume> --json --dangerously-bypass-approvals-and-sandbox \
  -m gpt-6.1-sol -c model_reasoning_effort=xhigh -o "$D/report" <thread_id> "$(cat "$D/prompt")"
```

- **Spawn:** leave out `resume` and `<thread_id>`. The prompt is the one from section 1 step 3.
  Write it with your file-writing tool, never by an `echo` or unquoted heredoc: messages carry
  backticks and `$`, and `"$(cat …)"` passes them to codex literally. The
  thread id is in the first line of `out`, `{"type":"thread.started","thread_id":"…"}`. Save it
  beside the brief.
- **Relay:** where section 2 says `SendMessage`, start a `resume` turn with the thread id and your
  message as the prompt.
- **Clear:** a new spawn turn with the same brief and the next task.
- **Watch:** every turn is a one-event wait (section 4). Use an until-loop on `$D/exit` with a
  deadline, and re-arm it on expiry until the exit file appears; the unit has no deadline of its
  own. `success exited 0` means `$D/report` holds the turn's last
  message, which is the manager's question, report or wait. Anything else: read `err` and the tail of
  `out`, and tell the owner. A fresh start prints `Reading additional input from stdin...` on `err`;
  that is normal, since a unit's stdin is already null. Stop a turn with
  `systemctl --user stop manager-<dir name>`.

What differs from the subagent:

- **No messages mid-turn.** The thread only reads input when the next `resume` turn starts, so
  never start a turn while the previous one runs. A new standing rule (section 2) goes into the
  brief at once and into the next `resume` message. "Hold merges" (section 3) still works, because the
  manager re-reads the brief's lane line before each merge.
- **No Skill, Agent or AskUserQuestion tools.** Codex uses a skill when the prompt or brief names
  it, from `~/.codex/skills`, where `install.sh` installs this repo's skills. For any other skill,
  including owner-only ones (section 5), give the path to its `SKILL.md`. Steps a skill runs as a
  Claude subagent, such as panel readers, run as `claude -p` or `codex exec` commands instead.
- **No sandbox and no deny list.** The bypass flag is required, because sandboxed codex cannot reach
  the nix daemon socket and cannot run gates (rloop-spec `AGT-10`). The brief's hard safety lines are
  its only fence. The brief's other rules hold as written: one question per turn, no owner-only
  skill on its own initiative, launch long jobs and return.

Checked on codex-cli 0.164.0, 2026-10-25, with trivial prompts: a start and a resume turn, both run
directly and as units like the one above, exited 0. Each resume reported the start's thread id and
recalled a word given in the start turn. The non-JSON resume banner and the start turns' session
files under `~/.codex/sessions` record `gpt-6.1-sol` with `xhigh` effort. With this exact unit line,
a start and a resume whose `$D/prompt` held backticks, `$(…)`, `$HOME`, quotes and `%n` echoed
them back unchanged. The commands, streams and
results are in [references/sol-manager-check.md](references/sol-manager-check.md).
