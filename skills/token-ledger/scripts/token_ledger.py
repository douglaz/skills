#!/usr/bin/env python3
"""token_ledger.py: measure one project's token spend from local Claude Code and Codex transcripts.

Reads (never writes) ~/.claude/projects, ~/.codex/sessions and, when present, <repo>/.rloop/runs.
Writes one row per model call to <out>/ledger.csv, breakdowns by provider/model, role, day, Run
and bead, and <out>/report.md with an API list-price estimate from prices.json.

Usage: token_ledger.py --project NAME [--repo PATH] [--out DIR] [--since YYYY-MM-DD] [...]
"""
import argparse
import collections
import csv
import datetime as dt
import glob
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
# Project paths named in tool calls; group 1 is the top-level name under a project root.
DEFAULT_REF_RE = r'(?:/home/[^/\s"\']+/(?:p|projects)/|/var/tmp/(?:rloop-units/)?)([A-Za-z][\w.-]*)'
RUN_ID_RE = re.compile(r'\.rloop/runs/(\d{8}T\d{6}\.\d+Z-\d+)')
SKIP_PROMPT = ('<command-', '<local-command', '<system-reminder>', '[Request interrupted', '<task-notification')
CODEX_INJECTED = ('# AGENTS.md instructions', '<environment_context>', '<user_instructions>', '<permissions',
                  '<INSTRUCTIONS>', '<skills', '<turn_aborted>', '<recommended_plugins>')
# Roles that belong to an rloop Run: only these may be attributed to a Run by time window.
RUN_ROLES = {'rloop Manager', 'rloop Implementer', 'rloop Reviewer', 'rloop adviser', 'probe', 'other (repo cwd)'}
COLS = ['provider', 'model', 'role', 'seat', 'run', 'bead', 'attribution', 'day', 'ts', 'session',
        'input_uncached', 'cache_write_5m', 'cache_write_1h', 'cache_write_untiered', 'cache_read', 'output',
        'reasoning_in_output', 'fast', 'web_searches', 'long_context', 'weight', 'usd']
NUM = COLS[10:17] + ['web_searches', 'weight', 'usd']


def parse_args(argv):
    a = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    a.add_argument('--project', required=True, help='key matched (case-insensitive) in cwds and Claude project dir names')
    a.add_argument('--repo', action='append', default=[],
                   help='repo whose .rloop/runs and .beads to read (repeatable; default: every project dir that has .rloop/runs)')
    a.add_argument('--bead-re', help='regex for tracker ids (default: the id prefixes found in the repos\' .beads/issues.jsonl)')
    a.add_argument('--out', help='output dir (default: /var/tmp/NAME-usage)')
    a.add_argument('--prices', default=str(HERE / 'prices.json'))
    a.add_argument('--claude-root', default='~/.claude/projects')
    a.add_argument('--codex-root', default='~/.codex/sessions')
    a.add_argument('--mixed-dir', action='append',
                   help='Claude project dir holding sessions of many projects (default: the encoded $HOME)')
    a.add_argument('--assistant-share', type=float, default=0.5,
                   help='a mixed-dir session counts when at least this share of its project-path tool refs are NAME')
    a.add_argument('--include-session', action='append', default=[], help='count this mixed-dir session regardless')
    a.add_argument('--exclude-session', action='append', default=[], help='never count this session')
    a.add_argument('--ref-re', default=DEFAULT_REF_RE, help='regex for project paths in tool calls (group 1 = name)')
    a.add_argument('--since', help='first UTC day to count, YYYY-MM-DD')
    a.add_argument('--until', help='last UTC day to count, YYYY-MM-DD')
    o = a.parse_args(argv)
    o.key = o.project.lower()
    o.out = Path(o.out or f'/var/tmp/{o.project}-usage')
    o.claude_root = Path(os.path.expanduser(o.claude_root))
    o.codex_root = Path(os.path.expanduser(o.codex_root))
    o.mixed_dir = o.mixed_dir or [str(Path.home()).replace('/', '-').replace('.', '-')]
    o.ref_re = re.compile(o.ref_re)
    return o


def in_window(o, ts):
    day = ts[:10]
    return (not o.since or day >= o.since) and (not o.until or day <= o.until)


