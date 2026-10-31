# Sol manager live check

The record behind SKILL.md section 7's "Checked on" paragraph. codex-cli 0.164.0
(`codex --version`), 2026-10-25, run in an empty scratch directory `$S` that is not a git
repository, hence `--skip-git-repo-check`. Every prompt is trivial. Re-run it to disagree.

```bash
F=(--dangerously-bypass-approvals-and-sandbox --skip-git-repo-check -m gpt-6.1-sol -c model_reasoning_effort=xhigh)
cd "$S"
```

## Direct start and resume

```bash
codex exec --json "${F[@]}" -o "$S/last1.txt" "Remember the word: heron. Reply with exactly: ok" \
  </dev/null >"$S/start.jsonl" 2>"$S/start.err"; echo "exit=$?"
T=$(head -1 "$S/start.jsonl" | jq -r .thread_id)
codex exec resume "${F[@]}" -o "$S/last2.txt" "$T" "What word did I ask you to remember? Reply with that word only." \
  </dev/null >"$S/resume.out" 2>"$S/resume.err"; echo "exit=$?"
codex exec resume --json "${F[@]}" -o "$S/last3.txt" "$T" "Reply with exactly: ok" \
  </dev/null >"$S/resume2.jsonl" 2>"$S/resume2.err"; echo "exit=$?"
```

| Run | exit | stdout | stderr | `-o` file |
|---|---|---|---|---|
| start | 0 | 4 JSONL lines; the first is `{"type":"thread.started","thread_id":"01a174de-18dc-78e1-91ff-5279286862b0"}`; one `agent_message` `ok` | `Reading additional input from stdin...` | `ok` |
| resume, no `--json` | 0 | `heron` | banner with `model: gpt-6.1-sol`, `reasoning effort: xhigh`, `session id: 01a174de-18dc-78e1-91ff-5279286862b0`, then hook lines | `heron` |
| resume, `--json` | 0 | first line `thread.started` with the same thread id; `agent_message` `ok` | empty | `ok` |

## As units

The section 7 unit line as first written (fixed directory per unit, exit file written in place,
prompt inline) with `--working-directory=$S`, `"$(command -v codex)" exec …` as above,
and `-o "$D/report"`. Unit 1 (`D=$S/unit1`) started a thread with the prompt
``Remember the word: osprey. Then run the shell command `systemctl --user is-system-running` and reply with exactly its output.``
Unit 2 (`D=$S/unit2`) ran `exec resume --json` on unit 1's thread id with
`What word did I ask you to remember? Reply with that word only.`

| Unit | `$D/exit` | `$D/out` | `$D/err` | `$D/report` |
|---|---|---|---|---|
| 1 | `success exited 0` | `thread.started` `01a174df-032b-7120-85dd-cd4f857979ee`; a `command_execution` of `systemctl --user is-system-running` with output `degraded` | `Reading additional input from stdin...` | `degraded` |
| 2 | `success exited 0` | `thread.started` with the same thread id; `agent_message` `osprey` | empty | `osprey` |

## Prompt from a file, atomic exit file

The section 7 unit line as committed (per-turn `mktemp -d` directory, `exit.tmp` renamed to
`exit`, `"$(cat "$D/prompt")"` as the prompt), with `--working-directory=$S`,
`--skip-git-repo-check`, and `mktemp -d "$S/units/check-$(date -u +%m%dT%H%M)-XXXXXX"` for `D`.
Each prompt file was written without the shell (the start's) or with `printf '%s\n' '<text>'`
(the resume's).

- Start, unit `manager-check-1025T2121-yKNDcq`, `$D/prompt`:
  ``Do not run any command. Reply with exactly the text between the two | marks, nothing else: |cost $HOME `uname` $(echo hi) "q" 'q' 100% %n done|``
- Resume of that thread (`01a174f0-96d1-7141-bbaa-1375cf34f19a`), unit
  `manager-check-1025T2121-Q0PhTZ`, `$D/prompt`:
  `Do not run any command. What text did I ask you to reply with in the first turn? Reply with it again exactly, then a space, then: $USER`

| Unit | `$D` after exit | `$D/exit` | `$D/err` | `$D/report` |
|---|---|---|---|---|
| start | `err exit out prompt report` (no `exit.tmp`) | `success exited 0` | `Reading additional input from stdin...` | ``cost $HOME `uname` $(echo hi) "q" 'q' 100% %n done`` |
| resume | `err exit out prompt report` | `success exited 0` | empty | ``cost $HOME `uname` $(echo hi) "q" 'q' 100% %n done $USER`` |

Both `out` files start with `thread.started` for the same thread id.

## Model and effort of the start turns

`--json` events carry neither. The session files do:

```bash
grep -o '"model":"[^"]*"\|"effort":"[^"]*"' ~/.codex/sessions/2026/10/25/rollout-*-<thread_id>.jsonl | sort | uniq -c
```

For both thread ids this printed only `"model":"gpt-6.1-sol"` and `"effort":"xhigh"` lines.

## Amendment, 2026-10-31

The owner now requires exactly `model_reasoning_effort=high` for every codex call.
The commands and observations above are the 2026-10-25 record, kept as measured;
for a new check, set `F` with `-c model_reasoning_effort=high` instead. Running
turns keep their current setting until they restart. This amendment records the
policy change, not a new live check.
