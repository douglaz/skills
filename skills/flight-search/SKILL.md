---
name: flight-search
description: >-
  Search and compare flights with Google Flights through the headless gstack
  browse daemon, then hand the chosen itinerary to an airline booking skill
  (copa-booking for Copa Airlines). Use this whenever the user wants to fly
  somewhere, asks for flight prices, cheapest dates, itineraries, layovers,
  who sells a fare, or says "book me a flight", "find flights", "how much to
  fly to", "trip to <conference/event>", even when they only name the event
  (look the dates up) or only the destination (infer the origin from memory or
  the machine's location). Also use it as the first step of any ticket
  purchase: search here, then invoke the airline skill for booking.
---

# Flight search (Google Flights via browse)

Google Flights is the fastest way to see every airline, nearby-date prices and
who sells each fare. It renders fine headless, so use the gstack `browse`
daemon. Airline sites are a different story: most sit behind bot protection,
which is why booking is a separate skill (`copa-booking` for Copa; the same
real-Chrome technique works for other carriers).

## 1. Pin down the trip

Collect these before touching the browser. Fill gaps yourself, then confirm
the assumptions in your first reply rather than blocking on questions:

- **Origin**: check memory for the user's home airport, then local hints that
  stay on the machine (system timezone, locale). If still unknown, ask; only
  query an IP geolocation service (`curl -s https://ipinfo.io/json`) with the
  user's permission, since it sends the machine's public IP to a third party.
  Say which airport you assumed and why.
- **Destination and dates**: for an event ("TABConf", "Web Summit"), WebSearch
  the next upcoming edition's dates and venue (if this year's has already
  happened, that means next year's; if no upcoming edition is announced, ask
  which year), then propose arriving the day before and leaving the day after.
  Show the event dates in your reply.
- **Passengers and cabin**: default 1 adult, economy.
- **Currency**: USD unless the user says otherwise.

## 2. Start the browser

Run the `browse` skill preamble (skill-start), then the setup check. Skills
may live under any of the three skills roots (Claude Code, Codex, legacy
Codex), so resolve both paths rather than assuming `~/.claude`:

```bash
# First hit wins for each, searched separately: gstack may live under one root
# (Claude Code's, where its installer puts it) while this skill is under another.
ROOTS=("$HOME/.claude/skills" "${CODEX_HOME:-$HOME/.codex}/skills" "$HOME/.agents/skills")
for d in "${ROOTS[@]}"; do [ -f "$d/flight-search/scripts/gf.sh" ] && { G="$d/flight-search/scripts/gf.sh"; break; }; done
for d in "${ROOTS[@]}"; do [ -x "$d/gstack/browse/dist/browse" ] && { B="$d/gstack/browse/dist/browse"; break; }; done
[ -n "${G:-}" ] && [ -n "${B:-}" ] || { echo "flight-search scripts or gstack browse not found under any skills root"; exit 1; }
$B status          # "Mode: headed" means a previous session left it headed
```

`gf.sh` probes the same roots for the browse binary (override with
`BROWSE_BIN`) and carries `--headed` when the daemon runs headed. It cannot
carry a `--proxy` (the daemon's proxy URL is not readable), so a daemon started
with a proxy must be `$B disconnect`ed first; Google Flights needs none. If
commands hang or the daemon is unresponsive, `$B disconnect` and retry. The
daemon can also restart on its own between commands (observed after a few
idle minutes): `$B status` then shows `about:blank`, and every step that
depends on page state (`grid`, `select`, `booking`, `handoff-url`) has to be
preceded by a fresh `search`, so run a dependent sequence back to back.

## 3. Search and read the results

```bash
$G search ASU ATL 2026-10-11 2026-10-16      # round trip; omit the return date for one way
$G search ASU ATL 2026-10-11 2026-10-16 for 2 adults business class   # extra words go into Google's query
```

Google's `q=` is natural language, so passenger words ride along. Google's
"round trip total" then covers the whole party, so compare against the
1-adult price before quoting. Rerunnable record (gstack 1.79.0.0 `browse`,
2026-09-08, streams captured separately; fares drift, the ratio is the point):

```console
$ G=skills/flight-search/scripts/gf.sh
$ $G search ASU ATL 2026-10-08 2026-10-17 >party1.out 2>party1.err; echo "exit=$?"; head -c 40 party1.out; wc -c <party1.err
exit=0
From 742 US dollars round trip total.
0
$ $G search ASU ATL 2026-10-08 2026-10-17 for 2 adults >party2.out 2>party2.err; echo "exit=$?"; head -c 41 party2.out; wc -c <party2.err
exit=0
From 1569 US dollars round trip total.
0
$ browse js "decodeURIComponent(new URLSearchParams(location.search).get('q'))"
Flights from ASU to ATL on 2026-10-08 through 2026-10-17 for 2 adults
```

Cabin words ("business class") were not measured; if you use them, check
the page's cabin control before quoting. `search` exits 1 with the page state
if no itinerary renders within 30 seconds (slow response, consent page).

Each printed block is one itinerary in Google's own words: price (Google's
round-trip total for the searched party, so per adult only for the default
1-adult search), airline, departure and arrival times, duration, layovers.
Put the top 3 to 5 in a table: price, airline, out times, stops and layover,
duration. Google's page also carries two useful hints worth quoting when they
appear in `$B text`: "Prices are currently high/typical/low" and "Travel
<dates> for $<price>".

