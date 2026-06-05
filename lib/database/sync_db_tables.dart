part of 'sync_db.dart';

@DataClassName('OutboxItem')
@TableIndex.sql(
  'CREATE INDEX idx_outbox_status_priority_created_at '
  'ON outbox (status, priority, created_at)',
)
// Hot-path partial that keeps `oldestOutboxItems` and
// `claimNextOutboxItem` focused on actionable rows even when the
// `sent` ledger has accumulated tens of thousands of entries (the
// 7-day retention window settles at ~30 k on heavy desktops). The
// non-partial index above stays for the full-status `watchOutboxItems`
// stream that the diagnostics UI reads.
//
// Status literals (0 and 3) intentionally mirror the current
// `OutboxStatus` enum order in
// `lib/features/sync/state/outbox_state_controller.dart`:
//   index 0 = pending, index 1 = sent, index 2 = error, index 3 = sending
// `@TableIndex.sql` only accepts a const string, so the indices cannot
// be derived from the enum at compile time. Drift safety: a guard test
// in `test/database/sync_db_test.dart` asserts the two indices used
// here match `OutboxStatus.pending.index` and `OutboxStatus.sending.index`,
// so any future enum reordering breaks the test instead of silently
// indexing the wrong rows.
@TableIndex.sql(
  'CREATE INDEX idx_outbox_actionable_priority_created_at '
  'ON outbox (priority, created_at) '
  'WHERE status IN (0, 3)',
)
// Covers `findPendingByEntryId` — the outbox merge-deduplication path
// fired on every enqueue. Filter is `status = pending AND
// outbox_entry_id = ? ORDER BY created_at DESC LIMIT 1`. Without this
// index the slow-query log on a real iOS device showed 2,394
// occurrences with p50=197 ms, p95=371 ms, because the planner fell
// back to the (status, priority, created_at) index and scanned every
// pending row to find the entry_id match. The partial WHERE keeps the
// index dense — only the hot pending+addressable rows live in it.
@TableIndex.sql(
  'CREATE INDEX idx_outbox_pending_entry_id_created_at '
  'ON outbox (outbox_entry_id, created_at) '
  'WHERE status = 0 AND outbox_entry_id IS NOT NULL',
)
// v21 partial retained for existing created-at-only plan guards and
// downgraded clients. Current dequeue paths order by priority first
// and use the status/priority index above, but dropping this index
// would add churn for databases that already created it.
@TableIndex.sql(
  'CREATE INDEX idx_outbox_pending_created_id '
  'ON outbox (created_at, id) '
  'WHERE status = 0',
)
// Legacy v21 expired-lease range companion. v22 drops it after fresh create
// and upgrade because the priority-first reclaim query should use the existing
// `(status, priority, created_at)` index. Leaving this created-at-only partial
// available lets SQLite choose a non-priority sort path and reintroduce
// `USE TEMP B-TREE FOR ORDER BY`.
// Status literal `3` mirrors `_outboxSendingStatus =
// OutboxStatus.sending.index` — same enum-order assumption the guard test in
// `test/database/sync_db_test.dart` already enforces.
@TableIndex.sql(
  'CREATE INDEX idx_outbox_sending_expiry '
  'ON outbox (created_at, id, updated_at) '
  'WHERE status = 3',
)
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(Constant(DateTime.now()))();

  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(Constant(DateTime.now()))();

  IntColumn get status =>
      integer().withDefault(Constant(OutboxStatus.pending.index))();

  IntColumn get retries => integer().withDefault(const Constant(0))();
  TextColumn get message => text()();
  TextColumn get subject => text()();
  TextColumn get filePath => text().named('file_path').nullable()();

  /// The journal entry or link ID for deduplication.
  /// When a pending item exists for the same entry, new updates can be merged
  /// to avoid sending redundant messages for rapidly-updated entries.
  TextColumn get outboxEntryId => text().named('outbox_entry_id').nullable()();

  /// Total payload size in bytes (attachment file size + JSON message size).
  /// Recorded at enqueue time for volume tracking and visualization.
  IntColumn get payloadSize => integer().named('payload_size').nullable()();

  /// Sync priority: 0=high (user), 1=normal (agent/system), 2=low (bulk resync).
  /// Entries are processed in priority order (ASC), then by creation date.
  IntColumn get priority =>
      integer().withDefault(Constant(OutboxPriority.low.index))();
}

