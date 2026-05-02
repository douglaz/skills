---
name: complexity-reducer
description: >-
  Reduce code complexity by deleting, collapsing, inlining, and simplifying
  code while preserving behavior. Use when asked to simplify, shrink,
  de-abstract, reduce LOC, remove ceremony, flatten control flow, delete dead
  code, or make code easier to understand, especially in Rust codebases and
  also in Bash or other languages.
---

# complexity-reducer

Make code smaller, flatter, and easier to reason about while preserving
observable behavior. Prefer deletion over addition, direct code over
indirection, and boring explicit code over generic infrastructure.

## Non-Negotiables

- Preserve behavior unless the user explicitly asks for behavior changes.
- Preserve public APIs, CLI flags, file formats, protocols, persistence
  semantics, exit codes, and error semantics unless the user explicitly allows
  changing them.
- Do not add dependencies.
- Do not introduce new layers, services, managers, factories, engines,
  registries, adapters, traits, interfaces, macros, or generic frameworks.
- Keep each patch focused on one simplification theme when feasible.
- Treat a net-positive LOC patch as suspicious; justify it before proceeding.
- Avoid touching unrelated code or reverting unrelated user changes.

## Simplification Order

Apply this order before considering a rewrite:

1. Delete unused code, flags, fields, enum variants, modules, test helpers, or
   configuration paths.
2. Merge duplicate branches, duplicated setup, duplicate tests, or split logic
   that always changes together.
3. Inline one-off wrappers, builders, adapters, trait implementations,
   callbacks, and pass-through functions.
4. Collapse needless state machines, async/concurrency, caching, retries,
   queues, and background tasks when only one path is used.
5. Rewrite only when deletion, merging, and inlining are not enough.

Add a helper, type, trait, interface, module, or abstraction only if it removes
at least two existing call sites or collapses repeated logic enough to reduce
overall conceptual surface area.

## Workflow

1. Establish scope from the user's request. If no scope is given, inspect the
   current branch diff against `origin/main` or `origin/master`; fetch first
   when remote refs may be stale.
2. Record the baseline: changed files, likely test commands, rough LOC or item
   counts if cheap, and relevant public API boundaries.
3. Search for simplification candidates before editing.
4. Produce a short plan with what will be removed, why behavior is preserved,
   risk, expected LOC direction, and validation command.
5. Apply the smallest high-confidence deletion first.
6. Validate with the repo's standard tests, formatting, and linting for the
   touched area.
7. If behavior preservation becomes uncertain, revert that simplification or
   stop and explain the uncertainty.

End with deletions made, behavior-preservation argument, tests run, rough
before/after metrics when available, remaining opportunities, and changes
intentionally not made.

## Rust Tactics

Prefer Rust simplifications that reduce concepts without weakening correctness:

- Delete traits with one implementor unless the trait is part of a public API,
  test seam, or real extension point.
- Inline builders used once, especially when a struct literal or direct
  constructor is clearer.
- Collapse wrapper structs, newtypes, and modules that only forward calls,
  unless they enforce an invariant or protect a public boundary.
- Replace custom parsing, path handling, iteration, sorting, locking, retry, or
  error plumbing with standard library or already-present crate behavior.
- Remove dead enum variants, fields, feature flags, cfg paths, and match arms
  only after checking construction and serialization/deserialization behavior.
- Prefer concrete types over generics when there is only one real type.
- Prefer ordinary functions over macros unless the macro materially removes
  repeated unsafe or syntax-heavy code.
- Keep `Result` and error context when callers depend on failure distinctions;
  simplify formatting and wrapping only when error semantics stay equivalent.
- Simplify lifetimes by owning data only when it does not introduce meaningful
  allocation, copying, or API churn.
- Avoid replacing clear match statements with clever combinator chains when it
  makes control flow harder to trace.

Rust validation candidates include `cargo test`, focused package tests,
`cargo fmt --check`, `cargo clippy -- -D warnings`, doctests, snapshot tests,
and CLI smoke checks.

## Bash And Other Languages

Use the same deletion-first stance outside Rust:

- In Bash, delete unused variables, flags, functions, traps, temporary files,
  subshells, command pipelines, and compatibility branches.
- Collapse wrappers around a single command when the wrapper does not enforce
  quoting, cleanup, retry, or error handling.
- Keep `set -euo pipefail`, quoting, cleanup traps, and explicit error checks
  when they protect behavior.
- Prefer existing POSIX or Bash builtins over custom parsing only when
  portability requirements permit it.
- Preserve exit codes, stdout/stderr shape, prompts, environment variables, and
  filesystem side effects.
- For other languages, map the same principles to local constructs: one-off
  interfaces, unused classes, needless factories, duplicate adapters, custom
  standard-library replacements, and dead configuration paths.

## Rejection Criteria

Reject or revise a simplification if it:

- Increases conceptual surface area.
- Introduces a new abstraction name without deleting substantially more.
- Makes control flow harder to trace.
- Spreads one concept across more files.
- Requires more context to understand than the original.
- Changes behavior without explicit permission.
- Cleans up a local spot while increasing global complexity.

The success metric is less code, fewer concepts, fewer paths, and equal
behavior.
