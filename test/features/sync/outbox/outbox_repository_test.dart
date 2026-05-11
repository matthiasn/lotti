import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

enum _GeneratedRepositoryBatchOperation {
  markSent,
  markRetry,
}

class _GeneratedRepositoryBatchRow {
  const _GeneratedRepositoryBatchRow({
    required this.selected,
    required this.unselectedStatus,
    required this.retries,
  });

  final bool selected;
  final OutboxStatus unselectedStatus;
  final int retries;

  OutboxStatus get initialStatus =>
      selected ? OutboxStatus.sending : unselectedStatus;

  @override
  String toString() {
    return '_GeneratedRepositoryBatchRow('
        'selected: $selected, '
        'unselectedStatus: $unselectedStatus, '
        'retries: $retries'
        ')';
  }
}

class _GeneratedRepositoryBatchScenario {
  const _GeneratedRepositoryBatchScenario({
    required this.operation,
    required this.maxRetries,
    required this.rows,
  });

  final _GeneratedRepositoryBatchOperation operation;
  final int maxRetries;
  final List<_GeneratedRepositoryBatchRow> rows;

  bool get hasSelectedRows => rows.any((row) => row.selected);

  OutboxStatus expectedStatus(_GeneratedRepositoryBatchRow row) {
    if (!row.selected) {
      return row.initialStatus;
    }
    return switch (operation) {
      _GeneratedRepositoryBatchOperation.markSent => OutboxStatus.sent,
      _GeneratedRepositoryBatchOperation.markRetry =>
        row.retries + 1 < maxRetries
            ? OutboxStatus.pending
            : OutboxStatus.error,
    };
  }

  int expectedRetries(_GeneratedRepositoryBatchRow row) {
    if (!row.selected ||
        operation == _GeneratedRepositoryBatchOperation.markSent) {
      return row.retries;
    }
    return row.retries + 1;
  }

  @override
  String toString() {
    return '_GeneratedRepositoryBatchScenario('
        'operation: $operation, '
        'maxRetries: $maxRetries, '
        'rows: $rows'
        ')';
  }
}

extension _AnyGeneratedRepositoryBatchScenario on glados.Any {
  glados.Generator<_GeneratedRepositoryBatchOperation>
  get repositoryBatchOperation =>
      glados.AnyUtils(this).choose(_GeneratedRepositoryBatchOperation.values);

  glados.Generator<OutboxStatus> get outboxStatus =>
      glados.AnyUtils(this).choose(OutboxStatus.values);

  glados.Generator<_GeneratedRepositoryBatchRow> get repositoryBatchRow =>
      glados.CombinableAny(this).combine3(
        glados.BoolAny(this).bool,
        outboxStatus,
        glados.IntAnys(this).intInRange(0, 6),
        (
          bool selected,
          OutboxStatus unselectedStatus,
          int retries,
        ) => _GeneratedRepositoryBatchRow(
          selected: selected,
          unselectedStatus: unselectedStatus,
          retries: retries,
        ),
      );

