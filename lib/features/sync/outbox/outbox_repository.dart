import 'package:drift/drift.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';

abstract class OutboxRepository {
  Future<List<OutboxItem>> fetchPending({int limit = 10});

  Future<void> markSent(OutboxItem item);

  Future<void> markRetry(OutboxItem item);
}

class DatabaseOutboxRepository implements OutboxRepository {
  DatabaseOutboxRepository(
    this._database, {
    this.maxRetries = 10,
  });

  final SyncDatabase _database;
  final int maxRetries;

  @override
  Future<List<OutboxItem>> fetchPending({int limit = 10}) {
    return _database.oldestOutboxItems(limit);
  }

  @override
  Future<void> markSent(OutboxItem item) async {
    await _database.updateOutboxItem(
      OutboxCompanion(
        id: Value(item.id),
        status: Value(OutboxStatus.sent.index),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> markRetry(OutboxItem item) async {
    final retries = item.retries + 1;
    final newStatus = retries < maxRetries
        ? OutboxStatus.pending.index
        : OutboxStatus.error.index;

    await _database.updateOutboxItem(
      OutboxCompanion(
        id: Value(item.id),
        status: Value(newStatus),
        retries: Value(retries),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
