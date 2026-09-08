#!/usr/bin/env node
// Copa Airlines booking driver over CDP (real Chrome launched by launch_chrome.sh).
// usage: node copa.js <cmd> [args]
//   status                                         url, DataDome iframe present?, logged-in user
//   search ORIG DEST YYYY-MM-DD [YYYY-MM-DD] [--plan-out f]   booking-panel search; prints cards + fare matrix
//   flights                                        print the visible flight cards
//   pick "CM 296 · CM 880" basic|classic|full|business        select that card's cabin + fare family
//   summary                                        itinerary / PriceLock / total on the summary page
//   continue                                       press the page's main Continue and print what loads
//   passenger [--profile [N]] [--first F --last L --dob DD/MM/YYYY --email E]
//             [--gender Male|Female] [--cc "+1 United States of America"] [--phone 5551234567]
//   seats-skip                                     "Continue to checkout" without seats
//   review [--no-insurance] [--no-carbon] [--no-miles] [--to-payment]   decline extras; optionally go to the pay page
//   plan [file]                                    re-print the fare matrix from a saved plan json
// Env: CDP_URL (http://127.0.0.1:9222), CDP_MATCH (tab url substring, default "copaair")
const fs = require('fs');
const CDP = process.env.CDP_URL || 'http://127.0.0.1:9222';
const MATCH = process.env.CDP_MATCH || 'copaair';
const MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const log = (...a) => console.log(...a);
const sleep = ms => new Promise(r => setTimeout(r, ms));
const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

function chromium() {
  for (const c of ['playwright-core', 'playwright', `${process.env.HOME}/.claude/skills/gstack/node_modules/playwright-core`]) {
    try { return require(c).chromium; } catch {}
  }
  throw new Error('playwright-core not found: npm i playwright-core, or install gstack');
}
const argv = process.argv.slice(2); const cmd = argv.shift();
const fi = argv.findIndex(a => a.startsWith('--'));
const pos = fi < 0 ? argv : argv.slice(0, fi); const rest = fi < 0 ? [] : argv.slice(fi);
const flag = n => { const i = rest.indexOf(n); if (i < 0) return undefined; const v = rest[i + 1]; return v !== undefined && !v.startsWith('--') ? v : true; };

