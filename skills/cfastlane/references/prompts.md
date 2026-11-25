# Combined fast-lane prompts

Use [fastlane's task and review templates](../../fastlane/references/prompts.md) as the source.
Everything there applies, including the task's test suspension, exact P0–P3 lines, PRODUCT/TEST
format, spec-only variants and delta-only re-review with earlier findings and listed follow-ups.
Tokens are measured, never limited; add no token cap, checkpoint or reading restriction.

## Task (`PKT/task.md`)

Copy fastlane's task template, changing only these combined-session details:

- Use PKT paths instead of `iN/` paths.
- Prepend: "You are one sol session doing this whole bounded packet: plan, code, build and write
  the handoff. There is no separate manager or implementer. Work in <worktree> and <PKT>; read
  AGENTS.md. A script commits. You call the reviewers and judge their findings in this turn."
- Keep its constraints, including "Tests are suspended. Don't run, fix, edit or add tests,
  fixtures or test scripts." Add "Launch models only through cfastlane's reviewer launcher;
  don't start other agents or models."
- Add: "Do all the work this task asks before you stop. End early only for a named obstacle:
  evidence that a requirement cannot be met as written, one specific step with what you tried and
  why each attempt failed, a run or decision reserved for the assistant or the owner, or the
  turn's time limit. Work that merely remains is not an obstacle. On an early stop call no
  reviewers; write the handoff as partial and name the obstacle." If the task has its own stop
  condition, write it as one of these obstacles, never as "if X cannot be finished".
- Before Handoff add: "Once the candidate is complete:
  Read <absolute cfastlane skill path>/SKILL.md for review and wait rules,
  and <absolute fastlane skill path>/references/prompts.md for the exact fixed review template.
  Make the diff with fastlane's make-diff.sh. Fill that template without rewording reviewer
  instructions or P0–P3 lines. Run cfastlane's review.sh PKT
  (it runs the grok probe), wait on every launched required seat with fastlane's wait.sh, and
  judge every finding as fastlane requires. Repair accepted P0/P1 and re-review the delta in
  this turn, retaining earlier findings and follow-ups. For a failed seat's one retry or a
  re-review, use review.sh PKT --out PKT/review-<round> --tag <fresh-tag> [SEAT...]. Never move
  active readers' directories. Wait on every required seat under the --out just launched;
  detect grok and read grok-missing in that same output. Never wait on an earlier round's
  exit files or on fable. Defer test-only findings and P2/P3.
  A P0/P1 this task already requires you to fix is repaired in this turn, whoever rated it.
  Never lower a reviewer's P0/P1 yourself: end your turn with that call and evidence for the
  owner. Likewise end for the owner if you raise one to P0/P1 and believe it should not or
  cannot be fixed within this task; give the reason. Collect and judge every required reader
  you launched before ending, unless that wait would pass the turn's limit."
- Append to Handoff: "Write <PKT>/commit-subject.txt (one line) and <PKT>/commit-body.txt.
  Include the final review and judgement paths, missing seats and any owner call. Leave the
  worktree uncommitted. If partial, name the obstacle and one precise remaining goal; if readers remain active,
  name their units and exit paths so a resume collects them without launching duplicates. End with
  `HANDOFF: complete` or `HANDOFF: partial`."

After the live test passes, lift the task's test ban exactly as fastlane requires and use
`FASTLANE_TESTS=on` on the resumed session.

## Resume note

```markdown
<Why the last turn ended, in one sentence.> The task in <PKT>/task.md and its rules still stand.

<The owner's decision on the session's call, the live failure, or the remaining goal.>
<Next step.> Continue in the same session; reuse what you already learned.
You still call and wait on reviewers, judge, repair accepted P0/P1 and re-review in this turn,
once the candidate is complete. Stop early only for a named obstacle.
Do not reword the fixed review brief. Never lower a reviewer's P0/P1 yourself; end your turn for
the owner's decision before that, or if you raise one you believe should not or cannot be fixed.
```

When the last turn ended partial with no named obstacle, say so in the first sentence, list the
remaining work in order and resume; that needs no owner decision. When it named one, follow the
table in SKILL.md's "Stopping early" before writing the note: a reserved decision or an unmeetable
requirement gets the owner's decision first, and the note carries it.

A review repair names only verified P0/P1 product findings, never P2/P3 or suspended test-only
findings. The session judges; the assistant only relays the calls reserved for the owner.

## Review brief (`PKT/review-brief.md`)

Copy fastlane's review brief verbatim, substituting PKT paths for `iN/` paths. The only additions:

- Under Read, add any packet plan or claim the task required, and `PKT/handoff.md` as **claims to
  check, not facts**. Review the uncommitted candidate; do not require a commit or a live receipt.
- The session receives and judges the report, following the owner-call guards above.

Keep fastlane's Report section and severity lines unchanged. For re-review, retain its earlier
findings, delta and listed-follow-ups entries. Use its spec-only variants when applicable.
