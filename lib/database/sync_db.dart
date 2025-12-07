import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/features/sync/tuning.dart';

part 'sync_db.g.dart';

const syncDbFileName = 'sync.sqlite';

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
}

@DataClassName('OutboxItem')
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
}

/// Tracks sync sequence entries by (hostId, counter) to detect gaps
/// and enable backfill requests for missing entries.
@DataClassName('SyncSequenceLogItem')
class SyncSequenceLog extends Table {
  /// The host UUID whose counter this record tracks
  TextColumn get hostId => text().named('host_id')();

  /// The monotonic counter for that host
  IntColumn get counter => integer()();

  /// The journal entry ID (null if entry is missing/unknown)
  TextColumn get entryId => text().named('entry_id').nullable()();

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

@DriftDatabase(tables: [Outbox, SyncSequenceLog, HostActivity])
class SyncDatabase extends _$SyncDatabase {
  SyncDatabase({
    this.inMemoryDatabase = false,
    String? overriddenFilename,
  }) : super(
          openDbConnection(
            overriddenFilename ?? syncDbFileName,
            inMemoryDatabase: inMemoryDatabase,
          ),
        );

  SyncDatabase.connect(super.c) : super.connect();

  bool inMemoryDatabase = false;

  Future<int> updateOutboxItem(OutboxCompanion item) {
    return (update(outbox)..where((t) => t.id.equals(item.id.value)))
        .write(item);
  }

  Future<int> addOutboxItem(OutboxCompanion entry) {
    return into(outbox).insert(entry);
  }

  Future<List<OutboxItem>> get allOutboxItems => select(outbox).get();

  Future<List<OutboxItem>> oldestOutboxItems(int limit) {
    return (select(outbox)
          ..where((t) => t.status.equals(OutboxStatus.pending.index))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit))
        .get();
  }

  Stream<List<OutboxItem>> watchOutboxItems({
    int limit = 1000,
    List<OutboxStatus> statuses = const [
      OutboxStatus.pending,
      OutboxStatus.error,
      OutboxStatus.sent,
    ],
  }) {
    return (select(outbox)
          ..where(
            (t) => t.status
                .isIn(statuses.map((OutboxStatus status) => status.index)),
          )
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(limit))
        .watch();
  }

  Stream<int> watchOutboxCount() {
    return (select(outbox)
          ..where(
            (t) => t.status.equals(OutboxStatus.pending.index),
          ))
        .watch()
        .map((res) => res.length);
  }

  Future<int> deleteOutboxItems() {
    return delete(outbox).go();
  }

