// ignore_for_file:

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';
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
  void captureEvent(dynamic event,
      {required String domain,
      String? subDomain,
      InsightLevel level = InsightLevel.info,
      InsightType type = InsightType.log}) {}

  @override
  void captureException(dynamic exception,
      {required String domain,
      String? subDomain,
      dynamic stackTrace,
      InsightLevel level = InsightLevel.error,
      InsightType type = InsightType.exception}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retry cap transitions item to error in DB', () async {
    final db = SyncDatabase(inMemoryDatabase: true);
    addTearDown(db.close);

    // Insert one outbox item with retries at cap-1
    const cap = 3;
    final itemId = await db.addOutboxItem(OutboxCompanion.insert(
      message: jsonEncode(const SyncMessage.aiConfigDelete(id: 'X').toJson()),
      subject: 'cap-test',
    ));
    // Set retries to cap-1 so the next markRetry hits cap
    await db.updateOutboxItem(OutboxCompanion(
      id: Value(itemId),
      retries: const Value(cap - 1),
      status: Value(OutboxStatus.pending.index),
    ));

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
}
