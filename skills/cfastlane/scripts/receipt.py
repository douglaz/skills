#!/usr/bin/env python3
"""Write the reproduction receipt the reviewer reads: PKT/manifest.json.

  receipt.py PKT [EVIDENCE_FILE ...]

Run it after the commit, the diff (fastlane's make-diff.sh into PKT/diff.patch) and the live run.
It records the commit, its tree, whether the worktree is clean, the diff's sha256 and line count,
the changed files, the scan of added lines, and for each EVIDENCE_FILE its sha256 and, for a JSON
file or a unit's exit file, its content. Reviewers are read-only and cannot run the check
themselves; this file is how they know which bytes were tested and what the run said. Nobody edits
it by hand.
"""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    pkt = Path(sys.argv[1]).resolve()
    cfg = json.loads((pkt / 'config.json').read_text())
    wt, base = cfg['worktree'], (pkt / 'base').read_text().strip()

    def git(*args):
        return subprocess.run(['git', '-C', wt, *args], capture_output=True, text=True, check=True).stdout.strip()

    patch = pkt / 'diff.patch'
    diff = patch.read_text()
    added = [l for l in diff.splitlines() if l.startswith('+') and not l.startswith('+++')]
    evidence = []
    for name in sys.argv[2:]:
        path = Path(name).resolve()
        data = path.read_bytes()
        row = dict(path=str(path), sha256=hashlib.sha256(data).hexdigest(), bytes=len(data))
        if path.suffix == '.json':
            row['content'] = json.loads(data)
        elif path.name == 'exit':
            row['content'] = data.decode().strip()
        evidence.append(row)
    head = git('rev-parse', 'HEAD')
    candidate = pkt / 'candidate'
    manifest = dict(
        commit=head, base=base, tree=git('rev-parse', 'HEAD^{tree}'),
        commit_is_candidate=candidate.exists() and candidate.read_text().strip() == head,
        worktree_clean=git('status', '--porcelain') == '',
        diff_sha256=hashlib.sha256(patch.read_bytes()).hexdigest(), diff_lines=len(diff.splitlines()),
        files=git('diff', '--name-only', base, 'HEAD').splitlines(),
        scans=dict(added_lines=len(added),
                   proof_gaps_or_bypasses=[l for l in added if re.search(
                       r'\bsorry\b|^\+\s*axiom\s|implemented_by|native_decide|\bunsafe\b', l)]),
        evidence=evidence,
        note='Written by a script after the commit and the live run; not edited by the author or a reviewer.')
    (pkt / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({k: manifest[k] for k in
                      ('commit', 'commit_is_candidate', 'worktree_clean', 'diff_sha256', 'diff_lines')}))


if __name__ == '__main__':
    main()
