# copaair.com field notes (observed Sep 2026, storefront GS / English)

Read this when a page differs from the scripted flow. Everything here was seen
live; selectors can drift, so treat them as the first thing to try.

## Bot protection

- `shopping.copaair.com` and `login.copaair.com` are behind DataDome. Automation
  browsers get HTTP 401 with a `captcha-delivery.com` iframe (`'t':'bv'` = hard
  block, `'t':'fe'` = interactive challenge). The `datadome` cookie is
  fingerprint-bound; importing it into another browser does not help.
- A real Google Chrome launched with `--remote-debugging-port` passes once the
  user solves the challenge. Playwright's `connectOverCDP` did not trip it
  during a full booking flow.
- Chrome 136+ ignores `--remote-debugging-port` on the default profile; use a
  separate `--user-data-dir`. The user then logs into ConnectMiles in that
  profile once.

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

## Summary page

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
- Continue button aria-label: `Button, Press enter to to validate your frequent
  flyer number, save the information and proceed to seat selection`. Name and
  birth date are locked after purchase.

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
