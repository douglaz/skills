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

One bead = one branch = one rb-lite run = one **work** PR = one squash merge = one bead
closed. (The closure that lands after the last bead may need its own small metadata PR —
see § LAND. That is bookkeeping, not a second work PR, and this rule does not forbid it.)
Never two runs on one branch, never two beads in one run.

Write the task file with the scope budget from Guard 2 — exact file list, LOC budget,
explicit **do NOT build** list, done-definition naming the tests.

Resolve `rb-lite` the way `orchestrating-with-rb-lite` does — PATH first, then the Nix
wrapper. Do not hardcode a local checkout path; most installs will not have one.

Write `.rb-lite-reviewers` before the run — the panel is codex + claude, both models
pinned, and the file is the only way to set it: rb-lite's built-in default lives inside
the binary and additionally runs Gemini through `npx -y`, which this stack does not use.
Take the two-reviewer file from `orchestrating-with-rb-lite` § Tool dependencies — write
it to a temp path and pass `--reviewers-file`, never `cat >` into the repo root (that
clobbers an existing panel, or leaves an untracked file the clean-tree LAND gate then
trips on). NOT the block under § Customizing the panel: it shows the same two commands
beside optional extras and a `my-linter` placeholder that runs as command-not-found.

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

**Exit gate:** rb-lite exits clean, you independently ran the gate to a real exit code,
**and** every load-bearing behavior the bead introduced has been inverted with a matching
assertion observed to fail. The panel reads code; it does not run it — and a suite that was
already green before the bead proves nothing about the bead. Most beads never reach PROVE
(that phase is for test-shaped deliverables and money/data/infra work), so if this evidence
is not required here it is required nowhere.

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
2. **Make it fail first — once per property, on the right assertion.** Point the new test
   at the unfixed code and watch it go red. A test that could never have failed proves
   nothing. Two refinements that decide whether the red run means anything:
   - **Read the failure.** It must name the assertion pinning the behavior you broke. An
     initialization error, a panic, or an unrelated assertion reddens without the test
     ever reaching the behavior, and taking that as proof certifies something nothing
     tests.
   - **One mutation per property.** A gate claiming two independent properties needs two;
     reddening the first leaves the second untested while looking verified.
   - Break the **production behavior**, never the test's expected value or its setup —
     those redden any assertion, including one that never runs. And for a live gate
     (real DB, running service, money), isolate first: a defective build can perform the
     bad operation before an assertion notices. See `testing-with-rb-lite`.

**Exit gate:** the gate ran and printed green, **and** you observed a matching assertion
FAIL for every property it claims — quote both: the green command with its exit code, and
each red run with the behavior you inverted and the assertion that reported it. Green alone
does not close PROVE. A gate never observed red is an untested instrument, and this is the
phase whose entire job is to establish that the instrument works.

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

Four preconditions, all of which must hold, and every one of which has bitten.

The fourth needs a step *before* the panel runs, so do this first — the moment the tree is
committed and you are about to launch the final panel:

```bash
DS=<the drive-status path resolved in Phase 0>
STATE_DIR=$(dirname "$(git rev-parse --git-path drive/state)")
mkdir -p "$STATE_DIR"
# CLEAN BEFORE PINNING, not merely clean before clearing. Precondition 1 below already says
# to panel the committed tree, but it is only CHECKED after the panel — and by then the
# evidence can be gone. A dirty tree here means the panel reviews HEAD-plus-uncommitted
# while panel_tip names HEAD alone; revert or stash those edits and every post-panel check
# passes, because the tip still matches and the tree is now clean. Clearance would then
# record "the panel read this commit" about a tree the panel never saw. Checking here makes
# that unrepresentable instead of undetectable.
# Two checks, because a FAILED `git status` also prints nothing: a corrupt index would read
# as a clean tree, in the clearing direction.
_ST=$(git status --porcelain) || { echo "cannot read the worktree — do NOT start the panel"; exit 1; }
[ -z "$_ST" ] || { echo "tree dirty — commit first, do NOT start the panel"; exit 1; }
# Pin what the panel is about to read. GitHub allows retargeting a PR at any moment,
# including while a 15-minute panel runs, and a retarget moves the reviewed surface
# without moving HEAD — so every SHA the clearance records would still match.
# The OID as well as the name. A same-named base that is force-pushed BACKWARD while the
# panel runs leaves panel_base equal and the rewound base still an ancestor of HEAD, so a
# name-only pin agrees and clearance records a base the panel never diffed against.
_DSP=$("$DS" --json)
_PB=$(printf %s "$_DSP" | jq -r '.default_branch')
# FETCH BEFORE PINNING. Two failures share this cause. Pinning `origin/$_PB` unfetched
# records whatever the last fetch left there, so the clearance-time comparison reads the
# same stale ref on both sides and passes vacuously — the check cannot see the rewind it
# exists to catch. And in a `--single-branch` clone that ref does not exist at all, so the
# pin records `unknown`, the clearance guard hard-exits on it, and its remedy ("re-run the
# panel") re-pins `unknown` forever: clearance becomes unreachable in a clone type this
# file elsewhere documents as supported. One fetch, here, closes both.
# The repo that OWNS this PR, not the parent by default. Fetching the parent's branch into
# refs/remotes/origin/$_PB clobbers the fork's own tracking ref, and every downstream check
# (panel_base_oid, cleared_base, base_fresh) then validates against a branch GitHub will
# never merge into — with "REBASE FIRST" as the symptom and re-clearing as a remedy that
# re-pins the same wrong ref forever.
# `base_repo`, not `pr_repo`. They answer different questions and conflating them
# deadlocked the fork path: with no PR yet — the prescribed state for a FIRST clearance —
# pr_repo named the fork, so this pinned the fork's base tip while the clearance snippet
# below fetched the PARENT's into the same ref. The OID check then failed on every attempt
# and told you to re-run the panel, which re-pinned the same ref. Both snippets read
# base_repo now, so they cannot disagree. Read both fields from one snapshot: two detector
# calls can transiently resolve different PRs and pair repo B with repo A's branch.
_UPP=$(printf %s "$_DSP" | jq -r '.base_repo // ""')
# gh's own clone URL: `owner/repo` alone points at public github.com, which on GitHub
# Enterprise either fails or resolves an unrelated public repo of the same name.
[ -n "$_UPP" ] && { _UPP=$(gh repo view "$_UPP" --json url -q .url 2>/dev/null) \
  || { echo "cannot resolve the clone URL for $_UPP — do NOT proceed"; exit 1; }; } || _UPP=origin
git fetch -q "$_UPP" "+refs/heads/$_PB:refs/remotes/origin/$_PB" \
  || { echo "cannot fetch $_PB — the panel's base is unknown, do NOT start the panel"; exit 1; }
# TELL THE PANEL WHICH COMMIT, and check what it reports back. `multi-reviewer-loop`
# deliberately uses a private `refs/remotes/prbase/<branch>` ref when a PR exists, while
# its no-PR path may use `origin/<branch>`. Requiring one spelling rejects a correct
# post-PR panel; the commit identity is the invariant that prevents an empty or wrong diff.
echo "panel base must resolve to: $(git rev-parse "origin/$_PB") (branch $_PB)"
{ printf 'panel_base=%s\n' "$_PB"
  printf 'panel_base_oid=%s\n' "$(git rev-parse "origin/$_PB")"
  printf 'panel_tip=%s\n' "$(git rev-parse HEAD)"; } > "$STATE_DIR/panel" \
  || { echo "could not pin the panel's inputs"; exit 1; }
```

When the panel returns, copy the exact ref from its final `Base:` line and verify its
identity. `origin/<base>` before a PR and `refs/remotes/prbase/<base>` after one are both
valid when they resolve to the pinned commit:

```bash
PANEL_REPORTED_BASE='<exact ref from the final panel summary>'
STATE_DIR=$(dirname "$(git rev-parse --git-path drive/state)")
PANEL_BASE_OID=$(sed -n 's/^panel_base_oid=//p' "$STATE_DIR/panel" 2>/dev/null | head -1)
[ -n "$PANEL_BASE_OID" ] \
  && [ "$(git rev-parse "$PANEL_REPORTED_BASE" 2>/dev/null)" = "$PANEL_BASE_OID" ] \
  || { echo "the panel reviewed a different base commit — re-run it; NOT cleared"; exit 1; }
```


