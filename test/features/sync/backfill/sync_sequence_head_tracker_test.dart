import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/backfill/sync_sequence_head_tracker.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';

import '../../../database/sync_db_test_utils.dart';
import '../../../mocks/mocks.dart';

void main() {
  late SyncDatabase database;
  late SyncSequenceLogService sequenceLog;
  late SyncSequenceHeadTracker tracker;
  final initialTime = DateTime.utc(2026, 9, 26, 12);
  const freshness = Duration(minutes: 6);

  setUp(() {
    database = SyncDatabase(inMemoryDatabase: true);
    sequenceLog = SyncSequenceLogService(
      syncDatabase: database,
      vectorClockService: MockVectorClockService(),
      loggingService: MockDomainLogger(),
    );
    tracker = SyncSequenceHeadTracker(
      database: database,
      sequenceLog: sequenceLog,
      freshness: freshness,
    );
  });
  tearDown(() async => database.close());

  Future<List<int>> candidates({Map<String, int> coverage = const {}}) async =>
      (await tracker.loadRepairBatch(
        limit: 2,
        perHost: 2,
        retryCooldown: const Duration(hours: 1),
        suppressedCoverage: coverage,
      )).map((row) => row.counter).toList();

  glados.Glados(
    glados.CombinableAny(glados.any).combine2(
      glados.IntAnys(glados.any).intInRange(1, 16),
      glados.IntAnys(glados.any).intInRange(1, 6),
      (head, batch) => (head: head, batch: batch),
    ),
    glados.ExploreConfig(numRuns: 30),
  ).test('bounded scans discover every counter despite older announcements', (
    scenario,
  ) async {
    await withClock(Clock.fixed(initialTime), () async {
      await clearAllSyncTables(database);
      final freshSequence = SyncSequenceLogService(
        syncDatabase: database,
        vectorClockService: MockVectorClockService(),
        loggingService: MockDomainLogger(),
      );
      final freshTracker = SyncSequenceHeadTracker(
        database: database,
        sequenceLog: freshSequence,
        freshness: freshness,
      )..observe('origin', scenario.head);
      for (
        var scanned = 0;
        scanned < scenario.head;
        scanned += scenario.batch
      ) {
        freshTracker.observe('origin', 1);
        await freshTracker.materialize(
          limit: scenario.batch,
          perHost: scenario.batch,
        );
      }
      final rows = await freshTracker.loadRepairBatch(
        limit: scenario.head + 1,
        perHost: scenario.head + 1,
        retryCooldown: Duration.zero,
      );
      expect(rows.map((row) => row.counter), [
        for (var counter = 1; counter <= scenario.head; counter++) counter,
      ]);
      expect(
        rows.every((row) => row.status == SyncSequenceStatus.missing.index),
        isTrue,
      );
      expect(
        await database.getEntryByHostAndCounter('origin', scenario.head + 1),
        isNull,
      );
      expect(await database.resolvedSequenceUpperBounds(), isEmpty);
    });
  }, tags: 'glados');

  test(
    'discovers the final counter in bounded slices without receipts',
    () async {
      await withClock(Clock.fixed(initialTime), () async {
        tracker.observe('origin', 3);
        await tracker.materialize(limit: 2, perHost: 2);
        expect(await candidates(), [1, 2]);
        expect(await database.getEntryByHostAndCounter('origin', 3), isNull);

        // An unresolved earlier counter cannot pin the scan to the same slice.
        tracker.observe('origin', 1);
        await tracker.materialize(limit: 2, perHost: 2);
        for (var counter = 1; counter <= 3; counter++) {
          final row = await database.getEntryByHostAndCounter(
            'origin',
            counter,
          );
          expect(row?.status, SyncSequenceStatus.missing.index);
        }
        expect(await database.getLastCounterForHost('origin'), 0);
        expect(await database.resolvedSequenceUpperBounds(), isEmpty);
      });
    },
  );

  test(
    'fresh heads reopen retired gaps with cooldown and preserve receipts',
    () async {
      await withClock(Clock.fixed(initialTime), () async {
        final old = DateTime.utc(2024);
        final statuses = [
          SyncSequenceStatus.unresolvable,
          SyncSequenceStatus.received,
          SyncSequenceStatus.burned,
          SyncSequenceStatus.deleted,
          SyncSequenceStatus.requested,
        ];
        for (var i = 0; i < statuses.length; i++) {
          await database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value('origin'),
              counter: Value(i + 1),
              status: Value(statuses[i].index),
              createdAt: Value(old),
              updatedAt: Value(old),
              requestCount: const Value(99),
              lastRequestedAt: Value(i == 4 ? initialTime : old),
            ),
          );
        }
        tracker.observe('origin', 5);
        expect(await candidates(), [1]);
        expect(await database.getLastCounterForHost('origin'), 4);

        await sequenceLog.markAnnouncedHeadRequests([
          (hostId: 'origin', counter: 1),
        ]);
        expect(await candidates(), isEmpty);
        expect(await database.getLastCounterForHost('origin'), 0);
        for (var i = 1; i < statuses.length; i++) {
          final row = await database.getEntryByHostAndCounter('origin', i + 1);
          expect(row?.status, statuses[i].index);
        }
      });
    },
  );

  test('expires silent origins and accepts later announcements', () async {
    var now = initialTime;
    await withClock(Clock(() => now), () async {
      tracker
        ..observe('', 2)
        ..observe('origin', 0);
      expect(tracker.hasFreshHeads, isFalse);
      tracker.observe('origin', 2);
      expect(tracker.hasFreshHeads, isTrue);
      now = now.add(freshness);
      expect(tracker.hasFreshHeads, isFalse);
      await tracker.materialize(limit: 2, perHost: 2);
      expect(await candidates(), isEmpty);

      tracker.observe('origin', 2);
      await tracker.materialize(limit: 2, perHost: 2);
      expect(await candidates(), [1, 2]);
    });
  });

  test(
    'rotates origins when the pass budget is smaller than the host set',
    () async {
      await withClock(Clock.fixed(initialTime), () async {
        for (final host in ['a', 'b', 'c']) {
          tracker.observe(host, 2);
        }
        for (var i = 0; i < 3; i++) {
          await tracker.materialize(limit: 1, perHost: 1);
        }
        final selected = <String>[];
        for (var i = 0; i < 3; i++) {
          final batch = await tracker.loadRepairBatch(
            limit: 1,
            perHost: 1,
            retryCooldown: Duration.zero,
          );
          selected.add(batch.single.hostId);
          expect(batch.single.counter, 1);
        }
        expect(selected, ['a', 'b', 'c']);
        await tracker.materialize(limit: 1, perHost: 1);
        expect(
          (await database.getEntryByHostAndCounter('a', 2))?.status,
          SyncSequenceStatus.missing.index,
        );
      });
    },
  );

  test(
    'pages past pending and leased requests without duplicating them',
    () async {
      await withClock(Clock.fixed(initialTime), () async {
        tracker.observe('origin', 6);
        await tracker.materialize(limit: 6, perHost: 6);
        for (final status in [OutboxStatus.pending, OutboxStatus.sending]) {
          final first = status == OutboxStatus.pending ? 1 : 3;
          await database.addOutboxItem(
            buildOutboxCompanion(
              status: status,
              createdAt: initialTime,
              subject: 'backfillRequest:batch:2',
              message: jsonEncode(
                SyncMessage.backfillRequest(
                  entries: [
                    for (var counter = first; counter < first + 2; counter++)
                      BackfillRequestEntry(hostId: 'origin', counter: counter),
                  ],
                  requesterId: 'receiver',
                ).toJson(),
              ),
            ),
          );
        }
        expect(await candidates(), [5, 6]);
        expect(await candidates(coverage: {'origin': 5}), [6]);
      });
    },
  );

  test('snapshot promises do not advance the durable scan cursor', () async {
    await withClock(Clock.fixed(initialTime), () async {
      tracker.observe('origin', 3);
      await tracker.materialize(
        limit: 3,
        perHost: 3,
        suppressedCoverage: {'origin': 3},
      );
      expect(await database.getEntryByHostAndCounter('origin', 1), isNull);
      await tracker.materialize(limit: 3, perHost: 3);
      expect(await candidates(), [1, 2]);
      expect(
        (await database.getEntryByHostAndCounter('origin', 3))?.status,
        SyncSequenceStatus.missing.index,
      );
    });
  });

  test('failed materialization does not advance the next scan', () async {
    await withClock(Clock.fixed(initialTime), () async {
      tracker.observe('origin', 2);
      await database.customStatement('''
        CREATE TRIGGER refuse_head_gap BEFORE INSERT ON sync_sequence_log
        BEGIN SELECT RAISE(ABORT, 'head gap unavailable'); END
      ''');
      await expectLater(
        tracker.materialize(limit: 2, perHost: 2),
        throwsA(isA<Exception>()),
      );
      await database.customStatement('DROP TRIGGER refuse_head_gap');
      await tracker.materialize(limit: 2, perHost: 2);
      expect(await candidates(), [1, 2]);
    });
  });
}