async function connect() {
  const b = await chromium().connectOverCDP(CDP);
  const pages = b.contexts().flatMap(c => c.pages());
  const p = pages.find(x => x.url().includes(MATCH)) || pages[0];
  if (!p) throw new Error('no open tab; run launch_chrome.sh first');
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
// Click the first visible element whose aria-label or text matches re.
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

// Range date picker: click day `iso` in the month whose header ("October 2026") sits above the cell.
// Labels disappear in return mode, so cells are located geometrically, not by aria-label.
async function pickDay(p, iso) {
  const [y, m, d] = iso.split('-').map(Number); const header = `${MONTHS[m - 1]} ${y}`;
  for (let i = 0; i < 14; i++) {
    const r = await p.evaluate(([header, d]) => {
      const vis = e => e.offsetParent !== null;
      const heads = [...document.querySelectorAll('*')].filter(e => vis(e) && e.children.length === 0 && /^[A-Z][a-z]+ \d{4}$/.test(e.textContent.trim())).map(e => ({ t: e.textContent.trim(), y: e.getBoundingClientRect().top }));
      const h = heads.find(x => x.t === header); if (!h) return { heads: heads.map(x => x.t) };
      const next = heads.filter(x => x.y > h.y).map(x => x.y).sort((a, b) => a - b)[0] ?? Infinity;
      const tds = [...document.querySelectorAll('td')].filter(c => vis(c) && c.innerText.trim() === String(d)).map(c => ({ c, y: c.getBoundingClientRect().top })).filter(x => x.y > h.y && x.y < next);
      if (!tds.length) return { heads: heads.map(x => x.t), nocell: true };
      tds[0].c.scrollIntoView({ block: 'center' }); const rc = tds[0].c.getBoundingClientRect();
      return { x: rc.x + rc.width / 2, y: rc.y + rc.height / 2, label: tds[0].c.getAttribute('aria-label') || '' };
    }, [header, d]);
    if (r.x !== undefined) { await p.mouse.click(r.x, r.y); return `${header} ${d} (${r.label.slice(0, 25) || 'cell'})`; }
    if (r.nocell) throw new Error(`day ${d} not clickable in ${header} (past or unavailable?)`);
    const adv = await p.evaluate(() => { const a = [...document.querySelectorAll('[aria-label]')].filter(e => e.offsetParent && /Press enter to go to \w+ days/.test(e.getAttribute('aria-label'))); const last = a[a.length - 1]; if (!last) return null; last.click(); return last.getAttribute('aria-label').slice(0, 30); });
    if (!adv) throw new Error(`${header} not visible (${r.heads.join(', ')}) and no next-month arrow`);
    await sleep(500);
  }
  throw new Error('could not reach ' + header);
}

function summarizePlan(d) {
  const out = [];
  for (const od of d) {
    out.push(`== ${od.originDestinationKey} ${od.origin.code} ${od.origin.departureDate} -> ${od.destination.code}  (${od.currency?.code || ''})`);
    const rows = (od.solutions || []).map(s => {
      const segs = s.flights.map(f => `${f.marketingCarrier.airlineCode}${f.marketingCarrier.flightNumber} ${f.departure.airportCode} ${f.departure.flightTime}→${f.arrival.airportCode} ${f.arrival.flightTime}${f.changeOfDay !== '0' ? '+' + f.changeOfDay : ''}`).join(' / ');
      const lay = s.flights.filter(f => f.layoverTime && f.layoverTime !== '0h0m').map(f => f.layoverTime).join(',');
      const offers = (s.offers || []).map(o => `${o.fareFamily?.code || '?'}=${o.totalPrice ?? o.pricePerAdult}`).join(' ');
      return [s.lowestPriceCoachCabin, `  $${s.lowestPriceCoachCabin} ${s.journeyTime.replace('PT', '')} lay=${lay || '-'} ${segs} | ${offers}`];
    }).sort((a, b) => a[0] - b[0]);
    rows.forEach(r => out.push(r[1]));
    if (od.priceCalendars) out.push('  nearby: ' + od.priceCalendars.map(c => `${c.date}:${c.price}`).join(' '));
  }
  return out.join('\n') + '\nFare codes: BAS=Economy Basic CLS=Economy Classic CLF=Classic Flex EFU=Economy Full PRO=Business Promo BFU=Business Full';
}

const cmds = {
  async status({ p }) {
    const captcha = await p.evaluate(() => !!document.querySelector('iframe[src*="captcha-delivery"]'));
    const user = await p.evaluate(() => document.getElementById('btnMembersLoginBox')?.getAttribute('aria-label') || null);
    log(JSON.stringify({ url: p.url(), captcha, user, title: await p.title() }));
    log(clean((await body(p)).slice(0, 500)));
  },
  async search({ p }) {
    const [o, d, dep, ret] = pos; if (!o || !d || !dep) throw new Error('usage: search ORIG DEST YYYY-MM-DD [YYYY-MM-DD]');
    const planOut = flag('--plan-out') || 'copa-plan.json'; let plan = null;
    p.on('response', async r => { if (/ibe\/booking\/plan\?/.test(r.url())) { try { plan = await r.text(); fs.writeFileSync(planOut, plan); } catch {} } });
    if (!/booking-panel/.test(p.url())) { await p.goto('https://shopping.copaair.com/booking-panel', { waitUntil: 'domcontentloaded' }); await sleep(3500); }
    await clickBy(p, /^Accept$/);
    if (!ret) log('one way:', await clickBy(p, /^ONE WAY$/));
    for (const [sel, code] of [['#origin-autocomplete-0', o], ['#destination-autocomplete-0', d]]) {
      await p.click(sel); await p.fill(sel, ''); await p.keyboard.type(code, { delay: 80 }); await sleep(1800);
      let picked = await pickOption(p, new RegExp(`(^|[^A-Z])${code}([^A-Z]|$)`));
      if (!picked) { log(sel, 'options:', await listOptions(p)); await p.keyboard.press('ArrowDown'); await p.keyboard.press('Enter'); picked = '(first option)'; }
      await sleep(500); log(sel, '=', await p.inputValue(sel), 'via', picked);
    }
    await p.click('#date-input-0'); await sleep(1200);
    log('depart:', await pickDay(p, dep)); await sleep(700);
    if (ret) { log('return:', await pickDay(p, ret)); await sleep(700); }
    log('dates =', await p.inputValue('#date-input-0'));
    await clickBy(p, /^(Done|Apply|Confirm|OK)$/); await sleep(400);
    log('search:', await clickBy(p, /^Search Flights/));
    const ok = await waitUntil(p, (t, u) => !/booking-panel/.test(u) && stable(t) && /CM \d+ · |Oops! No flights|flexible-search/.test(t + u), 75000, 3000);
    log('results loaded:', ok, p.url().replace(/\?.*/, ''));
    await sleep(1500);
    await cmds.flights({ p });
    if (plan) { log('---- FARE MATRIX (from API, saved to ' + planOut + ') ----'); log(summarizePlan(JSON.parse(plan))); }
    else log('(no /ibe/booking/plan response captured; fares above are the visible "from" prices only)');
  },
  async flights({ p }) {
    const t = clean(await body(p)); const s = t.indexOf('Filters'); const e = t.indexOf('Need Help?');
    log(t.slice(0, Math.min(s > 0 ? s : 500, 500)).trim()); log('---- CARDS ----');
    log(t.slice(s > 0 ? s : 0, e > s ? e : undefined).slice(0, 7000));
  },
  async pick({ p }) {
    const [card, fam = 'classic'] = pos; if (!card) throw new Error('usage: pick "CM 296 · CM 880" basic|classic|full|business');
    const cabin = fam === 'business' ? '^Business Cabin' : '^Economy cabin';
    const ok = await p.evaluate(([card, cabinRe]) => {
      const R = new RegExp(cabinRe); const c = [...document.querySelectorAll('*')].find(e => e.children.length === 0 && e.textContent.includes(card));
      if (!c) return 'card not found: ' + card;
      let el = c; for (let k = 0; k < 8 && el; k++) { el = el.parentElement; const bs = [...el.querySelectorAll('button,[role="button"]')].filter(b => b.offsetParent && R.test(b.getAttribute('aria-label') || '')); if (bs.length) { bs[0].scrollIntoView({ block: 'center' }); bs[0].click(); return bs[0].getAttribute('aria-label'); } }
      return 'no cabin button near card';
    }, [card, cabin]);
    log('cabin:', ok); if (/not found|no cabin/.test(ok)) throw new Error(ok);
    await sleep(2500);
    log('fares offered:', JSON.stringify(await p.evaluate(() => [...document.querySelectorAll('button,[role="button"]')].filter(b => b.offsetParent && /fare family/i.test(b.getAttribute('aria-label') || '')).map(b => (b.getAttribute('aria-label') || '').slice(0, 70)))));
    const famRe = { basic: '^Economic ?Basic fare family', classic: '^Economic ?Classic fare family', full: '^Economic ?Full fare family', business: '^Business.* fare family' }[fam];
    const confirmRe = { basic: '^Select Economy Basic', classic: '^Select Economy Classic', full: '^Select Economy Full', business: '^Select Business' }[fam];
    if (!famRe) throw new Error('fare family must be basic|classic|full|business');
    log('expand:', await clickBy(p, famRe)); await sleep(1500);
    log('confirm:', await clickBy(p, confirmRe));
    const ok2 = await waitUntil(p, (t, u) => /summary/.test(u) || /Select return flight/.test(t), 30000, 1500);
    await sleep(1500); const t = clean(await body(p)); log('now:', p.url().replace(/\?.*/, ''), ok2 ? '' : '(no page change detected)');
    log(t.slice(0, 700));
  },
  async summary({ p }) {
    const t = clean(await body(p)); const s = t.indexOf('Your flight itinerary'); log(t.slice(s >= 0 ? s : 0, (s >= 0 ? s : 0) + 3500));
    log('radios:', JSON.stringify(await p.evaluate(() => [...document.querySelectorAll('input[type=radio]')].map(r => ({ name: r.name, checked: r.checked, label: (r.closest('label')?.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 45) })))));
  },
  async continue({ p }) {
    const before = p.url();
    log('clicked:', await clickBy(p, '^Continue button|^Continue$', 'button'));
    const ok = await waitUntil(p, (t, u) => u !== before && stable(t) && t.length > 400, 60000, 2500);
    await sleep(1500); log('url:', p.url(), ok ? '' : '(url unchanged)');
    log(clean(await body(p)).slice(0, 2500)); log('errors:', JSON.stringify(await errors(p))); log('CTAs:', JSON.stringify(await ctas(p)));
  },
  async passenger({ p }) {
    if (!/traveler-information/.test(p.url())) log('warning: not on the traveler-information page:', p.url());
    const prof = flag('--profile');
    if (prof !== undefined) {
      await p.evaluate(() => document.getElementById('filled-auto-populate0')?.click()); await sleep(800);
      await centerClick(p, '#profile0'); await sleep(1500);
      const opts = await listOptions(p); log('profiles:', JSON.stringify(opts));
      const idx = prof === true ? 0 : Number(prof);
      log('profile picked:', await p.evaluate(i => { const els = [...document.querySelectorAll('[role="option"], [role="listbox"] li')].filter(e => e.offsetParent && e.innerText.trim()); if (!els[i]) return null; els[i].click(); return els[i].innerText.trim(); }, idx));
      await sleep(2500);
    } else if (flag('--first')) {
      await p.evaluate(() => document.getElementById('filled-manual0')?.click()); await sleep(500);
      await p.fill('#name0', String(flag('--first'))); await p.fill('#surname0', String(flag('--last') || ''));
      if (flag('--dob')) { // DD/MM/YYYY; the three comboboxes were not exercised in the field, verify the printed values
        const [dd, mm, yy] = String(flag('--dob')).split('/');
        for (const [id, re] of [['#day0', `^0?${Number(dd)}$`], ['#month0', `^(${MONTHS[Number(mm) - 1]}|0?${Number(mm)})$`], ['#year0', `^${yy}$`]]) { await centerClick(p, id); await sleep(800); log(id, await pickOption(p, re)); await sleep(400); }
      }
      if (flag('--email')) { await p.fill('#email0', String(flag('--email'))); await p.fill('#confirmEmail0', String(flag('--email'))); }
    }
    if (flag('--gender')) { await centerClick(p, '#gender0'); await sleep(900); log('gender:', await pickOption(p, `^${flag('--gender')}$`)); await sleep(500); }
    if (flag('--cc')) {
      const cc = String(flag('--cc')); const inp = p.locator('input[name="areaCode"]');
      await inp.scrollIntoViewIfNeeded(); await inp.click(); await p.keyboard.press('Control+A'); await p.keyboard.press('Backspace'); await sleep(500);
      await p.keyboard.type(cc.split(' ')[0], { delay: 80 }); await sleep(1500);
      const picked = await pickOption(p, `^${esc(cc)}$`); log('country:', picked);
      if (!picked) log('  labels containing that code:', JSON.stringify((await listOptions(p)).filter(x => x.startsWith(cc.split(' ')[0] + ' ')).slice(0, 12)));
      await sleep(500);
    }
    if (flag('--phone')) { await p.click('#phone0'); await p.fill('#phone0', ''); await p.keyboard.type(String(flag('--phone')), { delay: 40 }); await p.keyboard.press('Tab'); await sleep(700); }
    log('FIELDS:', JSON.stringify(await fields(p), null, 1)); log('errors:', JSON.stringify(await errors(p)));
  },
  async 'seats-skip'({ p }) {
    log('clicked:', await clickBy(p, '^Go to checkout|Continue to checkout'));
    const ok = await waitUntil(p, (t, u) => /checkout/.test(u) && stable(t) && /Review and Pay|Reservation cost/.test(t), 60000, 3000);
    log('checkout page:', ok, p.url()); log(clean(await body(p)).slice(0, 1500));
  },
  async review({ p }) {
    const pickRadio = re => p.evaluate(r => { const R = new RegExp(r, 'i'); const lab = [...document.querySelectorAll('label')].find(l => R.test(l.innerText)); if (!lab) return null; (lab.querySelector('input[type=radio]') || lab).click(); return lab.innerText.replace(/\s+/g, ' ').trim().slice(0, 60); }, re);
    if (flag('--no-insurance')) log('insurance:', await pickRadio("No, I don.t want to add travel insurance"));
    if (flag('--no-carbon')) log('carbon:', await pickRadio("No, I don.t want to offset"));
    if (flag('--no-miles')) log('miles:', await pickRadio('Do not multiply'));
    await sleep(600);
    log('radios:', JSON.stringify(await p.evaluate(() => [...document.querySelectorAll('input[type=radio]')].map(r => ({ name: r.name, checked: r.checked, label: (r.closest('label')?.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 45) })))));
    const t = clean(await body(p)); const i = t.indexOf('Reservation cost'); log(t.slice(i >= 0 ? i : 0, (i >= 0 ? i : 0) + 400));
    if (flag('--to-payment')) {
      log('clicked:', await clickBy(p, '^Continue button', 'button'));
      const ok = await waitUntil(p, (t, u) => /secure\.copaair\.com/.test(u) && /Pay reservation|payment method/i.test(t), 75000, 3000);
      log('payment page reached:', ok, p.url()); log(clean(await body(p)).slice(0, 1200));
      log('STOP: card entry and "Confirm Purchase and Continue" are for the user.');
    }
  },
  async plan() { log(summarizePlan(JSON.parse(fs.readFileSync(pos[0] || 'copa-plan.json', 'utf8')))); },
};

(async () => {
  if (!cmds[cmd]) { console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(1, 16).join('\n')); process.exit(2); }
  let ctx = {}; let code = 0;
  try { if (cmd !== 'plan') ctx = await connect(); await cmds[cmd](ctx); }
  catch (e) { log('ERR', e.message.split('\n')[0]); code = 1; }
  if (ctx.b) await ctx.b.close(); // disconnect; Chrome stays open
  process.exit(code);
})();
