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

Gate for this repo: `{{GATE}}`
