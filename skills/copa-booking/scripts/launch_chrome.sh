#!/usr/bin/env bash
# Launch the user's real Google Chrome with a DevTools port on a dedicated profile.
# Chrome's own release notes say 136+ refuses --remote-debugging-port on the default profile; that was
# not measured here (the default profile was in use by the user's normal Chrome). The dedicated
# profile ~/.config/chrome-agent is what was run and what worked (see references/copa-site-notes.md).
# Usage: launch_chrome.sh [URL]   Env: CDP_PORT (9222), CHROME_AGENT_PROFILE, CHROME_BIN (google-chrome)
set -euo pipefail
PORT="${CDP_PORT:-9222}"
PROFILE="${CHROME_AGENT_PROFILE:-$HOME/.config/chrome-agent}"
BIN="${CHROME_BIN:-google-chrome}"
URL="${1:-https://shopping.copaair.com/booking-panel}"
# A real DevTools endpoint answers /json/version with a webSocketDebuggerUrl. `-f` plus the
# payload check keeps any other listener on the port (a 404 from some unrelated service)
# from being mistaken for a running Chrome.
cdp_up() { curl -sf --max-time 2 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | grep -q '"webSocketDebuggerUrl"'; }
# The DevTools port is loopback-only but unauthenticated, so any other account logged into
# this machine could attach to the logged-in Copa tabs (including the payment page). This
# workflow is for a single-user desktop; refuse — before touching a running Chrome or starting
# one — when other users are logged in, unless the caller has judged the host trusted.
# This sees utmp sessions only (tty/pty logins); a local account running without one stays
# invisible, so the check is a heuristic, not proof of a single-user host. It fails closed when
# it cannot run at all.
if [ "${CDP_SHARED_HOST_OK:-}" != "1" ]; then
  sessions=$(who 2>/dev/null) || { echo "cannot enumerate logged-in users (who failed or is missing); the DevTools port on :$PORT has no authentication. Set CDP_SHARED_HOST_OK=1 only if this host is yours alone." >&2; exit 1; }
  others=$(printf '%s\n' "$sessions" | awk 'NF {print $1}' | sort -u | grep -vx "$(id -un)" | tr '\n' ' ' || true)
  if [ -n "$others" ]; then
    echo "other users are logged in ($others): the DevTools port on :$PORT has no authentication, so they could attach to the booking session. Use a single-user desktop, or set CDP_SHARED_HOST_OK=1 to proceed anyway." >&2; exit 1
  fi
fi
if cdp_up; then
  # Still open the requested URL: the drivers only touch a tab whose URL matches, so a reused
  # Chrome whose Copa tab was closed would otherwise dead-end at `copa.js status`.
  if curl -sf --max-time 5 -X PUT "http://127.0.0.1:$PORT/json/new?$URL" >/dev/null; then
    echo "CDP already listening on :$PORT; opened $URL as a new tab in the running Chrome"; exit 0
  fi
  echo "CDP is listening on :$PORT but it refused to open a new tab (PUT /json/new failed)" >&2; exit 1
fi
export DISPLAY="${DISPLAY:-:0}"
mkdir -p "$PROFILE"
nohup "$BIN" --remote-debugging-port="$PORT" --user-data-dir="$PROFILE" \
  --no-first-run --no-default-browser-check --new-window "$URL" >/dev/null 2>&1 &
for _ in $(seq 1 20); do
  sleep 1
  if cdp_up; then
    echo "CDP up on :$PORT (profile $PROFILE). Tell the user a Chrome window is open on their desktop."; exit 0
  fi
done
echo "Chrome did not expose a DevTools endpoint on :$PORT (DISPLAY right? $BIN installed? port taken by something else? export CDP_PORT=9223 for this launcher and the drivers alike)" >&2; exit 1
