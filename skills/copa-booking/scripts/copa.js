#!/usr/bin/env node
// Copa Airlines booking driver over CDP (real Chrome launched by launch_chrome.sh).
// usage: node copa.js <cmd> [args]
//   status                                         url, DataDome iframe present?, loggedIn (ConnectMiles), raw login-box label
//   search ORIG DEST YYYY-MM-DD [YYYY-MM-DD] [--adults N] [--plan-out f]
//                                                  booking-panel search; prints cards + fare matrix. The panel keeps its
//                                                  last traveler count, so the script VERIFIES it reads N adults (default 1)
//                                                  and refuses otherwise; set travelers in the Chrome window first.
//   flights                                        print the visible flight cards
//   pick "CM 296 · CM 880" basic|classic|full|business|business-promo|business-full
//                                                  select that card's cabin + fare family ("business" must be unambiguous)
//   summary ["CM 296 · CM 880" "CM 891 · CM 291" classic 2026-10-08 2026-10-17]
//                                                  itinerary / PriceLock / total; flights, fare family and dates
//                                                  (bound to legs in order) are asserted, exit 1 otherwise
//   continue                                       press the page's main Continue; exits 1 unless the expected next page loads
//   passenger [--traveler K] [--profile [N]] [--first F --last L --dob DD/MM/YYYY --email E]
//             [--gender Male|Female] [--cc "+1 United States of America"] [--phone 5551234567] [--show-fields]
//             (values are printed masked; --show-fields prints only name and birth date in clear, for the read-back)
//             (--profile alone = first saved passenger; N counts from 1 in the picker's order;
//              --traveler K fills the K-th traveler's block, default 1; contact fields sit on traveler 1)
//   seats-skip                                     "Continue to checkout" without seats
//   review [--no-insurance] [--no-carbon] [--no-miles] [--to-payment]   decline extras; optionally go to the pay page
//   plan <file>                                    re-print the fare matrix from a saved plan json
// Every required click or page transition throws (exit 1) when it does not happen, so a
// selector that drifted cannot leave the flow silently on the wrong page.
// Env: CDP_URL (default http://127.0.0.1:$CDP_PORT, port 9222 — the same CDP_PORT launch_chrome.sh reads),
//      CDP_MATCH (tab url substring, default "copaair")
const fs = require('fs');
const os = require('os');
const path = require('path');
const CDP = process.env.CDP_URL || `http://127.0.0.1:${process.env.CDP_PORT || 9222}`;
const MATCH = process.env.CDP_MATCH || 'copaair';
const MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const log = (...a) => console.log(...a);
const sleep = ms => new Promise(r => setTimeout(r, ms));
const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
// A required step: anything falsy (null, false, '') means the page is not where the flow assumes.
const must = (what, v) => { if (!v) throw new Error(`required step failed: ${what}`); return v; };
// Passenger data stays out of stdout (transcripts persist): values are masked; --show-fields
// unmasks name and birth date only, for the confirmation the purchase lock requires.
const mask = (k, v) => {
  v = String(v ?? ''); if (!v) return '(empty)';
  if (/email/i.test(k)) return /@/.test(v) ? v.replace(/^(.).*?(@.*)$/, '$1***$2') : 'set (' + v.length + ' chars)'; // a malformed address must not print whole
  if (/phone|FFPnumber|areaCode/i.test(k)) return v.length > 3 ? '***' + v.slice(-3) : '***';
  if (/^(day|month|year)$/i.test(k)) return 'set';
  if (/name|surname/i.test(k)) return v[0] + '*** (' + v.length + ' chars)';
  if (/^(gender|FFProgramID)$/i.test(k)) return v; // the only values known to be harmless (Male/Female, a program code)
  return 'set (' + v.length + ' chars)'; // deny by default: known-traveler, redress and any future field stay out of the transcript
};
const initials = s => String(s).trim().split(/\s+/).map(w => w[0] || '').join('') + '…';

function chromium() {
  const H = process.env.HOME; const roots = [`${H}/.claude/skills`, `${process.env.CODEX_HOME || H + '/.codex'}/skills`, `${H}/.agents/skills`];
  for (const c of ['playwright-core', 'playwright', ...roots.map(r => `${r}/gstack/node_modules/playwright-core`)]) {
    try { return require(c).chromium; } catch {}
  }
  throw new Error('playwright-core not found: npm i playwright-core, or install gstack under a skills root');
}
const argv = process.argv.slice(2); const cmd = argv.shift();
const fi = argv.findIndex(a => a.startsWith('--'));
const pos = fi < 0 ? argv : argv.slice(0, fi); const rest = fi < 0 ? [] : argv.slice(fi);
const flag = n => { const i = rest.indexOf(n); if (i < 0) return undefined; const v = rest[i + 1]; return v !== undefined && !v.startsWith('--') ? v : true; };
// For flags that take a value: absent → undefined, present without a value → error, never the
// literal "true" typed into a form field.
const val = n => { const v = flag(n); if (v === true) throw new Error(`${n} needs a value`); return v; };

