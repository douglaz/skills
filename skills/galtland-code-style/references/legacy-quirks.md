# Legacy quirks — do not replicate; flag on review

The original 2022 codebase carried habits that were era constraints, upstream
example residue, or accidents — not style. When **applying** the style, never
introduce these. When **reviewing**, flag them as `legacy-quirk` findings with
the modern replacement.

## Era-bound (the constraint is gone)

- **rustfmt.toml keys restating defaults** (`hard_tabs = false`,
  `merge_derives = true`, `use_try_shorthand = false`, etc.) — template
  residue; config files should contain only intent. Note: `unstable_features
  = true` is NOT such residue — the import options are still nightly-only
  (verified: rustfmt 1.8.0-stable warns and ignores them). The real finding
  when reviewing is an **unpinned nightly assumption**: the config demands
  nightly rustfmt but nothing (rust-toolchain.toml, CI `cargo +nightly fmt
  --check`) enforces it, so stable-toolchain contributors silently bypass it.
- **The `instant` crate** for wasm-safe time — unmaintained; use `web-time`.
- **cfg by `target_os = "unknown"`** to detect wasm — write
  `target_arch = "wasm32"` (or `target_family = "wasm"`).
- **Blanket `tokio::task::yield_now().await` after channel sends.** Tokio's
  cooperative budget already forces yields on busy resources; blanket yields
  add wakeup churn. Acceptable only in profiled single-threaded (wasm) hot
  loops, with a comment.
- **Positional `{}` format args mixed with inline captures** — pre-1.58
  residue; unify on inline captures (`clippy::uninlined_format_args`).
- **Hand-rolled length-prefixed codecs / `ProtocolName` impls (libp2p)** —
  modern libp2p ships `request_response::cbor`/`json` behaviours and
  `StreamProtocol`; hand-rolling is now a choice that needs a reason
  (wire-format stability, size caps) stated in a comment.

## Upstream example residue

- **Empty-parens unit structs**: `pub struct FooProtocol();` — copied from the
  old libp2p file-sharing example. Write `pub struct FooProtocol;`.
- **`#[behaviour(ignore)]` state embedded in behaviour structs** — removed
  from modern libp2p derive; keep loop state in a struct beside the event
  loop.

## Accidents (cheap wins on review)

- **Vestigial dependencies**: declared in Cargo.toml, zero uses in src. Check
  with a grep per suspicious dep. (Original had `structopt` and
  `pretty_env_logger` declared in a library crate, unused.)
- **Logger/CLI deps in library crates** — logger init and arg parsing belong
  to binaries.
- **Unconditional wasm-only deps** — put under
  `[target.'cfg(target_arch = "wasm32")'.dependencies]`.
- **Superseded modules kept compiled** (`server.rs` alongside `server2.rs`,
  both `pub mod`). Keeping history is git's job; if the old module must stay
  temporarily, `#[cfg(feature = "legacy")]`-gate it or at least stop exporting
  it. Underscore-prefixed dead helpers inside live modules: delete.
- **Commented-out code blocks as decision records.** The original kept
  superseded implementations inline (old serializers, abandoned gossip
  config). Prefer: delete, and record the decision in a short comment ("using
  bincode; field-by-field framing benched slower, see <commit>") or commit
  message. On review, flag blocks > ~10 lines.

## Judgment calls (not automatic findings)

- **`.expect("...; qed")` unreachability proofs**: fine when the proof is
  real. Flag only when the "unreachable" path is reachable by remote input or
  channel-drop timing — those become `if let`/`match` with a `warn`.
- **`todo!()`**: acceptable mid-development on genuinely undecided branches;
  a finding when reachable from production input paths (e.g. `None` arm of a
  channel `recv()`).
