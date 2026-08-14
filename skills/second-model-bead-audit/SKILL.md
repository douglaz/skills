---
name: second-model-bead-audit
description: >-
  Runs the default final launch-readiness audit for a polished bead graph against
  its plan. A read-only two-reviewer panel (Codex gpt-5.6-sol at xhigh plus Claude
  reviewer at high effort) independently checks coverage, ownership, bead quality,
  dependencies, priority, verification, and operational obligations; the
  orchestrator merges and reconciles their findings into one verdict. Use after
  bead-polish-loop by default, or when the user asks to sanity-check, audit, get a
  second opinion on, or approve beads before implementation. Prefer read-only
  review unless the user explicitly asks for bead edits.
argument-hint: "[plan/spec path] [--reviewers codex|claude|codex,claude]"
compatibility: >-
  Requires br, bv, jq, SHA-256 tooling (sha256sum or shasum), and GNU timeout
  (timeout or gtimeout) on PATH, plus a repo that uses .beads/. The full default
  panel also requires authenticated codex and claude CLIs. One available reviewer
  produces a DEGRADED audit; if no requested reviewer can run, the audit is
  BLOCKED.
---

# second-model-bead-audit

Give the polished bead graph a fresh, adversarial launch-readiness check before
implementation starts.

This is still called a second-model audit because at least one panel member should
be independent of the model lineage that built and polished the graph. The default
is now a panel, not one hand-picked alternate model: two independent reads expose
both shared findings and useful disagreements, and avoid making graph authorship a
prerequisite for choosing the reviewer.

## Default posture

- Run this audit after every non-trivial `bead-polish-loop`, not only for
  high-stakes launches.
- Keep the panel read-only. It reports exact fixes; `bead-polish-loop` owns normal
  graph mutation.
- Run both reviewers independently and in parallel. Never seed one with the
  other's findings or with your own conclusions.
- Treat panel findings as hypotheses to verify, not commands to obey.
- Do not proceed to implementation on `FAIL` or `CONDITIONAL PASS`. Resolve and
  re-audit every accepted condition first; any graph edit invalidates the old
  verdict.

The user may explicitly opt out for a tiny or low-risk graph. Record the skipped
gate rather than silently treating the polisher's own convergence judgment as an
independent audit.

## Inputs

Parse `--reviewers <list>` first. Valid values are `codex`, `claude`, and
`codex,claude`; the default is both. A model name (`fable`, `opus`) is accepted
where the slot name goes and pins that model instead of running the ladder. A
user-pinned one-reviewer audit is a
`PINNED PANEL`, not an availability failure, but it still lacks full-panel
agreement.

The remaining argument is the plan/spec path. If it is absent, discover the
relevant plan from the beads' spec refs and repo docs. Ask only when multiple
plausible source plans would materially change the coverage audit.

## Tool dependencies and panel health

The graph audit itself requires `br`, `bv`, `jq`, SHA-256 tooling (`sha256sum` or
`shasum`), and GNU `timeout` (`timeout` or `gtimeout`). If any is missing, stop
and tell the user. If their commands fail unexpectedly, flag a likely CLI-version
mismatch rather than inventing alternate syntax.

The default panel is:

| Reviewer | Invocation | Role |
|---|---|---|
| `codex` | `codex exec`, `gpt-5.6-sol`, `model_reasoning_effort="xhigh"`, read-only sandbox | Independent plan/graph audit with a custom rubric |
| `claude` | `claude -p`, `--model "$CLAUDE_MODEL" --effort high`, read-only tool set | Independent plan/graph audit with the same rubric |

`$CLAUDE_MODEL` is resolved by the ladder probe in
[multi-reviewer-loop/references/reviewer-panel.md](../multi-reviewer-loop/references/reviewer-panel.md)
§ Resolving the Claude reviewer's model. Record which model actually ran — the
report template has a field for it, and the independence rule below turns on it.

`jq` is used to build the common graph snapshot and unwrap the Claude JSON result.

- Both healthy: `FULL PANEL`.
- One missing, unauthenticated, timed out, or unusable: continue with the survivor
  and label the audit `DEGRADED`.
- No requested external reviewer runs successfully: `BLOCKED`. Do not silently
  replace the panel with the coordinating agent's self-review.
- A user-pinned reviewer that runs successfully: `PINNED PANEL`.
- Never turn an empty, truncated, ambiguous, or failed reviewer response into a
  clean vote.

