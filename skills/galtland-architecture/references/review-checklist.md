# Architecture review checklist

Walk the target codebase against each item. For every hit, record: severity,
file:line, the concrete cost (what breaks or what maintenance it causes), and
the pattern-conformant fix. Skip items that don't apply — but say so in the
"Not applicable" section of the report, with the reason.

## Ownership and concurrency

- [ ] **Locked event-driven state.** Any `Arc<Mutex<...>>` around a swarm,
  connection pool, GUI handle, FFI handle, or other event-driven/`!Sync`
  object. High severity: this is the deadlock-and-starvation generator the
  single-owner loop exists to prevent.
- [ ] **Multiple owners of one event source.** Two loops polling the same
  receiver/socket, or event handling scattered across modules that each hold a
  piece of the state.
- [ ] **Locks held across `.await`.** Especially registry locks held while
  calling into an actor client (deadlock if the actor needs the registry).
- [ ] **Blocking in the owner loop.** File IO, sync DB calls, or long
  computation inside the `select!` body instead of spawned per-event.

## Command layer

- [ ] **Ad-hoc shared state instead of commands.** Components reaching into
  shared structs to get network/engine effects, rather than sending a typed
  command.
- [ ] **Command enums without reply channels** where callers need results —
  forcing polling or side-channel flags.
- [ ] **Flattened error layers.** Transport failures and remote/application
  errors collapsed into one `anyhow::Error` at the boundary, so callers can't
  retry vs ban vs propagate differently. (Medium: judgment call — flag only if
  callers demonstrably need the distinction.)
- [ ] **Client methods that can hang forever**: a send succeeded but the
  matching pending-map entry can be dropped without resolving the oneshot.

## Pending maps / bridging

- [ ] **Pending maps that never shrink** (entries not removed on failure paths).
- [ ] **`.expect()`/`.unwrap()` on pending lookups** reachable by remote input.
- [ ] **No coalescing** of identical concurrent in-flight queries where the
  underlying operation is expensive (low severity, optimization).

## Event distribution

- [ ] **Must-handle-once events on broadcast channels** (a `Lagged` receiver
  silently drops a response obligation). High severity.
- [ ] **Observability events on point-to-point channels**, forcing every new
  consumer to thread through existing code.
- [ ] **Unbounded channels without a stated reason.** Unbounded is legitimate
  exactly where backpressure would deadlock the owner loop — demand the
  comment; otherwise flag as an OOM vector.
- [ ] **No admission control on remote-triggered work.** Unbounded event
  channel + spawn-per-event with no concurrency cap (semaphore, worker pool,
  per-peer rate limit) lets a peer or burst drive unbounded task count / queue
  depth. High severity when the trigger is remote — it's a DoS/OOM surface.
- [ ] **Sequential event handling** where a slow handler stalls dispatch
  (missing spawn-per-event).

## Actor lifecycle

- [ ] **Actors without graceful shutdown**: no `Die`/close command, teardown
  (unpublish, flush, notify) never runs; killed via task abort or process exit.
- [ ] **Missing self-deregistration**: daemon exits (esp. on error) but its
  registry entry remains, so lookups return a dead client forever.
- [ ] **Cleanup not panic-safe**: registry removal is a bare `remove()` after
  the daemon's await rather than a Drop guard, so a panic-unwind skips it and
  leaks a dead client. (`spawn`'s error logging catches `Err`, not panics.)
- [ ] **Sluggish cancellation**: abort checked via `try_recv()` at loop top
  instead of a `select!` arm / `CancellationToken`, so abort is delayed while
  the daemon is blocked inside one iteration.
- [ ] **Launch races**: two callers launching the same resource actor
  concurrently both succeed, or the loser gets a hang instead of an error.
- [ ] **Leaked idle actors**: per-resource daemons with no inactivity
  self-termination for resources that go quiet.
- [ ] **Actor ceremony around synchronous state**: task+channel+enum+client
  wrapping what is just a map behind a mutex. Low-medium: complexity cost.
- [ ] **`recv() => None` unhandled** (`todo!()`, `unreachable!()`, or silent
  hang when all clients drop).

## Crate organization

- [ ] **Platform leakage in the core**: the crate meant to be portable pulls
  OS-bound deps (raw sockets, native TLS, full tokio) unconditionally. Test:
  does `cargo build --target wasm32-unknown-unknown -p <core>` pass, if
  multi-platform is a stated goal?
- [ ] **Hardcoded platform services** where injection is needed: transports,
  spawners, clocks constructed inside the core instead of passed in.
- [ ] **Version drift surface**: foundational deps (tokio, the network stack)
  declared independently by many crates instead of re-exported from the core.
- [ ] **Unjustified crate count**: crates that don't differ in platform
  support, dependency weight, or reuse boundary (low severity).
- [ ] **Vestigial dependencies**: declared in a manifest, zero uses in src
  (cheap `grep` per dep name). Low severity, quick win.

## Report calibration

- Severity is about consequence, not pattern purity: a locked swarm that works
  today under low load is still high (latent deadlock); a missing broadcast
  tier in a two-consumer app is low.
- A finding without a concrete failure story or maintenance cost isn't a
  finding — cut it.
- Always fill "What matches" and "Not applicable": the review should show what
  was checked and consciously cleared, not just what's wrong.
