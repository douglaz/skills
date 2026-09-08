#!/usr/bin/env node
// Generic driver for a real Chrome exposed over CDP (see launch_chrome.sh).
// usage: node cdp.js <cmd> [args]
//   url | text [maxChars] | eval <js> | click <sel> | fill <sel> <val> | type <sel> <val> | wait <sel> | shot <png>
// Env: CDP_URL (default http://127.0.0.1:$CDP_PORT, port 9222 — the same CDP_PORT launch_chrome.sh reads),
//      CDP_MATCH (substring picking the tab, default "copaair")
function chromium() {
  const H = process.env.HOME; const roots = [`${H}/.claude/skills`, `${process.env.CODEX_HOME || H + '/.codex'}/skills`, `${H}/.agents/skills`];
  for (const c of ['playwright-core', 'playwright', ...roots.map(r => `${r}/gstack/node_modules/playwright-core`)]) {
    try { return require(c).chromium; } catch {}
  }
  throw new Error('playwright-core not found: npm i playwright-core, or install gstack under a skills root');
}
(async () => {
  const cdp = process.env.CDP_URL || `http://127.0.0.1:${process.env.CDP_PORT || 9222}`;
  let b;
  try { b = await chromium().connectOverCDP(cdp); }
  catch (e) { console.log(`ERR cannot connect to ${cdp}: ${e.message.split('\n')[0]} — run launch_chrome.sh, or set CDP_PORT/CDP_URL to match it`); process.exit(1); }
  const pages = b.contexts().flatMap(c => c.pages());
  const match = process.env.CDP_MATCH || 'copaair';
  const hits = pages.filter(x => x.url().includes(match));
  let p = hits[0];
  if (hits.length > 1) { // several match: take the most recently active per Chrome's /json order (see copa.js)
    try {
      const ids = await Promise.all(hits.map(async pg => { const s = await pg.context().newCDPSession(pg); const { targetInfo } = await s.send('Target.getTargetInfo'); await s.detach(); return targetInfo.targetId; }));
      const order = (await (await fetch(cdp.replace(/\/$/, '') + '/json')).json()).filter(t => t.type === 'page').map(t => t.id);
      p = hits.map((pg, i) => [order.indexOf(ids[i]), pg]).filter(([r]) => r >= 0).sort((a, b) => a[0] - b[0])[0]?.[1];
    } catch { p = undefined; }
    if (!p) { console.log(`ERR ${hits.length} tabs match ${JSON.stringify(match)} and could not be ranked — set CDP_MATCH to a distinguishing URL fragment`); await b.close(); process.exit(1); }
    console.log(`(${hits.length} tabs match; driving the most recently active: ${p.url().slice(0, 70)})`);
  }
  if (!p) { // never fall back to an arbitrary tab: another debug Chrome on the port would be driven blind
    console.log(`ERR no open tab matches ${JSON.stringify(match)}; tabs: ${pages.map(x => x.url().slice(0, 60)).join(' | ') || '(none)'} — set CDP_MATCH`);
    await b.close(); process.exit(1);
  }
  const [cmd, a1, a2] = process.argv.slice(2);
  let code = 0;
  try {
    if (cmd === 'url') console.log(p.url());
    else if (cmd === 'text') console.log((await p.innerText('body')).replace(/​/g, '').replace(/\n{2,}/g, '\n').slice(0, +a1 || 4000));
    else if (cmd === 'eval') console.log(JSON.stringify(await p.evaluate(a1)));
    else if (cmd === 'click') { await p.click(a1, { timeout: 10000 }); console.log('clicked', a1); }
    else if (cmd === 'fill') { await p.fill(a1, a2, { timeout: 10000 }); console.log('filled', a1); }
    else if (cmd === 'type') { await p.click(a1); await p.keyboard.type(a2, { delay: 40 }); console.log('typed', a1); }
    else if (cmd === 'wait') { await p.waitForSelector(a1, { timeout: 20000 }); console.log('found', a1); }
    else if (cmd === 'shot') { await p.screenshot({ path: a1 }); console.log('saved', a1); }
    else { console.log('unknown cmd; see header of cdp.js'); code = 2; }
  } catch (e) { console.log('ERR', e.message.split('\n')[0]); code = 1; }
  await b.close(); // disconnects only; Chrome keeps running
  process.exit(code);
})();
