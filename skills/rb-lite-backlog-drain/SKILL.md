---
name: rb-lite-backlog-drain
description: >-
  Internal companion procedure for orchestrating-with-rb-lite's serialized bead
  backlog drain. Load this exact skill only when orchestrating-with-rb-lite or a
  sibling skill directs you here; it is not a standalone workflow selector.
user-invocable: false
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Backlog-drain workflow

The complete operating procedure for rb-lite's serialized `br` backlog-drain mode.
When `orchestrating-with-rb-lite` directs a full backlog drain, read it before selecting
the first bead and follow all twelve steps in order. When a sibling skill links to one
numbered section for recovery, execute only that cited section; do not start a drain or
touch unrelated beads.

## Contents

- Steps 1–4: pick, read, branch, and write the task file
- Steps 5–7: run rb-lite, interpret its summary, and run local gates
- Steps 8–10: commit, push, wait for CI, merge, and reset
- Step 11: close the bead through a reviewed metadata path
- Step 12: resume safely and continue until the scoped backlog is empty

Use this mode when the user wants to clear an existing `br` backlog with
rb-lite. The beads are the input; do not invent a fresh work list. Codex is
operating the queue and PR workflow, while rb-lite handles the inner
implement → review loop for each bead.

1. **Pick.** Run `"$BEADS_JSONL_RESOLVER" --run-br ready --limit 10`. Take the top P0 first; if none,
   the lowest-numbered P1; only descend to P2 if the user says so or the
   P1 list is empty / oversized.

2. **Read.** Run `"$BEADS_JSONL_RESOLVER" --run-br show <id>` (and `"$BEADS_JSONL_RESOLVER" --run-br show <id> --json` if structured
   fields help). If the acceptance criteria are vague, pause and ask the
   user before writing the task.

3. **Sync base and branch.** Confirm there is no unrelated dirty work, fetch
   the selected base, and start the bead from that clean base. Use one branch
   per bead, e.g. `feat/<bead-id>-<short-slug>`. Let rb-lite create/switch the
   branch with `--branch` unless the branch already exists and the user
   explicitly wants to resume it. Do not pile multiple beads onto one branch.

