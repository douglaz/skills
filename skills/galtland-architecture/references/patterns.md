# Pattern catalog

Code-level shapes for the six decisions. Sketches are generic tokio Rust;
adapt names to the domain. Sections:

1. Crate organization
2. Client / command enum
3. Pending-id maps (callback → async bridge)
4. Two-tier event fan-out
5. Daemon actor lifecycle
6. When a plain mutex beats an actor
7. Known pitfalls (from the original codebase's own scars)

## 1. Crate organization

```
workspace/
├── core/          # compiles for every target incl. wasm32-unknown-unknown
├── nativecommon/  # OS-dependent infra: sockets, DNS, ingest servers, device IO
├── appcommon/     # persistence and other shared-but-heavy app services
├── cli/           # thin frontend: daemon + client subcommands
├── desktop/       # thin frontend
└── browser/       # wasm frontend
```

Rules that keep the split honest:

- `core`'s dependency features must be wasm-safe. On
  `wasm32-unknown-unknown`, tokio supports only `sync`, `macros`, `io-util`,
  `rt`, and `time` — NOT `fs`, `net`, `process`, `signal`, or the multi-thread
  runtime. So the core uses `["sync", "rt", "macros"]` (add `time`/`io-util`
  if needed) and keeps filesystem, sockets, and threads out — they're injected
  from platform crates. Network libraries have transport features OFF. If
  `cargo build --target wasm32-unknown-unknown -p core` breaks, the boundary
  leaked.
- Platform services are **injected**: `core::engine::build(...)` takes the
  transport/IO handle as a parameter (`Boxed` trait object); each platform
  crate has its own `our_transport()` constructor of the same shape. Same for
  the filesystem — the core takes a storage trait object, natives back it with
  `tokio::fs`, wasm with IndexedDB/OPFS.
- Spawning goes through cfg-switched impls. The subtlety: browser futures are
  usually `!Send` (they touch `!Send` JS handles), so the wasm path must NOT
  require `Send`, while the native multi-thread runtime does. cfg the bound —
  don't write one `Send`-bounded helper for both:

```rust
#[cfg(not(target_arch = "wasm32"))]
pub fn spawn<F: Future<Output = ()> + Send + 'static>(fut: F) { tokio::spawn(fut); }

#[cfg(target_arch = "wasm32")]
pub fn spawn<F: Future<Output = ()> + 'static>(fut: F) {
    wasm_bindgen_futures::spawn_local(fut);   // no Send bound
}

// The error-logging wrapper mirrors the same cfg split on the Send bound:
#[cfg(not(target_arch = "wasm32"))]
pub fn spawn_and_log_error<F>(fut: F)
where F: Future<Output = anyhow::Result<()>> + Send + 'static { spawn(log_errors(fut)) }

#[cfg(target_arch = "wasm32")]
pub fn spawn_and_log_error<F>(fut: F)
where F: Future<Output = anyhow::Result<()>> + 'static { spawn(log_errors(fut)) }

async fn log_errors(fut: impl Future<Output = anyhow::Result<()>>) {
    if let Err(e) = fut.await { log::error!("task failed: {e:#}") }
}
```

  Every background task goes through `spawn_and_log_error` so no failure is
  silent. (galtland kept two named fns, `spawn_and_log_error` /
  `wspawn_and_log_error`; the cfg'd-bound single name above is cleaner.)
- `core` re-exports its foundational deps (`pub use {tokio, bytes, ...};`) so
  downstream crates that touch those types import through one path. This does
  NOT by itself pin one version — cargo can still resolve multiple versions of
  a dep, and re-export only helps for deps whose types cross your crate
  boundaries. To actually enforce one version, use
  `[workspace.dependencies]` + per-crate `dep.workspace = true`, and audit with
  `cargo tree -d` / `cargo-deny`. Re-export is for API ergonomics; the
  workspace table is for version unification.
- Gate wasm-only deps properly: `[target.'cfg(target_arch = "wasm32")'.dependencies]`,
  not unconditional entries.

## 2. Client / command enum

```rust
pub enum Command {
    GetRecord {
        key: Key,
        reply: oneshot::Sender<anyhow::Result<Record>>,
    },
    Request {
        peer: PeerId,
        req: Request,
        // outer error = transport failed; inner = peer answered with an error
        reply: oneshot::Sender<Result<Result<Response, String>, OutboundFailure>>,
    },
    Dial {
        peer: PeerId,
        addresses: Vec<Multiaddr>,
        reply: oneshot::Sender<Result<(), DialError>>,
    },
}

#[derive(Clone)]
pub struct BackendClient {
    sender: mpsc::Sender<Command>,
}

impl BackendClient {
    pub async fn get_record(&self, key: Key) -> anyhow::Result<Record> {
        let (reply, rx) = oneshot::channel();
        self.sender
            .send(Command::GetRecord { key, reply })
            .await
            .map_err(|_| anyhow::anyhow!("backend loop gone"))?;
        rx.await? // collapse one layer only when the caller can't act on it
    }
}
```

Why this shape:

- **The enum is the API contract.** Every operation's inputs and exact reply
  type are visible in one place; adding an operation is one variant + one
  method, and the compiler walks you to the handler match arm.
- **Layered results are a feature, not noise.** Don't flatten
  `Result<Result<T, AppError>, TransportError>` at the boundary — callers
  handle "connection died" and "peer refused" differently (retry vs ban).
  Flatten only at the layer that genuinely treats them the same.
- **Clone is the sharing model.** Handing a `BackendClient` to a task is the
  only way to reach the backend; there is nothing to lock.
- Small channel bounds (8–16) are fine for command channels: senders await,
  and the owner loop drains fast because handlers are non-blocking (see §3).

## 3. Pending-id maps (callback → async bridge)

For APIs that answer via later events instead of returned futures:

```rust
struct Pending {
    get_record: HashMap<Key, Vec<oneshot::Sender<anyhow::Result<Record>>>>,
    requests: HashMap<RequestId, oneshot::Sender<Result<Response, Failure>>>,
    record_cache: HashMap<Key, Record>,
}

// command side (inside the owner loop — must not block or await IO):
Command::GetRecord { key, reply } => {
    if let Some(hit) = pending.record_cache.get(&key) {
        let _ = reply.send(Ok(hit.clone()));
    } else {
        match pending.get_record.entry(key.clone()) {
            Entry::Occupied(mut e) => e.get_mut().push(reply), // coalesce
            Entry::Vacant(e) => {
                api.start_get(key);          // fire the underlying query
                e.insert(vec![reply]);
            }
        }
    }
}

// event side:
Event::GetRecordDone { key, result } => {
    for tx in pending.get_record.remove(&key).unwrap_or_default() {
        if tx.send(result.clone()).is_err() {
            log::warn!("get_record caller for {key:?} went away");
        }
    }
    if let Ok(r) = result { pending.record_cache.insert(key, r); }
}
```

Rules:

- Key by **request id** when replies are 1:1; key by **resource** with a
  `Vec<Sender>` when concurrent callers should share one underlying query.
- Caching lives here, invisible to callers.
- On completion, `remove()` the entry — a pending map that only grows is a
  leak. On failure events, resolve with the error; never leave a sender parked
  (the caller hangs forever).
- A missing pending entry on event arrival is a bug worth surfacing loudly in
  development, but prefer `if let Some(tx)` + `log::error!` over
  `.expect()` — a misbehaving remote must not be able to panic the owner loop.
- **Every pending entry needs a deadline.** If the underlying API can fail to
  emit any completion/failure event (peer vanishes, query silently drops), a
  parked sender leaks the map and hangs the caller forever. Either the API has
  its own per-query timeout that always fires an event (libp2p kad does), or
  you add one: a caller-side `tokio::time::timeout` on `rx.await`, plus a sweep
  that drops pending entries older than a TTL and resolves them with a timeout
  error. Also drain pending maps on connection-close and shutdown, resolving
  each with an error rather than dropping the sender silently.

## 4. Two-tier event fan-out

```rust
// tier 1: must be handled exactly once (carries a response obligation)
let (event_tx, event_rx) = mpsc::unbounded_channel::<InboundRequest>();
// Unbounded so the OWNER LOOP never blocks feeding this channel — a bounded
// channel here would let a slow dispatcher back-pressure and deadlock the one
// loop that drains everything else. Unbounded solves the deadlock; it does NOT
// grant unlimited work. See admission control below.

// tier 2: facts anyone may observe; lossy is acceptable
let (broadcast_tx, _) = broadcast::channel::<NetworkFact>(16);

// dispatcher: spawn per event, but BOUND concurrent in-flight work with a
// semaphore so remote peers can't spawn unbounded tasks (OOM/DoS).
let inflight = Arc::new(Semaphore::new(MAX_CONCURRENT_REQUESTS));
loop {
    tokio::select! {
        Some(ev) = event_rx.recv() => {
            match inflight.clone().try_acquire_owned() {
                Ok(permit) => spawn_and_log_error(async move {
                    let _permit = permit;                 // released on task end
                    handle_request(ctx.clone(), ev).await
                }),
                Err(_) => reject_overloaded(ev),          // shed load, don't queue
            }
        }
        Ok(fact) = broadcast_rx.recv() =>
            spawn_and_log_error(handle_fact(ctx.clone(), fact)),
    }
}
```

Admission control is not optional when tier-1 events are **remote-triggered**.
Exactly-once delivery says nothing about *how many* may be in flight: an
attacker (or a burst) can push the unbounded channel and the spawn-per-event
dispatcher into unbounded queue depth and unbounded task count. Guard it — a
semaphore cap with load-shedding (above), a bounded worker pool, or an explicit
per-peer rate limit — and `log()` when you shed so silent drops are visible.
The unbounded channel protects the owner loop; the semaphore protects the host.

The classification question for every event: *if two components both reacted to
this, would something break?* Response-carrying events: yes (double reply) →
mpsc. Stats/topology/gossip: no → broadcast. Don't put must-handle events on a
broadcast channel "for flexibility" — `Lagged` drops them silently.

## 5. Daemon actor lifecycle

One task per *live* resource (active stream, transfer, session):

```rust
enum StreamCmd {
    Feed { data: Vec<Frame>, reply: oneshot::Sender<anyhow::Result<()>> },
    Get  { peer: PeerId, seek: Seek, reply: oneshot::Sender<ResponseResult> },
    Die  { reply: oneshot::Sender<()> },
}

#[derive(Clone)]
pub struct StreamClient { sender: mpsc::Sender<StreamCmd> }

pub async fn launch(
    key: StreamKey,
    registry: ArcMutex<HashMap<StreamKey, StreamClient>>,
    deps: Deps,
    initializer: oneshot::Sender<anyhow::Result<StreamClient>>,
) -> anyhow::Result<StreamClient> {
    let (tx, rx) = mpsc::channel(8);
    let client = {
        let mut reg = registry.lock().await;
        match reg.entry(key.clone()) {
            Entry::Occupied(_) => {
                let _ = initializer.send(Err(anyhow::anyhow!("{key:?} already active")));
                anyhow::bail!("{key:?} already active");
            }
            Entry::Vacant(e) => {
                let client = StreamClient { sender: tx };
                e.insert(client.clone());
                let _ = initializer.send(Ok(client.clone()));
                client
            }
        }
    };
    spawn_and_log_error({
        let registry = registry.clone();
        let key = key.clone();
        async move {
            // Drop guard: deregisters on EVERY exit — Ok, Err, AND panic-unwind.
            // A plain `registry.remove()` after the await is skipped on panic,
            // leaving a dead client in the map forever.
            let _guard = DeregisterOnDrop { registry: registry.clone(), key: key.clone() };
            stream_daemon(key.clone(), rx, deps).await
        }
    });
    Ok(client)
}

// Cleanup that survives panic. For an async registry lock, the guard can't
// .await in Drop, so either use a std::sync::Mutex for the registry (lock is
// uncontended and never held across await) or hand the key to a cleanup task.
struct DeregisterOnDrop { registry: Arc<std::sync::Mutex<HashMap<StreamKey, StreamClient>>>, key: StreamKey }
impl Drop for DeregisterOnDrop {
    fn drop(&mut self) { self.registry.lock().unwrap().remove(&self.key); }
}
```

The lifecycle parts, and why each exists:

- **Registry** (`ArcMutex<HashMap<Key, Client>>`): lookup-or-launch is the only
  place this lock is held, and never across an await into the actor itself.
- **Initializer oneshot**: launching is fallible and async; the caller learns
  "here's your client" or "launch failed because X" through one channel instead
  of polling the registry.
- **Registration race handled at the entry**: occupied → error out; don't
  silently return the existing actor unless idempotent launch is the documented
  semantic.
- **Abort oneshot** (for workflow daemons like seekers): store the abort sender
  in the registry; the daemon awaits it as one arm of its `tokio::select!`, so
  abort preempts whatever else the daemon is awaiting and fires promptly. A
  `try_recv()` poll at loop top (what galtland did) only checks between
  iterations, so abort is delayed for as long as the daemon is blocked inside
  one — prefer `select!`, or a `tokio_util::sync::CancellationToken`.
  Cancellation is a message, not a `JoinHandle::abort()` — the daemon gets to
  clean up (unpublish, notify peers).
- **`Die` command**: graceful shutdown that runs teardown (unpublish records,
  flush) and then returns from the loop, replying when done.
- **Self-deregistration via a Drop guard in the spawned wrapper**, not a bare
  `remove()` after the await and not inside the daemon body — the guard's Drop
  runs whether the daemon returns Ok, returns Err, or panics and unwinds. A
  plain post-await `remove()` is skipped on panic, and `spawn_and_log_error`
  logs a returned `Err` but not a panic, so without the guard a panicked daemon
  leaves a dead client wired into the registry.
- **Self-termination**: daemons for resources with natural idleness track
  last-activity and `Die` themselves after a timeout, so abandoned resources
  don't leak tasks.

Consumers of an actor hold a `Client`, never the receiver, never the state.
If a dropped consumer matters (per-consumer queues), detect it via failed
`reply.send()` and evict that consumer.

## 6. When a plain mutex beats an actor

Use a `Mutex<T>` struct instead of an actor when ALL of:

- operations are synchronous (no IO, no awaits while holding the lock),
- there's no lifetime — the state exists for the whole process,
- no operation needs to sequence with events from elsewhere.

Rate counters, blacklists, peer statistics, config: mutex. An actor here adds a
task, a channel, an enum, and a client for zero safety gain. The reverse smell
also holds: if a mutex-guarded struct starts doing IO under the lock or growing
"pending" fields, it wants to be an actor.

## 7. Known pitfalls (scars from the original)

- **Don't `.expect()` on pending-map lookups or channel sends in the owner
  loop** — remote peers and dying tasks can trigger both; log and continue.
- **Don't blanket-`yield_now()`** after every send. Tokio's cooperative budget
  already forces yields on busy channels; sprinkle yields only in genuinely
  starving single-threaded (wasm) hot loops, if profiling shows the need.
- **Handle `None` from `recv()`** in every daemon loop (channel closed = all
  clients dropped): exit cleanly, run teardown. `todo!()` there becomes a
  production panic.
- **Registry cleanup must survive panic**: a bare `remove()` after the daemon's
  await covers Ok/Err returns but not a panic-unwind — use the Drop-guard in §5
  so cleanup runs on every exit including panic.
- **Beware lock-ordering across registries**: if daemon A (holding no lock)
  calls a client whose daemon needs registry B while caller holds registry A,
  you're fine; but never call actor clients *while holding* a registry lock.
- If wrapping libp2p specifically: modern versions removed
  `#[behaviour(ignore)]` — keep pending maps and channels in a struct *next to*
  the Swarm inside the owner loop, not inside the behaviour.
