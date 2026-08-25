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

Use this mode when the user wants to clear an existing `br` backlog with
rb-lite. The beads are the input; do not invent a fresh work list. Codex is
operating the queue and PR workflow, while rb-lite handles the inner
implement → review loop for each bead.

<a id="backlog-step-1"></a>

1. **Pick, through the one shared selector.** Bead selection never runs a bare `br` in the
   caller's shell. Prepare its two inputs **once per scheduling session**:

   - **The pinned executable.** Admit the exact `br v0.3.2` artifact and record
     `PRIVATE_BR` (its canonical path in a private directory outside the driven worktree)
     and `PRIVATE_BR_OID` (`"$BEADS_GIT_RUNNER" hash-file "$PRIVATE_BR"`), exactly as
     [step 11](#backlog-step-11) does. Provenance comes from the artifact — the pinned
     Linux digests or a recorded local release build of the exact commit — never from a
     path and object id someone handed you.
   - **The helper.** Select `SELECT_BEAD_LANES` through the installed-companion trust
     block, as one absolute path **outside** the driven worktree:
     `$HOME/.claude/skills/rb-lite-backlog-drain/scripts/select-bead-lanes`, the
     `${CODEX_HOME:-$HOME/.codex}` equivalent, or `$HOME/.agents/...`. Never execute a
     repository-relative `skills/rb-lite-backlog-drain/scripts/select-bead-lanes`: that
     path is whatever the repository being drained planted there.
   - **The shell you call from.** Stay in the loader-cleared shell
     [`beads-jsonl-path`](../beads-jsonl-path/SKILL.md#resolve-before-writing) established,
     where `BEADS_GIT_RUNNER` was admitted: no script can clear `LD_PRELOAD` for its own
     interpreter, so the caller does it once before these processes start. Clear the Beads
     location namespace in that same shell too — the selector and
     [step 11](#backlog-step-11) clear it internally, but E1's `--run-br` deliberately
     **forwards** `BEADS_*`/`BR_*`, so an override left standing sends every other step to
     a different store than the one selection was authorized against.

     ```bash
     for _v in ${!BEADS_@} ${!BR_@}; do
       case $_v in BEADS_JSONL_RESOLVER|BEADS_GIT_RUNNER) continue ;; esac
       unset "$_v" || { echo "cannot clear the Beads location overrides"; exit 1; }
     done
     ```

   Then call **exactly one** of the two modes, and keep calling that same one:

   ```bash
   # A drive with a declared scope (DRIVE.md carries one `**Scope-Label:**` line):
   "$SELECT_BEAD_LANES" --scoped --scope-label drive-open-issues \
     --br-path "$PRIVATE_BR" --br-oid "$PRIVATE_BR_OID"
   # A directly requested generic drain, with no Drive scope in force:
   "$SELECT_BEAD_LANES" --generic --br-path "$PRIVATE_BR" --br-oid "$PRIVATE_BR_OID"
   ```

   Scoped mode requires the active Drive declaration. `drive-status
   --select-bead-lanes-json ...` is its UI delegate; direct invocation avoids a reverse
   dependency between `drive` and this skill.

   Both modes clear the location overrides, run the pinned E1 clean locator, record the
   JSONL's object id, do pinned `--no-db` reads only, and require that same id after the
   last read. Failure, schema violation, or movement exits nonzero with **no stdout**.

   **Route only on the typed object.**

   - `lanes["executor-skills"]` — resume `in_progress` before selecting `ready`; these may
     authorize a local BUILD. Take the top P0 first, otherwise the lowest-numbered P1;
     descend to P2 only if the user says so or the P1 list is empty or oversized. Do not
     start a second branch while this serialized drain still has a resumed bead.
   - `lanes["executor-rb-lite"]` — routable, but only as **external** delegation. It never
     authorizes local execution here.
   - `lanes["authority-human"]` — report and **stop**. An authority row blocks automated
     routing whatever else is ready.
   - Every array empty with `unresolved_count > 0` — a graph problem, not a finished
     scope: report GRAPH. `blocked_count` says how much of it is dependency-blocked.
   - In scoped mode, `unresolved_count == 0` with every array and count zero — DONE, and
     only under the existing DRIVE-record precondition.

   Generic mode answers the same questions with `ready`/`in_progress` at the top level and
   no lanes. Ready or in-progress work authorizes generic BUILD. With no executable row,
   positive unresolved means GRAPH; zero unresolved/counts/arrays means DONE without `DRIVE.md`.
   An ordinary **unlabeled** row is work, not an empty queue, and must never be read as DONE.
   If any unresolved row carries `drive-open-issues`,
   `executor-skills`, `executor-rb-lite`, or `authority-human`, it refuses with
   `Drive-managed labels require scoped routing`: recognized metadata belongs to the scoped
   router, never to a generic local drain. That unresolved-row check is the whole of what
   generic mode enforces — it never reads `DRIVE.md`, so choosing the mode is the caller's
   assertion, made here, that no Drive scope is in force. The mode chosen here also fixes the
   `LANE_LABEL` [step 11](#backlog-step-11) closes under: a scoped row's own lane, or
   `generic-unlabeled` for a row this mode returned.

2. **Read, through the same pinned tool and store.** Use step 1's retained inputs:

   ```bash
   "$BEADS_JSONL_RESOLVER" --pinned-br "$PRIVATE_BR" "$PRIVATE_BR_OID" --run-br \
     --no-db --no-auto-import --no-auto-flush show <id>          # add --json if it helps
   ```

   Not a bare `--run-br show`: that one resolves `br` on the caller's PATH, and its
   DB-mode read answers out of the local cache — which step 1's `--no-db` selection never
   consulted and cannot vouch for. The body you write the task from would then be whatever
   a stale cache holds, not the bead the selection authorized. `--no-db` reads the same
   clean tracked JSONL the selector routed on, and the pinned prefix is the same tool. The
   store is the one step 1's shell already fixed by clearing the location overrides. If
   the acceptance criteria are vague, pause and ask the user before writing the task.

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

11. **Close the bead natively, after the merge.** This is the canonical closure fact for
    every skill in this repository; the other command-bearing consumers link here rather
    than carrying their own copy.

Closure is `br v0.3.2`'s own primitive: one full-ID `close --reason --transition-comment`,
then one strict `sync --flush-only`. No wrapper, marker, rollback, batching, or `--force`.
Run it on a **fresh standalone clone** of merged default, never a linked worktree: pinned
`v0.3.2` keeps a worktree-local cache, so a linked checkout can split state across two
caches. The exact release is mandatory.

**Before the block below, establish the two inputs it will not establish for you.**

- `PRIVATE_BR` / `PRIVATE_BR_OID`. Provenance comes from the artifact, never a
  caller-supplied pair. The one accepted prebuilt is Linux archive
  `br-0.3.2-linux_x86_64.tar.gz` (SHA-256
  `e67c560e77e912490e44a65e3e9c13205210d171e729c5d801072ee508207288`) and the binary it
  contains (SHA-256
  `590aebae292bca9d36bf90d3219dcb27a3536f402864841b2a11d5c07c4c6c63`); on any other
  platform, build commit `4104c31e79bf806f53e2eba0a4cd2ba6c594f8b9` locally in release
  mode from a clean checkout and record the source commit, the build command, and the
  resulting digest. Place exactly that executable as `br` in a private directory
  **outside** the clone with `"$BEADS_GIT_RUNNER" make-temp-dir` and `copy-file`, then
  record `PRIVATE_BR_OID=$("$BEADS_GIT_RUNNER" hash-file "$PRIVATE_BR")`. The
  [`--pinned-br` prefix](../beads-jsonl-path/SKILL.md#pin-one-already-admitted-br-executable)
  re-proves that exact path and object id before every invocation with no PATH fallback,
  so a tool swapped between two commands is refused by the next.
- `BEADS_JSONL_RESOLVER` / `BEADS_GIT_RUNNER`, from
  [`beads-jsonl-path` § Resolve before writing](../beads-jsonl-path/SKILL.md#resolve-before-writing) —
  **stopping before its final clean-mode `BEADS_JSONL=` call**, which runs `br where` and
  so must not precede admission. That bootstrap is the only Git run before admission;
  after it every `br`, `jq`, and Git call goes through those two runners.

`CLOSE_REASON` is one nonempty line carrying durable outcome identity: normally the merged
work-PR URL plus its 40-lowercase-hex merge SHA; for a decision or no-change closure, an
immutable decision/review-thread URL plus the accepted comment, range, or no-change
identity; for an authority publication, an immutable release URL, tag, or commit.
`CLOSE_EVIDENCE` is the nonempty reviewed note, with no NUL and no outer whitespace.
`LANE_LABEL` is `executor-skills`, `executor-rb-lite`, `authority-human`, or internal
`generic-unlabeled` — never a Beads label or graph value, carried by no bead. It names a
row the selector's **generic** mode returned, which by that mode's contract carries no
recognized Drive metadata; without it a generic drain could start ordinary unlabeled work
and have no way to finish it.

Whichever value you pass is checked against the target, never trusted, before the close,
so a mismatch leaves status and comments untouched:

- one of the three lane labels — the target's recognized lane set must be exactly that one
  label, and the row must also carry `drive-open-issues`;
- `generic-unlabeled` — the target must carry none of `drive-open-issues`,
  `executor-skills`, `executor-rb-lite`, or `authority-human`, which is the same guarantee
  generic selection already enforced when it handed the bead over.

Neither classification can stand in for the other, and a missing, multiple, wrong, or
out-of-scope one refuses before the close. A fifth value refuses at the accepted-value
guard, before the private directory or the pinned binary, so it never reaches the
cache-creating import.

`CLOSE_SNAPSHOT_DIR` is empty first; the block prints its private directory — **keep that
path**. There is no rollback/state marker. Before `CLOSURE_COMPLETE`, recovery follows the
matrix below, not always a same-clone resume: an incomplete snapshot or pre-close state means
abandon this clone and restart fresh; eligible closed states resume here. The captured line is
durable completion evidence. Only then are artifacts removed best-effort; interruption after it
cannot retract completion, and cleanup failure only warns.

Because that directory is caller-supplied and the resume writes fixed names into it before
classifying anything, it is **admitted before it is opened**: one canonical, absolute,
owner-held, mode-0700 real directory outside the clone, every artifact name it knows
absent or an owner-held regular single-link file. Symlinked directory or artifact,
hard-linked outside alias, non-private mode, or a path inside the worktree refuses before
the first redirection — which is why a first entry prints the canonical spelling of the
directory it just made.

Exact v0.3.2 `where --json` owns `database_path`; metadata may rename the cache. Its
canonical parent must be inside the clone, and the recorded exact path and sidecars govern
both entry and resume. The block never assumes `beads.db`.

```bash
# BEGIN NATIVE CLOSE
# Inputs: BEAD_ID CLOSE_REASON CLOSE_EVIDENCE LANE_LABEL PRIVATE_BR PRIVATE_BR_OID
# CLOSE_SNAPSHOT_DIR (empty on a first entry), BEADS_JSONL_RESOLVER, BEADS_GIT_RUNNER.
set -uo pipefail
# Bash imports the caller's exported functions, so a caller `unset` or `command` would own
# every check below, including the override clearing that decides which store this close
# writes to. POSIX special-builtin precedence is the one lookup a function cannot shadow:
# recover the builtins through it, then drop every inherited function first. Loader
# injection stays a caller obligation; no script can clear LD_PRELOAD for its own
# interpreter.
nc_posix_was=${POSIXLY_CORRECT+x}
nc_posix_value=${POSIXLY_CORRECT-}
POSIXLY_CORRECT=y
\unset -f command builtin exec unset 2>/dev/null || :
while command builtin read -r _ _ nc_function; do
  command builtin unset -f -- "$nc_function" || {
    printf 'CLOSURE_INCOMPLETE %s\n' 'cannot clear the inherited shell functions' >&2
    exit 1
  }
done < <(command builtin declare -F)
if [ -n "$nc_posix_was" ]; then POSIXLY_CORRECT=$nc_posix_value
else command unset POSIXLY_CORRECT; fi
command unset nc_function nc_posix_was nc_posix_value
nc_stop() { printf 'CLOSURE_INCOMPLETE %s\n' "$1" >&2; exit 1; }
# Abandoning is a success of the matrix, not of the closure: the clone is untouched, so
# the remedy is a new clone, not a repair. It still exits nonzero.
nc_abandon() { printf 'CLOSURE_ABANDON %s\n' "$1" >&2; exit 1; }
# Named inputs first: a missing one is this block's fixed diagnostic, not an `unbound
# variable` abort from whichever expansion reaches it first.
for nc_input in BEADS_JSONL_RESOLVER BEADS_GIT_RUNNER BEAD_ID CLOSE_REASON \
  CLOSE_EVIDENCE LANE_LABEL PRIVATE_BR PRIVATE_BR_OID; do
  [ -n "${!nc_input-}" ] || nc_stop "the required input $nc_input is unset or empty"
done
CLOSE_SNAPSHOT_DIR=${CLOSE_SNAPSHOT_DIR-}
NC_PIN=( "$BEADS_JSONL_RESOLVER" --pinned-br "$PRIVATE_BR" "$PRIVATE_BR_OID" --run-br )
NC_NO_AUTO=( --no-auto-import --no-auto-flush )
# Every name this block writes there: a resume admits these before opening any of them,
# and the cleanup at the end removes exactly this list.
NC_SNAPSHOT_ARTIFACTS=( {version,where}.{json,err} {jsonl,db}.path pre.{jsonl,oid}
  import.{out,err} pre-show.{json,err} resume-{jsonl,db}.{json,err}
  retry.jsonl post-show.{json,err} )

[ -d .git ] || nc_stop 'not a standalone clone: .git is not a directory'
# Location overrides decide which store every command below reads and writes: clear the
# whole namespace, exported or not, keeping only the two validated runner paths. Block-own
# arrays are NC_-prefixed so this sweep cannot unset them under `set -u`.
for nc_variable in ${!BEADS_@} ${!BR_@}; do
  case $nc_variable in BEADS_JSONL_RESOLVER|BEADS_GIT_RUNNER) continue ;; esac
  unset "$nc_variable" || nc_stop 'cannot clear the Beads location overrides'
done
case $LANE_LABEL in
  executor-skills|executor-rb-lite|authority-human|generic-unlabeled) ;;
  *) nc_stop 'the expected lane label is not one of the four accepted values' ;;
esac
[[ "$CLOSE_REASON" != *$'\n'* ]] || nc_stop 'the close reason is not one line'
[[ ! "$CLOSE_EVIDENCE" =~ ^[[:space:]]|[[:space:]]$ ]] ||
  nc_stop 'the evidence has outer whitespace'
NC_ROOT=$("$BEADS_GIT_RUNNER" worktree-root) ||
  nc_stop 'cannot resolve the standalone clone root'

if [ -n "$CLOSE_SNAPSHOT_DIR" ]; then
  SNAP=$CLOSE_SNAPSHOT_DIR
  # Caller-supplied, and everything below redirects into it or unlinks a name inside it,
  # so admit it FIRST: one canonical absolute owner-held mode-0700 real directory outside
  # the clone, every known artifact name absent or an owner-held single-link regular file.
  # Otherwise the first `>` follows a replacement to a file this closure does not own.
  NC_BAD_DIR='the retained closure directory is not one canonical private directory outside the clone'
  NC_BAD_ARTIFACT='a retained closure artifact is not a regular private file'
  NC_STAT=$(command -p -v stat) || nc_stop "$NC_BAD_DIR"
  nc_stat() { "$NC_STAT" -c "$1" -- "$3" 2>/dev/null ||
    "$NC_STAT" -f "$2" "$3" 2>/dev/null; }
  nc_snapshot_canonical=$(CDPATH= cd -P -- "$SNAP" 2>/dev/null && command builtin pwd -P) &&
    nc_snapshot_mode=$(nc_stat %a %Lp "$SNAP") &&
    [ -d "$SNAP" ] && [ ! -L "$SNAP" ] && [ -O "$SNAP" ] &&
    [[ "$SNAP" == /* && "$SNAP" != *$'\n'* ]] &&
    [ "$nc_snapshot_canonical" = "$SNAP" ] && [ "$nc_snapshot_mode" = 700 ] ||
    nc_stop "$NC_BAD_DIR"
  case $SNAP in "$NC_ROOT"|"$NC_ROOT"/*) nc_stop "$NC_BAD_DIR" ;; esac
  for nc_artifact in "${NC_SNAPSHOT_ARTIFACTS[@]}"; do
    nc_artifact_path=$SNAP/$nc_artifact
    [ ! -L "$nc_artifact_path" ] || nc_stop "$NC_BAD_ARTIFACT"
    [ ! -e "$nc_artifact_path" ] || {
      [ -f "$nc_artifact_path" ] && [ -O "$nc_artifact_path" ] &&
        [ "$(nc_stat %h %l "$nc_artifact_path")" = 1 ] || nc_stop "$NC_BAD_ARTIFACT"
    }
  done
  [ -s "$SNAP/pre.jsonl" ] && [ -s "$SNAP/pre.oid" ] &&
    [ -s "$SNAP/jsonl.path" ] && [ -s "$SNAP/db.path" ] ||
    nc_stop 'the retained pre-close snapshot is incomplete — abandon this clone and start from a fresh one'
else
  SNAP=$("$BEADS_GIT_RUNNER" make-temp-dir native-close) ||
    nc_stop 'cannot create the private closure directory'
  # Print the canonical spelling: it is the one form the admission above accepts when
  # this same path comes back as CLOSE_SNAPSHOT_DIR.
  SNAP=$(CDPATH= cd -P -- "$SNAP" 2>/dev/null && command builtin pwd -P) ||
    nc_stop 'cannot canonicalize the private closure directory'
fi
printf 'CLOSE_SNAPSHOT_DIR=%s\n' "$SNAP"

# Identity first, and on every entry including a resume: the locator itself runs
# `br where`, so nothing may execute this binary before it has been re-proved.
"${NC_PIN[@]}" "${NC_NO_AUTO[@]}" version --json \
  >"$SNAP/version.json" 2>"$SNAP/version.err" ||
  nc_stop 'the pinned br identity call failed'
[ -s "$SNAP/version.err" ] && nc_stop 'the pinned br identity call wrote to stderr'
"$BEADS_JSONL_RESOLVER" --run-jq -e '.version == "0.3.2" and .build == "release"
  and .commit == "4104c31e79bf806f53e2eba0a4cd2ba6c594f8b9"' \
  <"$SNAP/version.json" >/dev/null ||
  nc_stop 'the pinned br is not the exact v0.3.2 release build'

# Contain and record the pinned `where` database path before import; entry and resume must
# never guess `beads.db`.
"${NC_PIN[@]}" "${NC_NO_AUTO[@]}" where --json \
  >"$SNAP/where.json" 2>"$SNAP/where.err" || nc_stop 'the pinned where call failed'
[ -s "$SNAP/where.err" ] && nc_stop 'the pinned where call wrote to stderr'
DATABASE_PATH=$("$BEADS_JSONL_RESOLVER" --run-jq -er '
  .database_path
  | select(type == "string" and length > 0 and startswith("/") and (contains("\n") | not))' \
  <"$SNAP/where.json" 2>/dev/null) || nc_stop 'the database path is not one absolute line'
nc_database_name=${DATABASE_PATH##*/}
nc_database_dir=${DATABASE_PATH%/*}
[ -n "$nc_database_name" ] && [ "$nc_database_name" != . ] &&
  [ "$nc_database_name" != .. ] && [ "$nc_database_dir" != "$DATABASE_PATH" ] ||
  nc_stop 'the database path has no file name'
NC_DATABASE_DIR=$(CDPATH= cd -P -- "$nc_database_dir" 2>/dev/null && command builtin pwd -P) ||
  nc_stop 'cannot canonicalize the database directory'
case $NC_DATABASE_DIR in
  "$NC_ROOT"|"$NC_ROOT"/*) ;;
  *) nc_stop 'the configured database is outside the standalone clone' ;;
esac
DATABASE_PATH=$NC_DATABASE_DIR/$nc_database_name
unset NC_ROOT NC_DATABASE_DIR nc_database_dir nc_database_name

if [ -z "$CLOSE_SNAPSHOT_DIR" ]; then
  BEADS_JSONL=$("$BEADS_JSONL_RESOLVER" --pinned-br "$PRIVATE_BR" "$PRIVATE_BR_OID") ||
    nc_stop 'the clean beads JSONL locator refused'
  for nc_cache in "$DATABASE_PATH" "$DATABASE_PATH-wal" \
    "$DATABASE_PATH-shm" "$DATABASE_PATH-journal"; do
    { [ -e "$nc_cache" ] || [ -L "$nc_cache" ]; } &&
      nc_stop 'a first entry requires an absent cache — use a fresh standalone clone'
  done
  # Proof input, not a recovery marker: the final comparison reads and re-hashes this copy.
  printf '%s\n' "$BEADS_JSONL" >"$SNAP/jsonl.path" ||
    nc_stop 'cannot record the resolved beads JSONL path'
  printf '%s\n' "$DATABASE_PATH" >"$SNAP/db.path" ||
    nc_stop 'cannot record the resolved database path'
  "$BEADS_GIT_RUNNER" copy-file "$BEADS_JSONL" "$SNAP/pre.jsonl" ||
    nc_stop 'cannot copy the clean beads JSONL'
  PRE_OID=$("$BEADS_GIT_RUNNER" hash-file "$BEADS_JSONL") ||
    nc_stop 'cannot hash the clean beads JSONL'
  [ "$PRE_OID" = "$("$BEADS_GIT_RUNNER" hash-file "$SNAP/pre.jsonl")" ] ||
    nc_stop 'the private copy does not match the clean beads JSONL'
  printf '%s\n' "$PRE_OID" >"$SNAP/pre.oid" || nc_stop 'cannot record the snapshot hash'
  "${NC_PIN[@]}" "${NC_NO_AUTO[@]}" sync --import-only \
    >"$SNAP/import.out" 2>"$SNAP/import.err" || nc_stop 'the pinned import failed'
  [ -s "$SNAP/import.err" ] && nc_stop 'the pinned import wrote to stderr'
  "${NC_PIN[@]}" --no-db "${NC_NO_AUTO[@]}" show "$BEAD_ID" --json \
    >"$SNAP/pre-show.json" 2>"$SNAP/pre-show.err" ||
    nc_stop 'cannot read the target before closing'
  "$BEADS_JSONL_RESOLVER" --run-jq -e --arg id "$BEAD_ID" --arg lane "$LANE_LABEL" '
    def lanes: ["executor-skills", "executor-rb-lite", "authority-human"];
    def carried($names): [.[0].labels[]? | select(. as $l | $names | index($l))];
    length == 1 and .[0].id == $id
    and (.[0].status == "open" or .[0].status == "in_progress")
    and (if $lane == "generic-unlabeled"
         then carried(["drive-open-issues"] + lanes) == []
         else carried(lanes) == [$lane] and carried(["drive-open-issues"]) != [] end)' \
    <"$SNAP/pre-show.json" >/dev/null ||
    nc_stop 'the target is not exactly one open or in-progress bead carrying exactly the expected scope and lane'
  # The whole mutation: one full id, no preceding status write, no batch, no --force; a
  # failed second pinned admission is CLOSURE_INCOMPLETE, never another binary.
  "${NC_PIN[@]}" "${NC_NO_AUTO[@]}" \
    close "$BEAD_ID" --reason "$CLOSE_REASON" --transition-comment "$CLOSE_EVIDENCE" &&
  "${NC_PIN[@]}" "${NC_NO_AUTO[@]}" sync --flush-only ||
    nc_stop 'the native close and strict flush did not both succeed'
else
  # Resume. Re-admit, reclassify, and never close a second time.
  BEADS_JSONL=$("$BEADS_JSONL_RESOLVER" --pinned-br "$PRIVATE_BR" "$PRIVATE_BR_OID" \
    --allow-dirty) || nc_stop 'the beads JSONL could not be resolved on resume'
  IFS= read -r RECORDED_PATH <"$SNAP/jsonl.path" &&
    IFS= read -r RECORDED_DB_PATH <"$SNAP/db.path" &&
    IFS= read -r PRE_OID <"$SNAP/pre.oid" ||
    nc_stop 'the retained pre-close snapshot is unreadable'
  [ "$BEADS_JSONL" = "$RECORDED_PATH" ] ||
    nc_stop 'the resumed clone resolves a different beads JSONL'
  [ "$DATABASE_PATH" = "$RECORDED_DB_PATH" ] ||
    nc_stop 'the resumed clone resolves a different database path'
  [ "$PRE_OID" = "$("$BEADS_GIT_RUNNER" hash-file "$SNAP/pre.jsonl")" ] ||
    nc_stop 'the retained pre-close copy no longer has its recorded hash'
  NOW_OID=$("$BEADS_GIT_RUNNER" hash-file "$BEADS_JSONL") ||
    nc_stop 'cannot hash the beads JSONL on resume'
  DB_PRESENT=false
  for nc_cache in "$DATABASE_PATH" "$DATABASE_PATH-wal" \
    "$DATABASE_PATH-shm" "$DATABASE_PATH-journal"; do
    { [ -e "$nc_cache" ] || [ -L "$nc_cache" ]; } && DB_PRESENT=true
  done
  # Three states, and bare "closed" is not one: another reason or comment is a different
  # write than the one this resume is finishing, so it reaches human repair, not a flush.
  NC_CLASSIFY='def evidence_count($rows):
      [$rows[] | select(.id == $id) | .comments[]? | select(.text == $text)] | length;
    def pre_status:
      ([$pre[] | select(.id == $id) | .status]) as $states
      | if ($states | length) == 1
           and ($states[0] == "open" or $states[0] == "in_progress")
        then $states[0] else error("pre-status") end;
    if length == 1 and .[0].status == "closed" and .[0].close_reason == $reason
       and evidence_count(.) == evidence_count($pre) + 1
    then "intended-closed"
    elif length == 1 and .[0].status == pre_status then "pre-close"
    else "other" end'
  # Classify BEFORE any DB-mode command: with the cache absent only `--no-db` may run,
  # because a DB-mode read would create the very cache this branch is deciding about.
  "${NC_PIN[@]}" --no-db "${NC_NO_AUTO[@]}" show "$BEAD_ID" --json \
    >"$SNAP/resume-jsonl.json" 2>"$SNAP/resume-jsonl.err" ||
    nc_stop 'cannot read the target from the JSONL on resume'
  JSONL_STATE=$("$BEADS_JSONL_RESOLVER" --run-jq -er --arg id "$BEAD_ID" \
    --arg reason "$CLOSE_REASON" --arg text "$CLOSE_EVIDENCE" \
    --slurpfile pre "$SNAP/pre.jsonl" "$NC_CLASSIFY" <"$SNAP/resume-jsonl.json") ||
    nc_stop 'cannot classify the resumed JSONL row'
  if ! $DB_PRESENT; then
    [ "$NOW_OID" = "$PRE_OID" ] &&
      nc_abandon 'the cache is absent and the JSONL still matches the retained pre-close snapshot — abandon this clone and start from a fresh one'
    nc_stop 'the cache is absent and the JSONL does not match the retained snapshot'
  fi
  "${NC_PIN[@]}" "${NC_NO_AUTO[@]}" show "$BEAD_ID" --json \
    >"$SNAP/resume-db.json" 2>"$SNAP/resume-db.err" ||
    nc_stop 'cannot read the target from the cache on resume'
  DB_STATE=$("$BEADS_JSONL_RESOLVER" --run-jq -er --arg id "$BEAD_ID" \
    --arg reason "$CLOSE_REASON" --arg text "$CLOSE_EVIDENCE" \
    --slurpfile pre "$SNAP/pre.jsonl" "$NC_CLASSIFY" <"$SNAP/resume-db.json") ||
    nc_stop 'cannot classify the resumed cache row'
  if [ "$DB_STATE" = pre-close ] && [ "$JSONL_STATE" = pre-close ]; then
    [ "$NOW_OID" = "$PRE_OID" ] || nc_stop 'the JSONL diverged from the retained pre-close snapshot — stop for human repair'
    nc_abandon 'the cache and the JSONL are both still in the retained pre-close state — a resumed attempt never closes; abandon this clone and start from a fresh one'
  elif [ "$DB_STATE" = intended-closed ] && [ "$JSONL_STATE" = pre-close ]; then
    # The target row matching is not enough: the flush publishes the cache over the WHOLE
    # file and the proof compares against the retained snapshot, so a diverged JSONL would
    # be destroyed and certified. Exact bytes or human repair.
    [ "$NOW_OID" = "$PRE_OID" ] ||
      nc_stop 'the JSONL diverged from the retained pre-close snapshot — stop for human repair'
    "${NC_PIN[@]}" "${NC_NO_AUTO[@]}" sync --flush-only ||
      nc_stop 'the strict flush failed on resume'
  elif [ "$DB_STATE" = intended-closed ] && [ "$JSONL_STATE" = intended-closed ]; then
    NC_RETRY=$SNAP/retry.jsonl
    "$BEADS_GIT_RUNNER" copy-file "$BEADS_JSONL" "$NC_RETRY" &&
      [ "$NOW_OID" = "$("$BEADS_GIT_RUNNER" hash-file "$NC_RETRY")" ] || nc_stop 'cannot retain the pre-flush JSONL'
    "${NC_PIN[@]}" "${NC_NO_AUTO[@]}" sync --flush-only || nc_stop 'the idempotent strict flush failed on resume'
    if [ "$NOW_OID" != "$("$BEADS_GIT_RUNNER" hash-file "$BEADS_JSONL")" ]; then
      "$BEADS_GIT_RUNNER" copy-file "$NC_RETRY" "$BEADS_JSONL" &&
        [ "$NOW_OID" = "$("$BEADS_GIT_RUNNER" hash-file "$BEADS_JSONL")" ] || nc_stop 'the idempotent flush moved the JSONL and restoration failed — use the retained copy for human repair'
      nc_stop 'the idempotent flush moved the JSONL; its prior bytes were restored — stop for human repair'
    fi
  else
    nc_stop 'the resumed state is not one this matrix admits — stop for human repair'
  fi
fi

# Proof. The flush made the JSONL intentionally dirty — what clean mode refuses — so the
# path comes back through --allow-dirty.
BEADS_JSONL=$("$BEADS_JSONL_RESOLVER" --pinned-br "$PRIVATE_BR" "$PRIVATE_BR_OID" \
  --allow-dirty) || nc_stop 'cannot resolve the flushed beads JSONL'
[ "$PRE_OID" = "$("$BEADS_GIT_RUNNER" hash-file "$SNAP/pre.jsonl")" ] ||
  nc_stop 'the retained pre-close copy changed before the proof'
"$BEADS_JSONL_RESOLVER" --run-jq -e -n --slurpfile pre "$SNAP/pre.jsonl" \
  --slurpfile post "$BEADS_JSONL" --arg id "$BEAD_ID" --arg reason "$CLOSE_REASON" \
  --arg text "$CLOSE_EVIDENCE" '
  def ids($rows): [$rows[] | if (.id | type) == "string" and (.id | length) > 0
                             then .id else error("id") end];
  def changed($before; $after):
    [ (($before | keys) + ($after | keys) | unique)[] as $key
      | select(($before | has($key)) != ($after | has($key))
               or $before[$key] != $after[$key])
      | $key ];
  def multiset($values):
    ($values | map(tojson) | group_by(.) | map({key: .[0], value: length}) | from_entries);
  ids($pre) as $pre_ids | ids($post) as $post_ids
  | if ($pre_ids | unique | length) != ($pre_ids | length)
       or ($post_ids | unique | length) != ($post_ids | length)
    then error("duplicate id") else . end
  | if ($pre_ids | length) != ($post_ids | length) then error("row count") else . end
  | if ($pre_ids | sort) != ($post_ids | sort) then error("id set") else . end
  | INDEX($pre[]; .id) as $before | INDEX($post[]; .id) as $after
  | if any($pre_ids[]; . != $id and (changed($before[.]; $after[.]) | length) > 0)
    then error("bystander") else . end
  | if (changed($before[$id]; $after[$id]) | sort)
       != ["close_reason", "closed_at", "comments", "status", "updated_at"]
    then error("changed fields") else . end
  | $after[$id] as $target
  | if $target.status == "closed" and $target.close_reason == $reason
       and ($target.closed_at | type) == "string" and ($target.closed_at | length) > 0
       and ($target.updated_at | type) == "string" and ($target.updated_at | length) > 0
       and $target.updated_at != $before[$id].updated_at
    then . else error("target fields") end
  | multiset($before[$id].comments // []) as $was
  | multiset($target.comments // []) as $now
  | if any($was | to_entries[]; (($now[.key]) // 0) < .value)
    then error("comment lost") else . end
  | [$now | to_entries[] | {key: .key, value: (.value - (($was[.key]) // 0))}
     | select(.value != 0)] as $added
  | if ($added | length) != 1 or $added[0].value != 1
    then error("comment added") else . end
  | if ($added[0].key | fromjson | .text) != $text
    then error("comment text") else . end
  | true' >/dev/null || nc_stop 'the structural closure proof refused'
"${NC_PIN[@]}" --no-db "${NC_NO_AUTO[@]}" show "$BEAD_ID" --json \
  >"$SNAP/post-show.json" 2>"$SNAP/post-show.err" ||
  nc_stop 'cannot read the closed target'
"$BEADS_JSONL_RESOLVER" --run-jq -e --arg id "$BEAD_ID" --arg reason "$CLOSE_REASON" \
  'length == 1 and .[0].id == $id and .[0].status == "closed"
   and .[0].close_reason == $reason' <"$SNAP/post-show.json" >/dev/null ||
  nc_stop 'the closed target does not read back as closed with the exact reason'
# For human review only. A literal Git diff never substitutes for the proof above.
"$BEADS_GIT_RUNNER" --literal-pathspecs diff --no-ext-diff --no-textconv --text \
  HEAD -- "$BEADS_JSONL" || nc_stop 'cannot render the closure diff for human review'
# Every closure/proof step is final. Publish durable external completion before cleanup:
# before this line the retained proof is resumable; after a captured line completion is
# authoritative even if interruption leaves private artifacts behind.
printf 'CLOSURE_COMPLETE %s\n' "$BEAD_ID" ||
  nc_stop 'cannot emit durable completion evidence'
# Only now remove the exact artifacts best-effort. A copy of the whole pre-close graph does
# not belong in /tmp, but cleanup cannot retract a truthful completion already published.
nc_removed=true
nc_unlink=$(command -p -v unlink) && nc_rmdir=$(command -p -v rmdir) || nc_removed=false
if $nc_removed; then
  # Exactly the names this block writes, never `"$SNAP"/*`: on a resume the directory is
  # caller-supplied, and a glob would unlink whatever else it was handed. Anything
  # unexpected survives, `rmdir` refuses the populated directory, and the removal reports
  # as failed rather than quietly taking a file with it.
  for nc_artifact in "${NC_SNAPSHOT_ARTIFACTS[@]}"; do
    [ -e "$SNAP/$nc_artifact" ] || [ -L "$SNAP/$nc_artifact" ] || continue
    "$nc_unlink" "$SNAP/$nc_artifact" || nc_removed=false
  done
  "$nc_rmdir" "$SNAP" || nc_removed=false
fi
$nc_removed || {
  printf '%s\n' 'the closure is complete, but its private directory could not be removed — delete the printed CLOSE_SNAPSHOT_DIR by hand' >&2 || :
}
# END NATIVE CLOSE
```

The structural proof is the gate, not the exit codes. Both inputs must have unique nonempty
string ids, equal row counts, and identical id sets before any map is built; every bystander
record and every non-allowed target field must preserve key presence *and* JSON value; the
target's changed-field set must be exactly `status`, `closed_at`, `close_reason`,
`updated_at`, and `comments`, with both timestamps present, nonempty, and `updated_at`
actually moved. Comments are compared as a multiset and order-independently, because
v0.3.2 sorts them canonically on export: every pre-close comment object must survive intact
and exactly one new comment must appear, carrying `CLOSE_EVIDENCE`. Losing, rewriting, or
gaining any other comment refuses.

A **pre-mutation refusal leaves status and comments untouched** — a blocked close exits
nonzero with the bead still in its original open or in-progress state and no comment added.
A later failure follows the resume
matrix; nothing here promises rollback. Never close twice, reopen, compensate, or claim a
rollback happened.

**Resume, in one sentence per state.** Cache absent and the JSONL byte-identical to the
retained pre-close snapshot: this clone was never touched — abandon it and start from a fresh
one. Both pre-close: the same answer, but only if the JSONL still matches that snapshot. Cache
closed with the intended reason and comment while the JSONL still matches: flush only. Both
closed: retain the JSONL, retry the idempotent flush once, and restore if it moves before human
repair; otherwise prove. Anything else stops. The two flush branches are eligible only because
the normal path already completed the byte-preserving import and target preflight; each protects
the complete file rather than trusting only the target row's status.

Then run `./check.sh`, take the diff through independent review, and land it as one
standalone metadata PR — see the commit and PR mechanics below.

**That closure commit does not ride a work branch.** The Beads DB is shared across branches
with no git awareness and import is last-write-wins on `updated_at`, so a closure committed
on a feature branch leaks to the default branch at the next checkout;
`docs/adr/0003-bead-closure-stays-post-merge.md` records the code evidence. Closure runs
after the squash merge, on its own standalone clone, branch, and PR, and that PR must
**merge** — until it does, a fresh clone still shows the bead open.

**Give the PR body a machine-readable marker line, one per bead it closes:**

```text
bead-closure: <bead-id>
```

Step 8 puts the bead id in every ordinary work PR body too, so the id alone cannot
distinguish "the work merged" from "the closure merged" — and step 12's resume discovery
depends on telling them apart. The marker is what it filters on.

**Never hand-edit the JSONL.** A hand edit does not advance `updated_at`, so the cache and
the file hold different bodies under identical timestamps and nothing can tell them apart;
`sync --help`'s "Stale DB Guard" is an **id**-level check, so same-id-different-body — the
case that loses text — is unguarded by design. Write bead text with
`"$BEADS_JSONL_RESOLVER" --run-br update <id> --description "<full body>"`. The task
template's ".beads/ is orchestration state" line is a *reviewing* scope rule, not an
editing licence.

**A flush still re-exports every bead**, which is why the proof above compares whole rows
rather than the target alone: on `br 0.2.19`, closing a single bead through the old
`update -s closed` path silently reverted ~40 KB of specification text across three other
beads and deleted a fourth, at exit 0. That is a measured 0.2.19 observation retained as
version-scoped evidence, and the structural proof is what turns it from an invisible loss
into a refusal. The pin does not retire it. Re-measured on 2026-08-22 under both `br 0.2.19`
and the pinned `br v0.3.2`, on the **native** path this step actually runs: import, then a
JSONL-only body edit that does not advance `updated_at`, then
`close --reason --transition-comment` and `sync --flush-only`. Under both versions the
target closed correctly and the edited bystander body silently reverted to the cache's
copy, with all three commands at exit 0 and zero stderr bytes. This is **not** the pre-0.1.45 corruption bug in
[owning skill's Tool dependencies](../orchestrating-with-rb-lite/SKILL.md#tool-dependencies):
no `ISSUE_NOT_FOUND`, no branch reset, and every command reported success.

<a id="backlog-step-11-recovery"></a>

**Recovering from that reversion on a live worktree.** This step's own closure runs on a
disposable standalone clone, so its answer to trouble is the abandon matrix above: throw
the clone away. The skills that write beads *in place* — `bead-polish-loop`,
`plan-to-beads-transfer`, `second-model-bead-audit`, and
[harden-until-clean § 2](../orchestrating-with-rb-lite/references/harden-until-clean.md) —
have no clone to abandon, and they link here for the repair rather than each carrying a
copy. Which side holds the good text decides the recipe, and guessing cements the loss.

- **(a) the cache is stale and the file is still good** — rebuild the cache from the file.
  `sync --import-only` alone cannot do it: it compares `updated_at`, so equal timestamps
  with different bodies report `Skipped: N (up-to-date)` forever. The stale cache has to go
  first.
- **(b) the flush already ran and the field diff shows damage** — the working copy *is* the
  damaged artifact. Read both
  `"$BEADS_GIT_RUNNER" --literal-pathspecs diff --no-ext-diff --no-textconv --text --cached -- "$BEADS_JSONL"`
  and the same command without `--cached`, then decide **explicitly** which of the index,
  the worktree, or `HEAD` holds the good bodies. A staged copy only proves a choice exists,
  and an earlier flush may have been staged before anyone noticed — so restoring
  unconditionally from `HEAD` can overwrite the very copy you selected.

Four things the recipe must do in either case, each learned by getting it wrong: back up
the cache and **check that the copy succeeded**; **verify the cache and its `-wal`/`-shm`
siblings are actually gone** (`rm -f` is silent on a permissions failure, and a surviving
cache makes the import skip equal-timestamp records and report success); **check the import
and the replay before any flush** (the stale cache is already deleted, so a failed import
leaves an empty one and the flush writes *that* over what was just restored); and **rebuild
the cache before replaying anything** — restore, delete, re-import, and only then replay.
Replaying first lets the next `br` command auto-flush the still-stale cache over the
restored file, destroying the recovery with the recovery. Finally, **replay the complete
intended delta**, not one command: a single closure is the drain's case, but the batching
callers above lose their whole round unless the entire manifest is replayed.

**A round summary is not a replay manifest.** It records what was decided, not the
generated ids, the exact field values, or the order they were written in — and recovery
discards the working JSONL before anyone can read them back off it. So a batching caller
writes the manifest *before* its first mutation: one line per intended `br` command,
complete enough to re-run verbatim. Resolve the path for that inspection with
`"$BEADS_JSONL_RESOLVER" --allow-dirty`, or `--recovery` when the artifact may be missing
entirely; a hardcoded `.beads/issues.jsonl` restores nothing on a `.beads.jsonl` repo. Git
is the whole recovery, which is why the field diff has to happen **before** anything is
staged: an uncommitted hand edit that a flush overwrote is simply gone.

<a id="backlog-step-12"></a>

12. **Loop.** Repeat **the same mode** [step 1](#backlog-step-1) chose, with the retained
    `PRIVATE_BR`/`PRIVATE_BR_OID`/`SELECT_BEAD_LANES` — or, after a resume that lost them,
    prepare new inputs the same way first. Never switch modes silently, and never read
    generic unlabeled work as an empty queue. Then, **on a resumed drain, look for an
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

    `BEAD_ID` is the bead you are about to take — loop this query over each unresolved row
    in the typed selection rather than assuming a variable survived the clone. Empty, the
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
