#!/bin/sh
# launch-unit.sh [--kind KIND] [--manager NAME] UNIT DIR [--stdout FILE] -- CMD [ARGS...]
# launch-unit.sh --check KIND [LANE_DIR]
#
# Start CMD as a capped `systemd-run --user` unit and return at once.
# DIR gets: unit (the unit name), kind, manager, out (stdout, unless --stdout FILE), err, and exit, written
# by ExecStopPost as "SERVICE_RESULT EXIT_CODE EXIT_STATUS" (e.g. "success exited 0").
# Caps: MemoryMax 16G (FASTLANE_MEM overrides), no swap, OOMPolicy=continue. stdin is /dev/null.
# Working directory: FASTLANE_CWD, or the current directory.
# The stop command holds no `$`: a user-manager re-exec re-reads the saved unit, and an escaped
# variable would then expand to something else.
#
# Lane guards. The lane folder is the nearest directory at or above DIR that holds a `waits` file.
# - Wait record: when there is one, a line "MANAGER | UNIT | DIR/exit | DEADLINE" is appended to
#   it (DEADLINE in UTC, 55 minutes out, like 2026-11-19T18:30Z), and DIR/record names the file so
#   wait.sh can refresh and remove the line. MANAGER: --manager, else FASTLANE_MANAGER, else "-".
# - Busy check: KIND is deploy, live or other (the default). A deploy refuses while a live unit
#   started in the lane folder is active, and a live run refuses while a deploy is; nothing else
#   blocks. Units are found by their DIR/kind files and checked by name, never by listing units.
#   `--check KIND [LANE_DIR]` runs that check alone (LANE_DIR defaults to the nearest lane folder
#   at or above the current directory): exit 1 and the holders when it would refuse, else 0.
# - Disk floor: refuse when the working directory's filesystem, or /nix/store's, has less than
#   FASTLANE_MIN_FREE_GB GiB free (default 45).
set -eu
usage() {
  echo "usage: $0 [--kind deploy|live|other] [--manager NAME] UNIT DIR [--stdout FILE] -- CMD [ARGS...]" >&2
  echo "       $0 --check deploy|live|other [LANE_DIR]" >&2
  exit 2
}

# lane_of PATH: print the nearest directory at or above PATH that holds a `waits` file.
lane_of() {
  d=$1
  while :; do
    [ -f "$d/waits" ] && { printf '%s\n' "$d"; return 0; }
    [ "$d" = / ] && return 1
    d=$(dirname "$d")
  done
}

# conflict KIND: the kind a KIND launch must not overlap, or nothing.
conflict() { case $1 in deploy) echo live ;; live) echo deploy ;; esac; }

# holders LANE KIND: print each unit this script started under LANE that is still active and of the
# kind KIND conflicts with. It finds them by their DIR/kind files and checks each unit by name, so a
# unit whose wait-record line is gone (its wait returned) still counts.
holders() {
  c=$(conflict "$2")
  [ -n "$c" ] || return 0
  find "$1" -type f -name kind | while IFS= read -r k; do
    d=$(dirname "$k")
    [ "$(cat "$k")" = "$c" ] && [ -s "$d/unit" ] && [ ! -s "$d/exit" ] || continue
    u=$(cat "$d/unit")
    # An `if`, so an inactive last unit doesn't become the loop's status and trip `set -e`.
    if systemctl --user is-active --quiet "$u"; then
      echo "busy: $c unit $u is active (manager $(cat "$d/manager" 2>/dev/null || echo -), $d)"
    fi
  done
  return 0
}

check_kind() { case $1 in deploy|live|other) ;; *) echo "kind must be deploy, live or other: $1" >&2; exit 2 ;; esac; }

