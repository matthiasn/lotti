# ADR 0142: Sync Moves into an Isolate That Owns `sync.sqlite`, and Every Apply Is Acknowledged

## Status

Accepted

## Date

2026-10-20

## Context

Lotti has had UI lag on phones. The worst cause, the "ghost page", is fixed. What
remains points at sync, because much of sync's work runs on the UI isolate
whatever the user is doing:

- The **Matrix SDK `/sync` loop** parses every response and decrypts every
  Olm/Megolm event on the UI isolate, continuously, foreground or background.
- **Live admission** copies each event with `jsonDecode(jsonEncode(...))`,
  checks trust and writes it into `inbound_event_queue`, on every `onSync`.
- **Bridge and catch-up walks** page `/messages`, decrypt and enqueue, as many
  pages as a gap takes.
- The **`fromSync` notification fan-out** makes every `updateStream` listener
  re-query, plus the goal, synced-audio and project-agent dispatchers.
- **Timers** every 2 minutes (backfill requests, sync recovery) and every
  10 seconds (outbox watchdog).

None of this checks user activity, and nothing in `lib/features/sync` responds
to the app being backgrounded. `UserActivityGate` covers three consumers only —
the outbox drain, the inbound worker and queued attachment downloads — and
each checks once, before it starts; work in progress is never interrupted. The
full inventory, with costs, is in
[the sync isolate concept](../../knowledge/features/sync/isolate.md#what-runs-regardless-of-activity).

An isolate-hosted sync was built once before and removed unused
([ADR 0046](0046-sync-actor-isolate-removed-and-how-to-rebuild.md)). That ADR
names the trap: the actor was built in isolation from the live receive path,
which then grew `queue/`, `sequence/`, `backfill/` and `media/`, so reaching
parity meant writing all of that a second time. Its phase 4 — journal writes
from the actor — never merged; its phase 5 logged the actor in as a second,
hidden Matrix device, which ADR 0045's "directly verified devices only" rule
would never send keys to.

ADR 0046 proposed that a worker open its own connections to *every* database
and write the journal directly. Mapping what an apply touches rules that out:
one inbound message can write `db.sqlite`, `settings.sqlite`,
`agent.sqlite`, `notifications.sqlite`, `ai_config.sqlite` and
`ai_consumption.sqlite`, schedule OS notifications, write the keychain, and
call agent services that exist only in Riverpod. Several readers on the UI
isolate keep in-memory state a second isolate's writes would never refresh —
the config-flag cache inside `JournalDb`, `EntitiesCacheService` — and several
Drift `watch()` streams (conflicts, outbox count, backfill counts, AI configs)
do not fire for writes made from another isolate.

## Decision

**Sync moves into one long-lived worker isolate, in steps, behind the
`use_isolate_sync` config flag, which defaults to off.** With the flag off,
production sync is exactly what it was.

### Ownership is split by database

- **The sync isolate** owns the Matrix client — the app's *existing* device,
  as its only user, never a second device — its SDK database, the sync loop,
  decryption, admission, bridge walks, attachment downloads and outbox sending.
  **It is the only writer of `sync.sqlite`.**
- **The UI isolate** stays the only writer of every other database, and keeps
  the apply step (`InboundWorker` → `SyncEventProcessor`) with its activity
  gate, its transactions and its notifications. It may keep read-only
  connections to `sync.sqlite` for the pages that show sync state.

The hand-off is the table that already is the boundary between receiving and
applying: `inbound_event_queue`.

### An apply is acknowledged, never fire-and-forget

The sync isolate tracks every inbound entry until the UI isolate positively
confirms it was applied, and retries until it does. A message that could be
lost in transit would leave nothing knowing what is missing — and knowing what
is missing is the whole of the sequence and backfill design.

- **The UI isolate pulls work.** When its activity gate allows, it asks for the
  next entry. The isolate *leases* it: the row turns `leased` with
  `lease_until`, exactly as `peekBatchReady` stamps it today.
- **The UI isolate answers with the outcome it already computes** — one of
  `ApplyOutcome`'s values (`applied`, `retriable`, `missingBase`,
  `pendingBarrier`, `pendingDescriptor`, `pendingAttachment`, `permanentSkip`,
  `undecodable`) plus the sequence-log effects of the apply. The isolate turns
  that into the row's next state with the retry and abandonment rules that
  exist now, and records the sequence-log effects in the same `sync.sqlite`
  transaction.
- **No answer means not applied.** A lease that expires without an
  acknowledgement — the UI isolate was killed, the message was lost, the apply
  hung — makes the row deliverable again. Apply therefore stays idempotent,
  which vector-clock supersession already makes it.
- **The journal commit and the acknowledgement are two transactions in two
  files**, as the apply and the queue update are today. A crash between them
  re-delivers the entry and the re-apply is a no-op; it never loses one.

The same rule holds the other way: anything the UI isolate asks the sync
isolate to record (an outbox enqueue, for one) is pending on the UI side until
the isolate confirms it.

### The protocol

Typed, immutable messages over `SendPort` (the worker shares the UI isolate's
isolate group, so classes travel by value):

- **requests** carry a command and a request id; **replies** echo the id with a
  result or a typed failure (`timeout`, `isolateExited`, `notRunning`,
  `failed`);
- **events** are unprompted: log lines today; queue growth, outbox and login
  state as the steps land;
- lists cross the boundary, never sets.

