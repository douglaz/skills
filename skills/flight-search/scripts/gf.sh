#!/usr/bin/env bash
# Google Flights helper on top of the gstack browse daemon.
#   gf.sh search ORIG DEST DEPART [RETURN]   print itineraries (Google's aria-label text, one block each)
#   gf.sh grid                              open the "Date grid" and print "$price, <dep> to <ret>" cells
#   gf.sh select PRICE                      click the itinerary priced PRICE (digits, no $), print what follows
#   gf.sh booking                           print booking options (airline vs OTA) on the booking page
#   gf.sh handoff-url                       capture the form behind "Continue to book" (first option)
# Env: BROWSE_BIN (path to browse), CURR (default USD)
set -euo pipefail
B="${BROWSE_BIN:-$HOME/.claude/skills/gstack/browse/dist/browse}"
[ -x "$B" ] || { echo "browse not found at $B; run the gstack browse skill setup first" >&2; exit 1; }
# Follow whatever mode the daemon is already in (a headed daemon rejects plain commands).
if "$B" status 2>/dev/null | grep -q "Mode: headed"; then B="$B --headed"; fi
CURR="${CURR:-USD}"
extract='Array.from(document.querySelectorAll("[aria-label^=\"From \"]")).map(e=>e.getAttribute("aria-label")).join("\n---\n")'

cmd=${1:-}; shift || true
case "$cmd" in
  search)
    o=${1:?origin}; d=${2:?destination}; dep=${3:?depart YYYY-MM-DD}; ret=${4:-}
    if [ -n "$ret" ]; then q="Flights%20from%20$o%20to%20$d%20on%20$dep%20through%20$ret"
    else q="One%20way%20flights%20from%20$o%20to%20$d%20on%20$dep"; fi
    $B goto "https://www.google.com/travel/flights?q=$q&curr=$CURR&hl=en" >/dev/null
    sleep 6
    $B js "$extract"
    ;;
  grid)
    ref=$($B snapshot -i 2>/dev/null | grep -oE '@e[0-9]+ \[button\] "Date grid"' | grep -oE '@e[0-9]+' | head -1 || true)
    [ -n "$ref" ] && $B click "$ref" >/dev/null && sleep 4
    $B snapshot 2>/dev/null | grep -oE '\[button\] "\$[0-9,]+,[^"]*"' | sed 's/\[button\] //'
    ;;
  select)
    price=${1:?price digits}
    $B js "document.querySelector('[aria-label^=\"From $price\"]').click()" >/dev/null
    sleep 6
    echo "URL: $($B js 'location.href' | head -c 120)"
    $B js "$extract"
    ;;
  booking)
    $B text 2>/dev/null | grep -oE "Booking options.{0,900}" | head -c 1000; echo
    $B snapshot -i 2>/dev/null | grep -E "Continue to book" || true
    ;;
  handoff-url)
    # Google's Continue button POSTs a hidden form to a _blank window; record it instead of following it.
    $B js "window.__cap=[];HTMLFormElement.prototype.submit=function(){window.__cap.push({action:this.action,target:this.target,inputs:[...this.querySelectorAll('input')].map(i=>[i.name,i.value.slice(0,120)])})};'hooked'" >/dev/null
    $B js "document.querySelector('[aria-label^=\"Continue to book\"]').click();'clicked'" >/dev/null
    sleep 3
    $B js "JSON.stringify(window.__cap)"
    ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac
