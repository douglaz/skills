#!/usr/bin/env node
// tab.mjs — drive one tab of the VM's Chromium over the DevTools protocol.
// No dependencies: needs Node 22+ (global fetch and WebSocket).
//
// usage: browser-vm tab [--tab NAME] <command> [args]
//
//   open [URL]            new tab (replaces a tab of the same NAME); prints the URL and title it landed on
//   goto URL              navigate the current tab; prints the URL and title
//   url                   print the tab's full URL and title
//   text [SELECTOR]       visible text of the page or of one element (first 6000 chars; --max N)
//   elements              list inputs, buttons and links you can act on
//   eval EXPR             evaluate JavaScript in the page, print the JSON result (promises are awaited)
//   click TARGET          click a CSS selector if TARGET is one that matches, else the first visible
//                         control whose label equals (or, failing that, contains) TARGET; waits for
//                         the page to settle and prints what was clicked and where the tab is now
//   fill SELECTOR [TEXT]  focus the field, replace its value; with --stdin the text is read from stdin
//   type [TEXT]           type into whatever has focus; with --stdin the text is read from stdin
//   key NAME              press Enter, Tab, Escape, Backspace, ArrowDown or ArrowUp
//   wait TARGET [SECS]    wait until a selector or a piece of text is on the page (default 30 s)
//   shot FILE.png         screenshot of the visible viewport; add --full for the whole page
//   tabs                  list open pages (origin and path only)
//   close                 close the tab
//
// A native dialog is answered at once and reported on stderr: alert and beforeunload are accepted,
// confirm and prompt are dismissed. A browser that stops answering fails the command after 30 s.
//
// Use --stdin for anything secret: a password given as an argument is visible in the process list.
// The tab id is remembered per NAME (default "main") under $BROWSER_VM_STATE/tabs, so successive
// calls act on the same tab. Exit status: 0 ok, 1 the action failed, 2 usage.

import { readFileSync, writeFileSync, mkdirSync, existsSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const SRC = readFileSync(new URL(import.meta.url), 'utf8').split('\n').slice(1);
const HELP = SRC.slice(0, SRC.findIndex((l) => !l.startsWith('//'))).map((l) => l.replace(/^\/\/ ?/, '')).join('\n');

const KEYS = { Enter: 13, Tab: 9, Escape: 27, Backspace: 8, ArrowDown: 40, ArrowUp: 38 };
const COMMANDS = ['open', 'goto', 'url', 'text', 'elements', 'eval', 'click', 'fill', 'type', 'key', 'wait', 'shot', 'tabs', 'close'];

function usage(msg) {
  if (msg) console.error(`tab: ${msg}`);
  console.error(HELP);
  process.exit(2);
}
function fail(msg) {
  console.error(`tab: ${msg}`);
  process.exit(1);
}

// ---- arguments ------------------------------------------------------------
const argv = process.argv.slice(2);
const flags = { tab: 'main', stdin: false, full: false, max: 6000 };
const rest = [];
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--tab') flags.tab = argv[++i] ?? usage('--tab needs a name');
  else if (a === '--max') flags.max = Number(argv[++i]) || usage('--max needs a number');
  else if (a === '--stdin') flags.stdin = true;
  else if (a === '--full') flags.full = true;
  else rest.push(a);
}
const [cmd, arg, arg2] = rest;
if (!cmd || cmd === 'help' || cmd === '-h' || cmd === '--help') { console.log(HELP); process.exit(0); }
if (!COMMANDS.includes(cmd)) usage(`unknown command: ${cmd}`);
if (!/^[A-Za-z0-9._-]+$/.test(flags.tab)) usage('tab names use letters, digits, dot, dash and underscore');
if (cmd === 'key' && !(arg in KEYS)) usage(`key must be one of: ${Object.keys(KEYS).join(', ')}`);
if (['goto', 'eval', 'click', 'wait', 'shot'].includes(cmd) && !arg) usage(`${cmd} needs an argument`);
if (cmd === 'fill' && !arg) usage('fill needs a selector');
if (cmd === 'fill' && arg2 === undefined && !flags.stdin) usage('fill needs TEXT or --stdin');
if (cmd === 'type' && arg === undefined && !flags.stdin) usage('type needs TEXT or --stdin');