def skip_file(o, path):
    """A file last written before --since holds nothing inside the window."""
    if not o.since:
        return False
    mtime = dt.datetime.fromtimestamp(os.path.getmtime(path), dt.timezone.utc).strftime('%Y-%m-%d')
    return mtime < o.since


def text_of(c):
    if isinstance(c, str):
        return c
    return ' '.join(x.get('text', '') for x in c or [] if isinstance(x, dict) and x.get('type') in ('text', 'input_text'))


def parse_ts(s):
    return dt.datetime.fromisoformat(s.replace('Z', '+00:00')) if s else None


# ---------- rloop Runs ----------

def discover(o, cwds):
    """Run repos (dirs with .rloop/runs) and tracker dirs (with .beads) among the project's cwds and their parents.
    Panel clones carry .beads but never .rloop, which git ignores, so they never count as Run repos."""
    runs_dirs, bead_dirs = set(), set()
    cands = set(cwds) | {os.path.expanduser(f'~/p/{o.project}'), os.path.expanduser(f'~/projects/{o.project}')}
    for c in cands | set(o.repo):
        p = Path(os.path.expanduser(c))
        while o.key in str(p).lower() and p != p.parent:
            if (p / '.beads' / 'issues.jsonl').is_file():
                bead_dirs.add(os.path.realpath(p))
            if (p / '.rloop' / 'runs').is_dir():
                runs_dirs.add(os.path.realpath(p))
                break
            p = p.parent
    if o.repo:
        runs_dirs = {os.path.realpath(os.path.expanduser(r)) for r in o.repo}
    return sorted(runs_dirs), sorted(bead_dirs | runs_dirs)


def tracker_ids(dirs):
    ids = set()
    for d in dirs:
        f = Path(d) / '.beads' / 'issues.jsonl'
        if f.is_file():
            for line in f.open(encoding='utf-8', errors='replace'):
                try:
                    ids.add(json.loads(line).get('id', ''))
                except ValueError:
                    pass
    ids.discard('')
    return ids


def load_runs(repos, find_bead):
    runs, seat_of_session = {}, {}
    for d in sorted(p for r in repos for p in (Path(r) / '.rloop' / 'runs').glob('*/')):
        rid, files = d.name, {p.name: p for p in d.iterdir() if p.is_file()}
        try:
            start = dt.datetime.strptime(rid[:15], '%Y%m%dT%H%M%S').replace(tzinfo=dt.timezone.utc)
        except ValueError:
            continue
        end = max([dt.datetime.fromtimestamp(p.stat().st_mtime, dt.timezone.utc) for p in files.values()] or [start])
        bead = '(pick only; no brief)'
        if 'task-1.md' in files:
            t1 = files['task-1.md'].read_text(encoding='utf-8', errors='replace')
            first = t1.splitlines()[0] if t1 else ''
            bead = find_bead(first) or find_bead(t1) or 'no tracker id: ' + first.lstrip('# ')[:50]
        status = ''
        if 'finished.md' in files:
            status = files['finished.md'].read_text(encoding='utf-8', errors='replace').split('\n', 1)[0].replace('STATUS: ', '').strip()
        mgr = files['session'].read_text(encoding='utf-8', errors='replace').strip() if 'session' in files else ''
        err_tok = 0
        for name, p in files.items():
            if name.endswith('.err'):
                txt = p.read_text(encoding='utf-8', errors='replace')
                m = re.search(r'^session id: (\S+)', txt, re.M)
                if m:
                    seat_of_session[m.group(1)] = rid
                err_tok += sum(int(x.replace(',', '')) for x in re.findall(r'^tokens used\n([\d,]+)', txt, re.M))
        runs[rid] = dict(start=start, end=end, bead=bead, status=status, mgr=mgr, err_tok=err_tok,
                         rounds=sum(1 for n in files if re.fullmatch(r'implementer-\d+\.out', n)))
    return runs, seat_of_session


def home_of(cwd):
    m = re.match(r'/home/[^/]+', cwd or '')
    return m.group(0) if m else ''


def window_run(runs, ts):
    t = parse_ts(ts)
    hit = [rid for rid, r in runs.items() if t and r['start'] <= t <= r['end']]
    if not hit:
        return '', ''
    return max(hit, key=lambda rid: runs[rid]['start']), 'time window' + (' (overlap)' if len(hit) > 1 else '')


# ---------- roles ----------