1. **The tree is clean, and the final panel ran on the committed tree.** `multi-reviewer-loop` deliberately leaves its fixes uncommitted,
   and reviews tracked working-tree changes — so `git rev-parse HEAD` at that moment names
   a commit that does *not* contain what was just reviewed. Recording it would make
   `cleared == tip` true while the reviewed fixes are absent from the commit and the PR.
   Commit first, *then* run the final panel, then clear. Ordering it that way also closes
   the mutating-commit-hook case: a `lint-staged`-style hook rewrites content during
   `git commit`, so a panel that ran before the commit reviewed a tree the commit no
   longer has — and the clean-worktree check still passes, because the hook staged its
   own changes. Panelling the committed tree makes that unrepresentable rather than
   something to detect.
2. **The fetch succeeded.** A failed fetch leaves a stale tracking ref, and an ancestry
   check against a stale ref reports fresh when it is not.
3. **The base is an ancestor of the tip** — via `drive-status`, not a hand-rolled check.
   It already resolves `origin/HEAD`-unset clones, non-`main`/`master` defaults, and the
   `gh` fallback; reimplementing a two-branch version here would refuse to clear in any
   repo defaulting to `develop` or `trunk`.
4. **The clearance names what the panel actually read.** Both inputs can move while the
   panel runs, and neither move is visible in the checks above: retargeting the PR changes
   the base without touching HEAD, and a commit made between the panel finishing and the
   clearance being recorded changes the tip that gets recorded as reviewed. Pin both
   before the panel (above) and compare after.