4. **Task file.** Write a focused task file, usually under
   `.rb-lite/tasks/bead-<id>.md`, using the
   [already-loaded owning skill's backlog task template](../orchestrating-with-rb-lite/SKILL.md#backlog-task-template). Keep it outside
   the committed source diff unless the repo intentionally tracks task
   files.

5. **Run rb-lite.**

   ```bash
   rb-lite run \
     --implementer claude,codex \
     --task-file .rb-lite/tasks/bead-<id>.md \
     --base origin/main \
     --branch feat/<bead-id>-<short-slug> \
     --run-dir /tmp/rb-lite-<bead-id>-run
   ```

   If using the nix fallback, prefix the same `run ...` arguments with
   `nix run --refresh github:douglaz/rb-lite --`.

6. **Read the JSON summary.** Exit `0` with status `clean` means the panel
   had no P0/P1/P2 findings. For exit `10`, `11`, `12`, `13`, or `70`, use
   the [already-loaded owning skill's exit-code diagnosis table](../orchestrating-with-rb-lite/SKILL.md#exit-codes-and-json-schema) and
   inspect the run artifacts before
   deciding whether to rerun, fix manually, or file a dogfood bead.

<a id="backlog-step-7"></a>

7. **Run local gates.** Use the repo's own verification contract. In the
   Rust/Nix repos this skill was built for, the default gate set is:

   ```bash
   nix develop -c cargo fmt --check
   nix develop -c cargo clippy --locked -- -D warnings
   nix develop -c cargo test --locked --features test-stub
   nix build
   ```

   Treat real failures as part of the bead. Treat pre-existing flakiness as
   a separate bead; don't hand-tune the branch to hide a flaky CI failure.

   **These gates were already green before the bead, so passing them proves
   nothing about it.** For **each** load-bearing behavior the bead introduces —
   a new invariant, an ordering, a clock or lock choice — invert it in the
   working tree, one at a time, and confirm the assertion that pins *that*
   behavior goes red; then revert. Read the failure rather than just observing
   one: a mutation that trips an initialization error or an unrelated assertion
   proves nothing, and a mutation that changes no test outcome means the drain
   shipped a behavior nothing covers.

   **Protect the accepted diff before you invert anything.** rb-lite leaves its
   changes UNCOMMITTED until step 8, so the obvious way to undo a mutation —
   `git restore <file>` / `git checkout -- <file>` — discards rb-lite's accepted
   implementation in that file along with your inversion. The gates ran before the
   mutation and nothing re-runs after the revert, so step 8 would commit and push
   a tree missing part of the work. Commit or stash the accepted diff first, or
   mutate in a scratch copy — not "revert and re-run green". When the accepted fix and a
   regression test sit in the same file, the file-level restore removes both and the suite
   then passes *because* the test that would expose the loss is gone. Verify by diffing the
   restored tree against the preserved diff, not by trusting a green run.

   **A mutation that stays green STOPS the drain — it is not a note to carry into
   step 8.** Diagnosing an uncovered behavior and then committing anyway ships
   exactly what the check was added to catch, and step 8 pushes immediately, so
   there is no later point that is cheaper. Add or repair the test that pins the
   behavior, observe its red run against the inverted code AND its green run
   against the correct code, and only then continue.

   **That repair was never reviewed.** rb-lite returned its verdict on the tree
   before you touched it, and step 9's SHA guard assumes local `HEAD` is the tree
   the panel read — which it no longer is. Red/green proves the test detects the
   behavior; it says nothing about the test's cleanup, isolation, or fixtures.
   Neither obvious continuation is allowed here, which is the real problem: a second
   rb-lite run breaks the one-bead/one-run invariant, and carrying it forward reaches
   step 9's SHA guard, which asserts local `HEAD` is the tree rb-lite reviewed. So take
   the third path — **stop the drain and track the repair as its own work**, on its own
   branch with its own review. If the repair is small enough to belong to this bead, a
   separate reviewer pass over the amended tree is the only in-band option; say which you
   chose. Do not let it ride out on a clean verdict that predates it, and do not pretend
   a second rb-lite run is permitted. If you cannot pin it — the
   behavior is not reachable from a test, or the fix is out of the bead's scope —
   say so and stop; that is a finding about the bead, not a formality to wave
   through. Full rationale is in the [already-loaded owning skill's Verify the landed diff](../orchestrating-with-rb-lite/SKILL.md#verify-the-landed-diff).

<a id="backlog-step-8"></a>

8. **Commit, push, PR.** Add only intentional source/docs/config changes and
   any bead-state sync files the repo expects. Do not commit `.rb-lite/` run
   artifacts. Commit with a real message, push, and create a PR with a body
   that includes the bead id, rb-lite status/rounds, and local test plan.

9. **CI.** Capture the head *before* waiting, then wait for green:

    ```bash
    # Persisted to a file, not just a shell variable. Steps 9 and 10 usually run as
    # separate tool calls, so a variable set here is gone by the merge — and the guard
    # there would then abort a correct drain with "local HEAD moved". Under the git dir,
    # so it is per-checkout and never committed (ADR 0001).
    # Probe both repositories: a fork can host its own PR, and a colliding number in the
    # parent can otherwise make the drain watch checks for somebody else's tree.
    # Guarded: a failed parent lookup is not "not a fork" — it silently drops the one
    # candidate whose same-number PR the ambiguity refusal below exists to catch.
    SELF=$(gh repo view --json nameWithOwner -q .nameWithOwner) \
      || { echo "cannot resolve this repository"; exit 1; }
    PARENT=$(gh repo view --json parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else "" end') \
      || { echo "cannot resolve the parent repository — a PR there would be invisible"; exit 1; }
    LOCAL_HEAD=$(git rev-parse HEAD)
    # Both repos matching is ambiguous, not a tiebreak: the same branch can be opened as a
    # PR against the parent AND the fork, and picking the parent silently can watch and
    # merge a PR the drain never gated. Refuse; pin the intended repo in every -R instead.
    # And a FAILED query is not a miss: "no such PR" is read out of gh's own error text,
    # because a transient failure treated as absence erases one candidate — and with it
    # the refusal — leaving the drain watching whichever PR the outage left visible.
    # PullRequest-level not-found only: both candidates are repos the API just named, so
    # a Repository-level "could not resolve" or an HTTP 404 is lost access, not absence.
    _GH_ERR=$(mktemp) || { echo "mktemp failed"; exit 1; }; trap 'rm -f "$_GH_ERR"' EXIT   # both scripts do this; the snippets leaked it
    R=""; _M=0
    for _r in ${PARENT:+"$PARENT"} "$SELF"; do
      if ! _h=$(gh pr view <pr> -R "$_r" --json headRefOid -q .headRefOid 2>"$_GH_ERR"); then
        grep -qiE 'could not resolve to a pullrequest|no pull requests found' "$_GH_ERR" \
          || { echo "cannot query PR <pr> in $_r — absence not established"; exit 1; }
        _h=""
      fi
      if [ "$_h" = "$LOCAL_HEAD" ]; then _M=$((_M+1)); [ -n "$R" ] || R="$_r"; fi
    done
    [ "$_M" -le 1 ] || { echo "PR <pr> matches this head in BOTH $PARENT and $SELF — ambiguous"; exit 1; }
    [ -n "$R" ] || { echo "cannot find PR <pr> for local HEAD"; exit 1; }
    MERGING_SHA=$(gh pr view <pr> -R "$R" --json headRefOid -q .headRefOid)
    [ -n "$MERGING_SHA" ] || { echo "cannot resolve the PR head"; exit 1; }
    printf '%s\n' "$MERGING_SHA" > "$(git rev-parse --git-path rb-lite-merging-sha)"
    # Bind it to the commit that was actually reviewed. The remote head is only the right
    # thing to merge if it IS your local HEAD — the tree rb-lite ran on and step 7's gates
    # passed on. If the branch moved since step 8, green CI would otherwise merge code no
    # panel and no gate ever saw.
    [ "$MERGING_SHA" = "$(git rev-parse HEAD)" ] \
      || { echo "PR head $MERGING_SHA is not the reviewed local HEAD — re-run the panel"; exit 1; }
    gh pr checks <pr> -R "$R" --watch
    ```

   Capture first, because the SHA is what makes the pin mean anything. Reading it
   *after* the checks pass adopts whatever is there then — so a force-push landing
   between green CI and the merge gets pinned to itself and sails through the very
   guard meant to catch it. Pinning the pre-CI SHA makes GitHub reject the merge
   instead; rerun the checks against the new head and try again.

   On known-flaky CI, rerun failed jobs via `gh run rerun <id> --failed`; do not
   keep changing product code just to dodge a flake.

10. **Merge and reset.** Squash-merge the PR, delete the branch, then reset local state
    to *where the merge landed* — not to `origin`, which on a fork is your own copy — and rerun the
    authoritative build gate before taking the next bead:

    ```bash
    # Read the step-9 pin before resolving the host. Matching the PR against that SHA keeps
    # a same-number PR in the parent from winning when the real PR is owned by the fork.
    MERGING_SHA=$(cat "$(git rev-parse --git-path rb-lite-merging-sha)" 2>/dev/null || echo "")
    [ -n "$MERGING_SHA" ] || { echo "no pinned SHA — re-run step 9"; exit 1; }
    SELF=$(gh repo view --json nameWithOwner -q .nameWithOwner) \
      || { echo "cannot resolve this repository"; exit 1; }
    PARENT=$(gh repo view --json parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else "" end') \
      || { echo "cannot resolve the parent repository — a PR there would be invisible"; exit 1; }
    # Same ambiguity rule as step 9: both repos carrying PR <pr> at the pinned SHA means
    # two distinct PRs, and merging the parent's silently can land the one nobody gated.
    # Same absence rule too: only gh's own "no such PR" counts as a miss — a transient
    # failure treated as one hides the second match and merges the survivor. And only the
    # PullRequest-level text: a Repository-level "could not resolve" or an HTTP 404 on a
    # repo the API just named is lost access, not absence.
    _GH_ERR=$(mktemp) || { echo "mktemp failed"; exit 1; }; trap 'rm -f "$_GH_ERR"' EXIT   # both scripts do this; the snippets leaked it
    R=""; _M=0
    for _r in ${PARENT:+"$PARENT"} "$SELF"; do
      if ! _h=$(gh pr view <pr> -R "$_r" --json headRefOid -q .headRefOid 2>"$_GH_ERR"); then
        grep -qiE 'could not resolve to a pullrequest|no pull requests found' "$_GH_ERR" \
          || { echo "cannot query PR <pr> in $_r — absence not established; do NOT merge"; exit 1; }
        _h=""
      fi
      if [ "$_h" = "$MERGING_SHA" ]; then _M=$((_M+1)); [ -n "$R" ] || R="$_r"; fi
    done
    [ "$_M" -le 1 ] || { echo "PR <pr> matches the pinned SHA in BOTH $PARENT and $SELF — ambiguous"; exit 1; }
    [ -n "$R" ] || { echo "cannot find PR <pr> for the pinned SHA"; exit 1; }
    PR_REFS=$(gh pr view <pr> -R "$R" --json baseRefName,headRefName) \
      || { echo "cannot resolve the PR branches"; exit 1; }
    BASE=$(printf %s "$PR_REFS" | jq -r '.baseRefName // ""')
    HEAD_BRANCH=$(printf %s "$PR_REFS" | jq -r '.headRefName // ""')
    [ -n "$BASE" ] && [ -n "$HEAD_BRANCH" ] \
      || { echo "cannot resolve the PR branches"; exit 1; }
    # Check the merge's exit status. `--delete-branch` makes gh switch branches as a side
    # effect, so a FAILED merge still leaves you somewhere plausible-looking — and step 11
    # then closes the bead for a merge that never happened, which is the exact state this
    # skill's reviewed-closure path exists to prevent.
    # The base moves while a bead is built and reviewed, and --match-head-commit pins only
    # the HEAD — a squash replays onto the CURRENT base, so a behind branch lands a
    # composition nobody reviewed while every SHA still matches. Fetch the live base and
    # test ancestry before merging, the same way the PR workflow's merge procedure does.
    # gh's own clone URL: `owner/repo` alone points at public github.com, which on GitHub
    # Enterprise either fails or resolves an unrelated public repo of the same name.
    R_URL=$(gh repo view "$R" --json url -q .url 2>/dev/null) \
  || { echo "cannot resolve the clone URL for $R — do NOT merge"; exit 1; }
    git fetch "$R_URL.git" "+refs/heads/$BASE:refs/remotes/upstream/$BASE" \
      || { echo "cannot fetch the merge target — base unknown, do NOT merge"; echo "  (on a private repo cloned over SSH this is usually missing git credentials for https, not a missing base)"; exit 1; }
    # Against $MERGING_SHA, not HEAD: that is the commit --match-head-commit pins and the
    # one GitHub will squash. A local rebase during CI that was never pushed would make
    # HEAD pass this test while the pinned remote SHA is still behind the base.
    [ "$MERGING_SHA" = "$(git rev-parse HEAD)" ] \
      || { echo "local HEAD moved since step 9 — re-run the panel and the checks"; exit 1; }
    git merge-base --is-ancestor "refs/remotes/upstream/$BASE" "$MERGING_SHA" \
      || { echo "REBASE FIRST — $BASE advanced since the review"; exit 1; }
    # LAST, immediately before the merge, for the reason given at the same spot in the
    # PR workflow's merge procedure: ancestry
    # answers "did $BASE advance", never "is $BASE still the
    # target". A retarget points the PR at a different branch, leaving every check above
    # validating the old one while gh squashes onto the new one — and the head never moves,
    # so --match-head-commit stays satisfied. Read here, not earlier: each check between
    # this read and the merge widens the window. It cannot reach zero (GitHub has no base
    # pin), but it is one API call wide.
    BASE_NOW=$(gh pr view <pr> -R "$R" --json baseRefName -q .baseRefName) \
      || { echo "cannot re-read the merge target — do NOT merge"; exit 1; }
    [ -n "$BASE_NOW" ] && [ "$BASE_NOW" = "$BASE" ] \
      || { echo "the PR was retargeted ($BASE -> ${BASE_NOW:-unknown}) — the panel reviewed against $BASE; re-run the panel"; exit 1; }
    gh pr merge <pr> -R "$R" --squash --delete-branch --match-head-commit "$MERGING_SHA" \
      || { echo "merge did not land — do NOT close the bead"; exit 1; }

    # `gh pr merge` returning 0 means the PR was accepted for merging — which, in a repo with a
    # required merge queue, means ENQUEUED, not landed. Fetching now would read the still-old
    # base and any caller that closes a tracker item here would close it for a merge that has
    # not happened. Wait for the state to actually reach MERGED.
    _n=0
    while [ "$_n" -lt 60 ]; do
      _n=$((_n+1))
      _ST=$(gh pr view <pr> -R "$R" --json state -q .state 2>/dev/null || echo "")
      [ "$_ST" = "MERGED" ] && break
      [ "$_ST" = "CLOSED" ] && { echo "PR was closed without merging"; exit 1; }
      sleep 10
    done
    [ "$_ST" = "MERGED" ] || { echo "PR still not merged (state=$_ST) — do NOT proceed"; exit 1; }

    # Reset from where the merge LANDED. On a fork clone `origin` is your fork and does
    # not contain the upstream squash commit, so resetting to origin/$BASE silently starts
    # the next bead from a tree missing the one just merged — its PR then replays or
    # conflicts with it.
    # gh's own clone URL: `owner/repo` alone points at public github.com, which on GitHub
    # Enterprise either fails or resolves an unrelated public repo of the same name.
    R_URL=$(gh repo view "$R" --json url -q .url 2>/dev/null) \
  || { echo "cannot resolve the clone URL for $R — do NOT merge"; exit 1; }
    git fetch "$R_URL.git" "+refs/heads/$BASE:refs/remotes/upstream/$BASE" \
      || { echo "cannot fetch the merge target"; echo "  (on a private repo cloned over SSH this is usually missing git credentials for https, not a missing base)"; exit 1; }
    # `checkout -B` moves the branch ref unconditionally, and a clean worktree does not
    # protect committed work: any local commit on $BASE that upstream lacks becomes
    # unreachable. A same-name fork PR is different: local $BASE is the feature head, and
    # the squash commit cannot contain it. Allow only the verified, pinned PR head itself;
    # a later local commit still refuses the reset.
    if git show-ref --verify --quiet "refs/heads/$BASE" \
       && ! git merge-base --is-ancestor "$BASE" "refs/remotes/upstream/$BASE"; then
      if [ "$HEAD_BRANCH" != "$BASE" ] \
         || [ "$(git rev-parse "refs/heads/$BASE")" != "$MERGING_SHA" ]; then
        echo "local $BASE has commits upstream does not — refusing to reset; rebase or push them first"
        exit 1
      fi
    fi
    # Refuse a dirty worktree HERE, immediately before the reset: the merge-queue wait
    # above can run ten minutes, and `checkout -B` silently CARRIES any nonconflicting
    # tracked modification onto the fresh base — the build below then passes and the next
    # bead inherits work that was never on this branch. FULL status, untracked included:
    # checkout does not move an untracked file, but it does not remove it either, so a
    # file created during the wait sits in the "fresh" base worktree where the build and
    # the next bead's branch inherit it — unreviewed, and invisible to `-uno`.
    _WT=$(git status --porcelain) || { echo "cannot read the worktree — not resetting"; exit 1; }
    [ -z "$_WT" ] || { echo "worktree changed while waiting for the merge — resolve that before resetting to $BASE"; exit 1; }
    git checkout -B "$BASE" "refs/remotes/upstream/$BASE" \
      || { echo "cannot reset to the merge target"; exit 1; }
    nix build
    ```

    Substitute `master` only when the repo actually uses `master`.

<a id="backlog-step-11"></a>

11. **Close the bead, through a reviewed path.** Run `"$BEADS_JSONL_RESOLVER" --run-br update <bead-id> -s closed`
    after the merged code is present on the base branch. That write lands in the
    tracked `.beads/*.jsonl`, so do **not** commit it straight to the default branch —
    it would reach the branch unreviewed. Carry the closure commit into the next bead's
    branch, where it rides that PR; when the queue is empty and there is no next branch,
    open one small metadata PR for it **and land it** — carry it through review and merge
    like any other. Opening it is not enough: until it merges, the closure never reaches
    the default branch and a fresh clone still shows the bead open, which is the failure
    this reviewed path exists to prevent. The drain is not done until that PR is merged. Do not leave it uncommitted either, or the next
    run starts from a dirty base and silently carries the previous closure into its diff.

    **Give the PR body a machine-readable marker line, one per bead it closes:**

    ```text
    bead-closure: <bead-id>
    ```

    Step 8 puts the bead id in every ordinary work PR body too, so the id alone cannot
    distinguish "the work merged" from "the closure merged" — and step 12's resume
    discovery depends on telling them apart. The marker is what it filters on.

    Verify it landed with a checked *explicit* sync: it propagates a real exit code, which
    the automatic flush after `"$BEADS_JSONL_RESOLVER" --run-br update` does not — that one swallows its error. The
    mutation is already in the shared DB, so the sync either writes it out or fails loudly:

    ```bash
    # Resolve and prove the JSONL clean FIRST: `"$BEADS_JSONL_RESOLVER" --run-br update` auto-flushes the cache over it.
    # Clear loader injection in this already-running shell before the locator starts
    # any new process. The resolver/git-clean script bodies are too late: a shebang
    # interpreter would already have loaded caller-selected libraries.
    _bjp_posixly_was_set=${POSIXLY_CORRECT+x}
    _bjp_posixly_value=${POSIXLY_CORRECT-}
    POSIXLY_CORRECT=y
    export POSIXLY_CORRECT
    \unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE \
      LD_ORIGIN_PATH LD_PRELOAD_32 LD_PRELOAD_64 DYLD_INSERT_LIBRARIES \
      DYLD_LIBRARY_PATH DYLD_FRAMEWORK_PATH DYLD_FALLBACK_LIBRARY_PATH \
      DYLD_FALLBACK_FRAMEWORK_PATH LIBPATH SHLIB_PATH GCONV_PATH LOCPATH || {
      printf '%s\n' 'cannot clear dynamic-loader injection before beads-jsonl-path — do NOT write' >&2
      exit 1
    }
    if [ -n "$_bjp_posixly_was_set" ]; then
      POSIXLY_CORRECT=$_bjp_posixly_value
      export POSIXLY_CORRECT
    else
      \unset POSIXLY_CORRECT
    fi
    BEADS_JSONL_RESOLVER=$(
      (
        # Resolve the clean interpreter in a subshell. POSIX special-builtin precedence
        # prevents exported caller functions from redefining this trust path, and the
        # subshell leaves the caller's shell state untouched.
        POSIXLY_CORRECT=y
        export POSIXLY_CORRECT
        \unset -f command builtin exec unset 2>/dev/null || :
        _bjp_bash=$(command -p -v bash) || {
          printf '%s\n' 'cannot locate a trusted Bash for the beads JSONL locator — do NOT write' >&2
          exit 1
        }
        unset BASH_ENV ENV BASH_COMPAT BASH_LOADABLES_PATH BASH_XTRACEFD CDPATH GLOBIGNORE
        exec "$_bjp_bash" --noprofile --norc -p -s <<'__BJP_TRUSTED_BASH__'
    # Privileged Bash ignores inherited functions. Clear the other startup controls too,
    # then perform every candidate, worktree, provenance, and byte-agreement decision here.
    command unset BASH_ENV ENV BASH_COMPAT BASH_LOADABLES_PATH BASH_XTRACEFD CDPATH GLOBIGNORE || {
      printf '%s\n' 'cannot sanitize the beads JSONL locator shell environment — do NOT write' >&2
      exit 1
    }
    while command builtin read -r _ _ _bjp_function; do
      command unset -f -- "$_bjp_function" || {
        printf '%s\n' 'cannot sanitize the beads JSONL locator shell environment — do NOT write' >&2
        exit 1
      }
    done < <(command builtin declare -F)
    unset _bjp_function
    _bjp_git=$(command -p -v git) || {
      printf '%s\n' 'cannot locate a trusted Git for beads-jsonl-path — do NOT write' >&2
      exit 1
    }
    _bjp_cmp=$(command -p -v cmp) || {
      printf '%s\n' 'cannot locate a trusted cmp for beads-jsonl-path — do NOT write' >&2
      exit 1
    }
    _bjp_stat=$(command -p -v stat) || {
      printf '%s\n' 'cannot locate a trusted stat for beads-jsonl-path — do NOT write' >&2
      exit 1
    }
    _bjp_regular_link_count() {
      local path=$1 count
      if count=$("$_bjp_stat" -c %h "$path" 2>/dev/null) && [[ $count =~ ^[0-9]+$ ]]; then
        :
      elif count=$("$_bjp_stat" -f %l "$path" 2>/dev/null) && [[ $count =~ ^[0-9]+$ ]]; then
        :
      else
        return 1
      fi
      printf '%s\n' "$count"
    }
    _bjp_git_environment=( "${!GIT@}" )
    for _bjp_git_variable in "${_bjp_git_environment[@]}"; do
      command unset -- "$_bjp_git_variable" || {
        printf '%s\n' 'cannot sanitize the Git environment for beads-jsonl-path — do NOT write' >&2
        exit 1
      }
    done
    unset _bjp_git_variable _bjp_git_environment

    BEADS_JSONL_RESOLVER=
    BEADS_GIT_RUNNER=
    for _bjp_dir in "$HOME/.claude/skills/beads-jsonl-path" \
      "${CODEX_HOME:-$HOME/.codex}/skills/beads-jsonl-path" \
      "$HOME/.agents/skills/beads-jsonl-path"; do
      case $_bjp_dir in
        /*) ;;
        *) printf '%s\n' 'installed beads-jsonl-path target is not absolute — do NOT write' >&2; exit 1 ;;
      esac
      _bjp_candidate="$_bjp_dir/scripts/resolve-beads-jsonl"
      [ -x "$_bjp_candidate" ] || continue
      [ ! -L "$_bjp_candidate" ] || {
        printf '%s\n' 'installed beads-jsonl-path resolver is a symbolic link — do NOT write' >&2
        exit 1
      }
      _bjp_root_raw=$("$_bjp_git" --no-replace-objects -c core.fsmonitor=false rev-parse --show-toplevel 2>/dev/null) || {
        printf '%s\n' 'cannot resolve the current Git worktree — do NOT write' >&2
        exit 1
      }
      _bjp_root=$(
        CDPATH=
        export CDPATH
        cd -P -- "$_bjp_root_raw" 2>/dev/null && pwd -P
      ) || {
        printf '%s\n' 'cannot canonicalize the current Git worktree — do NOT write' >&2
        exit 1
      }
      _bjp_candidate_dir=$(
        CDPATH=
        export CDPATH
        cd -P -- "$_bjp_dir/scripts" 2>/dev/null && pwd -P
      ) || {
        printf '%s\n' 'cannot canonicalize installed beads-jsonl-path target — do NOT write' >&2
        exit 1
      }
      _bjp_candidate="$_bjp_candidate_dir/resolve-beads-jsonl"
      [ ! -L "$_bjp_candidate" ] || {
        printf '%s\n' 'installed beads-jsonl-path resolver is a symbolic link — do NOT write' >&2
        exit 1
      }
      case $_bjp_root:$_bjp_candidate_dir in
        /:/*|*:"$_bjp_root"|*:"$_bjp_root"/*)
          printf '%s\n' 'installed beads-jsonl-path target is inside the current Git worktree — do NOT write' >&2
          exit 1
          ;;
      esac
      [ -f "$_bjp_candidate" ] || {
        printf '%s\n' 'installed beads-jsonl-path resolver is not a regular file — do NOT write' >&2
        exit 1
      }
      _bjp_link_count=$(_bjp_regular_link_count "$_bjp_candidate") || {
        printf '%s\n' 'cannot inspect installed beads-jsonl-path resolver hard-link count — do NOT write' >&2
        exit 1
      }
      [ "$_bjp_link_count" = 1 ] || {
        printf '%s\n' 'installed beads-jsonl-path resolver has multiple hard links — do NOT write' >&2
        exit 1
      }
      unset _bjp_link_count
      if ! IFS= command builtin read -r _bjp_shebang <"$_bjp_candidate"; then
        printf '%s\n' 'cannot inspect installed beads-jsonl-path resolver interpreter — do NOT write' >&2
        exit 1
      fi
      [ "$_bjp_shebang" = '#!/bin/sh' ] || {
        printf '%s\n' 'installed beads-jsonl-path resolver has an unexpected interpreter — do NOT write' >&2
        exit 1
      }
      unset _bjp_shebang
      _bjp_runner="$_bjp_candidate_dir/git-clean"
      [ -x "$_bjp_runner" ] || {
        printf '%s\n' 'installed beads-jsonl-path Git runner unavailable — do NOT write' >&2
        exit 1
      }
      [ ! -L "$_bjp_runner" ] || {
        printf '%s\n' 'installed beads-jsonl-path Git runner is a symbolic link — do NOT write' >&2
        exit 1
      }
      [ -f "$_bjp_runner" ] || {
        printf '%s\n' 'installed beads-jsonl-path Git runner is not a regular file — do NOT write' >&2
        exit 1
      }
      _bjp_link_count=$(_bjp_regular_link_count "$_bjp_runner") || {
        printf '%s\n' 'cannot inspect installed beads-jsonl-path Git runner hard-link count — do NOT write' >&2
        exit 1
      }
      [ "$_bjp_link_count" = 1 ] || {
        printf '%s\n' 'installed beads-jsonl-path Git runner has multiple hard links — do NOT write' >&2
        exit 1
      }
      unset _bjp_link_count
      if ! IFS= command builtin read -r _bjp_shebang <"$_bjp_runner"; then
        printf '%s\n' 'cannot inspect installed beads-jsonl-path Git runner interpreter — do NOT write' >&2
        exit 1
      fi
      [ "$_bjp_shebang" = '#!/bin/sh' ] || {
        printf '%s\n' 'installed beads-jsonl-path Git runner has an unexpected interpreter — do NOT write' >&2
        exit 1
      }
      unset _bjp_shebang
      unset _bjp_candidate_dir
      if [ -z "$BEADS_JSONL_RESOLVER" ]; then
        BEADS_JSONL_RESOLVER=$_bjp_candidate
        BEADS_GIT_RUNNER=$_bjp_runner
      elif ! "$_bjp_cmp" -s "$BEADS_JSONL_RESOLVER" "$_bjp_candidate" \
          || ! "$_bjp_cmp" -s "$BEADS_GIT_RUNNER" "$_bjp_runner"; then
        printf '%s\n' 'installed beads-jsonl-path companions disagree — do NOT write' >&2
        exit 1
      fi
      unset _bjp_runner
    done
    unset _bjp_candidate _bjp_root _bjp_root_raw _bjp_git _bjp_cmp _bjp_stat
    [ -n "$BEADS_JSONL_RESOLVER" ] && [ -n "$BEADS_GIT_RUNNER" ] || {
      printf '%s\n' 'beads-jsonl-path companion unavailable — do NOT write' >&2
      exit 1
    }
    printf '%s\n' "$BEADS_JSONL_RESOLVER"
    __BJP_TRUSTED_BASH__
      )
    ) || exit 1
    BEADS_GIT_RUNNER=${BEADS_JSONL_RESOLVER%/*}/git-clean
    unset _bjp_candidate
    # Installed targets only. A relative `skills/beads-jsonl-path/scripts/resolve-beads-jsonl`
    # is whatever executable the repo being drained planted there, and this snippet would
    # run it. From a checkout, run that checkout's copy by absolute path instead.
    [ -n "$BEADS_JSONL_RESOLVER" ] || {
      echo "beads-jsonl-path companion unavailable — do NOT write" >&2
      exit 1
    }
    BEADS_JSONL=$("$BEADS_JSONL_RESOLVER") || exit 1
    "$BEADS_JSONL_RESOLVER" --run-br update <bead-id> -s closed || { echo "br update failed"; exit 1; }
    "$BEADS_JSONL_RESOLVER" --run-br sync --flush-only || { echo "not persisted"; exit 1; }
    ```

    **Check for divergence BEFORE the first `br` write.** `"$BEADS_JSONL_RESOLVER" --run-br update` auto-flushes, so a
    staged or unstaged divergence in the JSONL is destroyed by the very first mutation — and
    since neither the index nor `HEAD` holds it, every later diff shows only your intended
    change, which makes the loss *undetectable*, not merely unrecoverable. Resolve and
    prove the real path clean with `beads-jsonl-path/scripts/resolve-beads-jsonl` before
    any writing `br` command; `.beads/issues.jsonl` is only the default layout, and a
    hardcoded path gives a false all-clear on a `.beads.jsonl` repo.

    **That sync proves the closure reached the file. It says nothing about what else the
    same write overwrote.** Every `br` write flushes the whole gitignored cache over the
    tracked JSONL, so a write to **one** bead rewrites **all** of them, and any body the
    cache holds a stale copy of is reverted. Observed on `"$BEADS_JSONL_RESOLVER" --run-br 0.2.19`: closing a single bead
    silently reverted ~40 KB of specification text across three *other* beads and deleted a
    fourth. Exit 0, success message, nothing failed. This step is the last write of every
    bead, which is how the drain routes you into it every time.

    Hand-editing the JSONL is what makes the cache stale — a hand edit does not advance
    `updated_at`, so cache and file hold different bodies under identical timestamps and
    nothing can tell them apart. **Write bead text through `"$BEADS_JSONL_RESOLVER" --run-br update <id> --description "<full body>"`, never
    the file.** The task template's ".beads/ is orchestration state" line is a *reviewing*
    scope rule, not an editing licence. And the advertised guard does not help: `"$BEADS_JSONL_RESOLVER" --run-br sync
    --help`'s "Stale DB Guard" is an **id**-level check, so same-id-different-body — the
    case that loses text — is unguarded by design.

    So field-diff the resolved path before committing any `br` write. Rerun the
    resolver-locator block above, stopping before its final clean-mode `BEADS_JSONL=` call,
    and resolve it with
    `BEADS_JSONL=$("$BEADS_JSONL_RESOLVER" --allow-dirty) || exit 1` here: the write already
    happened, so the divergence you are inspecting is exactly what the default clean-state
    mode refuses. In recovery use
    `BEADS_JSONL=$("$BEADS_JSONL_RESOLVER" --recovery) || exit 1`, which can name a missing
    artifact without pretending it is still tracked and structurally safe. A fresh
    recovery session that
    hardcodes `.beads/issues.jsonl` restores nothing on a `.beads.jsonl` repo. A full-file
    re-serialization with every id on both sides is normal; ids on only one side, or a
    `description` you did not touch, is the tell.

    **Recovery depends on which side holds the good text, and guessing cements the loss.**

    - **(a) cache stale, file still good** — rebuild the cache from the file.
      `"$BEADS_JSONL_RESOLVER" --run-br sync --import-only` alone cannot do it: it compares `updated_at`, so equal
      timestamps with different bodies report `Skipped: N (up-to-date)` forever. The stale
      DB has to go first.
    - **(b) the flush already ran and the diff shows damage** — the working copy *is* the
      damaged artifact. Restore it from the good side, **rebuild the cache**, and only then
      replay: replaying first lets the still-stale cache auto-flush over what you just
      restored. Read
      `"$BEADS_GIT_RUNNER" --literal-pathspecs diff --no-ext-diff --no-textconv --text --cached -- "$BEADS_JSONL"`
      and
      `"$BEADS_GIT_RUNNER" --literal-pathspecs diff --no-ext-diff --no-textconv --text -- "$BEADS_JSONL"`,
      then decide explicitly which of the index, worktree, or `HEAD` holds the good
      bodies; a staged copy only proves a choice exists, and an earlier flush may
      have been staged before anyone noticed.

    Four things the recipe must do in both cases, each learned by getting it wrong: back up
    the cache and **check the copy succeeded**; **verify the DB and its `-wal`/`-shm`
    siblings are actually gone** (`rm -f` is silent on a permissions failure, and a
    surviving cache makes the import skip equal-timestamp records and report success);
    **check the import and the replay before any flush** (the stale DB is already deleted,
    so a failed import leaves an empty one and the flush writes *that* over what you just
    restored); and **rebuild the cache BEFORE replaying anything** — restore, delete and
    re-import the DB, and only then replay. Restoring the file and replaying straight away
    lets the first `br` command auto-flush the *still-stale* cache over what you just
    restored, destroying the recovery with the recovery. And **replay the complete intended
    delta**, not one command: the drain's case is a single closure, but
    `plan-to-beads-transfer` and `bead-polish-loop` batch, so restoring from git there
    discards their legitimate work unless the whole manifest is replayed.

    **A round summary is not a replay manifest.** It records what you decided, not the
    generated ids, the exact field values, or the order they were written in — and recovery
    discards the working JSONL before you can go back and read them off it. So batching
    callers must write the manifest *before* the first mutation: one line per intended `br`
    command, complete enough to re-run verbatim. A coverage matrix or a round summary
    reconstructed afterwards is a description of the work, not a copy of it.

    Git is the whole recovery, which is why the field-diff must happen **before** you stage
    anything: an uncommitted hand-edit that a flush overwrote is simply gone. That is the
    sharpest reason never to write bead text through the file.

    This is **not** the pre-0.1.45 corruption bug in
    [owning skill's Tool dependencies](../orchestrating-with-rb-lite/SKILL.md#tool-dependencies): no
    `ISSUE_NOT_FOUND`, no branch reset, and every command reported success.

    Closing on the feature branch before the merge is **not** a safe shortcut, however
    transactional it looks — the beads DB is shared across branches with no git
    awareness, and import is last-write-wins, so the closure leaks. See
    `docs/adr/0003-bead-closure-stays-post-merge.md` for the code evidence.

<a id="backlog-step-12"></a>

12. **Loop.** Return to `"$BEADS_JSONL_RESOLVER" --run-br ready --limit 10` — but **on a resumed drain, look for an
    in-flight closure PR before selecting work.** A closure lives on its metadata branch
    until it merges, so a fresh clone of the default branch sees the old JSONL with the
    bead still open and will happily rebuild and re-merge work that is already done. The
    queue cannot tell you this; only the forge can:

    ```bash
    SELF=$(gh repo view --json nameWithOwner -q .nameWithOwner) \
      || { echo "cannot resolve this repository — closure-PR discovery is incomplete"; exit 1; }
    PARENT=$(gh repo view --json parent -q 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else "" end') \
      || { echo "cannot resolve the parent repository — closure-PR discovery is incomplete"; exit 1; }
    CLOSURE_PRS=()
    for UP in ${PARENT:+"$PARENT"} "$SELF"; do
      # `url` is not decoration: this loop MERGES parent and fork results, and a bare
      # `number` is ambiguous across them — #42 exists in both. Acting on a parent hit with
      # the fork's `-R` opens an unrelated same-numbered PR. The url carries the repository.
      _PRS=$(gh pr list -R "$UP" --state all --limit 1000 --json number,state,headRefName,title,body,url) \
        || { echo "cannot query closure PRs in $UP — do not resume work from partial results"; exit 1; }
      CLOSURE_PRS+=("$_PRS")
      # 1000 is a CAP, not "all of them". With more newer PRs than that, the older closure
      # or work PR this recovery exists to find falls outside the snapshot, both filters
      # come back empty, and the drain rebuilds work that already merged. A saturated page
      # is the only case where anything can hide, so pay for the search only then.
      if [ "$(printf '%s' "$_PRS" | jq 'length')" -ge 1000 ]; then
        _MORE=$(gh pr list -R "$UP" --state all --limit 1000 --search "$BEAD_ID in:body" \
                  --json number,state,headRefName,title,body,url) \
          || { echo "closure search in $UP failed — do not resume from partial results"; exit 1; }
        CLOSURE_PRS+=("$_MORE")
      fi
    done
    printf '%s\n' "${CLOSURE_PRS[@]}" \
      | jq -s --arg id "$BEAD_ID" 'add | unique_by(.url) | .[] | select($id != "" and ((.body // "") | ascii_downcase
        | test("(^|\\r|\\n)[[:space:]]*bead-closure:[[:space:]]*" + ($id|ascii_downcase|gsub("\\.";"\\.")) + "[[:space:]]*(\\r|\\n|$)")))'
    # SAME shell, same snapshot: the bead's work PRs, MERGED **or still OPEN**. Consulted
    # whenever the marker query above is empty — see below. MERGED-only hid the third
    # resume state: a work PR opened but not yet landed carries the bead id and no
    # `bead-closure:` marker, so neither query saw it and the drain re-entered step 6 to
    # rebuild work that was already open for review. Run separately this would re-fetch,
    # and a fetch that failed here while the marker query succeeded would silently read as
    # "nothing merged", the exact collapse this query exists to close.
    printf '%s\n' "${CLOSURE_PRS[@]}" \
      | jq -s --arg id "$BEAD_ID" 'add | unique_by(.url) | .[] | select(.state=="MERGED" or .state=="OPEN")
          | select($id != "" and ((.body // "") | ascii_downcase
            | test("(^|[^a-z0-9._-])" + ($id|ascii_downcase|gsub("\\.";"\\.")) + "([^a-z0-9._-]|$)")))'
    ```

    `BEAD_ID` is the bead you are about to take — loop this query over each open bead from
    `"$BEADS_JSONL_RESOLVER" --run-br ready`/`"$BEADS_JSONL_RESOLVER" --run-br list` rather than assuming a variable survived the clone. Empty, the
    filter rejects everything and the closure PR this exists to find is missed.

    Keyed on the **`bead-closure:` marker plus the bead id**, not on the id alone: step 8
    puts the id in every ordinary work PR body, so an id-only filter returns the merged
    work PR for any bead whose work landed — which on a fresh clone looks exactly like
    closure history when no closure was ever opened, and defeats the guard. Not a
    branch-naming convention either — nothing mandates one. The raised `--limit` matters
    because `gh pr list` returns 30 by default — an older closure PR hides behind newer
    work PRs, which is the resume case this exists for.

    **An empty result from the marker query answers only "no closure PR was opened" — it
    is NOT evidence that nothing merged.** A drain that stops between step 10's merge and
    step 11's closure PR leaves exactly that state: the work merged, the bead still open
    in the JSONL, and no marker anywhere for the first query to find. Reading empty as
    "unfinished" there rebuilds and re-merges code already on the base. The second query
    in the block is what tells those apart: it asks the same snapshot whether the bead's
    WORK already merged.

    Read any hit before acting on it. **Take the repository from the hit's `url`, never
    from the number alone** — these results merge the parent's PRs with the fork's, and
    #42 exists in both; a parent hit acted on with the fork's `-R` lands you on an
    unrelated PR. Then **read its `state` — it names where to resume**. `MERGED`: a merged PR carrying the id is almost certainly the work PR, and
    the bead open in the default branch's JSONL beside it is precisely the interrupted
    state; do **not** rebuild the bead, its code is on the base — resume at step 11, close
    the bead and land the closure PR. `OPEN`: the work PR is up and has not landed, so
    resume *that* PR's review-and-merge flow at step 9 rather than rebuilding — a rebuild
    here races an open review and lands the bead twice.

    Only when *both* queries are empty does "not started" stand, which is a narrower claim
    than the "not started *or* not merged" this once read as — that phrasing quietly
    folded the OPEN work PR into the same answer. On a drain older than these markers and
    id-carrying bodies, even that needs the hits read by hand, because neither convention
    was in force when its PRs were written.

    An OPEN one: land it before taking another bead. A CLOSED-but-unmerged one is worse — the
    work PR already merged, the closure never did, and `--state open` cannot see it: reopen
    or replace it rather than rebuilding the bead. `drive`'s resume checklist does
    the same discovery for the same reason (`skills/drive/references/phases.md` § LAND).

    Stop when the queue is empty **and** any
    final metadata PR from step 11 has merged — an open closure PR means the drain is
    still in flight, however empty the queue looks. Also stop when
    the user says stop, a bead needs human product/security judgment, or a
    P0/P1 dogfood bead interrupts the queue.
