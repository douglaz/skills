---
name: testing-with-rb-lite
description: >-
  Uses `rb-lite` to AUTHOR a test or verification gate — a unit/integration
  test, a live end-to-end smoke, a benchmark or property check — and then
  INDEPENDENTLY runs and verifies it, because rb-lite's reviewer panel reads the
  test's code but never runs the gate, and a test that falsely reports PASS is
  worse than no test at all. Use whenever the user wants rb-lite (or "codex +
  claude") to write a test, build a smoke or integration gate, add test
  coverage, reproduce a bug in a failing test, or produce a passing live
  verification for a feature — especially high-stakes tests (money code, live
  infra, data-loss paths) where a false green greenlights a lie. Triggers:
  "use rb-lite to test this", "have rb-lite write a smoke/integration test",
  "get a live gate for this via rb-lite", "add coverage with rb-lite", "write a
  test that proves X with codex+claude", "rb-lite a gate for this feature".
  This is for producing and verifying TESTS/GATES; driving a feature
  implementation is `orchestrating-with-rb-lite` instead.
---

## What this skill is, in one paragraph

`rb-lite` can write a good test, but it cannot certify that the test passes. Its
reviewer panel (codex + Claude, per `.rb-lite-reviewers`) reads the test's **code** — it does not
run a live gate, boot a database, stand up a federation, or execute the smoke
against real infrastructure. So a `clean` rb-lite run means "no reviewer
objected to the test's source," not "the test runs and passes." This skill
splits the work along that seam: **rb-lite authors the test; you independently
run and verify it.** The independent run is the gate — not rb-lite's verdict.
The whole reason to be careful here is that a test which falsely reports PASS is
strictly worse than no test: it converts an unverified claim into a green check
that everyone downstream trusts. The job is to make the test *earn* its green.

## Use this skill when

- The user wants rb-lite / "codex + claude" to **write a test, smoke, or
  integration gate** for existing or just-merged code.
- The user wants to **add test coverage** to a change via rb-lite.
- The user wants a **failing test that reproduces a bug** before the fix.
- The user wants a **live end-to-end verification** (a smoke against a real DB,
  a devimint federation, a running service) produced with rb-lite.
- The test is **high-stakes** — money movement, data loss, a security boundary,
  a pre-deploy gate — where you cannot afford a false green.

## Do NOT use this skill when

- The task is to **implement a feature** (the code, not a test for it). That is
  `orchestrating-with-rb-lite`. (A feature task that includes "and add tests" is
  fine there; reach for THIS skill when the deliverable *is* the test/gate.)
- A **single trivial check** the user can run in one command — just run it.
- You **cannot independently run the test** and never will be able to (no
  environment, no fixtures, no live infra, and no plan to get them). Without an
  independent run you cannot gate, so say that plainly rather than shipping a
  test whose green rests only on rb-lite's word.

## Tool dependencies

Same core as `orchestrating-with-rb-lite`: resolve the `rb-lite` binary
(`command -v rb-lite`, else `nix run --refresh github:douglaz/rb-lite -- ...` —
`--refresh` on the session's first invocation is required there and equally required
here, or nix serves an hour-stale cached revision), and have
`codex` + `claude` on PATH and authenticated for the panel. Read that skill's
"Tool dependencies" for the details; they are not repeated here.

**Additionally**, this skill needs whatever the test itself needs to *run*: the
build toolchain, the live environment (a devimint dev-fed, a test DB, a running
gateway), fixtures, and any binaries the test invokes. Confirm you can bring the
test's environment up *before* launching rb-lite — if you can't run the test,
you can't gate it, and you'll have spent a long run producing something you
can't trust. Building/booting the environment once up front also warms caches
and de-risks the run.

## The core principle: rb-lite authors, YOU verify

Hold onto the seam:

- **rb-lite's panel reviews the test's source.** Good for logic, structure,
  missing cases, convention — bad for "does it actually pass." Its `clean` is
  one input, not the gate.
- **Your independent run is the gate.** Run the final test yourself, in a clean
  environment, with freshly built binaries, and read the *real* result markers —
  not the process exit code (a trailing `echo` makes a failed gate exit 0; a
  masked `command not found` exits 127 under a green wrapper). A live gate is
  only verified once *you* have watched it go green end to end.

This is not distrust of rb-lite for its own sake — the panel genuinely catches
real test bugs. It's that the one thing the panel structurally cannot do is the
one thing a test exists to establish.

## The false-PASS traps

These are the specific ways an author (rb-lite or anyone) makes a test that
reports PASS without proving anything. Name each one in the task file as
forbidden, and check for each when you review the result. They are the reason
"watch closely" is the operative instruction for this skill.

- **Stale binaries.** The test runs against a previously built binary, so it
  exercises *old* code and passes on behavior the change already removed. Rebuild
  fresh before every run and reference binaries by explicit path, not a PATH
  copy. This is the single most common false green.
- **Substring / always-true assertions.** `grep 100000` matches `1000000` and
  `0`; `grep -q ok` matches almost anything. Parse a typed value (`--json` +
  `jq`, integer `-eq`) and compare exactly. An assertion that can't fail proves
  nothing.
- **Assertion-weakening to force green.** `|| true` on the check, a slack window
  that swallows the real answer, a looser matcher added the round after the
  strict one failed. If the real behavior doesn't satisfy the strict assertion,
  the test should FAIL loudly — that failure is the test doing its job. A
  genuinely flaky *step* gets a retry; the *assertion* never gets loosened.
- **Fake setup / no proof-of-work.** The test claims to reproduce a condition it
  didn't actually create — "store loss" that never deletes the store, "empty DB"
  that isn't empty, "crash" that didn't crash. Add a proof-of-work assertion:
  before the action, assert the precondition holds (the store is gone, the
  balance is 0, the row is absent) so a later success can only come from the code
  under test, not a leftover.
- **False PASS on a hang or bad exit.** A hung gate killed by a timeout, or a
  setup failure, read as success. End the test with an explicit PASS marker
  reached *only after* the assertions, and check that real marker — not the
  wrapper's exit code.
- **Editing the code under test to pass.** The author changes the very code the
  test is supposed to verify so the test goes green. Forbid it: the test tests
  the merged/target code as-is. A real bug the test surfaces is the test
  SUCCEEDING — report it, don't paper over it. (A genuinely wrong comment the
  test exposes may be corrected, but that carries the same evidence burden as any
  behavior claim, and the code itself stays put.)
