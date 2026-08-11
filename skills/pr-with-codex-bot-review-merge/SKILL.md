---
name: pr-with-codex-bot-review-merge
description: >-
  Internal companion procedure for the final squash-merge and safe cleanup phase
  of pr-with-codex-bot-review. Load this exact skill only when the owning skill
  directs you here; it is not a standalone PR workflow.
user-invocable: false
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
---

# Squash-merge and clean up

The required merge and local-reset sequence after § 7 has admitted a PR.
Run it as written; it deliberately re-checks mutable forge and worktree state.

## Contents

- Verify a clean worktree and identify the one PR matching the reviewed head
- Re-run `bot-gate` and retain the reviewed tip and JSON evidence
- Fetch and verify the base, then detect a late PR retarget
- Squash-merge with the reviewed full OID and wait for `MERGED`
- Preserve merge evidence, fetch the landed base, and refuse unsafe resets
- Reset the local base and run its authoritative build

```bash
# Two checks, because a FAILED `git status` also prints nothing: a corrupt index would
# read as a clean tree, in the merging direction.
_ST=$(git status --porcelain) || { echo "cannot read the worktree — do NOT merge"; exit 1; }
[ -z "$_ST" ] || { echo "tree dirty — do NOT merge"; exit 1; }
# Resolve by matching HEAD, not by preferring the parent. A fork can host its own PRs, and
# both repos can carry PR number N — so parent-first targets a missing or unrelated PR and
# the real one can never be landed. `bot-gate` resolves the same way for the same reason.
# BOTH matching is ambiguous, not a tiebreak: the same branch can be opened as a PR against
# the parent AND the fork, and the two PRs were gated separately — silently merging the
# parent's can land a PR whose reviews nobody checked. Refuse and make the caller say
# which repo.
# Guarded, because a failed lookup is not an answer: an unguarded SELF empties the loop's
# only sure candidate, and a failed parent lookup silently reads as "not a fork" — dropping
# the very candidate whose second PR the ambiguity refusal below exists to catch.
SELF=$(gh repo view --json nameWithOwner -q .nameWithOwner) \
  || { echo "cannot resolve this repository — do NOT merge"; exit 1; }
UP=$(gh repo view --json parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else "" end') \
  || { echo "cannot resolve the fork parent — a PR there would be invisible; do NOT merge"; exit 1; }
# "No such PR" and "the query failed" share an exit code, so absence is read out of gh's
# own error text; any other failure may be hiding the second match. bot-gate makes the
# same split, but this loop picks the repo the MERGE targets, so it cannot lean on that.
# PullRequest-level not-found only: both candidates are repos the API just named, so a
# Repository-level "could not resolve" or an HTTP 404 is lost access, not absence.
_GH_ERR=$(mktemp) || { echo "mktemp failed"; exit 1; }; trap 'rm -f "$_GH_ERR"' EXIT   # both scripts do this; the snippets leaked it
R=""; _M=0
for _c in ${UP:+"$UP"} "$SELF"; do
  if ! _h=$(gh pr view <N> -R "$_c" --json headRefOid -q .headRefOid 2>"$_GH_ERR"); then
    grep -qiE 'could not resolve to a pullrequest|no pull requests found' "$_GH_ERR" \
      || { echo "cannot query PR <N> in $_c — absence not established; do NOT merge"; exit 1; }
    _h=""
  fi
  if [ "$_h" = "$(git rev-parse HEAD)" ]; then
    _M=$((_M+1)); [ -n "$R" ] || R="$_c"
  fi
done
[ "$_M" -le 1 ] || { echo "PR <N> matches this head in BOTH $UP and $SELF — ambiguous; re-run with the intended repo pinned in every -R"; exit 1; }
[ -n "$R" ] || { echo "no PR <N> whose head is this tree in ${UP:+$UP or }$SELF"; exit 1; }
PR_REFS=$(gh pr view <N> -R "$R" --json baseRefName,headRefName) \
  || { echo "cannot resolve the PR branches"; exit 1; }
BASE=$(printf %s "$PR_REFS" | jq -r '.baseRefName // ""')
HEAD_BRANCH=$(printf %s "$PR_REFS" | jq -r '.headRefName // ""')
[ -n "$BASE" ] && [ -n "$HEAD_BRANCH" ] \
  || { echo "cannot resolve the PR branches"; exit 1; }

# Check the exit status. `--delete-branch` makes gh switch branches as a side effect, so a
# FAILED merge still leaves you somewhere plausible-looking; without this the steps below
# "confirm $BASE is healthy" on a tree where nothing landed, and any caller that closes a
# tracker item after this block closes it for a merge that never happened.
# $REVIEWED_TIP is the SHA bot-gate checked in § 7, not a fresh `git rev-parse HEAD`.
# Re-reading HEAD here re-adopts whatever is current — a late amend or concurrent
# automation that pushed after the gate returned — and pins the merge to that, so GitHub
# ACCEPTS the unreviewed head instead of refusing it. The pin is only a guard if it names
# the tree that was actually reviewed.
# Run the gate and REQUIRE its exit status. A command substitution swallows it: bot-gate
# prints its JSON — `tip` included — before exiting 1 on BLOCKED, so `$(... | jq -r .tip)`
# yields a perfectly good SHA from a run that said do not merge, and jq's own exit 0 hides
# it. An amend landing between § 7 and here then produces a BLOCKED gate whose tip is the
# new head, the equality check compares the new head to itself and passes, and the merge
# takes the unreviewed tree — the exact outcome this pin exists to refuse.
# Re-resolved here: this block re-derives $R and $BASE so it can run standalone, and an
# unset $BOT_GATE would execute an empty command and report "do NOT merge" for a gate that
# was merely not found.
for d in "$HOME/.claude/skills/pr-with-codex-bot-review" \
         "${CODEX_HOME:-$HOME/.codex}/skills/pr-with-codex-bot-review" \
         "$HOME/.agents/skills/pr-with-codex-bot-review"; do
  [ -x "$d/scripts/bot-gate" ] && { BOT_GATE="$d/scripts/bot-gate"; break; }
done
[ -n "${BOT_GATE:-}" ] || { echo "bot-gate not found — resolve it as in § 7"; exit 1; }
unset REVIEWED_TIP
# DEGRADED REENTRY A: stop here after repository and BOT_GATE resolution.
GATE_RC=0
GATE_JSON=$("$BOT_GATE" <N> --json) || GATE_RC=$?
if [ "$GATE_RC" -eq 0 ]; then
  [ "$(printf %s "$GATE_JSON" | jq -r .verdict)" = "NO_PENDING_EVIDENCE" ] \
    || { echo "gate verdict is not NO_PENDING_EVIDENCE"; exit 1; }
  REVIEWED_TIP=$(printf %s "$GATE_JSON" | jq -er .tip) \
    || { echo "gate JSON has no tip"; exit 1; }
elif [ "$GATE_RC" -eq 4 ]; then
  GATE_EVIDENCE=$(git rev-parse --git-path "merge-gate-<N>.json") \
    || { echo "cannot resolve the gate-evidence path"; exit 1; }
  (umask 077; printf '%s\n' "$GATE_JSON" > "$GATE_EVIDENCE") \
    || { echo "cannot preserve exit-4 gate JSON"; exit 1; }
  echo "bot-gate exit 4: preserved JSON at $GATE_EVIDENCE; STOP and load exact skill pr-with-codex-bot-review § 8b"
else
  echo "bot-gate says do NOT merge (exit $GATE_RC)"
  exit 1
fi
# The normal path sets REVIEWED_TIP above. Exit 4 deliberately leaves it unset: complete
# main-skill § 8b and run its fresh live-gate check, then set REVIEWED_TIP only from that
# new JSON before resuming at R_URL below. The saved file is incident evidence, never an
# admission token. A pasted-through sequence cannot drift into a merge because this guard
# refuses it, including in a reused shell that had REVIEWED_TIP set before this gate call.
[ -n "${REVIEWED_TIP:-}" ] \
  || { echo "REVIEWED_TIP unset — do NOT continue; complete § 8b first"; exit 1; }
# Repository, ancestry, retarget, queue, evidence, and reset checks remain mandatory.
# DEGRADED REENTRY B: resume here after completing main-skill § 8b.
# The forge's own clone URL, not a hardcoded github.com one. `$R` is only `owner/repo`,
# so on GitHub Enterprise the literal host either fails or — worse — resolves an unrelated
# PUBLIC repo of the same name and validates ancestry against a stranger's branch.
R_URL=$(gh repo view "$R" --json url -q .url 2>/dev/null) \
  || { echo "cannot resolve the clone URL for $R — do NOT merge"; exit 1; }
R_URL="$R_URL.git"
# Fetch the base AFTER the potentially slow bot gate. Fetching it before the API sweep lets
# the merge target advance during the gate, making the ancestry result stale at merge time.
git fetch "$R_URL" "+refs/heads/$BASE:refs/remotes/upstream/$BASE" \
  || { echo "cannot fetch the merge target — base unknown, do NOT merge"; echo "  (on a private repo cloned over SSH this is usually missing git credentials for https, not a missing base)"; exit 1; }
git merge-base --is-ancestor "refs/remotes/upstream/$BASE" HEAD \
  || { echo "REBASE FIRST — $BASE advanced since the review"; exit 1; }
[ "$REVIEWED_TIP" = "$(git rev-parse HEAD)" ] \
  || { echo "local HEAD moved since the gate ran — re-run § 7"; exit 1; }
# LAST, immediately before the merge. Ancestry answers "did $BASE advance"; it cannot
# answer "is $BASE still the target". A RETARGET points the PR at a different branch
# entirely: $BASE then names the old one, everything above validates that one, and
# `gh pr merge` squashes onto whatever the PR points at now — with the head unmoved, so
# --match-head-commit stays satisfied. Read it here rather than beside the gate because
# every check between the read and the merge widens the window. The window is not zero and
# cannot be: GitHub offers no base pin to match --match-head-commit. It is now one API call
# wide instead of a fetch plus two checks, and a retarget is one click.
BASE_NOW=$(gh pr view <N> -R "$R" --json baseRefName -q .baseRefName) \
  || { echo "cannot re-read the merge target — do NOT merge"; exit 1; }
[ -n "$BASE_NOW" ] && [ "$BASE_NOW" = "$BASE" ] \
  || { echo "the PR was retargeted ($BASE -> ${BASE_NOW:-unknown}) — the panel reviewed a diff against $BASE; re-run § 7"; exit 1; }
gh pr merge <N> -R "$R" --squash --delete-branch --match-head-commit "$REVIEWED_TIP" \
  || { echo "merge did not land — do NOT proceed"; exit 1; }

# `gh pr merge` returning 0 means the PR was accepted for merging — which, in a repo with a
# required merge queue, means ENQUEUED, not landed. Fetching now would read the still-old
# base and any caller that closes a tracker item here would close it for a merge that has
# not happened. Wait for the state to actually reach MERGED.
_n=0
while [ "$_n" -lt 60 ]; do
  _n=$((_n+1))
  _ST=$(gh pr view <N> -R "$R" --json state -q .state 2>/dev/null || echo "")
  [ "$_ST" = "MERGED" ] && break
  [ "$_ST" = "CLOSED" ] && { echo "PR was closed without merging"; exit 1; }
  sleep 10
done
[ "$_ST" = "MERGED" ] || { echo "PR still not merged (state=$_ST) — do NOT proceed"; exit 1; }

# Keep $GATE_JSON: the merge report has to QUOTE it (see
# the already-loaded owning skill's § 8a; see
# ../pr-with-codex-bot-review/SKILL.md#8a-the-merge-report-must-quote-the-gate). Do not re-run the gate to
# produce the quote — the PR is merged by now, so a fresh run describes a different world.
printf '%s\n' "$GATE_JSON" > "${TMPDIR:-/tmp}/merge-evidence-<N>.json"

# Re-fetch after the merge: the ref above predates the squash commit. Reset from where the
# merge actually landed — `origin` is your fork and may not contain it at all. Fetch before
# checkout, because in a single-branch fork clone neither a local `$BASE` nor `origin/$BASE`
# exists, so `git checkout "$BASE"` fails and an unguarded reset then runs against whatever
# branch is still checked out.
git fetch "$R_URL" "+refs/heads/$BASE:refs/remotes/upstream/$BASE" \
  || { echo "cannot fetch the merge target"; exit 1; }
# `checkout -B` repoints the branch ref unconditionally, and a clean worktree does not
# protect COMMITTED work: a local bead closure or DRIVE.md update on $BASE awaiting its
# metadata PR — a state this skill's own LAND flow produces — becomes unreachable except
# via reflog. The exception is a same-name fork PR: local $BASE is the verified feature
# head, and a squash commit does not descend from it. Matching the reviewed OID distinguishes
# that head from later local-only commits, which must still stop the reset.
if git show-ref --verify --quiet "refs/heads/$BASE" \
   && ! git merge-base --is-ancestor "$BASE" "refs/remotes/upstream/$BASE"; then
  if [ "$HEAD_BRANCH" != "$BASE" ] \
     || [ "$(git rev-parse "refs/heads/$BASE")" != "$REVIEWED_TIP" ]; then
    echo "local $BASE has commits upstream does not — refusing to reset; push or rebase them first"
    exit 1
  fi
fi
# Re-check the worktree HERE, not only at the top of this block: the merge-queue wait
# above can run ten minutes, and `checkout -B` silently CARRIES any nonconflicting tracked
# modification made meanwhile onto the fresh base — the build below then "confirms" a tree
# that is not the branch tip. FULL status, untracked included: the top-of-block check ran
# BEFORE the wait, so it cannot vouch for a file created during it — and checkout does not
# remove an untracked file, so it sits in the "fresh" base worktree where the build and
# whatever branches from here inherit it, unreviewed and invisible to `-uno`.
_ST=$(git status --porcelain) || { echo "cannot re-read the worktree — not resetting"; exit 1; }
[ -z "$_ST" ] || { echo "worktree changed while waiting for the merge — resolve that, then reset to $BASE by hand"; exit 1; }
git checkout -B "$BASE" "refs/remotes/upstream/$BASE" \
  || { echo "cannot reset to the merge target — do NOT treat what follows as a check of it"; exit 1; }
nix build                                    # confirm the base is healthy
```

`--match-head-commit` takes the **full 40-char OID**, which is why the snippet pins
`$REVIEWED_TIP` from the gate's JSON: it is already the full SHA, and it is the tip the
gate actually checked. Do not substitute `git rev-parse HEAD` here — that re-reads the
current head, so an amend after the gate ran gets pinned to itself and merges unreviewed.
Nor the wrapper's body SHA, which may be abbreviated and would make every merge refuse
with no hint why.

Check before merging, and make it `exit 1` rather than print: a bare `git status
--porcelain` exits 0 either way, and `--delete-branch` makes `gh pr merge` switch branches
itself — so a dirty tree aborts *after* the squash has already landed. Stash if the change
matters; discard only after looking, because `git checkout -- .` is not recoverable.

`checkout -B` rather than `pull` because squash-merge rewrites history — the branch is
repointed at the merge target, not merged with it.
