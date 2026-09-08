#!/usr/bin/env bash
# Launch the user's real Google Chrome with a DevTools port on a dedicated profile.
# Chrome 136+ ignores --remote-debugging-port on the default profile, hence ~/.config/chrome-agent.
# Usage: launch_chrome.sh [URL]   Env: CDP_PORT (9222), CHROME_AGENT_PROFILE, CHROME_BIN (google-chrome)
set -euo pipefail
PORT="${CDP_PORT:-9222}"
PROFILE="${CHROME_AGENT_PROFILE:-$HOME/.config/chrome-agent}"
BIN="${CHROME_BIN:-google-chrome}"
URL="${1:-https://shopping.copaair.com/booking-panel}"
if curl -s --max-time 2 "http://127.0.0.1:$PORT/json/version" >/dev/null; then
  echo "CDP already listening on :$PORT; reusing the running Chrome"; exit 0
fi
export DISPLAY="${DISPLAY:-:0}"
mkdir -p "$PROFILE"
nohup "$BIN" --remote-debugging-port="$PORT" --user-data-dir="$PROFILE" \
  --no-first-run --no-default-browser-check --new-window "$URL" >/dev/null 2>&1 &
for _ in $(seq 1 20); do
  sleep 1
  if curl -s --max-time 2 "http://127.0.0.1:$PORT/json/version" >/dev/null; then
    echo "CDP up on :$PORT (profile $PROFILE). Tell the user a Chrome window is open on their desktop."; exit 0
  fi
done
echo "Chrome did not expose CDP on :$PORT (is DISPLAY right? is $BIN installed?)" >&2; exit 1
