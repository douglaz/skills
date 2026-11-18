#!/usr/bin/env node
// nopecha-status.mjs — report whether the NopeCHA extension in the VM holds an API key.
// Prints "key: set" or "key: not set" and exits 0; exits 1 when it cannot tell. Never prints the key.
const port = process.env.BROWSER_VM_CDP_PORT || '9333';
const base = `http://127.0.0.1:${port}`;
const fail = (m) => { console.error(`nopecha-key: ${m}`); process.exit(1); };
const targets = async () => JSON.parse(await (await fetch(`${base}/json`).catch(() => fail(`no browser on ${base}. Run \`browser-vm up\` first.`))).text());
const worker = (ts) => ts.find((t) => t.type === 'service_worker' && t.url.startsWith('chrome-extension://') && /\/assets\//.test(t.url));

let t = worker(await targets());
if (!t) {
  // The extension's background worker sleeps when idle; any page load wakes it.
  const page = await (await fetch(`${base}/json/new?https://nopecha.com/`, { method: 'PUT' })).json();
  for (let i = 0; i < 10 && !t; i++) { await new Promise((r) => setTimeout(r, 1000)); t = worker(await targets()); }
  await fetch(`${base}/json/close/${page.id}`);
}
if (!t) fail('the extension\'s background worker is not running (see `browser-vm ssh journalctl -u chromium-cdp -n 30 --no-pager`; `reset-profile` clears a stale one)');

const ws = new WebSocket(t.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; }).catch(() => fail('could not attach to the extension'));
const reply = await new Promise((res) => {
  ws.onmessage = (m) => { const d = JSON.parse(m.data); if (d.id === 1) res(d); };
  ws.send(JSON.stringify({ id: 1, method: 'Runtime.evaluate', params: { awaitPromise: true, returnByValue: true,
    expression: "chrome.storage.local.get('settings').then((s) => typeof s.settings?.key === 'string' && s.settings.key.length > 0)" } }));
});
ws.close();
const v = reply.result?.result?.value;
if (typeof v !== 'boolean') fail('could not read the extension\'s settings');
console.log(v ? 'key: set' : 'key: not set');
process.exit(0);
