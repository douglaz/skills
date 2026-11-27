#!/usr/bin/env bash
set -euo pipefail

./install.test
./skills/pr-with-codex-bot-review/scripts/bot-gate.test
./skills/pr-with-codex-bot-review/scripts/gate-and-merge.test
./skills/pr-with-codex-bot-review/scripts/pr-watch.test
./skills/copa-booking/scripts/copa.test
./skills/browser-vm/scripts/browser-vm.test
./skills/lnd-payments/scripts/lnpay.test
./skills/token-ledger/scripts/token_ledger.test
./skills/pdf-to-kindle-epub/scripts/pdf2epub.test
./skills/fastlane/scripts/fastlane.test
./skills/fastlane/scripts/decision-panel.test
./skills/cfastlane/scripts/cfastlane.test
