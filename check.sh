#!/usr/bin/env bash
set -euo pipefail

./skills/beads-jsonl-path/scripts/resolve-beads-jsonl.test
./install.test
./skills/pr-with-codex-bot-review/scripts/bot-gate.test
./skills/drive/scripts/drive-status.test
