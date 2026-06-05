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
