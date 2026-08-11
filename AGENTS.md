# AGENTS.md

<!-- agent-discipline-v1 -->
## Working agreement

These rules are here because agents get them wrong by default, not because they
are good general advice.

**Edits must be verified, not assumed.** Prefer your harness's edit tool: it
fails loudly when the target text does not match. `sed -i` and `str.replace()`
do the opposite — a pattern that matches nothing changes nothing, exits 0, and
prints whatever success message you wrote. Batching several edits into one
scripted call is the usual reason this happens, and the saved tool calls are not
worth it. If you do script an edit, assert the target exists before replacing and
make the success message conditional on that assert, then grep the file
afterwards for both the new text and the absence of the old. Prose and markdown
are where this bites hardest: nothing compiles a README, so a silently skipped
edit survives and gets reported as done.

The check does not stop at the file. `nothing to commit, working tree clean` reads
exactly the same whether the work was already committed or was reverted underneath
you by another process holding the tree — so never take that message as proof a
commit happened. Take the exit code instead (`git commit` exits **1** on an empty
commit), and for anything you care about also look inside the commit, since a
partial loss commits cleanly at exit 0:

```
git add -- <every path this change touched>   # not `git add -A`: on a dirty tree it
git diff --cached                            # sweeps in unrelated work — and READ this,
                                             # since staging a path that was already
                                             # dirty takes the other agent's hunks too
git commit -m "<msg>" || { echo "commit produced nothing"; exit 1; }
git show --stat --format= HEAD               # all the paths you meant, and only those
```

Then confirm the *content* landed, per file, by the check that fits it — a file that
gained content must contain a distinctive new phrase; a file you removed lines from must
still exist **and** hold the expected remaining count of the deleted phrase; a deleted path
must be absent. A file that BOTH gained and lost content needs both of the first two — the
added phrase passing says nothing about whether the removal survived. One does not
substitute for another, and each has a way to
lie: `grep` defaults to regex (use `-Fq --`), `git show ... | grep` returns 141 under
`pipefail` when grep exits early (capture to a file first), `grep -c` counts lines rather
than occurrences, and demanding *zero* occurrences rejects a correct partial removal.

```bash
(
  _chk=$(mktemp) || { echo "cannot create the scratch file — do NOT report the commit verified"; exit 1; }
  trap 'rm -f "$_chk"' EXIT
  # ...the three loops, using `grep -Fq --` / `grep -Fo | wc -l || true` on a captured file.
)
```

The subshell keeps that temporary cleanup from replacing an `EXIT` trap owned by
the caller. A clean `git status` is neither check.

The same tools also corrupt without failing. In a `sed` replacement string `&`
means "the whole match", so substituting a value containing `&&` — any shell
command that chains, which is most of them — silently doubles it and reports
success. Substitute with something that treats the replacement as a literal, and
grep for the result afterwards.

**Never pipe a gate through `tail`, `head`, or `grep`.** A pipeline's exit status
is the last command's, and `tail` always succeeds, so a failing build reports
exit 0. Group the entire gate, use a fresh log, save the real status, and return
that status after reading the log:

```bash
(
  _gate_log=$(mktemp) || { echo "cannot create gate log"; exit 1; }
  _gate_cleanup() {
    _gate_cleanup_rc=$?
    if ! rm -f "$_gate_log"; then
      echo "cannot remove gate log" >&2
      [ "$_gate_cleanup_rc" -ne 0 ] || _gate_cleanup_rc=1
    fi
    trap - EXIT
    exit "$_gate_cleanup_rc"
  }
  trap _gate_cleanup EXIT
  _gate_had_errexit=0
  case $- in *e*) _gate_had_errexit=1; set +e ;; esac
  (
    [ "$_gate_had_errexit" -eq 0 ] || set -e
    <gate>
  ) >"$_gate_log" 2>&1
  _gate_rc=$?
  [ "$_gate_had_errexit" -eq 0 ] || set -e
  cat "$_gate_log" || { echo "cannot read gate log"; exit 1; }
  printf 'EXIT=%s\n' "$_gate_rc" || exit 1
  exit "$_gate_rc"
)
```

The nested subshell isolates its cleanup trap from the caller and removes the
private log on normal return, error, or handled termination. The inner subshell
makes one redirection cover an `&&` gate instead of only its final command.
Temporarily disabling wrapper `errexit` permits status capture; restoring it
inside the inner subshell preserves a gate function's original fail-fast
behavior. Cleanup failure turns success into failure but preserves an existing
nonzero/signal status. `exit` otherwise returns the saved status unchanged,
including categorized statuses such as 2 or 124.

**"Passing", "clean", "working", "verified", and "done" require a command and an
exit code.** If you cannot show one, say what you actually observed instead. This
is the single most common way an agent reports success it did not have.

**A claim about what a tool does needs a run, not a recollection.** Prose asserting
observable behaviour — an exit code, which stream output went to, which versions were
tested — is as capable of being wrong as code, and nothing compiles it. Record enough that
a reader can re-run it and disagree: the command, the versions, the mode where the mode
changes the answer, and the observed result with the streams *separated by redirection*
rather than labelled by hand. Two things that are not records: a bare "Measured on
git 2.54.0", which names no command or result, and "fails silently", which names no
version or mode. And observing is not explaining — a rerun gives you the exit code and the
streams, never the *why*; "X fails because Y" needs Y varied on its own with the outcome
changing, or the documentation cited. Absent that, write what you saw and leave the cause
out. A claim you cannot run — a version you do not have — is not yours to assert: say it
is unmeasured and narrow it to a possibility.

**Reviewers read code; they do not run it.** A clean review — human, bot, or
model — is not a passing build. Run the gate yourself before calling anything
done.

**A test that has never failed has proven nothing.** When you add one for a bug,
watch it go red against the unfixed code first. A test asserting behaviour that
was already correct is indistinguishable from a test asserting nothing.

Three things decide whether that red run means anything. Break the **production
behaviour**, never the test's expected value or its setup — those redden any
assertion, including one that never reaches the behaviour. **Read the failure**: it
must name the assertion pinning what you broke, not an unrelated panic. And run **one
mutation per property** the test claims, since reddening the first of two leaves the
second untested while looking verified. If the test drives anything live — a real
database, a running service, real money — do the red run in a disposable environment
or not at all: a deliberately broken build can perform the harmful operation before
any assertion notices.

Gate for this repo: `./install.test && ./skills/pr-with-codex-bot-review/scripts/bot-gate.test && ./skills/drive/scripts/drive-status.test`
<!-- end-agent-discipline -->
