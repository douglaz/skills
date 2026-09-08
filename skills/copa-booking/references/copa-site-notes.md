# copaair.com field notes (observed Sep 2026, storefront GS / English)

Read this when a page differs from the scripted flow. Everything here was seen
live; selectors can drift, so treat them as the first thing to try.

## Provenance

One booking session on 2026-09-07/08 (UTC), ASU→ATL round trip, 1 adult,
Economy Classic, run from Linux with these versions:

- Google Chrome 152.0.7977.82, launched as `google-chrome
  --remote-debugging-port=9222 --user-data-dir=~/.config/chrome-agent` and
  driven with `playwright-core` 1.62.1 (`chromium.connectOverCDP`) on Node
  24.19.0; the driving commands are the ones now in `scripts/copa.js` (the
  session used their predecessors with the same selectors).
- gstack 1.79.0 `browse` (Playwright Chromium) for the headless and `--headed`
  attempts; observations there came from `browse goto` (reported `(401)`),
  `browse html body`, and `browse network`.

What was not measured: the cookie route. gstack's `cookie-import-browser`
reported `Imported 0 cookies for copaair.com` from both a Chrome and a Chromium
profile, so no imported `datadome` cookie was ever presented to the site. Site
behaviour in other regions, storefronts, or on macOS/Windows is also unmeasured.

### Rerunnable record: the browse daemon is blocked

Run on 2026-09-08 (UTC) with gstack 1.79.0.0's `browse` (`B` below), from
Asunción; each stream captured by redirection. `browse goto` exits 0 even when
the page answers 401 — the HTTP status is only in its stdout line.

```console
$ B=~/.claude/skills/gstack/browse/dist/browse; URL=https://shopping.copaair.com/booking-panel
$ $B disconnect; $B goto "$URL" >goto.headless.out 2>goto.headless.err; echo "exit=$?"
exit=0
$ cat goto.headless.out
Navigated to https://shopping.copaair.com/booking-panel (401)
$ cat goto.headless.err
[browse] Starting server...
$ $B html body >body.headless.html 2>body.headless.err; echo "exit=$?"
exit=0
$ grep -oE "'rt':'[a-z]'|'t':'[a-z]+'" body.headless.html; grep -c captcha-delivery.com/captcha body.headless.html
'rt':'c'
't':'bv'
1

$ $B disconnect; DISPLAY=:0 $B --headed goto "$URL" >goto.headed.out 2>goto.headed.err; echo "exit=$?"
exit=0
$ cat goto.headed.out
Navigated to https://shopping.copaair.com/booking-panel (401)
$ cat goto.headed.err
[browse] Starting server in headed mode...
$ sleep 3; $B --headed html body >body.headed.html 2>body.headed.err; echo "exit=$?"
exit=0
$ grep -oE "'rt':'[a-z]'|'t':'[a-z]+'" body.headed.html; grep -c captcha-delivery body.headed.html
'rt':'i'
3
```

Read: both modes get a 401 body that is DataDome's `dd` config plus the
`geo.captcha-delivery.com` challenge; headless carries `'t':'bv'` (the block
the user cannot click through), headed carries `'rt':'i'` (the interactive
page; on 2026-09-07 the same run showed `'t':'fe'`). The user could not pass
the challenge in the headed daemon's window either, which is an observation,
not an explanation of why. Only the real Chrome path below produced a page
with flight results.

## Bot protection

- `shopping.copaair.com` and `login.copaair.com` are behind DataDome. The
  headless daemon got HTTP 401 with a `captcha-delivery.com` iframe and
  `'t':'bv'` in the page's `dd` config (a block the user cannot click through);
  the headed daemon got 401 with `'t':'fe'` (an interactive challenge that the
  user still could not pass in that window). Whether a copied `datadome` cookie
  would pass is unmeasured (see Provenance).
- The real Google Chrome above passed once the user solved the challenge in its
  window. Playwright's `connectOverCDP` did not trip DataDome during that one
  full booking flow (search → fares → passenger → seats → review → payment
  page).