/// Tracks sync sequence entries by (hostId, counter) to detect gaps
/// and enable backfill requests for missing entries.
///
/// The primary key on `(host_id, counter)` already gives us the critical
/// sequence lookup index. Additional indices focus on the queue-oriented access
/// paths that would otherwise scan large portions of the table:
/// - actionable rows ordered by age
/// - payload-id lookups used to resolve pending hints
@DataClassName('SyncSequenceLogItem')
@TableIndex.sql(
  'CREATE INDEX idx_sync_sequence_log_actionable_status_created_at '
  'ON sync_sequence_log (status, created_at) '
  'WHERE status IN (1, 2)',
)
// Companion partial keyed on `updated_at` so
// `retireAgedOutRequestedEntries` (which filters on `updated_at <
// cutoff`) does not fall back to the autoindex on (host_id, counter)
// and effectively scan every row that ever held status IN (1, 2).
// Both partials cover overlapping rows but with different sort keys.
@TableIndex.sql(
  'CREATE INDEX idx_sync_sequence_log_actionable_status_updated_at '
  'ON sync_sequence_log (status, updated_at) '
  'WHERE status IN (1, 2)',
)
// Companion partial for `retireExhaustedRequestedEntries`, which
// filters on `(status IN (1,2)) AND request_count >= ? AND
// last_requested_at IS NOT NULL AND last_requested_at < ?`. Neither
// the `created_at` nor `updated_at` partial sorts by the bound
// column, so before this index the predicate fell back to the
// autoindex on (host_id, counter) and scanned every actionable row.
// Restricting the partial WHERE to `last_requested_at IS NOT NULL`
// keeps the index dense and matches the predicate's NOT NULL guard.
@TableIndex.sql(
  'CREATE INDEX idx_sync_sequence_log_actionable_status_last_requested_at '
  'ON sync_sequence_log (status, last_requested_at) '
  'WHERE status IN (1, 2) AND last_requested_at IS NOT NULL',
)
// Covering index for `getBackfillStats`. The previous SUM-of-CASE
// formulation full-scanned 700 k+ rows on production devices
// (858 s/day on a real desktop). With this index, GROUP BY
// (host_id, status) becomes index-only and emits only ~80 rows
// (≈ hosts × statuses) which the Dart side pivots cheaply.
@TableIndex.sql(
  'CREATE INDEX idx_sync_sequence_log_host_status '
  'ON sync_sequence_log (host_id, status)',
)
// Covers `getLastCounterForHost`. The watermark CTE only needs rows whose
// status is terminal/resolved (`received`, `backfilled`, `deleted`,
// `unresolvable`, or `burned`) ordered by counter for a single host. A
// literal-status partial index lets SQLite walk exactly that subset in
// `(host_id, counter)` order instead of scanning every row for the host and
// filtering `missing/requested` rows out inside the window function. The
// status literals mirror [SyncSequenceStatusX.isResolved]; the v24 migration
// rebuilds this index when `burned` (8) is appended to the resolved set.
@TableIndex.sql(
  'CREATE INDEX idx_sync_sequence_log_resolved_host_counter '
  'ON sync_sequence_log (host_id, counter) '
  'WHERE status IN (0, 3, 4, 5, 8)',
)
@TableIndex.sql(
  'CREATE INDEX idx_sync_sequence_log_payload_resolution '
  'ON sync_sequence_log (entry_id, payload_type, status) '
  'WHERE entry_id IS NOT NULL',
)
// Covers `getLastSentCounterForEntry`. Placing `counter DESC` before
// `status` lets SQLite satisfy `ORDER BY counter DESC LIMIT 1` by walking
// the index behind the `(host_id, entry_id)` equality prefix in reverse
// counter order and applying the `status IN (?, ?)` predicate in-index,
// terminating on the first match. With `status` trailing `counter`, the
// engine would have to merge two status partitions via a temp B-tree.
@TableIndex.sql(
  'CREATE INDEX idx_sync_sequence_log_host_entry_status_counter '
  'ON sync_sequence_log (host_id, entry_id, counter DESC, status) '
  'WHERE entry_id IS NOT NULL',
)
class SyncSequenceLog extends Table {
  /// The host UUID whose counter this record tracks
  TextColumn get hostId => text().named('host_id')();