def prompt_role(p, repo_cwd=True):
    head = p[:500]
    if 'You are the Manager of an rloop Run' in head:
        return 'rloop Manager'
    if p.startswith('/goal implement the task') or 'You are the Implementer of an rloop' in head:
        return 'rloop Implementer'
    if re.search(r'independent Reviewers? of an rloop Round', head):
        return 'rloop Reviewer'
    if p.strip() == '/usage' or re.match(r'\s*Reply with the single word', p):
        return 'probe'
    if 'manager-brief' in head:
        return 'delegate manager'
    if repo_cwd and re.search(r'\b(advis|consultation)', p[:200], re.I):  # rloop Consultations run in the repo
        return 'rloop adviser'
    return ''


SEATS = ('fable', 'opus', 'sonnet', 'haiku', 'mythos', 'astra', 'sol', 'grok')


def seat_of(model):
    m = model.lower()
    return next((s for s in SEATS if s in m), model)


# ---------- Claude ----------

def scan_claude(o):
    roots = os.listdir(o.claude_root) if o.claude_root.is_dir() else []  # a Codex-only machine has none
    dirs = [d for d in roots if o.key in d.lower() and d not in o.mixed_dir]
    mixed = [d for d in o.mixed_dir if (o.claude_root / d).is_dir()]
    files, msgs = {}, {}
    for d in dirs + mixed:
        for f in sorted(glob.glob(f'{o.claude_root}/{d}/**/*.jsonl', recursive=True)):
            if skip_file(o, f):
                continue
            rel = os.path.relpath(f, o.claude_root)
            parts = rel.split('/')
            sub = 'subagents' in parts
            meta = dict(rel=rel, dir=d, mixed=d in mixed, sub=sub, session=parts[1] if sub else parts[1][:-6],
                        entry='', first=None, queued=None, refs_key=0, refs_any=0, prompts_key=0, cwds=set(), start='', end='')
            with open(f, encoding='utf-8', errors='replace') as fh:
                for line in fh:
                    try:
                        r = json.loads(line)
                    except ValueError:
                        continue
                    ty, ts, m = r.get('type'), r.get('timestamp', ''), r.get('message') or {}
                    if ts:
                        meta['start'] = meta['start'] or ts
                        meta['end'] = ts
                    if r.get('cwd'):
                        meta['cwds'].add(r['cwd'])
                    meta['entry'] = meta['entry'] or r.get('entrypoint', '')
                    if ty == 'queue-operation' and r.get('operation') == 'enqueue' and meta['queued'] is None:
                        meta['queued'] = r.get('content') if isinstance(r.get('content'), str) else None
                    if ty == 'user' and not r.get('isMeta') and not r.get('toolUseResult'):
                        t = text_of(m.get('content', ''))
                        if t.strip() and not t.lstrip().startswith(SKIP_PROMPT):
                            meta['first'] = t if meta['first'] is None else meta['first']
                            meta['prompts_key'] += o.key in t.lower()
                    elif ty == 'assistant' and m.get('id') and m.get('usage'):
                        for c in m.get('content') or []:
                            if isinstance(c, dict) and c.get('type') == 'tool_use':
                                for name in set(o.ref_re.findall(json.dumps(c.get('input', '')))):
                                    meta['refs_any'] += 1
                                    meta['refs_key'] += name.lower().startswith(o.key)
                        msgs[m['id']] = (rel, ts, m.get('model', ''), r.get('cwd', ''), m['usage'])  # last record wins
            meta['first'] = meta['first'] or meta['queued'] or ''
            files[rel] = meta
    return files, msgs


def claude_usage_rows(usage, model):
    """Yield (model, kind, counts) for the message and each advisor iteration (not in the top-level usage)."""
    def counts(u):
        cc = u.get('cache_creation') or {}
        w5, w1 = cc.get('ephemeral_5m_input_tokens'), cc.get('ephemeral_1h_input_tokens')
        total_w = u.get('cache_creation_input_tokens', 0) or 0
        tiered = (w5 or 0) + (w1 or 0)
        return dict(input_uncached=u.get('input_tokens', 0) or 0, cache_write_5m=w5 or 0, cache_write_1h=w1 or 0,
                    cache_write_untiered=max(total_w - tiered, 0), cache_read=u.get('cache_read_input_tokens', 0) or 0,
                    output=u.get('output_tokens', 0) or 0, reasoning_in_output=0,
                    web_searches=(u.get('server_tool_use') or {}).get('web_search_requests', 0) or 0)
    yield model, 'main', counts(usage), usage.get('speed') == 'fast'
    for it in usage.get('iterations') or []:
        if it.get('type') == 'advisor_message':
            yield it.get('model', model), 'advisor', counts(it), False


