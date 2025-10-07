import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
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
  });
}