  /// The monotonic counter for that host
  IntColumn get counter => integer()();

  /// The payload ID (journal entry ID or entry link ID).
  /// Null if the payload is missing/unknown.
  TextColumn get entryId => text().named('entry_id').nullable()();

  /// What kind of payload [entryId] refers to.
  IntColumn get payloadType => integer()
      .named('payload_type')
      .withDefault(Constant(SyncSequencePayloadType.journalEntity.index))();

  /// The host UUID that sent the message which informed us about this record.
  /// For received entries, this is the sender. For gaps detected from VCs,
  /// this is the host whose message contained the VC that revealed the gap.
  TextColumn get originatingHostId =>
      text().named('originating_host_id').nullable()();

  /// Status of this sequence entry (received, missing, requested, etc.)
  IntColumn get status =>
      integer().withDefault(Constant(SyncSequenceStatus.received.index))();

  /// When this log entry was created
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  /// When this log entry was last updated
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  /// Number of backfill requests sent for this entry
  IntColumn get requestCount =>
      integer().named('request_count').withDefault(const Constant(0))();

  /// When a backfill request was last sent for this entry
  DateTimeColumn get lastRequestedAt =>
      dateTime().named('last_requested_at').nullable()();

  /// The documents-directory-relative path to the entry's JSON file.
  /// Stored so the backfill sweep can delete zombie files for any payload
  /// type, not just agent entities/links whose paths are derivable from ID.
  TextColumn get jsonPath => text().named('json_path').nullable()();

  @override
  Set<Column> get primaryKey => {hostId, counter};
}

/// Tracks when each host was last seen (received a message from).
/// Used to determine if a host has been active since our last backfill request.
@DataClassName('HostActivityItem')
class HostActivity extends Table {
  /// The host UUID
  TextColumn get hostId => text().named('host_id')();

  /// When we last received a message from this host
  DateTimeColumn get lastSeenAt => dateTime().named('last_seen_at')();

  @override
  Set<Column> get primaryKey => {hostId};
}

