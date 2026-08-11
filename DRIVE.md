# DRIVE — keep shared skills fully loadable in Tau

**Scope:** keep each top-level `SKILL.md` inside Tau's 64 KiB source-prefix limit
and each folded description inside its 1,024-byte limit. Move long procedural detail
into exact-name companion skills without changing the workflow, then pin both limits
in `install.test`.
**Phase:** HARDEN · **Bead:** n/a (direct repository-maintenance change)
· **Branch:** `fix/tau-skill-limits`
**Pending:** —
**Gate:** `./install.test && ./skills/pr-with-codex-bot-review/scripts/bot-gate.test && ./skills/drive/scripts/drive-status.test`
· run 2026-08-10 on the working tree based at `ffe024ff93a6e7a6a40c87f8e49ed3888f95cb24`
with bash 5.3.15: `passed 25, failed 0` / `passed 124, failed 0` /
`passed 70, failed 0`, each exit 0.

## Done

- Measured Tau 0.1.0's raw 65,536-byte skill-source prefix and 1,024-byte description
  bounds against the implementation in `~/p/tau`.
- Extracted the long procedures from `multi-reviewer-loop`,
  `orchestrating-with-rb-lite`, and `pr-with-codex-bot-review` into required companion
  skills while retaining the entry points and stable recovery anchors in their main
  skills. Exact companion names work with Tau's source-opaque skill loader and avoid
  selecting a different duplicate installation through process-local filesystem state.
- Shortened oversized descriptions and added dependency-free compatibility checks.
- Mutation-tested over-limit, missing-skill, unsupported-description, and broken-link
  failures; separately verified ignored workspace directories are excluded from the
  skill inventory.
- Ran iterative independent Codex and Opus review and addressed the accepted findings.

## Now

Require one clean parallel reviewer confirmation plus the review loop's consistency
pass on the amended tree.

## Next

Commit the reviewed tree, push `fix/tau-skill-limits`, and open the PR with the local
gate and reviewer evidence.

## Open questions for the human

None.
