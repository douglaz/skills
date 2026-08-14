---
name: beads-jsonl-path
description: >-
  Internal companion owner of the current repository's Beads JSONL path. Load
  this exact skill only when another skill directs you here: to resolve the real
  JSONL path, to prove that its HEAD, index, and worktree bytes are identical
  before a writing `br` command, or to refuse staged, unstaged, hidden-index,
  unmerged, symlink, gitlink, untracked, missing, nonregular, or wrong-worktree
  state without touching the Beads store.
user-invocable: false
---

Resolve and inspect the Beads JSONL through the bundled script. Do not reproduce
its `br`, `jq`, or Git inspection in a consumer.

## Resolve before writing

Run this before the first `br` command that can mutate or flush:

```bash
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
_bjp_git_environment=( "${!GIT_@}" )
for _bjp_git_variable in "${_bjp_git_environment[@]}"; do
  command unset -- "$_bjp_git_variable" || {
    printf '%s\n' 'cannot sanitize the Git environment for beads-jsonl-path — do NOT write' >&2
    exit 1
  }
done
unset _bjp_git_variable _bjp_git_environment

BEADS_JSONL_RESOLVER=
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
  unset _bjp_candidate_dir
  if [ -z "$BEADS_JSONL_RESOLVER" ]; then
    BEADS_JSONL_RESOLVER=$_bjp_candidate
  elif ! "$_bjp_cmp" -s "$BEADS_JSONL_RESOLVER" "$_bjp_candidate"; then
    printf '%s\n' 'installed beads-jsonl-path companions disagree — do NOT write' >&2
    exit 1
  fi
done
unset _bjp_candidate _bjp_root _bjp_root_raw _bjp_git _bjp_cmp
[ -n "$BEADS_JSONL_RESOLVER" ] || {
  printf '%s\n' 'beads-jsonl-path companion unavailable — do NOT write' >&2
  exit 1
}
printf '%s\n' "$BEADS_JSONL_RESOLVER"
__BJP_TRUSTED_BASH__
  )
) || exit 1
unset _bjp_candidate
# Installed targets only — do NOT add a fallback to a relative
# `skills/beads-jsonl-path/scripts/resolve-beads-jsonl`. This snippet runs in the agent's
# shell inside the repository being driven, so that path is whatever executable THAT
# repository planted there, and every consumer would run it automatically.
[ -n "$BEADS_JSONL_RESOLVER" ] || {
  echo "beads-jsonl-path companion unavailable — do NOT write" >&2
  exit 1
}
BEADS_JSONL=$("$BEADS_JSONL_RESOLVER") || exit 1
```

If nothing resolves you are running from a checkout rather than an install: rerun the
same installer command once, or run this checkout's own `scripts/resolve-beads-jsonl` by
absolute path — the copy in the skills checkout you are editing, never one named
relative to the repository you are driving.

On success, `BEADS_JSONL` is the only stdout: an absolute path inside the
current Git worktree whose stage-0 index entry, normal index flags, HEAD entry,
worktree type and mode, and raw bytes all agree. Both the locator and resolver
discard inherited `GIT_*` overrides before repository discovery, so a caller
cannot redirect that proof to another worktree, index, object store, or config.
Every Git inspection also forces `core.fsmonitor=false`, so the read-only owner
does not execute a repository-configured monitor hook.

On failure, stop before any Beads write. Do not replace the owner with
`git status`, porcelain parsing, or a hardcoded `.beads/issues.jsonl` path.

## Inspect dirty content without dropping path ownership

The default mode refuses a dirty JSONL, which is exactly right before a write and wrong
after one. Pass `--allow-dirty` when the file is *supposed* to differ from HEAD and you
still need its real path:

- the post-write field diff (`git --no-replace-objects -c core.fsmonitor=false --literal-pathspecs diff HEAD -- "$BEADS_JSONL"`) that reads what the
  flush actually wrote;
- a handoff that arrives flushed but uncommitted, such as `bead-polish-loop` →
  `second-model-bead-audit`, where the audit reads the diff rather than gating on it.

In a session that has not already set `BEADS_JSONL_RESOLVER`, rerun the resolver-locator
block above, stopping before its final clean-mode `BEADS_JSONL=` call — that call is the
one this mode exists to get past, so running it first exits 1 on exactly the dirty JSONL
you came here for.

```bash
BEADS_JSONL=$("$BEADS_JSONL_RESOLVER" --allow-dirty) || exit 1
```

`--allow-dirty` stops requiring HEAD, index, and worktree bytes to be identical, and
changes nothing else. It still requires one normally flagged, tracked stage-0 regular
entry with mode `100644` in the index and HEAD, holding real content rather than an
intent-to-add placeholder, plus a non-symlink regular worktree file. It therefore refuses
hidden flags, intent-to-add, untracked, unmerged, missing, wrong-mode, and wrong-type
states before an audit flush.
The resolver and every documented consumer force `core.fsmonitor=false`, so a
monitor that missed a write cannot make the `git status` or `git diff HEAD` you
are about to read report a clean file over changed bead bodies.
It still performs no Beads mutation or flush.

## Name a damaged path for recovery

Use `--recovery` only after deciding recovery is required. Recovery is the fresh-session
case by definition, so rerun the resolver-locator block above first,
stopping before its final clean-mode `BEADS_JSONL=` call — a destroyed JSONL is precisely
what that call refuses.

```bash
BEADS_JSONL=$("$BEADS_JSONL_RESOLVER" --recovery) || exit 1
```

Recovery may need to name a missing export, so this mode retains byte-safe resolution and
worktree containment but does not require tracked/index/HEAD state. It accepts only an
absent path or a non-symlink regular file; a symlink, FIFO, directory, or other nonregular
occupant still refuses. A path equal to or beneath `$GIT_DIR`, Git's common
administrative directory, or `<worktree>/.git` also refuses, including a linked
worktree's `.git` pointer file. Never use recovery mode before a `br` write.
Read the symlink half at its measured width: on br 0.2.19 a `.beads/issues.jsonl` symlink
whose target exists is already resolved to that target before this owner sees it, so the
refusal covers the dangling link and containment covers one pointing out of the worktree,
while a live in-worktree link is inspected — and named — as the file `br` writes through
it. Recovery still tells you where the bytes land; it does not vet the configuration that
put them there.
Successful recovery resolution only names the artifact; it is not a safety gate that
authorizes a subsequent Beads query, mutation, or flush. Follow the owning recovery
procedure before any such command.