Exact prompts, invocations, log layout, clean detection, and recovery rules live
in [references/reviewer-panel.md](references/reviewer-panel.md). Read that file
before launching the panel.

## Independence from the graph

Panel health and graph independence are different claims. Report both.

Determine who built or substantially polished the graph from session context or
`br show <id> --json` actor/history fields when practical. Do not delay the audit
just to establish authorship.

For each reviewer, label independence:

- `INDEPENDENT`: a different model family from the graph's builder/polisher.
- `BUILDER-LINEAGE`: the same model family; useful corroboration, but not the
  second opinion.
- `UNKNOWN`: graph authorship could not be established.

With a Codex-built graph, the Claude auditor supplies the independent vote; with a
Claude-built graph, Codex does. When authorship is mixed or unknown, the two-reviewer
panel is still stronger than guessing which single auditor to invoke.

**The label is relative to the graph's builder, and a fallback does not change who
that was.** The ladder stays inside the Claude family, so on a *Claude-built* graph a
`fable`→`opus` substitution was `BUILDER-LINEAGE` before and stays `BUILDER-LINEAGE`;
on a *Codex-built* graph the Claude auditor is `INDEPENDENT` whichever rung it landed
on. Do not downgrade it for matching the **coordinator** — the coordinator did not
build the graph, and on a Codex-built graph that downgrade would strip the label from
the one reviewer actually supplying the independent vote while leaving it on Codex,
which is the reviewer sharing lineage with the builder.

Coordinator-matching is worth **disclosing** rather than scoring. When the agent
running this audit is itself the model that filled the Claude slot, say so in the
panel roster: it is a separate process with its own context and a read-only tool set,
so it is not the self-review the panel-health rules forbid, but a reader deciding how
much the second opinion is worth should not have to infer it.

## Required outputs

1. Launch verdict: `FAIL`, `CONDITIONAL PASS`, or `PASS`; `NONE` when panel
   health is `BLOCKED`. State whether the § 3b coherence pass was run and what it
   found — a verdict on text nobody read end to end is worth less than it looks.
2. Audit quality: `FULL PANEL`, `DEGRADED`, `PINNED PANEL`, or `BLOCKED`.
3. Panel roster, model settings, exit health, and independence labels.
4. One merged report with blockers first and every finding tagged `BOTH`,
   `CODEX`, `CLAUDE`, or `CONFLICT`.
5. Exact bead-level fixes or proposed `br` actions where they are safe to state.
6. Disagreements and contradictions, plus the plan section or bead evidence that
   settled them.
7. Paths to the raw reviewer outputs and merged report.

A semantic `PASS` from a degraded or pinned audit must retain that quality label,
for example `PASS (DEGRADED)`. Only a healthy full panel can produce an
unqualified `PASS`. If no reviewer is `INDEPENDENT` from the known graph lineage,
also append `NO INDEPENDENT VOTE` to any pass label. A blocked audit produces no
launch verdict.

Only an unqualified `PASS` clears the gate automatically. A qualified pass
requires either a later healthy full-panel pass or the user's explicit,
recorded acceptance of the reduced review coverage.

## Workflow

### 1. Preflight and shared scope

1. Read `AGENTS.md`, `README.md`, the relevant plan/spec, and any graph-specific
   guidance.
2. Confirm the graph is meaningful and has already had a real polish pass. If it
   is raw, redirect to `bead-polish-loop`; the final gate should not substitute for
   routine cleanup.
3. Confirm `br`, `bv`, `jq`, the requested reviewer CLIs, and the exact
   `beads-jsonl-path` companion are available. The audit still runs `jq` itself for
   the graph snapshot and the Claude JSON result, so the companion owning its own
   `jq` check does not retire this one.
4. Define the audit scope explicitly:
   - authoritative plan/spec files, approved deltas, and recorded waivers
   - plan-backed root beads/epics and their child/dependency closure
   - the wider graph only for cross-scope dependencies and frontier health

   Do not label unrelated backlog beads as unplanned merely because
   `br list -a` includes them.
