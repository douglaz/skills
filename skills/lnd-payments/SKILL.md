---
name: lnd-payments
description: >-
  Send and receive Bitcoin Lightning payments with an lnd node reached through
  kubectl exec and lncli. Use when the user wants to pay a Lightning/BOLT11
  invoice, decode an invoice or Lightning QR image, create a receive invoice
  optionally as a QR code, generate an onchain (on-chain) bitcoin receive
  address, send bitcoin onchain (on-chain) to an address when Lightning finds no
  route or the recipient wants a chain payment, watch a receive invoice until
  settlement, inspect outgoing payment
  status/fees/routes/preimages, make a shareable proof-of-payment certificate
  (HTML or PNG) for a settled send, or check an lnd node's sync, channel, and
  onchain balance.
  Use for Kubernetes-hosted lnd nodes configured through environment variables
  or XDG config files.
---

# lnd-payments

Operate a Kubernetes-hosted lnd node by exec-ing `lncli` inside the configured
workload. Use `scripts/lnpay` instead of hand-writing `kubectl exec` commands.

Paying an invoice spends real bitcoin and is irreversible. Always decode and
show amount, description, destination, and expiry before sending. The `pay`
command is a dry run until `--yes` is supplied, and so is `sendonchain`.

## Configuration

Keep private node details outside this public skill. Configure the runtime with
environment variables or XDG config files. Effective precedence is:

1. Explicit environment variables.
2. `LNPAY_CONFIG=/path/to/config.env`.
3. `${XDG_CONFIG_HOME:-$HOME/.config}/lnpay/profiles/$LNPAY_PROFILE.env`.
4. `${XDG_CONFIG_HOME:-$HOME/.config}/lnpay/config.env`.

When `LNPAY_CONFIG` is not set, the script loads `config.env` first, then the
selected profile, so profile values can override shared defaults.

Required values:

```bash
LN_CONTEXT=my-kube-context
LN_NAMESPACE=my-lnd-namespace
LN_TARGET=deploy/my-lnd
```

Optional values:

```bash
LN_CONTAINER=lnd
LN_LOCAL_ALIAS=my-node
LNPAY_FEE_LIMIT_PERCENT=0.5
LNPAY_PAY_TIMEOUT=60
LNPAY_TRACK_TIMEOUT=30
LNPAY_WATCH_TIMEOUT=1800
LNPAY_WATCH_INTERVAL=8
```

For compatibility, `LN_DEPLOY=my-lnd` may be used instead of `LN_TARGET`; the
script converts it to `deploy/my-lnd` at that config source's precedence. Prefer
`LN_TARGET` for public examples because it can also point at another Kubernetes
workload form.

Do not store macaroons, TLS keys, kubeconfigs, payment history, invoices, or
preimages in this skill or in public config examples. The config should only
contain selectors that tell `kubectl` where to run `lncli`.

## CLI

Run `scripts/lnpay <command>` using this skill's absolute path. Examples below
use `scripts/lnpay` from the skill directory.

```bash
scripts/lnpay config                    show loaded config, without secrets
scripts/lnpay node                      sync status + channel/onchain balance
scripts/lnpay newaddress [TYPE] [--json] generate an onchain receive address
scripts/lnpay sendonchain <addr> <sats> send onchain, dry-run until --yes
      [--sat-per-vbyte N|--conf-target N] [--label L] [--yes]
scripts/lnpay receive <sats> [--memo M] create an invoice to receive sats
      [--qr PATH] [--ansi] [--expiry S] [--json]
scripts/lnpay decode <bolt11|lightning:...>
                                        show what an invoice will pay
      [--json]
scripts/lnpay decode-qr <image>         read a bolt11 out of a Lightning QR
scripts/lnpay pay <bolt11|lightning:...|@image>
                                        pay invoice, dry-run until --yes
      [--amt S] [--fee-limit N] [--timeout S] [--yes]
scripts/lnpay track <payment_hash|bolt11>
                                        status, fee, preimage, route aliases
      [--timeout S] [--json]
scripts/lnpay watch <payment_hash|bolt11>
                                        poll until a receive invoice settles
      [--timeout S] [--interval S]
scripts/lnpay proof <payment_hash|bolt11>
                                        proof-of-payment certificate
      [--to LABEL] [--html PATH] [--png PATH]
```

The CLI is non-interactive: commands exit non-zero on failure, `--json` returns
`lncli` JSON for `decode`, `track`, and `newaddress`, `receive --json` adds a hex
`payment_hash`, and other commands print key/value lines.

Start by running `scripts/lnpay config` and `scripts/lnpay node` to verify the
configured node is reachable, synced, and has enough balance for the send:
`spendable_local` for Lightning, `onchain_usable` for chain payments.