const port = process.env.BROWSER_VM_CDP_PORT || '9333';
const base = `http://127.0.0.1:${port}`;
const stateDir = process.env.BROWSER_VM_STATE || join(process.env.XDG_STATE_HOME || join(homedir(), '.local/state'), 'browser-vm');
const tabsDir = join(stateDir, 'tabs');
const idFile = join(tabsDir, flags.tab);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function http(path, init) {
  try {
    const r = await fetch(base + path, init);
    return await r.text();
  } catch {
    fail(`no browser on ${base}. Run \`browser-vm up\` first (or check \`browser-vm status\`).`);
  }
}
const listTargets = async () => JSON.parse(await http('/json')).filter((t) => t.type === 'page');

// ---- commands that need no attached tab -------------------------------------
if (cmd === 'tabs') {
  // Origin and path only: a query string or fragment can carry a secret.
  const bare = (u) => { try { const x = new URL(u); return x.origin === 'null' ? x.protocol + x.pathname : x.origin + x.pathname; } catch { return '(unparsed)'; } };
  for (const t of await listTargets()) console.log(`${t.id}\t${bare(t.url).slice(0, 120)}\t${t.title.slice(0, 60)}`);
  process.exit(0);
}

let tid = existsSync(idFile) ? readFileSync(idFile, 'utf8').trim() : null;
if (cmd === 'open') {
  if (tid) await http(`/json/close/${tid}`);
  const t = JSON.parse(await http('/json/new?about:blank', { method: 'PUT' }));
  tid = t.id;
  mkdirSync(tabsDir, { recursive: true });
  writeFileSync(idFile, tid);
}
if (!tid) fail(`no tab named "${flags.tab}" yet. Start with: browser-vm tab --tab ${flags.tab} open URL`);
if (cmd === 'close') {
  await http(`/json/close/${tid}`);
  rmSync(idFile, { force: true });
  process.exit(0);
}

const target = (await listTargets()).find((t) => t.id === tid);
if (!target) {
  rmSync(idFile, { force: true });
  fail(`tab "${flags.tab}" is gone (browser restarted or tab closed). Open it again.`);
}

// ---- CDP session ------------------------------------------------------------
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('websocket')); }).catch(() => fail('could not attach to the tab'));
let seq = 0;
const pending = new Map();
// A native dialog (alert, confirm, prompt, beforeunload) freezes the page: every evaluate would
// wait on it forever. Answer it at once and say so. alert and beforeunload are accepted (there is
// nothing to decide, and refusing a beforeunload would silently cancel the navigation asked for);
// confirm and prompt are dismissed, because accepting one can approve something the caller never
// saw.
const dialogs = [];
function answerDialog(type, message) {
  const accept = type === 'alert' || type === 'beforeunload';
  dialogs.push(`dialog (${type}) "${String(message || '').slice(0, 120)}" was ${accept ? 'accepted' : 'dismissed'}`);
  ws.send(JSON.stringify({ id: ++seq, method: 'Page.handleJavaScriptDialog', params: { accept } }));
}
ws.onmessage = (m) => {
  const d = JSON.parse(m.data);
  if (d.method === 'Page.javascriptDialogOpening') answerDialog(d.params.type, d.params.message);
  if (d.id && pending.has(d.id)) { pending.get(d.id)(d); pending.delete(d.id); }
};
// No call may wait forever: a browser that stops answering is a failure to report, not a hang.
const send = (method, params = {}, timeoutMs = 30000) => new Promise((res) => {
  const id = ++seq;
  const timer = setTimeout(() => { pending.delete(id); fail(`the browser did not answer ${method} within ${timeoutMs / 1000}s`); }, timeoutMs);
  pending.set(id, (d) => { clearTimeout(timer); res(d); });
  ws.send(JSON.stringify({ id, method, params }));
});

async function evaluate(expression, timeoutMs) {
  const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }, timeoutMs);
  if (r.error) return { error: r.error.message };
  if (r.result.exceptionDetails) {
    const e = r.result.exceptionDetails;
    return { error: e.exception?.description || e.text };
  }
  return { value: r.result.result.value };
}
// A navigation can destroy the execution context under an evaluate; retry briefly.
async function evalRetry(expression, tries = 5) {
  let r;
  for (let i = 0; i < tries; i++) {
    r = await evaluate(expression);
    if (!r.error || !/context|navigat|Target closed/i.test(r.error)) return r;
    await sleep(700);
  }
  return r;
}
async function settle(ms = 1500) {
  await sleep(ms);
  for (let i = 0; i < 20; i++) {
    const r = await evaluate('document.readyState');
    if (r.value === 'complete' || r.value === 'interactive') return;
    await sleep(500);
  }
}
function stdinText() {
  const t = readFileSync(0, 'utf8').replace(/\r?\n$/, '');
  if (!t) fail('--stdin was given but stdin was empty');
  return t;
}

