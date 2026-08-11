---
name: multi-reviewer-loop-delegating-edits
description: >-
  Internal companion procedure for safely delegating edits from
  multi-reviewer-loop. Load this exact skill only when multi-reviewer-loop directs
  you here; it is not a standalone review workflow.
user-invocable: false
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Delegating reviewer-loop edits

Use this only after the orchestrator has verified and adjudicated the findings.
It defines how a fresh implementer may edit without damaging pre-existing work.

## Contents

- Why a fresh editor helps
- The adjudicator/implementer responsibility split
- Scope, tool, verification, and concept-sweep requirements
- Four captures: tracked staged/unstaged patches, porcelain status, untracked bytes,
  and explicit path existence
- States that cannot safely be delegated
- The five-step rollback sequence
- Why `git stash create` is not an equivalent snapshot

**The agent that wrote the text is the worst available editor of it.** After a few
passes you stop reading what is on the page and start reading what you meant. Measured
on one long documentation loop: the orchestrator fixing its own artifact introduced
roughly one to two *new* defects per fixing pass across eleven passes — the same claim
corrected in one file and left standing in its twin (ten times), replacements spliced
into the middle of a sentence without re-reading (breaking a list and duplicating a
clause), and absolutes that outran the code. Handed the same kind of findings, a fresh
implementer applied five of them with zero self-inflicted defects and proactively swept
eight sibling occurrences the orchestrator had not been asked about.

Treat that as one trial, not a law — by then the artifact was already much cleaner and
the findings were unusually well specified. The mechanism is probably **freshness plus a
written finding list**, not the particular model: delegating forces you to state each
finding precisely enough for someone else to act on, which by itself kills the vague ones.

**The split that works:**

- **You adjudicate.** Verify each finding against source first. Never hand over a finding
  you have not checked — you would be outsourcing the judgment, not the typing.
- **The implementer edits**, in a fresh context. A fresh context is also an *ignorant*
  one: everything it must not do has to be in the prompt, because none of it is in the
  air. Carry all of:
  - **The scope, named.** The exact paths it may touch and the tools it may use. An
    implementer told only "fix these findings" will range further than you meant, and
    you cannot review what you did not bound.
  - **Verify before fixing.** Findings are hypotheses; one may be wrong. Say so, or a
    fresh agent will treat your list as a work order.
  - **Sweep by concept, not by phrase.** After each fix, search the whole artifact for
    the same claim stated differently.
  - **Read back every passage you splice into** — the whole sentence and its
    neighbours, not the replaced span.
  - **Use the harness edit tool, not `sed -i` or `str.replace`**, which report success
    on zero matches. If an edit must be scripted, assert the target exists before
    replacing, then grep the file for both the new text and the *absence* of the old.
    This is the repo's standing edit contract (`agents-md`), and it does not travel to
    a fresh context on its own.
  - **Add no *unrequested* mechanism** — not "nothing new". A verified finding may
    genuinely require a lock, a validation, or a transaction; what is forbidden is
    anything beyond the finding. Scope conflicts come back to you to adjudicate, not
    resolved by the implementer.
  - Plus your environment guards.
- **Tool-managed state is delegable too — through the tool, never the file.** A ticket
  tracker or database whose on-disk form is a single JSONL line per record is corrupted by
  hand-editing, so the instinct is to keep those findings yourself. Measured: that instinct
  cost more than it saved. The orchestrator's own shell command-substituted the backticks
  in a double-quoted update and silently blanked three field names in a record. Delegating
  the same work with one rule — *use the CLI, never edit the file* — landed clean and the
  database still parsed. Name the tool, forbid the file, and require a read-back.
