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

Then **record the clearance**, which is what admits LAND. Assert the base is fresh in the
same breath: a panel that cleared a branch already behind base cleared a tree that is not
the one that will land.

Three preconditions, all of which must hold, and every one of which has bitten:

1. **The tree is clean.** `multi-reviewer-loop` deliberately leaves its fixes uncommitted,
   and reviews tracked working-tree changes — so `git rev-parse HEAD` at that moment names
   a commit that does *not* contain what was just reviewed. Recording it would make
   `cleared == tip` true while the reviewed fixes are absent from the commit and the PR.
   Commit first, then clear.
2. **The fetch succeeded.** A failed fetch leaves a stale tracking ref, and an ancestry
   check against a stale ref reports fresh when it is not.
3. **The base is an ancestor of the tip** — via `drive-status`, not a hand-rolled check.
   It already resolves `origin/HEAD`-unset clones, non-`main`/`master` defaults, and the
   `gh` fallback; reimplementing a two-branch version here would refuse to clear in any
   repo defaulting to `develop` or `trunk`.

```bash
DS=<the drive-status path resolved in Phase 0>
[ -z "$(git status --porcelain)" ] || { echo "tree dirty — commit first, do NOT clear"; exit 1; }
git fetch -q origin || { echo "fetch failed — base unknown, do NOT clear"; exit 1; }
[ "$("$DS" --json | jq -r '.base_fresh')" = "true" ] || { echo "REBASE FIRST — not cleared"; exit 1; }

STATE=$(git rev-parse --git-path drive/state)
mkdir -p "$(dirname "$STATE")" && printf 'cleared=%s\n' "$(git rev-parse HEAD)" > "$STATE" \
  || { echo "could not persist clearance"; exit 1; }
echo "cleared $(git rev-parse --short HEAD)"
```

Each check `exit 1`s rather than warning: a printed warning followed by an unconditional
write records clearance anyway, which is exactly what admits derived LAND.

Nothing is committed here — that is the point. A commit would change the SHA this file
just recorded as reviewed.

---

## LAND — PR through the bots

**Enter when:** the panel cleared this checkout, `cleared` still equals the tip, the base
is an ancestor of the tip, and the worktree is clean. Those three are what LAND is derived
from; the gate was HARDEN's exit condition and is already spent by the time LAND is
reachable — the detector cannot check it and does not claim to. LAND is *derived* from those facts,
never read from `DRIVE.md` (ADR 0002) — a record claiming LAND is a stale or hand-edited
file and `drive-status` will say so.

### The three checks, before you merge

**1. The tip is the tree that was reviewed.** Name the SHAs and refuse if they differ:

```text
panel cleared : <sha>          # $(git rev-parse --git-path drive/state)
bots cleared  : <sha>          # the codex wrapper's "Reviewed commit:", NOT the +1
tip           : <sha>
```

Take the bots' SHA from the review wrapper, not the reaction — a `+1` carries no SHA and
survives a force-push, so a stale one reads exactly like approval of the current head:

```bash
gh api --paginate --slurp repos/<owner>/<repo>/pulls/<N>/reviews \
  | jq -r '[.[][] | select(.user.login|startswith("chatgpt-codex-connector"))
            | .body | capture("Reviewed commit:[^0-9a-f]*(?<sha>[0-9a-f]{7,40})").sha] | last'
```

Collect across pages and take `last`: the endpoint returns reviews oldest-first, and after
several rounds a bare stream prints one SHA per round with no indication which is current.
(`--slurp` cannot combine with `--jq`, hence the pipe.)

If the codex bot reacted `+1` with no wrapper, you have no SHA anchor: `@codex review` and
wait for one. CodeRabbit's check is per-commit, but a `SUCCESS` may be a *skip* — read the
"Files skipped from review" list and re-trigger unless the skip was expected.

**2. Do not demand `merged SHA == reviewed SHA`.** The merge is a squash, so it always
creates a new commit; that equality is unsatisfiable by construction.

