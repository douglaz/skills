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
- Keep its constraints, including running every task-required check in full while other tests
  are suspended. Add "Launch models only through cfastlane's reviewer launcher;
  don't start other agents or models."
- Add: "Do all the work this task asks before you stop. End early only for a named obstacle:
  evidence that a requirement cannot be met as written, one specific step with what you tried and
  why each attempt failed, a run or decision reserved for the assistant or the owner, or the
  turn's time limit. Work that merely remains is not an obstacle. On an early stop call no
  reviewers on a partial candidate; write the handoff as partial and name the obstacle. Send contradictions
  within the packet brief to the assistant. Apply the baseline and preexisting-observation rules."
  If the task has its own stop
  condition, write it as one of these obstacles, never as "if X cannot be finished".
- Before Handoff add: "Once the candidate is complete, review it unless the tests-back no-change
  handoff in cfastlane's close-out step applies:
  Read <absolute cfastlane skill path>/SKILL.md for review and wait rules,
  and <absolute fastlane skill path>/references/prompts.md for the exact fixed review template.
  Before each review put the current candidate's required check commands and exits in the handoff.
  Refresh checks a repair can affect before re-review.
  Make the diff with fastlane's make-diff.sh. Fill that template without rewording reviewer
  instructions or P0–P3 lines. On the packet's first round run cfastlane's review.sh PKT
  (it runs the grok probe), wait on every launched required seat with fastlane's wait.sh, and
  judge every finding and use fastlane's round caps. Count three for product code and two each for
  test tooling and tests-back. Each separately committed stage and each failed-live-test repair
  starts at one. Follow fastlane's cap exceptions and disposition. Repair eligible P0/P1 and re-review the delta in
  this turn, retaining earlier findings and follow-ups. For each later launch, including the first
  round of a new stage or a seat retry, use review.sh PKT --out <fresh-output> --tag <fresh-tag>
  [SEAT...]. Never move
  active readers' directories. Wait on every required seat under the --out just launched;
  detect grok and read grok-missing in that same output. Never wait on an earlier round's
  exit files or on fable. Put suspended test-only findings in deferred-tests.md and P2/P3 in followups.md.
  Take owner calls before lowering a reviewer's P0/P1 or leaving a raised P0/P1 open outside the
  cap rule. Finish independent work, look ahead for other owner decisions, and batch the calls with
  a recommendation and evidence for each. Read <PKT>/notes.md if present before each review round,
  each repair and the handoff. Collect and judge every required reader
  you launched before ending, unless that wait would pass the turn's limit."
- Append to Handoff: "Write <PKT>/commit-subject.txt (one line) and <PKT>/commit-body.txt.
  Include the final review and judgement paths, missing seats and any owner call. Leave the
  worktree uncommitted. If partial, name the obstacle and one precise remaining goal; if readers remain active,
  name their units and exit paths so a resume collects them without launching duplicates. End with
  `HANDOFF: complete` or `HANDOFF: partial`."

After the live test passes, lift the task's test ban exactly as fastlane requires and use
`FASTLANE_TESTS=on` for every tests-back resume. Use the no-change handoff in cfastlane's close-out
step if the completed tests-back stage matches the last accepted commit.

## Resume note

```markdown
<Why the last turn ended, in one sentence.> The task and its rules still stand with the corrections
named here. Re-read <PKT>/task.md and any corrected packet files.

<The owner's decision on the session's call, the live failure, or the remaining goal.>
<Next step.> Continue in the same session; reuse what you already learned.
For a complete candidate, call and wait on reviewers, judge, repair and re-review under fastlane's
round caps unless the tests-back no-change handoff applies. Keep the count in the same stage. Follow the task's rules for
notes, named checks and batching owner calls. Stop early only for a named obstacle.
Do not reword the fixed review brief.
```

When the last turn ended partial with no named obstacle, say so in the first sentence, list the
remaining work in order and resume; that needs no owner decision. When it named one, follow the
table in SKILL.md's "Stopping early" before writing the note, even if the build also failed. What
the table sends to the owner gets the owner's result or decision first, and the note carries it;
what it reserves for the assistant, the assistant does first, and the note carries that result.

A review repair names only verified P0/P1 within the cap rule, never P2/P3 or suspended test-only
findings. The session judges; the assistant only relays the calls reserved for the owner.

## Review brief (`PKT/review-brief.md`)

Copy fastlane's review brief verbatim, substituting PKT paths for `iN/` paths. The only additions:

- Under Read, give the paths to `PKT/task.md`, `PKT/handoff.md` and any packet plan or claim
  the task required. Review the uncommitted candidate; do not require a commit or a live receipt.
- The session receives and judges the report, following the owner-call guards above.

Keep fastlane's Report section and severity lines unchanged. For re-review, retain its earlier
findings, delta and listed-follow-ups entries. Use its spec-only variants when applicable.
