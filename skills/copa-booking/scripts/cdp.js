#!/usr/bin/env node
// Generic driver for a real Chrome exposed over CDP (see launch_chrome.sh).
// usage: node cdp.js <cmd> [args]
//   url | text [maxChars] | eval <js> | click <sel> | fill <sel> <val> | type <sel> <val> | wait <sel> | shot <png>
// Env: CDP_URL (http://127.0.0.1:9222), CDP_MATCH (substring picking the tab, default "copaair")
function chromium() {
  for (const c of ['playwright-core', 'playwright', `${process.env.HOME}/.claude/skills/gstack/node_modules/playwright-core`]) {
    try { return require(c).chromium; } catch {}
  }
  throw new Error('playwright-core not found: npm i playwright-core, or install gstack');
}
(async () => {
  const b = await chromium().connectOverCDP(process.env.CDP_URL || 'http://127.0.0.1:9222');
  const pages = b.contexts().flatMap(c => c.pages());
  const p = pages.find(x => x.url().includes(process.env.CDP_MATCH || 'copaair')) || pages[0];
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