# ---------- Codex ----------

def scan_codex(o):
    sessions, calls, maybe, seen = {}, [], [], set()
    for f in sorted(glob.glob(f'{o.codex_root}/**/rollout-*.jsonl', recursive=True)):
        if skip_file(o, f):
            continue
        with open(f, encoding='utf-8', errors='replace') as fh:
            try:
                meta = json.loads(fh.readline())['payload']
            except (ValueError, KeyError, TypeError):
                continue
            cwd, sid = meta.get('cwd') or '', meta.get('id') or meta.get('session_id')
            ours = o.key in cwd.lower()
            prompt, model, records, totals, has_records = None, '', [], [], False
            # codex exec (Run seats, panels, sol managers) says originator codex_exec; a subagent's source is a dict
            interactive = meta.get('originator') not in (None, 'codex_exec') and not isinstance(meta.get('source'), dict)
            for line in fh:
                if not ours:  # peek at the first real prompt only, to list possible strays
                    if '"user"' not in line:
                        continue
                    try:
                        p = json.loads(line).get('payload', {})
                    except ValueError:
                        continue
                    t = codex_user_text(p)
                    if t is not None:
                        if o.key in t.lower():
                            maybe.append([sid, cwd, f, t[:200].replace('\n', ' ')])
                        break
                    continue
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                ty, p, ts = d.get('type'), d.get('payload') or {}, d.get('timestamp', '')
                if ty == 'turn_context':
                    model = p.get('model') or model
                elif ty == 'response_item' and prompt is None:
                    prompt = codex_user_text(p)
                elif ty == 'token_usage_record':
                    has_records = True  # even when every record is a duplicate, this is no legacy file
                    if p.get('response_id') in seen:
                        continue
                    seen.add(p.get('response_id'))
                    records.append((ts, model, p.get('usage') or {}))
                elif ty == 'event_msg' and p.get('type') == 'token_count' and p.get('info'):
                    totals.append((ts, model, p['info'].get('total_token_usage') or {}))
        if not ours:
            continue
        if not has_records:  # older rollouts: per-call usage = growth of the running total
            prev = {}
            for ts, m, tot in totals:
                if tot.get('total_tokens', 0) > prev.get('total_tokens', 0):
                    if (sid, ts, tot.get('total_tokens')) not in seen:  # a copied legacy file counts once
                        seen.add((sid, ts, tot.get('total_tokens')))
                        records.append((ts, m, {k: tot.get(k, 0) - prev.get(k, 0) for k in tot}))
                    prev = tot
        s = sessions.setdefault(sid, dict(cwd=cwd, start=meta.get('timestamp', ''), first=prompt or '', files=0,
                                          interactive=interactive))
        if meta.get('timestamp', '') < s['start'] or not s['first']:  # role comes from the earliest rollout
            s.update(start=meta.get('timestamp', ''), first=prompt or s['first'])
        s['files'] += 1
        calls += [(sid, ts, m, u) for ts, m, u in records]
    return sessions, calls, maybe


def codex_user_text(p):
    if p.get('type') != 'message' or p.get('role') != 'user':
        return None
    t = text_of(p.get('content', []))
    return None if t.lstrip().startswith(CODEX_INJECTED) else t


# ---------- pricing ----------

def lookup(table, model):
    """Exact id, a dated snapshot (key-YYYYMMDD) or a bracketed tier (key[1m]). Never a bare prefix:
    claude-opus-5-6 is not claude-opus-5, and pricing it so would hide that it is unpriced."""
    m = model.replace(' [advisor]', '')
    keys = [k for k in table if m == k or re.fullmatch(re.escape(k) + r'(?:-\d{8}|\[[^\]]*\])', m)]
    return table[max(keys, key=len)] if keys else None


