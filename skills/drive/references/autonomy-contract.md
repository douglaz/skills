# The autonomy contract

Why each rule in this skill exists. Derived from 8,810 real user messages across 2,611
sessions in `~/.claude/projects` (analyzed 2026-08-01). Every rule below traces to a
measured intervention — a turn the user had to spend telling the agent to do something it
should already have done.

Read this when tempted to relax a rule, or when adding a new one.

---

## 1. The continuation tax — the single biggest leak

| Message | Count |
|---|---|
| `continue` | 195 |
| `status?` | 101 |
| `do it` | 77 |
| `/loop` (manual self-pacing) | 125 |
| `continue from where you left off.` | 18 |
| `commit/push`, `commit it`, `push it`, `add/commit/push` | ~20 verbatim |
| `call codex to review everything` / `call codex again` / `call codex and fable again` | ~20 |

451 nudges were traced back to the assistant's preceding message:

- **23% followed a direct question** — "Want me to do X?", "Should I...?", "worth doing a
  release build first?"
- **22% followed a summary that simply stopped** — the work was done, the next step was
  obvious, and the turn ended anyway.
- **10% followed a background-job wait** — "I'll report when codex finishes", then idle.

Actual samples of what preceded a `continue`:

> "So the toolchain is ready; the remaining work is the step-2 source split. Want me to do
> Option A and scaffold the index.html so we can attempt a real trunk build?"

> "Want me to implement those three wasm-only changes and deploy them for you to test on
> Chrome? They can't black-screen (config only), and I'll verify the WebGL2 render still
> works headless before shipping."

Both describe work that is *unambiguously inside the authorized lane*, *reversible*, and
*already reasoned through*. The question added nothing and cost a round trip.

**Rule:** state the next step and take it. This had already been captured as a standing
preference; what was missing was per-phase enforcement, which is what this skill provides.

---

## 2. Verification demands — 14.5% of all messages

Phrases like "are you sure", "did you actually", "prove it", "show me the output",
"don't just assume", "is it really passing".

> "have codex and claude build an end-to-end gate for the checkout flow and verify it goes
> green on a real run — **i don't trust a test that was only reviewed**"

> "use rb-lite to add integration coverage ... and make sure the tests **actually run
> green**, not just that codex+claude sign off on the source"

> "the fee calculator keeps getting off-by-one regressions. can you get rb-lite to write a
> property test for it and run it **enough that we're actually confident**?"

This is a standing, repeatedly-restated requirement, not a per-task preference. It already
justified an entire skill (`testing-with-rb-lite`).

There is also a known concrete failure: piping `check.sh` through `tail` reported exit 0
on a red clippy gate, and a broken commit got pushed.

**Rule:** Guard 1. Evidence with a real exit code, never piped, or the phase does not
close. Make new tests fail first.

---

## 3. Gates that had to be fired by hand — 1,303 messages

The user routinely supplies the *sequencing* the agent should already know:

> "call codex one more time on code, fix issues, commit then continue on next steps"

> "commit/push then run codex again"

> "write the spec then call codex review xhigh on it, then commit/push and call codex one
> more time, then before implementing we want to write detailed buildable implementation
> specs then review them with codex xhigh"

> "fix upstream using rb-lite. keep debug for now. make sure to review upstream with codex
> and fable before marking the pr as ready. after marking as ready, address any issues.
> only then go to 7qc"

That last one is a whole pipeline typed out by hand. It is the same pipeline every time.

**Rule:** Guard 3. Commit → push → next reviewer is part of the transition, not a separate
request. The phase table encodes the sequence so it never has to be dictated again.

---

## 4. Overengineering — 488 messages

> "yeah, overengineering is one of the biggest risks for this project. let's do it again.
> perhaps be more specific about what needs to be accomplished"

> "I'm a bit divided on this. using the hexagonal architecture, with all the traits and
> abstractions usually lead to overengineering ... **how could we avoid overengineering on
> this project?**"

> "just one thing, doing the payment should be out of scope for the cli"

Concrete blowup: one project's config bootstrap reached **~3,000 lines** with data-dir
permission hardening far beyond the milestone's single-operator threat model, because the
review loop ratchets — each round's reviewers find deeper edges, and feeding them all back
drives bloat.

The user's own refinement: the real control is **watching each round and intervening when
the code starts degrading**, not blunt pre-set caps. Caps are backstops and checkpoints.

**Rule:** Guard 2. Declare the budget and the do-NOT-build list up front; file-lock from
round 1; treat round count and LOC as *flags* that trigger a goal-vs-complexity re-read,
not as verdicts; hard-brake and report at 2× budget or round 4.

---

## 5. Design-first on cross-cutting changes

On one apparently-bounded bead, the scope cascaded: each review round revealed another
consumer of the same boundary, and the fix was re-scoped one file wider per round (3→4→5).
The user rejected the resulting question, asked for the mechanism to be re-explained, and
chose **"design it properly first."** That was right — the clean design (a non-moving floor
column every consumer reads) only emerged after a design pass.

**Rule:** stop-list item 3. A *second* review round adding another consumer of the same
concept is the tell. Stop expanding the file-lock; run a design-advice pass that enumerates
all consumers of the new invariant, then write one task spanning the whole boundary.

---

## 6. Context loss — 244 messages

"you already did", "we already discussed", "as I said", "like I said". Plus 101 `status?`
messages that are purely a request for state the agent should have been volunteering.

**Rule:** Guard 4. `DRIVE.md` at the repo root, rewritten at every transition, committed
with the work. It answers `status?` before it is asked and lets a fresh session resume
without re-deriving anything.

---

## What is deliberately NOT automated

Autonomy is not the goal; *correct* autonomy is. These stay with the human because the
transcripts show the user actively wants them:

- **Money-path and consensus design forks.** The user consistently engages deeply here
  ("why does an operator need money?", "reconsider the fix, I thought the logical fix was
  different DBs"). Surface these.
- **Product and UX taste.** Copy, layout, what a feature should feel like — the user has
  strong specific opinions and corrects them readily.
- **Domain-model correctness.** Long, substantive corrections about economics, physics, and
  protocol semantics. The agent cannot infer these; ask.
- **Anything irreversible or outward-facing.** Unchanged from the base rules.

The line: **automate the mechanics, escalate the judgment.**