// Finds an element by CSS selector, else by visible text / label / placeholder, in the page.
const FIND = `(q) => {
  let el = null;
  try { el = document.querySelector(q); } catch (e) {}
  if (!el) {
    const norm = (s) => (s || '').replace(/\\s+/g, ' ').trim().toLowerCase();
    const want = norm(q);
    const label = (e) => norm(e.innerText || e.value || e.getAttribute('aria-label') || e.getAttribute('placeholder') || e.getAttribute('title'));
    const visible = (e) => { const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0; };
    const pool = [...document.querySelectorAll('button, a, [role=button], [role=link], [role=tab], [role=menuitem], input, textarea, select, label, summary')].filter(visible);
    el = pool.find((e) => label(e) === want) || pool.find((e) => label(e).includes(want));
  }
  return el;
}`;

async function locate(q) {
  const r = await evalRetry(`(() => { const el = (${FIND})(${JSON.stringify(q)}); if (!el) return null;
    el.scrollIntoView({ block: 'center', inline: 'center' }); const r = el.getBoundingClientRect();
    const label = (el.innerText || el.value || el.getAttribute('aria-label') || el.getAttribute('placeholder') || '').replace(/\\s+/g, ' ').trim().slice(0, 50);
    return { x: r.x + r.width / 2, y: r.y + r.height / 2, tag: el.tagName.toLowerCase(), label: el.type === 'password' ? '' : label }; })()`);
  if (r.error) fail(r.error);
  return r.value;
}
async function clickAt(p) {
  for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) {
    await send('Input.dispatchMouseEvent', { type, x: p.x, y: p.y, button: 'left', clickCount: 1 });
  }
}

await send('Page.enable');
// A dialog that was already open when this command attached raised its event before we listened.
// Dismiss it; "no dialog is showing" is the normal answer and is ignored.
{
  const r = await send('Page.handleJavaScriptDialog', { accept: false });
  if (!r.error) dialogs.push('a dialog left open by an earlier step was dismissed');
}
await send('Page.bringToFront');

// Where the tab is now, without the query string or fragment (either can carry a secret).
async function where() {
  const r = await evalRetry('JSON.stringify({ url: location.origin + location.pathname, title: document.title })');
  return r.value ?? '{}';
}