def price_claude(p, c, fast):
    if not p:
        return None
    mult = p.get('fast_multiplier', 1) if fast else 1
    usd = (c['input_uncached'] * p['input'] + c['cache_read'] * p['cache_read'] + c['output'] * p['output']
           + c['cache_write_5m'] * p['cache_write_5m'] + (c['cache_write_1h'] + c['cache_write_untiered']) * p['cache_write_1h'])
    return usd * mult / 1e6 + c['web_searches'] * p.get('web_search_per_request', 0)


def price_codex(p, c, total_in):
    if not p:
        return None, False
    lc = p.get('long_context')
    long = bool(lc and total_in > lc['threshold'])
    r = lc if long else p
    usd = (c['input_uncached'] * r['input'] + c['cache_read'] * r['cached_input'] + c['output'] * r['output']
           + c['cache_write_untiered'] * r.get('cache_write', r['input']))
    return usd / 1e6, long


def weight(c):
    """Price-independent ratio: input 1, cache write 1.25 (5m) / 2 (1h), cache read 0.1, output 5."""
    return (c['input_uncached'] + 1.25 * c['cache_write_5m'] + 2 * (c['cache_write_1h'] + c['cache_write_untiered'])
            + 0.1 * c['cache_read'] + 5 * c['output'])


# ---------- ledger ----------