// Only a tab whose URL contains CDP_MATCH is ever driven, and when several match the MOST
// RECENTLY ACTIVE one wins — the tab the launcher or `search` just opened, or the one the user
// just solved the challenge in — while older matching tabs are earlier sessions (a payment page
// waiting for a card, a PriceLock hold) that must be left alone. Chrome's /json endpoint lists
// targets most-recently-active first (Playwright's page order is not creation order, measured);
// pages are matched to it by target id. `search` opens its own tab unless the chosen one is
// already the booking panel, so it never navigates a half-finished booking away.
async function mostRecent(hits) {
  if (hits.length < 2) return hits[0];
  const ids = await Promise.all(hits.map(async pg => { const s = await pg.context().newCDPSession(pg); const { targetInfo } = await s.send('Target.getTargetInfo'); await s.detach(); return targetInfo.targetId; }));
  const order = (await (await fetch(CDP.replace(/\/$/, '') + '/json')).json()).filter(t => t.type === 'page').map(t => t.id);
  const ranked = hits.map((pg, i) => [order.indexOf(ids[i]), pg]).filter(([r]) => r >= 0).sort((a, b) => a[0] - b[0]);
  if (!ranked.length) throw new Error(`${hits.length} tabs match ${JSON.stringify(MATCH)} and none could be ranked by recency; set CDP_MATCH to a distinguishing URL fragment`);
  return ranked[0][1];
}
async function connect({ freshPanel = false } = {}) {
  const b = await chromium().connectOverCDP(CDP);
  const pages = b.contexts().flatMap(c => c.pages());
  const hits = pages.filter(x => x.url().includes(MATCH));
  let p;
  try { p = await mostRecent(hits); } catch (e) { await b.close(); throw e; }
  if (hits.length > 1) log(`${hits.length} tabs match ${JSON.stringify(MATCH)}; driving the most recently active (${p.url().slice(0, 70)}) and leaving the others alone`);
  if (freshPanel && (!p || !/booking-panel/.test(p.url()))) {
    // A tab already sitting on the booking panel is never a half-finished booking, so reuse
    // one if any is open (whatever its recency) before adding another tab to the window.
    const panel = hits.find(x => /booking-panel/.test(x.url()));
    if (panel) { p = panel; log('reusing the open booking-panel tab for the search'); }
    else {
      if (!b.contexts().length) { await b.close(); throw new Error('no browser context to open a tab in'); }
      p = await b.contexts()[0].newPage(); log('opened a new tab for the search' + (hits.length ? ' (the existing Copa tabs are past the booking panel and are left untouched)' : ''));
    }
  }
  if (!p) { await b.close(); throw new Error(`no open tab matches ${JSON.stringify(MATCH)}; tabs: ${pages.map(x => x.url().slice(0, 60)).join(' | ') || '(none)'} — run launch_chrome.sh or set CDP_MATCH`); }
  return { b, p };
}
const body = p => p.innerText('body').catch(() => '');
const clean = t => t.replace(/​/g, '').replace(/\n{2,}/g, '\n');
const stable = t => !/Wait a moment|Loading results/i.test(t.slice(0, 400));
async function waitUntil(p, pred, ms = 45000, step = 1500) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) { const t = await body(p); if (await pred(t, p.url())) return true; await sleep(step); }
  return false;
}
// Click the first visible element whose aria-label or text matches re. Returns null when nothing matched.
const clickBy = (p, re, sel = 'button,[role="button"],a') => p.evaluate(([r, s]) => {
  const R = new RegExp(r, 'i');
  const e = [...document.querySelectorAll(s)].find(e => e.offsetParent && (R.test(e.getAttribute('aria-label') || '') || R.test((e.innerText || '').replace(/\s+/g, ' ').trim())));
  if (!e) return null; e.scrollIntoView({ block: 'center' }); e.click();
  return ((e.getAttribute('aria-label') || e.innerText) || '').replace(/\s+/g, ' ').trim().slice(0, 90);
}, [re.source || re, sel]);
const pickOption = (p, re) => p.evaluate(r => {
  const R = new RegExp(r, 'i');
  const els = [...document.querySelectorAll('[role="option"], [role="listbox"] li')].filter(e => e.offsetParent);
  const t = els.find(e => R.test(e.innerText.replace(/\s+/g, ' ').trim()));
  if (!t) return null; t.scrollIntoView({ block: 'center' }); t.click();
  return t.innerText.replace(/\s+/g, ' ').trim().slice(0, 60);
}, re.source || re);
const listOptions = p => p.evaluate(() => [...document.querySelectorAll('[role="option"], [role="listbox"] li')].filter(e => e.offsetParent && e.innerText.trim()).map(e => e.innerText.replace(/\s+/g, ' ').trim().slice(0, 50)));
async function centerClick(p, sel) {
  const c = await p.evaluate(s => { const d = document.querySelector(s); if (!d) return null; d.scrollIntoView({ block: 'center' }); const r = d.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; }, sel);
  if (!c) throw new Error('not found: ' + sel);
  await p.mouse.click(c.x, c.y);
}
const errors = p => p.evaluate(() => [...document.querySelectorAll('[class*="error" i], [role="alert"]')]
  .filter(e => e.offsetParent && e.innerText.replace(/[​\s]/g, '').length > 2 && !/travel requirements|Seat selection page/i.test(e.innerText))
  .map(e => e.innerText.replace(/\s+/g, ' ').trim().slice(0, 100)));
