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
POSIXLY_CORRECT=y
\unset -f command builtin exec unset
_gate_outer_bash=$(\command -p -v bash) ||
  { echo "cannot locate trusted Bash"; exit 1; }
\exec "$_gate_outer_bash" --noprofile --norc -p -s <<'__AGENT_GATE_WRAPPER__'
_gate_environment=$(command -p env) || exit 1
while IFS="=" read -r _gate_env_name _; do
  case $_gate_env_name in
    BASH_FUNC_command%%)
      printf "%s\n" "refusing exported command function" >&2
      exit 97
      ;;
    BASH_FUNC_*%%)
      printf "%s\n" "refusing exported shell function" >&2
      exit 97
      ;;
  esac
done <<<"$_gate_environment"
command type -P python3 >/dev/null 2>&1 ||
  { echo "python3 is required for gate supervision"; exit 1; }
_gate_dir=$(command mktemp -d) || { echo "cannot create gate directory"; exit 1; }
_gate_log="$_gate_dir/output.log"
_gate_error="$_gate_dir/error.log"
_gate_script="$_gate_dir/gate.bash"
_gate_runner="$_gate_dir/supervisor.py"
_gate_pending="$_gate_dir/exec.pending"
  _gate_remove_dir() {
    _gate_remove_rc=0
    for _gate_file in "$_gate_log" "$_gate_error" "$_gate_script" "$_gate_runner" "$_gate_pending"; do
      if [ -e "$_gate_file" ] && ! command unlink "$_gate_file"; then
        _gate_remove_rc=1
      fi
    done
    if ! command rmdir "$_gate_dir"; then
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
  if ! command cat >"$_gate_script" <<'__AGENT_GATE__'
<gate>
__AGENT_GATE__
  then
    echo "cannot write gate script"
    exit 1
  fi
  if ! command cat >"$_gate_runner" <<'__AGENT_SUPERVISOR__'
import os
import select
import signal
import subprocess
import sys
import time

root, bash, watchdog_pid, pending_path = sys.argv[1:5]
watchdog_pid = int(watchdog_pid)
log_path = os.path.join(root, "output.log")
error_path = os.path.join(root, "error.log")
gate_path = os.path.join(root, "gate.bash")
runner_path = os.path.join(root, "supervisor.py")
managed_signals = (signal.SIGHUP, signal.SIGINT, signal.SIGQUIT, signal.SIGTERM)
child = None
gate_pgid = None
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


def write_terminal_status(stdout_fd, status):
    global signal_ready
    data = f"EXIT={status}\n".encode("ascii")
    while True:
        signal_ready = True
        _, writable, _ = select.select([], [stdout_fd], [], 0.1)
        if not writable:
            continue
        previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, managed_signals)
        signal_ready = False
        kernel_pending = signal.sigpending().intersection(managed_signals)
        if pending_signal is not None or kernel_pending:
            signum = pending_signal
            if signum is None:
                signum = min(kernel_pending)
            raise GateCancelled(signum)
        ignore_managed_signals()
        try:
            written = os.write(stdout_fd, data)
        except BaseException:
            signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
            raise
        if written != len(data):
            signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
            raise RuntimeError("partial terminal status write")
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        return


def group_alive(pgid):
    try:
        os.killpg(pgid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


subreaper_enabled = False


def enable_child_subreaper():
    global subreaper_enabled
    if not sys.platform.startswith("linux"):
        return
    import ctypes

    libc = ctypes.CDLL(None, use_errno=True)
    prctl = getattr(libc, "prctl", None)
    if prctl is None:
        raise OSError("Linux libc has no prctl")
    prctl.argtypes = (
        ctypes.c_int,
        ctypes.c_ulong,
        ctypes.c_ulong,
        ctypes.c_ulong,
        ctypes.c_ulong,
    )
    prctl.restype = ctypes.c_int
    if prctl(36, 1, 0, 0, 0) != 0:  # PR_SET_CHILD_SUBREAPER
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))
    subreaper_enabled = True


