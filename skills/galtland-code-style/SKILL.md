---
name: galtland-code-style
description: >-
  Apply or review the galtland Rust code-style conventions: anyhow-based error
  handling with layered Results and invariant-asserting context messages,
  enum-variant-path-prefixed log messages with levels chosen by actionability,
  XxxInfo parameter-object structs, Client/daemon naming pairs, scoped consts,
  clone-into-closure blocks, module-granular import formatting, and
  TODO/FIXME/todo!() discipline. Use when writing Rust code that should match
  this style, setting up rustfmt/clippy for a project, or when asked to review
  a Rust codebase for style, error handling, logging quality, or convention
  conformance ("review the style", "make this consistent", "clean up the error
  handling/logging", "set up rustfmt"). Also knows which habits from the
  original 2022 codebase are legacy quirks that must NOT be replicated.
---

# galtland-code-style

Rust conventions distilled from galtland, filtered through a legacy audit: only
the era-independent, deliberate choices are prescribed here. Two modes:

- **Apply** — write or refactor code to match these conventions.
- **Review** — audit a codebase for conformance and for the legacy quirks.

For review mode, read `references/legacy-quirks.md` too — it lists dated habits
to flag (and to avoid reintroducing when applying).

## Formatting (rustfmt)

Install this `rustfmt.toml` — five lines, nothing restating defaults:

```toml
unstable_features = true   # the four options below are still nightly-only
imports_granularity = "Module"
group_imports = "StdExternalCrate"
reorder_impl_items = true
blank_lines_upper_bound = 2
```

These options remain nightly-only (verified on rustfmt 1.8.0-stable, 2025:
stable warns and ignores them). Format with `cargo +nightly fmt` and pin the
expectation so it's enforced, not aspirational: a CI job running
`cargo +nightly fmt --check` (formatting-only nightly is fine even when the
build is stable). Without that pin, contributors on stock stable silently
produce differently-shaped files. Do not add keys that restate rustfmt
defaults — config files should contain only intent.

What this buys: every file opens with three import blocks (std / external /
crate), one `use` per parent module with items merged in braces, no
multi-module nested trees; consts sort above fns in impls so a type's tuning
knobs read first. The uniform header shape makes unfamiliar files scannable.
(Note: `imports_granularity` merges/splits braces but does NOT expand
`use foo::*` — to actually forbid globs, add
`clippy::wildcard_imports = "warn"`.)

## Error handling

- **`anyhow` for application and internal leaf code.** The boundary isn't
  "published to crates.io" — it's "does a caller branch on the failure?" Any
  crate, even an internal workspace one, whose callers need to match on *why*
  something failed (retry this, surface that, ignore the other) should expose a
  typed error (`thiserror`) at that boundary. Everywhere below it — where a
  failure just propagates up with context — `anyhow`. galtland used `anyhow`
  even in its library crate because nothing downstream branched; don't
  generalize that to "libraries use anyhow."
- **Layered `Result`s are the error taxonomy.** Keep
  `anyhow::Result<Result<T, RemoteError>>`-style nesting when the layers mean
  different things (local failure vs transport failure vs remote refusal) and
  callers act differently on each. Match `Ok(Ok(..))` explicitly. Flatten only
  at the layer that genuinely treats them alike.
- **`anyhow::bail!(...)` over `return Err(anyhow!(...))`** — always
  equivalent, less noise.
- **`.context()` messages state the violated invariant**, not a restatement of
  the operation: `context("Expected receiver to be still up")` tells the
  debugger what assumption broke. When using `expect`, justify unreachability
  in the message (the `; qed` convention for proofs is welcome).
- **A dropped reply-channel receiver is an event, not an error**: prefer
  `if reply.send(x).is_err() { log::warn!("requester of {key:?} went away") }`
  over `?`-propagating a send error — the peer dying must not crash the
  server side.
- **`#[must_use]` on response/verdict enums** whose silent dropping would be a
  bug (protocol responses, access-control decisions).
- **Errors that cross serialization boundaries** (wire, IPC): stringify as late
  as possible, keep structure until then. `Result<T, String>` is fine only when
  the far side just *displays* the error. If the far side *decides* on it
  (retry, ban, fall back to another peer), send a serializable error
  enum/code — a bare string forces the receiver to parse prose. galtland used
  `Result<T, String>` on the wire and flagged its own cost
  (`//FIXME: too many errors converted to string`); treat that as the ceiling,
  not the target.

## Logging

- **Prefix each message with the exact variant/state being handled**:
  `log::debug!("Command::GetRecord will request {key:?}")`,
  `info!("SwarmEvent::ConnectionEstablished {peer}")`. The log becomes a
  grep-able trace of the state machine — a variant name in a log line lands
  you on the handling code.
- **Choose level by actionability**: `trace` = loop ticks; `debug` = every
  command/request; `info` = lifecycle and topology changes; `warn` = peer or
  input misbehavior (bans, invalid data); `error` = reserved for crashed
  tasks/broken invariants. If everything is `error`, nothing is.
- **Inline format captures only**: `log::warn!("banning {peer} for {reason}")`,
  never positional `{}` with trailing args. Enforce with
  `clippy::uninlined_format_args`.
- **If the project uses `tracing` instead of `log`** (preferable for a real
  async service — spans tie a request's logs together), keep the same
  discipline but move structure out of the string: variant/state as the event
  name or `target`, and the peer id / request id / offset as *fields*
  (`debug!(target: "get_record", %key, "requesting")`) rather than
  interpolated into prose. You keep the grep-by-variant property and gain
  filterable structured fields.

## Naming and structure

- **Parameter-object `XxxInfo` structs** for functions taking 3+ related
  arguments; destructure on the first line
  (`let PublishInfo { key, sender } = info;`). Call sites read like keyword
  arguments; adding a field doesn't ripple through signatures.
- **Command enums with imperative variant names** (`Die`, `GetPeers`, `Feed`)
  paired with an `XxxClient` struct in the same file, one async method per
  variant.
- **Scoped constants at point of use**: a threshold used by one paragraph of
  logic is declared in that block —
  `{ const MAX_CONSECUTIVE_ERRORS: usize = 3; ... }` — not hoisted to the
  module top. Constants used across an impl go at the top of the impl (rustfmt
  sorts them there).
- **`let x = { ... };` block-expression initialization** for anything needing
  multi-step setup, instead of mutation-after-declare or one-shot helper fns.
- **Clone-into-closure via braced argument**:
  `spawn({ let client = client.clone(); async move { ... } })` — clones stay
  scoped to the spawn expression; no `client2`/`_clone` names polluting the
  enclosing scope.
- **`@`-bindings on grouped match arms** to capture-and-log without
  restating: `other @ (State::Banned | State::StillBanned) => debug!("{other:?}")`.
- **`spawn_and_log_error`-style wrappers** for every fire-and-forget task —
  a background task whose `Result` vanishes is a silent failure factory.

## Comments and doubt

- Comment *why*, at decision points: the unbounded-channel rationale, the
  reverse-ordered buffer explanation. No narration of what the next line does.
- Calibrated doubt markers: `TODO` = deferred feature; `FIXME` = known
  correctness debt **with the failure mode spelled out**; `todo!()` = only for
  genuinely unreachable-until-decided branches — never on paths remote input
  can reach.
- Tests return `anyhow::Result<()>` and use `?` — no `.unwrap()` chains.
- `#[allow]` only narrow and justified; a broad allow is a finding.

## Review mode

Audit the target against every section above plus
`references/legacy-quirks.md`. Structure the output as:

```
# Style review: <project>

## Conforms
## Findings
Per finding: **[category]** <defect> — file:line, why it matters, the fix.
Categories: formatting | errors | logging | structure | comments | legacy-quirk
## Suggested tooling
rustfmt.toml / clippy lints that would enforce the findings automatically.
```

Prioritize findings that cost something (debuggability, silent failures,
reviewability) over cosmetic deviations. When the target project has its own
established conventions that merely differ, note the difference once — don't
report every instance as a defect.
