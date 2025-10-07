import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockOutboxRepository extends Mock implements OutboxRepository {}

class MockOutboxMessageSender extends Mock implements OutboxMessageSender {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(const SyncMessage.aiConfigDelete(id: 'id'));
  });

  group('OutboxProcessor', () {
    late MockOutboxRepository repository;
    late MockOutboxMessageSender sender;
    late MockLoggingService logging;
    late OutboxProcessor processor;

    setUp(() {
      repository = MockOutboxRepository();
      sender = MockOutboxMessageSender();
      logging = MockLoggingService();

      processor = OutboxProcessor(
        repository: repository,
        messageSender: sender,
        loggingService: logging,
      );
    });

    OutboxItem buildItem({String subjectValue = 'subject', int retries = 0}) {
      final message = json.encode(
        const SyncMessage.aiConfigDelete(id: 'config-id').toJson(),
      );

      return OutboxItem(
        id: 1,
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
        updatedAt: DateTime.now(),
        status: OutboxStatus.pending.index,
        retries: retries,
        message: message,
        subject: subjectValue,
      );
    }

    test('returns none when no pending items', () async {
      when(() => repository.fetchPending(limit: any<int>(named: 'limit')))
          .thenAnswer((_) async => []);

      final result = await processor.processQueue();

      expect(result.shouldSchedule, isFalse);
      verify(() => repository.fetchPending(limit: any<int>(named: 'limit')))
          .called(1);
      verifyNever(() => sender.send(any<SyncMessage>()));
    });

    test('marks sent and schedules immediate retry when more items', () async {
      final first = buildItem();
      final second = buildItem(subjectValue: 'next');

      when(() => repository.fetchPending(limit: any<int>(named: 'limit')))
          .thenAnswer((_) async => [first, second]);
      when(() => sender.send(any<SyncMessage>())).thenAnswer((_) async => true);
      when(() => repository.markSent(first)).thenAnswer((_) async {});
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenAnswer((_) {});

      final result = await processor.processQueue();

      expect(result.shouldSchedule, isTrue);
      expect(result.nextDelay, Duration.zero);
      verify(() => repository.markSent(first)).called(1);
      verify(() => sender.send(any<SyncMessage>())).called(1);
    });

    test('returns none when last item sent', () async {
      final item = buildItem();
      when(() => repository.fetchPending(limit: any<int>(named: 'limit')))
          .thenAnswer((_) async => [item]);
      when(() => sender.send(any<SyncMessage>())).thenAnswer((_) async => true);
      when(() => repository.markSent(item)).thenAnswer((_) async {});
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenAnswer((_) {});

      final result = await processor.processQueue();

      expect(result.shouldSchedule, isFalse);
      verify(() => repository.markSent(item)).called(1);
    });

    test('schedules retry when sender returns false', () async {
      final item = buildItem();
      when(() => repository.fetchPending(limit: any<int>(named: 'limit')))
          .thenAnswer((_) async => [item]);
      when(() => sender.send(any<SyncMessage>()))
          .thenAnswer((_) async => false);
      when(() => repository.markRetry(item)).thenAnswer((_) async {});

      final result = await processor.processQueue();

      expect(result.shouldSchedule, isTrue);
      expect(result.nextDelay, const Duration(seconds: 5));
      verify(() => repository.markRetry(item)).called(1);
    });

    test('handles exception by marking retry and scheduling error delay',
        () async {
      final item = buildItem();
      when(() => repository.fetchPending(limit: any<int>(named: 'limit')))
          .thenAnswer((_) async => [item]);
      when(() => sender.send(any<SyncMessage>()))
          .thenThrow(Exception('send failed'));
      when(() => repository.markRetry(item)).thenAnswer((_) async {});
      when(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'))).thenAnswer((_) {});

      final result = await processor.processQueue();

      expect(result.shouldSchedule, isTrue);
      expect(result.nextDelay, const Duration(seconds: 15));
      verify(() => repository.markRetry(item)).called(1);
      verify(() => logging.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'))).called(1);
    });

    test('marks item as error after exceeding max retries', () async {
      final db = SyncDatabase(inMemoryDatabase: true);
      final repositoryWithLimit = DatabaseOutboxRepository(db, maxRetries: 2);
      final processorWithRepo = OutboxProcessor(
        repository: repositoryWithLimit,
        messageSender: sender,
        loggingService: logging,
      );

      await db.addOutboxItem(
        OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          retries: const Value(1),
          message: Value(buildItem().message),
          subject: const Value('subject'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      when(() => sender.send(any<SyncMessage>()))
          .thenAnswer((_) async => false);

      final result = await processorWithRepo.processQueue();

      expect(result.shouldSchedule, isTrue);
      final rows = await db.select(db.outbox).get();
      expect(rows.first.status, OutboxStatus.error.index);

      await db.close();
    });
  });
}
