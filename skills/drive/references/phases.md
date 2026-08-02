# Phase mechanics

One section per phase: how to enter, what to run, what proves it closed, and what to do
when it fails. The driver reads only the section for the phase it is entering.

---

## SHAPE — prose goal → reviewed spec

**Enter when:** the goal is prose and no reviewed spec covers it.
**Skip when:** the change is ≤ a couple of lines, or a current spec already covers it.

The user's standing instruction, said near-verbatim across projects:

> "don't direct implement it. generate a detailed spec and let codex review it many times
> with the review loop then implement it using the rb-lite skill"

Treat that as the default for anything non-trivial.

1. If the domain is fuzzy, interrogate first — `grill-with-docs` when the repo has
   `CONTEXT.md`/ADRs worth sharpening against, `grill-me` otherwise, `planning-workflow`
   or `spec` for greenfield structure.
2. Write the spec to `docs/specs/<slug>.md`. It must be **buildable**: concrete file
   paths, named types, the failure modes, and the verification obligations. A spec a
   fresh agent cannot execute from is not done.
3. Commit it, then review it — repeatedly, not once. Pin the model and effort explicitly:
   inheriting the user's defaults would let a low-effort pass satisfy a gate that says
   xhigh.
   ```bash
   codex review --base <spec-base-commit> \
     -c 'model="gpt-5.6-sol"' -c 'model_reasoning_effort="xhigh"'
   # no PROMPT arg when --base is used — they are mutually exclusive
   ```
4. Apply findings, re-commit, re-review. Loop until a pass returns no P0/P1.
5. For plan-shaped work, `plan-eng-review` / `plan-ceo-review` add a product lens.

**Exit gate:** spec committed **and** a codex xhigh pass returns no P0/P1. Quote the pass.

**Failure:** reviewers keep finding fundamentals → the design is unsettled, not the prose.
Run a `codex exec` **design-advice** pass (ask for the minimal correct mechanism and *all*
consumers of the new invariant) before writing more spec.

---

## GRAPH — spec → executable bead graph

**Enter when:** a reviewed spec exists with no bead graph covering it.
**Skip when:** the work is a single bounded bead — just build it.

1. `plan-to-beads-transfer` — beads must be self-contained. A fresh agent executes from
   the bead alone, without reopening the spec.
2. `bead-polish-loop` — coverage, dedup, dependency shape, sizing, priority, verification.
3. `second-model-bead-audit` — the default final gate. A conditional/failed verdict feeds
   accepted findings back into one more focused polish round, then re-audits.

**Exit gate:** audit verdict PASS and a **scoped** ready bead exists — `br ready` filtered
through `DRIVE.md`'s `Scope:` line, not the raw repository count.

**Failure:** the audit says coverage is thin → the *spec* is thin. Go back to SHAPE for
the uncovered area rather than inventing beads to paper over it.

---

## BUILD — one bead → one branch

**Enter when:** `br ready` has a bead **inside the goal's scope**.

Scope first, then pick. The scope is the `Scope:` line in `DRIVE.md` — one canonical
definition every phase reads. If the goal named a bead, epic, or milestone, only beads in
that set are eligible, and DONE means *that set* is empty — not the whole repository
backlog.
A bare `br ready` in a repo with unrelated work will happily hand you a higher-priority
bead the user never asked for, and the drive would then build, review, and **merge** it
autonomously. Draining the entire backlog is a legitimate goal, but only when the user
actually said so ("drain the backlog"), never as a side effect of a scoped request.

Write it to `DRIVE.md`'s `Scope:` line before the first bead, so a resumed session
inherits the boundary along with the goal. Within scope, take the
highest-priority bead; ties break toward whatever unblocks the most work.

One bead = one branch = one rb-lite run = one PR = one squash merge = one bead closed.
Never two runs on one branch, never two beads in one run.

Write the task file with the scope budget from Guard 2 — exact file list, LOC budget,
explicit **do NOT build** list, done-definition naming the tests.

Resolve `rb-lite` the way `orchestrating-with-rb-lite` does — PATH first, then the Nix
wrapper. Do not hardcode a local checkout path; most installs will not have one.

