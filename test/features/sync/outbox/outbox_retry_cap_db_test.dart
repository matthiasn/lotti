// ignore_for_file:

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/services/logging_service.dart';
// mocktail not used here

class _SenderFalse implements OutboxMessageSender {
  @override
  Future<bool> send(SyncMessage message) async => false;
}

class _NoopLogging extends LoggingService {
  @override
  void captureEvent(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) {}

  @override
  void captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retry cap transitions item to error in DB', () async {
    final db = SyncDatabase(inMemoryDatabase: true);
    addTearDown(db.close);

    // Insert one outbox item with retries at cap-1
    const cap = 3;
    final itemId = await db.addOutboxItem(
      OutboxCompanion.insert(
        message: jsonEncode(const SyncMessage.aiConfigDelete(id: 'X').toJson()),
        subject: 'cap-test',
      ),
    );
    // Set retries to cap-1 so the next markRetry hits cap
    await db.updateOutboxItem(
      OutboxCompanion(
        id: Value(itemId),
        retries: const Value(cap - 1),
        status: Value(OutboxStatus.pending.index),
      ),
    );

    final repo = DatabaseOutboxRepository(db, maxRetries: cap);
    final sender = _SenderFalse();
    final log = _NoopLogging();

    final proc = OutboxProcessor(
      repository: repo,
      messageSender: sender,
      loggingService: log,
      maxRetriesOverride: cap,
    );

    final result = await proc.processQueue();
    expect(result.shouldSchedule, isTrue);
    expect(result.nextDelay, Duration.zero); // advance to next item

    // Verify DB state updated to error and retries incremented to cap
    final rows = await db.allOutboxItems;
    final row = rows.firstWhere((e) => e.id == itemId);
    expect(row.retries, cap);
    expect(row.status, OutboxStatus.error.index);
  });

  // Regression: closes the merge-send race where a concurrent merge silently
  // overwrote the in-flight outbox row's message after the processor had
  // already serialized it for Matrix, abandoning the merged covered-VCs list.
  // With the atomic claim, the row is `sending` during send, so
  // `updateOutboxMessage` no longer matches and the merged content is forced
  // into a fresh pending row that still rides its own Matrix event.
  test(
    'merge during send spills into a fresh pending row, never overwrites the '
    'in-flight one',
    () async {
      final db = SyncDatabase(inMemoryDatabase: true);
      addTearDown(db.close);

      final originalJson = jsonEncode(
        const SyncMessage.aiConfigDelete(id: 'original').toJson(),
      );
      final itemId = await db.addOutboxItem(
        OutboxCompanion.insert(
          message: originalJson,
          subject: 'merge-race',
          outboxEntryId: const Value('entity-1'),
        ),
      );

      // Processor claims the row: pending → sending.
      final claimed = await db.claimNextOutboxItem();
      expect(claimed, isNotNull);
      expect(claimed!.id, itemId);

      // Concurrent merge attempts to update the now-sending row. With the fix
      // in place the WHERE status=pending clause no longer matches, so the
      // merge caller gets affectedRows=0 and the row content is preserved.
      final mergedJson = jsonEncode(
        const SyncMessage.aiConfigDelete(id: 'merged').toJson(),
      );
      final affected = await db.updateOutboxMessage(
        itemId: itemId,
        newMessage: mergedJson,
        newSubject: 'merge-race:v2',
      );
      expect(
        affected,
        0,
        reason:
            'claim() must have transitioned the row to sending so in-flight '
            'merges cannot overwrite the row content mid-send',
      );

      // The row content on disk is still the original — exactly what the
      // processor is sending over the wire.
      final rowMidSend = (await db.allOutboxItems).firstWhere(
        (e) => e.id == itemId,
      );
      expect(rowMidSend.message, originalJson);
      expect(rowMidSend.status, OutboxStatus.sending.index);

      // Caller's fallback inserts a fresh pending row with the merged message,
      // so the merged covered-VC set will still ride its own Matrix event.
      final freshId = await db.addOutboxItem(
        OutboxCompanion.insert(
          message: mergedJson,
          subject: 'merge-race:v2',
          outboxEntryId: const Value('entity-1'),
        ),
      );
      expect(freshId, isNot(itemId));

      final fresh = (await db.allOutboxItems).firstWhere(
        (e) => e.id == freshId,
      );
      expect(fresh.message, mergedJson);
      expect(fresh.status, OutboxStatus.pending.index);
    },
  );
}
