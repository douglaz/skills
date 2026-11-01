---
name: beads-jsonl-path
description: >-
  Internal companion for resolving the current Beads JSONL and checking for
  existing edits before br writes. Load when a bead workflow directs you here.
user-invocable: false
---

Use native `br`, `jq`, and Git. Reads use `--no-auto-flush --no-auto-import`.
Never hand-edit JSONL; write issue fields through `br`.

## Resolve and check before writing

Run from the intended worktree. Start with no `BEADS_REVIEWED` in a new session;
later rounds may continue from this session's last reviewed result.
In separate shells, pass the printed checkpoint assignment to the next admission;
rerun the resolution through `BEADS_JSONL=` before a later diff call.

```bash
set -euo pipefail
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"
WHERE=$(br --no-auto-flush --no-auto-import where --json) || exit 1
BEADS_JSONL=$(jq -er '.jsonl_path | select(type == "string" and startswith("/"))' <<<"$WHERE") || exit 1
STATUS=$(br --no-auto-flush --no-auto-import vcs-status --json) || exit 1
if ! jq -e --arg path "${BEADS_JSONL#"$REPO_ROOT"/}" --argjson previous "${BEADS_REVIEWED:-null}" '
  .schema == "br.vcs-export-status.v2" and .available == true and .vcs == "git"
  and .tracked == true and .path_scope == "workspace" and .path == $path
  and ([.head.object_id, .index.object_id, .worktree_raw_git_blob_hash]
       | all(.[]; type == "string" and length > 0))
  and ((.index_clean == true and .worktree_clean == true) or
    ($previous != null and
     [.path, .head.object_id, .index.object_id, .worktree_raw_git_blob_hash] ==
     [$previous.path, $previous.head.object_id, $previous.index.object_id,
      $previous.worktree_raw_git_blob_hash]))
' <<<"$STATUS" >/dev/null; then
  git --no-pager --literal-pathspecs -c core.fsmonitor=false diff --no-ext-diff --no-textconv --text --cached HEAD -- "$BEADS_JSONL"
  git --no-pager --literal-pathspecs -c core.fsmonitor=false diff --no-ext-diff --no-textconv --text -- "$BEADS_JSONL"
  echo 'Existing JSONL changes: stop and resolve them before writing.' >&2
  exit 1
fi
```

For inspection or an audit handoff, only the resolution commands through
`BEADS_JSONL=` are needed; they authorize no writes.

## Review every write

After every `br` write, inspect this diff and stop on IDs or fields you did not
intend to change. Preserve the bytes and report; do not automatically restore them.

```bash
git --no-pager --literal-pathspecs -c core.fsmonitor=false diff --no-ext-diff --no-textconv --text HEAD -- "$BEADS_JSONL"
```

Require `br sync --flush-only` to succeed before handing off the export.
After reviewing the result, retain a checkpoint for the next round:

```bash
BEADS_REVIEWED=$(br --no-auto-flush --no-auto-import vcs-status --json) || exit 1
printf 'BEADS_REVIEWED=%q\n' "$BEADS_REVIEWED"
```
