#!/usr/bin/env python3
"""Packet meter: new tokens (uncached input plus output) spent by a packet's model sessions.

  meter.py PKT [--phase session|review]
  meter.py --claude-transcript FILE [--since ISO_UTC]

It only measures. Nothing here stops, caps or warns: the lane reports what a change cost, and the
owner decides what to do with the number.

PKT holds config.json and a start stamp in epoch seconds: meter-start (phase session, the default)
or review-start (phase review). The combined session is selected by the id session.sh resumes,
read from turns/*/session/err. The review phase excludes that id. Other codex sessions count when
their transcript was written after the
stamp and its working directory is one of the packet's roots (config "roots", default: PKT and the
worktree) or below one. In phase review, Claude transcripts whose working directory is the worktree
count too, so the reading covers every reviewer seat.

Prints the reading as JSON and writes it to PKT/meter.json or PKT/review-meter.json. It can be run
at any time; a response still in flight is not counted until it lands.

The second form meters one Claude transcript, for example the assistant's own session.

Why uncached input plus output: a long session re-reads its history from cache on every step, so
total tokens grow with the number of steps, not with the work. The total is printed as a diagnostic.
"""
import json
import os
import re
import sys
from pathlib import Path

CODEX_SESSIONS = Path(os.environ.get('CFASTLANE_CODEX_SESSIONS', Path.home() / '.codex' / 'sessions'))
CLAUDE_PROJECTS = Path(os.environ.get('CFASTLANE_CLAUDE_PROJECTS', Path.home() / '.claude' / 'projects'))


def config(pkt):
    cfg = json.loads((pkt / 'config.json').read_text())
    cfg.setdefault('roots', [str(pkt), cfg['worktree']])
    return cfg


def codex_last_usage(path):
    last = None
    with path.open() as f:
        for line in f:
            if '"token_count"' not in line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            info = d.get('payload', {}).get('info')
            if d.get('type') == 'event_msg' and info:
                last = info['total_token_usage']
    return last


def codex_meta(path):
    try:
        with path.open() as f:
            meta = json.loads(next(f))
        return meta.get('payload', {})
    except (OSError, StopIteration, json.JSONDecodeError):
        return None


def codex_rows(roots, since, combined_id, phase):
    rows = []
    for path in sorted(CODEX_SESSIONS.glob('*/*/*/*.jsonl')):
        try:
            if path.stat().st_mtime < since:
                continue
        except OSError:
            continue
        meta = codex_meta(path)
        if meta is None:
            continue
        is_combined = meta.get('id') == combined_id
        if is_combined != (phase == 'session'):
            continue
        cwd = Path(meta.get('cwd', '/nonexistent')).resolve()
        if not any(cwd == r or r in cwd.parents for r in roots):
            continue
        u = codex_last_usage(path)
        if u:
            rows.append(dict(kind='codex', session=path.name, cwd=str(cwd), total=u['total_tokens'],
                             new=u['input_tokens'] - u.get('cached_input_tokens', 0) + u['output_tokens']))
    return rows


def claude_usage(path, since_iso=''):
    """Sum one Claude transcript, one row per message id (the last record of a message is final)."""
    seen = {}
    with open(path) as f:
        for line in f:
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            msg = d.get('message') or {}
            u = msg.get('usage')
            if d.get('type') != 'assistant' or not u or not msg.get('id'):
                continue
            if since_iso and (d.get('timestamp') or '') < since_iso:
                continue
            seen[msg['id']] = u
    fresh = sum(u.get('input_tokens', 0) + u.get('cache_creation_input_tokens', 0) for u in seen.values())
    out = sum(u.get('output_tokens', 0) for u in seen.values())
    cached = sum(u.get('cache_read_input_tokens', 0) for u in seen.values())
    return dict(messages=len(seen), uncached_input=fresh, output=out, new=fresh + out, total=fresh + out + cached)


def claude_rows(worktree, since):
    folder = CLAUDE_PROJECTS / re.sub(r'[^A-Za-z0-9]', '-', str(worktree))
    rows = []
    for path in sorted(folder.glob('*.jsonl')):
        try:
            if path.stat().st_mtime < since:
                continue
        except OSError:
            continue
        u = claude_usage(path)
        rows.append(dict(kind='claude', session=path.name, cwd=str(worktree), total=u['total'], new=u['new']))
    return rows


def reading(pkt, phase='session'):
    cfg = config(pkt)
    stamp = pkt / ('meter-start' if phase == 'session' else 'review-start')
    since = float(stamp.read_text().strip())
    combined_id = None
    for log in sorted(pkt.glob('turns/*/session/err')):
        match = re.search(r'^session id: *([A-Za-z0-9-]+)', log.read_text(), re.M)
        if match:
            combined_id = match[1]
            break
    if combined_id is None:
        sys.exit('combined session id unavailable: cannot separate session and reviewer tokens')
    rows = codex_rows([Path(r).resolve() for r in cfg['roots']], since, combined_id, phase)
    if phase == 'review':
        rows += claude_rows(Path(cfg['worktree']).resolve(), since)
    return dict(packet=cfg['name'], phase=phase, new_tokens=sum(r['new'] for r in rows),
                total_diagnostic=sum(r['total'] for r in rows), participants=rows,
                measurement='Latest cumulative counters per session; a response in flight is not counted.')


def main():
    args = sys.argv[1:]
    if args and args[0] == '--claude-transcript':
        since = args[args.index('--since') + 1] if '--since' in args else ''
        print(json.dumps(dict(since=since, **claude_usage(args[1], since))))
        return
    if not args or args[0].startswith('-'):
        sys.exit(__doc__)
    pkt = Path(args[0]).resolve()
    phase = args[args.index('--phase') + 1] if '--phase' in args else 'session'
    if phase not in ('session', 'review'):
        sys.exit('phase must be session or review')
    result = reading(pkt, phase)
    out = pkt / ('meter.json' if phase == 'session' else 'review-meter.json')
    tmp = out.with_suffix('.json.tmp')
    tmp.write_text(json.dumps(result, indent=2) + '\n')
    tmp.replace(out)
    print(json.dumps(result))


if __name__ == '__main__':
    main()
