# When the loop misbehaves

Read this when a run does something you did not expect — nits past round 5, a repeatedly
no-op implementer, a dead implementer, a whole run killed by a signal, a ballooning bead,
a hang, or a flag the docs say exists being rejected.

## When the loop misbehaves

- **Reviewers keep finding nits past round 5.** That's reviewer ratchet.
  Check the latest review file: if findings are P3-only, something is
  wrong with the severity floor (it should have stopped). Otherwise,
  stop manually and apply the remaining items. Raising the floor to P1 silences the
  defect reviewers' P2s, where real should-fix findings live, so it is not the fix
  here. (On rb-lite 0.3.x it also filtered out the built-in skeptic; from 0.4.0 that
  reviewer is matched off-floor and is unaffected.)
- **Implementer "stabilized at iteration 1" repeatedly.** The implementer is
  declining to act. The consensus-failure stop catches it after
  `--max-noop-rounds` (default 2) — exit 13. Before overriding, read *why* it
  declined: a stuck implementer and one legitimately rejecting findings as false
  positives or over-specification both look like a no-op round, but only the first
  is a problem. If the latest `review-round-*.md` plus the implementer's own
  output show documented, evidence-backed rejections, exit 13 is the right
  outcome, not a failure to force past. Don't lower `--max-noop-rounds` unless you
  understand the trade-off.
- **Implementer dies (exit 10) — rogue self-terminate or transient API
  failure.** Two recurring causes: the implementer signals/kills its own
  process tree (exit 143 / SIGTERM, with a self-experimentation note in
  `implementer-round-*-iter-*.stderr` — the "self-destruct" mode the task's
  scope guard is meant to prevent), or a transient provider error (429
  rate-limit / 529 overload). Both leave a partial, unreliable working tree.
  Recovery: restore only to the saved pre-run state (reset/delete the rb-lite
  impl branch if it created one; otherwise apply the pre-run commit/stash/patch
  you made before launch). Do not blindly run `git checkout -- .` or remove all
  new files on a branch that may have had user work before rb-lite started.
  Then **relaunch leading with the OTHER implementer** — swap the round-1 preset
  (`--implementer claude,codex` ↔ `codex,claude`). A per-implementer failure
  (one provider overloaded, or one CLI's self-experiment habit) usually doesn't
  recur when the other leads round 1.
- **Whole run dies mid-round with a signal and ~no output (exit 143 / 137, status
  `internal_error`).** If you have more than one rb-lite run going (across sessions
  or projects), this is almost always *another* session's broad `pkill -f rb-lite`
  collateral-killing yours — not a fault in rb-lite, the box, or the task. Just
  relaunch the same run; it'll usually complete. (Distinct from the exit-10
  implementer self-terminate above: that's the implementer's own subprocess; this is
  your entire run getting a signal from outside.) **Corollary for stopping your OWN
  run:** never `pkill -f rb-lite` (or `-f <some-runword>`) — the pattern matches your
  own shell (exit 144 self-kill) AND every other session's run. Stop the tracked
  background task (TaskStop), or send SIGTERM to the exact wrapper PID
  (`pgrep`/`kill <pid>`). Current rb-lite forwards TERM/INT/HUP/QUIT to the active
  child process. If you used SIGKILL, or if implementer/reviewer children remain
  after TERM/INT/HUP/QUIT forwarding, kill the exact orphaned child PIDs separately.
  **No launch trick saves you from this case.** A `pkill -f rb-lite` matches
  rb-lite's own argv regardless of how it was launched. A resource scope
  (`systemd-run --scope`, a cgroup) can help with lifecycle and resource
  containment, but it is not protection from a same-user broad `pkill`, direct
  PID kill, or OOM kill. For a determined
  name/PID/OOM sweep, recoverability (relaunch — the run is resumable, the diff is
  in the tree) is the real defense; stronger isolation means a separate user, PID
  namespace/container, or tighter operational discipline.
- **A run balloons — many rounds, a huge module, edits sprawling into other files.**
  This bead was high-blast-radius and ran unsupervised. Don't keep relaying findings;
  discard and apply the re-scope + file-lock + watch-each-round recovery playbook in
  [task-files.md](task-files.md). (Better: catch it live next time — watch the
  rounds and intervene before it balloons.)
- **Run hangs.** rb-lite has a default 14400s (4 hour) per-iteration
  timeout — far longer than any realistic iteration. If it actually
  needs to be lower, pass `--implement-timeout SECS`. (Reviewers have their
  own 1800s timeout; a timed-out reviewer is dropped from the panel — see
  [verifying-the-diff.md](verifying-the-diff.md) on degraded panels.)
- **`nix run` fails with HTTP 404.** The repo went private, or the user
  doesn't have access. Confirm
  https://github.com/douglaz/rb-lite is public and try again.
- **rb-lite rejects a flag the docs say exists.** You're on a cached revision.
  Rerun with `nix run --refresh github:douglaz/rb-lite -- ...` (or
  `nix profile upgrade`) before concluding the build predates the feature.
