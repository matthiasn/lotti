import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncDatabase extends Mock implements SyncDatabase {}

void main() {
  group('DatabaseOutboxRepository', () {
    setUpAll(() {
      registerFallbackValue(const OutboxCompanion());
      registerFallbackValue(Duration.zero);
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
        priority: OutboxPriority.low.index,
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
            ),
          ),
        ),
      ).called(1);
    });

    test(
      'markRetry increments retries and keeps pending when below max',
      () async {
        final item = OutboxItem(
          id: 2,
          message: '{}',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          subject: 'subject',
          priority: OutboxPriority.low.index,
        );

        when(() => database.updateOutboxItem(any())).thenAnswer((_) async => 1);

        await repository.markRetry(item);

        verify(
          () => database.updateOutboxItem(
            any(
              that: isA<OutboxCompanion>()
                  .having((c) => c.retries, 'retries', const Value(1))
                  .having(
                    (c) => c.status,
                    'status',
                    Value(OutboxStatus.pending.index),
                  ),
            ),
          ),
        ).called(1);
      },
    );

    test('markRetry marks error once retries reach maxRetries', () async {
      final item = OutboxItem(
        id: 3,
        message: '{}',
        status: OutboxStatus.pending.index,
        retries: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        subject: 'subject',
        priority: OutboxPriority.low.index,
      );

      when(() => database.updateOutboxItem(any())).thenAnswer((_) async => 1);

      await repository.markRetry(item);

      verify(
        () => database.updateOutboxItem(
          any(
            that: isA<OutboxCompanion>()
                .having((c) => c.retries, 'retries', const Value(2))
                .having(
                  (c) => c.status,
                  'status',
                  Value(OutboxStatus.error.index),
                ),
          ),
        ),
      ).called(1);
    });

    group('claim', () {
      test('delegates to database with the provided lease duration', () async {
        when(
          () => database.claimNextOutboxItem(
            leaseDuration: any(named: 'leaseDuration'),
          ),
        ).thenAnswer((_) async => null);

        await repository.claim(leaseDuration: const Duration(seconds: 30));

        verify(
          () => database.claimNextOutboxItem(
            leaseDuration: const Duration(seconds: 30),
          ),
        ).called(1);
      });

      test('falls back to default lease when none is provided', () async {
        when(
          () => database.claimNextOutboxItem(
            leaseDuration: any(named: 'leaseDuration'),
          ),
        ).thenAnswer((_) async => null);

        await repository.claim();

        verify(
          () => database.claimNextOutboxItem(
            // Assert the exact default constant, even though it currently
            // matches the DB-layer default — the test exists to catch a
            // drift between the two.
            // ignore: avoid_redundant_argument_values
            leaseDuration: SyncTuning.outboxClaimLease,
          ),
        ).called(1);
      });

      test('returns the claimed item as-is', () async {
        final claimed = OutboxItem(
          id: 10,
          message: '{"updated": true}',
          status: OutboxStatus.sending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          subject: 'subject',
          priority: OutboxPriority.low.index,
        );

        when(
          () => database.claimNextOutboxItem(
            leaseDuration: any(named: 'leaseDuration'),
          ),
        ).thenAnswer((_) async => claimed);

        final result = await repository.claim();

        expect(result, equals(claimed));
      });
    });

    group('hasMorePending', () {
      test('returns true when at least one pending row exists', () async {
        final item = OutboxItem(
          id: 1,
          message: '{}',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          subject: 'subject',
          priority: OutboxPriority.low.index,
        );
        when(
          () => database.oldestOutboxItems(1),
        ).thenAnswer((_) async => [item]);

        expect(await repository.hasMorePending(), isTrue);
      });

      test('returns false when no pending rows exist', () async {
        when(
          () => database.oldestOutboxItems(1),
        ).thenAnswer((_) async => <OutboxItem>[]);

        expect(await repository.hasMorePending(), isFalse);
      });
    });

    group('pruneSentOutboxItems', () {
      test(
        'delegates to database with the retention duration and forwards '
        'the deleted count back to the caller — the OutboxService sweep '
        'reads the count only for logging cardinality, so it has to be '
        'the same value the DB reported',
        () async {
          when(
            () => database.pruneSentOutboxItems(
              retention: any(named: 'retention'),
            ),
          ).thenAnswer((_) async => 42);

          final deleted = await repository.pruneSentOutboxItems(
            retention: const Duration(days: 7),
          );

          expect(deleted, 42);
          verify(
            () => database.pruneSentOutboxItems(
              retention: const Duration(days: 7),
            ),
          ).called(1);
        },
      );
    });
  });
}