def reap_adopted_children():
    if not subreaper_enabled:
        return
    while True:
        try:
            pid, _ = os.waitpid(-1, os.WNOHANG)
        except ChildProcessError:
            return
        if pid == 0:
            return


def stop_group(signum):
    global gate_pgid
    if child is None or gate_pgid is None:
        return True
    pgid = gate_pgid
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
        reap_adopted_children()
        time.sleep(0.01)
    reap_adopted_children()
    stopped = not group_alive(pgid)
    if stopped:
        gate_pgid = None
    return stopped


def remove_private_dir():
    ok = True
    for path in (log_path, error_path, gate_path, runner_path, pending_path):
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass
        except OSError:
            ok = False
    try:
        os.rmdir(root)
    except FileNotFoundError:
        pass
    except OSError:
        ok = False
    return ok and not os.path.lexists(root)


for managed_signal in managed_signals:
    signal.signal(managed_signal, receive_signal)
signal.signal(signal.SIGCHLD, signal.SIG_DFL)
signal.pthread_sigmask(signal.SIG_UNBLOCK, managed_signals)

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
    enable_child_subreaper()
    environment = os.environ.copy()
    shell_control = {
        "BASHOPTS",
        "BASH_COMPAT",
        "BASH_ENV",
        "BASH_LOADABLES_PATH",
        "BASH_XTRACEFD",
        "CDPATH",
        "ENV",
        "GLOBIGNORE",
        "POSIXLY_CORRECT",
        "SHELLOPTS",
    }
    for name in tuple(environment):
        if name in shell_control or name.startswith("BASH_FUNC_"):
            environment.pop(name, None)
    environment["BASH_ENV"] = "/dev/null"
    with open(log_path, "wb") as output, open(error_path, "wb") as errors:
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
                stderr=errors,
                env=environment,
                start_new_session=True,
            )
            gate_pgid = child.pid
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        rc = child.wait()
        if rc < 0:
            rc = 128 - rc
        reap_adopted_children()
        if group_alive(gate_pgid):
            if not stop_group(signal.SIGTERM):
                print("cannot terminate gate process group", file=sys.stderr)
                rc = rc if rc != 0 else 1
            elif rc == 0:
                print("gate left background processes running", file=sys.stderr)
                rc = 1
        else:
            gate_pgid = None
except GateCancelled as cancellation:
    cancelled = cancellation.signum
    ignore_managed_signals()
    if not stop_group(cancellation.signum):
        print("cannot terminate gate process group", file=sys.stderr)
    rc = 128 + cancellation.signum
except BaseException as error:
    ignore_managed_signals()
    if gate_pgid is not None and group_alive(gate_pgid):
        stop_group(signal.SIGTERM)
    print(f"cannot run gate: {error}", file=sys.stderr)
    rc = rc if rc != 0 else 1
try:
    if cancelled is None:
        stdout_fd = sys.stdout.fileno()
        stderr_fd = sys.stderr.fileno()
        stdout_was_blocking = os.get_blocking(stdout_fd)
        stderr_was_blocking = os.get_blocking(stderr_fd)
        os.set_blocking(stdout_fd, False)
        os.set_blocking(stderr_fd, False)
        for path, target_fd in ((log_path, stdout_fd), (error_path, stderr_fd)):
            with open(path, "rb") as output:
                while True:
                    chunk = output.read(65536)
                    if not chunk:
                        break
                    pending = memoryview(chunk)
                    while pending:
                        try:
                            written = os.write(target_fd, pending)
                            pending = pending[written:]
                        except BlockingIOError:
                            select.select([], [target_fd], [], 0.1)
    if not remove_private_dir():
        print("cannot remove gate directory", file=sys.stderr)
        rc = rc if rc != 0 else 1
    if cancelled is None:
        write_terminal_status(stdout_fd, rc)
        os.set_blocking(stdout_fd, stdout_was_blocking)
        os.set_blocking(stderr_fd, stderr_was_blocking)
