# AGENTS.md

<!-- agent-discipline-v1 -->

## Working agreement

- Verify edits in the resulting diff, including intended additions and removals.
  For scripted replacements, assert the expected matches before writing and use
  literal replacement values.
- Stage only intended changes and inspect the staged diff, including any hunks
  that were already dirty. Check the commit command's exit status and inspect the
  committed content; a clean worktree alone does not prove the change landed.
- Run the complete gate without piping it through an output filter. If capturing
  output, redirect the whole gate to a fresh log, save its status before reading
  the log, and return that status. Use the repository's existing runner when
  timeout or process supervision is needed; keep that machinery out of this file.
- Report the command and observed exit status when claiming work passes, is clean,
  works, is verified or is done.
  Interrupted or incomplete execution is unverified. A clean review is independent
  judgment, not evidence that a build or test ran.
- Support claims about tool behavior with a reproducible command, relevant version
  and mode, and observed result; capture stdout and stderr separately when the
  distinction matters. Label unmeasured claims and distinguish an observed result
  from a cause established by a controlled comparison or documentation.
- For a bug regression test, demonstrate that it catches the bug on unfixed code
  and passes with the fix. Check the failure is the intended assertion, rather
  than setup or an unrelated error. Use a disposable environment for a deliberate
  break that could affect live systems or funds; otherwise report that the red
  run was not performed.

Gate for this repo: `./check.sh`
<!-- end-agent-discipline -->
