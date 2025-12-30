import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncDatabase extends Mock implements SyncDatabase {}

void main() {
  group('DatabaseOutboxRepository', () {
    setUpAll(() {
      registerFallbackValue(const OutboxCompanion());
    });
    late MockSyncDatabase database;
    late DatabaseOutboxRepository repository;

    setUp(() {
      database = MockSyncDatabase();
      repository = DatabaseOutboxRepository(database, maxRetries: 2);
    });

    test('fetchPending delegates to database with limit', () async {
      when(() => database.oldestOutboxItems(5)).thenAnswer((_) async => []);

      await repository.fetchPending(limit: 5);

      verify(() => database.oldestOutboxItems(5)).called(1);
    });

    test('markSent updates item status and timestamp', () async {
      final item = OutboxItem(
        id: 1,
        message: '{}',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        subject: 'subject',
      );

      when(() => database.updateOutboxItem(any())).thenAnswer((_) async => 1);

      await repository.markSent(item);

      verify(
        () => database.updateOutboxItem(
          any(
              that: isA<OutboxCompanion>().having(
            (c) => c.status,
            'status',
            Value(OutboxStatus.sent.index),
          )),
        ),
      ).called(1);
    });

    test('markRetry increments retries and keeps pending when below max',
        () async {
      final item = OutboxItem(
        id: 2,
        message: '{}',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        subject: 'subject',
      );

      when(() => database.updateOutboxItem(any())).thenAnswer((_) async => 1);

      await repository.markRetry(item);

      verify(
        () => database.updateOutboxItem(
          any(
              that: isA<OutboxCompanion>()
                  .having((c) => c.retries, 'retries', const Value(1))
                  .having((c) => c.status, 'status',
                      Value(OutboxStatus.pending.index))),
        ),
      ).called(1);
    });

    test('markRetry marks error once retries reach maxRetries', () async {
      final item = OutboxItem(
        id: 3,
        message: '{}',
        status: OutboxStatus.pending.index,
        retries: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        subject: 'subject',
      );

      when(() => database.updateOutboxItem(any())).thenAnswer((_) async => 1);

      await repository.markRetry(item);

      verify(
        () => database.updateOutboxItem(
          any(
              that: isA<OutboxCompanion>()
                  .having((c) => c.retries, 'retries', const Value(2))
                  .having((c) => c.status, 'status',
                      Value(OutboxStatus.error.index))),
        ),
      ).called(1);
    });

    group('refreshItem', () {
      test('returns item when found and still pending', () async {
        final item = OutboxItem(
          id: 10,
          message: '{"updated": true}',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          subject: 'subject',
        );

        when(() => database.getOutboxItemById(10))
            .thenAnswer((_) async => item);

        final result = await repository.refreshItem(item);

        expect(result, equals(item));
        verify(() => database.getOutboxItemById(10)).called(1);
      });

      test('returns null when item not found', () async {
        final item = OutboxItem(
          id: 11,
          message: '{}',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          subject: 'subject',
        );

        when(() => database.getOutboxItemById(11))
            .thenAnswer((_) async => null);

        final result = await repository.refreshItem(item);

        expect(result, equals(null));
      });

      test('returns null when item status is sent', () async {
        final originalItem = OutboxItem(
          id: 12,
          message: '{}',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          subject: 'subject',
        );

        final sentItem = OutboxItem(
          id: 12,
          message: '{}',
          status: OutboxStatus.sent.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          subject: 'subject',
        );

        when(() => database.getOutboxItemById(12))
            .thenAnswer((_) async => sentItem);

        final result = await repository.refreshItem(originalItem);

        expect(result, equals(null));
      });

      test('returns null when item status is error', () async {
        final originalItem = OutboxItem(
          id: 13,
          message: '{}',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          subject: 'subject',
        );

        final errorItem = OutboxItem(
          id: 13,
          message: '{}',
          status: OutboxStatus.error.index,
          retries: 5,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          subject: 'subject',
        );

        when(() => database.getOutboxItemById(13))
            .thenAnswer((_) async => errorItem);

        final result = await repository.refreshItem(originalItem);

        expect(result, equals(null));
      });
    });
  });
}
