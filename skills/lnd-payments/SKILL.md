---
name: lnd-payments
description: >-
  Send and receive Bitcoin Lightning payments with an lnd node reached through
  kubectl exec and lncli. Use when the user wants to pay a Lightning/BOLT11
  invoice, decode an invoice or Lightning QR image, create a receive invoice
  optionally as a QR code, watch a receive invoice until settlement, inspect
  outgoing payment status/fees/routes/preimages, or check an lnd node's sync and
  channel balance. Use for Kubernetes-hosted lnd nodes configured through
  environment variables or XDG config files.
---

# lnd-payments

Operate a Kubernetes-hosted lnd node by exec-ing `lncli` inside the configured
workload. Use `scripts/lnpay` instead of hand-writing `kubectl exec` commands.

Paying an invoice spends real bitcoin and is irreversible. Always decode and
show amount, description, destination, and expiry before sending. The `pay`
command is a dry run until `--yes` is supplied.

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
LNPAY_FEE_LIMIT_PERCENT=2
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
scripts/lnpay node                      sync status + spendable/inbound balance
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
```

The CLI is non-interactive: commands exit non-zero on failure, `--json` returns
`lncli` JSON for `decode` and `track`, `receive --json` adds a hex
`payment_hash`, and other commands print key/value lines.

Start by running `scripts/lnpay config` and `scripts/lnpay node` to verify the
configured node is reachable, synced, and has enough spendable local balance for
sends.

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

The default fee ceiling is `LNPAY_FEE_LIMIT_PERCENT` of the amount, with a floor
of 5 sats. This is a maximum, not the expected fee. Report failed attempts
before retrying with a higher `--fee-limit`.

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
