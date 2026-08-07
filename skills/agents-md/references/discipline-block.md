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
git add -- <every path this change touched>   # NOT `git add -A` on a dirty tree: it
git diff --cached                            # sweeps in unrelated work. And READ this:
                                             # on a path that was ALREADY dirty, staging
                                             # it by name still takes the other agent's
                                             # hunks in that same file.
git commit -m "<msg>" || { echo "commit produced nothing"; exit 1; }
# The commit's own file list first — every path you touched, and nothing you did not.
_chk=$(mktemp)
git show --stat --format= HEAD
# Each file that should CONTAIN the change:
for f in <every file you changed that gained or changed content>; do
  git show "HEAD:$f" >"$_chk" 2>/dev/null || { echo "$f did not land"; exit 1; }
  grep -Fq -- "<a distinctive phrase from that file>" "$_chk" || { echo "$f did not land"; exit 1; }
done
# Removal-only edits have no new phrase to find, and any surviving phrase passes even if
# the removal was reverted. Assert the removed text is GONE:
for f in <every file you removed lines from>; do
  # Existence FIRST. `git show HEAD:<gone>` fails, so grep returns nonzero and the `&&`
  # is skipped — an accidental whole-file deletion reads identically to a clean removal.
  git show "HEAD:$f" >"$_chk" 2>/dev/null || { echo "$f is missing from HEAD entirely"; exit 1; }
  _n=$(grep -Fc -- "<a distinctive phrase you deleted>" "$_chk" || true)
  # COUNT, not absence: removing one of several identical lines legitimately leaves
  # the phrase behind, and demanding zero rejects that correct commit.
  [ "${_n:-0}" -eq <occurrences expected AFTER the removal> ] \
    || { echo "$f: expected <n> occurrence(s) of the removed text, found ${_n:-0}"; exit 1; }
done
# Each file the change DELETES is verified by ABSENCE — `git show HEAD:<path>` fails by
# design on a deleted path, so folding deletions into the loop above marks every correct
# deletion as a loss:
for f in <every path the change deletes>; do
  git show "HEAD:$f" >/dev/null 2>&1 && { echo "$f is still present"; exit 1; }
done
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
