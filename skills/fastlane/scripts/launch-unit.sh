#!/bin/sh
# launch-unit.sh UNIT DIR [--stdout FILE] -- CMD [ARGS...]
#
# Start CMD as a capped `systemd-run --user` unit and return at once.
# DIR gets: unit (the unit name), out (stdout, unless --stdout FILE), err, and exit, written by
# ExecStopPost as "SERVICE_RESULT EXIT_CODE EXIT_STATUS" (e.g. "success exited 0").
# Caps: MemoryMax 16G (FASTLANE_MEM overrides), no swap, OOMPolicy=continue. stdin is /dev/null.
# Working directory: FASTLANE_CWD, or the current directory.
# The stop command holds no `$`: a user-manager re-exec re-reads the saved unit, and an escaped
# variable would then expand to something else.
set -eu
usage() { echo "usage: $0 UNIT DIR [--stdout FILE] -- CMD [ARGS...]" >&2; exit 2; }
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
[ ! -e "$DIR/exit" ] || { echo "$DIR/exit exists: use a fresh directory" >&2; exit 2; }
if systemctl --user is-active --quiet "$UNIT"; then echo "unit $UNIT is already active" >&2; exit 2; fi
printf '%s\n' "$UNIT" > "$DIR/unit"
NPM_BIN=$HOME/.npm-global/bin
systemd-run --user --unit="$UNIT" --collect --expand-environment=no \
  --working-directory="${FASTLANE_CWD:-$(pwd)}" \
  -E PATH="$NPM_BIN:$PATH" -E GIT_OPTIONAL_LOCKS=0 \
  -p KillMode=mixed -p TimeoutStopSec=120 \
  -p MemoryMax="${FASTLANE_MEM:-16G}" -p MemorySwapMax=0 -p OOMPolicy=continue \
  -p "StandardOutput=file:$OUT" -p "StandardError=file:$DIR/err" \
  -p "ExecStopPost=/bin/sh -c 'printenv SERVICE_RESULT EXIT_CODE EXIT_STATUS | xargs > $DIR/exit'" \
  "$@"
sleep 2
if systemctl --user is-active --quiet "$UNIT" || [ -s "$DIR/exit" ]; then
  echo "started $UNIT -> $DIR"
else
  echo "unit $UNIT is not active and wrote no exit file; see $DIR/err" >&2; exit 1
fi
