#!/usr/bin/env bash
set -euo pipefail

./install.test
./skills/pr-with-codex-bot-review/scripts/bot-gate.test
./skills/drive/scripts/drive-status.test
