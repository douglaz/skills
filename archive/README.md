# Archived skills

Nothing under `archive/` is installed by `install.sh` or run by `./check.sh`. It is kept
for reference only.

Archived on 2026-09-17 because the lifecycle machinery grew too complex to keep honest:

- `skills/drive` — the phase-machine meta-skill, its `drive-status` detector and tests
- `skills/orchestrating-with-rb-lite` — rb-lite implement/review loop and harden-until-clean
- `skills/rb-lite-backlog-drain` — the serialized one-bead-per-branch drain
- `skills/testing-with-rb-lite` — rb-lite as a test/gate author with independent runs
- `DRIVE.md`, `docs/adr/`, `docs/specs/` — the last drive record, its ADRs, the E3 plan and probe

The live bead skills (`plan-to-beads-transfer`, `bead-polish-loop`,
`second-model-bead-audit`) still point at the drain skill's step 11 for JSONL recovery;
that text is at `skills/rb-lite-backlog-drain/SKILL.md#backlog-step-11` here.

A replacement approach has not been decided.
