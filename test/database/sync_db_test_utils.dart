/// Shared helpers for the `SyncDatabase` test files in this directory.
///
/// The original monolithic `sync_db_test.dart` was mirror-split along the
/// `lib/database/sync_db_*.dart` part-file seams; the outbox-row builder and
/// the generated outbox-status model below are used by several of the split
/// files.
library;

import 'package:drift/drift.dart';
import 'package:glados/glados.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';

extension SyncDatabaseTestQueries on SyncDatabase {
  Future<List<OutboxItem>> get allOutboxItems => select(outbox).get();

  Future<OutboxItem?> getOutboxItemById(int id) {
    return (select(
      outbox,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
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
            (table) => table.status.isIn(
              statuses.map((status) => status.index),
            ),
          )
          ..orderBy([
            (table) => OrderingTerm(
              expression: CustomExpression<int>(
                'CASE WHEN status IN '
                '(${OutboxStatus.pending.index}, '
                '${OutboxStatus.sending.index}) THEN 0 '
                'WHEN status = ${OutboxStatus.error.index} THEN 1 ELSE 2 END',
              ),
            ),
            (table) => OrderingTerm(expression: table.priority),
            (table) => OrderingTerm(
              expression: table.createdAt,
              mode: OrderingMode.desc,
            ),
            (table) => OrderingTerm(
              expression: table.id,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit))
        .watch();
  }

  Future<int> getMissingSequenceCount() =>
      _countSequenceByStatus(SyncSequenceStatus.missing);

  Future<int> getRequestedSequenceCount() =>
      _countSequenceByStatus(SyncSequenceStatus.requested);

  Future<int> _countSequenceByStatus(SyncSequenceStatus status) async {
    final query = selectOnly(syncSequenceLog)
      ..addColumns([syncSequenceLog.hostId.count()])
      ..where(syncSequenceLog.status.equals(status.index));
    final result = await query.getSingle();
    return result.read(syncSequenceLog.hostId.count()) ?? 0;
  }

  Future<int> getPendingOutboxCount() async {
    final query = selectOnly(outbox)
      ..addColumns([outbox.id.count()])
      ..where(outbox.status.equals(OutboxStatus.pending.index));
    final result = await query.getSingle();
    return result.read(outbox.id.count()) ?? 0;
  }

  Future<int> getSentCountSince(DateTime since) async {
    final result = await customSelect(
      'SELECT COUNT(*) AS cnt '
      'FROM outbox INDEXED BY idx_outbox_sent_updated_at '
      'WHERE status = 1 AND updated_at >= ?',
      variables: [Variable.withDateTime(since)],
      readsFrom: {outbox},
    ).getSingle();
    return result.read<int>('cnt');
  }
}

OutboxCompanion buildOutboxCompanion({
  required OutboxStatus status,
  required DateTime createdAt,
  int retries = 0,
  String subject = 'subject',
  String message = '{}',
  String? filePath,
}) {
  return OutboxCompanion(
    status: Value(status.index),
    subject: Value(subject),
    message: Value(message),
    createdAt: Value(createdAt),
    updatedAt: Value(createdAt),
    retries: Value(retries),
    filePath: filePath == null
        ? const Value.absent()
        : Value<String?>(filePath),
  );
}

/// Generated model of an outbox row's claim/prune-relevant status.
/// `expiredSending` and `activeSending` both map to [OutboxStatus.sending];
/// they differ in whether the lease (`updated_at`) is older than the
/// reclaim/retention cutoff.
enum GeneratedOutboxStatus {
  pending,
  expiredSending,
  activeSending,
  sent,
  error,
}

extension AnyGeneratedOutboxStatus on Any {
  Generator<GeneratedOutboxStatus> get generatedOutboxStatus =>
      choose(GeneratedOutboxStatus.values);
}

/// Deletes every row from every table in [db] **without** recreating the
/// schema, so a single `setUpAll`-opened in-memory [SyncDatabase] can be reused
/// across all tests in a group/file while each test still starts from an empty
/// database. The 24-step migration ladder then runs once per file instead of
/// once per test. (Unlike `JournalDb`, `SyncDatabase` keeps no in-memory cache,
/// so a table wipe fully resets its state.)
///
/// Foreign-key enforcement is toggled off for the sweep so delete order is
/// irrelevant, and `db.allTables` guarantees no table is missed.
Future<void> clearAllSyncTables(SyncDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  // Enumerate from sqlite_master rather than `db.allTables`: some tables (e.g.
  // sync_sequence_watermarks) are created via raw migration SQL and are NOT in
  // the Drift-declared set, so allTables would silently leave them uncleared —
  // a real cross-test contamination source.
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'",
      )
      .get();
  for (final row in tables) {
    await db.customStatement('DELETE FROM ${row.read<String>('name')}');
  }
  // Reset AUTOINCREMENT counters so rowids restart at 1 (matching a fresh DB),
  // which id-asserting tests rely on. sqlite_sequence only exists when some
  // table uses AUTOINCREMENT.
  final hasSequence = await db
      .customSelect(
        'SELECT 1 FROM sqlite_master '
        "WHERE type = 'table' AND name = 'sqlite_sequence'",
      )
      .get();
  if (hasSequence.isNotEmpty) {
    await db.customStatement('DELETE FROM sqlite_sequence');
  }
  await db.customStatement('PRAGMA foreign_keys = ON');
}