- **A gate that has never been red.** Every trap above is a way a test passes
  without proving anything; this is the one check that catches the whole family
  at once, including the ones not on this list. Before you accept a green run,
  break **the production behavior the test exists to detect** — invert the
  invariant in the code under test, or run the gate against the known-defective
  build — and confirm the gate FAILS, then revert. A gate that has only ever been
  observed green is an untested instrument, and reading its source cannot tell you
  whether it can fail: rb-lite's panel reads that source and this is precisely what
  it cannot establish. Report the red run alongside the green one; a PASS with no
  matching FAIL is half the evidence.

  **Break the behavior, never the oracle.** Corrupting the test's own expected
  value, or skipping its setup, turns any assertion red — including one that never
  reaches the target behavior at all. A gate with fake setup or a stale binary
  (the two traps above) will happily fail that way while still being blind to the
  regression you shipped, so the red run would prove exactly nothing. The mutation
  has to be one a real regression could make, and the assertion that fails has to
  be the one that pins the behavior.

## Workflow

1. **Confirm the shape.** The deliverable is a test/gate, and you can run its
   environment. If either isn't true, redirect (to `orchestrating-with-rb-lite`,
   or to "here's why we can't gate this yet").

2. **Find the templates first.** Before writing anything, look for existing
   passing tests of the same kind in the repo (a sibling smoke, a similar
   integration test, the test harness's conventions). Pointing rb-lite at a
   proven template is the biggest single reduction in false-PASS risk — the
   template already handles the environment setup, the reliable ordering, the
   exact-assertion helpers, and the failure diagnostics. "Extend this working
   test" beats "write a new one."

3. **Write a trap-aware task file.** State precisely **what the test must
   PROVE** (the exact property, the exact numbers), point at the template(s) to
   reuse verbatim, embed the false-PASS traps above as hard constraints, and —
   crucially — require the implementer to **actually RUN the test and report the
   real output**, not merely write it and claim it would pass. See the template
   below.

4. **Run rb-lite, capped.** Tests ratchet on nits (a reviewer will always find
   one more edge case in a shell script); cap `--max-rounds` low (say 6) so a
   fractal tail of P3s doesn't burn hours. Give the implementer enough per-round
   timeout for a real environment run (a live smoke can take many minutes).

5. **Watch closely** — this is where the value is:
   - Read the committed test for weak or always-true assertions; confirm the
     strict ones survived the review rounds (the ratchet should *strengthen*
     coverage, never dilute an assertion).
   - Diff the change: it should be **test-only**. A touched non-test file is a
     flag — verify it's a legitimate comment/doc correction, not a code change
     that makes the test pass.
   - Check what findings survived to the cap. P3 script nits are fine; an
     unresolved correctness finding about the test is not.
   - Confirm the implementer actually ran it (real environment output in the
     artifacts), and note whether its run genuinely passed or was claimed.

6. **Independently run it — the gate.** Rebuild fresh, bring the environment up
   yourself, run the final test end to end, and verify the **real** result
   markers. This is the authoritative step; everything before it is preparation.
   If your run reveals a real bug in the code under test, that's the gate
   working — stop and report it.

   **Then run it once more with the thing it detects deliberately broken, and
   watch it FAIL.** Break the **production behavior** in your own scratch copy —
   invert the invariant in the code under test, or run against the known-defective
   build — never the test's expected value and never its setup. Those turn any
   assertion red, including one that never reaches the behavior, so a gate with
   fake setup or a stale binary passes this check while staying blind to the real
   regression. Confirm the gate goes red **for the right reason** (read the failure
   message and check it names the assertion that pins the behavior, not just the
   exit code), then revert. Green proves the test runs. Only the red run proves it
   can tell the difference — and it is the one piece of evidence rb-lite's panel
   structurally cannot supply, since the panel reads the test's source and never
   executes it.

7. **Land the exact verified artifact.** Commit the test *as you verified it*
   (don't apply last-minute cosmetic edits to a money gate without re-verifying —
   commit-what-passed). Report per "Required outputs."

## Required outputs

When you finish, report:

1. The rb-lite binary used and the run's `status` / `exit_code` (from the JSON
   summary line).