- A separate `--user-data-dir` is used. Chrome's release notes state that 136+
  refuses `--remote-debugging-port` on the default profile; that was not
  measured here (the default profile was busy with the user's normal Chrome),
  so it is the vendor's claim, not an observation. The dedicated profile is
  the measured, working path (Provenance above). The user logs into
  ConnectMiles in that profile once.

## SPA routes (shopping.copaair.com)

`/booking-panel` (search form), `/flights` (results; needs in-app state,
direct navigation bounces to the panel), `/flexible-search` (calendar grid),
`/summary`, `/traveler-information/<id>`, `/checkout/<id>`; seats live on
`seats.copaair.com`, payment on `secure.copaair.com/<code>/<id>`.

Deep links with `date1=`/`date2=` query params (what Google Flights hands off)
are routed by `useNoAvailabilityRedirect` to `/flexible-search` with the text
"We couldn't find flights on the selected dates" even when the plan API
returns solutions; its Continue button just reloads the same page. Always
search from `/booking-panel`.

## Booking panel

- Trip type buttons: `ROUND TRIP`, `ONE WAY`, `MULTI-CITY / STOPOVER`.
- Inputs: `#origin-autocomplete-0`, `#destination-autocomplete-0` (type the
  IATA code, options are `[role=option]` whose text ends with the code),
  `#date-input-0` (range picker), `#travelerSelection` ("1  Adult"),
  `#panelPromocode`. Search button aria-label starts with `Search Flights`.
- Date picker: shows three months with headers like `October 2026`; arrows have
  aria-labels `August 2026. Press enter to go to August days.` Day cells are
  `td[role=button]` with aria-label `Thursday 08. Press enter to select this
  day.` while choosing the departure; after the first click the picker switches
  to return mode and the aria-labels disappear, so locate cells by month header
  position. Closing and reopening the picker restarts the range. The input
  reads `Thu 8, Oct - Sat 17, Oct` when both are set; a `Done` button closes it.
- First results render sometimes shows `Invalid date` and `Oops! No flights
  found.` for a few seconds, then the list appears.

## Results page

- Header `Select outbound flight` / `Select return flight`, a 7-day price
  strip (`Days browser button. Press enter to modify the departure date...`).
- Each card: flight numbers `CM 296 · CM 880`, `Layover in PTY (1h 51m)`,
  times, duration, `View details`, and cabin buttons with aria-labels
  `Economy cabin. Price from 362.48 USD per adult` / `Business Cabin. Price
  from ...`. Clicking a cabin button expands fare cards with aria-labels
  `Economic Basic fare family, this fare is priced at 362.48 USD...`,
  `EconomicClassic fare family...` (no space), `EconomicFull fare family...`.
  Clicking one expands its attributes and a confirm button `Select Economy
  Classic`; only that confirm advances the flow.
- `Add Stopover` offers a free Panama stopover; `Flexible search` and
  `Stopover in Panama` links leave the flow.

## Plan API

`GET https://api.copaair.com/ibe/booking/plan?departureAirport1=..` fires when
results load. Response: array of origin-destinations, each with `solutions[]`
(`key`, `numberOfLayovers`, `journeyTime` ISO-8601, `lowestPriceCoachCabin`,
`lowestPriceBusinessCabin`, `flights[]` with `marketingCarrier.{airlineCode,
flightNumber}`, `departure/arrival.{airportCode,flightDate,flightTime}`,
`layoverTime`, `changeOfDay`; `offers[]` with `fareFamily.{code,name}`,
`pricePerAdult`, `totalPrice`, `seatsLeft`) and `priceCalendars[]` (7 days of
lowest prices). Fare codes: BAS Economy Basic, CLS Economy Classic, CLF
Economy Classic Flex (API only, not shown in UI), EFU Economy Full, PRO
Business Promo, BFU Business Full. Round-trip total = outbound offer + return
offer; taxes are already inside these numbers (summary shows fare + taxes
split, same total).

`/ibe/booking/flexible-dates` returns the grid used by `/flexible-search`.

## Header / login box

Logged in, `#btnMembersLoginBox` carries aria-label `You've logged in with the
user <NAME>. Press Enter to enter Member's Menu` and the header shows the
member's initials. Logged out (observed after the session expired a few hours
later), that id is absent, the header shows `LOG IN`, and the login control's
aria-label is `Connect Miles Login, allows you to get access to your member
profile. Press Enter to go to Login form.` `status` keys `loggedIn` on the
logged-in phrase and reports whichever label it finds as `user`.

## Summary page

Each itinerary line reads `Thu, Oct 8, 2026 · CM 296 · CM 880` (nonstop: a
single flight number after the date, inferred, not observed) and its fare
family (`Economy Classic`) appears a few lines below, before `Change Flight`.
Itinerary with `Change Flight` per direction, baggage allowance, an upsell
(`Unlimited Flexibility +147.60 USD`), PriceLock radios (`name=priceLock`:
`1` = 24 hours free, `3` = 3 days for a fee, `0` = continue without, default
`0`), `Reservation cost` block with AIRFARE, fees and taxes, Total. Continue
button aria-label starts with `Continue button`.

## Traveler information

- Radios `#filled-auto-populate0` (Use profile) and `#filled-manual0`.
  Profile combobox `#profile0` lists saved passengers as `FIRST MIDDLE LAST`
  in capitals; picking one fills `name0`, `surname0`, `day/month/year`
  comboboxes (`#day0`, `#month0`, `#year0`), `email0`, `confirmEmail0`,
  `FFProgramID`=CM and `FFPnumber`. Gender may come through as `Unknown`, which
  the form rejects.
- `#gender0` combobox: options `Male`, `Female` only.
- Phone: `input[name=areaCode]` is an autocomplete over ~250 entries labelled
  `+1 United States of America`, `+1 United States Virgin Islands`, `+595
  Paraguay`... Typing `United States` filters to nothing; type the dial code
  and pick the exact label. Free text there yields `Enter a valid phone
  number`. Number goes in `#phone0` without spaces.
- Optional: Frequent Flyer Program, Known traveler number, Redress number.
- Continue button: visible text `Continue` (what the driver matches), aria-label
  `Button, Press enter to to validate your frequent flyer number, save the
  information and proceed to seat selection`. Name and birth date are locked
  after purchase.

## Seats, checkout, payment

- Seat map (`seats.copaair.com`) per flight; `Go to checkout. Press Enter to
  continue without seats` skips. Economy Extra seats from about 50 USD.
- Checkout (`/checkout/<id>`, "Review and Pay"): miles booster radios
  (`miles-booster.selection`, default `no-multiplier`), insurance radios
  (`insuranceSelected` / `insuranceUnselected`, nothing selected by default,
  about 68.72 USD per passenger), carbon offset radios (`carbon-emission`,
  default decline, 12.51 USD). Continue button aria-label starts with
  `Continue button`.
- Payment (`secure.copaair.com`): "Pay reservation", travel certificate,
  `Enter a credit card → Select`, PayPal, `Confirm Purchase and Continue`,
  purchase summary total. This is the hand-off point.