## On-chain addresses

Use `scripts/lnpay newaddress` to generate a fresh on-chain bitcoin receive
address from the lnd wallet. The address type is an optional positional argument:

- `p2wkh` (default) — native SegWit `bc1q…`, widely compatible.
- `np2wkh` — nested SegWit `3…`, for legacy senders.
- `p2tr` — Taproot `bc1p…`.

Each call returns a new unused address. Add `--json` to pass through the raw
`lncli newaddress` JSON (`{"address": "..."}`) for scripting. This funds the lnd
on-chain wallet (e.g. for opening channels); it does not create a Lightning
invoice — use `receive` for that.

## Sending on-chain

Use `scripts/lnpay sendonchain <address> <sats>` when Lightning is not the right
rail: the payee asked for a chain payment, the amount exceeds outbound channel
liquidity, or `pay` exhausted its routes. Same workflow as `pay`:

1. Run `scripts/lnpay sendonchain <address> <sats>` without `--yes`.
2. Relay the address, amount, feerate, fee estimate, and total.
3. Ask the user to confirm.
4. Re-run with `--yes`, then report the returned `txid`.

The dry run reads and never writes: `lncli estimatefee`, plus `lncli walletbalance`
when a manual feerate is given. It cannot broadcast. `estimatefee` decodes the
address and selects the coins, so an address lnd cannot decode, or an amount the
wallet cannot fund, fails there with exit 1 before `sendcoins` is ever reached.

Amounts are whole satoshis, like everywhere else in this CLI. A BTC-denominated
figure such as `0.00123456` is refused rather than truncated; convert it first
(1 BTC = 100,000,000 sat) and say the sat figure back to the user.

Fees: the default is whatever `--conf-target 6` estimates, and the same target
goes to the broadcast. Every quote is an estimate, not the fee — lnd re-estimates
when it crafts the transaction, and the operator's confirmation sits in between,
so a moving mempool moves the number. Say it to the user as an estimate. Under
`--sat-per-vbyte N` the rate itself is exact and only the quoted total is
approximate, scaled from the estimate's implied vsize. The two flags are mutually
exclusive, and neither accepts 0: to lncli 0 means "unset, pick your own rate".
Amounts and both flags also reject a leading zero, because lncli parses integer
flags with base 0 and would read `0123` as octal 83.

If a low-feerate transaction stalls in the mempool, bump it with
`lncli wallet bumpfee <txid>:<index>` rather than re-sending — the outpoint must
be **your own change output** from that transaction, not the payee's.

Under `--sat-per-vbyte` the dry run settles funding itself, by checking the amount
plus the scaled fee against the spendable on-chain balance. `estimatefee` funds
its request at the conf-target rate, which the broadcast will not use, so it
cannot speak for a manual one in either direction: a high rate would clear the
dry run and then fail inside `sendcoins`, and a low one would be refused for
failing to afford a fee it never pays. The estimate is therefore requested at
`--conf_target 1008`, the lowest rate the estimator quotes, purely to validate
the address and reveal the vsize. A request that cannot be funded even at that
floor rate cannot be funded at any rate, so refusing it there is correct. The
scaled fee is an estimate, so a marginal case can still fail at broadcast.

One known limitation, left in deliberately. If the estimator's 1008-block rate is
*above* the manual rate, a balance sitting between the two totals is refused by
`estimatefee` before the balance check runs. The band is
`vsize x (estimated_rate - requested_rate)` satoshis wide, and it is empty
whenever the two rates match — the 1008-block rate bottoms out at the 1 sat/vB
relay minimum, which is also the lowest `--sat-per-vbyte` accepted, so this needs
a congested mempool and a deliberate underbid. Closing it would mean validating
the address in this script instead of letting lnd do it, which is a second source
of truth about address validity for a band a few hundred satoshis wide. The
failure is a refusal that names insufficient funds, never a wrong send: raise
`--sat-per-vbyte`, or send slightly less.

`--label "<text>"` tags the transaction in lnd's own records, which is worth
doing — it is the only place the reason for the spend is written down. The value
may not start with `-`, so that `--label --yes` is refused instead of taking
`--yes` as the label and quietly downgrading the send to a dry run.

Two things that do not carry over from Lightning. Spendable on-chain balance is
not the channel balance `node` reports as `spendable_local`; read
`onchain_usable`, which already subtracts the anchor-channel reserve lnd keeps
back for force-close fee bumping. And an on-chain payment produces no preimage,
so `proof` cannot certify one — a txid shows that coins moved to an address, not
that a specific invoice was satisfied.

