# The managed discipline block

This is the canonical text the skill writes between
`<!-- agent-discipline-v1 -->` and `<!-- end-agent-discipline -->`.

Two rules govern what may live here:

1. **It must apply to essentially every repo.** Anything language-, tool-, or
   project-specific belongs outside the markers, where a human maintains it.
2. **It must be something an agent gets wrong without being told.** "Write good
   code" is noise. "`sed -i` reports success when it matched nothing" is not —
   it is a specific, load-bearing fact that has silently corrupted real work.

Every line below was added because its absence produced a concrete failure. If a
rule cannot be traced to one, it does not belong here — this block is copied into
every repo, so bloat is expensive and gets ignored wholesale.

`{{GATE}}` is substituted with the repo's real gate command when the skill can
detect one, and the line is dropped when it cannot.

Everything above this marker is commentary for whoever maintains the block. The
text the skill copies starts at the next line and runs to the end of the file.

<!-- BLOCK-START -->

## Working agreement

These rules are here because agents get them wrong by default, not because they
are good general advice.

**Edits must be verified, not assumed.** Prefer your harness's edit tool: it
fails loudly when the target text does not match. `sed -i` and `str.replace()`
do the opposite — a pattern that matches nothing changes nothing, exits 0, and
prints whatever success message you wrote. Batching several edits into one
scripted call is the usual reason this happens, and the saved tool calls are not
worth it. If you do script an edit, assert the target exists before replacing and
make the success message conditional on that assert, then grep the file
afterwards for both the new text and the absence of the old. Prose and markdown
are where this bites hardest: nothing compiles a README, so a silently skipped
edit survives and gets reported as done.

The check does not stop at the file. `nothing to commit, working tree clean` reads
exactly the same whether the work was already committed or was reverted underneath
you by another process holding the tree — so never take that message as proof a
commit happened. Take the exit code instead (`git commit` exits **1** on an empty
commit), and for anything you care about also look inside the commit, since a
partial loss commits cleanly at exit 0:

```
git add -- <every path this change touched>   # not `git add -A`: on a dirty tree it
git diff --cached                            # sweeps in unrelated work — and READ this,
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

A clean `git status` is neither check.

The same tools also corrupt without failing. In a `sed` replacement string `&`
means "the whole match", so substituting a value containing `&&` — any shell
command that chains, which is most of them — silently doubles it and reports
success. Substitute with something that treats the replacement as a literal, and
grep for the result afterwards.

**Never pipe a gate through `tail`, `head`, or `grep`.** A pipeline's exit status
is the last command's, and `tail` always succeeds, so a failing build reports
exit 0. Redirect and capture the real code:

```
<gate> > /tmp/gate.log 2>&1; echo "EXIT=$?"
```

Then read the log. Note the `;` — not `|`.

**"Passing", "clean", "working", "verified", and "done" require a command and an
exit code.** If you cannot show one, say what you actually observed instead. This
is the single most common way an agent reports success it did not have.

**A claim about what a tool does needs a run, not a recollection.** Prose asserting
observable behaviour — an exit code, whether output lands on stdout or stderr, which
versions were tested — is as capable of being wrong as code, and nothing compiles it.
Measured on one documentation branch: five such claims shipped false through eight review
rounds, each sitting beside a **correct** fix, and three were introduced by the commit
fixing the previous one. Every test suite stayed green throughout, because suites do not
read prose. A wrong reason is worse than no reason: it invites the next agent to
"simplify" the guard away, since the stated justification is disprovable in thirty
seconds.

So run it, and record enough that a reader can re-run it and disagree — the command, the
mode if it matters, the version, and what you observed:

```
$ git status --porcelain -- ""          # git 2.54.0
fatal: empty string is not a valid pathspec. please use . instead if you meant
to match all paths
exit 128, nothing on stdout
```

A bare `Measured on git 2.54.0` is greppable but asserts nothing checkable, and "fails
silently" names no version or mode. Neither is a record.

**Observing is not explaining, and only one of them is settled by re-running.** A rerun
gives you the exit code and the streams; it does not tell you *why*. A command can fail
for several config- or environment-dependent reasons, so "X fails because Y" needs more
than a transcript of X failing: vary Y alone and show the outcome change, or cite the
documentation or source. Absent that, write what you saw and leave the cause out — an
invented mechanism beside a correct guard is exactly what gets the guard deleted later.
The mode rider is the cheapest instance — and note it takes *two* runs, not one, because
the second is the counterfactual:

```
$ grep -Fo -- x "" | wc -l ; echo $?                  # bash 5.3.9, GNU grep 3.12
grep: : No such file or directory                     # stderr
0                                                     # stdout, from wc
0                                                     # status
$ set -o pipefail; grep -Fo -- x "" | wc -l ; echo $?
grep: : No such file or directory
0
2
```

Same command, same output, different status — so "the count came back 0 because `wc`
succeeded" is settled only by the pair. One run would have re-blessed the wrong
component.

**A claim you cannot run is not yours to assert.** A version you do not have, a kernel
path you cannot force — say it is unmeasured and narrow it to a possibility. "Behavior
may differ on older git — unmeasured here" costs one word over "behavior differs", and
only one of them is a claim you can be wrong about.

**Reviewers read code; they do not run it.** A clean review — human, bot, or
model — is not a passing build. Run the gate yourself before calling anything
done.

**A test that has never failed has proven nothing.** When you add one for a bug,
watch it go red against the unfixed code first. A test asserting behaviour that
was already correct is indistinguishable from a test asserting nothing.

Three things decide whether that red run means anything. Break the **production
behaviour**, never the test's expected value or its setup — those redden any
assertion, including one that never reaches the behaviour. **Read the failure**: it
must name the assertion pinning what you broke, not an unrelated panic. And run **one
mutation per property** the test claims, since reddening the first of two leaves the
second untested while looking verified. If the test drives anything live — a real
database, a running service, real money — do the red run in a disposable environment
or not at all: a deliberately broken build can perform the harmful operation before
any assertion notices.

Gate for this repo: `{{GATE}}`