```bash
DS=<the drive-status path resolved in Phase 0>
# Two checks, because a FAILED `git status` also prints nothing: a corrupt index would
# read as a clean tree, in the clearing direction.
_ST=$(git status --porcelain) || { echo "cannot read the worktree — do NOT clear"; exit 1; }
[ -z "$_ST" ] || { echo "tree dirty — commit first, do NOT clear"; exit 1; }
# Name the ref: a --single-branch clone's refspec covers only the feature branch, so a
# bare `git fetch origin` never creates origin/<base> and freshness stays unknowable.
# On a fork PR `origin` is YOUR fork, while GitHub merges into the upstream base repo —
# fetching origin/$BASE would validate freshness against a stale fork branch. Ask the PR
# for its base repo and fetch from there.
DS_PRE=$("$DS" --json)
BASE=$(printf %s "$DS_PRE" | jq -r '.default_branch')
# Precondition 4. Everything below validates whatever base is CURRENT — so if the PR was
# retargeted mid-panel, the fetch, the ancestry test and the recorded `cleared_base` would
# all agree about a branch no reviewer diffed against. Compare with what was pinned before
# the panel; the failure mode is silent otherwise, because every SHA still matches.
STATE_DIR=$(dirname "$(git rev-parse --git-path drive/state)")
PANEL_BASE=$(sed -n 's/^panel_base=//p' "$STATE_DIR/panel" 2>/dev/null | head -1)
PANEL_TIP=$(sed -n 's/^panel_tip=//p' "$STATE_DIR/panel" 2>/dev/null | head -1)
[ -n "$PANEL_BASE" ] && [ -n "$PANEL_TIP" ] \
  || { echo "the panel's inputs were never pinned — re-run the panel; NOT cleared"; exit 1; }
[ "$PANEL_BASE" = "$BASE" ] \
  || { echo "PR retargeted during review ($PANEL_BASE -> $BASE) — re-run the panel; NOT cleared"; exit 1; }
[ "$PANEL_TIP" = "$(git rev-parse HEAD)" ] \
  || { echo "HEAD moved since the panel ran — re-run it; NOT cleared"; exit 1; }
PANEL_BASE_OID=$(sed -n 's/^panel_base_oid=//p' "$STATE_DIR/panel" 2>/dev/null | head -1)
[ -n "$PANEL_BASE_OID" ] && [ "$PANEL_BASE_OID" != "unknown" ] \
  || { echo "the panel's base OID was never pinned — re-run the panel; NOT cleared"; exit 1; }
# Compared AFTER the fetch below, not here: both sides would otherwise read the same stale
# local ref and agree with themselves. See the assertion following the fetch.
# ONE resolution, from drive-status. This block used to re-derive the base repository by
# hand — probing the PR, falling back to `.parent`, falling back to origin — and it
# disagreed with the pre-panel pin above, which resolved the same thing differently. Both
# write refs/remotes/origin/$BASE, so on a fork clone with no PR yet (the prescribed state
# for a FIRST clearance) the pin recorded the fork's tip, this fetch overwrote it with the
# parent's, and the OID assertion failed on every attempt — telling you to re-run a
# 15-minute panel that re-pinned the same ref. Eleven sites in this repo have now gone
# wrong re-deriving the upstream; the detector computes it once and both snippets read it.
# DS_PRE pairs the branch and repository in one resolution. $DSJ below is deliberately
# taken AFTER the fetch, to read a freshness that only exists once the ref is updated.
BASE_REMOTE=$(printf %s "$DS_PRE" | jq -r '.base_repo // ""')
# gh's own clone URL: `owner/repo` alone points at public github.com, which on GitHub
# Enterprise either fails or resolves an unrelated public repo of the same name.
[ -n "$BASE_REMOTE" ] && { BASE_REMOTE=$(gh repo view "$BASE_REMOTE" --json url -q .url 2>/dev/null) \
  || { echo "cannot resolve the clone URL for $BASE_REMOTE — do NOT proceed"; exit 1; }; } || BASE_REMOTE=origin
git fetch -q "$BASE_REMOTE" "+refs/heads/$BASE:refs/remotes/origin/$BASE" \
  || { echo "fetch failed — base unknown, do NOT clear"; exit 1; }
# NOW the pinned OID means something: this ref was just refreshed from the remote, so a
# mismatch is a real move (including a force-push backward, which leaves the rewound base
# an ancestor of HEAD and therefore invisible to every other check here).
[ "$PANEL_BASE_OID" = "$(git rev-parse "origin/$BASE")" ] \
  || { echo "base $BASE moved under the panel ($PANEL_BASE_OID -> $(git rev-parse --short "origin/$BASE")) — re-run it; NOT cleared"; exit 1; }
# One call, and assert it is still talking about the SAME base. A second `drive-status`
# can resolve a different default_branch if its PR lookup transiently fails, so a
# base_fresh=true for `main` could be accepted while the ref actually fetched was
# `origin/release`.
DSJ=$("$DS" --json)
[ "$(printf %s "$DSJ" | jq -r '.default_branch')" = "$BASE" ] \
  || { echo "base changed under the check (want $BASE) — NOT cleared"; exit 1; }
BF=$(printf %s "$DSJ" | jq -r '.base_fresh')
# null != false. false = genuinely behind base, and a rebase fixes it. null = freshness was
# never computed, for one of two reasons the detector names in its own output: the base was
# GUESSED (no authoritative source, so the test is vacuous), or the PR's base commit is not
# in this clone (fetch it). Neither is fixable by rebasing, so do not suggest that.
[ "$BF" = "true" ] || { [ "$BF" = "null" ] \
  && { echo "base freshness unknown — run drive-status and read the reason (guessed base, or the PR's base commit not fetched); NOT cleared"; exit 1; } \
  || { echo "REBASE FIRST — behind base; NOT cleared"; exit 1; }; }

STATE=$(git rev-parse --git-path drive/state)
# Record the BASE too. `codex review --base` is diff-scoped, so retargeting the PR to an
# older ancestor afterwards expands the reviewed surface without moving HEAD — the tip SHA
# alone would still match and LAND would be derived over a diff no panel read.
mkdir -p "$(dirname "$STATE")" \
  && { printf 'cleared=%s\n' "$(git rev-parse HEAD)"
       # The PINNED oid, not the current ref: they are equal here only because the
       # assertion above just proved it, and recording the pin keeps that provenance.
       printf 'cleared_base=%s\n' "$PANEL_BASE_OID"; } > "$STATE" \
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
is an ancestor of the tip *and* still the one recorded in `cleared_base`, and the worktree
is clean. Those four are what LAND is derived from; the gate was HARDEN's exit condition and is already spent by the time LAND is
reachable — the detector cannot check it and does not claim to. LAND is *derived* from those facts,
never read from `DRIVE.md` (ADR 0002) — a record claiming LAND is a stale or hand-edited
file and `drive-status` will say so.

### The three checks, before you merge

**1. The tip is the tree that was reviewed.** Name the SHAs and refuse if they differ:

```text
panel cleared : <sha>          # $(git rev-parse --git-path drive/state)
bots read     : <sha>          # the codex review's `.commit_id`, NOT the +1
tip           : <sha>
```

"Read", not "cleared". The wrapper proves which tree the bot looked at; nothing in the
API proves the bot is finished with it, which is why `bot-gate`'s verdict is
`NO_PENDING_EVIDENCE` rather than a clearance (ADR 0004). The *panel's* clearance is the
one that admits LAND.

Take the bots' SHA from the review wrapper, not the reaction — a `+1` carries no SHA and
survives a force-push, so a stale one reads exactly like approval of the current head:

```bash
gh api --paginate --slurp repos/<owner>/<repo>/pulls/<N>/reviews \
  | jq -r '[.[][] | select(.user.login=="chatgpt-codex-connector[bot]" and .user.type=="Bot")
            | .commit_id] | last'