Never hand-write `kubectl exec ... lncli sendcoins`. `lncli` forces the
confirmation prompt off whenever stdout is not a terminal, which it never is
under `kubectl exec`. Such a command broadcasts immediately, with no dry run and
no confirmation. `sendonchain` is the guard.

These claims rest on runs, not recollection. Re-run them like this — streams to
separate files, status captured, so a reader can disagree with the result rather
than with a hand-written label:

```bash
K=(kubectl --context "$LN_CONTEXT" -n "$LN_NAMESPACE" exec "$LN_TARGET" -c lnd -- lncli)
ADDR=31h1vYVSYuKP6AhS86fbRdMw9XHieotbST   # P2SH over an all-zero script hash:
                                          # valid checksum, provably unspendable
"${K[@]}" version >ver.out 2>ver.err; echo "exit=$?"
"${K[@]}" sendcoins --help >help.out 2>help.err; echo "exit=$?"
"${K[@]}" estimatefee '{"notavalidaddress":1000}' --conf_target 6 >bad.out 2>bad.err; echo "exit=$?"
"${K[@]}" estimatefee "{\"$ADDR\":$OVER}" --conf_target 6 >poor.out 2>poor.err; echo "exit=$?"
```

Observed on **lncli v0.21.3-beta** (`ver.out` → `"version": "0.21.3-beta"`), with
`OVER` set to `confirmed_balance + 100000000`:

| run | exit | stdout | stderr |
|---|---|---|---|
| `sendcoins --help` | 0 | 2277 bytes, contains the `--force` line below | 0 bytes |
| `estimatefee` undecodable address | 1 | **0 bytes** | 114 bytes, message below |
| `estimatefee` over-balance amount | 1 | **0 bytes** | 131 bytes, message below |

- `help.out` contains: `--force, -f   if set, the transaction will be broadcast
  without asking for confirmation; this is set to true by default if stdout is
  not a terminal avoid breaking existing shell scripts`.
- `bad.err`: `[lncli] rpc error: code = Unknown desc = decoded address is of
  unknown format`.
- `poor.err`: `[lncli] rpc error: code = Unknown desc = insufficient funds
  available to construct transaction`. This is what makes the dry run fail closed
  on an unfundable amount; `lnpay.test` fakes both refusals.

Both failures put **nothing** on stdout and exit non-zero, which is why
`est="$(lncli estimatefee ...)" || die` is a sound guard rather than a hopeful one.

Rate by conf target — the measurement the floor-rate choice above rests on. Same
address, 250000 sats, run the same way:

```bash
for ct in 1 6 144 1008; do
  "${K[@]}" estimatefee "{\"$ADDR\":250000}" --conf_target "$ct" \
    >"ct$ct.out" 2>"ct$ct.err"; echo "conf_target=$ct exit=$?"
done
```

All four exited 0 with 286 bytes on stdout and **0 bytes on stderr**. From the
`ct*.out` files, on lncli v0.21.3-beta:

| conf_target | 1 | 6 | 144 | 1008 |
|---|---|---|---|---|
| sat_per_vbyte | 2 | 1 | 1 | 1 |
| fee_sat | 324 | 172 | 145 | 145 |

**Re-running this will not reproduce the fees, and should not.** `estimatefee`
selects coins, so `fee_sat` moves with the wallet's UTXO set: an earlier run the
same day, on the same node and amount, returned 305 / 162 / 145 / 145. The design
does not depend on those numbers. It depends on the rate being non-increasing in
the conf target and bottoming at the 1 sat/vB relay floor, which is why 1008 is
asked for when the funding decision has already been delegated to the balance
check. Treat the fee row as a snapshot and the `sat_per_vbyte` row as the claim.

## Receiving

Use `scripts/lnpay receive <sats> --memo "<memo>" --qr /tmp/invoice.png` to
create a receive invoice and QR code. QR generation uppercases the invoice for
compact QR alphanumeric mode, then round-trip verifies the image with `zbarimg`.

For a terminal QR preview, add `--ansi`; when combined with `--json`, the ANSI QR
is written to stderr so stdout stays parseable. lnd's default invoice expiry is
used unless `--expiry <seconds>` is supplied. The displayed `payment_hash` is hex
and can be passed directly to `scripts/lnpay watch`.

## Sending

Invoices can be bare BOLT11 strings for any network (`lnbc`, `lntb`,
`lnbcrt`, etc.), `lightning:` URIs, BIP21 `bitcoin:...?lightning=...` URIs, or
Lightning QR images passed as `@/path/to/image`. Non-BOLT11 QR payloads fail
closed, including LNURL or plain `bitcoin:` address QRs without `lightning=`.