```bash
if command -v rb-lite >/dev/null 2>&1; then RB=(rb-lite)
else RB=(nix run --refresh github:douglaz/rb-lite --); fi

"${RB[@]}" run \
  --implementer claude,codex \
  --task-file <task> \
  --base <default-branch> \
  --branch <bead-id>-<slug> \
  --run-dir <scratchpad>/<bead-id>
```

Launch it **as the `run_in_background` command with no trailing `&`** — a trailing `&`
detaches it from the tracked wrapper and you lose the completion notification.

Watch each round. Two proxies flag overengineering (round count climbing, LOC far past
comparable beads); confirm by re-reading the goal. Hard brake at 2× budget or round 4.

**Known traps:**
- rb-lite leaves changes **uncommitted**. It also runs `cargo fmt` — a focused fix can
  come back having reformatted the whole workspace. Check the real hunks and revert
  fmt-only churn with `git checkout <base> -- <files>`.
- **Codex reviewers are blind to untracked files.** A new module left untracked produces a
  false "module missing / fails to compile" P1 every round. `git add` new files early;
  recognize that finding as the blind-codex tell, not a defect.
- Exit 143/137 with no output usually means another session's broad `pkill` collateral-
  killed the run. Retry — do not abandon rb-lite.
- Before relaunching a seemingly-stalled run, check `ps -eo pid,etimes,args | grep rb-lite`.
  A long iteration is not a dead run, and `TaskList` can glitch empty. Never
  `pkill -f` (it self-matches your own shell and hits other sessions) — kill by exact PID.

**Exit gate:** rb-lite exits clean **and** you independently ran the gate to a real exit
code. The panel reads code; it does not run it.

---

## PROVE — the gate must actually run

**Enter when:** the deliverable *is* a test or gate, or the change touches money,
consensus, data-loss, or live infra.

**One run per branch still holds.** `testing-with-rb-lite` starts its own rb-lite run, so
running it on a branch that already had a BUILD run would be the second run on that branch
— and that skill authors tests, not features, so it cannot finish the bead either. Pick one:

- **Fold the proof into BUILD** — name the gate in the BUILD task's done-definition so the
  same run produces feature and test together. Preferred for a bead that is mostly code.
- **Cut a separate test bead on its own branch** and run `testing-with-rb-lite` there.
  Preferred when the gate is substantial (a live e2e, a property suite) or the feature has
  already landed.

Either way the non-negotiables below apply.

Two non-negotiables:

1. **Run it yourself**, unpiped:
   ```bash
   <gate-cmd> > /tmp/gate.log 2>&1; echo "EXIT=$?"
   ```
2. **Make it fail first.** Point the new test at the unfixed code and watch it go red.
   A test that could never have failed proves nothing.

**Exit gate:** the gate ran, printed green, and you quoted the command and exit code.

---

## HARDEN — reviewer panel until clean

**Enter when:** the branch carries substantive unreviewed code.

1. `multi-reviewer-loop` — codex plus Claude Fable in parallel each pass. Their
   disagreements are the highest-signal moments. Findings both raise get fixed first; a
   finding only one raises still gets the full evidence bar, because the other reviewer's
   silence is not counter-evidence.
2. If one reviewer is unavailable the loop runs **degraded** and must say so — and a
   degraded run cannot reach `CLEAN`, only `CLEAN_DEGRADED`. That is not this phase's
   exit gate, so do not grind passes toward a verdict the run can no longer produce:
   fix the reviewer (auth, install) and re-run, or stop and tell the user HARDEN
   finished degraded and why. Never report a one-reviewer pass as clean.
3. Then a **final gate on the committed diff**, which reliably catches P2s the P1-floor
   loop skipped:
   ```bash
   codex review --base <spec-or-merge-base> \
     -c 'model="gpt-5.6-sol"' -c 'model_reasoning_effort="xhigh"'
   ```
   Budget ~2 fix rounds of narrow P2 edges on delicate paths, then hold the line and
   surface further P2s to the user rather than auto-chasing them.

Re-verify the build and tests yourself after every fix round. **And re-run the panel after
any final-gate fix** — once you change code, the earlier clean verdicts no longer cover the
diff you are about to ship, so "both reviewers clean" would be a claim about an older tree.
Re-running builds and tests is not a substitute: they never saw the finding in the first
place.