```

`.commit_id`, not a SHA scraped out of the body. § 7 of `pr-with-codex-bot-review` gives
the security reason (seven hex characters collide and can be ground out); the operational
one is that jq's `capture` *errors* on a non-matching input rather than skipping it, so a
single review whose body lacks the phrase aborts the whole filter and the snippet prints
nothing at all — hiding every round's SHA, including the current one.

Collect across pages and take `last`: the endpoint returns reviews oldest-first, and after
several rounds a bare stream prints one SHA per round with no indication which is current.
(`--slurp` cannot combine with `--jq`, hence the pipe.)

If the codex bot reacted `+1` with no wrapper, you have no SHA anchor — nothing proves
which tree that round read. `bot-gate` reports this as its own verdict,
`BLOCKED_UNATTRIBUTED` at **exit 4**: still a refusal, but one saying that more waiting
may not fix it, because the missing signal is the one that would attribute the round. Do
not sit in a poll loop on exit 4. `@codex review` to force a fresh wrapper — try that
first, since exit 4 also fires when a sticky older 👍 merely post-dates your local commit.
If no wrapper follows, confirm a real incident and use the degraded-forge procedure in
`pr-with-codex-bot-review` § 8b, recording what you substituted. A plain exit 1 with no
wrapper is the other case — the bot has not reviewed this tip — and there, waiting is
exactly right.

CodeRabbit's status is a **PR-level signal**, not per-commit: it lands on whatever head
exists when the bot posts it, so a green on the tip is not evidence about the tip. ADR 0004
records the measurement. `bot-gate` prints it and does not gate on it; neither should you.

Read its "Files skipped from review" list and re-trigger unless the skip was expected.

**2. Do not demand `merged SHA == reviewed SHA`.** The merge is a squash, so it always
creates a new commit; that equality is unsatisfiable by construction.

Pin the head in the merge itself, using **the tip `bot-gate` checked** rather than a fresh
`git rev-parse HEAD` — see `pr-with-codex-bot-review` § 8, which captures it from the
gate's JSON. A re-read pins whatever is current, so an amend landing after the gate gets
pinned to itself and is accepted
(`-R` because a bare PR number resolves against the current repo, which on a fork is yours)
(the **full** OID; the wrapper's SHA may be abbreviated, which would refuse every merge).
Between comparing SHAs and merging, another push can land; `--match-head-commit` makes the
merge refuse rather than take the newer, unreviewed head. Base drift in that same window is
*not* closed by any local check — only branch protection or a merge queue does that, which
is per-repo config this skill cannot assume.

**3. The base is still an ancestor of the tip** — checked when the panel clears **and**
again immediately before merging:

```bash
DS=<the drive-status path resolved in Phase 0>
# Re-derived here: this snippet runs in a different session from HARDEN's, after the whole
# bot-round cycle, so it cannot inherit variables from it. A fork PR merges into the
# upstream base repo while `origin` is your fork.
# REST, not `gh pr view --json baseRepository` — that field does not exist, and without
# `set -e` the failure is silent and falls back to origin, i.e. the fork.
DSJ2_PRE=$("$DS" --json)   # before the fetch; $DSJ2 below is taken after it, deliberately
BASE=$(printf %s "$DSJ2_PRE" | jq -r '.default_branch')
# Same single resolution as clearance uses. Hand-rolling it here forced the parent, so a
# fork-hosted PR was invisible and LAND could never merge it — and it could disagree with
# the ref the panel was pinned against, which is the deadlock the pre-panel pin hit.
BASE_REMOTE=$(printf %s "$DSJ2_PRE" | jq -r '.base_repo // ""')
# gh's own clone URL: `owner/repo` alone points at public github.com, which on GitHub
# Enterprise either fails or resolves an unrelated public repo of the same name.
[ -n "$BASE_REMOTE" ] && { BASE_REMOTE=$(gh repo view "$BASE_REMOTE" --json url -q .url 2>/dev/null) \
  || { echo "cannot resolve the clone URL for $BASE_REMOTE — do NOT proceed"; exit 1; }; } || BASE_REMOTE=origin
