# Behavioural claims in prose

The managed block carries this rule in one paragraph, because it is copied into every repo
and bloat there gets ignored wholesale. This file is the long form — the incident it came
from, what a sufficient record looks like, and the two distinctions that are easy to state
and hard to apply. It stays in this repository; it is not part of the copied block.

## The incident

One documentation branch (`douglaz/skills` #40) carried four one-line rules between sibling
sites. Landing those four took **8 codex bot rounds, 5 local panel passes, 13 corrections**
— the corrections outnumbering the rules, and overwhelmingly to *sentences* rather than
code. Five of them were false statements about tool behaviour, recorded here as they were
corrected in that branch's review; the command, version and captured output for each are in
its commit history rather than restated below, since this table is a summary of prior
corrections and not itself new evidence:

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

Run this one **inside a git repository**: outside one it also exits 128 with an empty
stdout, so two of the three recorded lines match for entirely the wrong reason and only
the stderr gives it away.

```console
$ ( set +e                            # these commands FAIL on purpose; under `set -e`
>   d=$(mktemp -d) || exit 1          # the subshell dies before recording anything
>   trap 'rm -rf "$d"' EXIT           # `||` not `&&`: on failure d is empty -> /o
>   git status --porcelain -- "" >"$d/o" 2>"$d/e"
>   echo "status=$?" ; wc -c <"$d/o" ; cat "$d/e" )      # git 2.54.0
status=128
0
fatal: empty string is not a valid pathspec. please use . instead if you meant to match all paths
```

Two things are being shown and they should not be conflated: the redirection establishes
**where** each stream went, and `wc -c <"$d/o"` returning 0 establishes that stdout was
**empty**. Redirection alone proves provenance only — a record that captures streams and
never inspects them has shown nothing about their contents. A reader can re-run both and
disagree, which is the whole test.

## Observing is not explaining

A rerun gives the exit code and the streams; it never gives the *why*. A command can fail
for several config- or environment-dependent reasons, so `X fails because Y` needs Y varied
on its own with the outcome changing, or the documentation or source cited.

The cheapest instance, and the one that shipped wrong on #40 — note it takes **two** runs,
because the second is the counterfactual:

Pin the baseline explicitly. `bash -c` inherits `pipefail` when the parent exports
`SHELLOPTS`, and a contaminated baseline reports 2 where it should report 0 — so if BOTH
children were left unpinned the pair would read 2 vs 2, with nothing in the output saying
why. The run below pins only the second, which is what makes the contamination visible:
`unpinned=2` against `pinned=0`. (Note `set +e` here precedes the export, so `SHELLOPTS`
carries `pipefail` and not `errexit`. Order matters for what gets inherited. The exact
`SHELLOPTS` string depends on the parent shell — interactive parents add `history`,
`emacs` and more — so what must reproduce is the presence of `pipefail` and the absence
of `errexit`, not the literal list.)
Shown rather than asserted, because a warning about unverifiable claims has no business
being one:

```console
$ ( set +e ; set -o pipefail ; export SHELLOPTS    # bash 5.3.9
>   bash -c '{ grep -Fo -- x "" | wc -l ; } >/dev/null 2>&1 ; echo "unpinned=$?"'
>   bash --noprofile --norc -c 'set +o pipefail; { grep -Fo -- x "" | wc -l ; } >/dev/null 2>&1 ; echo "pinned=$?"' )
unpinned=2                                     # baseline contaminated
#   measured: under a contaminated parent, `set +o pipefail` alone gives 0 and
#   `--noprofile --norc` alone still gives 2 — the flags do not pin the mode. They
#   are kept only to keep rc/profile files out of the run.
pinned=0                                       # `set +o pipefail` is the pin
```

With that established, the experiment itself:

```console
$ ( set +e ; d=$(mktemp -d) || exit 1 ; trap 'rm -rf "$d"' EXIT ; export d
>   bash --noprofile --norc -c 'set +o pipefail; { grep -Fo -- x "" | wc -l ; } >"$d/o1" 2>"$d/e1" ; echo "status=$?"'
>   cat "$d/o1" "$d/e1"
>   bash --noprofile --norc -c 'set -o pipefail; { grep -Fo -- x "" | wc -l ; } >"$d/o2" 2>"$d/e2" ; echo "status=$?"'
>   cat "$d/o2" "$d/e2" )              # bash 5.3.9, GNU grep 3.12, coreutils 9.11
status=0
0
grep: : No such file or directory
status=2
0
grep: : No such file or directory
```

`wc`'s version is recorded because `wc` is one of the two commands whose status the
experiment is about. Both captures go to a `mktemp -d` directory with a cleanup trap, not
to fixed names: these snippets exist to be re-run, and a predictable `/tmp/o` on a shared
host can already be a symlink that redirection follows and truncates before the command
starts — while bare `o1`/`e1` litter whatever directory the reader is standing in. And the
creation is checked with `||`, not chained with `&&`: on failure `&&` skips only the trap,
leaving `d` empty so the *next* command redirects to `/o` at the filesystem root. That is
the unchecked-`mktemp` defect this repo fixed at four sites in #40, which is how thoroughly
this class recurs. Each example is one **subshell**, so its `EXIT` trap fires the moment the
example ends: a single-quoted trap expands `$d` at exit, so in an interactive shell a reader
who reassigns `d` afterwards gets `rm -rf` on the *new* value. Shown with `echo` in place of
`rm -rf`, so the record is complete without being destructive:

```console
$ ( set +e ; orig=$(mktemp -d) || exit 1 ; victim=$(mktemp -d) || exit 1 ; d="$orig"
>   trap 'echo "trap would run: rm -rf $d" ; rm -rf "$orig" "$victim"' EXIT
>   echo "registered with d=$d" ; d="$victim" ; echo "reassigned  d=$d" )
registered with d=/tmp/tmp.mkZzPEd1Zj
reassigned  d=/tmp/tmp.4TTmbbLLqg
trap would run: rm -rf /tmp/tmp.4TTmbbLLqg          # bash 5.3.9 — the VICTIM

# mktemp randomises, so YOUR paths will differ; what must reproduce is that the
# third line names the SECOND directory, not the first.
```

The cleanup uses `$orig`/`$victim`, which nothing reassigns, so the demonstration
removes both directories while still showing `$d` resolving late.

Identical stdout, identical stderr, **different status** — and the status is the only thing
that moved, so the status is the only thing this pair explains. It settles
"the pipeline *reported* 0 because `wc`, the last command, succeeded": remove `pipefail`
and grep's failure is invisible; add it and the 2 surfaces. It does **not** explain why the
count is 0 — that is unchanged in both runs, so nothing here bears on it. Matching the
conclusion to the varied condition is the whole discipline; drifting from "the status
was 0" to "the count was 0" is how a correct experiment gets written up as the wrong
claim.

Capture the status before anything else runs on that line. Expansions happen left to right,
so a command substitution *earlier* in the word completes before a *later* `$?` is expanded,
and `$?` then reports the substitution rather than the command you meant:

```console
$ bash -c 'false; echo "count=$(printf 0) status=$?"'   # bash 5.3.9
count=0 status=0
$ bash -c 'false; echo "status=$? count=$(printf 0)"'
status=1 count=0
```

Same command, same two expansions, opposite order, opposite answer. `st=$?` on its own line
removes the question. Recorded because this file first got the *mechanism* backwards — it
claimed the substitution clobbers `$?` regardless of position, having observed a real
failure (the first form) and explained it with the wrong cause. Which is the section above,
happening to the section above.

## A claim you cannot run is not yours to assert

A version you do not have, a kernel path you cannot force. Say it is unmeasured and narrow
it to a possibility. "Behavior **may** differ on older git — unmeasured here" adds one word
to "Behavior differs on older git — unmeasured here", and only one of the two is a claim you
can be wrong about. The modal does not supply evidence — it is still unverified, and a
reader who needs the answer must go and measure it. What it buys is honesty about which of
those two states you are in.

## The honest cost

This rule is meaningfully harder to satisfy than to state. The pull request that introduced
it (`douglaz/skills` #46) required at least one correction in each of its **first six**
review rounds — a bounded historical fact rather than a present universal, which would
refute itself on the first clean round, i.e. exactly the event needed to land. Its commit
history carries the per-round detail, deliberately not restated here, since a running count
asserted in prose goes stale the next round and this file is about not doing that. Every one was an
instance of the defect the rule names. Several were found by pointing the rule at itself:
a transcript that misquoted its own output, an example that failed the standard it was
demonstrating, a gate claim recorded as a date rather than a commit, hand-labelled streams
that asserted provenance instead of showing it, and a counterfactual whose conclusion named
a different quantity than the one it varied.

That is not an argument against the rule. It is the measurement of how invisible this class
of error is without one, and it should be quoted to anyone who thinks the rule is obvious.
