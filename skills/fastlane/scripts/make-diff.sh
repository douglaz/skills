#!/usr/bin/env bash
# make-diff.sh WORKTREE BASE OUT_FILE
#
# Write everything the candidate changes relative to BASE into OUT_FILE: committed and uncommitted
# changes to tracked files, plus every untracked (not ignored) file as a new-file diff.
# Prints the line count and sha256. Re-run it before committing: the sha must match the one the
# reviewers read.
set -euo pipefail
[ $# -eq 3 ] || { echo "usage: $0 WORKTREE BASE OUT_FILE" >&2; exit 2; }
WT=$1 BASE=$2 OUT=$3
git -C "$WT" rev-parse --verify --quiet "$BASE^{commit}" >/dev/null || { echo "no commit $BASE" >&2; exit 2; }
git -C "$WT" diff --binary "$BASE" > "$OUT"
while IFS= read -r -d '' f; do
  rc=0; git -C "$WT" diff --binary --no-index -- /dev/null "$f" >> "$OUT" || rc=$?
  [ "$rc" -le 1 ] || { echo "diff failed for $f" >&2; exit 1; }
done < <(git -C "$WT" ls-files --others --exclude-standard -z)
echo "$OUT: $(wc -l < "$OUT") lines, sha256 $(sha256sum "$OUT" | cut -d' ' -f1)"
