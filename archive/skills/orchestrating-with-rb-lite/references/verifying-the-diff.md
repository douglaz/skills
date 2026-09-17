# Verifying and committing the landed diff

Read this at workflow step 10.5, every run. rb-lite leaves its final accepted diff
**uncommitted** and its `clean` is the panel's verdict, not ground truth — so this is
where a run stops being "finished" and starts being *verified*. Covers the five checks
and how to commit the result without losing it.

## Verify the landed diff

The single most important habit when driving rb-lite for real work: **`clean`
means "no surviving reviewer raised a P0/P1/P2," not "correct."** Five things
dogfooding made concrete:

- **The diff is uncommitted.** rb-lite leaves the final accepted changes in the
  working tree (it does not commit on your behalf). Always inspect with `git
  status` / `git diff` and commit the intentional changes yourself — and watch
  for stray scratch files (e.g. a `tmp_*` debug test the implementer created and
  forgot to remove).
- **The panel degrades silently.** The panel succeeds with as few as one exit-0
  reviewer (a missing CLI, an expired/free-tier auth, or an 1800s reviewer
  timeout drops the others). So a `clean` run can rest on a single reviewer's
  read. Confirm the real panel strength in `log.txt` (`round N review panel
  proceeded with partial failures: K of M reviewers succeeded`) and the
  `review-round-*.md` status headers. The thinner the panel, the more the next
  two steps matter.
- **Independent verification is the gate, not the panel.** Re-run the project's
  own contract (its test suites, byte-identical golden/digest checks,
  `fmt`/`clippy`) on the landed diff yourself. For high-stakes or finding-shaped
  work, also run a **separate adversarial result-review** with a second model
  over the committed diff — phrased to attack: *is the result genuine, was
  anything tuned to pass the panel, is the claim honestly scoped?* Treat the
  panel's `clean` as one input into your own PASS decision.
- **Verify the comments, not just the code.** Agent loops can *corrupt a correct
  comment* to placate a reviewer: read every load-bearing correctness/safety/
  invariant comment in the landed diff and confirm each is TRUE per the code —
  following the invariant across files when its guarantee lives outside the diff.
  Then reconcile the **commit message's claims against the shipped comments** (a
  commit that says "conservative lower bound" over a comment that says the opposite
  is a tell). Observed: a reviewer asserted a false out-of-diff fee premise, the
  implementer rewrote a correct invariant docstring to agree, and two more
  reviewers then echoed the corrupted comment — a self-reinforcing loop that only
  broke on reading the unchanged cap code. Tests passing does not catch this;
  reading the claims against the code does.
- **A green suite does not prove the diff is covered.** Re-running gates that
  already passed cannot tell you whether the loop shipped a behavior no test
  pins. For each load-bearing behavior the diff *introduces* — a new invariant,
  an ordering, a clock or lock choice — **invert it in the working tree, confirm
  a test FAILS, then revert.** Read the failure: it has to be *the assertion that
  pins that behavior*, not merely something going red.

  **Isolate the run if the gate touches anything live.** A feature's regression gate
  can drive a real database, a running service, or real funds, and an inverted
  behavior may PERFORM the harmful operation before any assertion notices — the
  mutation is not a dry run. Use a disposable environment, pick a non-destructive
  mutation, or say plainly that the check could not be done safely. Never run a
  deliberately broken build against live state; this applies here and in
  [exact companion skill `rb-lite-backlog-drain`, step 7](../../rb-lite-backlog-drain/SKILL.md#backlog-step-7), not only where
  the deliverable is a test. A behavior mutation can
  trip an initialization error, a panic, or an unrelated assertion long before
  the intended check runs, and taking that as proof of coverage certifies a
  behavior nothing tests. If nothing fails, the loop wrote code the panel
  described and the suite ignores. Observed: a nine-round run ended `clean` with
  every gate green — `fmt`, `clippy -D warnings`, 685 workspace tests, three
  demos, a 16/16 adversarial suite, and CI on a dedicated runner — and swapping a
  single argument at one call site (the mapping anchoring a security deadline)
  still left all 498 lib tests passing. Nine rounds of reading missed it; one
  mutation found it. Keep it scoped to the handful of behaviors the diff
  introduces — each check is one edit, one targeted test, one revert — and treat
  it as the cheapest thing that separates "tests pass" from "tests would notice."

## Committing the accepted diff

**The same prohibition binds you.** An edit made to a tracked file while `codex review`
is running is silently destroyed, and rb-lite runs `codex review` inside every review
round — so for the length of a run the repo is not yours to touch. The loss surfaces as
`nothing to commit, working tree clean` on a commit you expected to carry work, with the
content absent from the file *and* from `HEAD`. Wait for the run to exit before editing
anything, and when you commit the accepted diff, check both things that message hides:

```bash
git add -- <every path this change touched>   # NOT `git add -A`: on a dirty tree that
                                             # stages unrelated work. Even by name, a path
                                             # already dirty brings the other agent's hunks.
git diff --cached                            # read-only review of what you just staged;
                                             # since staging a path that was already
                                             # dirty takes the other agent's hunks too
git commit -m "<msg>" || { echo "commit produced nothing"; exit 1; }
git show --stat --format= HEAD               # all the paths you meant, and only those
```

Then confirm the *content* landed, per file, by the check that fits it — a file that
gained content must contain a distinctive new phrase; a file you removed lines from must
still exist **and** hold the expected remaining count of the deleted phrase; a deleted path
must be absent. A file that BOTH gained and lost content needs both of the first two — the
added phrase passing says nothing about whether the removal survived. One does not
substitute for another, and each has a way to
lie: `grep` defaults to regex (use `-Fq --`), `git show ... | grep` returns 141 under
`pipefail` when grep exits early (capture to a file first), `grep -c` counts lines rather
than occurrences, and demanding *zero* occurrences rejects a correct partial removal.

```bash
_chk=$(mktemp) || { echo "cannot create the scratch file — do NOT report the commit verified"; exit 1; }
trap 'rm -f "$_chk"' EXIT
# ...the three loops, using `grep -Fq --` / `grep -Fo | wc -l || true` on a captured file.
```

`git commit` with nothing staged exits **1**, so the `||` catches a total loss however
reassuring the message reads; the `grep` catches a partial one, which commits cleanly at
exit 0 carrying only some of the change. A clean `git status` is neither check — it reads
identically whether the work was committed or reverted underneath you. Detail, including
the probe design that gives a false all-clear, is in
[multi-reviewer-loop/references/reviewer-panel.md](../../multi-reviewer-loop/references/reviewer-panel.md).
