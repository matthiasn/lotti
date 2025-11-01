import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockOutboxRepository extends Mock implements OutboxRepository {}

class MockMessageSender extends Mock implements OutboxMessageSender {}

class MockLogging extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      OutboxItem(
        id: 1,
        message: '{}',
        subject: 's',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    registerFallbackValue(const SyncMessage.aiConfigDelete(id: 'x'));
  });

  test('send timeout triggers retry and schedules backoff', () async {
    final repo = MockOutboxRepository();
    final sender = MockMessageSender();
    final log = MockLogging();

    final pending = OutboxItem(
      id: 1,
      // Use valid JSON encoding for the stored message payload
      message: jsonEncode(const SyncMessage.aiConfigDelete(id: 'cfg').toJson()),
      subject: 'host:1',
      status: OutboxStatus.pending.index,
      retries: 0,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    when(() => repo.fetchPending(limit: any<int>(named: 'limit')))
        .thenAnswer((_) async => [pending]);
    when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
    // Sender completes after a long delay, exceeding timeout
    when(() => sender.send(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(seconds: 1));
      return true;
    });
    when(() => log.captureEvent(any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'))).thenAnswer((_) {});
    when(() => log.captureException(any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace')))
        .thenAnswer((_) async {});

    final proc = OutboxProcessor(
      repository: repo,
      messageSender: sender,
      loggingService: log,
      retryDelayOverride: const Duration(milliseconds: 200),
      sendTimeoutOverride: const Duration(milliseconds: 50),
    );

    final result = await proc.processQueue();
    expect(result.shouldSchedule, isTrue);
    expect(result.nextDelay?.inMilliseconds, 200);
    verify(() => repo.markRetry(any())).called(1);
  });
}
