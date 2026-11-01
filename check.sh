#!/usr/bin/env bash
set -euo pipefail

./install.test
./skills/pr-with-codex-bot-review/scripts/bot-gate.test
./skills/pr-with-codex-bot-review/scripts/pr-watch.test
./skills/copa-booking/scripts/copa.test
./skills/lnd-payments/scripts/lnpay.test
./skills/token-ledger/scripts/token_ledger.test