5. Flush once, capture one shared baseline, and fingerprint it before launching
   either reviewer:

   ```bash
   # An explicit sync propagates a real exit code, so require success. (Only the automatic
   # post-mutation flush swallows its error.) An unchanged graph legitimately reports no
   # diff, so do not also demand that the JSONL changed here.
   # A flush writes the whole gitignored beads.db cache over the tracked JSONL, so any bead
   # body hand-edited into the file (which does not advance updated_at) is silently
   # reverted — exit 0, no warning — and an audit over a truncated graph reviews text the
   # reviewers will never see. Check BEFORE flushing: afterwards the file matches the index
   # again, so the diff comes back empty and the loss is undetectable. Recovery is in
   # exact companion skill rb-lite-backlog-drain, step 11:
   # ../rb-lite-backlog-drain/SKILL.md#backlog-step-11.
   # Companion unavailable: stop, rerun the same installer command once, reload it, and
   # do not improvise this procedure.
   BEADS_JSONL_RESOLVER=$(
     (
       # Resolve the clean interpreter in a subshell. POSIX special-builtin precedence
       # prevents exported caller functions from redefining this trust path, and the
       # subshell leaves the caller's shell state untouched.
       POSIXLY_CORRECT=y
       export POSIXLY_CORRECT
       \unset -f command builtin exec unset 2>/dev/null || :
       _bjp_bash=$(command -p -v bash) || {
         printf '%s\n' 'cannot locate a trusted Bash for the beads JSONL locator — do NOT write' >&2
         exit 1
       }
       unset BASH_ENV ENV BASH_COMPAT BASH_LOADABLES_PATH BASH_XTRACEFD CDPATH GLOBIGNORE
       exec "$_bjp_bash" --noprofile --norc -p -s <<'__BJP_TRUSTED_BASH__'
   # Privileged Bash ignores inherited functions. Clear the other startup controls too,
   # then perform every candidate, worktree, provenance, and byte-agreement decision here.
   command unset BASH_ENV ENV BASH_COMPAT BASH_LOADABLES_PATH BASH_XTRACEFD CDPATH GLOBIGNORE || {
     printf '%s\n' 'cannot sanitize the beads JSONL locator shell environment — do NOT write' >&2
     exit 1
   }
   while command builtin read -r _ _ _bjp_function; do
     command unset -f -- "$_bjp_function" || {
       printf '%s\n' 'cannot sanitize the beads JSONL locator shell environment — do NOT write' >&2
       exit 1
     }
   done < <(command builtin declare -F)
   unset _bjp_function
   _bjp_git=$(command -p -v git) || {
     printf '%s\n' 'cannot locate a trusted Git for beads-jsonl-path — do NOT write' >&2
     exit 1
   }
   _bjp_cmp=$(command -p -v cmp) || {
     printf '%s\n' 'cannot locate a trusted cmp for beads-jsonl-path — do NOT write' >&2
     exit 1
   }
   _bjp_stat=$(command -p -v stat) || {
     printf '%s\n' 'cannot locate a trusted stat for beads-jsonl-path — do NOT write' >&2
     exit 1
   }
   _bjp_regular_link_count() {
     local path=$1 count
     if count=$("$_bjp_stat" -c %h "$path" 2>/dev/null) && [[ $count =~ ^[0-9]+$ ]]; then
       :
     elif count=$("$_bjp_stat" -f %l "$path" 2>/dev/null) && [[ $count =~ ^[0-9]+$ ]]; then
       :
     else
       return 1
     fi
     printf '%s\n' "$count"
   }
   _bjp_git_environment=( "${!GIT_@}" )
   for _bjp_git_variable in "${_bjp_git_environment[@]}"; do
     command unset -- "$_bjp_git_variable" || {
       printf '%s\n' 'cannot sanitize the Git environment for beads-jsonl-path — do NOT write' >&2
       exit 1
     }
   done
   unset _bjp_git_variable _bjp_git_environment

   BEADS_JSONL_RESOLVER=
   for _bjp_dir in "$HOME/.claude/skills/beads-jsonl-path" \
     "${CODEX_HOME:-$HOME/.codex}/skills/beads-jsonl-path" \
     "$HOME/.agents/skills/beads-jsonl-path"; do
     case $_bjp_dir in
       /*) ;;
       *) printf '%s\n' 'installed beads-jsonl-path target is not absolute — do NOT write' >&2; exit 1 ;;
     esac
     _bjp_candidate="$_bjp_dir/scripts/resolve-beads-jsonl"
     [ -x "$_bjp_candidate" ] || continue
     [ ! -L "$_bjp_candidate" ] || {
       printf '%s\n' 'installed beads-jsonl-path resolver is a symbolic link — do NOT write' >&2
       exit 1
     }
     _bjp_root_raw=$("$_bjp_git" --no-replace-objects -c core.fsmonitor=false rev-parse --show-toplevel 2>/dev/null) || {
       printf '%s\n' 'cannot resolve the current Git worktree — do NOT write' >&2
       exit 1
     }
     _bjp_root=$(
       CDPATH=
       export CDPATH
       cd -P -- "$_bjp_root_raw" 2>/dev/null && pwd -P
     ) || {
       printf '%s\n' 'cannot canonicalize the current Git worktree — do NOT write' >&2
       exit 1
     }
     _bjp_candidate_dir=$(
       CDPATH=
       export CDPATH
       cd -P -- "$_bjp_dir/scripts" 2>/dev/null && pwd -P
     ) || {
       printf '%s\n' 'cannot canonicalize installed beads-jsonl-path target — do NOT write' >&2
       exit 1
     }
     _bjp_candidate="$_bjp_candidate_dir/resolve-beads-jsonl"
     [ ! -L "$_bjp_candidate" ] || {
       printf '%s\n' 'installed beads-jsonl-path resolver is a symbolic link — do NOT write' >&2
       exit 1
     }
     case $_bjp_root:$_bjp_candidate_dir in
       /:/*|*:"$_bjp_root"|*:"$_bjp_root"/*)
         printf '%s\n' 'installed beads-jsonl-path target is inside the current Git worktree — do NOT write' >&2
         exit 1
         ;;
     esac
     _bjp_link_count=$(_bjp_regular_link_count "$_bjp_candidate") || {
       printf '%s\n' 'cannot inspect installed beads-jsonl-path resolver hard-link count — do NOT write' >&2
       exit 1
     }
     [ "$_bjp_link_count" = 1 ] || {
       printf '%s\n' 'installed beads-jsonl-path resolver has multiple hard links — do NOT write' >&2
       exit 1
     }
     unset _bjp_link_count
     unset _bjp_candidate_dir
     if [ -z "$BEADS_JSONL_RESOLVER" ]; then
       BEADS_JSONL_RESOLVER=$_bjp_candidate
     elif ! "$_bjp_cmp" -s "$BEADS_JSONL_RESOLVER" "$_bjp_candidate"; then
       printf '%s\n' 'installed beads-jsonl-path companions disagree — do NOT write' >&2
       exit 1
     fi
   done
   unset _bjp_candidate _bjp_root _bjp_root_raw _bjp_git _bjp_cmp _bjp_stat
   [ -n "$BEADS_JSONL_RESOLVER" ] || {
     printf '%s\n' 'beads-jsonl-path companion unavailable — do NOT write' >&2
     exit 1
   }
   printf '%s\n' "$BEADS_JSONL_RESOLVER"
   __BJP_TRUSTED_BASH__
     )
   ) || exit 1
   unset _bjp_candidate
   # Installed targets only. A relative `skills/beads-jsonl-path/scripts/resolve-beads-jsonl`
   # is whatever executable the audited repo planted there, and this snippet would run it.
   # From a checkout, run that checkout's copy by absolute path instead.
   [ -n "$BEADS_JSONL_RESOLVER" ] || {
     echo "beads-jsonl-path companion unavailable — do NOT flush" >&2
     exit 1
   }
   # --allow-dirty, and INSPECT rather than gate on cleanliness: the normal
   # bead-polish-loop handoff arrives with the round's intended `br` edits flushed and
   # uncommitted, so the owner's default clean-state mode would refuse the audit after
   # every non-noop round. Nothing tells an intended mutation from a hand edit — only
   # reading the diff can. Compare against HEAD, not the index: a damaged JSONL that is
   # staged makes a worktree-vs-index diff empty while HEAD still holds the good bodies.
   # `--allow-dirty` retains the owner's tracked stage-0, normal-flag, regular-mode proof
   # and drops byte identity only where the two commands below can still see the
   # difference — it refuses a write a file system monitor's cache is hiding from them.
   # The status and diff are both still required: status
   # distinguishes staged from unstaged intended edits, while the HEAD diff exposes both.
   BEADS_JSONL=$("$BEADS_JSONL_RESOLVER" --allow-dirty) || exit 1
   git --no-replace-objects -c core.fsmonitor=false --literal-pathspecs status --porcelain -- "$BEADS_JSONL" || { echo "cannot read the worktree — do NOT flush"; exit 1; }
   git --no-replace-objects -c core.fsmonitor=false --literal-pathspecs diff HEAD -- "$BEADS_JSONL" || { echo "cannot diff the JSONL — do NOT flush"; exit 1; }
   : "${BEADS_DIFF_REVIEWED:?read the two commands above, then set this to how you resolved it}"
   br sync --flush-only || { echo "flush failed"; exit 1; }
   # AND AGAIN AFTER. A clean pre-flush diff only means the worktree matched git — it says
   # nothing about the gitignored cache, so a stale DB introduces the damage HERE. Read
   # this before consuming the graph; auditing a truncated one reviews text the reviewers
   # will never see.
   git --no-replace-objects -c core.fsmonitor=false --literal-pathspecs diff HEAD -- "$BEADS_JSONL" || { echo "cannot diff the JSONL — do NOT audit"; exit 1; }
   : "${BEADS_POSTFLUSH_REVIEWED:?read the post-flush diff above before auditing}"
   br list --limit 0 --json -a
   bv --robot-triage
   bv --robot-plan
   bv --robot-suggest
   ```

   Add `bv --robot-insights`, `bv --robot-priority`, and targeted
   `br show <id> --json` when useful.
