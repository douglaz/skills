---
name: copa-booking
description: >-
  Book a Copa Airlines itinerary on copaair.com up to the payment step by
  driving the user's real Google Chrome over the DevTools protocol: launch
  Chrome with a debug port, let the user clear DataDome and log into
  ConnectMiles, run the booking-panel search, pick outbound and return fare
  families, auto-fill the passenger from the profile, skip seats and extras,
  and stop on the card form. Use whenever the user wants to buy, book, hold or
  price a Copa / ConnectMiles ticket, mentions copaair.com, CM flight numbers,
  Panama connections, or when flight-search ends with Copa as the seller. Also
  the reference technique for any airline site that blocks automation browsers.
---

# Copa Airlines booking (real Chrome over CDP)

Copa's shopping site (`shopping.copaair.com`) sits behind DataDome. Headless
and headed Playwright browsers get a 401 challenge page they cannot pass, and
importing cookies from the user's browsers was not a usable route either (the
importer found nothing to import, so whether a copied cookie would pass is
unmeasured). What works: a real Google Chrome that the user unlocks once, which
you then drive over the DevTools protocol. Chrome 136+ refuses remote debugging
on its default profile, so a dedicated profile directory is used; the user logs
into ConnectMiles there once and it persists.

Everything below stops at the payment page. Card entry and the final "Confirm
Purchase" click are always the user's: do not type card numbers or press that
button even if a card is pasted in chat; ask them to enter it in the Chrome
window instead.

## Inputs to have ready

From `flight-search` or the user: origin, destination, dates, flight numbers
per direction (as Copa prints them, e.g. `CM 296 · CM 880`), and the fare
family (`basic`, `classic`, `full`, `business`). If you only have a price,
`copa.js search` prints the whole fare matrix so you can match it.

Fare families in economy: **Basic** (no checked bag, paid seat, changes with
fee), **Classic** (23 kg bag, regular seat pick, one free change if made 8+
days out), **Full** (two bags, refundable-ish). Google Flights' headline price
is normally Basic; users who say "with a bag" mean Classic. Business comes as
**Promo** and **Full** (API codes PRO/BFU, very different prices); `pick`
refuses a bare `business` when both are offered, so pass `business-promo` or
`business-full`. The business labels were not exercised in the field.

## Flow

Scripts live in `scripts/`. The skill may be installed under any of the three
skills roots (Claude Code, Codex, legacy Codex), so resolve it rather than
assuming one:

```bash
for d in "$HOME/.claude/skills/copa-booking" \
         "${CODEX_HOME:-$HOME/.codex}/skills/copa-booking" \
         "$HOME/.agents/skills/copa-booking"; do
  # The whole script set must be there: a stale root with only copa.js would pass and fail at launch.
  if [ -f "$d/scripts/copa.js" ] && [ -f "$d/scripts/cdp.js" ] && [ -x "$d/scripts/launch_chrome.sh" ]; then
    S="$d/scripts"; break
  fi
done
[ -n "${S:-}" ] || { echo "copa-booking scripts (copa.js, cdp.js, launch_chrome.sh) not found together under any skills root"; exit 1; }
C="node $S/copa.js"
```

Both scripts need `playwright-core` (resolved by `require`, falling back to the
copy gstack bundles under `~/.claude/skills/gstack/node_modules`). Every
required click or page transition in `copa.js` throws and exits 1 when it does
not happen, so a non-zero exit means "the page is not where the flow assumes",
never "carry on".

### 1. Launch Chrome and hand the challenge to the user

```bash
"$S/launch_chrome.sh" https://shopping.copaair.com/booking-panel
$C status        # {"url":..., "captcha":true/false, "loggedIn":true/false, "user":"<login-box label>"}
```

The launcher reuses a Chrome that is already listening on the port and opens
the URL as a new tab there, so the drivers always have a Copa tab to attach
to. When several Copa tabs are open the drivers take the most recently active
one (Chrome's own ordering) and say so; other tabs (a payment page still
waiting for a card, a PriceLock hold from an earlier session) are never
navigated: `search` opens its own tab unless the chosen one is already the
booking panel. Close finished tabs yourself when a session ends. If port 9222 is taken, export `CDP_PORT` once; the launcher and
both drivers read it.

If `captcha` is true, stop and tell the user: a Chrome window titled Copa is
open on their desktop; solve the challenge there, then say "done". Do not try
to solve or bypass it. If `loggedIn` is false the user has a choice: log into
ConnectMiles in that window so the passenger form auto-fills from the profile
(no name or birth date in chat), or continue as a guest and give you the
passenger details for the manual form (`--first --last --dob --email`). Only
the challenge blocks progress.

### 2. Search from the booking panel

```bash
$C search ASU ATL 2026-10-08 2026-10-17     # omit the return date for one way; --adults N for a party
```

The panel remembers its traveler count between searches and the script does
not drive that popover. It verifies the control reads the expected adults
(1 unless `--adults N`) with no children or infants, and exits 1 otherwise;
in that case ask the user to set travelers in the Chrome window and rerun.
Later, fill each traveler with `passenger --traveler K`; only traveler 1 was
exercised in the field.