git fetch -q "$BASE_REMOTE" "+refs/heads/$BASE:refs/remotes/origin/$BASE" \
  || { echo "fetch failed — base unknown, do NOT merge"; exit 1; }
# One call, asserted to still name the same base: a second `drive-status` can resolve a
# different default_branch if its PR lookup transiently fails, so base_fresh=true for
# `main` would be accepted while the ref actually fetched was `origin/release`.
DSJ2=$("$DS" --json)
[ "$(printf %s "$DSJ2" | jq -r '.default_branch')" = "$BASE" ] \
  || { echo "base changed under the check (want $BASE) — do NOT merge"; exit 1; }
# THE PANEL'S CLEARANCE MUST STILL NAME THE TIP. Every other check here is about the base,
# and the tip moves too: answering a bot finding by amending after the panel cleared the
# previous HEAD produces a tree `bot-gate` will pass — it only ever asks about the current
# tip — while no panel has read it. drive-status already reports this (cleared_matches_tip
# false, phase HARDEN rather than LAND); nothing here was reading it.
[ "$(printf %s "$DSJ2" | jq -r '.cleared_matches_tip')" = "true" ] \
  || { echo "the panel has not cleared this tip (amended since clearance?) — re-run the panel; do NOT merge"; exit 1; }
[ "$(printf %s "$DSJ2" | jq -r '.phase')" = "LAND" ] \
  || { echo "drive-status says phase=$(printf %s "$DSJ2" | jq -r '.phase'), not LAND — do NOT merge"; exit 1; }
# The clearance must still name the base it was written against. Retargeting to an OLDER
# ancestor after clearance leaves HEAD untouched and the new base still an ancestor of it,
# so base_fresh stays true and the name check agrees with itself — while the PR's diff has
# silently grown to include commits no panel read. cleared_base is the only field that
# notices, so assert it here and not only at clearance time.
# false and null are different problems with opposite remedies, the same way base_fresh's
# are below. false = the base really moved, so re-run the panel. null = nothing to compare
# against (no cleared_base line, or no base ref resolves), and re-clearing cannot fix the
# second of those — drive-status prints which it is.
CBM=$(printf %s "$DSJ2" | jq -r '.cleared_base_matches')
[ "$CBM" = "true" ] || { [ "$CBM" = "null" ] \
  && { echo "clearance base unverifiable — run drive-status and read the reason (no cleared_base recorded, or no base ref resolves); do NOT merge"; exit 1; } \
  || { echo "clearance was recorded against a different base — re-run the panel; do NOT merge"; exit 1; }; }
BF=$(printf %s "$DSJ2" | jq -r '.base_fresh')
# null != false. false = genuinely behind base, and a rebase fixes it. null = the base was
# GUESSED (no authoritative source), so freshness was never computed and no rebase can
# help — the fix is establishing a real base, e.g. `git remote set-head origin -a`.
[ "$BF" = "true" ] || { [ "$BF" = "null" ] \
  && { echo "base freshness unknown — run drive-status and read the reason; do NOT merge"; exit 1; } \
  || { echo "REBASE FIRST — behind base"; exit 1; }; }
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

