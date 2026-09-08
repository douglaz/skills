#!/usr/bin/env bash
# Google Flights helper on top of the gstack browse daemon.
#   gf.sh search ORIG DEST DEPART [RETURN] [EXTRA WORDS...]
#                                           print itineraries (Google's aria-label text, one block each);
#                                           extra words go into Google's natural-language query,
#                                           e.g. "for 2 adults" or "business class"
#   gf.sh grid                              open the "Date grid" and print "<price>, <dates>" cells
#   gf.sh select PRICE [N]                  click the itinerary priced PRICE (digits, no symbol). With several
#                                           at that price and no N, it refuses without clicking; N picks one.
#   gf.sh booking                           print booking options (airline vs OTA) on the booking page
#   gf.sh handoff-url [SELLER|N]            capture the form behind "Continue to book with SELLER"; with several
#                                           sellers on the page and no argument it refuses
# Env: BROWSE_BIN (path to browse; otherwise probed under each skills root), CURR (default USD)
# Needs jq (URL-encoding), a prerequisite this repo already lists.
set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "gf.sh needs jq on PATH" >&2; exit 1; }
bin="${BROWSE_BIN:-}"
if [ -z "$bin" ]; then
  for d in "$HOME/.claude/skills" "${CODEX_HOME:-$HOME/.codex}/skills" "$HOME/.agents/skills"; do
    [ -x "$d/gstack/browse/dist/browse" ] && { bin="$d/gstack/browse/dist/browse"; break; }
  done
fi
[ -n "$bin" ] && [ -x "$bin" ] || { echo "gstack browse not found (set BROWSE_BIN, or build it with the gstack browse skill's setup)" >&2; exit 1; }
# The executable and its global flags live in an array so every call site (quoted or not) runs
# the same command. Follow the daemon's mode: a headed daemon rejects plain commands. Only
# --headed is carried; a daemon started with --proxy must be disconnected first (its proxy URL
# is not knowable here).
B=("$bin")
if "$bin" status 2>/dev/null | grep -q "Mode: headed"; then B+=(--headed); fi
CURR="${CURR:-USD}"
extract='Array.from(document.querySelectorAll("[aria-label^=\"From \"]")).map(e=>e.getAttribute("aria-label")).join("\n---\n")'
# Run a browse command into a file and return ITS status: a dead daemon must surface as a
# failure, never as "no results" (the fallbacks below apply only to a successful empty answer).
browse_to() { local f=$1; shift; "${B[@]}" "$@" >"$f" 2>&1 || { echo "browse $1 failed (exit $?):" >&2; tail -3 "$f" >&2; return 1; }; }
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT

cmd=${1:-}; shift || true
case "$cmd" in
  search)
    o=${1:?origin}; d=${2:?destination}; dep=${3:?depart YYYY-MM-DD}; shift 3
    ret=""; if [[ "${1:-}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then ret=$1; shift; fi
    extra="$*"
    if [ -n "$ret" ]; then q="Flights from $o to $d on $dep through $ret"
    else q="One way flights from $o to $d on $dep"; fi
    [ -n "$extra" ] && q="$q $extra"
    # Encode the whole natural-language query (an "&" in "2 adults & 1 child" must not end it).
    q=$(jq -rn --arg s "$q" '$s|@uri')
    "${B[@]}" goto "https://www.google.com/travel/flights?q=$q&curr=$CURR&hl=en" >/dev/null
    # Poll instead of a fixed sleep: a slow render or a consent page would otherwise print
    # nothing and exit 0, which reads exactly like a search with no results.
    out=""
    for _ in 1 2 3 4 5 6; do sleep 5; out=$("${B[@]}" js "$extract"); [ -n "$out" ] && break; done
    if [ -z "$out" ]; then
      echo "no itineraries rendered within 30 s; page is: $("${B[@]}" js 'document.title') — $("${B[@]}" text 2>/dev/null | tr '\n' ' ' | head -c 300)" >&2; exit 1
    fi
    printf '%s\n' "$out"
    ;;
  grid)
    browse_to "$tmp" snapshot -i
    ref=$(grep -oE '@e[0-9]+ \[button\] "Date grid"' "$tmp" | grep -oE '@e[0-9]+' | head -1 || true)
    # A missing button is a state to report below; a click that fails is an error to surface.
    # Any currency prefix (US$, €, £ ...), the amount, then a label carrying at least one
    # "<Mon> <d>" date (round trip: "Oct 8 to Oct 17"; one-way labels were not exercised).
    cell_re='\[button\] "[^"0-9]{0,4}[0-9][0-9,.]*, [^"]*[A-Z][a-z]{2} [0-9]{1,2}[^"]*"'
    if [ -n "$ref" ]; then
      "${B[@]}" click "$ref" >/dev/null || { echo "browse click on the Date grid button failed" >&2; exit 1; }
      # Poll for the grid to render rather than sleeping a fixed time.
      for _ in 1 2 3 4 5; do sleep 3; browse_to "$tmp" snapshot; grep -qE "$cell_re" "$tmp" && break; done
    else
      browse_to "$tmp" snapshot
    fi
    cells=$(grep -oE "$cell_re" "$tmp" | sed 's/\[button\] //' || true)
    [ -n "$cells" ] && printf '%s\n' "$cells" || echo "(no date-grid cells found; is a search loaded? run: $0 search ...)"
    ;;
  select)
    price=${1:?price digits}; n=${2:-}
    # Both values are interpolated into JS: enforce the shape. Google writes four-digit fares
    # without a thousands separator ("From 1551 US dollars", observed), so digits only is right.
    [[ "$price" =~ ^[0-9]+$ ]] || { echo "PRICE must be digits only (got '$price')" >&2; exit 1; }
    [[ -z "$n" || "$n" =~ ^[1-9][0-9]*$ ]] || { echo "N must be a positive integer (got '$n')" >&2; exit 1; }
    # Trailing space after the amount: "From 988 " must not match "From 9880 ...". Count first and
    # click only when the choice is unambiguous or an index says which; clicking the first of
    # several would advance the page before the caller could pick another.
    before=$("${B[@]}" js 'location.href')
    out=$("${B[@]}" js "(()=>{const m=[...document.querySelectorAll('[aria-label^=\"From $price \"]')];const n=${n:-0};if(!m.length)return 'ERROR: no itinerary priced $price';if(m.length>1&&!n)return 'ERROR: '+m.length+' itineraries priced $price; rerun as: select $price <index 1..'+m.length+'>';const e=m[n?n-1:0];if(!e)return 'ERROR: no itinerary #'+n+' priced $price ('+m.length+' match)';e.click();return m.length+' itinerar'+(m.length===1?'y':'ies')+' priced $price; clicked #'+(n||1)})()")
    echo "$out"; case "$out" in *ERROR:*) exit 1;; esac
    # Wait for the page to move on (return options or the booking page) instead of sleeping.
    moved=""
    for _ in 1 2 3 4 5 6 7 8 9 10; do sleep 3; now=$("${B[@]}" js 'location.href'); [ "$now" != "$before" ] && { moved=1; break; }; done
    [ -n "$moved" ] || { echo "page did not change within 30 s after the click (still $before)" >&2; exit 1; }
    echo "URL: $(printf '%s' "$now" | head -c 120)"
    "${B[@]}" js "$extract"
    ;;
  booking)
    browse_to "$tmp" text
    # `browse text` may wrap; flatten before matching, and an absent section is an answer, not a crash.
    tr '\n' ' ' <"$tmp" | grep -oE "Booking options.{0,900}" | head -c 1000 \
      || echo "(no 'Booking options' section: select an outbound and a return first with: $0 select PRICE)"
    echo
    browse_to "$tmp" snapshot -i
    grep -E "Continue to book" "$tmp" || true
    ;;
  handoff-url)
    # handoff-url [SELLER|N]: capture the form behind "Continue to book with <SELLER> ...". With several
    # sellers on the page and no argument it refuses, so the wrong seller's form is never captured.
    who=${1:-}; who_re='^[A-Za-z0-9 ]{1,40}$'
    [[ -z "$who" || "$who" =~ $who_re ]] || { echo "SELLER must be a seller name or an index (got '$who')" >&2; exit 1; }
    # Google's Continue button POSTs a hidden form to a _blank window; record it instead of following it.
    # Two hooks: prototype.submit() for direct calls (what Google used when measured), and a capturing
    # submit listener for requestSubmit()/button activation, which bypass the prototype method.
    "${B[@]}" js "window.__cap=[];const rec=(f,via)=>window.__cap.push({via,action:f.action,target:f.target,inputs:[...f.querySelectorAll('input')].map(i=>[i.name,i.value.slice(0,120)])});HTMLFormElement.prototype.submit=function(){rec(this,'submit()')};document.addEventListener('submit',e=>{rec(e.target,'submit event');e.preventDefault()},true);'hooked'" >/dev/null
    # The seller buttons render after the booking page loads ("Checking prices from multiple sources…"): wait for them.
    n=0; for _ in 1 2 3 4 5 6 7 8 9 10; do n=$("${B[@]}" js "document.querySelectorAll('[aria-label^=\"Continue to book\"]').length"); [ "$n" != "0" ] && break; sleep 2; done
    out=$("${B[@]}" js "(()=>{const bs=[...document.querySelectorAll('[aria-label^=\"Continue to book\"]')];const labels=bs.map(b=>b.getAttribute('aria-label'));const who='$who';let e;if(!bs.length)return 'ERROR: no Continue to book button on this page';if(/^[0-9]+$/.test(who))e=bs[+who-1];else if(who)e=bs.find(b=>b.getAttribute('aria-label').toLowerCase().includes('with '+who.toLowerCase()));else if(bs.length===1)e=bs[0];else return 'ERROR: '+bs.length+' sellers on this page; rerun as: handoff-url <seller or index>: '+labels.join(' | ');if(!e)return 'ERROR: no seller matches '+JSON.stringify(who)+': '+labels.join(' | ');e.click();return 'clicked: '+e.getAttribute('aria-label')})()")
    echo "$out"; case "$out" in *ERROR:*) exit 1;; esac
    # The click alone proves nothing: wait for a hook to record the form, and fail when none does.
    cap="[]"
    for _ in 1 2 3 4 5 6 7 8 9 10; do sleep 1; cap=$("${B[@]}" js "JSON.stringify(window.__cap)"); [ "$cap" != "[]" ] && break; done
    [ "$cap" != "[]" ] || { echo "no form submission was captured within 10 s of the click (hooks: submit(), submit event); nothing to hand off" >&2; exit 1; }
    printf '%s\n' "$cap"
    ;;
  *) sed -n '2,12p' "$0"; exit 1 ;;
esac
