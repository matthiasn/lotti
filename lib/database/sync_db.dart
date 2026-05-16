import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/features/sync/outbox/outbox_daily_volume.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/tuning.dart';

part 'sync_db.g.dart';

const syncDbFileName = 'sync.sqlite';

final int _outboxSendingStatus = OutboxStatus.sending.index;

/// Producer tag for an [InboundEventQueueItem]. Identifies which
/// ingestion path enqueued the event so diagnostics can break down
/// queue depth by source and so bootstrap-specific back-pressure can
/// target the right writer.
enum InboundEventProducer { live, bridge, bootstrap, backfill }

/// Status for entries in the sync sequence log.
/// Tracks whether an entry was received, is missing, or has been backfilled.
enum SyncSequenceStatus {
  /// Entry was received and processed successfully
  received,

  /// Gap detected - entry expected but not yet received
  missing,

  /// Backfill request has been sent for this entry
  requested,

  /// Entry was received via backfill after being marked missing
  backfilled,

  /// Responder confirmed the entry was purged/deleted
  deleted,

  /// Originating host confirmed it cannot resolve its own counter.
  /// This happens when a counter was superseded before being recorded
  /// (e.g., rapid edits where intermediate versions were never persisted).
  unresolvable,
}

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
// Hot-path partials for `oldestOutboxItems` and `claimNextOutboxBatch`'s
// pending branch. Both queries shape as
//   `WHERE status = 0 ORDER BY created_at ASC, id ASC LIMIT N`
// — sorted by (created_at, id) but with no priority column in the
// ORDER BY. The general `idx_outbox_status_priority_created_at` index
// sorts within status by (priority, created_at) instead, so the
// planner had to materialise the matching rows into a temp B-tree to
// re-sort. The 2026-05-12 desktop super-slow log captured this as
// `SEARCH outbox USING INDEX idx_outbox_status_priority_created_at
// (status=?)` + `USE TEMP B-TREE FOR ORDER BY` at 553 ms / 706 ms /
// 6.0 s. The literal `WHERE status = 0` keeps the index dense (only
// the actionable pending rows live in it), so the LIMIT walk stops
// at the first row regardless of how many `sent` tombstones have
// accumulated.
@TableIndex.sql(
  'CREATE INDEX idx_outbox_pending_created_id '
  'ON outbox (created_at, id) '
  'WHERE status = 0',
)
// Companion partial for `claimNextOutboxBatch`'s expired-`sending`
// branch (`WHERE status = 3 AND updated_at < cutoff ORDER BY
// created_at ASC, id ASC LIMIT N`). Leading on `updated_at` lets the
// `< cutoff` filter cut the partial index to just the expired rows
// before any sort step; `(created_at, id)` then satisfies the ORDER
// BY without a temp B-tree. Status literal `3` mirrors
// `_outboxSendingStatus = OutboxStatus.sending.index` — same
// enum-order assumption the guard test in
// `test/database/sync_db_test.dart` already enforces.
@TableIndex.sql(
  'CREATE INDEX idx_outbox_sending_expiry '
  'ON outbox (updated_at, created_at, id) '
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

@DriftDatabase(
  tables: [
    Outbox,
    SyncSequenceLog,
    HostActivity,
    InboundEventQueue,
    QueueMarkers,
  ],
)
class SyncDatabase extends _$SyncDatabase {
  SyncDatabase({
    this.inMemoryDatabase = false,
    String? overriddenFilename,
    bool background = true,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : super(
         openDbConnection(
           overriddenFilename ?? syncDbFileName,
           inMemoryDatabase: inMemoryDatabase,
           background: background,
           documentsDirectoryProvider: documentsDirectoryProvider,
           tempDirectoryProvider: tempDirectoryProvider,
         ),
       );

  SyncDatabase.connect(super.c) : super.connect();

  bool inMemoryDatabase = false;

  Future<int> updateOutboxItem(OutboxCompanion item) {
    return (update(
      outbox,
    )..where((t) => t.id.equals(item.id.value))).write(item);
  }

  Future<int> addOutboxItem(OutboxCompanion entry) {
    return into(outbox).insert(entry);
  }

  Future<List<OutboxItem>> get allOutboxItems => select(outbox).get();

  /// Get a single outbox item by its ID.
  /// Used to re-read an item before sending to ensure we have the latest
  /// message after potential merges.
  Future<OutboxItem?> getOutboxItemById(int id) {
    return (select(outbox)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<OutboxItem>> oldestOutboxItems(int limit) {
    return (select(outbox)
          ..where((t) => t.status.equals(OutboxStatus.pending.index))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt),
            (t) => OrderingTerm(expression: t.id),
          ])
          ..limit(limit))
        .get();
  }

  Future<OutboxItem?> claimNextOutboxItem({
    Duration leaseDuration = const Duration(minutes: 1),
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final reclaimWindow = effectiveNow.subtract(leaseDuration);

    return transaction(() async {
      final candidate =
          await (select(outbox)
                ..where(
                  (t) =>
                      (t.status.equals(OutboxStatus.pending.index)) |
                      (t.status.equals(_outboxSendingStatus) &
                          t.updatedAt.isSmallerThanValue(reclaimWindow)),
                )
                ..orderBy([
                  (t) => OrderingTerm(expression: t.createdAt),
                  (t) => OrderingTerm(expression: t.id),
                ])
                ..limit(1))
              .getSingleOrNull();

      if (candidate == null) {
        return null;
      }

      final updated =
          await (update(outbox)..where(
                (t) =>
                    t.id.equals(candidate.id) &
                    t.status.equals(candidate.status) &
                    (candidate.status == _outboxSendingStatus
                        ? t.updatedAt.equals(candidate.updatedAt)
                        : const Constant(true)),
              ))
              .write(
                OutboxCompanion(
                  status: Value(_outboxSendingStatus),
                  updatedAt: Value(effectiveNow),
                ),
              );

      if (updated != 1) {
        return null;
      }

      return OutboxItem(
        id: candidate.id,
        createdAt: candidate.createdAt,
        updatedAt: effectiveNow,
        status: _outboxSendingStatus,
        retries: candidate.retries,
        message: candidate.message,
        subject: candidate.subject,
        filePath: candidate.filePath,
        outboxEntryId: candidate.outboxEntryId,
        payloadSize: candidate.payloadSize,
        priority: candidate.priority,
      );
    });
  }

  /// Atomically claim a batch of consecutive outbox rows in createdAt order,
  /// transitioning each from `pending` (or an expired `sending` lease) to
  /// `sending` under one transaction.
  ///
  /// Boundary rule for `OutboxProcessor` bundling:
  ///  - If the head row has `filePath != null` (media attachment), the
  ///    returned list contains only that row. Media attachments always
  ///    travel alone.
  ///  - Otherwise, the returned list is the maximal prefix of consecutive
  ///    rows whose `filePath` is null, capped at [maxSize]. The walk stops
  ///    at the first media attachment, so the returned slice can be sent
  ///    as a single bundle envelope.
  ///
  /// If a CAS race causes any per-row update to fail mid-batch, the walk
  /// stops there. The returned list is always a contiguous prefix of the
  /// query order — never a non-contiguous gap, which would otherwise
  /// violate `createdAt` send ordering.
  Future<List<OutboxItem>> claimNextOutboxBatch({
    required int maxSize,
    Duration leaseDuration = const Duration(minutes: 1),
    DateTime? now,
  }) async {
    if (maxSize <= 0) return const <OutboxItem>[];
    final effectiveNow = now ?? DateTime.now();
    final reclaimWindow = effectiveNow.subtract(leaseDuration);

    return transaction(() async {
      // Split the original `status = pending OR (status = sending AND
      // updated_at < cutoff)` into two indexed seeks. The combined
      // predicate prevented the planner from matching either of the
      // existing outbox indices and forced a SCAN (218 ms in the
      // super-slow log). Each branch is now a clean equality on
      // `status`. The merge in Dart is bounded by `2 × maxSize` rows;
      // trivial. `id` is the secondary sort key so the merged batch
      // matches the contiguous-prefix ordering contract that
      // `OutboxRepository.claimNextBatch` and
      // `OutboxProcessor._processBundle` rely on: when `createdAt`
      // ties, picking a stable order keeps the first
      // `filePath != null` boundary deterministic across repeated
      // calls.
      final pendingRows =
          await (select(outbox)
                ..where(
                  (t) => t.status.equals(OutboxStatus.pending.index),
                )
                ..orderBy([
                  (t) => OrderingTerm(expression: t.createdAt),
                  (t) => OrderingTerm(expression: t.id),
                ])
                ..limit(maxSize))
              .get();
      final expiredSendingRows =
          await (select(outbox)
                ..where(
                  (t) =>
                      t.status.equals(_outboxSendingStatus) &
                      t.updatedAt.isSmallerThanValue(reclaimWindow),
                )
                ..orderBy([
                  (t) => OrderingTerm(expression: t.createdAt),
                  (t) => OrderingTerm(expression: t.id),
                ])
                ..limit(maxSize))
              .get();
      final candidates = <OutboxItem>[...pendingRows, ...expiredSendingRows]
        ..sort((a, b) {
          final created = a.createdAt.compareTo(b.createdAt);
          if (created != 0) return created;
          return a.id.compareTo(b.id);
        });
      if (candidates.length > maxSize) {
        candidates.removeRange(maxSize, candidates.length);
      }

      if (candidates.isEmpty) return const <OutboxItem>[];

      final List<OutboxItem> selected;
      if (candidates.first.filePath != null) {
        selected = [candidates.first];
      } else {
        final stopAt = candidates.indexWhere(
          (row) => row.filePath != null,
        );
        selected = stopAt == -1 ? candidates : candidates.sublist(0, stopAt);
      }

      final claimed = <OutboxItem>[];
      for (final candidate in selected) {
        final updated =
            await (update(outbox)..where(
                  (t) =>
                      t.id.equals(candidate.id) &
                      t.status.equals(candidate.status) &
                      (candidate.status == _outboxSendingStatus
                          ? t.updatedAt.equals(candidate.updatedAt)
                          : const Constant(true)),
                ))
                .write(
                  OutboxCompanion(
                    status: Value(_outboxSendingStatus),
                    updatedAt: Value(effectiveNow),
                  ),
                );
        if (updated != 1) {
          break;
        }
        claimed.add(
          candidate.copyWith(
            status: _outboxSendingStatus,
            updatedAt: effectiveNow,
          ),
        );
      }

      return claimed;
    });
  }

  /// Bulk-set every row whose id is in [ids] to `sent`, stamping
  /// `updatedAt = now`. Single SQL `UPDATE … WHERE id IN (…)` instead of N
  /// per-row writes — used by `OutboxRepository.markSentBatch` after a
  /// bundle send succeeds.
  Future<void> markOutboxItemsSent({
    required List<int> ids,
    DateTime? now,
  }) async {
    if (ids.isEmpty) return;
    await (update(outbox)..where((t) => t.id.isIn(ids))).write(
      OutboxCompanion(
        status: Value(OutboxStatus.sent.index),
        updatedAt: Value(now ?? DateTime.now()),
      ),
    );
  }

  SimpleSelectStatement<$OutboxTable, OutboxItem> _outboxItemsQuery({
    required int limit,
    required List<OutboxStatus> statuses,
  }) {
    return select(outbox)
      ..where(
        (t) => t.status.isIn(
          statuses.map((OutboxStatus status) => status.index),
        ),
      )
      ..orderBy([
        // Actionable items (pending/sending) appear before completed ones
        // so they are never pushed outside the query limit by old sent rows.
        (t) => OrderingTerm(
          expression: CustomExpression<int>(
            'CASE WHEN status IN '
            '(${OutboxStatus.pending.index}, $_outboxSendingStatus) THEN 0 '
            'WHEN status = ${OutboxStatus.error.index} THEN 1 '
            'ELSE 2 END',
          ),
        ),
        (t) => OrderingTerm(expression: t.priority),
        (t) => OrderingTerm(
          expression: t.createdAt,
          mode: OrderingMode.desc,
        ),
        // Deterministic tie-breaker — without this, rows near the
        // limit boundary can swap places between refreshes when
        // priority and createdAt match. Matches the id tie-break used
        // in claimNextOutboxBatch().
        (t) => OrderingTerm(
          expression: t.id,
          mode: OrderingMode.desc,
        ),
      ])
      ..limit(limit);
  }

  Stream<List<OutboxItem>> watchOutboxItems({
    int limit = 1000,
    List<OutboxStatus> statuses = const [
      OutboxStatus.pending,
      OutboxStatus.sending,
      OutboxStatus.error,
      OutboxStatus.sent,
    ],
  }) {
    return _outboxItemsQuery(limit: limit, statuses: statuses).watch();
  }

  /// One-shot fetch with the same shape and ordering as [watchOutboxItems].
  /// Used by surfaces that explicitly opt out of the live watcher (e.g.
  /// the outbox monitor page, which would otherwise re-run a temp-B-tree
  /// sort on every sync write).
  Future<List<OutboxItem>> getOutboxItems({
    int limit = 1000,
    List<OutboxStatus> statuses = const [
      OutboxStatus.pending,
      OutboxStatus.sending,
      OutboxStatus.error,
      OutboxStatus.sent,
    ],
  }) {
    return _outboxItemsQuery(limit: limit, statuses: statuses).get();
  }

  /// Watches the count of actionable (pending + in-flight) outbox items.
  /// Used by the badge to show how many items still need to be sent.
  Stream<int> watchOutboxCount() {
    final query = selectOnly(outbox)
      ..addColumns([outbox.id.count()])
      ..where(
        outbox.status.isIn([
          OutboxStatus.pending.index,
          _outboxSendingStatus,
        ]),
      );
    return query.watchSingle().map((row) => row.read(outbox.id.count()) ?? 0);
  }

  /// Delete a single outbox item by its ID.
  Future<int> deleteOutboxItemById(int id) {
    return (delete(outbox)..where((t) => t.id.equals(id))).go();
  }

  /// Prune outbox rows with `status = sent` whose `updated_at` is older
  /// than [retention]. `updated_at` is the send time (set by `markSent`);
  /// `created_at` is the enqueue time, which can be days older for rows
  /// that were stuck pending. Using send time means "7 days retained as
  /// sent" regardless of how long the row waited in pending — and it
  /// matches the same send-time definition used by the outbox volume
  /// view in the UI.
  ///
  /// Error rows (`status = error`) are deliberately kept regardless of
  /// age so a human can still inspect persistently failed sends;
  /// pending and sending rows are live state and are never considered
  /// for pruning.
  ///
  /// Without this, the outbox grows unbounded (observed: 395k rows on
  /// desktop, 265k on mobile). Every outbox enqueue pays the table-size
  /// cost on indexed writes, WAL checkpoints get heavier, and backups
  /// balloon. A week of kept-forever sent rows is already far more
  /// than the `outbox_entry_id` dedup path requires (dedup only
  /// matters for in-flight edits — a message already sent more than a
  /// minute ago will never be re-deduped).
  ///
  /// Returns the number of rows deleted.
  Future<int> pruneSentOutboxItems({
    required Duration retention,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(retention);
    return (delete(outbox)..where(
          (t) =>
              t.status.equals(OutboxStatus.sent.index) &
              t.updatedAt.isSmallerThanValue(cutoff),
        ))
        .go();
  }

  /// Same retention semantics as [pruneSentOutboxItems], but deletes in
  /// bounded chunks so the writer lock is released between batches and
  /// concurrent enqueue/claim/watch can interleave. Required for one-shot
  /// cleanup on devices where the table has accumulated hundreds of
  /// thousands of `sent` rows — a single unbounded DELETE on that volume
  /// holds the writer for many seconds and stalls the whole sync pipeline.
  ///
  /// Each pass deletes up to [chunkSize] rows, then awaits a microtask
  /// (or the supplied [yieldDelay]) to let other queued statements run.
  /// Loop terminates when a pass deletes fewer than [chunkSize] rows.
  ///
  /// When [vacuumWhenDone] is true and at least one row was deleted, runs
  /// `VACUUM` after the loop to reclaim disk space — VACUUM rewrites the
  /// whole DB file, so it is opt-in and only worth running after a large
  /// purge.
  ///
  /// [onProgress] receives the running deletion total after each chunk;
  /// callers (UI, periodic timer) can emit traces or update progress UI.
  Future<int> pruneSentOutboxItemsChunked({
    required Duration retention,
    int chunkSize = 5000,
    Duration yieldDelay = Duration.zero,
    bool vacuumWhenDone = false,
    DateTime? now,
    void Function(int deletedSoFar)? onProgress,
  }) async {
    // A non-positive `chunkSize` would wedge the loop:
    // - `chunkSize == 0` → `LIMIT 0` deletes nothing, `n == 0`,
    //   `n < chunkSize` is `0 < 0` → false → infinite spin.
    // - `chunkSize < 0` → SQLite treats `LIMIT -1` as "no limit"
    //   so the first pass deletes every eligible row, but the
    //   termination check still fails (e.g. `n < -1`).
    // Mirror the same short-circuit `_retireInPages` uses for
    // `pageSize <= 0` so a misconfigured caller cannot stall the
    // writer.
    if (chunkSize <= 0) return 0;
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(retention);
    final sentStatus = OutboxStatus.sent.index;
    var total = 0;
    while (true) {
      // Subquery on `id` lets us bound a single statement's row count via
      // LIMIT — drift's `delete(...).where(...)` does not expose LIMIT
      // directly. The inner SELECT walks
      // `idx_outbox_status_priority_created_at` (status leading column) so
      // it is index-bounded, not a scan.
      final n = await customUpdate(
        'DELETE FROM outbox WHERE id IN '
        '(SELECT id FROM outbox '
        'WHERE status = ? AND updated_at < ? '
        'LIMIT ?)',
        variables: [
          Variable.withInt(sentStatus),
          Variable.withDateTime(cutoff),
          Variable.withInt(chunkSize),
        ],
        updates: {outbox},
      );
      total += n;
      onProgress?.call(total);
      if (n < chunkSize) break;
      // Yield the writer so other statements queued behind the chunk can
      // run before we ask for another delete batch.
      await Future<void>.delayed(yieldDelay);
    }
    if (vacuumWhenDone && total > 0) {
      await customStatement('VACUUM');
    }
    return total;
  }

  /// Get (hostId, counter) pairs from queued or in-flight backfill request
  /// messages in outbox.
  ///
  /// Used to avoid enqueuing duplicate backfill requests while an older request
  /// is still pending or leased in `sending`.
  ///
  /// Two filters applied at SQL level keep this cheap on devices where the
  /// outbox has accumulated hundreds of thousands of rows:
  /// 1. `status IN (0, 3)` is inlined as a literal SQL fragment via
  ///    `CustomExpression` so the SQLite planner can prove this query's
  ///    WHERE implies the partial index's WHERE clause
  ///    (`idx_outbox_actionable_priority_created_at`, declared with
  ///    `WHERE status IN (0, 3)`). Drift's
  ///    `t.status.isIn([pending, sending])` binds the two status values
  ///    as parameters; the planner can't see them at plan time, the
  ///    partial-index match fails, and the predicate falls back to a
  ///    full table scan. The 2026-05-12 desktop slow_queries log
  ///    captured this shape at 357 hits/day with every plan reading
  ///    `SCAN outbox` (avg 226 ms, max 1.8 s) before the rewrite.
  ///    Literal values mirror `OutboxStatus.pending.index = 0` and
  ///    `_outboxSendingStatus = 3` — the guard test in
  ///    `test/database/sync_db_test.dart` asserts the partial-index
  ///    declaration stays in sync with this assumption.
  /// 2. `subject LIKE 'backfillRequest:%'` — `_enqueueBackfillRequest`
  ///    sets `subject` to `'backfillRequest:batch:N'` for every backfill
  ///    request enqueue, so the prefix is a reliable marker. Without
  ///    this filter we materialise every actionable row and JSON-decode
  ///    each one to find the tiny subset of backfill requests; with it,
  ///    only the matching rows are decoded.
  Future<Set<({String hostId, int counter})>>
  getPendingBackfillEntries() async {
    final pendingItems =
        await (select(outbox)..where(
              (t) =>
                  const CustomExpression<bool>('status IN (0, 3)') &
                  t.subject.like('backfillRequest:%'),
            ))
            .get();

    final entries = <({String hostId, int counter})>{};

    for (final item in pendingItems) {
      try {
        final json = jsonDecode(item.message) as Map<String, dynamic>;
        // Defensive: a row whose subject starts with `backfillRequest:`
        // but whose message is some other shape would still be filtered
        // out here. The subject is set adjacent to the JSON encode in
        // `_enqueueBackfillRequest`, so this check is just belt and
        // braces.
        if (json['runtimeType'] != 'backfillRequest') continue;
        final entriesList = json['entries'] as List<dynamic>?;
        if (entriesList == null) continue;
        for (final entry in entriesList) {
          if (entry is Map<String, dynamic>) {
            final hostId = entry['hostId'] as String?;
            final counter = entry['counter'] as int?;
            if (hostId != null && counter != null) {
              entries.add((hostId: hostId, counter: counter));
            }
          }
        }
      } catch (_) {
        // Skip malformed messages
      }
    }

    return entries;
  }

  // ============ Sync Sequence Log Methods ============

  /// Record or update a sequence log entry.
  /// Uses insertOnConflictUpdate to handle upserts.
  Future<int> recordSequenceEntry(SyncSequenceLogCompanion entry) {
    return into(syncSequenceLog).insertOnConflictUpdate(entry);
  }

  /// Get the highest contiguous resolved counter for a given host, starting
  /// from counter `1`.
  ///
  /// Returns:
  /// - `null` when the host is entirely unknown to this device
  /// - `0` when the host is known but counter `1` is still unresolved
  /// - `N > 0` when every counter `1..N` is resolved or terminal
  ///
  /// This is intentionally not `MAX(counter)`. Gap detection must not advance
  /// past unresolved earlier counters just because a sparse newer row exists.
  Future<int?> getLastCounterForHost(String hostId) async {
    final received = SyncSequenceStatus.received.index;
    final backfilled = SyncSequenceStatus.backfilled.index;
    final deleted = SyncSequenceStatus.deleted.index;
    final unresolvable = SyncSequenceStatus.unresolvable.index;

    // Within the resolved subset, `counter == row_number()` only holds while we
    // still have the contiguous prefix `1..N`. The first hole or unresolved
    // status breaks that equality, which is exactly the watermark we need.
    final query = customSelect(
      '''
      WITH host_counters AS (
        SELECT counter, status
        FROM sync_sequence_log
        WHERE host_id = ?
      ),
      resolved_prefix AS (
        SELECT
          counter,
          ROW_NUMBER() OVER (ORDER BY counter) AS rn
        FROM host_counters
        WHERE status IN (?, ?, ?, ?)
      )
      SELECT CASE
        WHEN (SELECT COUNT(*) FROM host_counters) = 0 THEN NULL
        ELSE COALESCE(
          (
            SELECT MAX(counter)
            FROM resolved_prefix
            WHERE counter = rn
          ),
          0
        )
      END AS last_counter
      ''',
      variables: [
        Variable.withString(hostId),
        Variable.withInt(received),
        Variable.withInt(backfilled),
        Variable.withInt(deleted),
        Variable.withInt(unresolvable),
      ],
      readsFrom: {syncSequenceLog},
    );

    final result = await query.getSingle();
    return result.readNullable<int>('last_counter');
  }

  /// Get entries with status 'missing' or 'requested' that haven't
  /// exceeded maxRequestCount, ordered by creation time (oldest first).
  /// Return rows in `missing` / `requested` state that are still eligible
  /// for a backfill request.
  ///
  /// [minAge] holds rows freshly detected as missing back for a grace window,
  /// so a short-lived gap caused by out-of-order priority messages resolves
  /// naturally via the standard sync path before backfill fires. Only rows
  /// whose `created_at` is at or before `now - minAge` are returned. Pass
  /// `Duration.zero` to disable (manual / "request now" paths).
  Future<List<SyncSequenceLogItem>> getMissingEntries({
    int limit = 50,
    int maxRequestCount = 10,
    int offset = 0,
    Duration minAge = Duration.zero,
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(minAge);
    return (select(syncSequenceLog)
          ..where(
            (t) =>
                (t.status.equals(SyncSequenceStatus.missing.index) |
                    t.status.equals(SyncSequenceStatus.requested.index)) &
                t.requestCount.isSmallerThanValue(maxRequestCount) &
                t.createdAt.isSmallerOrEqualValue(cutoff),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Update the status of a sequence log entry.
  Future<int> updateSequenceStatus(
    String hostId,
    int counter,
    SyncSequenceStatus status,
  ) {
    return (update(syncSequenceLog)..where(
          (t) => t.hostId.equals(hostId) & t.counter.equals(counter),
        ))
        .write(
          SyncSequenceLogCompanion(
            status: Value(status.index),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Batch increment request counts for multiple entries.
  /// Uses batch operations for efficiency while maintaining atomic increments.
  Future<void> batchIncrementRequestCounts(
    List<({String hostId, int counter})> entries,
  ) async {
    if (entries.isEmpty) return;

    final now = DateTime.now();
    // Drift's default `dateTime()` column encodes values as Unix seconds
    // (see the `store_date_time_values_as_text` guide). Anything written
    // via raw `customStatement` bindings must match that encoding, or
    // later comparisons like `retireExhaustedRequestedEntries`' cutoff
    // (bound via `Variable.withDateTime(...)`) will compare milliseconds
    // against seconds and silently never match.
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    await batch((b) {
      for (final entry in entries) {
        b.customStatement(
          'UPDATE sync_sequence_log '
          'SET request_count = request_count + 1, '
          'status = ?, '
          'updated_at = ?, '
          'last_requested_at = ? '
          'WHERE host_id = ? AND counter = ?',
          [
            SyncSequenceStatus.requested.index,
            nowSeconds,
            nowSeconds,
            entry.hostId,
            entry.counter,
          ],
        );
      }
    });
  }

  /// Get a specific sequence log entry by host ID and counter.
  Future<SyncSequenceLogItem?> getEntryByHostAndCounter(
    String hostId,
    int counter,
  ) {
    return (select(syncSequenceLog)..where(
          (t) => t.hostId.equals(hostId) & t.counter.equals(counter),
        ))
        .getSingleOrNull();
  }

  /// Find the nearest sequence log entry for a host with a counter >= [counter]
  /// that has a locally resolved payload. Used to find covering entries when
  /// the exact counter is not in the sequence log (superseded).
  ///
  /// Only returns rows with `received` or `backfilled` status to avoid
  /// returning hint-only rows (where `entryId` is set but the payload may
  /// not exist locally yet).
  Future<SyncSequenceLogItem?> getNearestCoveringEntry(
    String hostId,
    int counter,
  ) {
    return (select(syncSequenceLog)
          ..where(
            (t) =>
                t.hostId.equals(hostId) &
                t.counter.isBiggerOrEqualValue(counter) &
                t.entryId.isNotNull() &
                (t.status.equals(SyncSequenceStatus.received.index) |
                    t.status.equals(SyncSequenceStatus.backfilled.index)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.counter)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get the highest counter sent by [hostId] for a given [entryId].
  /// Returns null when this host has never sent the entry.
  /// Used to build covered vector clocks for already-sent predecessors so
  /// that receivers can resolve intermediate counters without backfill.
  Future<int?> getLastSentCounterForEntry(String hostId, String entryId) async {
    final received = SyncSequenceStatus.received.index;
    final backfilled = SyncSequenceStatus.backfilled.index;
    // ORDER BY counter DESC LIMIT 1 resolves as an index-only scan against
    // `idx_sync_sequence_log_host_entry_status_counter` with early
    // termination on the first match, instead of scanning every row that
    // matches the prefix just to compute MAX(counter).
    final query = customSelect(
      '''
      SELECT counter AS last_counter
      FROM sync_sequence_log
      WHERE host_id = ?
        AND entry_id = ?
        AND status IN (?, ?)
      ORDER BY counter DESC
      LIMIT 1
      ''',
      variables: [
        Variable.withString(hostId),
        Variable.withString(entryId),
        Variable.withInt(received),
        Variable.withInt(backfilled),
      ],
      readsFrom: {syncSequenceLog},
    );
    final result = await query.getSingleOrNull();
    return result?.readNullable<int>('last_counter');
  }

  /// Get all pending (missing/requested) sequence log entries for a given payload.
  /// Used to resolve pending backfill hints when a payload arrives via sync.
  Future<List<SyncSequenceLogItem>> getPendingEntriesByPayloadId({
    required SyncSequencePayloadType payloadType,
    required String payloadId,
  }) {
    return (select(syncSequenceLog)..where(
          (t) =>
              t.entryId.equals(payloadId) &
              t.payloadType.equals(payloadType.index) &
              (t.status.equals(SyncSequenceStatus.missing.index) |
                  t.status.equals(SyncSequenceStatus.requested.index)),
        ))
        .get();
  }

  /// Get the total count of entries in the sequence log.
  Future<int> getSequenceLogCount() async {
    final countQuery = selectOnly(syncSequenceLog)
      ..addColumns([syncSequenceLog.hostId.count()]);
    final countResult = await countQuery.getSingle();
    return countResult.read(syncSequenceLog.hostId.count()) ?? 0;
  }

  // ============ Host Activity Methods ============

  /// Update or insert host activity (last seen timestamp).
  Future<int> updateHostActivity(String hostId, DateTime lastSeenAt) {
    return into(hostActivity).insertOnConflictUpdate(
      HostActivityCompanion(
        hostId: Value(hostId),
        lastSeenAt: Value(lastSeenAt),
      ),
    );
  }

  /// Get the last seen timestamp for a host.
  Future<DateTime?> getHostLastSeen(String hostId) async {
    final result = await (select(
      hostActivity,
    )..where((t) => t.hostId.equals(hostId))).getSingleOrNull();
    return result?.lastSeenAt;
  }

  /// Get all existing counters for a specific host.
  /// Used for efficient bulk population to avoid N+1 queries.
  Future<Set<int>> getCountersForHost(String hostId) async {
    final entries = await (select(
      syncSequenceLog,
    )..where((t) => t.hostId.equals(hostId))).map((row) => row.counter).get();
    return entries.toSet();
  }

  /// Get existing counters for a specific host within an inclusive range.
  /// Used to materialize large gaps without doing one lookup per counter.
  Future<Set<int>> getCountersForHostInRange(
    String hostId,
    int startCounter,
    int endCounter,
  ) async {
    if (endCounter < startCounter) return <int>{};
    final entries =
        await (select(syncSequenceLog)..where(
              (t) =>
                  t.hostId.equals(hostId) &
                  t.counter.isBiggerOrEqualValue(startCounter) &
                  t.counter.isSmallerOrEqualValue(endCounter),
            ))
            .map((row) => row.counter)
            .get();
    return entries.toSet();
  }

  /// Batch insert multiple sequence log entries.
  Future<void> batchInsertSequenceEntries(
    List<SyncSequenceLogCompanion> entries,
  ) async {
    await batch((b) {
      b.insertAll(syncSequenceLog, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  /// Get backfill statistics grouped by host.
  /// Returns counts of entries in each status per host.
  ///
  /// Implementation note: the previous `SUM(CASE WHEN status=…)`
  /// formulation forced a full table scan of `sync_sequence_log`
  /// (700 k+ rows on production devices, 858 s of cumulative DB time
  /// per day on a real desktop). With the v15
  /// `idx_sync_sequence_log_host_status` covering index, GROUP BY
  /// `(host_id, status)` is an index-only scan that emits ~80 rows
  /// (≈ hosts × statuses), and the per-host pivot happens cheaply in
  /// Dart.
  Future<BackfillStats> getBackfillStats() async {
    final hostStatusCounts = await customSelect(
      '''
      SELECT host_id, status, COUNT(*) AS cnt
      FROM sync_sequence_log
      GROUP BY host_id, status
      ''',
      readsFrom: {syncSequenceLog},
    ).get();

    if (hostStatusCounts.isEmpty) {
      return BackfillStats.fromHostStats(const []);
    }

    final perHost = <String, Map<int, int>>{};
    for (final row in hostStatusCounts) {
      final host = row.read<String>('host_id');
      final status = row.read<int>('status');
      final count = row.read<int>('cnt');
      perHost.putIfAbsent(host, () => <int, int>{})[status] = count;
    }

    final received = SyncSequenceStatus.received.index;
    final missing = SyncSequenceStatus.missing.index;
    final requested = SyncSequenceStatus.requested.index;
    final backfilled = SyncSequenceStatus.backfilled.index;
    final deleted = SyncSequenceStatus.deleted.index;
    final unresolvable = SyncSequenceStatus.unresolvable.index;

    final hostIds = perHost.keys.toList()..sort();
    final hostStats = [
      for (final host in hostIds)
        BackfillHostStats(
          receivedCount: perHost[host]![received] ?? 0,
          missingCount: perHost[host]![missing] ?? 0,
          requestedCount: perHost[host]![requested] ?? 0,
          backfilledCount: perHost[host]![backfilled] ?? 0,
          deletedCount: perHost[host]![deleted] ?? 0,
          unresolvableCount: perHost[host]![unresolvable] ?? 0,
        ),
    ];

    return BackfillStats.fromHostStats(hostStats);
  }

  /// Get entries with status 'requested' for re-requesting.
  /// These are entries that were requested but never received.
  /// Ignores maxRequestCount to allow re-requesting stuck entries.
  Future<List<SyncSequenceLogItem>> getRequestedEntries({
    int limit = 50,
    int offset = 0,
  }) {
    return (select(syncSequenceLog)
          ..where(
            (t) => t.status.equals(SyncSequenceStatus.requested.index),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Reset request count and last requested time for specified entries.
  /// This allows them to be re-requested as if they were new.
  /// Uses batch operations for efficiency.
  Future<void> resetRequestCounts(
    List<({String hostId, int counter})> entries,
  ) async {
    if (entries.isEmpty) return;

    final now = DateTime.now();
    await batch((b) {
      for (final entry in entries) {
        b.update(
          syncSequenceLog,
          SyncSequenceLogCompanion(
            requestCount: const Value(0),
            lastRequestedAt: const Value(null),
            updatedAt: Value(now),
          ),
          where: (t) =>
              t.hostId.equals(entry.hostId) & t.counter.equals(entry.counter),
        );
      }
    });
  }

  /// Cheap existence probe for any actionable (`missing` or `requested`) row.
  ///
  /// Used as the gate for the periodic backfill timer: when the table holds
  /// no actionable rows, the timer body can skip both retire passes and the
  /// `_loadNextUnqueuedMissingBatch` work entirely. The slow-query log on
  /// 2026-05-12 showed `processBackfillRequests` ticking 347 times against
  /// an empty actionable set, each pass running 5 sync_db queries — one
  /// of which (`getPendingBackfillEntries`) hit the outbox at 226 ms avg.
  ///
  /// `status IN (1, 2)` is inlined as a literal SQL fragment via
  /// `CustomExpression` so the SQLite planner can prove this query's WHERE
  /// implies the partial index
  /// `idx_sync_sequence_log_actionable_status_created_at`'s WHERE clause
  /// (`WHERE status IN (1, 2)`). With a `LIMIT 1` the planner short-circuits
  /// on the first matching index row, so this is effectively O(log n) on the
  /// partial index even with hundreds of thousands of historical rows
  /// already in `received`/`backfilled`/`unresolvable`.
  Future<bool> hasActionableEntries() async {
    final row = await customSelect(
      'SELECT 1 FROM sync_sequence_log WHERE status IN (1, 2) LIMIT 1',
      readsFrom: {syncSequenceLog},
    ).getSingleOrNull();
    return row != null;
  }

  /// Get missing entries with age and per-host limits for automatic backfill.
  /// [maxAge] - Only include entries created within this duration
  /// [minAge] - Debounce window: rows freshly flagged as missing are held back
  ///           until their `created_at` is at or before `now - minAge`. This
  ///           lets short-lived gaps caused by out-of-order priority messages
  ///           resolve via the standard sync path before backfill fires. Pass
  ///           `Duration.zero` to disable (default).
  /// [maxPerHost] - Maximum entries to include per host
  Future<List<SyncSequenceLogItem>> getMissingEntriesWithLimits({
    int limit = 50,
    int maxRequestCount = 10,
    Duration? maxAge,
    Duration minAge = Duration.zero,
    int? maxPerHost,
    DateTime? now,
    int offset = 0,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final minAgeCutoff = effectiveNow.subtract(minAge);
    // All three time/count gates (`minAge`, `maxAge`, `maxRequestCount`) are
    // pushed into the SQL WHERE so we never materialise rows we'd
    // immediately discard. The per-host cap is still post-processed because
    // SQLite plain selects don't have a window-function-free way to
    // express "top N rows per host"; that post-processing runs on the
    // bounded result set below.
    final baseQuery = select(syncSequenceLog)
      ..where((t) {
        // `status IN (1, 2)` is inlined as a literal SQL fragment via
        // `CustomExpression` so the SQLite planner can prove it implies
        // the partial index's WHERE
        // (`idx_sync_sequence_log_actionable_status_created_at`,
        // declared with `WHERE status IN (1, 2)`). Drift's
        // `t.status.equals(?) | t.status.equals(?)` and
        // `t.status.isIn([?, ?])` both bind the values as parameters
        // unknown at plan time; the partial-index match fails and the
        // predicate falls back to a full table scan. The 2026-05-09
        // desktop slow_queries log captured this shape at 399 hits/day
        // in the 200–999 ms band before the rewrite. Literal values
        // mirror `SyncSequenceStatus.missing.index = 1` and
        // `.requested.index = 2`, matching the migration's enum-order
        // assumption.
        var predicate =
            const CustomExpression<bool>('status IN (1, 2)') &
            t.requestCount.isSmallerThanValue(maxRequestCount) &
            t.createdAt.isSmallerOrEqualValue(minAgeCutoff);
        if (maxAge != null) {
          final maxAgeCutoff = effectiveNow.subtract(maxAge);
          predicate = predicate & t.createdAt.isBiggerThanValue(maxAgeCutoff);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);

    // Cap the SQL fetch so a pathologically large missing-row backlog does
    // not blow up memory. Without `maxPerHost` the tight `offset + limit`
    // bound is exactly what the caller wants. With `maxPerHost`, the Dart
    // post-filter needs to see enough rows per host to pick the first N
    // per host while still honouring `offset + limit` across hosts — so
    // we fall back to a generous fixed cap. At production tuning
    // (`backfillProcessingBatchSize = 100`, `defaultBackfillMaxEntriesPerHost
    // = 250`), this cap is >> any realistic per-cycle working set; if it
    // ever saturates, the next periodic cycle picks up the remainder.
    const perHostFetchCap = 10000;
    final sqlFetchLimit = maxPerHost != null ? perHostFetchCap : offset + limit;
    baseQuery.limit(sqlFetchLimit);

    var entries = await baseQuery.get();

    // Apply per-host limit if specified
    if (maxPerHost != null) {
      final byHost = <String, List<SyncSequenceLogItem>>{};
      for (final entry in entries) {
        byHost.putIfAbsent(entry.hostId, () => []).add(entry);
      }
      entries = byHost.values.expand((list) => list.take(maxPerHost)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return entries.skip(offset).take(limit).toList();
  }

  /// Retire missing/requested rows whose request_count has reached the cap
  /// by flipping their status to `unresolvable`. Rows in `missing`/`requested`
  /// block the contiguous-prefix watermark in [getLastCounterForHost]; once
  /// a row has been asked for more than [maxRequestCount] times without
  /// resolving, the counter it points to is almost certainly unobtainable
  /// (pre-history entry, purged payload, or permanently VC-behind mapping).
  /// Promoting it to the terminal `unresolvable` state lets the watermark
  /// advance and stops every incoming event from paying the gap-detection
  /// cost for the same stuck range.
  ///
  /// A row is only retired when its most-recent request is older than
  /// [now] minus [grace], so a backfill request still queued in the outbox
  /// or in flight to a peer gets a fair chance to resolve before we flip
  /// the row terminal. Rows without a recorded `last_requested_at` (never
  /// requested, yet still past the count cap — unusual) are not retired.
  ///
  /// Returns the number of rows retired.
  ///
  /// Paginated: each [pageSize] batch flips in its own transaction so
  /// the writer lock is released between pages instead of being held
  /// for the full set. On a real desktop a single un-paginated UPDATE
  /// over a backlog of stuck rows held the lock for ~1.9 s and
  /// starved concurrent journal reads (slow_queries log,
  /// 2026-05-02). Smaller pages bound the worst-case lock hold to one
  /// page's worth of writes.
  Future<int> retireExhaustedRequestedEntries({
    int maxRequestCount = 10,
    Duration grace = const Duration(minutes: 5),
    DateTime? now,
    int pageSize = 500,
  }) async {
    final unresolvable = SyncSequenceStatus.unresolvable.index;
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(grace);

    // `status IN (1, 2)` is inlined as a literal so the SQLite planner
    // can prove this query's WHERE is implied by the partial index's
    // WHERE (`idx_sync_sequence_log_actionable_status_last_requested_at`,
    // declared with the same literal `WHERE status IN (1, 2)`). The
    // earlier `(status = ? OR status = ?)` form bound the status values
    // as parameters; the planner couldn't see them at plan time, the
    // partial index match failed, and the predicate fell back to a full
    // table scan (slow_queries log on the 2026-05-09 desktop: 403 hits
    // in the 200–999 ms band, sum 122 s/day). The literals here mirror
    // `SyncSequenceStatus.missing.index = 1` and `.requested.index = 2`
    // — same enum-order assumption already baked into the migrations.
    return _retireInPages(
      pageSize: pageSize,
      selectKeysSql:
          'SELECT host_id, counter FROM sync_sequence_log '
          'WHERE status IN (1, 2) '
          '  AND request_count >= ? '
          '  AND last_requested_at IS NOT NULL '
          '  AND last_requested_at < ? '
          'LIMIT ?',
      selectVariables: [
        Variable.withInt(maxRequestCount),
        Variable.withDateTime(cutoff),
      ],
      newStatus: unresolvable,
      effectiveNow: effectiveNow,
    );
  }

  /// Retire `missing`/`requested` rows whose `updated_at` is older than
  /// [amnestyWindow] by flipping their status to `unresolvable`,
  /// regardless of `request_count` or `last_requested_at`.
  ///
  /// The age check is against `updated_at` (the most recent status
  /// transition), not `created_at`, because the "Ask peers for
  /// unresolvable entries" action flips rows back to `missing` and
  /// refreshes `updated_at`. Using `created_at` would let the next
  /// sweep immediately re-retire rows the user just reopened —
  /// defeating the purpose of the peer-reask action.
  ///
  /// [retireExhaustedRequestedEntries] only retires rows that have been
  /// actively requested and hit the count cap. That leaves a failure
  /// mode where a row can slip into `requested` via
  /// `SyncSequenceLogService.handleBackfillResponse`'s hint-insertion
  /// path (which creates a row with status=`requested` but never sets
  /// `last_requested_at`), OR a row in `missing` accumulates a
  /// low `request_count` and then ages out of
  /// [getMissingEntriesWithLimits]'s `maxAge` window before hitting
  /// the cap. Either way, the row stays in a non-terminal status
  /// forever, blocking the contiguous-prefix watermark in
  /// [getLastCounterForHost] and causing every new event on the same
  /// host to re-emit the same gap range through gap detection.
  ///
  /// This method is the amnesty half of the retire pair: any
  /// `missing`/`requested` row older than [amnestyWindow] is treated as
  /// unresolvable. `amnestyWindow` should be wider than the active
  /// backfill-request window ([SyncTuning.defaultBackfillMaxAge]) so
  /// rows have a fair chance to be requested before being retired, but
  /// narrow enough that truly stuck rows do not accumulate
  /// indefinitely.
  ///
  /// Returns the number of rows retired.
  ///
  /// Paginated for the same lock-hold reason as
  /// [retireExhaustedRequestedEntries].
  Future<int> retireAgedOutRequestedEntries({
    Duration amnestyWindow = const Duration(days: 7),
    DateTime? now,
    int pageSize = 500,
  }) async {
    final unresolvable = SyncSequenceStatus.unresolvable.index;
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(amnestyWindow);

    // Same `IN (1, 2)` literal trick as
    // [retireExhaustedRequestedEntries] — needed so the planner can
    // match the partial index
    // `idx_sync_sequence_log_actionable_status_updated_at` (declared
    // `WHERE status IN (1, 2)`). 2026-05-09 desktop slow_queries log
    // showed this shape at 406 hits/day in the 200–999 ms band before
    // the rewrite.
    return _retireInPages(
      pageSize: pageSize,
      selectKeysSql:
          'SELECT host_id, counter FROM sync_sequence_log '
          'WHERE status IN (1, 2) '
          '  AND updated_at < ? '
          'LIMIT ?',
      selectVariables: [
        Variable.withDateTime(cutoff),
      ],
      newStatus: unresolvable,
      effectiveNow: effectiveNow,
    );
  }

  /// Shared paginator for the retire-* methods. Reads up to [pageSize]
  /// (host_id, counter) keys matching [selectKeysSql], then UPDATEs
  /// exactly those rows by primary key inside a transaction. Loops
  /// until a page comes back empty. Each page is one short writer
  /// transaction, capping the worst-case lock hold to one page worth
  /// of work regardless of backlog size.
  ///
  /// [selectVariables] must match [selectKeysSql] without the trailing
  /// `LIMIT ?` placeholder — the paginator binds [pageSize] for that
  /// itself.
  Future<int> _retireInPages({
    required int pageSize,
    required String selectKeysSql,
    required List<Variable<Object>> selectVariables,
    required int newStatus,
    required DateTime effectiveNow,
  }) async {
    if (pageSize <= 0) return 0;
    var totalRetired = 0;
    while (true) {
      final pageRetired = await transaction(() async {
        final rows = await customSelect(
          selectKeysSql,
          variables: [...selectVariables, Variable.withInt(pageSize)],
          readsFrom: {syncSequenceLog},
        ).get();
        if (rows.isEmpty) return 0;
        final placeholders = List<String>.generate(
          rows.length,
          (_) => '(?, ?)',
        ).join(', ');
        final updateVars = <Variable<Object>>[
          Variable.withInt(newStatus),
          Variable.withDateTime(effectiveNow),
          for (final row in rows) ...[
            Variable.withString(row.read<String>('host_id')),
            Variable.withInt(row.read<int>('counter')),
          ],
        ];
        return customUpdate(
          'UPDATE sync_sequence_log '
          'SET status = ?, updated_at = ? '
          'WHERE (host_id, counter) IN (VALUES $placeholders)',
          variables: updateVars,
          updates: {syncSequenceLog},
        );
      });
      totalRetired += pageRetired;
      if (pageRetired < pageSize) break;
    }
    return totalRetired;
  }

  /// Reset every unresolvable row back to `missing`, regardless of whether
  /// it has a known `entry_id`. Use this when the user explicitly wants to
  /// ask peers again for a host's entries — [resetUnresolvableWithKnownPayload]
  /// only covers rows that the local store has since repopulated, which
  /// excludes the common "dead originating host, but a currently-alive
  /// peer has the payload" case where the local row was flipped to
  /// `unresolvable` without ever receiving a hint.
  ///
  /// `request_count` is reset to 0 and `last_requested_at` cleared so the
  /// row rejoins the active backfill sweep; response processing will then
  /// fill in `entry_id` + flip status to `received`/`backfilled` if any
  /// peer answers.
  ///
  /// Returns the number of rows reset.
  Future<int> resetAllUnresolvableEntries() {
    return customUpdate(
      'UPDATE sync_sequence_log '
      'SET status = ?, request_count = 0, '
      'last_requested_at = NULL, updated_at = ? '
      'WHERE status = ?',
      variables: [
        Variable.withInt(SyncSequenceStatus.missing.index),
        Variable.withDateTime(DateTime.now()),
        Variable.withInt(SyncSequenceStatus.unresolvable.index),
      ],
      updates: {syncSequenceLog},
    );
  }

  /// Reset entries that were incorrectly marked as unresolvable back to
  /// "missing" so they can be re-requested. Only resets entries that have
  /// a known payload (entryId IS NOT NULL), meaning repopulation found them.
  /// Returns the number of entries reset.
  Future<int> resetUnresolvableWithKnownPayload() {
    return customUpdate(
      'UPDATE sync_sequence_log '
      'SET status = ?, request_count = 0, '
      'last_requested_at = NULL, updated_at = ? '
      'WHERE status = ? AND entry_id IS NOT NULL',
      variables: [
        Variable.withInt(SyncSequenceStatus.missing.index),
        Variable.withDateTime(DateTime.now()),
        Variable.withInt(SyncSequenceStatus.unresolvable.index),
      ],
      updates: {syncSequenceLog},
    );
  }

  // ============ Outbox Deduplication Methods ============

  /// Find a pending outbox item for a specific entry ID.
  /// Returns the most recent pending item for this entry, or null.
  Future<OutboxItem?> findPendingByEntryId(String entryId) {
    return (select(outbox)
          ..where((t) => t.status.equals(OutboxStatus.pending.index))
          ..where((t) => t.outboxEntryId.equals(entryId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Update an existing pending outbox item's message and subject.
  ///
  /// Only updates rows that are still [OutboxStatus.pending] to avoid
  /// overwriting in-flight or already-sent items (compare-and-swap on
  /// status). Returns the number of affected rows — 0 means the row was
  /// no longer pending and the caller should insert a fresh row instead.
  Future<int> updateOutboxMessage({
    required int itemId,
    required String newMessage,
    required String newSubject,
    int? payloadSize,
    int? priority,
  }) {
    return (update(outbox)..where(
          (t) =>
              t.id.equals(itemId) & t.status.equals(OutboxStatus.pending.index),
        ))
        .write(
          OutboxCompanion(
            message: Value(newMessage),
            subject: Value(newSubject),
            updatedAt: Value(DateTime.now()),
            payloadSize: payloadSize != null
                ? Value(payloadSize)
                : const Value.absent(),
            priority: priority != null ? Value(priority) : const Value.absent(),
          ),
        );
  }

  /// Get aggregated outbox volume per day for sent items.
  /// Groups by send time (`updated_at`) so items appear on the day they
  /// were actually transmitted, not the day they were created.
  Future<List<OutboxDailyVolume>> getDailyOutboxVolume({
    int days = 7,
    DateTime? now,
  }) async {
    if (days <= 0) return const [];

    final effectiveNow = (now ?? DateTime.now()).toUtc();
    final startOfToday = DateTime.utc(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day,
    );
    final cutoff = startOfToday.subtract(Duration(days: days - 1));

    final cutoffSeconds = cutoff.millisecondsSinceEpoch ~/ 1000;
    final rows = await customSelect(
      "SELECT strftime('%Y-%m-%d', updated_at, 'unixepoch') AS day, "
      'COALESCE(SUM(payload_size), 0) AS total_bytes, '
      'COUNT(*) AS item_count '
      'FROM outbox '
      'WHERE status = ? AND updated_at >= ? '
      'GROUP BY day '
      'ORDER BY day ASC',
      variables: [
        Variable.withInt(OutboxStatus.sent.index),
        Variable.withInt(cutoffSeconds),
      ],
    ).get();

    return rows.map((row) {
      final dayString = row.read<String>('day');
      final parts = dayString.split('-');
      return OutboxDailyVolume(
        date: DateTime.utc(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ),
        totalBytes: row.read<int>('total_bytes'),
        itemCount: row.read<int>('item_count'),
      );
    }).toList();
  }

  // ============ Sync Health Query Helpers ============

  /// Count of sequence log entries matching the given [status].
  Future<int> _countSequenceByStatus(SyncSequenceStatus status) async {
    final query = selectOnly(syncSequenceLog)
      ..addColumns([syncSequenceLog.hostId.count()])
      ..where(syncSequenceLog.status.equals(status.index));
    final result = await query.getSingle();
    return result.read(syncSequenceLog.hostId.count()) ?? 0;
  }

  /// Count of sequence log entries with status = missing.
  Future<int> getMissingSequenceCount() =>
      _countSequenceByStatus(SyncSequenceStatus.missing);

  /// Count of sequence log entries with status = requested.
  Future<int> getRequestedSequenceCount() =>
      _countSequenceByStatus(SyncSequenceStatus.requested);

  /// Count of pending outbox items (non-stream, single-shot).
  Future<int> getPendingOutboxCount() async {
    final query = selectOnly(outbox)
      ..addColumns([outbox.id.count()])
      ..where(outbox.status.equals(OutboxStatus.pending.index));
    final result = await query.getSingle();
    return result.read(outbox.id.count()) ?? 0;
  }

  /// Count of outbox items with status = sent and updatedAt >= [since].
  Future<int> getSentCountSince(DateTime since) async {
    final query = selectOnly(outbox)
      ..addColumns([outbox.id.count()])
      ..where(
        outbox.status.equals(OutboxStatus.sent.index) &
            outbox.updatedAt.isBiggerOrEqualValue(since),
      );
    final result = await query.getSingle();
    return result.read(outbox.id.count()) ?? 0;
  }

  @override
  int get schemaVersion => 21;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Creates tables with all current columns (including payload_type)
          await m.createTable(syncSequenceLog);
          await m.createTable(hostActivity);
        } else if (from < 3) {
          // Only add payload_type if table existed from v2 (without this column)
          await m.addColumn(syncSequenceLog, syncSequenceLog.payloadType);
        }
        if (from < 4) {
          // Add outboxEntryId column for outbox deduplication
          await m.addColumn(outbox, outbox.outboxEntryId);
        }
        if (from < 5) {
          // Add payloadSize column for volume tracking
          await m.addColumn(outbox, outbox.payloadSize);
        }
        if (from < 6) {
          // Add priority column for outbox priority queue
          await m.addColumn(outbox, outbox.priority);
        }
        if (from >= 2 && from < 7) {
          // Add jsonPath column for zombie file sweep on re-request.
          // Guard with from >= 2 because createTable (from < 2) already
          // includes jsonPath in the current schema definition.
          await m.addColumn(syncSequenceLog, syncSequenceLog.jsonPath);

          // Backfill jsonPath for existing agent entity/link entries whose
          // paths are derivable from entry_id. This ensures the zombie-file
          // sweep works for items stuck in 'requested' state before this
          // migration.
          await customStatement(
            'UPDATE sync_sequence_log '
            'SET json_path = CASE '
            "  WHEN payload_type = ${SyncSequencePayloadType.agentEntity.index} THEN '/agent_entities/' || entry_id || '.json' "
            "  WHEN payload_type = ${SyncSequencePayloadType.agentLink.index} THEN '/agent_links/' || entry_id || '.json' "
            'END '
            'WHERE entry_id IS NOT NULL AND payload_type IN ('
            '  ${SyncSequencePayloadType.agentEntity.index}, '
            '  ${SyncSequencePayloadType.agentLink.index}'
            ')',
          );
        }
        if (from < 8) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_actionable_status_created_at '
            'ON sync_sequence_log (status, created_at) '
            'WHERE status IN (1, 2)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_payload_resolution '
            'ON sync_sequence_log (entry_id, payload_type, status) '
            'WHERE entry_id IS NOT NULL',
          );
        }
        if (from < 9) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_outbox_status_priority_created_at '
            'ON outbox (status, priority, created_at)',
          );
        }
        if (from < 10) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_host_entry_status '
            'ON sync_sequence_log (host_id, entry_id, status) '
            'WHERE entry_id IS NOT NULL',
          );
        }
        if (from < 11) {
          // Replace the v10 prefix index with a covering one that includes
          // `counter` (and orders it descending ahead of `status`). Without
          // this, `getLastSentCounterForEntry` pulled every matching row
          // from the heap to compute MAX(counter), blocking the UI isolate
          // for 40–600 ms per outbox enqueue on hot entry_ids. The column
          // order lets `ORDER BY counter DESC LIMIT 1` terminate early in
          // the index itself instead of building a temp B-tree to merge
          // the two `status IN (?, ?)` partitions.
          await customStatement(
            'DROP INDEX IF EXISTS idx_sync_sequence_log_host_entry_status',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_host_entry_status_counter '
            'ON sync_sequence_log (host_id, entry_id, counter DESC, status) '
            'WHERE entry_id IS NOT NULL',
          );
        }
        if (from < 12) {
          // Phase 1 of the InboundEventQueue refactor — adds a durable
          // queue plus a per-room marker table so commitApplied can
          // delete the queue row and advance the marker atomically.
          // See docs/sync/2026-04-21_inbound_event_queue_implementation_plan.md.
          await m.createTable(inboundEventQueue);
          await m.createTable(queueMarkers);
          // Back-compat: when the queue is first enabled, Phase 2's
          // wiring reads the legacy markers from settings_db and seeds
          // `queue_markers` at that time. The migration itself leaves
          // the table empty so upgrading users without the flag on see
          // no behaviour change.
        }
        if (from >= 12 && from < 13) {
          // Phase-3 ledger refactor: rows are no longer deleted on
          // commit/skip. A `status` column carries the lifecycle,
          // `commitApplied` → 'applied' (kept for traceability),
          // `markSkipped` → 'abandoned' (resurrectable). The marker
          // clamp scans only active statuses so an abandoned poison
          // row cannot stall forward progress.
          //
          // Columns are additive with defaults, so any v12 rows in
          // flight at upgrade time are treated as `enqueued` and the
          // worker resumes their drain. Indexes are replaced with
          // partials that cover the new status-filtered access paths.
          //
          // Guarded on `from >= 12` because upgrades that cross v12
          // (e.g. v1 → v13) hit the `from < 12` branch above, which
          // calls `m.createTable(inboundEventQueue)`. That helper
          // uses the CURRENT (v13) schema, so the `status` column
          // et al. are already present; re-running the ALTERs here
          // would `duplicate column` out. Upgrades landing precisely
          // on v12 → v13 still need this step because the v12
          // createTable only ran in a previous migration invocation
          // against the older table definition.
          await customStatement(
            'ALTER TABLE inbound_event_queue '
            '''ADD COLUMN status TEXT NOT NULL DEFAULT 'enqueued' ''',
          );
          await customStatement(
            'ALTER TABLE inbound_event_queue '
            'ADD COLUMN committed_at INTEGER',
          );
          await customStatement(
            'ALTER TABLE inbound_event_queue '
            'ADD COLUMN abandoned_at INTEGER',
          );
          await customStatement(
            'ALTER TABLE inbound_event_queue '
            'ADD COLUMN last_error_reason TEXT',
          );
          await customStatement(
            'ALTER TABLE inbound_event_queue '
            'ADD COLUMN resurrection_count INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE inbound_event_queue '
            'ADD COLUMN json_path TEXT',
          );
          // Replace the drain index with a partial one so the applied
          // ledger (unbounded over time) never touches the peek path.
          await customStatement(
            'DROP INDEX IF EXISTS idx_inbound_event_queue_ready',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_inbound_event_queue_ready '
            'ON inbound_event_queue (next_due_at, origin_ts, queue_id) '
            '''WHERE status IN ('enqueued', 'retrying')''',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_active_room_ts '
            'ON inbound_event_queue (room_id, origin_ts) '
            '''WHERE status IN ('enqueued', 'leased', 'retrying')''',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_abandoned_path '
            'ON inbound_event_queue (json_path) '
            '''WHERE status = 'abandoned' ''',
          );
        }
        if (from < 14) {
          // `earliestReadyAt` full-scanned `inbound_event_queue` on
          // every worker idle tick — 3500 scans per hour, 73 seconds
          // of DB time, p95=46 ms and max=2.3 s on a real desktop
          // mid-drain. This partial index turns the MIN(CASE …)
          // probe into an active-rows-only scan.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_active_ready_at '
            'ON inbound_event_queue (next_due_at, lease_until) '
            '''WHERE status IN ('enqueued', 'retrying', 'leased')''',
          );
        }
        if (from < 15) {
          // 1. `resurrectByReason` was the #2 desktop slow query
          //    (298 s total, 5.9 s max). It filters
          //    `status='abandoned' AND last_error_reason=?` but no
          //    matching index existed, so it scanned 23 k+ rows of
          //    the applied ledger on every fire. Mirrors the existing
          //    `idx_inbound_event_queue_abandoned_path` shape.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_abandoned_reason '
            'ON inbound_event_queue (last_error_reason) '
            '''WHERE status = 'abandoned' ''',
          );
          // 2. `retireAgedOutRequestedEntries` filters on `updated_at`
          //    but the existing actionable partial index is keyed on
          //    `created_at`, so the WHERE picked the autoindex on
          //    (host_id, counter) and effectively scanned every row
          //    that ever held status IN (1,2). Add a partial keyed on
          //    the column the WHERE actually needs.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_actionable_status_updated_at '
            'ON sync_sequence_log (status, updated_at) '
            'WHERE status IN (1, 2)',
          );
          // 3. `getBackfillStats`' `SUM(CASE WHEN status=…)` GROUP BY
          //    host_id was a full table scan of 700 k+ rows
          //    (858 s total on desktop). With this covering index the
          //    plan becomes an index-only scan, GROUP BY (host_id,
          //    status) collapses to ~80 rows total, and the per-host
          //    aggregation in Dart is trivially fast.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_host_status '
            'ON sync_sequence_log (host_id, status)',
          );
          // 4. `oldestOutboxItems` and `claimNextOutboxItem` both
          //    scan via `idx_outbox_status_priority_created_at`, but
          //    with 32 k+ `sent` rows accumulated on desktop the
          //    index pages are dominated by terminal rows. A partial
          //    index limited to actionable statuses keeps the hot
          //    `sendNext` lookup focused on the ~6 rows that matter.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_outbox_actionable_priority_created_at '
            'ON outbox (priority, created_at) '
            'WHERE status IN '
            // pending=0, sending=3 — values must match OutboxStatus.
            '(${OutboxStatus.pending.index}, $_outboxSendingStatus)',
          );
        }
        if (from < 16) {
          // 1. `peekBatchReady` filters
          //    `status IN ('enqueued','retrying','leased')` so the
          //    crash-recovered peek can re-claim rows whose lease
          //    expired. The drain partial originally limited the
          //    WHERE to `('enqueued','retrying')`, so SQLite could
          //    not use it for ORDER BY origin_ts, queue_id and fell
          //    back to `idx_inbound_event_queue_active_ready_at`
          //    (keyed on (next_due_at, lease_until)) plus an
          //    external sort. Rebuild the partial with the matching
          //    status set so the worker's hot drain query becomes
          //    index-only on the sort columns.
          await customStatement(
            'DROP INDEX IF EXISTS idx_inbound_event_queue_ready',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_inbound_event_queue_ready '
            'ON inbound_event_queue (next_due_at, origin_ts, queue_id) '
            '''WHERE status IN ('enqueued', 'retrying', 'leased')''',
          );
          // 2. `retireExhaustedRequestedEntries` filters on
          //    `(status IN (1,2)) AND request_count >= ? AND
          //    last_requested_at IS NOT NULL AND last_requested_at < ?`.
          //    Neither existing actionable partial (created_at /
          //    updated_at) covers `last_requested_at`, so the planner
          //    fell back to the autoindex on (host_id, counter) and
          //    effectively scanned every actionable row. The new
          //    partial is keyed on the bound column so the predicate
          //    becomes a tight range scan.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_sync_sequence_log_actionable_status_last_requested_at '
            'ON sync_sequence_log (status, last_requested_at) '
            'WHERE status IN (1, 2) AND last_requested_at IS NOT NULL',
          );
        }
        if (from < 17) {
          // 1. Outbox merge dedup (`findPendingByEntryId`) was the #3
          //    iOS slow query (2,394 occurrences, p50=197 ms): scanning
          //    every pending row to find the entry_id match. Partial
          //    on (outbox_entry_id, created_at) keyed only on pending
          //    rows turns it into a tight index seek + DESC walk that
          //    terminates on the first row.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_outbox_pending_entry_id_created_at '
            'ON outbox (outbox_entry_id, created_at) '
            'WHERE status = ${OutboxStatus.pending.index} '
            'AND outbox_entry_id IS NOT NULL',
          );
          // 2. `resurrectByReason` was #2 with p50=101 ms / 6,331
          //    occurrences. The v15 partial index covers
          //    `(last_error_reason)` only; the actual predicate also
          //    constrains `resurrection_count < ?`, forcing per-row
          //    heap fetches to evaluate the count comparison. Stacking
          //    `resurrection_count` behind the reason equality keeps
          //    the walk inside the index.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_abandoned_reason_resurrection '
            'ON inbound_event_queue (last_error_reason, resurrection_count) '
            '''WHERE status = 'abandoned' ''',
          );
        }
        if (from < 18) {
          // Backstop the `QueueStats.stats()` and `readyNow` probes.
          // Their `status IN (?, ?, ?)` predicate could not be matched
          // to the existing partial index, so the planner full-scanned
          // the queue ledger (332 ms in the super-slow log). Non-partial
          // composite leading on `status` makes the predicate seekable.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_status_due_lease '
            'ON inbound_event_queue (status, next_due_at, lease_until)',
          );
          // Refresh stats for the new partition shape so the planner
          // picks the new index immediately on first launch instead of
          // waiting for the next ANALYZE cycle.
          await customStatement('ANALYZE');
        }
        if (from < 19) {
          // The v18 index seeked on status but couldn't satisfy
          // `MIN(enqueued_at)` without falling back to the heap, so the
          // stats query still showed up as a SCAN in the super-slow log
          // (240–550 ms per poll). Pairing `(status, enqueued_at)`
          // turns MIN into an O(1) seek per matched status partition.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_status_enqueued '
            'ON inbound_event_queue (status, enqueued_at)',
          );
          await customStatement('ANALYZE');
        }
        if (from < 20) {
          // `QueueStats.stats()` was rewritten as a single
          // `GROUP BY status, producer` aggregate. The v19 index keys
          // on `(status, enqueued_at)` but does not include
          // `producer`, so the planner had to read every matching row
          // from the heap to bucket by producer — 1014–2244 ms SCAN
          // hits on the 2026-05-10 super-slow log. Stacking
          // `(status, producer, enqueued_at)` makes the pivot
          // index-only over a tight key range and removes the TEMP
          // B-TREE for GROUP BY.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_inbound_event_queue_status_producer_enqueued '
            'ON inbound_event_queue (status, producer, enqueued_at)',
          );
          await customStatement('ANALYZE');
        }
        if (from < 21) {
          // `oldestOutboxItems` / `claimNextOutboxBatch` both fire
          //   `WHERE status = 0 ORDER BY created_at ASC, id ASC LIMIT N`
          // and the expired-sending companion fires
          //   `WHERE status = 3 AND updated_at < cutoff ORDER BY
          //   created_at ASC, id ASC LIMIT N`.
          // The general `(status, priority, created_at)` index sorts
          // within status by (priority, created_at) — not what the
          // ORDER BY needs — so the planner reverted to a temp
          // B-tree sort. The 2026-05-12 desktop super-slow log
          // captured 56 hits/day for the pending LIMIT 1 shape and 16
          // hits/day for the LIMIT 50 + updated_at companion, with
          // tails reaching 6.0 s. Two literal-status partial indices
          // sized to the actionable rows let the planner walk in
          // (created_at, id) order and stop at LIMIT — no temp
          // B-tree, no scanning of `sent` tombstones.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_outbox_pending_created_id '
            'ON outbox (created_at, id) '
            'WHERE status = 0',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_outbox_sending_expiry '
            'ON outbox (updated_at, created_at, id) '
            'WHERE status = 3',
          );
          await customStatement('ANALYZE');
        }
      },
    );
  }
}