The host **supervises** the worker, which the removed actor did not: an
unexpected exit is logged with the worker's error and trace, every request
still out to it fails at once with `isolateExited` instead of waiting out its
timeout, and a replacement is spawned after a backoff that grows with each
consecutive crash (1 s, 5 s, 15 s, then every minute) and resets once a worker
has run for five minutes. A worker that cannot be started at all is retried the
same way, and nothing — startup least of all — waits on a spawn.

The worker uses no Flutter plugins. Paths, credentials and connectivity come
from the host.

### Writes, refreshes and notifications across the boundary

Three questions every isolate design has to answer. This one answers them
with what already exists rather than with new machinery.

- **Database writes.** The sync isolate opens its own Drift connection to
  `sync.sqlite`, with the SQLite work running on the worker itself rather
  than in a nested isolate, and with the documents and temporary directories
  handed over by the host at the handshake — the database opener otherwise
  asks a path plugin, which the worker cannot call. SQLite's WAL mode and the
  5 s busy timeout already let two connections share the file; what they do
  not share is Drift's table-change tracking, which is why the next two
  points exist. The UI isolate keeps a connection for the pages that read
  sync state and, during the transition steps, for the tables it still owns.
  Each step names which side writes which table; what both sides still write
  while the receive side has not moved is tracked in the concept.
- **Data refresh.** Journal, settings, agent and notification data change
  only inside the apply step, which stays on the UI isolate, so the
  `UpdateNotifications` fan-out keeps firing where it fires today and no
  widget learns anything new.
- **Sync-state refresh.** A Drift `watch()` stream fires only for writes made
  through its own connection. The worker reports every table it wrote as a
  `SyncIsolateTablesChanged` event, and the host replays that into the UI
  isolate's connection with Drift's `notifyUpdates`, so the outbox count,
  queue depth, backfill and conflict streams the pages already watch fire as
  if the write had been local. Work for the UI isolate — an entry to apply —
  arrives as an event too, replacing the in-process depth stream the inbound
  worker listens to today.

### The steps

Each is one mergeable change; the flag stays off until the last.

1. **The flag and the host.** `use_isolate_sync`, the supervised
   `SyncIsolateHost`, and a worker that answers liveness. Flag on, it starts
   with the app and proves it runs; sync stays where it is. *(This change.)*
2. **Measure.** Timeline markers around the ungated paths, and a profile of a
   catch-up burst on a phone, before anything moves.
3. **Apply without a live `Room`.** In two halves. First, the apply path
   reads a `SyncEnvelope` — the five fields it needs, rebuilt from the stored
   decrypted JSON — instead of an SDK `Event` built against a room, and the
   one lookup that needed the room, exact descriptor recovery, goes through
   `SyncDescriptorFetcher`, answered by the UI isolate's client today and by
   the sync isolate later. The inbound worker no longer waits for a room: the
   one observable change is that queued entries apply before the SDK has
   emitted the room, instead of being retried every two seconds until it has.
   Second, `AttachmentIndex` holds Room-free descriptors and attachment
   downloads go through an interface of the same kind. Needed by everything
   after it. Then, before any receive code moves, the hand-off itself: the
   worker opens `sync.sqlite`, serves leases and acknowledgements, and
   reports the tables it wrote; with the flag on, the UI isolate's inbound
   worker leases and acknowledges through it. Which parts have landed is
   tracked in the concept, not here.
4. **Receive in the isolate.** Matrix client, sync loop, decryption, admission
   and bridge walks move; the lease/acknowledge protocol replaces the UI
   isolate's direct queue writes. A `startSyncServices()` seam keeps the
   legacy producers from starting when the flag is on. The docker two-device
   suite is rebuilt against the isolate, and the SDK database's "API misuse"
   error the actor only worked around is fixed at its cause.
5. **Send from the isolate.** Outbox claims and sends move; enqueue becomes an
   acknowledged request. How sequence counters are allocated without a
   round-trip on every save is decided in that step.
6. **Everything else behind commands:** login, SAS verification, rescans,
   attachment repair, the outbox monitor's actions.
7. **Dogfood with the flag on, then retire the UI-isolate path.**

## Consequences

- With the flag off nothing changes: no isolate, no host, no extra work.
- With it on, today, one idle isolate runs beside unchanged sync.
- Sync semantics do not change at any step — only which isolate runs the
  work. Replication, encryption, verification and what reaches other devices
  stay as they are.
- `sync.sqlite` gains a second writer only for the steps in which ownership
  is moving, and each step names which side writes which table.
- Pausing sync while the app is backgrounded would remove much of the same
  contention, but that changes behaviour and is a separate decision.

## Amendment 2026-10-24 — step 4 in two halves

Step 4 lands as two changes rather than one. First the UI stops seeing the
SDK: everything above the sync feature — the settings pages, the device and
verification sheets, the outbox, onboarding and provisioning — talks to sync
through `SyncService`, in plain types. Device rows, login states and
verification snapshots cross that seam, and the UI acts on a ceremony by its
id, never on an SDK object, because every one of those values is about to
cross a port. Then the receive side moves as step 4 describes. The split
keeps the flag-off path the only path the first change touches, which is
what makes the swap reviewable on its own.

## Related

- [ADR 0046](0046-sync-actor-isolate-removed-and-how-to-rebuild.md) — the
  removed actor, what proved sound, and the trap this design avoids
- [ADR 0045](0045-exclude-unverified-devices-from-key-sharing.md) — why the isolate uses
  the existing device rather than a second one
- [The sync isolate](../../knowledge/features/sync/isolate.md) — the host, its
  lifecycle, and what runs regardless of activity
- [Receive path](../../knowledge/features/sync/receive-path.md) — the inbound
  queue the hand-off is built on
