# Behavioural claims in prose

The managed block carries this rule in one paragraph, because it is copied into every repo
and bloat there gets ignored wholesale. This file is the long form — the incident it came
from, what a sufficient record looks like, and the two distinctions that are easy to state
and hard to apply. It stays in this repository; it is not part of the copied block.

## The incident

One documentation branch (`douglaz/skills` #40) carried four one-line rules between sibling
sites. Landing it took **8 codex bot rounds, 5 local panel passes, 13 corrections** — and
the corrections were overwhelmingly to *sentences*, not code:

| claimed | measured |
|---|---|
| `git status --porcelain -- ""` succeeds printing nothing | exit 128, `fatal: empty string is not a valid pathspec…` |
| an empty-filename redirect is silent | exit 1, `: No such file or directory` |
| "Measured on git 2.54 / jq 1.7" | the host ran jq 1.8.2; that run never happened |
| the removal check returns 0 "because `wc` succeeds" | under `pipefail` it exits 2; `\|\| true` swallows it |
| a held `.git/index.lock` makes `git status` fail | exit 0, on both a clean and a dirty tree |

Every one sat beside a **correct** fix. Three were introduced by the commit fixing the
previous one, including one by the commit whose own message named this failure mode. Every
test suite was green throughout, because suites do not read prose.

That is the argument for the rule: a wrong reason is worse than no reason, because it
invites the next agent to "simplify" the guard away — the stated justification is
disprovable in thirty seconds, so it reads as evidence the guard is confused.

## What a record looks like

Separate the streams with redirection. Hand-labelled comments on merged output assert
provenance rather than showing it — rerun in a terminal or CI log that combines file
descriptors and nothing distinguishes the two:

```console
$ git status --porcelain -- "" >/tmp/o 2>/tmp/e ; echo "status=$?"   # git 2.54.0
status=128
$ wc -c </tmp/o
0
$ cat /tmp/e
fatal: empty string is not a valid pathspec. please use . instead if you meant to match all paths
```

The redirection *is* the evidence for "nothing on stdout". A reader can re-run it and
disagree, which is the whole test.

## Observing is not explaining

A rerun gives the exit code and the streams; it never gives the *why*. A command can fail
for several config- or environment-dependent reasons, so `X fails because Y` needs Y varied
on its own with the outcome changing, or the documentation or source cited.

The cheapest instance, and the one that shipped wrong on #40 — note it takes **two** runs,
because the second is the counterfactual:

```console
$ bash -c '{ grep -Fo -- x "" | wc -l ; } >o1 2>e1 ; echo "status=$?"'   # bash 5.3.9, GNU grep 3.12
status=0
$ cat o1 ; cat e1
0
grep: : No such file or directory
$ bash -c 'set -o pipefail; { grep -Fo -- x "" | wc -l ; } >o2 2>e2 ; echo "status=$?"'
status=2
$ cat o2 ; cat e2
0
grep: : No such file or directory
```

Identical output, different status. So "the count came back 0 because `wc` succeeded" is
settled only by the pair — one run re-blesses the wrong component, which is exactly what
happened.

## A claim you cannot run is not yours to assert

A version you do not have, a kernel path you cannot force. Say it is unmeasured and narrow
it to a possibility. "Behavior may differ on older git — unmeasured here" costs one word
over "behavior differs", and only one of them is a claim you can be wrong about.

## The honest cost

This rule is meaningfully harder to satisfy than to state. The pull request that introduced
it needed **ten corrections to its own text across three review rounds**, every one an
instance of the defect the rule names, and three of them found by pointing the rule at
itself — including a transcript that misquoted its own output, an example that failed the
standard it was demonstrating, and a gate claim recorded as a date rather than a commit.

That is not an argument against the rule. It is the measurement of how invisible this class
of error is without one, and it should be quoted to anyone who thinks the rule is obvious.
