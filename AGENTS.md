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
  trap 'unlink "$_chk"' EXIT
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
_gate_dir=$(mktemp -d) || { echo "cannot create gate directory"; exit 1; }
_gate_log="$_gate_dir/output.log"
_gate_script="$_gate_dir/gate.bash"
_gate_runner="$_gate_dir/supervisor.py"
_gate_pending="$_gate_dir/exec.pending"
  _gate_remove_dir() {
    _gate_remove_rc=0
    for _gate_file in "$_gate_log" "$_gate_script" "$_gate_runner" "$_gate_pending"; do
      if [ -e "$_gate_file" ] && ! unlink "$_gate_file"; then
        _gate_remove_rc=1
      fi
    done
    if ! rmdir "$_gate_dir"; then
      _gate_remove_rc=1
    fi
    return "$_gate_remove_rc"
  }
  _gate_cleanup() {
    _gate_cleanup_rc=$?
    if ! _gate_remove_dir; then
      echo "cannot remove gate directory" >&2
      [ "$_gate_cleanup_rc" -ne 0 ] || _gate_cleanup_rc=1
    fi
    trap - EXIT
    exit "$_gate_cleanup_rc"
  }
  trap _gate_cleanup EXIT
  chmod 700 "$_gate_dir" || { echo "cannot protect gate directory"; exit 1; }
  if ! cat >"$_gate_script" <<'__AGENT_GATE__'
<gate>
__AGENT_GATE__
  then
    echo "cannot write gate script"
    exit 1
  fi
  if ! cat >"$_gate_runner" <<'__AGENT_SUPERVISOR__'
import os
import select
import signal
import subprocess
import sys
import time

root, bash, watchdog_pid, pending_path = sys.argv[1:5]
watchdog_pid = int(watchdog_pid)
log_path = os.path.join(root, "output.log")
gate_path = os.path.join(root, "gate.bash")
runner_path = os.path.join(root, "supervisor.py")
managed_signals = (signal.SIGHUP, signal.SIGINT, signal.SIGQUIT, signal.SIGTERM)
child = None
cancelled = None
signal_ready = False
pending_signal = None

class GateCancelled(BaseException):
    def __init__(self, signum):
        self.signum = signum


def receive_signal(signum, _frame):
    global pending_signal, signal_ready
    was_ready = signal_ready
    signal_ready = False
    if pending_signal is None:
        pending_signal = signum
    if not was_ready:
        return
    signal.pthread_sigmask(signal.SIG_BLOCK, managed_signals)
    raise GateCancelled(pending_signal)


def ignore_managed_signals():
    for signum in managed_signals:
        signal.signal(signum, signal.SIG_IGN)