let out = '';
switch (cmd) {
  case 'open':
  case 'goto': {
    const url = cmd === 'open' ? (arg || process.env.BROWSER_VM_URL || 'about:blank') : arg;
    const r = await send('Page.navigate', { url });
    if (r.result?.errorText) fail(`navigation failed: ${r.result.errorText}`);
    await settle(2500);
    out = await where();
    break;
  }
  case 'url': {
    const r = await evalRetry('JSON.stringify({ url: location.href, title: document.title })');
    out = r.value ?? fail(r.error);
    break;
  }
  case 'text': {
    const r = await evalRetry(arg
      ? `(() => { const el = (${FIND})(${JSON.stringify(arg)}); return el ? el.innerText : null; })()`
      : 'document.body.innerText');
    if (r.error) fail(r.error);
    if (r.value === null) fail(`nothing matches: ${arg}`);
    out = String(r.value).replace(/\n{3,}/g, '\n\n').slice(0, flags.max);
    break;
  }
  case 'elements': {
    const r = await evalRetry(`(() => {
      const vis = (e) => { const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0; };
      const t = (s) => (s || '').replace(/\\s+/g, ' ').trim().slice(0, 60);
      const rows = [];
      for (const e of document.querySelectorAll('input, textarea, select')) if (vis(e) && e.type !== 'hidden')
        rows.push('field   ' + e.tagName.toLowerCase() + (e.type ? '[type=' + e.type + ']' : '') + (e.name ? '[name=' + e.name + ']' : '') + (e.id ? '#' + e.id : '') + '  ' + t(e.getAttribute('placeholder') || e.getAttribute('aria-label')));
      for (const e of document.querySelectorAll('button, [role=button], input[type=submit]')) if (vis(e))
        rows.push('button  ' + (t(e.innerText || e.value || e.getAttribute('aria-label')) || '(no label)'));
      const links = [...document.querySelectorAll('a[href]')].filter(vis);
      for (const e of links.slice(0, 40)) rows.push('link    ' + (t(e.innerText) || '(no text)') + '  -> ' + e.href.slice(0, 90));
      if (links.length > 40) rows.push('... ' + (links.length - 40) + ' more links');
      const frames = [...document.querySelectorAll('iframe')].filter(vis);
      for (const e of frames) rows.push('iframe  ' + (e.src || e.title || '').slice(0, 90));
      return rows.join('\\n');
    })()`);
    out = r.value ?? fail(r.error);
    break;
  }
  case 'eval': {
    // The caller's own expression may legitimately wait (polling for a token, say): ten minutes.
    const r = await evaluate(arg, 600000);
    if (r.error) fail(r.error);
    out = typeof r.value === 'string' ? r.value : JSON.stringify(r.value);
    break;
  }
  case 'click': {
    const p = await locate(arg);
    if (!p) fail(`nothing to click matches: ${arg}. Run \`browser-vm tab elements\` to see what is there.`);
    await clickAt(p);
    await settle();
    out = `clicked <${p.tag}>${p.label ? ` "${p.label}"` : ''}; now at ${await where()}`;
    break;
  }
  case 'fill': {
    const text = flags.stdin ? stdinText() : arg2;
    const p = await locate(arg);
    if (!p) fail(`no field matches: ${arg}. Run \`browser-vm tab elements\` to see what is there.`);
    await clickAt(p);
    // Focus the field itself: a popup or a CAPTCHA frame can take focus right after the click,
    // and the text would then go somewhere else.
    const focus = await evaluate(`(() => { const el = (${FIND})(${JSON.stringify(arg)}); if (!el) return 'gone';
      if (el.disabled || el.readOnly) return 'the field is disabled or read-only';
      el.focus(); if (el.select) el.select(); return document.activeElement === el ? 'ok' : 'something else on the page holds the focus'; })()`);
    if (focus.value !== 'ok') fail(`could not fill ${arg}: ${focus.value ?? focus.error}`);
    await send('Input.insertText', { text });
    const check = await evaluate(`(() => { const el = (${FIND})(${JSON.stringify(arg)}); return el && 'value' in el ? el.value.length : -1; })()`);
    if (check.value !== -1 && check.value !== text.length) fail(`the field holds ${check.value} characters after typing ${text.length}; it may reformat or reject input`);
    out = `filled ${text.length} characters`;
    break;
  }
  case 'type': {
    const text = flags.stdin ? stdinText() : arg;
    await send('Input.insertText', { text });
    out = `typed ${text.length} characters`;
    break;
  }
  case 'key': {
    for (const type of ['keyDown', 'keyUp']) {
      await send('Input.dispatchKeyEvent', { type, key: arg, code: arg, windowsVirtualKeyCode: KEYS[arg], ...(arg === 'Enter' && type === 'keyDown' ? { text: '\r' } : {}) });
    }
    await settle();
    out = `pressed ${arg}`;
    break;
  }
  case 'wait': {
    const secs = Number(arg2) || 30;
    const deadline = Date.now() + secs * 1000;
    let found = false;
    while (Date.now() < deadline) {
      const r = await evaluate(`(() => { const q = ${JSON.stringify(arg)}; let el = null; try { el = document.querySelector(q); } catch (e) {}
        return !!el || document.body.innerText.toLowerCase().includes(q.toLowerCase()); })()`);
      if (r.value === true) { found = true; break; }
      await sleep(1000);
    }
    if (!found) fail(`"${arg}" did not appear within ${secs}s`);
    out = 'found';
    break;
  }
  case 'shot': {
    const r = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: flags.full });
    if (!r.result?.data) fail('screenshot failed');
    writeFileSync(arg, Buffer.from(r.result.data, 'base64'));
    out = `saved ${arg}`;
    break;
  }
}
console.log(out);
for (const d of dialogs) console.error(`tab: ${d}`);
ws.close();
process.exit(0);