- **Snapshot first — and non-destructively.** The implementer has write access, and
  [the already-loaded owning skill's § 1.7](../multi-reviewer-loop/SKILL.md#1-preflight) explicitly permits a dirty tree, so plain
  `git` is *not* your undo: `git checkout
  .`, `git stash` and `git reset --hard` each discard the user's pre-existing work along
  with the delegated edit, which [the owning skill's § 1.7](../multi-reviewer-loop/SKILL.md#1-preflight) forbids.

  Capture **four** things before granting access, and require the capture *commands* to
  succeed — never their output to be non-empty, since on a clean tree an empty patch is
  the correct answer:

  - `git diff --cached --binary --no-textconv --no-ext-diff -- <the delegated paths>` and
    `git diff --binary --no-textconv --no-ext-diff -- <the delegated paths>`, as **two**
    patches. `--no-ext-diff` because a configured `diff.external` helper is not disabled by
    `--no-textconv`: measured on git 2.43, a helper emitting `bogus` gave an exit-0 capture
    of non-patch output that could restore nothing. And `-- :(literal)<path>` for each delegated path at
    *capture* time — the `:(literal)` magic matters, because a bare pathspec still globs
    and delegated `a[1].txt` alongside an unrelated dirty `a1.txt` captures both, which
    then aborts the replay on the hunk step 2 left applied. With literal magic the replay
    needs no filtering: `git apply --include` takes a **pattern**, and both a
    bare directory and a literal `a[1].txt` silently match no hunks while exiting 0 — after
    step 2 has already reverted those paths, which turns a rollback into a loss that reports
    success. One combined `git diff HEAD` flattens the layers, so an `MM` path
    comes back ` M` and a later commit carries hunks the user left out. Both flags matter:
    without `--binary` a modified binary records only "Binary files differ" and will not
    apply; `--no-textconv` because the conversion is not what is on disk.
  - `git status --porcelain -z`, NUL-delimited. Porcelain quotes paths that need it, so a
    `cut`-based parse hands back a literal `"caf\303\251.py"` that does not exist. This
    is also what restores **intent-to-add** entries (` A `) afterwards:
    [the owning skill's § 1.6](../multi-reviewer-loop/SKILL.md#1-preflight) `git add
    -N` runs only before the first pass, so a file demoted to `??` during a rollback drops
    out of every later `codex review --base`.
  - a **byte copy of every pre-existing untracked path in scope** — no patch contains
    them. Clear each destination before copying and again before restoring: `cp -pR` into
    an existing directory nests rather than replaces, and exits 0 either way.
  - an **explicit existence list**: which delegated paths exist right now. Porcelain says
    nothing about a clean tracked file, so status-absence is *not* an existence test —
    treating it as one deletes exactly the files that were fine.

  **Refuse the paths this cannot represent.** The recoverable byte state has three parts:
  a staged diff, an unstaged diff, and a byte copy. Porcelain status and the existence
  list are metadata used to restore those parts. Any state that does not round-trip
  through the three byte representations is out of scope for delegation —
  take the path out and say so. Known cases: unmerged paths; either
  endpoint of a **staged rename**, which are one unit (reverting the destination leaves the
  source staged as deleted and the replay then fails); contents inside a dirty submodule;
  anything with a byte-transforming `.gitattributes` entry (`git check-attr --all` —
  `filter`, `text`, `eol`, `working-tree-encoding`); text files under `core.autocrlf`, in **either**
  `true` or `input` — both convert, with no attribute for `check-attr` to report.
  Measured: under `true` a mixed CRLF/LF file replayed as all-CRLF from a patch that
  applied cleanly; under `input` a CRLF worktree against an LF index gave an empty patch
  for a file `git status` called modified, and the rollback then rewrote it to LF;
  and files marked `assume-unchanged`,
  where all three captures *succeed while recording nothing* and the revert then replaces
  the bytes with `HEAD`. That list is the cases known to hit the rule, not the boundary.

  **To roll back**, undo only the delegated paths and rebuild them from the capture, in
  this order — anything else reaches for the destructive commands forbidden above:

  1. **delete the delegated paths the implementer created** — those absent from the
     *existence list*, never those merely absent from porcelain status. A clean tracked
     file has no status entry, so the status test would delete a file that was fine
  2. revert **only** the remaining delegated paths; leave every other path untouched
  3. re-apply the **staged** patch with `git apply --index`, then the **unstaged** one.
     No `--include` is needed or wanted — the patches were already restricted by pathspec
     at capture time, which is the only way to scope them without pattern semantics. Not
     `--cached`: it updates the index
     "without touching the working tree", so the worktree stays at `HEAD` and the unstaged
     patch fails against it — measured, `error: patch failed`, after the original was
     already reverted. Path-restricted capture is also what keeps the replay from touching
     unrelated hunks that step 2 deliberately left applied — replaying those would abort
     the whole patch with `patch does not apply` before any delegated path is restored.
     **Skip an empty patch file** (or pass `--allow-empty`): an
     unstaged-only edit leaves the staged layer empty and `git apply` exits 128 on it —
     after the revert, so the layer holding the user's work is never applied
  4. restore each untracked backup, clearing its destination first
  5. re-run `git add -N` for every path the status snapshot recorded as `" A "` — a leading
     space, then `A`; `"A "` is an ordinary staged addition and must not be re-added

  **`git stash create` cannot replace any of this.** It fails outright on the tree
  [the owning skill's § 1.6](../multi-reviewer-loop/SKILL.md#1-preflight) builds:

  ```console
  $ git stash create
  error: Entry 'café.py' not uptodate. Cannot merge.
  ```

  `git add -N` makes stash refuse outright. And it would not be a drop-in even without
  that: `stash create` takes no `-u`, so an untracked-only tree yields **no stash object at
  all** (measured), and a conflicted index is rejected rather than saved. It handles the
  *tracked-content* cases well — binaries, textconv, index layers — which is the useful
  half of the comparison, not the whole of it. Anyone proposing the swap should reproduce
  the error above first.

This is not `rb-lite`. That loop hands over the whole task and reviews the result; this
hands over *only the edit* for findings you have already verified.
