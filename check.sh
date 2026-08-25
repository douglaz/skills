#!/usr/bin/env bash
set -euo pipefail

./skills/beads-jsonl-path/scripts/resolve-beads-jsonl.test
./install.test
./skills/pr-with-codex-bot-review/scripts/bot-gate.test
./skills/drive/scripts/drive-status.test
./skills/rb-lite-backlog-drain/scripts/native-close.test
./skills/rb-lite-backlog-drain/scripts/closure-consumers.test
