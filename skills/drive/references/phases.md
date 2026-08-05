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

Four preconditions, all of which must hold, and every one of which has bitten.

The fourth needs a step *before* the panel runs, so do this first — the moment the tree is
committed and you are about to launch the final panel:

```bash
DS=<the drive-status path resolved in Phase 0>
STATE_DIR=$(dirname "$(git rev-parse --git-path drive/state)")
mkdir -p "$STATE_DIR"
# Pin what the panel is about to read. GitHub allows retargeting a PR at any moment,
# including while a 15-minute panel runs, and a retarget moves the reviewed surface
# without moving HEAD — so every SHA the clearance records would still match.
# The OID as well as the name. A same-named base that is force-pushed BACKWARD while the
# panel runs leaves panel_base equal and the rewound base still an ancestor of HEAD, so a
# name-only pin agrees and clearance records a base the panel never diffed against.
_PB=$("$DS" --json | jq -r '.default_branch')
# FETCH BEFORE PINNING. Two failures share this cause. Pinning `origin/$_PB` unfetched
# records whatever the last fetch left there, so the clearance-time comparison reads the
# same stale ref on both sides and passes vacuously — the check cannot see the rewind it
# exists to catch. And in a `--single-branch` clone that ref does not exist at all, so the
# pin records `unknown`, the clearance guard hard-exits on it, and its remedy ("re-run the
# panel") re-pins `unknown` forever: clearance becomes unreachable in a clone type this
# file elsewhere documents as supported. One fetch, here, closes both.
_UPP=$(gh repo view --json parent -q 'if .parent then "https://github.com/\(.parent.owner.login)/\(.parent.name)" else "" end' 2>/dev/null); [ -n "$_UPP" ] || _UPP=origin
git fetch -q "$_UPP" "+refs/heads/$_PB:refs/remotes/origin/$_PB" \
  || { echo "cannot fetch $_PB — the panel's base is unknown, do NOT start the panel"; exit 1; }
{ printf 'panel_base=%s\n' "$_PB"
  printf 'panel_base_oid=%s\n' "$(git rev-parse "origin/$_PB")"
  printf 'panel_tip=%s\n' "$(git rev-parse HEAD)"; } > "$STATE_DIR/panel" \
  || { echo "could not pin the panel's inputs"; exit 1; }
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
[ -z "$(git status --porcelain)" ] || { echo "tree dirty — commit first, do NOT clear"; exit 1; }
# Name the ref: a --single-branch clone's refspec covers only the feature branch, so a
# bare `git fetch origin` never creates origin/<base> and freshness stays unknowable.
# On a fork PR `origin` is YOUR fork, while GitHub merges into the upstream base repo —
# fetching origin/$BASE would validate freshness against a stale fork branch. Ask the PR
# for its base repo and fetch from there.
BASE=$("$DS" --json | jq -r '.default_branch')
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
# REST, not `gh pr view --json baseRepository` — that field does not exist, and without
# `set -e` the failure is silent and falls back to origin, i.e. the fork.
# The first clearance runs BEFORE any PR exists — that is the prescribed ordering — so a
# hard PR requirement here would deadlock every drive at its first HARDEN. Ask the PR when
# there is one; otherwise ask whether this repo is a fork; otherwise origin is the target.
UP=$(gh repo view --json nameWithOwner,parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else .nameWithOwner end' 2>/dev/null)
BR=$(git branch --show-current)
# `-R` needs an explicit selector — gh cannot infer the PR from the branch once --repo is
# given — and without `-R` a fork clone looks for the PR in the fork, where it is not.
# The head LABEL, not the branch name: gh matches `-R <upstream>` lookups against
# `<forkowner>:<branch>` for a cross-repo PR, so a bare branch finds nothing on exactly the
# fork clones `-R` is here for. drive-status builds the same selector and its suite pins
# the form; this snippet needs it too or LAND is unreachable on a fork.
_SELF=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
_SEL="$BR"; [ -n "$UP" ] && [ -n "$_SELF" ] && [ "$UP" != "$_SELF" ] && _SEL="${_SELF%%/*}:$BR"
if PRNUM=$(gh pr view "$_SEL" ${UP:+-R} ${UP:+"$UP"} --json number -q .number 2>/dev/null) && [ -n "$PRNUM" ]; then
  # -R the upstream: `{owner}/{repo}` expands to the CURRENT repo, which on a fork is
  # yours, not where the PR lives.
  UP=$(gh repo view --json nameWithOwner,parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else .nameWithOwner end')
  BASE_REMOTE=$(gh api "repos/$UP/pulls/$PRNUM" --jq .base.repo.clone_url 2>/dev/null) \
    || { echo "cannot resolve base repository"; exit 1; }
else
  BASE_REMOTE=$(gh repo view --json parent -q 'if .parent then "https://github.com/\(.parent.owner.login)/\(.parent.name)" else "" end' 2>/dev/null)
  [ -n "$BASE_REMOTE" ] || BASE_REMOTE=origin
fi
# Explicit DESTINATION refspec. `git fetch origin "$BASE"` updates only FETCH_HEAD — in a
# --single-branch clone the configured refspec covers just the feature branch, so
# refs/remotes/origin/$BASE is never created and base_fresh stays null forever, failing
# with "REBASE FIRST" that no rebase can fix. Verified.
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

If the codex bot reacted `+1` with no wrapper, you have no SHA anchor: `@codex review` and
wait for one. CodeRabbit's check is per-commit, but a `SUCCESS` may be a *skip* — read the
"Files skipped from review" list and re-trigger unless the skip was expected.

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
BASE=$("$DS" --json | jq -r '.default_branch')
# Re-derived here: this snippet runs in a different session from HARDEN's, after the whole
# bot-round cycle, so it cannot inherit variables from it. A fork PR merges into the
# upstream base repo while `origin` is your fork.
# REST, not `gh pr view --json baseRepository` — that field does not exist, and without
# `set -e` the failure is silent and falls back to origin, i.e. the fork.
UP2=$(gh repo view --json nameWithOwner,parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else .nameWithOwner end' 2>/dev/null)
BR2=$(git branch --show-current)
# The head LABEL, not the branch name: gh matches `-R <upstream>` lookups against
# `<forkowner>:<branch>` for a cross-repo PR, so a bare branch finds nothing on exactly the
# fork clones `-R` is here for. drive-status builds the same selector and its suite pins
# the form; this snippet needs it too or LAND is unreachable on a fork.
_SELF=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
_SEL2="$BR2"; [ -n "$UP2" ] && [ -n "$_SELF" ] && [ "$UP2" != "$_SELF" ] && _SEL2="${_SELF%%/*}:$BR2"
PRNUM=$(gh pr view "$_SEL2" ${UP2:+-R} ${UP2:+"$UP2"} --json number -q .number 2>/dev/null) || { echo "no PR — cannot resolve base repo"; exit 1; }
UP=$(gh repo view --json nameWithOwner,parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else .nameWithOwner end')
BASE_REMOTE=$(gh api "repos/$UP/pulls/$PRNUM" --jq .base.repo.clone_url 2>/dev/null) \
  || { echo "cannot resolve base repository"; exit 1; }
git fetch -q "$BASE_REMOTE" "+refs/heads/$BASE:refs/remotes/origin/$BASE" \
  || { echo "fetch failed — base unknown, do NOT merge"; exit 1; }
# One call, asserted to still name the same base: a second `drive-status` can resolve a
# different default_branch if its PR lookup transiently fails, so base_fresh=true for
# `main` would be accepted while the ref actually fetched was `origin/release`.
DSJ2=$("$DS" --json)
[ "$(printf %s "$DSJ2" | jq -r '.default_branch')" = "$BASE" ] \
  || { echo "base changed under the check (want $BASE) — do NOT merge"; exit 1; }
# The clearance must still name the base it was written against. Retargeting to an OLDER
# ancestor after clearance leaves HEAD untouched and the new base still an ancestor of it,
# so base_fresh stays true and the name check agrees with itself — while the PR's diff has
# silently grown to include commits no panel read. cleared_base is the only field that
# notices, so assert it here and not only at clearance time.
[ "$(printf %s "$DSJ2" | jq -r '.cleared_base_matches')" = "true" ] \
  || { echo "clearance was recorded against a different base — re-run the panel; do NOT merge"; exit 1; }
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
  PR #N` so a resumed session queries `#N` instead of stopping at a DONE that never landed.
  `N` does not exist until the PR is open, so amend it in afterwards — the first pushed
  head is never the one that merges.

  **That record is only on the metadata branch until it merges**, so a fresh clone of the
  default branch cannot see it: it finds the old `DRIVE.md` and an open bead, and would
  re-enter BUILD or HARDEN and duplicate the closure. `drive-status` cannot help — it
  reads PR state for the *current* branch, and a clone sitting on the default branch has
  none. So the discovery path is the forge, and it belongs in the resume checklist:

  ```bash
  UP=$(gh repo view --json nameWithOwner,parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else .nameWithOwner end')
  gh pr list -R "$UP" --state open --json number,headRefName,title   # closure PR in flight?
  ```

  **Before re-entering BUILD or HARDEN from a fresh clone with unresolved beads, run that
  query.** An open closure PR means the drive is `WAITING_FOR_MERGE`, not unfinished —
  land that PR rather than starting the work again.

