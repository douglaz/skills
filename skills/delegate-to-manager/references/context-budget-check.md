# Context budget: how the numbers were checked

Section 3's context budget rests on two observations from Claude Code 2.1.293. Both checks below read
only metadata from local transcripts: usage counts, `compact_boundary` records, and the
`<task-id>`/`<subagent_tokens>` tags of completion notifications. They print numbers, never message
text.

## `subagent_tokens` is the manager's context at the return

Every completion notification the assistant receives for a background Agent carries
`<usage><subagent_tokens>N</subagent_tokens><tool_uses>…</tool_uses><duration_ms>…</duration_ms></usage>`.
The check compares N with the manager's last request before the notification. The last request is
its prompt (`input_tokens + cache_creation_input_tokens + cache_read_input_tokens`) plus its
`output_tokens`.

```bash
python3 - "$HOME/.claude/projects/<dir>/<session>.jsonl" <<'EOF'
import json, re, sys, statistics
from pathlib import Path
parent = Path(sys.argv[1]); sub = parent.with_suffix('') / 'subagents'
def calls(aid):
    out, seen = [], set()
    f = sub / f'agent-{aid}.jsonl'
    for line in (open(f) if f.exists() else []):
        e = json.loads(line); m = e.get('message') or {}
        if e.get('type') != 'assistant' or m.get('id') in seen or not m.get('usage'): continue
        seen.add(m['id']); u = m['usage']
        out.append((e['timestamp'], sum(u.get(k) or 0 for k in ('input_tokens',
            'cache_creation_input_tokens', 'cache_read_input_tokens', 'output_tokens'))))
    return out
diffs = []
for line in open(parent):
    if '<subagent_tokens>' not in line: continue
    e = json.loads(line)
    if e.get('type') != 'user': continue
    for m in re.finditer(r'<task-id>([a-z0-9]+)</task-id>.{0,4000}?<subagent_tokens>(\d+)<', line):
        before = [c for c in calls(m.group(1)) if c[0] <= e['timestamp']]
        if before: diffs.append(abs(int(m.group(2)) - before[-1][1]))
print(len(diffs), 'returns; median |N - last request|:', statistics.median(diffs) if diffs else None)
EOF
```

**Observed on 2026-11-06:**
- For one long assistant session (2026-10-18 to 11-06), the snippet found 173 returns with a median
  difference of 1,080 tokens.
- A per-turn analysis of all 2026-11-04..06 delegate managers matched 300 returns with a median
  difference of 468 tokens.

The tag is not documented as a contract, so re-run the check after a Claude Code upgrade. If it
fails, section 3's "reading unavailable" rule applies.

## Auto-compaction fires about 33k below the configured window

Each automatic compaction writes a `system` record with `subtype: compact_boundary` and
`compactMetadata.preTokens`. The check takes the distribution of `preTokens` across manager
transcripts that ran under `CLAUDE_CODE_AUTO_COMPACT_WINDOW=150000`:

```bash
cat "$HOME"/.claude/projects/<dir>/<session>/subagents/agent-*.jsonl \
  | jq -r 'select(.type=="system" and .subtype=="compact_boundary") | .compactMetadata.preTokens' \
  | sort -n | awk '{a[NR]=$1} END {print NR, "compactions; p10", a[int(NR*.1)+1], "median", a[int(NR/2)+1], "p90", a[int(NR*.9)]}'
```

**Observed on 2026-11-06:**
- For the same session's managers, the snippet found 184 compactions, with `preTokens` p10 116,554,
  median 118,360 and p90 123,042.
- Across all 2026-11-04..06 delegate managers there were 337 compactions, with p10 116,673, median
  117,926 and p90 122,139. That is about 150000 − 33k.
- The next request after a compaction had a median context of 44,842.

A turn can therefore cross a 150000 window's trigger before it returns, so the budget for that
window sits near 90k.