**Exit gate:** merged at a tip the codex bot read with no pending round, no undispositioned
finding from either bot, with a fresh base, branch reset, bead
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
  PR owner/repo#N` so a resumed session queries that PR instead of stopping at a DONE that
  never landed. **Qualify it with the repository**, do not write a bare `#N`: on a fork the
  metadata PR may live in the parent or in the fork and the same number is a different PR
  in each, so a bare number sends a resumed clone to read an unrelated PR's state as this
  drive's. `drive-status` still parses the bare form for records already written, and
  reports `pending_pr_repo: null` for them so the ambiguity is visible rather than assumed.
  `N` does not exist until the PR is open, so amend it in afterwards — the first pushed
  head is never the one that merges. Give the PR body a machine-readable marker line, one
  per bead it closes — `bead-closure: <bead-id>` — because ordinary work PR bodies carry
  the bead id too, and the discovery query below filters on the marker to tell a merged
  closure from merged work.

  **That record is only on the metadata branch until it merges**, so a fresh clone of the
  default branch cannot see it: it finds the old `DRIVE.md` and an open bead, and would
  re-enter BUILD or HARDEN and duplicate the closure. `drive-status` cannot help — it
  reads PR state for the *current* branch, and a clone sitting on the default branch has
  none. So the discovery path is the forge, and it belongs in the resume checklist:

  ```bash
  SELF=$(gh repo view --json nameWithOwner -q .nameWithOwner) \
    || { echo "cannot resolve this repository — closure-PR discovery is incomplete"; exit 1; }
  PARENT=$(gh repo view --json parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else "" end') \
    || { echo "cannot resolve the parent repository — closure-PR discovery is incomplete"; exit 1; }
  CLOSURE_PRS=()
  for UP in ${PARENT:+"$PARENT"} "$SELF"; do
    # `url` is not decoration: this loop MERGES parent and fork results, and a bare `number`
    # is ambiguous across them — #42 exists in both. Acting on a parent hit with the fork's
    # `-R` opens an unrelated same-numbered PR. The url carries the repository.
    _PRS=$(gh pr list -R "$UP" --state all --limit 1000 --json number,state,headRefName,title,body,url) \
      || { echo "cannot query closure PRs in $UP — do not resume work from partial results"; exit 1; }
    # 1000 is a CAP, not "all of them". In a repo with more newer PRs than that, the older
    # closure or work PR this recovery exists to find falls outside the snapshot, both
    # filters come back empty, and the instructions below declare the bead not started —
    # rebuilding work that already merged. A saturated page is the only case where anything
    # can be hidden, so pay for the targeted search only then.
    CLOSURE_PRS+=("$_PRS")
    if [ "$(printf '%s' "$_PRS" | jq 'length')" -ge 1000 ]; then
      _MORE=$(gh pr list -R "$UP" --state all --limit 1000 --search "$BEAD_ID in:body" \
                --json number,state,headRefName,title,body,url) \
        || { echo "closure search in $UP failed — do not resume work from partial results"; exit 1; }
      CLOSURE_PRS+=("$_MORE")
    fi
  done
  # unique_by(.url): the saturation fallback above can return a PR the first page already
  # had, and a hit reported twice reads as two separate closures.
  printf '%s\n' "${CLOSURE_PRS[@]}" \
    | jq -s --arg id "$BEAD_ID" 'add | unique_by(.url) | .[] | select($id != "" and ((.body // "") | ascii_downcase
        | test("(^|\\r|\\n)[[:space:]]*bead-closure:[[:space:]]*" + ($id|ascii_downcase|gsub("\\.";"\\.")) + "[[:space:]]*(\\r|\\n|$)")))'
  # SAME shell, same snapshot: the bead's work PRs, MERGED **or still OPEN**. Consulted
  # whenever the marker query above is empty — see below. MERGED-only hid the third resume
  # state entirely: a work PR that was opened but has not landed carries the bead id and no
  # `bead-closure:` marker, so the marker query above skipped it and this one filtered it
  # out, leaving both empty on a fresh clone — and the driver re-entered BUILD to implement
  # work that was already open for review, duplicating both the commits and the PR.
  # Re-fetched in a separate block, a fetch that failed here while the marker query
  # succeeded would silently read as "nothing merged", the exact collapse this closes.
  printf '%s\n' "${CLOSURE_PRS[@]}" \
    | jq -s --arg id "$BEAD_ID" 'add | unique_by(.url) | .[] | select(.state=="MERGED" or .state=="OPEN")
        | select($id != "" and ((.body // "") | ascii_downcase
          | test("(^|[^a-z0-9._-])" + ($id|ascii_downcase|gsub("\\.";"\\.")) + "([^a-z0-9._-]|$)")))'
  ```

`BEAD_ID` comes from the bead you are resuming — on a fresh clone take it from `br list`'s
open beads, one query per candidate. There is no durable variable carrying it across a
clone boundary, so a snippet that assumes one silently rejects every PR (`$id != ""`) and
misses the closure it exists to find.