This fills the autocompletes, works the range date picker (both dates in one
open picker, it resets if closed in between), presses "Find flights" (the
button's aria-label is "Search Flights", which is what the script matches), waits
for the results to settle and prints two things: the visible outbound cards,
and a fare matrix parsed from Copa's `/ibe/booking/plan` API response (saved
as `plan.json` in a private temp directory of its own; the path is printed,
and `$C plan <file>` re-prints it). The matrix is the complete picture: every
itinerary, layover, and fare-family price per direction, plus the price
calendar for nearby days. Quote from it.

Never open a deep link with `date1=`/`date2=` in the URL (Google's hand-off
form does this): Copa redirects those to a "flexible search" page whose
Continue button loops. The booking panel is the only reliable entry.

The first render sometimes shows "Invalid date" and "No flights found" for a
few seconds before the list appears; the script waits through it.

### 3. Pick outbound, then return

```bash
$C pick "CM 296 · CM 880" classic      # opens the card's Economy panel, expands Classic, confirms
$C flights                             # now shows the return cards
$C pick "CM 891 · CM 291" classic
$C summary "CM 296 · CM 880" "CM 891 · CM 291" classic 2026-10-08 2026-10-17   # args must hold: flights, fare, dates in leg order
```

`pick` matches the flight-number string exactly as printed on the card (middle
dot, spaces; a nonstop card is just `CM 206`) and confines the fare click to
that card's own panel. Pass the flight numbers and fare family to `summary` so
it exits 1 if the page holds anything else: it checks whole flight strings and
the fare line under each itinerary line, one leg per direction requested. On
the summary page check the total against what you quoted and
tell the user about PriceLock: 24 hours is free, which is a good default when
they still need to think.

### 4. Continue to passengers and fill them

```bash
$C continue                                   # summary -> traveler-information
$C passenger --profile --gender Male --cc "+1 United States of America" --phone 5551234567
```

`--profile` picks the first saved passenger from the ConnectMiles profile
(name, birth date, email, frequent-flyer number come along); `--profile 2`
picks the second, counting from 1 in the order the picker lists them. Then supply what
the profile lacks: gender is a two-option dropdown (Male/Female), phone needs
the country from a dial-code picker whose labels look like `+1 United States
of America` (there is also `+1 United States Virgin Islands`, so pass the full
label), and the number without spaces. For a manual passenger use `--first
--last --dob DD/MM/YYYY --email` instead of `--profile`.

The script prints the field values masked plus any validation messages; the
form refuses to continue while "Enter a valid phone number" is showing.
Passport data is not requested here (Copa takes it at check-in), but name and
birth date cannot be changed after purchase, so read them back to the user once
with `--show-fields` and get a yes before continuing.

```bash
$C continue          # validates the frequent-flyer number and opens the seat map
```

`continue` knows where each page should lead (summary → passengers →
seats/checkout) and exits 1 if the site lands anywhere else, which is what an
expired session or a login redirect looks like.

### 5. Seats, review, payment

```bash
$C seats-skip                                   # "Continue to checkout" without seats
$C review --no-insurance --no-carbon --no-miles --to-payment
```

Classic fares include free regular seats, which can be picked later in "My
Trips", so skipping is the safe default unless the user stated a preference.
`review` declines the paid extras (insurance about $69, carbon offset, miles
booster) unless the user asked for them, prints the reservation cost block,
and `--to-payment` presses Continue so the page lands on
`secure.copaair.com` ("Pay reservation", credit card or PayPal).

Stop there. Report the total, what was chosen and declined, and that the card
form is waiting in the Chrome window. Then update memory with the itinerary and
"payment pending".

## Inspecting anything else

`scripts/cdp.js` is a generic driver for the same Chrome: `url`, `text [n]`,
`eval <js>`, `click <sel>`, `fill <sel> <val>`, `type <sel> <val>`, `wait
<sel>`, `shot <png>`. Reach for it when a page differs from the notes.
`references/copa-site-notes.md` lists the routes, element ids and quirks
observed on the site; read it before improvising on a page the flow does not
cover (multi-city, miles, children, business fares).

## Rules that keep this safe

- The DevTools port is loopback-only but has no authentication: any other
  account on the same machine could attach to the logged-in Copa tabs, payment
  page included. The launcher refuses when `who` shows other logged-in users or
  cannot run at all; that is a heuristic (it sees terminal sessions, not every
  local process), so treat this workflow as single-user-desktop only and
  override with `CDP_SHARED_HOST_OK=1` solely on a host the user trusts. Once
  the purchase is done tell the user to close that Chrome window.
- Never click "Confirm Purchase and Continue" and never type card numbers, even
  when a card is pasted in chat: the user enters it in the Chrome window.
- Passenger values print masked (`a***@x.com`, `***244`, names as first letter
  plus length); use `passenger --show-fields` only for the one read-back the
  name/birth-date lock requires, and do not repeat those values elsewhere.
- Never try to defeat DataDome; the user solves it in their own window.
- The Chrome window is the user's: do not close it, log out, or navigate away
  from a half-finished booking without saying so.
- Re-check the total on the summary and review pages; Google's price and
  Copa's can differ by tens of dollars and by fare family.
