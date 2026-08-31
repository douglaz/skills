#!/usr/bin/env bash
set -euo pipefail

./skills/beads-jsonl-path/scripts/resolve-beads-jsonl.test
./install.test
./skills/pr-with-codex-bot-review/scripts/bot-gate.test
./skills/drive/scripts/drive-status.test

# The record this repo is driven by, checked against the parser that reads it. In the
# 2026-08-30 run the driver wrote a **Baseline:** field that reads as well-formed to a human
# and parsed as nothing, so Guard 2 sat unarmed across three commits and five days while a
# commit titled "arm E3 production budget" said otherwise. Nothing objected, because nothing
# asked. Reads DRIVE.md only — no git, no forge, no network.
./skills/drive/scripts/drive-status --check-record
