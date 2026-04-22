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
@TableIndex.sql(
  'CREATE INDEX idx_inbound_event_queue_ready '
  'ON inbound_event_queue (next_due_at, origin_ts, queue_id) '
  '''WHERE status IN ('enqueued', 'retrying')''',
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
            (t) => OrderingTerm(expression: t.priority),
            (t) => OrderingTerm(expression: t.createdAt),
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
                  (t) => OrderingTerm(expression: t.priority),
                  (t) => OrderingTerm(expression: t.createdAt),
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

  Stream<List<OutboxItem>> watchOutboxItems({
    int limit = 1000,
    List<OutboxStatus> statuses = const [
      OutboxStatus.pending,
      OutboxStatus.sending,
      OutboxStatus.error,
      OutboxStatus.sent,
    ],
  }) {
    return (select(outbox)
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
          ])
          ..limit(limit))
        .watch();
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

  /// Get (hostId, counter) pairs from queued or in-flight backfill request
  /// messages in outbox.
  ///
  /// Used to avoid enqueuing duplicate backfill requests while an older request
  /// is still pending or leased in `sending`.
  Future<Set<({String hostId, int counter})>>
  getPendingBackfillEntries() async {
    final pendingItems =
        await (select(
              outbox,
            )..where(
              (t) =>
                  t.status.equals(OutboxStatus.pending.index) |
                  t.status.equals(_outboxSendingStatus),
            ))
            .get();

    final entries = <({String hostId, int counter})>{};

    for (final item in pendingItems) {
      try {
        final json = jsonDecode(item.message) as Map<String, dynamic>;
        // Check if this is a backfillRequest message
        if (json['runtimeType'] == 'backfillRequest') {
          final entriesList = json['entries'] as List<dynamic>?;
          if (entriesList != null) {
            for (final entry in entriesList) {
              if (entry is Map<String, dynamic>) {
                final hostId = entry['hostId'] as String?;
                final counter = entry['counter'] as int?;
                if (hostId != null && counter != null) {
                  entries.add((hostId: hostId, counter: counter));
                }
              }
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
  Future<List<SyncSequenceLogItem>> getMissingEntries({
    int limit = 50,
    int maxRequestCount = 10,
    int offset = 0,
  }) {
    return (select(syncSequenceLog)
          ..where(
            (t) =>
                (t.status.equals(SyncSequenceStatus.missing.index) |
                    t.status.equals(SyncSequenceStatus.requested.index)) &
                t.requestCount.isSmallerThanValue(maxRequestCount),
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
  Future<BackfillStats> getBackfillStats() async {
    // Use enum indices for status values to stay correct if enum order changes
    final received = SyncSequenceStatus.received.index;
    final missing = SyncSequenceStatus.missing.index;
    final requested = SyncSequenceStatus.requested.index;
    final backfilled = SyncSequenceStatus.backfilled.index;
    final deleted = SyncSequenceStatus.deleted.index;
    final unresolvable = SyncSequenceStatus.unresolvable.index;

    // Get all unique hosts with their status counts
    final query = customSelect(
      '''
      SELECT
        ssl.host_id,
        SUM(CASE WHEN ssl.status = $received THEN 1 ELSE 0 END) as received_count,
        SUM(CASE WHEN ssl.status = $missing THEN 1 ELSE 0 END) as missing_count,
        SUM(CASE WHEN ssl.status = $requested THEN 1 ELSE 0 END) as requested_count,
        SUM(CASE WHEN ssl.status = $backfilled THEN 1 ELSE 0 END) as backfilled_count,
        SUM(CASE WHEN ssl.status = $deleted THEN 1 ELSE 0 END) as deleted_count,
        SUM(CASE WHEN ssl.status = $unresolvable THEN 1 ELSE 0 END) as unresolvable_count,
        ha.last_seen_at
      FROM sync_sequence_log ssl
      LEFT JOIN host_activity ha ON ssl.host_id = ha.host_id
      GROUP BY ssl.host_id
      ORDER BY ssl.host_id
      ''',
      readsFrom: {syncSequenceLog, hostActivity},
    );

    final results = await query.get();
    final hostStats = results.map((row) {
      return BackfillHostStats(
        receivedCount: row.read<int>('received_count'),
        missingCount: row.read<int>('missing_count'),
        requestedCount: row.read<int>('requested_count'),
        backfilledCount: row.read<int>('backfilled_count'),
        deletedCount: row.read<int>('deleted_count'),
        unresolvableCount: row.read<int>('unresolvable_count'),
        lastSeenAt: row.readNullable<DateTime>('last_seen_at'),
      );
    }).toList();

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

  /// Get missing entries with age and per-host limits for automatic backfill.
  /// [maxAge] - Only include entries created within this duration
  /// [maxPerHost] - Maximum entries to include per host
  Future<List<SyncSequenceLogItem>> getMissingEntriesWithLimits({
    int limit = 50,
    int maxRequestCount = 10,
    Duration? maxAge,
    int? maxPerHost,
    DateTime? now,
    int offset = 0,
  }) async {
    // Get all missing/requested entries respecting request count
    final baseQuery = select(syncSequenceLog)
      ..where(
        (t) =>
            (t.status.equals(SyncSequenceStatus.missing.index) |
                t.status.equals(SyncSequenceStatus.requested.index)) &
            t.requestCount.isSmallerThanValue(maxRequestCount),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);

    var entries = await baseQuery.get();

    // Apply age filter if specified
    if (maxAge != null) {
      final cutoff = (now ?? DateTime.now()).subtract(maxAge);
      entries = entries.where((e) => e.createdAt.isAfter(cutoff)).toList();
    }

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
  Future<int> retireExhaustedRequestedEntries({
    int maxRequestCount = 10,
    Duration grace = const Duration(minutes: 5),
    DateTime? now,
  }) {
    final missing = SyncSequenceStatus.missing.index;
    final requested = SyncSequenceStatus.requested.index;
    final unresolvable = SyncSequenceStatus.unresolvable.index;
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(grace);
    return customUpdate(
      'UPDATE sync_sequence_log '
      'SET status = ?, updated_at = ? '
      'WHERE (status = ? OR status = ?) '
      '  AND request_count >= ? '
      '  AND last_requested_at IS NOT NULL '
      '  AND last_requested_at < ?',
      variables: [
        Variable.withInt(unresolvable),
        Variable.withDateTime(effectiveNow),
        Variable.withInt(missing),
        Variable.withInt(requested),
        Variable.withInt(maxRequestCount),
        Variable.withDateTime(cutoff),
      ],
      updates: {syncSequenceLog},
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
  Future<int> retireAgedOutRequestedEntries({
    Duration amnestyWindow = const Duration(days: 7),
    DateTime? now,
  }) {
    final missing = SyncSequenceStatus.missing.index;
    final requested = SyncSequenceStatus.requested.index;
    final unresolvable = SyncSequenceStatus.unresolvable.index;
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(amnestyWindow);
    return customUpdate(
      'UPDATE sync_sequence_log '
      'SET status = ?, updated_at = ? '
      'WHERE (status = ? OR status = ?) '
      '  AND updated_at < ?',
      variables: [
        Variable.withInt(unresolvable),
        Variable.withDateTime(effectiveNow),
        Variable.withInt(missing),
        Variable.withInt(requested),
        Variable.withDateTime(cutoff),
      ],
      updates: {syncSequenceLog},
    );
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
  int get schemaVersion => 14;

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
      },
    );
  }
}