  /// Get (hostId, counter) pairs from pending backfill request messages in outbox.
  /// Used to avoid enqueuing duplicate backfill requests.
  Future<Set<({String hostId, int counter})>>
      getPendingBackfillEntries() async {
    final pendingItems = await (select(outbox)
          ..where((t) => t.status.equals(OutboxStatus.pending.index)))
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

  /// Get the highest counter we've seen for a given host.
  /// Returns null if we've never seen this host.
  Future<int?> getLastCounterForHost(String hostId) async {
    final query = selectOnly(syncSequenceLog)
      ..addColumns([syncSequenceLog.counter.max()])
      ..where(syncSequenceLog.hostId.equals(hostId));

    final result = await query.getSingleOrNull();
    return result?.read(syncSequenceLog.counter.max());
  }

  /// Get entries with status 'missing' or 'requested' that haven't
  /// exceeded maxRequestCount, ordered by creation time (oldest first).
  Future<List<SyncSequenceLogItem>> getMissingEntries({
    int limit = 50,
    int maxRequestCount = 10,
  }) {
    return (select(syncSequenceLog)
          ..where(
            (t) =>
                (t.status.equals(SyncSequenceStatus.missing.index) |
                    t.status.equals(SyncSequenceStatus.requested.index)) &
                t.requestCount.isSmallerThanValue(maxRequestCount),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Update the status of a sequence log entry.
  Future<int> updateSequenceStatus(
    String hostId,
    int counter,
    SyncSequenceStatus status,
  ) {
    return (update(syncSequenceLog)
          ..where(
            (t) => t.hostId.equals(hostId) & t.counter.equals(counter),
          ))
        .write(
      SyncSequenceLogCompanion(
        status: Value(status.index),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Increment the request count, update status to 'requested', and set lastRequestedAt.
  /// Uses atomic SQL expression to avoid race conditions.
  Future<int> incrementRequestCount(String hostId, int counter) {
    final now = DateTime.now();
    return (update(syncSequenceLog)
          ..where(
            (t) => t.hostId.equals(hostId) & t.counter.equals(counter),
          ))
        .write(
      SyncSequenceLogCompanion.custom(
        requestCount: syncSequenceLog.requestCount + const Constant(1),
        status: Constant(SyncSequenceStatus.requested.index),
        updatedAt: Variable(now),
        lastRequestedAt: Variable(now),
      ),
    );
  }

  /// Get a specific sequence log entry by host ID and counter.
  Future<SyncSequenceLogItem?> getEntryByHostAndCounter(
    String hostId,
    int counter,
  ) {
    return (select(syncSequenceLog)
          ..where(
            (t) => t.hostId.equals(hostId) & t.counter.equals(counter),
          ))
        .getSingleOrNull();
  }

  /// Watch the count of missing entries for UI display.
  Stream<int> watchMissingCount() {
    return (select(syncSequenceLog)
          ..where(
            (t) =>
                t.status.equals(SyncSequenceStatus.missing.index) |
                t.status.equals(SyncSequenceStatus.requested.index),
          ))
        .watch()
        .map((res) => res.length);
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
    final result = await (select(hostActivity)
          ..where((t) => t.hostId.equals(hostId)))
        .getSingleOrNull();
    return result?.lastSeenAt;
  }

  /// Get all host activity records.
  Future<List<HostActivityItem>> getAllHostActivity() {
    return select(hostActivity).get();
  }

  /// Get missing entries that should be requested, applying smart filtering:
  /// 1. Only request from hosts that have been active since our last request
  /// 2. Respect exponential backoff based on request count
  ///
  /// This prevents wasteful requests to hosts that haven't been online
  /// and avoids hammering hosts with requests they can't fulfill.
  Future<List<SyncSequenceLogItem>> getMissingEntriesForActiveHosts({
    int limit = 50,
    int maxRequestCount = 10,
  }) async {
    // Get all missing/requested entries
    final missingEntries = await getMissingEntries(
      limit: limit * 3, // Get more since we'll filter some out
      maxRequestCount: maxRequestCount,
    );

    if (missingEntries.isEmpty) return [];

    // Get host activity for all relevant hosts in a single query
    final hostIds = missingEntries.map((e) => e.hostId).toSet().toList();
    final activities = await (select(hostActivity)
          ..where((tbl) => tbl.hostId.isIn(hostIds)))
        .get();
    final activityMap = {
      for (final activity in activities) activity.hostId: activity.lastSeenAt,
    };

    final now = DateTime.now();

    // Filter: only include entries where:
    // 1. Host has been active since last request
    // 2. Exponential backoff period has elapsed
    final filtered = missingEntries
        .where((entry) {
          final hostLastSeen = activityMap[entry.hostId];

          // If we've never seen this host, don't request (they might not exist)
          if (hostLastSeen == null) return false;

          // If we've never requested this entry, include it
          if (entry.lastRequestedAt == null) return true;

          // Check exponential backoff: enough time must have passed
          final backoffDuration =
              SyncTuning.calculateBackoff(entry.requestCount);
          final earliestRetry = entry.lastRequestedAt!.add(backoffDuration);
          if (now.isBefore(earliestRetry)) return false;

          // Host must have been active since our last request
          return hostLastSeen.isAfter(entry.lastRequestedAt!);
        })
        .take(limit)
        .toList();

    return filtered;
  }

  /// Get all existing counters for a specific host.
  /// Used for efficient bulk population to avoid N+1 queries.
  Future<Set<int>> getCountersForHost(String hostId) async {
    final entries = await (select(syncSequenceLog)
          ..where((t) => t.hostId.equals(hostId)))
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

    // Get all unique hosts with their status counts
    final query = customSelect(
      '''
      SELECT
        ssl.host_id,
        MAX(ssl.counter) as latest_counter,
        SUM(CASE WHEN ssl.status = $received THEN 1 ELSE 0 END) as received_count,
        SUM(CASE WHEN ssl.status = $missing THEN 1 ELSE 0 END) as missing_count,
        SUM(CASE WHEN ssl.status = $requested THEN 1 ELSE 0 END) as requested_count,
        SUM(CASE WHEN ssl.status = $backfilled THEN 1 ELSE 0 END) as backfilled_count,
        SUM(CASE WHEN ssl.status = $deleted THEN 1 ELSE 0 END) as deleted_count,
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
        hostId: row.read<String>('host_id'),
        latestCounter: row.read<int>('latest_counter'),
        receivedCount: row.read<int>('received_count'),
        missingCount: row.read<int>('missing_count'),
        requestedCount: row.read<int>('requested_count'),
        backfilledCount: row.read<int>('backfilled_count'),
        deletedCount: row.read<int>('deleted_count'),
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
  }) {
    return (select(syncSequenceLog)
          ..where(
            (t) => t.status.equals(SyncSequenceStatus.requested.index),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Reset request count and last requested time for specified entries.
  /// This allows them to be re-requested as if they were new.
  Future<void> resetRequestCounts(
    List<({String hostId, int counter})> entries,
  ) async {
    final now = DateTime.now();
    for (final entry in entries) {
      await (update(syncSequenceLog)
            ..where(
              (t) =>
                  t.hostId.equals(entry.hostId) &
                  t.counter.equals(entry.counter),
            ))
          .write(
        SyncSequenceLogCompanion(
          requestCount: const Value(0),
          lastRequestedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Get missing entries with age and per-host limits for automatic backfill.
  /// [maxAge] - Only include entries created within this duration
  /// [maxPerHost] - Maximum entries to include per host
  Future<List<SyncSequenceLogItem>> getMissingEntriesWithLimits({
    int limit = 50,
    int maxRequestCount = 10,
    Duration? maxAge,
    int? maxPerHost,
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
      final cutoff = DateTime.now().subtract(maxAge);
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

    return entries.take(limit).toList();
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(syncSequenceLog);
          await m.createTable(hostActivity);
        }
      },
    );
  }
}