/// Durable inbound queue for Matrix sync events. Three producers
/// (live stream, limited-sync bridge, bootstrap pagination) write
/// here; one `InboundWorker` drains and applies.
///
/// - `event_id` UNIQUE is the sole cross-producer dedupe primitive.
/// - `(next_due_at, origin_ts, queue_id)` index covers the drain
///   query: "oldest-due-first, origin-ascending, FIFO within the same
///   origin_ts".
/// - `lease_until` is a durable lease stamped by `peekBatchReady`;
///   after a crash, entries whose lease has expired are peekable
///   again. Exactly-once is guaranteed by the idempotent apply path
///   (vector-clock comparison), not by the lease itself.
/// - `raw_json` stores `Event.toJson()` from a *fully decrypted*
///   Event. The `PendingDecryptionPen` prevents pre-decryption
///   events from being enqueued.
@DataClassName('InboundEventQueueItem')
// Drain-path index. Partial on active statuses so the applied ledger
// (which can grow unbounded over time) is excluded from the index and
// the worker's peek query scans only the rows it can actually drain.
//
// `leased` is included so `peekBatchReady` (which filters
// `status IN ('enqueued','retrying','leased')` to make crash recovery
// peek the previously-leased rows once their lease expires) can use
// this index for ORDER BY. Without `leased` the planner falls back to
// `idx_inbound_event_queue_active_ready_at` (keyed on
// `(next_due_at, lease_until)`) and pays an external sort to honour
// the `ORDER BY origin_ts, queue_id` clause.
@TableIndex.sql(
  'CREATE INDEX idx_inbound_event_queue_ready '
  'ON inbound_event_queue (next_due_at, origin_ts, queue_id) '
  '''WHERE status IN ('enqueued', 'retrying', 'leased')''',
)
// `earliestReadyAt` probe: computes MIN(MAX(next_due_at, lease_until))
// across all actively-schedulable rows to tell the worker when the
// next row becomes peekable. Without this partial the query
// full-scans the entire queue table on every worker idle tick — on a
// desktop mid-drain we measured 3500+ scans totalling 73s of DB time
// per hour with p95=46ms and max=2.3s. Including `lease_until` lets
// the plan evaluate the CASE expression straight from index keys
// without heap lookups, and restricting to `(enqueued, retrying,
// leased)` keeps the applied ledger and poison-row `abandoned`
// entries out of the probe.
@TableIndex.sql(
  'CREATE INDEX idx_inbound_event_queue_active_ready_at '
  'ON inbound_event_queue (next_due_at, lease_until) '
  '''WHERE status IN ('enqueued', 'retrying', 'leased')''',
)
@TableIndex.sql(
  'CREATE INDEX idx_inbound_event_queue_room '
  'ON inbound_event_queue (room_id, origin_ts)',
)
// Marker-clamp probe: `_advanceMarkerIfNewer` asks for the oldest
// `origin_ts` across active statuses per room. Partial covers exactly
// that access pattern so a million applied rows never touch the
// clamp cost.
@TableIndex.sql(
  'CREATE INDEX idx_inbound_event_queue_active_room_ts '
  'ON inbound_event_queue (room_id, origin_ts) '
  '''WHERE status IN ('enqueued', 'leased', 'retrying')''',
)
// Path-based resurrection: `AttachmentIndex.pathRecorded` fires with a
// path; `resurrectByPath` scans abandoned rows for matching
// `json_path`. Partial on abandoned so the resurrect path is O(log n)
// over only the rows eligible to wake.
@TableIndex.sql(
  'CREATE INDEX idx_inbound_event_queue_abandoned_path '
  'ON inbound_event_queue (json_path) '
  '''WHERE status = 'abandoned' ''',
)
// Companion partial for `resurrectByReason`, which fires on every
// `JournalDb.updateStream` event to un-park abandoned rows whose
// last retry reason matches. Without it, the predicate
// `status='abandoned' AND last_error_reason=?` falls through to a
// table scan over the full applied ledger (23 k+ rows on production
// devices, 298 s of cumulative DB time per day on desktop).
@TableIndex.sql(
  'CREATE INDEX idx_inbound_event_queue_abandoned_reason '
  'ON inbound_event_queue (last_error_reason) '
  '''WHERE status = 'abandoned' ''',
)
// Tighter companion for `resurrectByReason`: the actual call adds a
// `resurrection_count < ?` predicate on top of the reason equality, so
// the predicate `(last_error_reason = ?) AND (resurrection_count < ?)`
// previously had to fetch each row through the heap to evaluate the
// count comparison. iOS slow-query log captured 6,331 occurrences with
// p50=101 ms, p95=344 ms. Stacking the count column behind the reason
// equality lets SQLite walk the index for the bounded prefix and never
// touch the heap.
@TableIndex.sql(
  'CREATE INDEX idx_inbound_event_queue_abandoned_reason_resurrection '
  'ON inbound_event_queue (last_error_reason, resurrection_count) '
  '''WHERE status = 'abandoned' ''',
)
// `QueueStats.stats()` and the `readyNow` probe filter
// `status IN ('enqueued','retrying','leased') AND next_due_at <= ?
// AND lease_until <= ?`, but the existing `idx_inbound_event_queue_
// active_ready_at` is partial on a constant `status IN (…)` clause
// that SQLite's theorem prover cannot match against a parameterized
// `IN (?, ?, ?)`. The slow-query log captured 332 ms full SCANs.
// A non-partial composite leading on `status` lets the planner seek
// for each bound status value and walk `(next_due_at, lease_until)`
// inside the index.
@TableIndex.sql(
  'CREATE INDEX idx_inbound_event_queue_status_due_lease '
  'ON inbound_event_queue (status, next_due_at, lease_until)',
)
// `QueueStats.stats()` aggregates `COUNT(*) + MIN(enqueued_at)`
// filtered by `status IN (...)`. The v18 index above lets the planner
// seek by status, but `MIN(enqueued_at)` cannot be evaluated without
// reading the heap because `enqueued_at` is not in any index keyed on
// `status`. The slow-query log captured this as a 240–550 ms SCAN of
// the entire queue table on every UI poll. Pairing `(status,
// enqueued_at)` makes MIN an O(1) index seek per matched status
// partition (the first entry of each partition is the minimum), and
// COUNT becomes an index-only walk over a tight key range.
@TableIndex.sql(
  'CREATE INDEX idx_inbound_event_queue_status_enqueued '
  'ON inbound_event_queue (status, enqueued_at)',
)
// `QueueStats.stats()` issues a single `GROUP BY status, producer`
// aggregate to populate `total`, `byProducer`, `applied`, `abandoned`,
// `retrying`, and `oldestEnqueuedAt` in one pass. The v19 index above
// covers `(status, enqueued_at)` but does not include `producer`, so
// the planner had to read every matching row from the heap to bucket
// by producer — captured as 1014–2244 ms SCAN+TEMP B-TREE hits in the
// 2026-05-10 super-slow log on a real desktop device. Stacking
// `producer` as the second column lets the planner walk the index
// once per status partition, emit one (status, producer, cnt,
// MIN(enqueued_at)) row per partition, and skip the temp B-tree.
@TableIndex.sql(
  'CREATE INDEX idx_inbound_event_queue_status_producer_enqueued '
  'ON inbound_event_queue (status, producer, enqueued_at)',
)
class InboundEventQueue extends Table {
  IntColumn get queueId => integer().autoIncrement().named('queue_id')();

