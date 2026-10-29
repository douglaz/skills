---
name: token-ledger
description: >-
  Measure how many tokens a project has consumed across Claude Code and Codex, and estimate what that
  would cost at API list prices. It builds a per-call ledger from the local transcripts
  (~/.claude/projects, ~/.codex/sessions), attributes every call to a provider, model, role (rloop
  Manager, Implementer, Reviewer seat, panel reader, delegate manager, assistant), day, rloop Run and
  tracker bead, and writes CSVs plus a report. Use this whenever the owner asks how much a project
  cost, where the tokens went, whether there is "an accounting of tokens", which beads or Runs were
  expensive, what reviewers or panels cost, or what the spend would be "if we used the API". Use it
  too for usage comparisons between projects or periods, even when they don't say "ledger".
argument-hint: "<project> [--since YYYY-MM-DD] [--until YYYY-MM-DD]"
---

# Token ledger

Every Claude Code and Codex call leaves exact token counts on disk. This skill turns those counts into
an answer the owner can act on. That means totals, where the tokens went, and an API-price estimate,
with the gaps stated.

## Run it

```bash
python3 -I <skill-dir>/scripts/token_ledger.py --project NAME            # whole history
python3 -I <skill-dir>/scripts/token_ledger.py --project NAME --since 2026-10-22 --out /var/tmp/NAME-usage-week
```

- `NAME` is matched, case-insensitively, against working directories and Claude project dir names. So
  `provisiond` picks up the repo, `/var/tmp/provisiond-*` panel folders and rloop Run dirs. A key that is a
  prefix of a sibling project also matches the sibling: `tau-web` matches `tau-web-rust`. Usually that
  is wanted. If it isn't, say so and pass a more exact key.
- **Repos are discovered, not assumed.**
  - Every project cwd, or a parent of one, that has `.rloop/runs` becomes a Run repo, so a spec repo
    and a code repo are both read.
  - Panel clones have `.beads` but never `.rloop`, which git ignores, so they never count as Run
    repos.
  - Check the `Run repos:` line at the top of `report.md`. If it's wrong, pass `--repo` once per repo.
- **Tracker ids are discovered too.** The id prefixes come from those repos' `.beads/issues.jsonl`, for
  example `pv` for provisiond and `tw` or `twr` for tau-web.
  - A match only counts when the tracker knows that id, so a path like `/var/tmp/provisiond-manager` is
    never read as one.
  - `--bead-re` overrides the pattern.
- Output goes to `/var/tmp/NAME-usage/` by default:
  - `report.md`;
  - `ledger.csv`, one row per model call;
  - `by_provider_model.csv`, `by_role.csv`, `by_day.csv`, `by_bead.csv`, `by_run.csv` and
    `by_attribution.csv`;
  - `runs.csv`, `assistant_sessions.csv` and `codex_maybe.csv`.
- It reads files only and makes no API calls. On about 60k calls it takes roughly 20 seconds.
- `scripts/token_ledger.test` is an offline check on synthetic transcripts. Run it after you change the
  script.

## Before you quote a cost: check the prices

`scripts/prices.json` holds list prices with an `as_of` date and its sources.

- **Stale prices:** if the date is more than about a month old, re-check the rates for the models that
  matter before quoting dollars. Use official pricing pages first, then aggregators.
- **Unpriced models:** a model missing from the table is listed as unpriced in the report. Look up its
  price and add it, rather than estimating it.
- **Updating:** edit `prices.json`, or pass `--prices FILE`, and re-run. A price change needs only a
  re-run, not a rescan.

Prices come from aggregators at least as often as from vendors, so say where the numbers came from.
Mention any line in `prices.json`'s `assumed` list that affects the total.

All history is priced at the `as_of` rates, so a price cut since then makes older work look cheaper
than it was billed. If the estimate matters, say so for the affected models, or price those weeks by
hand.

## Which calls belong to the project

- **Claude:** a call counts when its project dir name contains `NAME`.
- **Codex:** a call counts when its session cwd contains `NAME`.
- **Mixed home dir:** sessions started in the encoded `$HOME` dir (for example `-home-user`) mix many
  projects. Such a session counts when at least half (`--assistant-share`) of the project paths its tool
  calls touch are `NAME`'s.
  - The report says how many mixed sessions it counted and how many it left out.
  - `--include-session ID` and `--exclude-session ID` fix the borderline ones.
  - Write dir names that start with `-` as `--mixed-dir=-home-user`, because argparse reads a bare
    `-home-user` as a flag.
