# DRIVE — execute the open skills safety and correctness backlog

**Scope:** exactly the 29 GitHub issues in the #30–#66 set enumerated by
`docs/specs/backlog-execution-plan.md`; the Beads graph is the only work. GitHub
#67 is out of scope.
**Scope-Label:** `drive-open-issues`
**Phase:** SHAPE · **Bead:** E3 split · **Branch:** `shape/e3a-e3b-split`
**Pending:** —
**Gate:** `./check.sh`

## Done

- E1 (`skills-iog`) is closed; it is the prerequisite for the new E3a admission
  bead.
- The reviewed final shape splits E3 into E3a exact `br` admission/typed selection
  and E3b native closure/consumers. Rule 9 is the sole metadata-closure lifecycle
  owner; E3a has only its one-time coordinator bootstrap provider, and merged E3b
  supplies reusable Step 11.
- The planned GRAPH delta is bounded: create E3a depending on closed E1; change
  `skills-dhm` to depend on E3a; retain its identity and all 15 dependents; update
  descriptions only for `skills-dta`, `skills-xfd`, `skills-qmi`, `skills-rrk`,
  new E3a, and E3b `skills-dhm`. Do not edit Beads in this SHAPE pass.

## Now

E3a is scoped to exactly: two-form resolver parsing/refusal 22; pinned binary
validation/identity/OID/dispatch 32; atomic fixed-sibling selector admission/exec
18; selector entry/argv/private temp lifecycle 30; clean locator/OID snapshot/query
capture 32; scoped lane validation/typed output 56; generic validation/typed output
34; `drive-status` zero-`br`/no-inference 17; production API/consumer docs 36;
plan/global/table/frontier sync 23; gate wiring 2 = **302 production lines**;
**906 production lines** is the exact BUILD budget (`3 × 302`).

E3b is scoped to exactly: clean Bash entry/opaque input guards 18;
standalone/pinned-where/import/target preflight 26; native close/strict flush 6;
snapshot/no-DB/structural/literal proof 38; two-state retained-clone resume 12;
Step-11 branch/Pending/review/lease/merge procedure 24; forge resume discovery 28;
Drive/LAND/harden consumer links 12; E1 consumer note 3; versioned ADR 12;
plan/global/consumer/table sync 28; gate wiring 1 = **208 production lines**;
**624 production lines** is the exact BUILD budget (`3 × 208`).

## Next

Transition reviewed spec → graph transfer: create E3a only, transfer its closed-E1
edge and `skills-dhm`→E3a edge, keep all 15 `skills-dhm` dependents unchanged, and
confirm E3a alone is ready. Then E3b alone is ready; normal scheduling starts only
after E3b work and its rule-9 closure merge.

## Standing decisions

- Tests and fixtures are not production LOC and remain outside the production
  budgets; they still require relevant, mutation-sensitive coverage and the normal
  gate.
- Rule 7 remains the existing lane reservation. It is not a closure lock; rule 9
  owns the closure lifecycle and Step 11 is its post-E3b production provider.
