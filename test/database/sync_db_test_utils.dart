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
  for (final table in db.allTables) {
    await db.customStatement('DELETE FROM ${table.actualTableName}');
  }
  await db.customStatement('PRAGMA foreign_keys = ON');
}