Prefer this aria-label extraction over `$B text`: the full page text is
20 KB+ and slow. Skip screenshots; the daemon's screenshot path needs `sharp`,
which is not installed here.

## 4. Check nearby dates

Weekday effects are large (in the TABConf search, returning Saturday instead
of Friday cut the fare by a third). Always show the grid:

```bash
$G grid      # clicks "Date grid", prints "$price, Oct 8 to Oct 17" per cell
```

Reduce it to a small departure x return table around the user's dates and
name the pattern you see. Note that the grid shows the cheapest fare per cell,
which may be a worse connection than the headline itinerary. Only round-trip
grids were exercised; if a one-way search yields no cells, read Google's price
strip above the results with `$B text` instead.

## 5. Drill into the chosen itinerary

```bash
$G search ASU ATL 2026-10-08 2026-10-17   # re-run for the final dates
$G select 988        # click the itinerary priced $988 -> shows return options
$G select 988        # click the matching return -> booking page
$G booking           # "Book with COPA Airline $988 / Book with United $2,880"
```

`select` counts the itineraries at that price before clicking: with more than
one and no index it refuses and exits 1, so rerun as `$G select 988 2` with
the index of the one the user chose. It then waits for the page to move on and
exits 1 if it does not, rather than printing the old page as if it had.

The booking page names who sells the fare and at what price. Airline-direct is
almost always what the user wants; online travel agencies are worth mentioning
only when materially cheaper.

`$G handoff-url COPA` captures the form Google POSTs when you press that
seller's "Continue to book" (it opens in a new tab, so plain clicks look like
nothing happened); with several sellers listed it refuses until you name one
or pass its index. For
Copa this deep link is useless because their site redirects it to a
flexible-dates page; go through `copa-booking` instead.

## 6. Recommend, then let the user choose

Give one recommendation with the reason (total cost including the hotel nights
that cheaper dates add, connection quality, arrival time versus the event).
Then ask with AskUserQuestion: which itinerary, and whether they want the
booking driven up to the payment page in their own browser or just the link.
Never offer or accept card details in chat, for any airline: payment is typed
by the user into the airline's or payment provider's page. Buying spends
money and needs passport-grade personal data, so this is a genuine stop even
in autonomous mode.

## 7. Hand off to booking

- **Copa Airlines**: invoke the `copa-booking` skill and pass it the dates,
  flight numbers (e.g. "CM 296 · CM 880" out, "CM 891 · CM 291" back) and the
  fare family the user picked. Copa's site prices Economy Basic (no bag) versus
  Economy Classic (23 kg bag, seat pick, one free change); Google's headline
  price is usually Basic, so say which one you quoted.
- **Other airlines**: give the direct link. If asked to complete the booking,
  reuse the real-Chrome-over-CDP approach from `copa-booking`
  (`scripts/launch_chrome.sh` + `scripts/cdp.js` are airline-agnostic); only
  the page-specific driver differs.

## 8. Remember what you learned

Save to memory: the user's home airport, and the trip (event, dates, chosen
itinerary, price, booking status). Next time the user mentions the trip, check
whether the ticket was bought before searching again.

## Pitfalls seen in practice

- Google's price is a "from" total for the searched party and drifts within
  minutes; the airline's checkout total is the truth.
- `$B text` on Google Flights returns the results twice (top and "other"
  flights); the aria-label extraction dedupes naturally.
- Prices are the searched party's round-trip total in the currency `CURR`
  selects; the date grid follows that currency, so `CURR=EUR` prints `€` cells.