**Exit gate:** `multi-reviewer-loop` reports `CLEAN` — which means both reviewers clean
**and** its § 4b consistency pass clean, on the same tree. `CLEAN_DIFF_ONLY` is not
enough: it says the changed lines are fine and nothing checked whether the files still
agree with each other. Plus the final gate clean, and the gate green at a real exit code.

---

## LAND — PR through the bots

**Enter when:** the branch is clean, reviewed, and gate-green.

Follow `pr-with-codex-bot-review`. The parts that bite:

- Run a local Fable pre-review **before** pushing so the bot rounds start from the good
  diff.
- The codex bot's line-level findings live in **PR review comments**, not the review body.
  Read both.
- It auto-fires on substantive code PRs and is often silent on docs-only PRs. Silence on a
  docs PR is not a failure; re-trigger with `@codex review` when you need a pass.
- Address findings by amend + force-push **to your own PR branch** (allowed; force-pushing
  over someone else's work is stop-list).
- After any amend, the codex `+1` may still be the *previous* head's. Compare the wrapper's
  `Reviewed commit:` SHA against the tip before merging, not the reaction.
- A CodeRabbit `SUCCESS` that says `Review skipped` is not a review. Read the "Files
  skipped from review" list; re-trigger unless the skip was expected.
- Squash-merge, then **discard the uncommitted `Cleared:` marker before switching branches**
  (`git checkout -- DRIVE.md`). It is a tracked file differing between branches, so
  `git checkout <default>` otherwise aborts and leaves the PR merged but nothing cleaned up.
- Reset the local branch.

**Exit gate:** merged at the SHA both bots cleared, branch reset, bead closed
(`br close <id>`), `DRIVE.md` updated — the last two through a reviewed path.

`DRIVE.md`'s move to `**Phase:** LAND` belongs in the final pre-HARDEN sweep, so the panel
clears a tree that already carries it and nothing is added between clearance and merge.
See `SKILL.md` § "Bookkeeping goes in before the panel, or through its own PR".

`br close` cannot: closing before the merge marks work done that may never land, so the
closure is inherently post-merge. It writes `.beads/*.jsonl` on the default branch, and
committing it there is exactly the unreviewed-bookkeeping failure LAND now forbids. Do not
leave it uncommitted either — the next BUILD would start from a dirty base and silently
carry the previous bead's closure into its diff. Instead:

- **A scoped bead remains** → carry the closure commit (plus the `DRIVE.md` update) into
  the next bead's branch, where it rides that PR through the panel and both bots.
- **The scope is empty** → there is no next branch, and reporting DONE while a fresh clone
  still shows the bead open is a lie. Open one small metadata PR (bead closure + final
  `DRIVE.md`) and land it through the same gates. DONE is not reached until it merges.
  Write that `DRIVE.md` as `**Phase:** DONE · **Pending:** metadata PR #N`, so a session
  resuming after a restart queries `#N` instead of stopping at a DONE that has not landed.

Either way the tree is clean before BUILD re-enters, and nothing reaches the default
branch unreviewed.

Then go straight back to BUILD if a **scoped** ready bead remains — `br ready` filtered to
the goal's bead set, exactly as at BUILD entry. That loop is the whole point; do not stop to
ask whether to take the next bead *inside* the scope.

A bare `br ready` here re-opens the scope escape the entry check closes: the named scope
empties, an unrelated repository bead is ready, and the loop builds, reviews, and **merges**
work the user never authorized. When the scope is empty, the drive is done — even if the
repository still has ready beads. Say so and stop.

---

## DONE

**Within the goal's scope**, `br ready` is empty and so is the unresolved set — bare
`br list` (there is no `br open` subcommand; bare `br list` is open + in_progress, excluding
closed). Scope matters here as much as at BUILD entry: a scoped goal is DONE when *its* set
is empty, not when the repository is. Waiting on the global backlog turns a finished
milestone into an open-ended drain the user never asked for.

Report what landed, what is deferred and why, and stop. This is the one place a summary is
legitimately the end of the turn.

`drive-status` counts globally — it has no way to know your scope — so its `DONE` and its
bead numbers are repository-wide. Filter them against the scope in `DRIVE.md` yourself
before believing them.

If `br ready` is empty but the unresolved set is **not**, you are not done: every remaining
bead is blocked or deferred. That is a graph problem — re-audit dependencies and deferrals
in GRAPH rather than hunting for a bead to build. `drive-status` flags this case explicitly.