  /// Matrix event ID. UNIQUE at the DB level; duplicate inserts are
  /// silently rejected on all ingestion paths.
  TextColumn get eventId => text().named('event_id').unique()();

  /// Matrix room ID the event belongs to.
  TextColumn get roomId => text().named('room_id')();

  /// `originServerTs` in milliseconds since epoch. Drain order is
  /// ascending on this, then on `queue_id`.
  IntColumn get originTs => integer().named('origin_ts')();

  /// Enqueuing producer. Stored as `InboundEventProducer.name` to
  /// survive future enum reshuffling.
  TextColumn get producer => text()();

  /// Serialised `Event.toJson()`. Materialised to an `Event` at drain
  /// time; the queue itself never holds SDK objects.
  TextColumn get rawJson => text().named('raw_json')();

  /// Wall-clock enqueue timestamp (ms since epoch).
  IntColumn get enqueuedAt => integer().named('enqueued_at')();

  /// Retry counter. Incremented per scheduled retry; capped in
  /// `InboundWorker` to avoid eternal wedges on a single bad event.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Earliest time (ms since epoch) at which this entry is eligible
  /// for re-peek. 0 = ready now.
  IntColumn get nextDueAt =>
      integer().named('next_due_at').withDefault(const Constant(0))();

  /// Worker lease expiry (ms since epoch). 0 = not leased; peek stamps
  /// this to `now + leaseDuration` atomically. Entries with `lease_until
  /// > now` are not returned by `peekBatchReady`, so crashed-then-
  /// restarted workers do not double-drain until the lease expires.
  IntColumn get leaseUntil =>
      integer().named('lease_until').withDefault(const Constant(0))();