  glados.Generator<_GeneratedRepositoryBatchScenario>
  get repositoryBatchScenario => glados.CombinableAny(this).combine3(
    repositoryBatchOperation,
    glados.IntAnys(this).intInRange(1, 6),
    glados.ListAnys(this).listWithLengthInRange(0, 10, repositoryBatchRow),
    (
      _GeneratedRepositoryBatchOperation operation,
      int maxRetries,
      List<_GeneratedRepositoryBatchRow> rows,
    ) => _GeneratedRepositoryBatchScenario(
      operation: operation,
      maxRetries: maxRetries,
      rows: rows,
    ),
  );
}

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

    group('claimNextBatch', () {
      test(
        'delegates to database.claimNextOutboxBatch with the provided '
        'lease and maxSize',
        () async {
          when(
            () => database.claimNextOutboxBatch(
              maxSize: any(named: 'maxSize'),
              leaseDuration: any(named: 'leaseDuration'),
            ),
          ).thenAnswer((_) async => <OutboxItem>[]);

          await repository.claimNextBatch(
            maxSize: 50,
            leaseDuration: const Duration(seconds: 30),
          );

          verify(
            () => database.claimNextOutboxBatch(
              maxSize: 50,
              leaseDuration: const Duration(seconds: 30),
            ),
          ).called(1);
        },
      );

      test(
        'falls back to the SyncTuning lease when none is provided',
        () async {
          when(
            () => database.claimNextOutboxBatch(
              maxSize: any(named: 'maxSize'),
              leaseDuration: any(named: 'leaseDuration'),
            ),
          ).thenAnswer((_) async => <OutboxItem>[]);

          await repository.claimNextBatch(maxSize: 50);

          verify(
            () => database.claimNextOutboxBatch(
              maxSize: 50,
              // Asserting the exact default catches drift between the
              // repository fallback and the DB-layer default.
              // ignore: avoid_redundant_argument_values
              leaseDuration: SyncTuning.outboxClaimLease,
            ),
          ).called(1);
        },
      );

      test('returns the rows from the DB call as-is', () async {
        final claimed = [
          OutboxItem(
            id: 10,
            message: '{}',
            status: OutboxStatus.sending.index,
            retries: 0,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            subject: 'a',
            priority: OutboxPriority.normal.index,
          ),
          OutboxItem(
            id: 11,
            message: '{}',
            status: OutboxStatus.sending.index,
            retries: 0,
            createdAt: DateTime(2024).add(const Duration(minutes: 1)),
            updatedAt: DateTime(2024).add(const Duration(minutes: 1)),
            subject: 'b',
            priority: OutboxPriority.normal.index,
          ),
        ];
        when(
          () => database.claimNextOutboxBatch(
            maxSize: any(named: 'maxSize'),
            leaseDuration: any(named: 'leaseDuration'),
          ),
        ).thenAnswer((_) async => claimed);

        final result = await repository.claimNextBatch(maxSize: 50);

        expect(result, equals(claimed));
      });
    });

    // The batch-mark methods open a transaction over per-row updates. We
    // exercise them against a real in-memory SyncDatabase so the
    // transaction semantics get hit for free instead of fighting
    // mocktail's generic-method matching for `transaction<T>`.
    group('batch mark helpers (real SyncDatabase)', () {
      late SyncDatabase realDb;
      late DatabaseOutboxRepository realRepo;

      Future<int> insertRow({
        required OutboxStatus status,
        int retries = 0,
        DateTime? createdAt,
      }) {
        return realDb.addOutboxItem(
          OutboxCompanion(
            status: Value(status.index),
            subject: const Value('s'),
            message: const Value('{}'),
            createdAt: Value(createdAt ?? DateTime(2024)),
            updatedAt: Value(createdAt ?? DateTime(2024)),
            retries: Value(retries),
          ),
        );
      }

      setUp(() {
        realDb = SyncDatabase(inMemoryDatabase: true);
        realRepo = DatabaseOutboxRepository(realDb, maxRetries: 2);
      });
      tearDown(() async {
        await realDb.close();
      });

      test('markSentBatch flips every row to status=sent', () async {
        final ids = <int>[];
        for (var i = 0; i < 3; i++) {
          ids.add(
            await insertRow(
              status: OutboxStatus.sending,
              createdAt: DateTime(2024).add(Duration(minutes: i)),
            ),
          );
        }
        final items = <OutboxItem>[];
        for (final id in ids) {
          final row = await realDb.getOutboxItemById(id);
          expect(row, isNotNull);
          items.add(row!);
        }

        await realRepo.markSentBatch(items);

        for (final id in ids) {
          final refreshed = await realDb.getOutboxItemById(id);
          expect(refreshed?.status, OutboxStatus.sent.index);
        }
      });

      test('markSentBatch is a no-op for an empty list', () async {
        // Nothing to assert on the DB, but the call must not throw and must
        // not require a transaction round-trip — covered by the absence of
        // exceptions and by the next test still seeing untouched rows.
        await realRepo.markSentBatch(<OutboxItem>[]);
      });

      test(
        'markRetryBatch increments retries on every row while keeping rows '
        'below the cap as pending',
        () async {
          final id1 = await insertRow(status: OutboxStatus.sending);
          final id2 = await insertRow(
            status: OutboxStatus.sending,
            createdAt: DateTime(2024).add(const Duration(minutes: 1)),
          );
          final items = <OutboxItem>[
            (await realDb.getOutboxItemById(id1))!,
            (await realDb.getOutboxItemById(id2))!,
          ];

          await realRepo.markRetryBatch(items);

          for (final id in [id1, id2]) {
            final refreshed = await realDb.getOutboxItemById(id);
            expect(refreshed?.retries, 1);
            expect(refreshed?.status, OutboxStatus.pending.index);
          }
        },
      );

      test(
        'markRetryBatch flips each row to error once its incremented retry '
        'count reaches maxRetries — applied per row, so one batch can have '
        'some rows retried and others capped',
        () async {
          final stillTryingId = await insertRow(
            status: OutboxStatus.sending,
          );
          final cappedId = await insertRow(
            status: OutboxStatus.sending,
            retries: 1,
            createdAt: DateTime(2024).add(const Duration(minutes: 1)),
          );
          final items = <OutboxItem>[
            (await realDb.getOutboxItemById(stillTryingId))!,
            (await realDb.getOutboxItemById(cappedId))!,
          ];

          await realRepo.markRetryBatch(items);

          final stillTrying = await realDb.getOutboxItemById(stillTryingId);
          expect(stillTrying?.retries, 1);
          expect(stillTrying?.status, OutboxStatus.pending.index);

          final capped = await realDb.getOutboxItemById(cappedId);
          expect(capped?.retries, 2);
          expect(capped?.status, OutboxStatus.error.index);
        },
      );

      test('markRetryBatch is a no-op for an empty list', () async {
        await realRepo.markRetryBatch(<OutboxItem>[]);
      });

      glados.Glados(
        glados.any.repositoryBatchScenario,
        glados.ExploreConfig(numRuns: 140),
      ).test(
        'generated batch marking updates only selected rows with cap semantics',
        (scenario) async {
          realRepo = DatabaseOutboxRepository(
            realDb,
            maxRetries: scenario.maxRetries,
          );

          final ids = <int>[];
          for (var index = 0; index < scenario.rows.length; index++) {
            final row = scenario.rows[index];
            ids.add(
              await insertRow(
                status: row.initialStatus,
                retries: row.retries,
                createdAt: DateTime(2024).add(Duration(minutes: index)),
              ),
            );
          }

          final selectedItems = <OutboxItem>[];
          for (var index = 0; index < scenario.rows.length; index++) {
            if (!scenario.rows[index].selected) {
              continue;
            }
            final item = await realDb.getOutboxItemById(ids[index]);
            expect(item, isNotNull);
            selectedItems.add(item!);
          }

          switch (scenario.operation) {
            case _GeneratedRepositoryBatchOperation.markSent:
              await realRepo.markSentBatch(selectedItems);
            case _GeneratedRepositoryBatchOperation.markRetry:
              await realRepo.markRetryBatch(selectedItems);
          }

          for (var index = 0; index < scenario.rows.length; index++) {
            final row = scenario.rows[index];
            final refreshed = await realDb.getOutboxItemById(ids[index]);
            expect(refreshed, isNotNull);
            expect(refreshed!.status, scenario.expectedStatus(row).index);
            expect(refreshed.retries, scenario.expectedRetries(row));
          }
        },
        tags: 'glados',
      );
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

    group('pruneSentOutboxItemsChunked', () {
      test(
        'forwards every parameter (retention, chunkSize, vacuumWhenDone, '
        'onProgress) to the database call so the chunked path is wired '
        'through end-to-end',
        () async {
          Duration? capturedRetention;
          int? capturedChunkSize;
          bool? capturedVacuum;
          void Function(int)? capturedProgress;
          when(
            () => database.pruneSentOutboxItemsChunked(
              retention: any(named: 'retention'),
              chunkSize: any(named: 'chunkSize'),
              vacuumWhenDone: any(named: 'vacuumWhenDone'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((invocation) async {
            capturedRetention =
                invocation.namedArguments[#retention] as Duration?;
            capturedChunkSize = invocation.namedArguments[#chunkSize] as int?;
            capturedVacuum =
                invocation.namedArguments[#vacuumWhenDone] as bool?;
            capturedProgress =
                invocation.namedArguments[#onProgress] as void Function(int)?;
            // Simulate two chunks landing — caller's onProgress should
            // receive both totals as the chunked loop reports.
            capturedProgress?.call(5);
            capturedProgress?.call(7);
            return 7;
          });

          final reported = <int>[];
          final deleted = await repository.pruneSentOutboxItemsChunked(
            retention: const Duration(days: 14),
            chunkSize: 2500,
            vacuumWhenDone: true,
            onProgress: reported.add,
          );

          expect(deleted, 7);
          expect(capturedRetention, const Duration(days: 14));
          expect(capturedChunkSize, 2500);
          expect(capturedVacuum, isTrue);
          expect(reported, [5, 7]);
        },
      );

      test(
        'defaults vacuumWhenDone to false so the periodic background '
        'sweep does not pay the VACUUM cost on every tick',
        () async {
          bool? capturedVacuum;
          when(
            () => database.pruneSentOutboxItemsChunked(
              retention: any(named: 'retention'),
              chunkSize: any(named: 'chunkSize'),
              vacuumWhenDone: any(named: 'vacuumWhenDone'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((invocation) async {
            capturedVacuum =
                invocation.namedArguments[#vacuumWhenDone] as bool?;
            return 0;
          });

          await repository.pruneSentOutboxItemsChunked(
            retention: const Duration(days: 7),
          );

          expect(capturedVacuum, isFalse);
        },
      );
    });
  });
}
