---
name: galtland-architecture
description: >-
  Apply or review the galtland Rust async architecture: platform-split crate
  organization plus channel-based actor/command concurrency (command enums
  where every variant carries a oneshot reply, a single event loop exclusively
  owning un-shareable state, pending-id maps that bridge callback-style APIs to
  async/await, and per-resource daemon actors behind cloneable Client handles).
  Use when designing or restructuring a Rust async/networked service or
  workspace, wrapping an event-driven or !Sync API (libp2p, FFI, GUI loops,
  device handles), deciding between actors and mutexes, or when asked to
  review a Rust project's architecture, concurrency design, or crate layout.
  Trigger on "design the architecture", "organize the crates", "review the
  structure of this project", "should this be an actor", or any mention of
  galtland-style architecture.
---

# galtland-architecture

An architecture playbook distilled from galtland (a P2P streaming platform whose
core runs unchanged on native and wasm). Two modes:

- **Apply** — the user is designing or building something new, or refactoring
  toward this architecture.
- **Review** — the user wants an existing project audited against these
  patterns.

If the request doesn't say which, infer from context: "how should I structure X"
is apply; "look at my project" is review.

Read `references/patterns.md` before doing either — it contains the code-level
shape of each pattern and the pitfalls. For review, also read
`references/review-checklist.md`.

## The six core decisions

These are the load-bearing choices. Everything else is elaboration.

1. **Split crates by platform capability, not by feature.** A core crate that
   compiles everywhere (no OS sockets, no threads assumed, wasm-safe deps
   only); platform crates that inject what the core can't assume (transports,
   spawn functions, persistence); thin app crates per frontend. The test: can
   the core crate build for `wasm32-unknown-unknown`? If a feature split
   wouldn't change what platforms a crate supports, it doesn't deserve a crate.
   Re-export foundational deps (`pub use tokio;`) from the core so downstream
   crates can't drift versions.

2. **Give un-shareable state exactly one owner.** Anything event-driven,
   `!Sync`, or callback-based (a libp2p Swarm, an FFI handle, a GUI event loop)
   lives in a single `loop { select! { ... } }` that nothing else touches — no
   `Arc<Mutex<Swarm>>`, ever. Locks around event-driven state are the #1 smell
   this architecture exists to prevent.

3. **Talk to the owner through a command enum with typed replies.** A cloneable
   `Client` struct wraps an `mpsc::Sender<Command>`; every `Command` variant
   carries a `oneshot::Sender` for its reply, so the enum itself documents each
   operation's exact result type — including layered errors like
   `Result<Result<T, RemoteError>, TransportFailure>`, which keep "the network
   failed" and "the peer said no" separately matchable. A third failure —
   "the owner loop is gone" (the `mpsc::send` or the `oneshot::Receiver::await`
   errored) — is the *outermost* layer, produced by the Client method itself,
   not a variant of the protocol result; the method returns
   `anyhow::Result<Result<Result<T, RemoteError>, TransportFailure>>`.

4. **Bridge callback APIs with pending-id maps.** When the owned API answers
   via later events (query ids, request ids), store the reply sender in a
   `HashMap<Id, oneshot::Sender<...>>` when issuing the call, and resolve it in
   the event handler. Coalesce duplicate in-flight requests by keying on the
   *resource* with a `Vec` of senders, and cache results at this layer — the
   callers never know.

5. **Fan events out on two tiers by delivery semantics.** Events that must be
   handled exactly once (they carry a response obligation) go on an `mpsc`
   channel — unbounded if backpressure could deadlock the owner loop, with a
   comment saying so. Observability facts that any number of daemons may
   consume (stats, topology changes) go on a bounded, lossy
   `tokio::sync::broadcast`. A dispatcher loop spawns a task per event so one
   slow handler never stalls the rest — but when the events are
   remote-triggered, cap concurrent in-flight work (a semaphore with
   load-shedding, or a bounded worker pool). Unbounded channel + spawn-per-event
   with no cap is a DoS/OOM surface: exactly-once says nothing about how many
   run at once. See patterns.md §4.

6. **Model each live resource as a daemon actor — but only live resources.**
   One spawned task per active stream/transfer/session, with its own command
   enum, a registry entry (`ArcMutex<HashMap<Key, Client>>`), an initializer
   oneshot that returns the Client or the launch error, a prompt abort path
   (an abort receiver in the daemon's `select!`, or a `CancellationToken`), an
   explicit `Die` command for graceful shutdown, and self-deregistration on
   exit via a Drop guard (so it fires on panic too, not just Ok/Err). Pure
   bookkeeping (counters, blacklists, rate stats) stays as plain mutex-guarded
   structs — an actor for synchronous state is ceremony, not safety.

## Apply mode

Work in this order — each step's output feeds the next:

1. **Inventory the un-shareable things.** What in this system is event-driven,
   `!Sync`, callback-based, or a singleton handle? Each one gets an owner loop
   (usually just one loop owning all of them via `select!`).
2. **Draw the crate boundary by target.** What must run on every platform?
   What needs OS services? What is app-specific? Don't create more crates than
   the platform matrix justifies.
3. **Write the command enum first.** For each operation callers need, define
   the variant with its full reply type. This *is* the API design; the Client
   methods follow mechanically (one async method per variant).
4. **Classify the events.** For each event the owned API emits: does exactly
   one party need to act on it (mpsc tier), or is it a fact others may observe
   (broadcast tier)?
5. **Identify the live resources** and give each a daemon actor with the full
   lifecycle (registry, initializer, abort, Die, self-deregistration). Resist
   making actors for anything that doesn't have a lifetime.
6. Use the code sketches in `references/patterns.md` as the skeleton — they
   encode the details that are easy to get wrong (initializer error paths,
   registry cleanup on panic, dropped-receiver handling).

## Review mode

Read `references/review-checklist.md` and walk the target codebase against it.
Structure the output as:

```
# Architecture review: <project>

## What matches the pattern (and works)
## Findings
For each finding: **[severity: high|medium|low]** <one-line defect> —
file:line, why it bites (the concrete failure or maintenance cost), and the
pattern-conformant fix.
## Not applicable
Patterns from this playbook that don't fit this project, and why (so the user
knows they were considered, not missed).
```

Judge fit, not conformance for its own sake: a single-platform CLI doesn't need
the crate split; a project with no event-driven state doesn't need command
channels. Flag *mismatches that cost something*, and say what they cost.