And verify the closure actually happened. `br close` exits 0 even when the flush that
writes the JSONL failed, because the error is caught and logged at debug level:

```bash
# Before/after, not "is the JSONL dirty". A drain carries the previous bead's closure
# forward uncommitted, so from the second bead on the file is already dirty and a bare
# dirtiness test passes without this close having written anything — the exact swallowed
# auto-flush it is here to catch. Guard 1 in SKILL.md states the same rule; this is the
# third site of it.
beads_fingerprint() {   # portable: macOS sort has no -z and BSD xargs has no -r
  git ls-files -co --exclude-standard -- '*.beads.jsonl' '.beads/*.jsonl' \
    | LC_ALL=C sort | while IFS= read -r f; do printf '%s ' "$f"; cksum < "$f"; done | cksum
}
BEFORE=$(beads_fingerprint)
br close <id> || { echo "br close failed"; exit 1; }
[ "$(beads_fingerprint)" != "$BEFORE" ] \
  || { echo "closure not persisted — auto-flush was swallowed"; exit 1; }
```

`&&`/`||`, not `;`: a semicolon discards `br close`'s exit status, and `git status` exits
0 whether or not it printed anything — so the pair would report success on a closure that
never happened.

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

**Unless a closure PR is still open.** From a fresh clone this is not visible in the
record at all (see LAND above) — check `gh pr list -R <upstream> --state open` before
concluding the drive is unfinished — a bare `gh pr list` in a fork clone queries the fork,
where the closure PR is not. A record reading `DONE · Pending: metadata PR
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