Keyed on the **`bead-closure:` marker plus the bead id**, not on the id alone: every work
PR body carries the bead id too (rb-lite's step 8 requires it), so an id-only filter
returns the merged work PR for any bead whose work landed — on a fresh clone that reads
as closure history for a closure that was never opened, and the resume guard clears
itself on the wrong PR. Not a branch-naming convention either — nothing here mandates
one, so a filter like `test("closure|metadata")` misses a PR called `chore/close-bead-42`.
And note the raised `--limit`: `gh pr list` returns 30 by default, which hides an older
closure PR behind newer work PRs — precisely the resume case this query exists for.

**An empty result from the marker query answers only "no closure PR was opened" — it is
NOT evidence that nothing merged.** A session that stops between the work PR merging and
the metadata PR being opened leaves exactly that state: work on the base, bead still open
in the JSONL, no marker anywhere for the first query to find. Reading empty as
"unfinished" there re-enters BUILD and duplicates merged work. The second query in the
block is what tells those apart: it asks the same snapshot whether the bead's WORK
already merged (every work PR body carries the bead id — rb-lite's step 8 requires it).

Read any hit before acting on it. **Take the repository from the hit's `url`, never from
the number alone** — these results merge the parent's PRs with the fork's, and #42 exists
in both; a parent hit acted on with the fork's `-R` lands you on an unrelated PR. Then
**read its `state` — it names the resume point**:

- **`MERGED`** — a merged PR carrying the id is almost certainly the work PR, and the bead
  open in the default branch's JSONL beside it is precisely the interrupted state. The
  resume point is the closure path above (close the bead, open and land the metadata PR),
  **not** BUILD: the code is already on the base.
- **`OPEN`** — the work PR exists and has not landed. The resume point is that PR's own
  review-and-merge flow, **not** BUILD and not a second PR: rebuilding here races an open
  review and lands the bead twice. Treat it exactly as an interrupted HARDEN — the panel
  and the gate still have to clear the tip before it merges.

Only when both queries are empty does "not started" stand — and note that is a narrower
claim than the "not started *or* not merged" this once read as, which quietly folded the
OPEN case into the same answer. On a drive older than these markers and id-carrying
bodies, even that needs the hits read by hand, because neither convention was in force
when its PRs were written.

  **Before re-entering BUILD or HARDEN from a fresh clone with unresolved beads, run that
  query.** An open closure PR means the drive is `WAITING_FOR_MERGE`, not unfinished —
  land that PR rather than starting the work again.

And verify the closure actually happened. `br close` exits 0 even when the flush that
writes the JSONL failed, because the error is caught and logged at debug level:

```bash
br close <id> || { echo "br close failed"; exit 1; }
br sync --flush-only || { echo "closure not persisted — auto-flush was swallowed"; exit 1; }
```

`||`, not `;`: a semicolon discards the exit status of the command before it, so the pair
would report success on a closure that never happened.

A flush
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

**Unless a closure PR is still unmerged.** From a fresh clone this is not visible in the
record at all (see LAND above) — check `gh pr list -R <upstream> --state all` before
concluding the drive is unfinished. An OPEN one still needs landing; a CLOSED-but-unmerged
one must be reopened or replaced rather than rebuilding the bead. A bare `gh pr list` in a
fork clone queries the fork, where the closure PR is not. A record reading `DONE · Pending: metadata PR
#N` means "DONE once #N merges" — the merged file cannot state its own post-merge status,
so the driver queries. `drive-status` reports that state as `WAITING_FOR_MERGE`, not
`DONE`, precisely so a resumed session goes and lands the PR instead of reporting a
finished drive whose closure is still unmerged.

Report what landed, what is deferred and why, and stop. This is the one place a summary is
legitimately the end of the turn.

`drive-status` counts globally — it has no way to know your scope — so its `DONE` and its
bead numbers are repository-wide. Filter them against the scope in `DRIVE.md` yourself
before believing them.

If `br ready` is empty but the unresolved set is **not**, you are not done: every remaining
bead is blocked or deferred. That is a graph problem — re-audit dependencies and deferrals
in GRAPH rather than hunting for a bead to build. `drive-status` flags this case explicitly.