def build(o):
    prices = json.load(open(o.prices, encoding='utf-8'))
    files, msgs = scan_claude(o)
    sessions, calls, maybe = scan_codex(o)
    cwds = {c for f in files.values() if not f['mixed'] for c in f['cwds']} | {s['cwd'] for s in sessions.values()}
    repos, bead_dirs = discover(o, cwds)
    known = tracker_ids(bead_dirs)
    counts = collections.Counter(i.split('.')[0].rsplit('-', 1)[0] for i in known if '-' in i)
    prefixes = [k for k, _ in counts.most_common()] or [o.project]
    # longest first, so pv-long-name-abc is not cut short at pv-long
    bead_re = re.compile(o.bead_re or r'\b(?:' + '|'.join(map(re.escape, sorted(prefixes, key=len, reverse=True)))
                         + r')-[a-z0-9]{3,8}(?:\.\d+)*\b')

    def find_bead(text):  # the first id that the tracker knows (any match when no tracker was found)
        return next((m.group(0) for m in bead_re.finditer(text or '') if not known or m.group(0) in known), '')

    runs, seat_runs = load_runs(repos, find_bead)
    by_mgr = {r['mgr']: rid for rid, r in runs.items() if r['mgr']}
    epics = {i.split('.')[0] for i in known if '.' in i} or {b.split('.')[0] for r in runs.values() for b in [r['bead']] if '.' in b}
    short_re = re.compile(r'(?<![a-z0-9])(' + '|'.join(re.escape(e.rsplit('-', 1)[1]) for e in sorted(epics)) + r')\.?(\d+)(?!\d)') \
        if epics else None
    epic_of = {e.rsplit('-', 1)[1]: e for e in epics}

    def bead_from(*texts):
        for t in texts:
            b = find_bead(t)
            if b:
                return b
        for t in texts:  # short forms in panel folder names, e.g. panel-abc56-r1
            for m in (short_re.finditer(t or '') if short_re else []):
                b = f'{epic_of[m.group(1)]}.{m.group(2)}'
                if not known or b in known:
                    return b
        return ''

    def in_repo(cwd):
        rc = os.path.realpath(cwd) if cwd else ''
        return any(rc == r or rc.startswith(r + '/') for r in repos)

    def attribute(role, session_ids, first, dirname, ts):
        if role not in RUN_ROLES and role != 'delegate manager':
            return '', ''
        for s in session_ids:
            if s in by_mgr:
                return by_mgr[s], 'run session file'
            if s in seat_runs:
                return seat_runs[s], 'session id in run .err'
        m = RUN_ID_RE.search(first or '')
        if m and m.group(1) in runs:
            return m.group(1), 'run path in prompt'
        if 'rloop-runs-' in dirname:
            rid = dirname.split('rloop-runs-')[1].replace('-', '.', 1)
            if rid in runs:
                return rid, 'run dir name'
        if role in RUN_ROLES:
            return window_run(runs, ts)
        return '', ''

    ledger, notes = [], collections.Counter()
    o.repos, o.prefixes = repos, prefixes[:3] + ([f'{len(prefixes) - 3} more'] if len(prefixes) > 3 else [])

    # Claude
    mains = {f['session']: f for f in files.values() if f['mixed'] and not f['sub']}
    counted = set(o.include_session)
    for s, f in mains.items():
        if f['refs_any'] and f['refs_key'] / f['refs_any'] >= o.assistant_share:
            counted.add(s)
    counted -= set(o.exclude_session)
    for mid, (rel, ts, model, cwd, usage) in msgs.items():
        if not ts or not in_window(o, ts) or model == '<synthetic>':
            continue
        f = files[rel]
        if f['session'] in o.exclude_session:
            continue
        if f['mixed']:
            if f['session'] not in counted:
                continue
            role = ('delegate manager' if prompt_role(f['first']) == 'delegate manager' else 'assistant subagent') \
                if f['sub'] else 'assistant'
        else:
            parent = files.get(f"{f['dir']}/{f['session']}.jsonl", f) if f['sub'] else f
            if parent['entry'] == 'cli':  # an interactive session started in a project dir
                role = 'assistant (in project dir)' if not f['sub'] else (
                    'delegate manager' if prompt_role(f['first']) == 'delegate manager' else 'assistant subagent')
            else:  # claude -p: a Run seat, a panel reader or a probe; subagents inherit the parent's role
                role = prompt_role(parent['first'], in_repo(cwd)) or ('other (repo cwd)' if in_repo(cwd) else 'panel reader')
                f = parent
        run, how = attribute(role, [f['session']], f['first'], f['dir'], ts)
        # an assistant session spans many beads, so its first prompt names none of them reliably
        bead = runs[run]['bead'] if run else '' if role.startswith('assistant (') or role == 'assistant' else bead_from(f['first'], f['dir'])
        how = how or ('id in prompt or dir name' if bead else '')
        for m2, kind, c, fast in claude_usage_rows(usage, model):
            if not any(c[k] for k in ('input_uncached', 'cache_write_5m', 'cache_write_1h', 'cache_write_untiered', 'cache_read', 'output')):
                continue
            name = m2 + (' [advisor]' if kind == 'advisor' else '')
            usd = price_claude(lookup(prices['claude'], m2), c, fast)
            notes['unpriced claude ' + m2] += usd is None
            notes['claude cache writes without a tier (priced at 1h)'] += c['cache_write_untiered']
            notes['claude fast-mode calls'] += fast
            notes['claude web searches (unpriced unless prices.json sets web_search_per_request)'] += c['web_searches']
            notes['home ' + home_of(cwd)] += bool(home_of(cwd))
            ledger.append(dict(provider='claude', model=name, role=role, seat=seat_of(m2) if 'rloop' in role or role == 'panel reader' else '',
                               run=run, bead=bead or 'unattributed', attribution=how, day=ts[:10], ts=ts, session=f['session'],
                               **c, fast=int(fast), long_context=0, weight=weight(c), usd=usd))

    # Codex
    for sid, ts, model, u in calls:
        if not ts or not in_window(o, ts):
            continue
        s = sessions[sid]
        if sid in o.exclude_session:
            continue
        role = 'assistant (codex)' if s['interactive'] else \
            prompt_role(s['first'], in_repo(s['cwd'])) or ('other (repo cwd)' if in_repo(s['cwd']) else 'panel reader')
        if sid in by_mgr:
            role = 'rloop Manager'
        run, how = attribute(role, [sid], s['first'], '', ts)
        bead = runs[run]['bead'] if run else '' if s['interactive'] else bead_from(s['first'], s['cwd'])
        how = how or ('id in prompt or dir name' if bead else '')
        # input_tokens includes the cached and cache-write parts (cache writes were 0 in every rollout seen so far)
        i, ca, cw = (u.get(k, 0) or 0 for k in ('input_tokens', 'cached_input_tokens', 'cache_write_input_tokens'))
        c = dict(input_uncached=i - ca - cw, cache_write_5m=0, cache_write_1h=0, cache_write_untiered=cw, cache_read=ca,
                 output=u.get('output_tokens', 0) or 0, reasoning_in_output=u.get('reasoning_output_tokens', 0) or 0,
                 web_searches=0)
        usd, long = price_codex(lookup(prices['codex'], model), c, i)
        notes['unpriced codex ' + model] += usd is None
        notes['home ' + home_of(s['cwd'])] += bool(home_of(s['cwd']))
        ledger.append(dict(provider='codex', model=model, role=role, seat=seat_of(model) if 'rloop' in role or role == 'panel reader' else '',
                           run=run, bead=bead or 'unattributed', attribution=how, day=ts[:10], ts=ts, session=sid,
                           **c, fast=0, long_context=int(long), weight=weight(c), usd=usd))
    return ledger, runs, mains, counted, maybe, notes, prices