const fields = p => p.evaluate(() => Object.fromEntries([...document.querySelectorAll('input')].filter(e => e.offsetParent && (e.name || e.id) && e.type !== 'radio').map(e => [e.name || e.id, e.value])));
const ctas = p => p.evaluate(() => [...document.querySelectorAll('button,a')].filter(b => b.offsetParent && /continue|next|skip|proceed|pay|checkout|confirm|purchase|without/i.test((b.getAttribute('aria-label') || '') + ' ' + (b.innerText || ''))).map(b => ((b.getAttribute('aria-label') || b.innerText) || '').replace(/\s+/g, ' ').trim().slice(0, 80)));

// Range date picker: click day `iso` inside the month whose header ("October 2026") owns that
// month's table — the header that contains the table or is the last one preceding it in DOM
// order. Observed: headers sit outside their tables, months render side by side (same top), so
// geometry cannot tell them apart and aria-labels vanish in return mode.
async function pickDay(p, iso) {
  const [y, m, d] = iso.split('-').map(Number); const header = `${MONTHS[m - 1]} ${y}`;
  for (let i = 0; i < 14; i++) {
    const r = await p.evaluate(([header, d]) => {
      const vis = e => e.offsetParent !== null;
      const heads = [...document.querySelectorAll('*')].filter(e => vis(e) && e.children.length === 0 && /^[A-Z][a-z]+ \d{4}$/.test(e.textContent.trim()));
      const names = heads.map(h => h.textContent.trim());
      if (!names.includes(header)) return { heads: names };
      const monthOf = el => { let best = null; for (const h of heads) { if (el.contains(h)) return h.textContent.trim(); if (h.compareDocumentPosition(el) & Node.DOCUMENT_POSITION_FOLLOWING) best = h; } return best ? best.textContent.trim() : null; };
      const td = [...document.querySelectorAll('td')].find(c => vis(c) && c.innerText.trim() === String(d) && monthOf(c.closest('table') || c) === header);
      if (!td) return { heads: names, nocell: true };
      td.scrollIntoView({ block: 'center' }); const rc = td.getBoundingClientRect();
      return { x: rc.x + rc.width / 2, y: rc.y + rc.height / 2, label: td.getAttribute('aria-label') || '' };
    }, [header, d]);
    if (r.x !== undefined) { await p.mouse.click(r.x, r.y); return `${header} ${d} (${r.label.slice(0, 25) || 'cell'})`; }
    if (r.nocell) throw new Error(`day ${d} not clickable in ${header} (past or unavailable?)`);
    const adv = await p.evaluate(() => { const a = [...document.querySelectorAll('[aria-label]')].filter(e => e.offsetParent && /Press enter to go to \w+ days/.test(e.getAttribute('aria-label'))); const last = a[a.length - 1]; if (!last) return null; last.click(); return last.getAttribute('aria-label').slice(0, 30); });
    if (!adv) throw new Error(`${header} not visible (${r.heads.join(', ')}) and no next-month arrow`);
    await sleep(500);
  }
  throw new Error('could not reach ' + header);
}
// "8, Oct" — how the panel's date input renders a chosen day ("Thu 8, Oct - Sat 17, Oct");
// anchored on a non-digit so "8, Oct" does not accept "18, Oct".
const stamp = iso => { const [, m, d] = iso.split('-').map(Number); return `${d}, ${MONTHS[m - 1].slice(0, 3)}`; };
const stampRe = iso => new RegExp(`(^|\\D)${esc(stamp(iso))}`);

function summarizePlan(d) {
  const out = [];
  for (const od of d) {
    const cur = od.currency?.code || '';
    out.push(`== ${od.originDestinationKey} ${od.origin.code} ${od.origin.departureDate} -> ${od.destination.code}  (${cur})`);
    const rows = (od.solutions || []).map(s => {
      const segs = s.flights.map(f => `${f.marketingCarrier.airlineCode}${f.marketingCarrier.flightNumber} ${f.departure.airportCode} ${f.departure.flightTime}→${f.arrival.airportCode} ${f.arrival.flightTime}${f.changeOfDay !== '0' ? '+' + f.changeOfDay : ''}`).join(' / ');
      const lay = s.flights.filter(f => f.layoverTime && f.layoverTime !== '0h0m').map(f => f.layoverTime).join(',');
      const offers = (s.offers || []).map(o => `${o.fareFamily?.code || '?'}=${o.totalPrice ?? o.pricePerAdult}`).join(' ');
      // A business-only solution has no coach price; sort and label it by its business price.
      const coach = s.lowestPriceCoachCabin ?? null; const price = coach ?? s.lowestPriceBusinessCabin ?? Infinity;
      return [price, `  ${price === Infinity ? '?' : price} ${cur}${coach === null ? ' (business only)' : ''} ${s.journeyTime.replace('PT', '')} lay=${lay || '-'} ${segs} | ${offers}`];
    }).sort((a, b) => a[0] - b[0]);
    rows.forEach(r => out.push(r[1]));
    if (od.priceCalendars) out.push('  nearby: ' + od.priceCalendars.map(c => `${c.date}:${c.price}`).join(' '));
  }
  return out.join('\n') + '\nFare codes: BAS=Economy Basic CLS=Economy Classic CLF=Classic Flex EFU=Economy Full PRO=Business Promo BFU=Business Full';
}
function printPlan(plan, where) {
  let parsed;
  try { parsed = JSON.parse(plan); if (!Array.isArray(parsed)) throw new Error('not an array'); }
  catch (e) { log(`(plan response not parseable: ${e.message}; fares above are the visible "from" prices only)`); return; }
  try { log(`---- FARE MATRIX (from API; ${where}) ----`); log(summarizePlan(parsed)); }
  catch (e) { log(`(plan response has an unexpected shape: ${e.message})`); }
}

