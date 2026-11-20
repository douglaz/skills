#!/bin/sh
# wait.sh DEADLINE_SECONDS DIR...
#
# Wait until every DIR (made by launch-unit.sh) has an exit file. Deadline is capped at 3300 s.
# Exit 0: all "success exited 0". 1: all finished, one or more did not succeed.
#      2: a unit is gone without writing its exit file (result unknown). 124: deadline; re-arm.
# Pass only the seats you need: never include the optional fable seat.
#
# Wait record: for each DIR that launch-unit.sh recorded (DIR/record names the lane's record), this
# wait's line "MANAGER | UNIT | DIR/exit | DEADLINE" is written with its own deadline when it starts
# (replacing launch-unit.sh's line for the same manager) and removed when it ends, on every exit
# path, its own deadline included. MANAGER is FASTLANE_MANAGER, else the one that launched DIR, so
# a manager waiting on a peer's unit gets a line of its own. Other lines are left alone.
set -u
[ $# -ge 2 ] || { echo "usage: $0 DEADLINE_SECONDS DIR..." >&2; exit 2; }
DL=$1; shift
case "$DL" in ''|*[!0-9]*) echo "deadline must be seconds" >&2; exit 2 ;; esac
[ "$DL" -le 3300 ] || DL=3300
END=$(( $(date +%s) + DL ))

# record ADD|DROP: rewrite this wait's lines in each DIR's record, under the record's lock.
record() {
  for d in "$@"; do
    [ -s "$d/record" ] && [ -s "$d/unit" ] || continue
    rec=$(cat "$d/record"); u=$(cat "$d/unit")
    m=${FASTLANE_MANAGER:-$(cat "$d/manager" 2>/dev/null || echo -)}
    e=$(cd "$d" && pwd)/exit
    [ -f "$rec" ] || continue
    (
      flock 9
      # Replace the record only when the new copy was written in full (a full disk must not empty it).
      if awk -F'|' -v m="$m" -v u="$u" -v e="$e" '{
        f1 = $1; f2 = $2; f3 = $3
        gsub(/^ +| +$/, "", f1); gsub(/^ +| +$/, "", f2); gsub(/^ +| +$/, "", f3)
        if (!(f1 == m && f2 == u && f3 == e)) print }' "$rec" > "$rec.tmp.$$" \
        && { [ "$MODE" != ADD ] || printf '%s\n' "$m | $u | $e | $STAMP" >> "$rec.tmp.$$"; }; then
        mv "$rec.tmp.$$" "$rec"
      else
        rm -f "$rec.tmp.$$"; echo "wait record $rec not updated" >&2
      fi
    ) 9>> "$rec.lock"
  done
}
STAMP=$(date -u -d "@$(( END + 59 ))" +%Y-%m-%dT%H:%MZ)
MODE=ADD; record "$@"
trap 'MODE=DROP; record "$@"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

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