if [ "${1:-}" = --check ]; then
  [ $# -ge 2 ] && [ $# -le 3 ] || usage
  check_kind "$2"
  if [ $# -eq 3 ]; then LANE=$3; [ -f "$LANE/waits" ] || { echo "no waits file in $LANE" >&2; exit 2; }
  else LANE=$(lane_of "$(pwd)") || { echo "no lane folder (a waits file) at or above $(pwd)" >&2; exit 2; }
  fi
  H=$(holders "$LANE" "$2")
  [ -z "$H" ] || { printf '%s\n' "$H"; exit 1; }
  exit 0
fi

KIND=other MANAGER=${FASTLANE_MANAGER:--}
while :; do
  case "${1:-}" in
    --kind) [ $# -ge 2 ] || usage; KIND=$2; shift 2 ;;
    --manager) [ $# -ge 2 ] || usage; MANAGER=$2; shift 2 ;;
    *) break ;;
  esac
done
check_kind "$KIND"
case "$MANAGER" in ''|*[!A-Za-z0-9._@+-]*) echo "manager name: letters, digits and . _ @ + - only: $MANAGER" >&2; exit 2 ;; esac
[ $# -ge 4 ] || usage
UNIT=$1 DIR=$2; shift 2
OUT=$DIR/out
if [ "$1" = --stdout ]; then [ $# -ge 4 ] || usage; OUT=$2; shift 2; fi
[ "$1" = -- ] || usage
shift
# Make both paths absolute first, then check the paths the unit will really use.
case "$DIR" in /*) ;; *) DIR=$(pwd)/$DIR ;; esac
case "$OUT" in /*) ;; *) OUT=$(pwd)/$OUT ;; esac
case "$DIR $OUT" in
  *[!A-Za-z0-9._/@+=,:\ -]*) echo "plain paths only (no quotes, \$, % or globs): $DIR $OUT" >&2; exit 2 ;;
esac
case "$DIR$OUT" in *' '*) echo "paths must not contain spaces: $DIR $OUT" >&2; exit 2 ;; esac
mkdir -p "$DIR"
DIR=$(cd "$DIR" && pwd)
[ ! -e "$DIR/exit" ] || { echo "$DIR/exit exists: use a fresh directory" >&2; exit 2; }
if systemctl --user is-active --quiet "$UNIT"; then echo "unit $UNIT is already active" >&2; exit 2; fi
CWD=${FASTLANE_CWD:-$(pwd)}
FLOOR=${FASTLANE_MIN_FREE_GB:-45}
case "$FLOOR" in ''|*[!0-9]*) echo "FASTLANE_MIN_FREE_GB must be whole GiB: $FLOOR" >&2; exit 2 ;; esac
for p in "$CWD" /nix/store; do
  [ -e "$p" ] || continue
  kb=$(df -Pk "$p" | awk 'NR == 2 { print $4 }')
  case "$kb" in ''|*[!0-9]*) echo "cannot read free space for $p" >&2; exit 2 ;; esac
  [ "$kb" -ge $((FLOOR * 1048576)) ] \
    || { echo "disk floor: $p has $((kb / 1048576)) GiB free, below $FLOOR GiB; free space first" >&2; exit 3; }
done
LANE=$(lane_of "$DIR") || LANE=
if [ -n "$LANE" ]; then
  # Hold the record's lock from the busy check until the new line is in, so two launches can't
  # both pass the check.
  exec 9>> "$LANE/waits.lock"
  flock 9
  H=$(holders "$LANE" "$KIND")
  [ -z "$H" ] || { printf '%s\n' "$H" >&2; echo "refusing to start $KIND unit $UNIT" >&2; exit 3; }
fi
printf '%s\n' "$UNIT" > "$DIR/unit"
printf '%s\n' "$KIND" > "$DIR/kind"
printf '%s\n' "$MANAGER" > "$DIR/manager"
NPM_BIN=$HOME/.npm-global/bin
systemd-run --user --unit="$UNIT" --collect --expand-environment=no \
  --working-directory="$CWD" \
  -E PATH="$NPM_BIN:$PATH" -E GIT_OPTIONAL_LOCKS=0 \
  -p KillMode=mixed -p TimeoutStopSec=120 \
  -p MemoryMax="${FASTLANE_MEM:-16G}" -p MemorySwapMax=0 -p OOMPolicy=continue \
  -p "StandardOutput=file:$OUT" -p "StandardError=file:$DIR/err" \
  -p "ExecStopPost=/bin/sh -c 'printenv SERVICE_RESULT EXIT_CODE EXIT_STATUS | xargs > $DIR/exit'" \
  "$@"
if [ -n "$LANE" ]; then
  printf '%s\n' "$LANE/waits" > "$DIR/record"
  DL=$(date -u -d "@$(( $(date +%s) + 3300 + 59 ))" +%Y-%m-%dT%H:%MZ)
  printf '%s\n' "$MANAGER | $UNIT | $DIR/exit | $DL" >> "$LANE/waits"
  exec 9>&-
fi
sleep 2
if systemctl --user is-active --quiet "$UNIT" || [ -s "$DIR/exit" ]; then
  echo "started $UNIT -> $DIR"
else
  echo "unit $UNIT is not active and wrote no exit file; see $DIR/err" >&2; exit 1
fi