- **Codex strays:** a Codex session outside the project cwd whose first prompt names the project goes
  to `codex_maybe.csv`, not into the totals. Look at it and say whether it should count.
- **Other layouts:** tool-call paths are matched by `--ref-re` (default `~/p`, `~/projects`,
  `/var/tmp`). Override it for a differently organised machine.

## Roles and attribution

Roles come from each session's first prompt and its location:
- rloop's own prompts mark the Manager, Implementer, Reviewer and Consultation adviser.
- A `manager-brief` prompt marks a delegate manager.
- `claude -p` outside the repo is a panel reader.
- Interactive sessions are the assistant, and their subagents are assistant subagents.
- A Codex session is `assistant (codex)` when its `session_meta` carries an `originator` other than
  `codex_exec` and its `source` is not a subagent spawn.
  - Older rollouts with no `originator` can't be told apart, so they are classified by their prompt and
    location like any other call.
  - If one lands as `other (repo cwd)` and picks up Run spend it shouldn't have, say so, or pass
    `--exclude-session` for it.
- A Codex subagent takes its role and Run from the session that spawned it, following
  `parent_thread_id` up to the root. A child of an interactive session is `assistant subagent (codex)`.

A call reaches a Run, and through the Run its bead, in one of these ways, strongest first:
1. the Run's `session` file;
2. the session id in a Run's `.err`;
3. the Run path in the prompt;
4. the Run dir name;
5. last, the time window of a Run in the session's own repo. Only rloop roles can be attributed this
   way, and when two Runs in that repo overlap, the call is left without a Run.

When no Run matches, the bead comes from the first tracker id in the prompt or the dir name. Short
forms like `panel-abc56-r1`, meaning `<prefix>-abc.56`, count too.

Assistant main threads, Claude or Codex, never take a bead this way. One session spans many beads, and
labelling it by its first prompt once put two weeks of assistant work on a single bead. Assistant
threads are never matched to a Run by time window either, so their spend stays unattributed.

`by_attribution.csv` shows how much spend each method carried. A large time-window or unattributed
share is a caveat worth stating.

## Reporting to the owner

Lead with the answer in plain words, then keep it short:

1. **Totals by provider.** Give tokens and the API-cost estimate. Dollars can be added across
   providers. The `weight` column is a price-free ratio and can't be.
2. **Where it went.** Give the top roles and models. The Implementer usually leads in tokens and the
   Claude reviewers and Managers in dollars.
3. **The costliest beads, with their Rounds.** Beads that go back for more Rounds are where spend
   piles up.
4. **The trend by week.** Note when a role moved between providers.
5. **Caveats.** Include each gap the report lists that changes the picture.

**Volume versus cost.** Cache reads are usually over 90% of tokens but a much smaller share of cost. Don't
call something expensive from token counts alone.

## Known traps (why the script does what it does)

- **Repeated Claude records:** one Claude message can appear in several records. The script keeps the
  last usage per `message.id`. Summing records double-counts.
- **Advisor iterations:** these are in `usage.iterations` and not in the top-level usage, so they get
  their own `[advisor]` rows.
- **Cache-write tiers:** writes are split into 5-minute and 1-hour tiers (`cache_creation`), and the
  1-hour tier costs more.
  - Writes without a tier split are priced at the 1-hour rate.
  - Fast-mode calls (`speed: fast`) are priced at `fast_multiplier`.
- **Codex input counts:** `input_tokens` includes the cached part. Calls over a model's
  `long_context.threshold` pay the long-context rate for the whole request.
- **Older rollouts:** older Codex rollouts have no per-call records, so per-call usage is the growth of
  the running total.
  - That fallback is only for files with no per-call records at all.
  - A copied or resumed rollout whose records were all duplicates must not fall back, or it would add
    its running totals a second time.
- **rloop's "tokens used N":** this line is uncached input plus output only. It understates real volume
  by an order of magnitude or more. Don't report it as spend.
- **Missing tools:** tools that leave no local token records, such as grok, are absent. Say so rather
  than estimating them.
- **Other machines:** calls under a second home dir (for example `/home/master`) usually mean
  transcripts copied from another machine, so history from before the copy may be partial.
