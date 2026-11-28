#!/usr/bin/env python3
"""Check the session's uncommitted work and commit it. The session never commits its own work.

  close.py PKT check    print the scans, commit nothing (exit 1 with the reasons when a scan blocks)
  close.py PKT commit   the same scans, then commit and write the commit id to PKT/candidate

Reads PKT/config.json ("worktree"; optional "banned_text", a regular expression matched without
case against added lines and the commit message; optional "allowed_paths", a list of path prefixes
every changed file must fall under; optional "identity": {"name", "email"}) and PKT/base (the commit
the session started from). The commit message comes from PKT/commit-subject.txt and
PKT/commit-body.txt, which the session writes. After a repair turn, run it again: it expects HEAD
at the commit it made last (PKT/candidate) and scans only the work added since.

Blocks on: HEAD moved off the expected commit, a submodule (nested ones too, whatever its ignore setting)
with uncommitted or untracked files, checked before anything is staged, banned text, a file outside the
allowed paths, or a missing message. Lines that add `sorry`, an axiom or a kernel bypass are printed
for the judge to look at, never blocked, because their meaning depends on the project.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3 or sys.argv[2] not in ('check', 'commit'):
        sys.exit(__doc__)
    pkt, mode = Path(sys.argv[1]).resolve(), sys.argv[2]
    cfg = json.loads((pkt / 'config.json').read_text())
    wt, base = cfg['worktree'], (pkt / 'base').read_text().strip()

    def git(*args, check=True):
        return subprocess.run(['git', '-C', wt, *args], capture_output=True, text=True, check=check).stdout

    # A repair turn builds on the last commit this script made, so that commit is the expected HEAD
    # and the scans cover only the new work. The review diff still runs from PKT/base.
    candidate = pkt / 'candidate'
    base = candidate.read_text().strip() if candidate.exists() else base
    if git('rev-parse', 'HEAD').strip() != base:
        sys.exit(f'HEAD moved off the expected commit {base}: the session must not commit')

    # A submodule's uncommitted or untracked files reach no parent commit, so refuse them before
    # anything is staged. Each checked-out submodule, nested ones too, reports only its own files
    # and moved gitlinks; the explicit options override any ignore setting in .gitmodules or config.
    # Paths stay bytes until os.fsdecode, so any valid file name survives.
    def dirty_submodules(repo, prefix):
        found = []
        listed = subprocess.run(['git', '-C', repo, 'ls-files', '-s', '-z'], capture_output=True, check=True).stdout
        # `git add -A` re-adds a gitlink dropped from the index but kept in HEAD, so scan HEAD's too.
        listed += subprocess.run(['git', '-C', repo, 'ls-tree', '-r', '-z', 'HEAD'], capture_output=True).stdout
        paths = dict.fromkeys(os.fsdecode(e.split(b'\t', 1)[1]) for e in listed.split(b'\0')
                              if e.startswith(b'160000 '))
        for path in paths:
            sub = Path(repo) / path
            if not (sub / '.git').exists():
                continue  # uninitialized: no files
            if os.path.realpath(sub) != os.path.join(os.path.realpath(repo), path):
                continue  # the path now runs through a symlink, so the checkout is not this submodule
            status = subprocess.run(['git', '-C', str(sub), 'status', '--porcelain', '--untracked-files=all',
                                     '--ignore-submodules=dirty'], capture_output=True, check=True).stdout
            if status.strip():
                found.append(prefix + path)
            found += dirty_submodules(str(sub), prefix + path + '/')
        return found

    dirty = dirty_submodules(wt, '')
    if dirty:
        shown = (''.join(c if c.isprintable() else repr(c)[1:-1] for c in p) for p in dirty)  # escape \r and such
        sys.exit('blocked: submodules with uncommitted or untracked files: ' + ', '.join(shown))
    git('add', '-A', '-N')  # so new files show in the diff
    status = git('status', '--porcelain')
    if not status.strip():
        sys.exit('nothing to commit')
    diff = git('diff', base)
    files = git('diff', '--name-only', base).split()
    added = [l for l in diff.splitlines() if l.startswith('+') and not l.startswith('+++')]
    print('== status\n' + status + '== stat\n' + git('diff', '--stat', base))
    blocked = []
    banned = cfg.get('banned_text')
    if banned:
        hits = [l for l in added if re.search(banned, l, re.I)]
        print('== banned text in added lines (must be empty)\n' + '\n'.join(hits))
        if hits:
            blocked.append('banned text in added lines')
    allowed = cfg.get('allowed_paths')
    if allowed:
        outside = [f for f in files if not any(f.startswith(p) for p in allowed)]
        print('== files outside the allowed paths (must be empty)\n' + '\n'.join(outside))
        if outside:
            blocked.append('files outside the allowed paths')
    look = [l for l in added if re.search(r'\bsorry\b|^\+\s*axiom\s|implemented_by|native_decide|\bunsafe\b', l)]
    print('== proof gaps or bypasses in added lines (inspect)\n' + '\n'.join(look))
    subject, body = pkt / 'commit-subject.txt', pkt / 'commit-body.txt'
    if not (subject.exists() and subject.read_text().strip()):
        blocked.append('commit-subject.txt missing or empty')
    else:
        message = subject.read_text().strip() + '\n\n' + (body.read_text().strip() if body.exists() else '')
        if banned and re.search(banned, message, re.I):
            blocked.append('banned text in the commit message')
    if blocked:
        sys.exit('blocked: ' + '; '.join(blocked))  # exit status 1 with the reasons on stderr
    if mode == 'check':
        return
    ident = cfg.get('identity')
    who = ['-c', f"user.name={ident['name']}", '-c', f"user.email={ident['email']}"] if ident else []
    git('add', '-A')
    subprocess.run(['git', '-C', wt, *who, 'commit', '-q', '-m', message.strip()], check=True)
    sha = git('rev-parse', 'HEAD').strip()
    (pkt / 'candidate').write_text(sha + '\n')
    print('committed ' + sha)


if __name__ == '__main__':
    main()