def group_alive(pgid):
    try:
        os.killpg(pgid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def stop_group(signum):
    if child is None:
        return True
    pgid = child.pid
    try:
        os.killpg(pgid, signum)
    except ProcessLookupError:
        pass
    try:
        os.killpg(pgid, signal.SIGCONT)
    except ProcessLookupError:
        pass
    deadline = time.monotonic() + 0.2
    while group_alive(pgid) and time.monotonic() < deadline:
        time.sleep(0.01)
    if group_alive(pgid):
        try:
            os.killpg(pgid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    try:
        child.wait(timeout=1.0)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(pgid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        try:
            child.wait(timeout=1.0)
        except subprocess.TimeoutExpired:
            return False
    deadline = time.monotonic() + 1.0
    while group_alive(pgid) and time.monotonic() < deadline:
        time.sleep(0.01)
    return not group_alive(pgid)


def remove_private_dir():
    ok = True
    for path in (log_path, gate_path, runner_path, pending_path):
        if os.path.lexists(path):
            result = subprocess.run(
                ["unlink", path],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            ok = result.returncode == 0 and ok
    if not os.path.exists(root):
        return ok
    result = subprocess.run(
        ["rmdir", root],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0 and ok


for managed_signal in managed_signals:
    signal.signal(managed_signal, receive_signal)

try:
    os.unlink(pending_path)
except FileNotFoundError:
    pass
try:
    os.kill(watchdog_pid, signal.SIGTERM)
except ProcessLookupError:
    pass
try:
    os.waitpid(watchdog_pid, 0)
except ChildProcessError:
    pass

rc = 1
try:
    signal_ready = True
    if pending_signal is not None:
        signal_ready = False
        signal.pthread_sigmask(signal.SIG_BLOCK, managed_signals)
        raise GateCancelled(pending_signal)
    environment = os.environ.copy()
    environment["BASH_ENV"] = ""
    with open(log_path, "wb") as output:
        previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, managed_signals)
        try:
            child_bootstrap = (
                "import os,signal,sys;"
                "managed=tuple(map(int,sys.argv[3:]));"
                "signal.pthread_sigmask(signal.SIG_UNBLOCK,managed);"
                "os.execvpe(sys.argv[1],"
                "[sys.argv[1],'--noprofile','--norc','-eo','pipefail',sys.argv[2]],"
                "os.environ)"
            )
            child = subprocess.Popen(
                [
                    sys.executable,
                    "-I",
                    "-c",
                    child_bootstrap,
                    bash,
                    gate_path,
                    *(str(signum) for signum in managed_signals),
                ],
                stdin=subprocess.DEVNULL,
                stdout=output,
                stderr=subprocess.STDOUT,
                env=environment,
                start_new_session=True,
            )
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        rc = child.wait()
        if rc < 0:
            rc = 128 - rc
        if group_alive(child.pid):
            if not stop_group(signal.SIGTERM):
                print("cannot terminate gate process group", file=sys.stderr)
                rc = rc if rc != 0 else 1
            elif rc == 0:
                print("gate left background processes running", file=sys.stderr)
                rc = 1
except GateCancelled as cancellation:
    cancelled = cancellation.signum
    ignore_managed_signals()
    if not stop_group(cancellation.signum):
        print("cannot terminate gate process group", file=sys.stderr)
    rc = 128 + cancellation.signum
except BaseException as error:
    ignore_managed_signals()
    if child is not None and group_alive(child.pid):
        stop_group(signal.SIGTERM)
    print(f"cannot run gate: {error}", file=sys.stderr)
    rc = rc if rc != 0 else 1
try:
    if cancelled is None:
        stdout_fd = sys.stdout.fileno()
        stdout_was_blocking = os.get_blocking(stdout_fd)
        os.set_blocking(stdout_fd, False)
        with open(log_path, "rb") as output:
            while True:
                chunk = output.read(65536)
                if not chunk:
                    break
                pending = memoryview(chunk)
                while pending:
                    try:
                        written = os.write(stdout_fd, pending)
                        pending = pending[written:]
                    except BlockingIOError:
                        select.select([], [stdout_fd], [], 0.1)
        os.set_blocking(stdout_fd, stdout_was_blocking)
    if not remove_private_dir():
        print("cannot remove gate directory", file=sys.stderr)
        rc = rc if rc != 0 else 1
    if cancelled is None:
        print(f"EXIT={rc}")
except GateCancelled as cancellation:
    if "stdout_fd" in locals() and "stdout_was_blocking" in locals():
        os.set_blocking(stdout_fd, stdout_was_blocking)
    cancelled = cancellation.signum
    ignore_managed_signals()
    if child is not None and group_alive(child.pid):
        stop_group(cancellation.signum)
    rc = 128 + cancellation.signum
    if not remove_private_dir():
        print("cannot remove gate directory", file=sys.stderr)
except BaseException as error:
    if "stdout_fd" in locals() and "stdout_was_blocking" in locals():
        os.set_blocking(stdout_fd, stdout_was_blocking)
    ignore_managed_signals()
    print(f"cannot finalize gate: {error}", file=sys.stderr)
    rc = rc if rc != 0 else 1
    if not remove_private_dir():
        print("cannot remove gate directory", file=sys.stderr)
sys.exit(rc)
__AGENT_SUPERVISOR__
  then
    echo "cannot write gate supervisor"
    exit 1
  fi
: >"$_gate_pending" || { echo "cannot create exec marker"; exit 1; }
(
  sleep 2
  if [ -e "$_gate_pending" ]; then
    for _gate_file in "$_gate_log" "$_gate_script" "$_gate_runner" "$_gate_pending"; do
      [ ! -e "$_gate_file" ] || unlink "$_gate_file" 2>/dev/null || :
    done
    rmdir "$_gate_dir" 2>/dev/null || :
  fi
) &
_gate_exec_watchdog=$!
exec python3 -I "$_gate_runner" "$_gate_dir" "${BASH:-bash}" \
  "$_gate_exec_watchdog" "$_gate_pending"
```

Run this as a standalone final command, not as sourced setup for later commands:
`exec` makes the Python supervisor the caller-visible wrapper process, while a
failed `exec` leaves the shell cleanup trap armed. Put self-contained gate
commands between the delimiter lines. The supervisor runs them in a fresh Bash
from a private script with closed stdin, cleared `BASH_ENV`, disabled startup
files, and `pipefail`.
It creates a dedicated process group, handles HUP, INT, QUIT, and TERM even when
the invoking shell inherited an ignored signal, resumes stopped work, waits with
a deadline, and escalates boundedly when the leader or a descendant ignores the
signal. Cleanup happens before the reported final status: supervisor, read,
lingering-process, or cleanup failure turns success into failure but preserves
an existing nonzero/signal status. The wrapper returns that final status,
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

Gate for this repo: `./check.sh`
<!-- end-agent-discipline -->
