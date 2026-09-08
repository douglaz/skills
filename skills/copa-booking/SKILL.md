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
imported cookies do not help because the token is bound to the browser
fingerprint. What works: a real Google Chrome that the user unlocks once, which
you then drive over the DevTools protocol. Chrome 136+ refuses remote debugging
on its default profile, so a dedicated profile directory is used; the user logs
into ConnectMiles there once and it persists.

Everything below stops at the payment page. Card entry and the final "Confirm
Purchase" click belong to the user unless they explicitly hand you the card in
chat and ask you to pay.

## Inputs to have ready

From `flight-search` or the user: origin, destination, dates, flight numbers
per direction (as Copa prints them, e.g. `CM 296 · CM 880`), and the fare
family (`basic`, `classic`, `full`, `business`). If you only have a price,
`copa.js search` prints the whole fare matrix so you can match it.

Fare families in economy: **Basic** (no checked bag, paid seat, changes with
fee), **Classic** (23 kg bag, regular seat pick, one free change if made 8+
days out), **Full** (two bags, refundable-ish). Google Flights' headline price
is normally Basic; users who say "with a bag" mean Classic.

## Flow

Scripts live in `scripts/`; set `C="node $HOME/.claude/skills/copa-booking/scripts/copa.js"`.
Both scripts need `playwright-core`; they fall back to the copy bundled with
gstack at `~/.claude/skills/gstack/node_modules/playwright-core`.

### 1. Launch Chrome and hand the challenge to the user

```bash
$HOME/.claude/skills/copa-booking/scripts/launch_chrome.sh https://shopping.copaair.com/booking-panel
$C status        # {"url":..., "captcha":true/false, "user":"You've logged in with the user <NAME>..."}
```

If `captcha` is true or `user` is null, stop and tell the user: a Chrome window
titled Copa is open on their desktop; solve the challenge and log into
ConnectMiles there, then say "done". Logging in matters because the passenger
form can then auto-fill from the profile, which avoids asking for name and
birth date in chat. Do not try to solve or bypass the challenge.

### 2. Search from the booking panel

```bash
$C search ASU ATL 2026-10-08 2026-10-17     # omit the return date for one way
```

This fills the autocompletes, works the range date picker (both dates in one
open picker, it resets if closed in between), presses "Find flights", waits
for the results to settle and prints two things: the visible outbound cards,
and a fare matrix parsed from Copa's `/ibe/booking/plan` API response
(saved to `copa-plan.json`). The matrix is the complete picture: every
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
$C summary                             # itinerary, baggage, PriceLock options, total
```

`pick` matches the flight-number string exactly as printed on the card (middle
dot, spaces). On the summary page check the total against what you quoted and
tell the user about PriceLock: 24 hours is free, which is a good default when
they still need to think.

### 4. Continue to passengers and fill them

```bash
$C continue                                   # summary -> traveler-information
$C passenger --profile --gender Male --cc "+1 United States of America" --phone 5551234567
```

`--profile` picks the first saved passenger from the ConnectMiles profile
(name, birth date, email, frequent-flyer number come along). Then supply what
the profile lacks: gender is a two-option dropdown (Male/Female), phone needs
the country from a dial-code picker whose labels look like `+1 United States
of America` (there is also `+1 United States Virgin Islands`, so pass the full
label), and the number without spaces. For a manual passenger use `--first
--last --dob DD/MM/YYYY --email` instead of `--profile`.

The script prints the field values and any validation messages; the form
refuses to continue while "Enter a valid phone number" is showing. Passport
data is not requested here (Copa takes it at check-in), but name and birth
date cannot be changed after purchase, so echo them to the user.

```bash
$C continue          # validates the frequent-flyer number and opens the seat map
```

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

- Never click "Confirm Purchase and Continue" or type card numbers unless the
  user gave them in the conversation and asked you to pay.
- Never try to defeat DataDome; the user solves it in their own window.
- The Chrome window is the user's: do not close it, log out, or navigate away
  from a half-finished booking without saying so.
- Re-check the total on the summary and review pages; Google's price and
  Copa's can differ by tens of dollars and by fare family.