6. Create a unique audit directory and one neutral prompt containing the
   snapshotted requirement and graph paths, audit scope, categories, severity
   rules, and output contract. Do not include your conclusions or prior polish
   findings.

### 2. Run the panel

Start Codex and the Claude auditor in parallel with the same prompt. Close stdin on both batch
commands, persist stdout/stderr separately, and bound hangs with GNU `timeout`, which is
**required** — the prerequisites say to stop if it is missing, and the reference's snippet
`exit 1`s rather than run an unbounded panel.

The panel audits:

- plan-to-bead and bead-to-plan coverage
- duplicate or overlapping ownership
- vague, overloaded, undersized, or under-specified beads
- dependency direction, cycles, bottlenecks, and ready-frontier health
- priority and sequencing fit
- unit, integration/e2e, acceptance, and regression obligations
- logging, diagnostics, rollout, recovery, and operator-visible obligations
- scope growth or beads with no plan backing

Each reviewer must cite plan sections and bead IDs, propose bead-level remedies,
and state `No findings.` explicitly when clean.

Before parsing or merging findings, recompute the graph and requirement-source
fingerprints. Any drift during the panel invalidates every vote: report
`BLOCKED`, preserve the evidence, do not reset user state, and rerun only from a
stable new snapshot. Also reject contradictory or truncated reviewer output as
ambiguous rather than treating the presence of any finding tag as a usable audit.