// Summary page: each itinerary line reads "<Weekday>, <Mon> <d>, <yyyy> · CM 296[ · CM 880]" and its
// fare family line ("Economy Classic", "Business Promo") follows within a few lines. Nonstop legs
// carry a single flight number, so the date prefix, not a second middle dot, identifies the line.
function parseLegs(text) {
  const lines = text.split('\n').map(l => l.trim()); const legs = [];
  lines.forEach((l, i) => { if (/, \d{4} · [A-Z]{2} \d+/.test(l)) legs.push({ leg: l, fam: lines.slice(i + 1, i + 15).find(x => /^(Economy (Basic|Classic|Full)|Business\b.*)$/.test(x)) || '(no fare line found)' }); });
  return legs;
}
// A flight-number string must match whole ("CM 29" is not "CM 296", "CM 880" is not "CM 8801").
const flightsRe = s => new RegExp(`(^|[^\\d])${esc(s)}(?!\\d)`);

// Where each page's main Continue must lead; anything else (login, error, expired session) fails.
const NEXT = [
  [/\/summary/, /traveler-information/, 'the traveler-information page'],
  [/traveler-information/, /seats\.copaair\.com|\/checkout\//, 'the seat map or checkout'],
  [/\/checkout\//, /secure\.copaair\.com/, 'the payment page'],
];

const cmds = {
  async status({ p }) {
    const captcha = await p.evaluate(() => !!document.querySelector('iframe[src*="captcha-delivery"]'));
    // Logged in: #btnMembersLoginBox with "You've logged in with the user <NAME>. Press Enter ...".
    // Logged out (observed): no such id; the control's label starts "Connect Miles Login, ...".
    const user = await p.evaluate(() => document.getElementById('btnMembersLoginBox')?.getAttribute('aria-label')
      || [...document.querySelectorAll('[aria-label]')].map(e => e.getAttribute('aria-label')).find(l => /^Connect ?Miles Login/i.test(l)) || null);
    const loggedIn = /logged in with the user/i.test(user || '');
    log(JSON.stringify({ url: p.url(), captcha, loggedIn, user: user && user.replace(/(logged in with the user )([^.]+)/i, (m, a, n) => a + initials(n)), title: await p.title() }));
    log(clean((await body(p)).slice(0, 500)));
  },
  async 'parse-legs'() { const f = pos[0]; if (!f) throw new Error('usage: parse-legs <summary-text-file>'); log(JSON.stringify(parseLegs(fs.readFileSync(f, 'utf8')))); },
  async search({ p }) {
    const [o, d, dep, ret] = pos; if (!o || !d || !dep) throw new Error('usage: search ORIG DEST YYYY-MM-DD [YYYY-MM-DD]');
    const planFlag = val('--plan-out');
    // Default to a private temp dir (0700, random name) and an exclusive 0600 file: a search run
    // from inside a user's repository must not touch their tree, and itinerary data on a shared
    // host must not be readable by other users or land on a pre-planted symlink.
    const planOut = planFlag || path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'copa-plan-')), 'plan.json'); let plan = null, planErr = null, claimed = false;
    p.on('response', async r => {
      if (!/ibe\/booking\/plan\?/.test(r.url()) || claimed) return; // one search, one plan: claim synchronously, before the body is awaited
      claimed = true;
      try { plan = await r.text(); } catch (e) { planErr = 'response body unreadable: ' + e.message; return; }
      try { fs.writeFileSync(planOut, plan, { mode: 0o600, flag: 'wx' }); } catch (e) { planErr = 'not saved: ' + e.message; }
    });
    if (!/booking-panel/.test(p.url())) await p.goto('https://shopping.copaair.com/booking-panel', { waitUntil: 'domcontentloaded' }); // only ever a tab connect() just opened
    // Wait for the panel's controls, not for a timer: a tab the launcher just opened can still be
    // rendering its SPA even though its URL already reads booking-panel.
    const ready = await waitUntil(p, async t => /ROUND TRIP/.test(t) || !!(await p.evaluate(() => document.querySelector('iframe[src*="captcha-delivery"]'))), 25000, 1000);
    if (await p.evaluate(() => !!document.querySelector('iframe[src*="captcha-delivery"]'))) throw new Error('DataDome challenge is showing; the user must solve it in the Chrome window first');
    must('booking panel rendered its trip-type controls within 25 s', ready);
    await clickBy(p, /^Accept$/); // cookie banner, optional
    // The panel keeps its trip type across searches, so select it every time.
    log('trip type:', must('trip type button', await clickBy(p, ret ? /^ROUND TRIP$/ : /^ONE WAY$/)));
    // It also keeps the traveler count. Driving that popover is not implemented; verify instead.
    const adults = Number(val('--adults') || 1); const trav = (await p.inputValue('#travelerSelection')).replace(/\s+/g, ' ').trim();
    log('travelers =', trav);
    must(`traveler control reads ${adults} adult(s) with no children/infants (reads ${JSON.stringify(trav)}); set travelers in the Chrome window's panel, then rerun with --adults N`,
      new RegExp(`^${adults} Adults?$`, 'i').test(trav));
    for (const [sel, code] of [['#origin-autocomplete-0', o], ['#destination-autocomplete-0', d]]) {
      await p.click(sel); await p.fill(sel, ''); await p.keyboard.type(code, { delay: 80 }); await sleep(1800);
      let picked = await pickOption(p, new RegExp(`(^|[^A-Z])${code}([^A-Z]|$)`));
      if (!picked) { log(sel, 'options:', await listOptions(p)); await p.keyboard.press('ArrowDown'); await p.keyboard.press('Enter'); picked = '(first option)'; }
      await sleep(500); const val = await p.inputValue(sel); log(sel, '=', val, 'via', picked);
      must(`${sel} contains ${code}`, val.includes(code));
    }
    await p.click('#date-input-0'); await sleep(1200);
    log('depart:', await pickDay(p, dep)); await sleep(700);
    if (ret) { log('return:', await pickDay(p, ret)); await sleep(700); }
    const dates = await p.inputValue('#date-input-0'); log('dates =', dates);
    must(`date input shows ${stamp(dep)}${ret ? ' and ' + stamp(ret) : ''} (got ${JSON.stringify(dates)})`,
      stampRe(dep).test(dates) && (!ret || (stampRe(ret).test(dates) && / - /.test(dates))));
    await clickBy(p, /^(Done|Apply|Confirm|OK)$/); await sleep(400);
    log('search:', must('Search Flights button', await clickBy(p, /^Search Flights/)));
    // The first render often shows "Invalid date" / "Oops! No flights found" for ~10 s before
    // the cards (and the plan API response) arrive, so wait for cards specifically — every card,
    // nonstop or connecting, carries an "Outbound · from" / "Return · from" price line.
    const ok = await waitUntil(p, (t, u) => !/booking-panel/.test(u) && /(Outbound|Return) · from/.test(t), 75000, 3000);
    log('results loaded:', ok, p.url().replace(/\?.*/, ''));
    if (!ok) {
      await cmds.flights({ p });
      const challenged = await p.evaluate(() => !!document.querySelector('iframe[src*="captcha-delivery"]'));
      throw new Error(challenged ? 'no flight cards within 75 s: a DataDome challenge appeared while the results loaded; the user must solve it in the Chrome window, then rerun search'
        : 'no flight cards within 75 s (page above: flexible-search redirect or no availability)');
    }
    for (let i = 0; i < 10 && !claimed; i++) await sleep(1000); // the plan response can trail the render
    for (let i = 0; i < 10 && claimed && !plan && !planErr; i++) await sleep(500); // body still being read
    await cmds.flights({ p });
    if (plan) printPlan(plan, planErr || 'saved to ' + planOut);
    else log(`(no /ibe/booking/plan response captured${planErr ? ': ' + planErr : ''}; fares above are the visible "from" prices only)`);
  },
  async flights({ p }) {
    const t = clean(await body(p)); const s = t.indexOf('Filters'); const e = t.indexOf('Need Help?');
    log(t.slice(0, Math.min(s > 0 ? s : 500, 500)).trim()); log('---- CARDS ----');
    log(t.slice(s > 0 ? s : 0, e > s ? e : undefined).slice(0, 7000));
  },
  async pick({ p }) {
    const [card, fam = 'classic'] = pos; if (!card) throw new Error('usage: pick "CM 296 · CM 880" basic|classic|full|business|business-promo|business-full');
    const famRe = { basic: '^Economic ?Basic fare family', classic: '^Economic ?Classic fare family', full: '^Economic ?Full fare family', business: '^Business.* fare family', 'business-promo': '^Business ?Promo fare family', 'business-full': '^Business ?Full fare family' }[fam];
    const confirmRe = { basic: '^Select Economy Basic', classic: '^Select Economy Classic', full: '^Select Economy Full', business: '^Select Business', 'business-promo': '^Select Business ?Promo', 'business-full': '^Select Business ?Full' }[fam];
    if (!famRe) throw new Error('fare family must be basic|classic|full|business|business-promo|business-full');
    const cabin = /^business/.test(fam) ? '^Business Cabin' : '^Economy cabin';
    // Which leg is being picked decides what "moved on" means below: the outbound pick must
    // reveal the return list, the return pick must reach the summary URL.
    const leg = /Select return flight/.test(await body(p)) ? 'return' : 'outbound';
    // Mark the card's container so the fare-family and confirm clicks stay inside it: another
    // card's panel left open must not be what gets selected.
    const ok = await p.evaluate(([card, cabinRe]) => {
      document.querySelectorAll('[data-copa-pick]').forEach(e => e.removeAttribute('data-copa-pick'));
      const R = new RegExp(cabinRe); const norm = s => s.replace(/\s+/g, ' ').trim();
      const c = [...document.querySelectorAll('*')].find(e => e.children.length === 0 && norm(e.textContent) === norm(card)); // whole string: "CM 29" must not pick "CM 296"
      if (!c) return 'card not found: ' + card;
      let el = c; for (let k = 0; k < 8 && el; k++) { el = el.parentElement; const bs = [...el.querySelectorAll('button,[role="button"]')].filter(b => b.offsetParent && R.test(b.getAttribute('aria-label') || '')); if (bs.length) { el.setAttribute('data-copa-pick', '1'); bs[0].scrollIntoView({ block: 'center' }); bs[0].click(); return bs[0].getAttribute('aria-label'); } }
      return 'no cabin button near card';
    }, [card, cabin]);
    log('cabin:', ok); if (/not found|no cabin/.test(ok)) throw new Error(ok);
    await sleep(2500);
    // Copa renders the fare panel right after the card rather than inside it (observed), so
    // take the first matching button that is inside the marked card or follows it in DOM
    // order but still precedes the NEXT card's cabin buttons: a panel left open on an earlier
    // card precedes the marker, one on a later card sits past that bound, and both are skipped.
    await p.evaluate(() => {
      const anchor = document.querySelector('[data-copa-pick="1"]'); if (!anchor) return;
      const after = b => anchor.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING;
      const next = [...document.querySelectorAll('button,[role="button"]')].find(b => /^(Economy cabin|Business Cabin)/.test(b.getAttribute('aria-label') || '') && !anchor.contains(b) && after(b));
      window.__copaNear = b => anchor.contains(b) || (after(b) && (!next || (b.compareDocumentPosition(next) & Node.DOCUMENT_POSITION_FOLLOWING)));
    });
    const clickNear = re => p.evaluate(r => {
      const R = new RegExp(r, 'i'); const anchor = document.querySelector('[data-copa-pick="1"]'); if (!anchor || !window.__copaNear) return null;
      const t = [...document.querySelectorAll('button,[role="button"]')].find(b => b.offsetParent && (R.test(b.getAttribute('aria-label') || '') || R.test((b.innerText || '').replace(/\s+/g, ' ').trim())) && window.__copaNear(b));
      if (!t) return null; t.scrollIntoView({ block: 'center' }); t.click();
      return (anchor.contains(t) ? '[inside card] ' : '[after card] ') + ((t.getAttribute('aria-label') || t.innerText) || '').replace(/\s+/g, ' ').trim().slice(0, 80);
    }, re);
    const offered = await p.evaluate(() => [...document.querySelectorAll('button,[role="button"]')].filter(b => b.offsetParent && /fare family/i.test(b.getAttribute('aria-label') || '') && window.__copaNear && window.__copaNear(b)).map(b => (b.getAttribute('aria-label') || '').slice(0, 70)));
    log('fares offered:', JSON.stringify(offered));
    const hits = offered.filter(l => new RegExp(famRe, 'i').test(l));
    if (hits.length > 1) throw new Error(`"${fam}" is ambiguous here (${hits.map(h => h.split(' fare family')[0]).join(' / ')}); pass business-promo or business-full`);
    log('expand:', must(`${fam} fare card for ${card} (inside or after it)`, await clickNear(famRe))); await sleep(1500);
    log('confirm:', must(`Select ${fam} button for ${card}`, await clickNear(confirmRe)));
    const ok2 = leg === 'return'
      ? await waitUntil(p, (t, u) => /\/summary/.test(u), 30000, 1500)
      : await waitUntil(p, (t, u) => /Select return flight/.test(t) || /\/summary/.test(u), 30000, 1500);
    must(`page moved on after the ${leg} fare confirm (${leg === 'return' ? 'summary URL' : 'return list or summary'})`, ok2);
    await sleep(1500); const t = clean(await body(p)); log('now:', p.url().replace(/\?.*/, ''));
    log(t.slice(0, 700));
  },
  async summary({ p }) {
    const t = clean(await body(p)); const s = t.indexOf('Your flight itinerary'); log(t.slice(s >= 0 ? s : 0, (s >= 0 ? s : 0) + 3500));
    log('radios:', JSON.stringify(await p.evaluate(() => [...document.querySelectorAll('input[type=radio]')].map(r => ({ name: r.name, checked: r.checked, label: (r.closest('label')?.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 45) })))));
    // `summary "CM 296 · CM 880" "CM 891 · CM 291" classic` asserts the itinerary actually held.
    // A fare family is checked per leg (the fare line under each itinerary line, not the word
    // anywhere on the page: upsell copy names other families too), and there must be at least
    // one parsed leg per flight-number argument, so a missed leg cannot pass silently.
    const legs = parseLegs(t); if (legs.length) log('legs:', JSON.stringify(legs));
    const isFam = w => /^(basic|classic|full|business(-promo|-full)?)$/i.test(w); const isDate = w => /^\d{4}-\d{2}-\d{2}$/.test(w);
    const flightArgs = pos.filter(w => !isFam(w) && !isDate(w)); const dateArgs = pos.filter(isDate);
    if (flightArgs.length) must(`one parsed leg per requested direction (${legs.length} parsed, ${flightArgs.length} requested)`, legs.length >= flightArgs.length);
    // Dates (YYYY-MM-DD) bind to legs in order: the i-th date must be on the i-th itinerary line
    // ("Thu, Oct 8, 2026 · ..."), so a booking that drifted to another day cannot pass.
    dateArgs.forEach((iso, i) => { const [y, m, d] = iso.split('-').map(Number); const shown = `${MONTHS[m - 1].slice(0, 3)} ${d}, ${y}`; must(`leg ${i + 1} is on ${shown} (line: ${legs[i]?.leg || 'missing'})`, !!legs[i] && legs[i].leg.includes(shown + ' ·')); });
    for (const want of pos) {
      if (isDate(want)) continue;
      if (isFam(want)) {
        const re = /^business$/i.test(want) ? /^Business\b/ : new RegExp(`^(Economy )?${want.replace('-', ' ?')}$`, 'i');
        must(`every leg is ${want} (legs: ${legs.map(x => x.fam).join(' / ') || 'none found'})`, legs.length > 0 && legs.every(x => re.test(x.fam)));
      } else must(`summary shows ${JSON.stringify(want)} as a whole flight string`, legs.some(x => flightsRe(want).test(x.leg)));
    }
    if (pos.length) log('summary asserts ok:', pos.join(' | '));
  },
  async continue({ p }) {
    // Fail closed: only the three known pages have a Continue this command may press, and the
    // destination is judged on host + path so a login redirect carrying the expected route in
    // its query string cannot pass.
    const before = p.url(); const exp = NEXT.find(([from]) => from.test(new URL(before).pathname));
    must(`on a page this command knows (summary, traveler-information, checkout); now ${before.replace(/\?.*/, '')}`, !!exp);
    const dest = u => { const x = new URL(u); return x.host + x.pathname; };
    log('clicked:', must('Continue button', await clickBy(p, '^Continue button|^Continue$', 'button')));
    const ok = await waitUntil(p, (t, u) => u !== before && stable(t) && t.length > 400 && exp[1].test(dest(u)), 60000, 2500);
    await sleep(1500); log('url:', p.url());
    log(clean(await body(p)).slice(0, 2500)); const errs = await errors(p); log('errors:', JSON.stringify(errs)); log('CTAs:', JSON.stringify(await ctas(p)));
    must(`landed on ${exp[2]} after Continue (now ${p.url().replace(/\?.*/, '')}; errors: ${errs.join(' | ') || 'none'})`, ok);
  },
  async passenger({ p }) {
    must('on the traveler-information page (url: ' + p.url().replace(/\?.*/, '') + ')', /traveler-information/.test(p.url()));
    // Field ids carry the traveler index (name0, gender0, profile0 ...). Only traveler 1 (index 0)
    // was exercised in the field; contact fields (email, phone) sit on that block.
    const k = Number(val('--traveler') || 1) - 1; if (!Number.isInteger(k) || k < 0) throw new Error('--traveler K counts from 1');
    must(`traveler block #${k + 1} exists on the page (#name${k})`, await p.evaluate(i => !!document.getElementById('name' + i), k));
    const prof = flag('--profile');
    if (prof !== undefined) {
      const idx = prof === true ? 0 : Number(prof) - 1;
      if (!Number.isInteger(idx) || idx < 0) throw new Error('--profile N counts from 1');
      await p.evaluate(i => document.getElementById('filled-auto-populate' + i)?.click(), k); await sleep(800);
      await centerClick(p, `#profile${k}`); await sleep(1500);
      const show = flag('--show-fields') === true;
      const opts = await listOptions(p); log('profiles:', JSON.stringify(opts.map(initials))); // always initials: other saved passengers are not part of the read-back
      const picked = must(`saved passenger #${idx + 1} of ${opts.length} in the profile list`, await p.evaluate(i => { const els = [...document.querySelectorAll('[role="option"], [role="listbox"] li')].filter(e => e.offsetParent && e.innerText.trim()); if (!els[i]) return null; els[i].click(); return els[i].innerText.trim(); }, idx));
      log('profile picked:', show ? picked : initials(picked));
      await sleep(2500);
    } else if (val('--first')) {
      if (!val('--last')) throw new Error('--first needs --last too (a blank surname would only fail at the next step)');
      await p.evaluate(i => document.getElementById('filled-manual' + i)?.click(), k); await sleep(500);
      await p.fill(`#name${k}`, val('--first')); await p.fill(`#surname${k}`, val('--last'));
      if (val('--dob')) { // DD/MM/YYYY; the three comboboxes were not exercised in the field, verify the printed values
        const [dd, mm, yy] = val('--dob').split('/');
        for (const [id, re] of [[`#day${k}`, `^0?${Number(dd)}$`], [`#month${k}`, `^(${MONTHS[Number(mm) - 1]}|0?${Number(mm)})$`], [`#year${k}`, `^${yy}$`]]) { await centerClick(p, id); await sleep(800); log(id, must(`${id} option`, await pickOption(p, re))); await sleep(400); }
      }
      if (val('--email')) { await p.fill(`#email${k}`, val('--email')); await p.fill(`#confirmEmail${k}`, val('--email')); }
    }
    if (val('--gender')) { await centerClick(p, `#gender${k}`); await sleep(900); log('gender:', must('gender option', await pickOption(p, `^${val('--gender')}$`))); await sleep(500); }
    if (val('--cc')) {
      const cc = val('--cc'); const inp = p.locator('input[name="areaCode"]');
      await inp.scrollIntoViewIfNeeded(); await inp.click(); await p.keyboard.press('Control+A'); await p.keyboard.press('Backspace'); await sleep(500);
      await p.keyboard.type(cc.split(' ')[0], { delay: 80 }); await sleep(1500);
      const picked = await pickOption(p, `^${esc(cc)}$`); log('country:', picked);
      if (!picked) { log('  labels containing that code:', JSON.stringify((await listOptions(p)).filter(x => x.startsWith(cc.split(' ')[0] + ' ')).slice(0, 12))); throw new Error(`country label ${JSON.stringify(cc)} not in the picker; pass one of the labels above`); }
      await sleep(500);
    }
    if (val('--phone')) { await p.click(`#phone${k}`); await p.fill(`#phone${k}`, ''); await p.keyboard.type(val('--phone'), { delay: 40 }); await p.keyboard.press('Tab'); await sleep(700); }
    // --show-fields unmasks only what the name/birth-date lock makes the user confirm; email,
    // phone, frequent-flyer, known-traveler and redress numbers stay masked regardless.
    const raw = await fields(p); const show = flag('--show-fields') === true; const confirmable = /^(name|surname|day|month|year)$/;
    log(show ? 'FIELDS (name and birth date in clear for the read-back; the rest masked):' : 'FIELDS (masked; --show-fields to read name and birth date back to the user):', JSON.stringify(Object.fromEntries(Object.entries(raw).map(([k, v]) => [k, show && confirmable.test(k) ? v : mask(k, v)])), null, 1));
    const errs = await errors(p); log('errors:', JSON.stringify(errs));
    if (errs.length) throw new Error('form still shows validation errors: ' + errs.join(' | '));
  },
  async 'seats-skip'({ p }) {
    log('clicked:', must('Go to checkout button', await clickBy(p, '^Go to checkout|Continue to checkout')));
    const ok = await waitUntil(p, (t, u) => /checkout/.test(u) && stable(t) && /Review and Pay|Reservation cost/.test(t), 60000, 3000);
    log('checkout page:', ok, p.url()); log(clean(await body(p)).slice(0, 1500));
    must('checkout page loaded', ok);
  },
  async review({ p }) {
    const pickRadio = re => p.evaluate(r => { const R = new RegExp(r, 'i'); const lab = [...document.querySelectorAll('label')].find(l => R.test(l.innerText)); if (!lab) return null; (lab.querySelector('input[type=radio]') || lab).click(); return lab.innerText.replace(/\s+/g, ' ').trim().slice(0, 60); }, re);
    const optOuts = [['--no-insurance', "No, I don.t want to add travel insurance", 'insurance'], ['--no-carbon', "No, I don.t want to offset", 'carbon offset'], ['--no-miles', 'Do not multiply', 'miles booster']].filter(([f]) => flag(f));
    for (const [, re, what] of optOuts) log(`${what}:`, must(`${what} decline radio`, await pickRadio(re)));
    await sleep(600);
    const radios = await p.evaluate(() => [...document.querySelectorAll('input[type=radio]')].map(r => ({ name: r.name, checked: r.checked, label: (r.closest('label')?.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60) })));
    log('radios:', JSON.stringify(radios.map(r => ({ ...r, label: r.label.slice(0, 45) }))));
    // Clicking is not enough: confirm each requested opt-out is the CHECKED radio before moving on.
    for (const [, re, what] of optOuts) must(`${what} opt-out is checked`, radios.some(r => r.checked && new RegExp(re, 'i').test(r.label)));
    const t = clean(await body(p)); const i = t.indexOf('Reservation cost'); log(t.slice(i >= 0 ? i : 0, (i >= 0 ? i : 0) + 400));
    if (flag('--to-payment')) {
      log('clicked:', must('Continue button', await clickBy(p, '^Continue button', 'button')));
      const ok = await waitUntil(p, (t, u) => /secure\.copaair\.com/.test(u) && /Pay reservation|payment method/i.test(t), 75000, 3000);
      log('payment page reached:', ok, p.url()); log(clean(await body(p)).slice(0, 1200));
      must('payment page (secure.copaair.com) loaded', ok);
      log('STOP: card entry and "Confirm Purchase and Continue" are for the user.');
    }
  },
  async plan() { const f = pos[0]; if (!f) throw new Error('usage: plan <file.json> (search prints the path it saved)'); printPlan(fs.readFileSync(f, 'utf8'), 'from ' + f); },
};

(async () => {
  if (!cmds[cmd]) { const src = fs.readFileSync(__filename, 'utf8').split('\n').slice(1); console.log(src.slice(0, src.findIndex(l => !l.startsWith('//'))).join('\n')); process.exit(2); } // the whole leading comment block, however long it grows
  let ctx = {}; let code = 0;
  try { if (!['plan', 'parse-legs'].includes(cmd)) ctx = await connect({ freshPanel: cmd === 'search' }); await cmds[cmd](ctx); }
  catch (e) { log('ERR', e.message.split('\n')[0]); code = 1; }
  if (ctx.b) await ctx.b.close(); // disconnect; Chrome stays open
  process.exit(code);
})();