  /// Lifecycle state. One of:
  /// - `enqueued` — just inserted, ready to drain.
  /// - `leased` — worker picked it up; `lease_until > now` protects
  ///   against double-drain.
  /// - `retrying` — apply returned a recoverable failure; `next_due_at`
  ///   holds the backoff.
  /// - `applied` — `commitApplied` succeeded. Row is kept as an
  ///   append-only ledger for traceability; the marker has advanced.
  /// - `abandoned` — max attempts exceeded. Not drainable, but kept so
  ///   a resurrection trigger (attachment signal, journal update,
  ///   user-initiated "retry skipped") can flip it back to
  ///   `enqueued`.
  ///
  /// Stored as text rather than an enum index because the set is
  /// small, readable, and stable across future reorderings.
  TextColumn get status => text().withDefault(const Constant('enqueued'))();

  /// Wall-clock ms at which `commitApplied` flipped status to
  /// `applied`. NULL for non-applied rows.
  IntColumn get committedAt => integer().named('committed_at').nullable()();

  /// Wall-clock ms at which `markSkipped` flipped status to
  /// `abandoned`. NULL for non-abandoned rows.
  IntColumn get abandonedAt => integer().named('abandoned_at').nullable()();

  /// Last retry/skip reason (from `RetryReason.name` or
  /// `'permanentSkip'` / `'maxAttempts(...)'`). Diagnostics-only;
  /// resurrection does not gate on this.
  TextColumn get lastErrorReason =>
      text().named('last_error_reason').nullable()();

  /// Count of times this row has been flipped from `abandoned` back
  /// to `enqueued`. Guards against thrash: `resurrectByPath` /
  /// `resurrectAll` skip rows whose count exceeds the hard cap so a
  /// truly poison event cannot be resurrected forever.
  IntColumn get resurrectionCount =>
      integer().named('resurrection_count').withDefault(const Constant(0))();

  /// Derived from the Lotti sync payload (text message content
  /// `jsonPath`) when present. Used by
  /// `AttachmentIndex.pathRecorded` → `resurrectByPath` to wake the
  /// matching abandoned row as soon as the descriptor lands on disk.
  /// NULL when the event type does not carry a `jsonPath`.
  TextColumn get jsonPath => text().named('json_path').nullable()();
}

/// Per-room apply marker. Lives in `sync_db` (not `settings_db`) so
/// that `commitApplied` can delete the queue row and advance the
/// marker in the same transaction — closing the cross-DB hole the
/// review flagged (F5).
@DataClassName('QueueMarkerItem')
class QueueMarkers extends Table {
  TextColumn get roomId => text().named('room_id')();

  /// Last `$`-prefixed (server-assigned) event id applied. Nullable
  /// because early boot has none yet. Placeholder (`lotti-...`) ids
  /// are never written here; they stay in-memory on the worker.
  TextColumn get lastAppliedEventId =>
      text().named('last_applied_event_id').nullable()();

  /// Highest `originServerTs` we have applied and committed. Guarded
  /// by `TimelineEventOrdering.isNewer`; writes only accept
  /// monotonic advancement (F2).
  IntColumn get lastAppliedTs =>
      integer().named('last_applied_ts').withDefault(const Constant(0))();

  /// Monotonic counter incremented on every successful
  /// `commitApplied`. Diagnostic use only.
  IntColumn get lastAppliedCommitSeq => integer()
      .named('last_applied_commit_seq')
      .withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {roomId};
}