Pin the head in the merge itself — `gh pr merge <N> --squash --match-head-commit "$(git rev-parse HEAD)"`
(the **full** OID; the wrapper's SHA may be abbreviated, which would refuse every merge).
Between comparing SHAs and merging, another push can land; `--match-head-commit` makes the
merge refuse rather than take the newer, unreviewed head. Base drift in that same window is
*not* closed by any local check — only branch protection or a merge queue does that, which
is per-repo config this skill cannot assume.

**3. The base is still an ancestor of the tip** — checked when the panel clears **and**
again immediately before merging:

```bash
DS=<the drive-status path resolved in Phase 0>
git fetch -q origin || { echo "fetch failed — base unknown, do NOT merge"; exit 1; }
[ "$("$DS" --json | jq -r '.base_fresh')" = "true" ] || { echo "REBASE FIRST"; exit 1; }
```

Both `exit 1`. This is the last check before the merge, so a warning that returns 0 lets
`gh pr merge` run anyway — and a failed fetch leaves a stale tracking ref, which makes the
freshness test pass on information that is simply old.

Through `drive-status`, not a hand-rolled `merge-base` — same reason as HARDEN's
precondition 3: only the detector resolves `origin/HEAD`-unset clones and non-`main`
defaults, and a two-branch version here would refuse in any repo defaulting to `develop`.

This is the check with no other symptom. A squash merge replays the branch onto the
*current* base, so if the default branch advanced after clearance, what lands is a
combination no panel and no bot ever saw — while every SHA above still matches. Git merges
any textually non-conflicting branch behind base, so the failure is silent and semantic.
If it fails: rebase or merge base in, then re-clear (which means a new panel run).

### Bot rounds re-arm the panel

Address findings by amend + force-push **to your own PR branch** (allowed; force-pushing
over someone else's work is stop-list). Then:

- The codex bot's line-level findings live in **PR review comments**, not the review body.
  Read both. GitHub re-anchors an unresolved comment's `commit_id` to the newest commit
  while it still applies, so a "new" finding may be an old one carried forward — check
  `created_at`, not `commit_id`, before concluding a fix was rejected.
- It auto-fires on substantive code PRs and is often silent on docs-only PRs. Silence on a
  docs PR is not a failure; re-trigger with `@codex review` when you need a pass.
- **Every amend invalidates clearance, so re-run the full local panel.** The amended tree
  is one no panel has read, and the local panel is stronger than the bots. Re-clear, then
  let the bots re-review.
- **Cap: 3 bot rounds.** Past that, stop and report rather than looping — a PR still
  producing findings after three rounds is telling you the change is wrong-shaped, not
  that it needs a fourth patch. That is a stop-list item.

Run a local Fable pre-review **before** the first push so the bot rounds start from the
good diff and the cap is spent on real findings.

### Squash-merge, then clean up

**Exit gate:** merged at a tip every configured bot cleared, with a fresh base, branch reset, bead
closed (`br close <id>`), `DRIVE.md` updated — the last two through a reviewed path.

`br close` cannot ride this branch. It is tempting to think it can: `.beads/issues.jsonl`
is tracked, so a closure committed on the branch looks transactional. **It is not** — see
ADR 0003, which records the code evidence, because this is attractive enough to be
re-proposed. In short: `br close` auto-flushes immediately, the local SQLite DB is shared
by every branch with no git awareness, and import is last-write-wins on `updated_at`, so
the default branch's older OPEN record loses to the branch's newer closure. The closure
leaks across the checkout and nothing errors.

So closure is genuinely post-merge, and must not be committed straight to the default
branch. Do not leave it uncommitted either — the next BUILD would start from a dirty base
and silently carry the previous bead's closure into its diff. Instead:

- **A scoped bead remains** → carry the closure commit (plus the `DRIVE.md` update) into
  the next bead's branch, where it rides that PR through the panel and the configured bots.
- **The scope is empty** → open one small metadata PR (bead closure + final `DRIVE.md`)
  and land it through the same gates. Write it as `**Phase:** DONE · **Pending:** metadata
  PR #N` so a resumed session queries `#N` instead of stopping at a DONE that never landed.
  `N` does not exist until the PR is open, so amend it in afterwards — the first pushed
  head is never the one that merges.

And verify the closure actually happened. `br close` exits 0 even when the flush that
writes the JSONL failed, because the error is caught and logged at debug level:

```bash
br close <id>; git status --porcelain -- '*.beads*.jsonl'   # must be non-empty
```

The assertion holds only where a mutation definitely occurred, as it did here. A flush
over a graph that was already committed and unchanged legitimately reports nothing, so a
blanket "must be non-empty" would fail a healthy preflight.

Either way the tree is clean before BUILD re-enters, and nothing reaches the default
branch unreviewed.

Then go straight back to BUILD if a **scoped** ready bead remains — `br ready` filtered to
the goal's bead set, exactly as at BUILD entry. That loop is the whole point; do not stop to
ask whether to take the next bead *inside* the scope.

A bare `br ready` here re-opens the scope escape the entry check closes: the named scope
empties, an unrelated repository bead is ready, and the loop builds, reviews, and **merges**
work the user never authorized. When the scope is empty, the drive is done — even if the
repository still has ready beads. Say so and stop.


## DONE

**Within the goal's scope**, `br ready` is empty and so is the unresolved set — bare
`br list` (there is no `br open` subcommand; bare `br list` is open + in_progress, excluding
closed). Scope matters here as much as at BUILD entry: a scoped goal is DONE when *its* set
is empty, not when the repository is. Waiting on the global backlog turns a finished
milestone into an open-ended drain the user never asked for.

**Unless a `Pending:` PR has not merged.** A record reading `DONE · Pending: metadata PR
#N` means "DONE once #N merges" — the merged file cannot state its own post-merge status,
so the driver queries. `drive-status` reports that state as `WAITING_FOR_MERGE`, not
`DONE`, precisely so a resumed session goes and lands the PR instead of reporting a
finished drive whose closure is still open.

Report what landed, what is deferred and why, and stop. This is the one place a summary is
legitimately the end of the turn.

`drive-status` counts globally — it has no way to know your scope — so its `DONE` and its
bead numbers are repository-wide. Filter them against the scope in `DRIVE.md` yourself
before believing them.

If `br ready` is empty but the unresolved set is **not**, you are not done: every remaining
bead is blocked or deferred. That is a graph problem — re-audit dependencies and deferrals
in GRAPH rather than hunting for a bead to build. `drive-status` flags this case explicitly.