Workflow:

1. Run `scripts/lnpay pay <invoice>` without `--yes`.
2. Relay the decoded amount, description, destination, expiry, and fee ceiling.
3. Ask the user to confirm the decoded invoice and fee ceiling.
4. After confirmation, run `scripts/lnpay pay <invoice> --yes`.
5. After success, run `scripts/lnpay track <invoice>` or
   `scripts/lnpay track <payment_hash>` to verify the settled payment and
   collect actual fee, preimage, payment index, and route aliases.

Amountless invoices require `--amt <sats>`.

The default fee ceiling is `LNPAY_FEE_LIMIT_PERCENT` of the amount — 0.5% unless
configured otherwise — with a floor of 5 sats. This is a maximum, not the
expected fee; well-routed payments land far below it. Report failed attempts
before retrying with a higher `--fee-limit`, and raise it deliberately rather
than by reflex: `FAILURE_REASON_NO_ROUTE` is usually missing liquidity, and the
per-attempt fees in the output show whether the ceiling was ever the binding
constraint.

## Tracking

Use `scripts/lnpay track <payment_hash|bolt11>` when the user asks whether a
payment succeeded, what fee was paid, what preimage was returned, or what route
was used. It wraps `lncli trackpayment --json` and resolves hop aliases via
`getnodeinfo`.

`trackpayment` exposes only `--json` in checked lnd CLI releases; do not pass
`--no_inflight_updates`. `no_inflight_updates` is a router RPC field, not a
documented `lncli trackpayment` flag. `payinvoice`/`sendpayment` expose the
positive `--inflight_updates` flag for send streams when used with `--json`.

When reporting fees, distinguish `fee-limit` from actual `fee_sat`/`fee_msat`.
When reporting a route, include the configured local alias if present, then each
successful HTLC part and each hop alias, with pubkeys/channel IDs when audit
detail is useful.

## Proof of payment

Use `scripts/lnpay proof <payment_hash|bolt11> --to <label> --html out.html --png out.png`
when the user wants a receipt or proof of payment to send someone. It fills
`assets/proof-of-payment.html` from `trackpayment`: amount, fee, settlement time,
route aliases, preimage, payment hash, and the signed invoice. The HTML page
has a button that checks SHA-256(preimage) = payment hash in the viewer's
browser. The PNG is a 2x render of the same page (`#print` mode), with a
shell command for that check instead of the button.

- `--to` labels the recipient, for example the Lightning address the invoice
  came from. lnd doesn't know that address, so without `--to` the certificate
  names the destination node's alias.
- It refuses, exits 1, and writes nothing unless the payment is `SUCCEEDED`,
  the preimage hashes to the payment hash, and there is an invoice. A keysend
  preimage was chosen by the sender, so it proves nothing.
- Node aliases come from the public graph and are HTML-escaped.
- The PNG needs Google Chrome or Chromium on PATH, plus ImageMagick `magick`,
  which is fetched through `nix shell` when missing, like `qrencode`.
- The PNG is rendered in a 4000px-tall viewport. If a payment has so many
  parts that the certificate doesn't fit, `--png` refuses rather than cut it
  off; use `--html` for those.
- The preimage proves the invoice was paid, not who paid it. The sender and
  recipient names on the certificate are labels.

## Watching

Use `scripts/lnpay watch <payment_hash|bolt11> --timeout 1800 --interval 8` to
poll a receive invoice until `SETTLED`, `CANCELED`, expiry, or timeout. Run long
watches in the background rather than blocking the session.

## Dependencies

- `kubectl` with access to the configured context.
- `python3`.
- `qrencode` for QR generation and `zbarimg` for QR decoding; the script uses
  system binaries when available, otherwise it tries `nix shell nixpkgs#...`.
- `timeout` for bounded `trackpayment` calls.
- Google Chrome or Chromium and ImageMagick for `proof --png`.

Offline test: `scripts/lnpay.test` (fake `kubectl`, no node or browser).

## Troubleshooting

- Missing config: run `lnpay config`; set `LN_CONTEXT`, `LN_NAMESPACE`, and
  `LN_TARGET`, or create the XDG config file.
- `exec` fails: verify the Kubernetes target with `kubectl --context
  "$LN_CONTEXT" -n "$LN_NAMESPACE" get pods`.
- Wallet locked or lnd starting: surface that to the user; this skill does not
  hold unlock material.
- `decodepayreq failed`: the invoice may be truncated, wrong-network, expired,
  or the QR may contain a non-Lightning payload.
- Payment stuck or failed with no route: check `lnpay node` for outbound
  balance, then consider a higher explicit `--fee-limit`.