2. Rounds completed and the final panel state; note if it hit the cap and what
   (if anything) was left unresolved.
3. **The independent run you did and its real result** — the actual markers you
   checked (the PASS line, the exact assertion values), not the exit code. This
   is the sentence the whole skill exists to let you write truthfully.
4. **The red run** — which *production behavior* you broke to make the gate fail,
   and the failure it printed. Name the behavior, not just "I made it fail": a red
   run from a corrupted expected value or a skipped setup proves nothing. A PASS
   with no matching FAIL is half the evidence, so report both, or say plainly that
   you never saw the gate fail.
5. Any false-PASS trap you caught and corrected (in the test or in your own
   runner).
6. The test artifact path and where it landed (branch/PR).
7. If the gate revealed a real bug, what it was — a bug found here is a success.

## Task file template

```
# Task: <test/gate name>

Produce AND RUN <the test>. It MUST actually pass a real run, not merely be
written — a test that falsely reports PASS is worse than none.

## What the test must PROVE
<the exact property and the exact expected values — e.g. "after X, balance ==
the pre-loss balance EXACTLY (integer equality, zero slack)">.

## Base it on the existing working tests — do NOT invent scaffolding
<point at the sibling template(s); tell the implementer to reuse their setup,
ordering, exact-assertion helpers, and failure diagnostics verbatim>.

## The steps
<numbered, concrete, with the exact commands where known>.

## HARD CONSTRAINTS — the false-PASS traps, each forbidden
- Fresh binaries: rebuild before running; reference by explicit path, never a
  stale PATH copy.
- Exact/typed assertions: parse a value and compare exactly; never a substring
  grep or an always-true check.
- Never weaken an assertion to force green: a real failure is the test working.
  Retry a flaky STEP; never loosen the ASSERTION.
- Real setup, proven: actually create the condition, and assert the precondition
  holds before the action (proof-of-work) so success can't come from a leftover.
- Real PASS marker: reach an explicit PASS only after the assertions; the runner
  checks that marker, not a trailing exit code.
- Do NOT modify the code under test to make the test pass. If the code has a bug,
  report it — do not hide it.
- Prove the gate can fail: after it passes, break the PRODUCTION BEHAVIOR it
  detects (invert the invariant in the code under test, or run against the
  known-defective build) — never the expected value and never the setup, which go
  red without the gate ever reaching the behavior. Show the FAIL and its message,
  confirm it names the assertion that pins the behavior, then revert. A gate never
  observed red is not evidence.

## RUN IT and report the real output
Actually run the test (<the exact runner command / how to bring up the
environment>) and paste the real tail showing the PASS marker, plus the tail of
the deliberately-broken run showing the FAIL. Do NOT claim PASS without the
actual output, and do not claim the gate works on the green run alone.

## Forbidden
- Do NOT run rb-lite, `br`, `gh`, or signal any parent process. Do NOT commit.
```

## Relationship to `orchestrating-with-rb-lite`

That skill is the general implement → review loop and backlog-drain engine; it
already says "trust `clean` as no-objections, not correct" and "verify the
landed diff yourself." This skill is the specialization for when the deliverable
*is* a test or gate: it sharpens "verify yourself" into "independently RUN the
gate and read the real markers," and it front-loads the false-PASS traps that a
test — unlike ordinary code — is uniquely able to hide behind.