def write_csv(path, header, rows):
    with open(path, 'w', newline='', encoding='utf-8') as fh:
        w = csv.writer(fh)
        w.writerow(header)
        w.writerows(rows)


def aggregate(ledger, key):
    a = collections.defaultdict(lambda: collections.Counter())
    for L in ledger:
        acc = a[key(L)]
        for k in NUM:
            acc[k] += L[k] or 0
        acc['calls'] += 1
        acc['unpriced_calls'] += L['usd'] is None
    return sorted(a.items(), key=lambda kv: -kv[1]['usd'])


def money(x):
    return f'${x:,.0f}' if x >= 10 else f'${x:,.2f}'


def tokens(x):
    return f'{x / 1e6:,.1f}M' if x >= 1e5 else f'{x:,}'


def report(o, ledger, runs, mains, counted, maybe, notes, prices):
    o.out.mkdir(parents=True, exist_ok=True)
    write_csv(o.out / 'ledger.csv', COLS, [[L[k] if L[k] is not None else '' for k in COLS] for L in ledger])
    views = {'by_provider_model.csv': (['provider', 'model'], lambda L: (L['provider'], L['model'])),
             'by_role.csv': (['provider', 'role', 'seat'], lambda L: (L['provider'], L['role'], L['seat'])),
             'by_day.csv': (['day', 'provider'], lambda L: (L['day'], L['provider'])),
             'by_bead.csv': (['bead', 'provider'], lambda L: (L['bead'], L['provider'])),
             'by_run.csv': (['run', 'provider'], lambda L: (L['run'] or '-', L['provider'])),
             'by_attribution.csv': (['attribution'], lambda L: (L['attribution'] or 'unattributed',))}
    for name, (hdr, key) in views.items():
        write_csv(o.out / name, hdr + NUM + ['calls', 'unpriced_calls'],
                  [[*k, *[round(v[n], 2) for n in NUM], v['calls'], v['unpriced_calls']] for k, v in aggregate(ledger, key)])
    write_csv(o.out / 'runs.csv', ['run', 'start', 'end', 'bead', 'rounds', 'status', 'codex_err_tokens_used'],
              [[rid, r['start'].isoformat(), r['end'].isoformat(), r['bead'], r['rounds'], r['status'], r['err_tok']]
               for rid, r in runs.items()])
    write_csv(o.out / 'assistant_sessions.csv', ['session', 'counted', 'start', 'end', 'project_refs', 'all_refs', 'first_prompt'],
              [[s, s in counted, f['start'], f['end'], f['refs_key'], f['refs_any'], f['first'][:120].replace('\n', ' ')]
               for s, f in sorted(mains.items()) if s in counted or f['refs_key'] or f['prompts_key']])
    write_csv(o.out / 'codex_maybe.csv', ['session', 'cwd', 'file', 'first_prompt'], maybe)

    if not ledger:
        (o.out / 'report.md').write_text(f'# Token ledger: {o.project}\n\nNo calls found.\n', encoding='utf-8')
        return
    tsr = sorted(L['ts'] for L in ledger)
    out = [f'# Token ledger: {o.project}', '',
           f'Coverage {tsr[0][:16]}Z to {tsr[-1][:16]}Z; {len(ledger):,} calls. Prices: {prices.get("as_of", "?")} '
           f'list rates ({prices.get("unit", "USD per million tokens")}). The weight is a price-free ratio; never add '
           'weights across providers.', '',
           f"Run repos: {', '.join(o.repos) or 'none found'}. Tracker id prefixes: {', '.join(o.prefixes)}.", '']
    priced = sum(L['usd'] or 0 for L in ledger)
    out += [f'**Estimated API cost: {money(priced)}**', '', '## By provider', '',
            '| Provider | Uncached in | Cache write | Cache read | Output | Weight | API cost |', '|---|---|---|---|---|---|---|']
    for (prov,), v in aggregate(ledger, lambda L: (L['provider'],)):
        cw = v['cache_write_5m'] + v['cache_write_1h'] + v['cache_write_untiered']
        out.append(f"| {prov} | {tokens(v['input_uncached'])} | {tokens(cw)} | {tokens(v['cache_read'])} | "
                   f"{tokens(v['output'])} | {tokens(v['weight'])} | {money(v['usd'])} |")
    for title, key, n in (('By model', lambda L: (L['provider'], L['model']), 20),
                          ('By role', lambda L: (L['provider'], L['role'] + (f" ({L['seat']})" if L['seat'] else '')), 30)):
        out += ['', f'## {title}', '', '| Provider | Name | Calls | Weight | API cost |', '|---|---|---|---|---|']
        out += [f"| {k[0]} | {k[1]} | {v['calls']:,} | {tokens(v['weight'])} | {money(v['usd'])} |"
                for k, v in aggregate(ledger, key)[:n]]
    beads = aggregate(ledger, lambda L: (L['bead'],))
    per = collections.defaultdict(collections.Counter)
    for L in ledger:
        per[L['bead']][L['provider']] += L['usd'] or 0
    rb = collections.defaultdict(lambda: [0, 0])
    for r in runs.values():
        rb[r['bead']][0] += 1
        rb[r['bead']][1] += r['rounds']
    out += ['', '## Top beads', '', '| Bead | Claude | Codex | Total | Runs | Rounds |', '|---|---|---|---|---|---|']
    out += [f"| {b} | {money(per[b]['claude'])} | {money(per[b]['codex'])} | {money(v['usd'])} | {rb[b][0]} | {rb[b][1]} |"
            for (b,), v in beads[:15]]
    weeks = collections.defaultdict(collections.Counter)
    for L in ledger:
        y, w, _ = dt.date.fromisoformat(L['day']).isocalendar()
        weeks[f'{y}-W{w:02d}'][L['provider']] += L['usd'] or 0
    out += ['', '## By week', '', '| Week | Claude | Codex |', '|---|---|---|']
    out += [f"| {w} | {money(c['claude'])} | {money(c['codex'])} |" for w, c in sorted(weeks.items())]
    att = aggregate(ledger, lambda L: (L['attribution'] or 'unattributed',))
    out += ['', '## How calls were attributed', '']
    out += [f"- {k[0]}: {money(v['usd'])} ({v['calls']:,} calls)" for k, v in att]
    gaps = [f'- {k}: {v:,}' for k, v in sorted(notes.items()) if v and not k.startswith('home ')]
    homes = ', '.join(sorted(k[5:] for k, v in notes.items() if k.startswith('home ') and v))
    if homes:
        gaps.append(f'- Calls ran under {homes}; a second home dir usually means transcripts copied from another machine.')
    left = [s for s, f in mains.items() if s not in counted and (f['refs_key'] or f['prompts_key'])]
    out += ['', '## Gaps and caveats', '',
            f'- Mixed-dir sessions counted: {len(counted & set(mains))}; left out though they mention {o.project}: '
            f'{len(left)} (assistant_sessions.csv). Rule: at least {o.assistant_share:.0%} of a session\'s project-path tool refs.',
            f'- Codex sessions outside the project cwd whose first prompt mentions it: {len(maybe)} (codex_maybe.csv), not counted.',
            '- Tools without local token records (for example grok) are not in this ledger.',
            '- rloop prints "tokens used N" as uncached input plus output only; it understates real volume.',
            f"- Prices are list rates from prices.json as of {prices.get('as_of', '?')}, applied to all history (a price "
            'cut since then makes older work look cheaper than it was billed). Check the date and its `assumed` list before quoting.'] + gaps
    (o.out / 'report.md').write_text('\n'.join(out) + '\n', encoding='utf-8')


def main(argv=None):
    o = parse_args(sys.argv[1:] if argv is None else argv)
    ledger, runs, mains, counted, maybe, notes, prices = build(o)
    report(o, ledger, runs, mains, counted, maybe, notes, prices)
    total = sum(L['usd'] or 0 for L in ledger)
    print(f'{len(ledger):,} calls; estimated API cost {money(total)}; report: {o.out / "report.md"}')


if __name__ == '__main__':
    main()