except GateCancelled as cancellation:
    if "stdout_fd" in locals() and "stdout_was_blocking" in locals():
        os.set_blocking(stdout_fd, stdout_was_blocking)
    if "stderr_fd" in locals() and "stderr_was_blocking" in locals():
        os.set_blocking(stderr_fd, stderr_was_blocking)
    cancelled = cancellation.signum
    ignore_managed_signals()
    if gate_pgid is not None and group_alive(gate_pgid):
        stop_group(cancellation.signum)
    rc = 128 + cancellation.signum
    if not remove_private_dir():
        print("cannot remove gate directory", file=sys.stderr)
except BaseException as error:
    if "stdout_fd" in locals() and "stdout_was_blocking" in locals():
        os.set_blocking(stdout_fd, stdout_was_blocking)
    if "stderr_fd" in locals() and "stderr_was_blocking" in locals():
        os.set_blocking(stderr_fd, stderr_was_blocking)
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
_gate_python=$(command type -P python3) ||
  { echo "cannot locate python3"; exit 1; }
command unset BASH_ENV ENV ||
  { echo "cannot clear shell startup environment"; exit 1; }
while command builtin read -r _ _ _gate_function; do
  command builtin export -n -f -- "$_gate_function" ||
    { echo "cannot clear exported shell function"; exit 1; }
done < <(command builtin declare -F)
"$_gate_python" -I -c '
import os
import sys
import time

root, pending, *paths = sys.argv[1:]
time.sleep(2)
if os.path.lexists(pending):
    for path in paths:
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass
        except OSError:
            pass
    try:
        os.rmdir(root)
    except OSError:
        pass
' "$_gate_dir" "$_gate_pending" \
  "$_gate_log" "$_gate_error" "$_gate_script" "$_gate_runner" "$_gate_pending" &
_gate_exec_watchdog=$!
command exec "$_gate_python" -I "$_gate_runner" "$_gate_dir" "${BASH:-bash}" \
  "$_gate_exec_watchdog" "$_gate_pending"
__AGENT_GATE_WRAPPER__
```

This portable supervisor requires Python 3 in addition to Bash; preflight it
before creating any private artifacts, as the snippet does. Run this as a
standalone final command, not as sourced setup for later commands:
`exec` makes the Python supervisor the caller-visible wrapper process, while a
failed `exec` leaves the shell cleanup trap armed. Put self-contained gate
commands between the delimiter lines. The supervisor runs them in a fresh Bash
from a private script with closed stdin, cleared shell-startup environment,
disabled startup files, and `pipefail`. The wrapper clears `BASH_ENV` and `ENV`
and removes the export attribute from every inherited shell function before
either Python launch as well, so a Python path implemented by a shell shim cannot
bypass the supervisor before its own environment sanitization runs. The entire
wrapper runs from a quoted here-document inside privileged Bash, so it cannot
import exported or non-exported caller functions. The caller first enables
POSIX special-builtin precedence, uses backslash-suppressed special builtins to
remove local functions named for the trust path, resolves Bash through
`command -p`, and replaces itself with that clean interpreter. Its
preflight refuses every raw exported-function environment entry before creating
artifacts, and the normal sanitizer is a second defense before either Python
launch.
It creates a dedicated process group and, after the supervisor has launched,
handles HUP, INT, QUIT, and TERM even when the invoking shell inherited an
ignored signal. Signals delivered earlier in the bootstrap can still retain
their inherited disposition. The supervisor resumes stopped work, waits with a
deadline, and escalates boundedly when the leader or another process in that
group ignores the signal. On Linux it also becomes a child subreaper before
launch, so orphaned descendants are reparented to and reaped by the supervisor
rather than leaving a zombie-only group that POSIX `kill(0)` cannot distinguish
from live work; failure to establish that Linux contract is fail-closed. Other
platforms keep the portable process-group contract. Gate commands must use their
foreground mode and must not daemonize into a different session/process group;
that is outside this portable wrapper's containment contract. Cleanup happens
before the reported final status: supervisor, read,
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
