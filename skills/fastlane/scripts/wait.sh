#!/bin/sh
# wait.sh DEADLINE_SECONDS DIR...
#
# Wait until every DIR (made by launch-unit.sh) has an exit file. Deadline is capped at 3300 s.
# Exit 0: all "success exited 0". 1: all finished, one or more did not succeed.
#      2: a unit is gone without writing its exit file (result unknown). 124: deadline; re-arm.
# Pass only the seats you need: never include the optional fable seat.
set -u
[ $# -ge 2 ] || { echo "usage: $0 DEADLINE_SECONDS DIR..." >&2; exit 2; }
DL=$1; shift
case "$DL" in ''|*[!0-9]*) echo "deadline must be seconds" >&2; exit 2 ;; esac
[ "$DL" -le 3300 ] || DL=3300
END=$(( $(date +%s) + DL ))
while :; do
  pending=0
  for d in "$@"; do
    [ -s "$d/exit" ] && continue
    u=$(cat "$d/unit" 2>/dev/null || true)
    [ -n "$u" ] || { echo "UNKNOWN $d: no unit file (not made by launch-unit.sh?)"; exit 2; }
    if ! systemctl --user is-active --quiet "$u"; then
      sleep 3
      [ -s "$d/exit" ] && continue
      echo "GONE $d: unit $u is inactive and wrote no exit file"; exit 2
    fi
    pending=1
  done
  [ "$pending" = 0 ] && break
  [ "$(date +%s)" -ge "$END" ] && { echo "DEADLINE after ${DL}s; still running: $*"; exit 124; }
  sleep 15
done
rc=0
for d in "$@"; do
  e=$(cat "$d/exit"); echo "$d: $e"
  [ "$e" = "success exited 0" ] || rc=1
done
exit $rc