### 3. Merge and reconcile

Merge on the underlying claim, not wording:

- `BOTH`: both reviewers found the same issue.
- `CODEX` / `CLAUDE`: only that reviewer found it.
- `CONFLICT`: one asserts a problem and the other explicitly says the same graph
  shape is correct.

Agreement increases confidence and review order; it does not replace verification.
Silence from the other reviewer is not counter-evidence. For every contradiction,
read the cited plan and beads yourself, decide with citations, and record which
reviewer was right.

Reject a finding only with concrete plan, bead, or graph evidence. If a proposed
fix adds work not required by the plan or a real delivery/verification risk,
record it as out of scope rather than expanding the graph reflexively.

Use [references/review-report-template.md](references/review-report-template.md)
for the synthesis.

### 3b. The coherence pass — read each bead end to end

Every panel round re-reads the beads, which sounds like it should catch anything. It
does not catch the defect class that a *long* loop creates: an edit that is correct
where it lands and falsifies a claim three sections away. Bead text is prose with
internal cross-references, so each fix is also a chance to contradict something the
bead already said.

**Entry:** the panel came back clean, OR you have applied fixes across two or more
rounds. The second trigger is the important one — do not wait for a clean panel to
check coherence, because incoherence is what keeps the panel from going clean.

**How, and this is the whole point: read, do not grep.** Open each bead's full text
and read it top to bottom, in order, as an implementer would. Targeted edits at cited
line numbers are what introduced the drift; more targeted edits will not find it. If
you catch yourself grepping for the phrase a reviewer quoted, you are repeating the
mistake.

Check, per bead and then across the set:

- **Title against scope.** A bead retitled or rescoped mid-loop often keeps its
  original first sentence, which is the line an implementer reads first.
- **Requirements against each other.** A decision made in one requirement can be
  forbidden by another written two rounds earlier.
- **Requirements against ACs.** The commonest failure: the prose is fixed and the AC
  that asserts the opposite survives, because the reviewer quoted the prose.
- **Both against the authority docs.** An ADR amended mid-loop leaves beads citing
  what it used to say — and beads that widened a rule the ADR never granted.
- **Work-already-done sections.** "On merge, also amend X" is stale once X is amended.
- **Superseded instructions.** "Delete the glossary entry for Y" is wrong once Y has
  been replaced rather than removed.
- **Counts, inventories and file lists.** These go stale silently and are cheap to
  re-derive. Re-measure them; do not carry them forward. A count that was true two
  rounds ago reads exactly like one that is true now.
- **Across the set:** every cross-bead dependency rationale. A bead that says "depends
  on X because Y" is wrong the moment X's own text stops claiming Y.

Fix by **re-authoring the bead** when the contradictions are structural rather than
local. A bead carrying half a dozen of them has been patched past the point where
patching converges; rewriting it from the settled decisions is faster and leaves
something an implementer can follow.

Then re-run the panel. A coherence fix is a graph change like any other.

**Why this is a phase and not advice.** Observed on a three-bead money-path set: four
panel rounds, findings *rising* each round, because most were the orchestrator's own
partial fixes coming back. One coherence pass found eleven contradictions in a single
bead — including its own title contradicting its scope, an AC demanding exactly what a
requirement forbade, and a smoke-conversion count wrong by a factor of two — and
resolved more than the previous two rounds combined. `multi-reviewer-loop` § 4b makes
the same argument for diffs; bead graphs need it more, because prose has no compiler.

- `FAIL`: any blocking coverage, ownership, dependency, execution, or verification
  defect remains.
- `CONDITIONAL PASS`: no blocker, but one or more named important conditions must
  be fixed before the intended launch shape is safe.
- `PASS`: no blocking or important findings remain; optional nits may remain, AND
  § 3b has been run on the current text. A panel can only see what it was asked to
  look at; a bead that contradicts itself can pass every round, because each reviewer
  reads the section it was pointed at. Do not issue `PASS` on a set that has been
  edited across rounds without a coherence pass over it.

Reviewer verdict votes are evidence, not a majority election. The orchestrator
owns the final verdict and must explain any departure from either vote.

### 5. Handoff and re-audit

Normal mode is report-only:

- `PASS`: proceed to implementation.
- `CONDITIONAL PASS` or `FAIL`: send accepted findings into
  `bead-polish-loop`'s ledger, fix them there, then rerun the full panel.

If the user explicitly asks this skill to apply fixes, mutate only reconciled,
clearly justified items with `br`, flush with `br sync --flush-only`, and rerun the
panel before upgrading the verdict. Never let a reviewer edit the graph directly.

Bound an automatic polish/audit cycle to three panel runs. Stop earlier when the
same material finding survives two genuine fix attempts, the graph drifts during
review, reviewer health is blocked, or an architecture/product decision is
required. Surface the remaining issue instead of recursively invoking the two
skills forever.

**When findings RISE across rounds, suspect your own fixes before the graph.** A
panel that returns more blockers than last time is usually not finding new defects —
it is finding the contradictions the last round's edits introduced. Two tells: the
same finding returns in new wording after you "fixed" it, and reviewers begin citing
your own text against itself. Neither is answered by another round. Run § 3b, then
re-panel.

Stop and ask for a product/architecture decision when a finding exposes ambiguity
in the plan rather than a bead-quality defect.

## Command palette

```bash
br list --limit 0 --json -a
br show <id> --json
br update <id> --description "..."
br close <id> --reason "..."
br dep add <issue> <depends-on>
br dep remove <issue> <depends-on>
br lint
bv --robot-triage
bv --robot-plan
bv --robot-suggest
bv --robot-insights
bv --robot-priority
br sync --flush-only
```

## Failure patterns to avoid

- choosing only the presumed alternate model when both reviewers are available
- running reviewers sequentially or showing one the other's conclusions
- giving reviewers the polish findings and creating an echo chamber
- calling a one-reviewer, failed, empty, or ambiguous panel an unqualified pass
- counting reviewer votes instead of reconciling claims against the plan and graph
- dismissing a single-source finding because the other reviewer stayed silent
- letting either reviewer mutate beads
- nitpicking wording while missing absent work, dependency errors, or test gaps
- expanding the graph for speculative hardening with no plan or delivery need

## Pipeline context

This is the default final gate in the bead lifecycle:

1. `plan-to-beads-transfer` — create executable memory from a stable plan.
2. `bead-polish-loop` — iteratively refine the graph.
3. `second-model-bead-audit` — run the read-only reviewer panel and issue the
   launch verdict.

The gate is part of normal completion, not an optional high-stakes add-on. A
failed or conditional audit loops back to polishing and then through this gate
again.
