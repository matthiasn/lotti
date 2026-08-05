// ignore_for_file: avoid_redundant_argument_values

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'sync_sequence_log_service_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSyncDatabase mockDb;
  late MockDomainLogger mockLogging;
  late SyncSequenceLogService service;

  const myHostId = 'my-host-uuid';
  const aliceHostId = 'alice-host-uuid';
  const bobHostId = 'bob-host-uuid';

  setUpAll(registerSyncSequenceLogFallbackValues);

  setUp(() {
    final bench = SyncSequenceLogServiceTestBench.create(
      myHostId: myHostId,
      aliceHostId: aliceHostId,
      bobHostId: bobHostId,
    );
    mockDb = bench.mockDb;
    mockLogging = bench.mockLogging;
    service = bench.service;
  });

  group('recordReceivedEntry', () {
    test(
      "does not reopen a burned row for the originating host's own counter — "
      'burned is terminal even against a contradictory re-send',
      () async {
        final bench = RealSequenceLogTestBench.create(myHostId: myHostId);
        try {
          await bench.database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(aliceHostId),
              counter: const Value(3),
              entryId: const Value(null),
              status: Value(SyncSequenceStatus.burned.index),
              createdAt: Value(DateTime(2026, 5, 24, 10)),
              updatedAt: Value(DateTime(2026, 5, 24, 10)),
            ),
          );

          await bench.service.recordReceivedEntry(
            entryId: 'late-alice-3',
            vectorClock: const VectorClock({aliceHostId: 3}),
            originatingHostId: aliceHostId,
          );

          final row = await bench.database.getEntryByHostAndCounter(
            aliceHostId,
            3,
          );
          expect(row?.status, SyncSequenceStatus.burned.index);
          // The burn's empty payload mapping must survive.
          expect(row?.entryId, isNull);
        } finally {
          await bench.close();
        }
      },
    );

    test(
      'does not reopen a burned row that a different host entry merely covers '
      'in its vector clock — no phantom cross-entity mapping',
      () async {
        final bench = RealSequenceLogTestBench.create(myHostId: myHostId);
        try {
          await bench.database.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: const Value(bobHostId),
              counter: const Value(5),
              entryId: const Value(null),
              status: Value(SyncSequenceStatus.burned.index),
              createdAt: Value(DateTime(2026, 5, 24, 10)),
              updatedAt: Value(DateTime(2026, 5, 24, 10)),
            ),
          );

          // Alice's entry carries bob:5 in its vector clock — a covering
          // reference from a different entity, not bob's payload at counter 5.
          await bench.service.recordReceivedEntry(
            entryId: 'alice-entry-covering-bob-5',
            vectorClock: const VectorClock({aliceHostId: 2, bobHostId: 5}),
            originatingHostId: aliceHostId,
          );

          final bobRow = await bench.database.getEntryByHostAndCounter(
            bobHostId,
            5,
          );
          expect(bobRow?.status, SyncSequenceStatus.burned.index);
          expect(bobRow?.entryId, isNull);
        } finally {
          await bench.close();
        }
      },
    );

    test('records entry without gaps when sequential', () async {
      // Alice counter 1, first entry we've seen from Alice
      const vectorClock = VectorClock({aliceHostId: 1});
      const entryId = 'entry-1';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 1),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps, isEmpty);
      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });

    test('detects gaps when counter jumps', () async {
      // Alice counter was 2, now we get counter 5 - missing 3 and 4
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-5';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps.length, 2);
      expect(gaps[0], (hostId: aliceHostId, counter: 3));
      expect(gaps[1], (hostId: aliceHostId, counter: 4));

      // Missing counters are materialized in one batch, then the received entry
      // is recorded normally.
      verify(() => mockDb.batchInsertSequenceEntries(any())).called(1);
      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });

    test(
      'a skip-ahead counter leaves the cached watermark unchanged — '
      'under-reporting is safe, over-reporting would mask real gaps',
      () async {
        when(
          () => mockDb.getLastCounterForHost(aliceHostId),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockDb.batchInsertSequenceEntries(any()),
        ).thenAnswer((_) async {});

        // 1. Sequential counter 1: cold cache fills (one SQL read), then
        //    advances to 1.
        await service.recordReceivedEntry(
          entryId: 'e1',
          vectorClock: const VectorClock({aliceHostId: 1}),
          originatingHostId: aliceHostId,
        );

        // 2. Skip-ahead to 4: a gap — _advanceLastCounterCache must NOT
        //    move the watermark to 4.
        final gapsAt4 = await service.recordReceivedEntry(
          entryId: 'e4',
          vectorClock: const VectorClock({aliceHostId: 4}),
          originatingHostId: aliceHostId,
        );
        expect(gapsAt4, [
          (hostId: aliceHostId, counter: 2),
          (hostId: aliceHostId, counter: 3),
        ]);

        // 3. Counter 5: the gap scan must still start just above the cached
        //    watermark 1, re-flagging the unresolved 2 and 3 (4 now
        //    resolves). Had the skip-ahead advanced the cache to 4, the
        //    scan would start at 5 and report nothing.
        when(
          () => mockDb.getCountersForHostInRange(aliceHostId, 2, 4),
        ).thenAnswer((_) async => {4});
        when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 4)).thenAnswer(
          (_) async => createLogItem(
            aliceHostId,
            4,
            status: SyncSequenceStatus.received,
          ),
        );
        final gapsAt5 = await service.recordReceivedEntry(
          entryId: 'e5',
          vectorClock: const VectorClock({aliceHostId: 5}),
          originatingHostId: aliceHostId,
        );
        expect(gapsAt5, [
          (hostId: aliceHostId, counter: 2),
          (hostId: aliceHostId, counter: 3),
        ]);

        // The cached watermark served every read after the cold fill — the
        // slow watermark CTE ran exactly once.
        verify(() => mockDb.getLastCounterForHost(aliceHostId)).called(1);
      },
    );

    test(
      'detects the missing prefix when an online host has no stored counters yet',
      () async {
        const vectorClock = VectorClock({aliceHostId: 5});
        const entryId = 'entry-5';

        when(
          () => mockDb.getLastCounterForHost(aliceHostId),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, 1),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, 2),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, 3),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, 4),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        final gaps = await service.recordReceivedEntry(
          entryId: entryId,
          vectorClock: vectorClock,
          originatingHostId: aliceHostId,
        );

        expect(gaps, hasLength(4));
        expect(gaps.map((gap) => gap.counter).toList(), [1, 2, 3, 4]);
      },
    );

    test('skips own host in vector clock', () async {
      // VC includes our own host - should be skipped
      const vectorClock = VectorClock({myHostId: 10, aliceHostId: 5});
      const entryId = 'entry-x';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 4);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps, isEmpty);
      // Should track alice but not our own host
      verify(() => mockDb.getLastCounterForHost(aliceHostId)).called(1);
      verifyNever(() => mockDb.getLastCounterForHost(myHostId));
    });

    test('tracks ALL hosts in VC for gap detection', () async {
      // Multi-host VC: alice is originator, but we also track bob's counter
      const vectorClock = VectorClock({aliceHostId: 5, bobHostId: 8});
      const entryId = 'entry-alice';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 4);
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 6);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getEntryByHostAndCounter(bobHostId, 8),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      // Should detect gap for bob (7 is missing between 6 and 8)
      expect(gaps.length, 1);
      expect(gaps[0], (hostId: bobHostId, counter: 7));

      // Should check both hosts for gaps
      verify(() => mockDb.getLastCounterForHost(aliceHostId)).called(1);
      verify(() => mockDb.getLastCounterForHost(bobHostId)).called(1);

      // Missing counters are materialized in a batch; observed counters still
      // write individual sequence rows with entryId hints.
      verify(() => mockDb.batchInsertSequenceEntries(any())).called(1);
      verify(() => mockDb.recordSequenceEntry(any())).called(2);
    });

    test('ALL hosts in VC get entryId (enables backfill responses)', () async {
      // Multi-host VC: ALL hosts get the entryId so we can respond to
      // backfill requests for any (host, counter) in the entry's VC
      const vectorClock = VectorClock({aliceHostId: 5, bobHostId: 3});
      const entryId = 'entry-alice';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 4);
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getEntryByHostAndCounter(bobHostId, 3),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      // Should have 2 records: both alice and bob with entryId
      expect(captured.length, 2);

      final aliceRecord =
          captured.firstWhere(
                (c) =>
                    (c as SyncSequenceLogCompanion).hostId.value == aliceHostId,
              )
              as SyncSequenceLogCompanion;
      final bobRecord =
          captured.firstWhere(
                (c) =>
                    (c as SyncSequenceLogCompanion).hostId.value == bobHostId,
              )
              as SyncSequenceLogCompanion;

      // Both hosts should have the entryId set
      expect(aliceRecord.entryId.value, entryId);
      expect(bobRecord.entryId.value, entryId);
    });

    test('does not duplicate missing entries', () async {
      // Alice counter 3 was already marked missing, counter 5 arrives
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-5';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockDb.getCountersForHostInRange(aliceHostId, 3, 4),
      ).thenAnswer((_) async => {3});
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async =>
            createLogItem(aliceHostId, 3, status: SyncSequenceStatus.missing),
      );
      // Counter 5 doesn't exist
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      // Should still report gaps but not insert duplicate
      expect(gaps.length, 2);
      // Only one missing row is batch-inserted (4) and the received counter 5
      // is written normally.
      verify(() => mockDb.batchInsertSequenceEntries(any())).called(1);
      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });

    test(
      'does not report resolved counters from a stale cached watermark',
      () async {
        final bench = RealSequenceLogTestBench.create(myHostId: myHostId);

        try {
          await seedResolvedPrefix(
            database: bench.database,
            hostId: aliceHostId,
            resolvedPrefix: 10,
          );

          final firstGaps = await bench.service.recordReceivedEntry(
            entryId: 'stale-cache-entry-12',
            vectorClock: const VectorClock({aliceHostId: 12}),
            originatingHostId: aliceHostId,
          );
          expect(firstGaps, [(hostId: aliceHostId, counter: 11)]);
          expect(bench.missingCallbackCount, 1);

          final backfillGaps = await bench.service.recordReceivedEntry(
            entryId: 'stale-cache-entry-11',
            vectorClock: const VectorClock({aliceHostId: 11}),
            originatingHostId: aliceHostId,
          );
          expect(backfillGaps, isEmpty);

          final afterResolvedGaps = await bench.service.recordReceivedEntry(
            entryId: 'stale-cache-entry-13',
            vectorClock: const VectorClock({aliceHostId: 13}),
            originatingHostId: aliceHostId,
          );

          expect(afterResolvedGaps, isEmpty);
          expect(bench.missingCallbackCount, 1);
          expect(await bench.database.getLastCounterForHost(aliceHostId), 13);
        } finally {
          await bench.close();
        }
      },
    );

    glados.Glados(
      AnySequenceGapScenario(glados.any).sequenceGapScenario,
      glados.ExploreConfig(numRuns: 60),
    ).test(
      'matches the single-host gap model for generated sequence states',
      (scenario) async {
        final bench = RealSequenceLogTestBench.create(myHostId: myHostId);

        try {
          await seedGeneratedSequenceScenario(
            database: bench.database,
            hostId: aliceHostId,
            scenario: scenario,
          );

          final entryId = 'generated-entry-${scenario.observedCounter}';
          final expectedGaps = scenario.expectedGaps(aliceHostId);
          final expectedNewMissingCount = expectedGaps
              .where((gap) => scenario.insertsNewMissingCounter(gap.counter))
              .length;

          final gaps = await bench.service.recordReceivedEntry(
            entryId: entryId,
            vectorClock: VectorClock({aliceHostId: scenario.observedCounter}),
            originatingHostId: aliceHostId,
          );

          expect(gaps, expectedGaps);
          expect(
            bench.missingCallbackCount,
            expectedNewMissingCount > 0 ? 1 : 0,
          );

          for (final gap in expectedGaps) {
            final entry = await bench.database.getEntryByHostAndCounter(
              aliceHostId,
              gap.counter,
            );
            expect(entry, isNotNull);
            expect(
              entry?.status,
              scenario.expectedStatusAfterReceive(gap.counter)?.index,
            );
          }

          final observed = await bench.database.getEntryByHostAndCounter(
            aliceHostId,
            scenario.observedCounter,
          );
          expect(observed, isNotNull);
          expect(observed?.entryId, entryId);
          expect(observed?.status, scenario.expectedObservedStatus().index);

          expect(
            await bench.database.getLastCounterForHost(aliceHostId),
            scenario.expectedLastResolvedPrefixAfterReceive(),
          );
        } finally {
          await bench.close();
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      AnySequenceGapScenario(glados.any).coveredClockGapScenario,
      glados.ExploreConfig(numRuns: 60),
    ).test('uses covered vector clocks before deciding generated gaps', (
      scenario,
    ) async {
      final bench = RealSequenceLogTestBench.create(myHostId: myHostId);

      try {
        final entryId = 'covered-entry-${scenario.observedCounter}';
        final expectedGaps = scenario.expectedGaps(aliceHostId);
        final expectedNewMissingCount = expectedGaps
            .where((gap) => scenario.insertsNewMissingCounter(gap.counter))
            .length;

        final gaps = await bench.service.recordReceivedEntry(
          entryId: entryId,
          vectorClock: VectorClock({aliceHostId: scenario.observedCounter}),
          originatingHostId: aliceHostId,
          coveredVectorClocks: [
            for (final counter in scenario.coveredCounters)
              VectorClock({aliceHostId: counter}),
          ],
        );

        expect(gaps, expectedGaps);
        expect(bench.missingCallbackCount, expectedNewMissingCount > 0 ? 1 : 0);

        final maxCoveredCounter = scenario.coveredCounters.isEmpty
            ? 0
            : scenario.coveredCounters.reduce((a, b) => a > b ? a : b);
        final maxCounter = scenario.observedCounter > maxCoveredCounter
            ? scenario.observedCounter
            : maxCoveredCounter;
        for (var counter = 1; counter <= maxCounter; counter++) {
          final expectedStatus = scenario.expectedStatusAfterReceive(counter);
          final entry = await bench.database.getEntryByHostAndCounter(
            aliceHostId,
            counter,
          );
          if (expectedStatus == null) {
            expect(entry, isNull);
          } else {
            expect(entry, isNotNull);
            expect(entry?.status, expectedStatus.index);
          }
        }

        final observed = await bench.database.getEntryByHostAndCounter(
          aliceHostId,
          scenario.observedCounter,
        );
        expect(observed, isNotNull);
        expect(observed?.entryId, entryId);
        expect(observed?.status, SyncSequenceStatus.received.index);

        expect(
          await bench.database.getLastCounterForHost(aliceHostId),
          scenario.expectedLastResolvedPrefixAfterReceive(),
        );
      } finally {
        await bench.close();
      }
    }, tags: 'glados');

    glados.Glados(
      AnySequenceGapScenario(glados.any).multiHostGapScenario,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'matches the multi-host gap model for generated vector clocks',
      (scenario) async {
        const charlieHostId = 'charlie-host-uuid';
        final bench = RealSequenceLogTestBench.create(myHostId: myHostId);
        final seenAt = DateTime(2024, 3, 15, 11);

        try {
          await seedResolvedPrefix(
            database: bench.database,
            hostId: aliceHostId,
            resolvedPrefix: scenario.originatorResolvedPrefix,
          );
          await seedResolvedPrefix(
            database: bench.database,
            hostId: bobHostId,
            resolvedPrefix: scenario.bob.resolvedPrefix,
          );
          await seedResolvedPrefix(
            database: bench.database,
            hostId: charlieHostId,
            resolvedPrefix: scenario.charlie.resolvedPrefix,
          );
          await seedResolvedPrefix(
            database: bench.database,
            hostId: myHostId,
            resolvedPrefix: scenario.ownHost.resolvedPrefix,
          );

          if (scenario.bob.knownOnline) {
            await bench.database.updateHostActivity(bobHostId, seenAt);
          }
          if (scenario.charlie.knownOnline) {
            await bench.database.updateHostActivity(charlieHostId, seenAt);
          }

          final entryId =
              'multi-host-entry-${scenario.originatorObservedCounter}';
          final expectedGaps = scenario.expectedGaps(
            aliceHostId: aliceHostId,
            bobHostId: bobHostId,
            charlieHostId: charlieHostId,
          );

          final gaps = await bench.service.recordReceivedEntry(
            entryId: entryId,
            vectorClock: VectorClock(
              scenario.vectorClock(
                myHostId: myHostId,
                aliceHostId: aliceHostId,
                bobHostId: bobHostId,
                charlieHostId: charlieHostId,
              ),
            ),
            originatingHostId: aliceHostId,
          );

          expect(gaps, expectedGaps);
          expect(
            bench.missingCallbackCount,
            scenario.insertsNewMissing ? 1 : 0,
          );

          for (final gap in expectedGaps) {
            final entry = await bench.database.getEntryByHostAndCounter(
              gap.hostId,
              gap.counter,
            );
            expect(entry, isNotNull);
            expect(entry?.status, SyncSequenceStatus.missing.index);
          }

          await expectObservedCounter(
            database: bench.database,
            hostId: aliceHostId,
            counter: scenario.originatorObservedCounter,
            entryId: entryId,
          );
          if (scenario.bob.included) {
            await expectObservedCounter(
              database: bench.database,
              hostId: bobHostId,
              counter: scenario.bob.observedCounter,
              entryId: entryId,
            );
          }
          if (scenario.charlie.included) {
            await expectObservedCounter(
              database: bench.database,
              hostId: charlieHostId,
              counter: scenario.charlie.observedCounter,
              entryId: entryId,
            );
          }

          final ownObserved = await bench.database.getEntryByHostAndCounter(
            myHostId,
            scenario.ownHost.observedCounter,
          );
          if (scenario.ownHost.included &&
              scenario.ownHost.observedCounter >
                  scenario.ownHost.resolvedPrefix) {
            expect(ownObserved, isNull);
          } else if (scenario.ownHost.included) {
            expect(ownObserved, isNotNull);
            expect(ownObserved?.entryId, isNot(entryId));
          }

          for (final (:hostId, :expectedPrefix) in [
            (
              hostId: aliceHostId,
              expectedPrefix: scenario.expectedResolvedPrefixAfterReceive(
                hostId: aliceHostId,
                aliceHostId: aliceHostId,
                bobHostId: bobHostId,
                charlieHostId: charlieHostId,
                myHostId: myHostId,
              ),
            ),
            (
              hostId: bobHostId,
              expectedPrefix: scenario.expectedResolvedPrefixAfterReceive(
                hostId: bobHostId,
                aliceHostId: aliceHostId,
                bobHostId: bobHostId,
                charlieHostId: charlieHostId,
                myHostId: myHostId,
              ),
            ),
            (
              hostId: charlieHostId,
              expectedPrefix: scenario.expectedResolvedPrefixAfterReceive(
                hostId: charlieHostId,
                aliceHostId: aliceHostId,
                bobHostId: bobHostId,
                charlieHostId: charlieHostId,
                myHostId: myHostId,
              ),
            ),
            (
              hostId: myHostId,
              expectedPrefix: scenario.expectedResolvedPrefixAfterReceive(
                hostId: myHostId,
                aliceHostId: aliceHostId,
                bobHostId: bobHostId,
                charlieHostId: charlieHostId,
                myHostId: myHostId,
              ),
            ),
          ]) {
            expect(
              await bench.database.getLastCounterForHost(hostId),
              expectedPrefix,
              reason: 'watermark mismatch for $hostId in $scenario',
            );
          }
        } finally {
          await bench.close();
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      AnySequenceGapScenario(glados.any).statefulSequenceScenario,
      glados.ExploreConfig(numRuns: 80),
    ).test('matches the generated multi-event sequence model', (
      scenario,
    ) async {
      final bench = RealSequenceLogTestBench.create(myHostId: myHostId);
      final model = StatefulSequenceModel(hostId: aliceHostId);
      var expectedCallbackCount = 0;

      Future<void> applyEvents() async {
        for (var index = 0; index < scenario.events.length; index++) {
          final event = scenario.events[index];
          final expected = model.apply(event);
          if (expected.insertedNewMissing) {
            expectedCallbackCount++;
          }

          final gaps = await bench.service.recordReceivedEntry(
            entryId: 'stateful-entry-$index-${event.observedCounter}',
            vectorClock: VectorClock({aliceHostId: event.observedCounter}),
            originatingHostId: aliceHostId,
            coveredVectorClocks: [
              for (final counter in event.coveredCounters)
                VectorClock({aliceHostId: counter}),
            ],
          );

          expect(gaps, expected.gaps);
          if (scenario.deferMissingCallback) {
            expect(bench.missingCallbackCount, 0);
          } else {
            expect(bench.missingCallbackCount, expectedCallbackCount);
          }

          if (expected.requestedAfter.isNotEmpty) {
            await bench.service.markAsRequested(expected.requestedAfter);
          }
        }
      }

      try {
        if (scenario.deferMissingCallback) {
          await bench.service.runWithDeferredMissingEntries(applyEvents);
          expect(bench.missingCallbackCount, expectedCallbackCount > 0 ? 1 : 0);
        } else {
          await applyEvents();
          expect(bench.missingCallbackCount, expectedCallbackCount);
        }

        for (var counter = 1; counter <= model.maxCounter; counter++) {
          final expectedStatus = model.statusAt(counter);
          final entry = await bench.database.getEntryByHostAndCounter(
            aliceHostId,
            counter,
          );
          if (expectedStatus == null) {
            expect(entry, isNull);
          } else {
            expect(entry, isNotNull);
            expect(entry?.status, expectedStatus.index);
          }
        }

        expect(
          await bench.database.getLastCounterForHost(aliceHostId),
          model.lastResolvedPrefix(),
        );
      } finally {
        await bench.close();
      }
    }, tags: 'glados');

    test('marks previously missing entry as received', () async {
      // Entry was marked missing before, now it arrives via normal sync
      // (not via backfill request). Missing entries become received.
      const vectorClock = VectorClock({aliceHostId: 3});
      const entryId = 'entry-3';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 2);
      // Entry 3 exists and is missing
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 3),
      ).thenAnswer((_) async => createLogItem(aliceHostId, 3));
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps, isEmpty);

      // Verify the entry was recorded with received status
      // (only explicitly requested entries become backfilled)
      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;
      expect(captured.length, 1);
      final companion = captured[0] as SyncSequenceLogCompanion;
      expect(companion.status.value, SyncSequenceStatus.received.index);
    });

    test('marks previously requested entry as backfilled', () async {
      // Entry was explicitly requested via backfill, now it arrives
      // Requested entries become backfilled (request was fulfilled).
      const vectorClock = VectorClock({aliceHostId: 3});
      const entryId = 'entry-3';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 2);
      // Entry 3 exists and is requested
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async => createLogItem(
          aliceHostId,
          3,
          status: SyncSequenceStatus.requested,
        ),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps, isEmpty);

      // Verify the entry was recorded with backfilled status
      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;
      expect(captured.length, 1);
      final companion = captured[0] as SyncSequenceLogCompanion;
      expect(companion.status.value, SyncSequenceStatus.backfilled.index);

      // Verify backfill arrival was logged
      verify(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(that: contains('backfilled hostId=$aliceHostId')),
          subDomain: 'sequence.backfillArrived',
        ),
      ).called(1);
    });

    test('does not downgrade backfilled entry to received', () async {
      // Entry was already backfilled, receiving it again should NOT change status
      const vectorClock = VectorClock({aliceHostId: 3});
      const entryId = 'entry-3';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 2);
      // Entry 3 exists and is already backfilled
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async => createLogItem(
          aliceHostId,
          3,
          status: SyncSequenceStatus.backfilled,
        ),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      // Verify the entry keeps backfilled status (not downgraded to received)
      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;
      expect(captured.length, 1);
      final companion = captured[0] as SyncSequenceLogCompanion;
      expect(companion.status.value, SyncSequenceStatus.backfilled.index);
    });

    test('updates host activity for originating host', () async {
      // When receiving an entry, we should update host activity
      const vectorClock = VectorClock({aliceHostId: 1});
      const entryId = 'entry-1';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 1),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      // Verify host activity was updated for the originating host
      verify(() => mockDb.updateHostActivity(aliceHostId, any())).called(1);
    });

    test('updates non-originator missing entry to received', () async {
      // This is the key bug fix: if we had (bob:3) marked as missing,
      // and we receive an entry with VC {alice:5, bob:3} where alice
      // is the originator, the (bob:3) should be updated to received.
      const vectorClock = VectorClock({aliceHostId: 5, bobHostId: 3});
      const entryId = 'entry-modified';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 4);
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => null);
      // Bob:3 was previously marked as missing
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 3)).thenAnswer(
        (_) async =>
            createLogItem(bobHostId, 3, status: SyncSequenceStatus.missing),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      // Find bob's record
      final bobRecord =
          captured.firstWhere(
                (c) =>
                    (c as SyncSequenceLogCompanion).hostId.value == bobHostId,
              )
              as SyncSequenceLogCompanion;

      // Bob's missing entry should now be received with the entryId
      expect(bobRecord.status.value, SyncSequenceStatus.received.index);
      expect(bobRecord.entryId.value, entryId);
    });

    test('updates non-originator requested entry to backfilled', () async {
      // If we had (bob:3) marked as requested (we asked for backfill),
      // and we receive an entry with VC {alice:5, bob:3}, the (bob:3)
      // should be updated to backfilled (our request was fulfilled).
      const vectorClock = VectorClock({aliceHostId: 5, bobHostId: 3});
      const entryId = 'entry-modified';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 4);
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => null);
      // Bob:3 was previously marked as requested
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 3)).thenAnswer(
        (_) async =>
            createLogItem(bobHostId, 3, status: SyncSequenceStatus.requested),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      // Find bob's record
      final bobRecord =
          captured.firstWhere(
                (c) =>
                    (c as SyncSequenceLogCompanion).hostId.value == bobHostId,
              )
              as SyncSequenceLogCompanion;

      // Bob's requested entry should now be backfilled with the entryId
      expect(bobRecord.status.value, SyncSequenceStatus.backfilled.index);
      expect(bobRecord.entryId.value, entryId);

      // Verify non-originator backfill arrival was logged
      verify(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(that: contains('backfilled (non-originator)')),
          subDomain: 'sequence.backfillArrived',
        ),
      ).called(1);
    });

    test('does not downgrade non-originator backfilled entry', () async {
      // If (bob:3) is already backfilled, receiving another entry
      // with bob:3 in the VC should NOT downgrade it
      const vectorClock = VectorClock({aliceHostId: 5, bobHostId: 3});
      const entryId = 'entry-modified';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 4);
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => null);
      // Bob:3 was already backfilled
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 3)).thenAnswer(
        (_) async =>
            createLogItem(bobHostId, 3, status: SyncSequenceStatus.backfilled),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      // Find bob's record
      final bobRecord =
          captured.firstWhere(
                (c) =>
                    (c as SyncSequenceLogCompanion).hostId.value == bobHostId,
              )
              as SyncSequenceLogCompanion;

      // Bob's entry should stay backfilled (not downgraded to received)
      expect(bobRecord.status.value, SyncSequenceStatus.backfilled.index);
    });

    test('incremental large-gap extension spanning a chunk boundary only '
        'scans the unmaterialized sub-range, chunk by chunk', () async {
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 10);
      when(
        () => mockDb.getCountersForHostInRange(aliceHostId, any(), any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      // 1. First large gap 11..4999 materializes within a single chunk
      //    (chunk size 5000) and records the upper bound 4999.
      await service.recordReceivedEntry(
        entryId: 'e5000',
        vectorClock: const VectorClock({aliceHostId: 5000}),
        originatingHostId: aliceHostId,
      );
      verify(
        () => mockDb.getCountersForHostInRange(aliceHostId, 11, 4999),
      ).called(1);

      // 2. Counter 10001 extends the same gap. The incremental extension
      //    must start at previousBound+1 (5000) — not rescan 11..4999 —
      //    and must split the 5000..10000 range across the chunk
      //    boundary into two scans.
      final gaps = await service.recordReceivedEntry(
        entryId: 'e10001',
        vectorClock: const VectorClock({aliceHostId: 10001}),
        originatingHostId: aliceHostId,
      );

      verify(
        () => mockDb.getCountersForHostInRange(aliceHostId, 5000, 9999),
      ).called(1);
      verify(
        () => mockDb.getCountersForHostInRange(aliceHostId, 10000, 10000),
      ).called(1);
      // No other range scans — in particular no rescan below 5000.
      verifyNever(
        () => mockDb.getCountersForHostInRange(aliceHostId, any(), any()),
      );

      // The reported gap range covers only the newly materialized
      // sub-range 5000..10000.
      expect(gaps.length, 5001);
      expect(gaps.first, (hostId: aliceHostId, counter: 5000));
      expect(gaps.last, (hostId: aliceHostId, counter: 10000));
    });

    test('records the full large gap and logs it', () async {
      // Large gap: lastSeen=10, counter=500 should create entries for 11-499.
      const vectorClock = VectorClock({aliceHostId: 500});
      const entryId = 'entry-500';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 10);
      when(
        () => mockDb.getCountersForHostInRange(aliceHostId, 11, 499),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 500),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps.length, 489);
      expect(gaps.first.counter, 11);
      expect(gaps.last.counter, 499);
      verify(
        () => mockDb.getCountersForHostInRange(aliceHostId, 11, 499),
      ).called(1);

      final inserted =
          verify(
                () => mockDb.batchInsertSequenceEntries(captureAny()),
              ).captured.single
              as List<SyncSequenceLogCompanion>;
      expect(inserted.length, 500 - 10 - 1);
      expect(inserted.first.counter.value, 11);
      expect(inserted.last.counter.value, 499);

      // Verify large gap was logged
      verify(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(that: contains('largeGapDetected')),
          subDomain: 'sequence.largeGap',
        ),
      ).called(1);
    });

    test('chunks extreme gaps without truncating the logical result', () async {
      const lastSeen = 10;
      const chunkSize = SyncTuning.gapMaterializationChunkSize;
      const gapSize = SyncTuning.gapMaterializationChunkSize * 2 + 7;
      const observedCounter = lastSeen + gapSize + 1;
      const vectorClock = VectorClock({aliceHostId: observedCounter});
      const entryId = 'entry-extreme-gap';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => lastSeen);
      when(
        () => mockDb.getCountersForHostInRange(aliceHostId, any(), any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, observedCounter),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps.length, gapSize);
      expect(gaps.first.counter, lastSeen + 1);
      expect(gaps.last.counter, observedCounter - 1);
      verify(
        () => mockDb.getCountersForHostInRange(
          aliceHostId,
          lastSeen + 1,
          lastSeen + chunkSize,
        ),
      ).called(1);
      verify(
        () => mockDb.getCountersForHostInRange(
          aliceHostId,
          lastSeen + chunkSize + 1,
          lastSeen + chunkSize * 2,
        ),
      ).called(1);
      verify(
        () => mockDb.getCountersForHostInRange(
          aliceHostId,
          lastSeen + chunkSize * 2 + 1,
          observedCounter - 1,
        ),
      ).called(1);

      final inserted =
          verify(() => mockDb.batchInsertSequenceEntries(captureAny())).captured
              .map((value) => value as List<SyncSequenceLogCompanion>)
              .toList();
      expect(inserted, hasLength(3));
      expect(inserted[0], hasLength(SyncTuning.gapMaterializationChunkSize));
      expect(inserted[1], hasLength(SyncTuning.gapMaterializationChunkSize));
      expect(inserted[2], hasLength(7));

      verify(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(that: contains('extremeGapDetected')),
          subDomain: 'sequence.extremeGap',
        ),
      ).called(1);
    });

    test('invokes missing-work callback after detecting gaps', () async {
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-5';
      var nudgeCount = 0;
      service.onMissingEntriesDetected = () {
        nudgeCount++;
      };

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(nudgeCount, equals(1));
    });

    test('defers missing-work callback until deferred block exits', () async {
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-5';
      var nudges = 0;
      service.onMissingEntriesDetected = () {
        nudges++;
      };

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.runWithDeferredMissingEntries(() async {
        await service.recordReceivedEntry(
          entryId: entryId,
          vectorClock: vectorClock,
          originatingHostId: aliceHostId,
        );

        expect(nudges, 0);
      });

      expect(nudges, 1);
    });

    test('does not log largeGap when gap is within limits', () async {
      // Gap of 2 is well within maxGapSize
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-5';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      // Should NOT log largeGapDetected
      verifyNever(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(that: contains('largeGapDetected')),
          subDomain: 'sequence.largeGap',
        ),
      );
    });

    test('materializes only the incremental delta when the observed counter '
        'advances past a previously materialized range', () async {
      // Scenario: stuck watermark at 10, first entry observes alice at
      // (lastSeen + maxGapSize + 2) → whole range materializes, bound
      // recorded. Second entry is one counter higher — the short-circuit
      // must only materialize the single-counter delta, not re-scan the
      // previously materialized prefix.
      const lastSeen = 10;
      const observedCounter = lastSeen + SyncTuning.maxGapSize + 2;
      const vc1 = VectorClock({aliceHostId: observedCounter});
      const vc2 = VectorClock({aliceHostId: observedCounter + 1});

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => lastSeen);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: 'entry-first',
        vectorClock: vc1,
        originatingHostId: aliceHostId,
      );

      clearInteractions(mockDb);
      clearInteractions(mockLogging);
      // Re-stub after clearInteractions.
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => lastSeen);
      when(
        () => mockDb.updateHostActivity(any(), any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mockDb.getHostLastSeen(aliceHostId),
      ).thenAnswer((_) async => DateTime(2025, 1, 1));
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);
      when(
        () => mockDb.getPendingEntriesByPayloadId(
          payloadType: any(named: 'payloadType'),
          payloadId: any(named: 'payloadId'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockLogging.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      await service.recordReceivedEntry(
        entryId: 'entry-second',
        vectorClock: vc2,
        originatingHostId: aliceHostId,
      );

      // The previously materialized prefix (lastSeen+1 .. observedCounter-1)
      // must not be re-scanned — only the single-counter delta
      // (observedCounter .. observedCounter) should hit the DB.
      verifyNever(
        () => mockDb.getCountersForHostInRange(
          aliceHostId,
          lastSeen + 1,
          any(that: lessThanOrEqualTo(observedCounter - 1)),
        ),
      );
      // Incremental extensions of a previously-materialized large gap
      // deliberately do NOT re-log `largeGapDetected`. Logging it once per
      // incoming event dominated desktop log volume on hosts with a
      // permanent pre-history gap without adding new signal.
      verifyNever(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(that: contains('largeGapDetected')),
          subDomain: 'sequence.largeGap',
        ),
      );
    });

    test(
      'suppresses log and DB work entirely when an identical gap is observed '
      'again from a later entry',
      () async {
        // Simulates the stuck-watermark hot path: lastSeen never moves, and
        // every incoming entry observes exactly the same counter value for
        // the gapped host. After the first materialization, subsequent
        // entries must produce zero DB reads for the gap range and zero
        // verbose gap logs.
        const lastSeen = 10;
        const observedCounter = lastSeen + SyncTuning.maxGapSize + 2;
        const vectorClock = VectorClock({aliceHostId: observedCounter});

        when(
          () => mockDb.getLastCounterForHost(aliceHostId),
        ).thenAnswer((_) async => lastSeen);
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        await service.recordReceivedEntry(
          entryId: 'entry-first',
          vectorClock: vectorClock,
          originatingHostId: aliceHostId,
        );

        clearInteractions(mockDb);
        clearInteractions(mockLogging);
        when(
          () => mockDb.getLastCounterForHost(aliceHostId),
        ).thenAnswer((_) async => lastSeen);
        when(
          () => mockDb.updateHostActivity(any(), any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockDb.getHostLastSeen(aliceHostId),
        ).thenAnswer((_) async => DateTime(2025, 1, 1));
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockDb.getPendingEntriesByPayloadId(
            payloadType: any(named: 'payloadType'),
            payloadId: any(named: 'payloadId'),
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockLogging.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenReturn(null);

        await service.recordReceivedEntry(
          entryId: 'entry-second',
          vectorClock: vectorClock,
          originatingHostId: aliceHostId,
        );

        verifyNever(
          () => mockDb.getCountersForHostInRange(any(), any(), any()),
        );
        verifyNever(() => mockDb.batchInsertSequenceEntries(any()));
        verifyNever(
          () => mockLogging.log(
            LogDomain.sync,
            any<String>(that: contains('largeGapDetected')),
            subDomain: 'sequence.largeGap',
          ),
        );
        verifyNever(
          () => mockLogging.log(
            LogDomain.sync,
            any<String>(that: contains('extremeGapDetected')),
            subDomain: 'sequence.extremeGap',
          ),
        );
        verifyNever(
          () => mockLogging.log(
            LogDomain.sync,
            any<String>(that: contains('gapDetectedRange')),
            subDomain: 'sequence.gapDetected',
          ),
        );

        // Critical: the short-circuit must NOT skip recording the originator
        // counter itself — otherwise the row for `(alice, observedCounter)`
        // never lands in the sequence log, the watermark cannot advance past
        // it, and the next incoming entry re-enters the same stuck state.
        final recorded = verify(() => mockDb.recordSequenceEntry(captureAny()))
            .captured
            .map((c) => c as SyncSequenceLogCompanion)
            .where((c) => c.entryId.value == 'entry-second')
            .toList();
        expect(
          recorded,
          isNotEmpty,
          reason:
              'originator counter must be upserted even when the '
              'materialization short-circuit fires',
        );
        expect(recorded.first.counter.value, observedCounter);
      },
    );

    test('materializes only the incremental range when the watermark is stuck '
        'but the observed counter advances', () async {
      const lastSeen = 10;
      const firstObserved = lastSeen + SyncTuning.maxGapSize + 2;
      const secondObserved = firstObserved + 5;
      const vc1 = VectorClock({aliceHostId: firstObserved});
      const vc2 = VectorClock({aliceHostId: secondObserved});

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => lastSeen);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: 'entry-first',
        vectorClock: vc1,
        originatingHostId: aliceHostId,
      );

      clearInteractions(mockDb);
      clearInteractions(mockLogging);
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => lastSeen);
      when(
        () => mockDb.updateHostActivity(any(), any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mockDb.getHostLastSeen(aliceHostId),
      ).thenAnswer((_) async => DateTime(2025, 1, 1));
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);
      when(
        () => mockDb.getPendingEntriesByPayloadId(
          payloadType: any(named: 'payloadType'),
          payloadId: any(named: 'payloadId'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockLogging.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      await service.recordReceivedEntry(
        entryId: 'entry-second',
        vectorClock: vc2,
        originatingHostId: aliceHostId,
      );

      // Must scan only the NEW range (firstObserved .. secondObserved - 1),
      // never rescan the earlier (lastSeen+1 .. firstObserved - 1) segment.
      verify(
        () => mockDb.getCountersForHostInRange(
          aliceHostId,
          firstObserved,
          secondObserved - 1,
        ),
      ).called(1);
      verifyNever(
        () => mockDb.getCountersForHostInRange(
          aliceHostId,
          lastSeen + 1,
          any(that: lessThan(firstObserved)),
        ),
      );
    });
  });

  group('gap detection for offline hosts', () {
    test('skips gap detection for host that has never been online', () async {
      // Scenario: We receive an entry from alice with a VC containing charlie's
      // counter. Charlie has never sent us a message directly (never been
      // "online"), so we should NOT detect gaps for charlie.
      const charlieHostId = 'charlie-host-uuid';
      const vectorClock = VectorClock({aliceHostId: 5, charlieHostId: 10});
      const entryId = 'entry-alice';

      // Alice is online (has been seen before)
      when(
        () => mockDb.getHostLastSeen(aliceHostId),
      ).thenAnswer((_) async => DateTime(2025, 1, 1));
      // Charlie has NEVER been online (never sent us a message)
      when(
        () => mockDb.getHostLastSeen(charlieHostId),
      ).thenAnswer((_) async => null);

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 4); // No gap for alice
      when(() => mockDb.getLastCounterForHost(charlieHostId)).thenAnswer(
        (_) async => 5,
      ); // Would be a gap (5 -> 10) if we detected it
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getEntryByHostAndCounter(charlieHostId, 10),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      // Should NOT detect any gaps - charlie is offline so we skip gap detection
      expect(gaps, isEmpty);

      // Should log that we skipped gap detection for charlie
      verify(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(that: contains('skipGapDetection')),
          subDomain: 'sequence.skipGap',
        ),
      ).called(1);

      // Should NOT check for missing entries for charlie (counters 6-9)
      verifyNever(() => mockDb.getEntryByHostAndCounter(charlieHostId, 6));
      verifyNever(() => mockDb.getEntryByHostAndCounter(charlieHostId, 7));
      verifyNever(() => mockDb.getEntryByHostAndCounter(charlieHostId, 8));
      verifyNever(() => mockDb.getEntryByHostAndCounter(charlieHostId, 9));
    });

    test(
      'detects gaps for originating host even if not previously online',
      () async {
        // Edge case: The originating host might not have been in our hostActivity
        // table yet (first message from them). But since they just sent us a
        // message, we update their activity BEFORE gap detection, so they're
        // "online" now.
        const newHostId = 'new-host-uuid';
        const vectorClock = VectorClock({newHostId: 10});
        const entryId = 'entry-new';

        // New host - first time we've seen them, but they ARE the originator
        // The implementation updates host activity BEFORE gap detection
        when(
          () => mockDb.getHostLastSeen(newHostId),
        ).thenAnswer((_) async => null);

        when(
          () => mockDb.getLastCounterForHost(newHostId),
        ).thenAnswer((_) async => 5); // Gap: 6, 7, 8, 9
        when(
          () => mockDb.getEntryByHostAndCounter(newHostId, any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        final gaps = await service.recordReceivedEntry(
          entryId: entryId,
          vectorClock: vectorClock,
          originatingHostId: newHostId,
        );

        // SHOULD detect gaps for the originating host even though they weren't
        // previously in our hostActivity (they're online NOW - they just sent us
        // a message)
        expect(gaps.length, 4);
        expect(gaps.map((g) => g.counter).toList(), [6, 7, 8, 9]);
      },
    );

    test('detects gaps for known online hosts in multi-host VC', () async {
      // Scenario: Both alice and bob are known online hosts. We should detect
      // gaps for both of them.
      const vectorClock = VectorClock({aliceHostId: 10, bobHostId: 8});
      const entryId = 'entry-alice';

      // Both hosts are online
      when(
        () => mockDb.getHostLastSeen(aliceHostId),
      ).thenAnswer((_) async => DateTime(2025, 1, 1));
      when(
        () => mockDb.getHostLastSeen(bobHostId),
      ).thenAnswer((_) async => DateTime(2025, 1, 1));

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 7); // Gap: 8, 9
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 5); // Gap: 6, 7
      when(
        () => mockDb.getEntryByHostAndCounter(any(), any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      // Should detect gaps for BOTH hosts
      expect(gaps.length, 4);
      final aliceGaps = gaps.where((g) => g.hostId == aliceHostId).toList();
      final bobGaps = gaps.where((g) => g.hostId == bobHostId).toList();
      expect(aliceGaps.length, 2);
      expect(bobGaps.length, 2);
    });

    test(
      'mixed online/offline hosts in VC - only detect gaps for online',
      () async {
        // Scenario: VC contains alice (online), bob (online), and charlie
        // (offline). Should only detect gaps for alice and bob.
        const charlieHostId = 'charlie-host-uuid';
        const vectorClock = VectorClock({
          aliceHostId: 10,
          bobHostId: 8,
          charlieHostId: 15,
        });
        const entryId = 'entry-alice';

        // Alice and bob are online, charlie is not
        when(
          () => mockDb.getHostLastSeen(aliceHostId),
        ).thenAnswer((_) async => DateTime(2025, 1, 1));
        when(
          () => mockDb.getHostLastSeen(bobHostId),
        ).thenAnswer((_) async => DateTime(2025, 1, 1));
        when(
          () => mockDb.getHostLastSeen(charlieHostId),
        ).thenAnswer((_) async => null);

        when(
          () => mockDb.getLastCounterForHost(aliceHostId),
        ).thenAnswer((_) async => 8); // Gap: 9
        when(
          () => mockDb.getLastCounterForHost(bobHostId),
        ).thenAnswer((_) async => 6); // Gap: 7
        when(
          () => mockDb.getLastCounterForHost(charlieHostId),
        ).thenAnswer((_) async => 10); // Would be gap: 11-14 if online
        when(
          () => mockDb.getEntryByHostAndCounter(any(), any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        final gaps = await service.recordReceivedEntry(
          entryId: entryId,
          vectorClock: vectorClock,
          originatingHostId: aliceHostId,
        );

        // Should only detect gaps for alice and bob, NOT charlie
        expect(gaps.length, 2);
        final hostIds = gaps.map((g) => g.hostId).toSet();
        expect(hostIds, containsAll([aliceHostId, bobHostId]));
        expect(hostIds, isNot(contains(charlieHostId)));

        // Should log skipGapDetection for charlie
        verify(
          () => mockLogging.log(
            LogDomain.sync,
            any<String>(that: contains('skipGapDetection')),
            subDomain: 'sequence.skipGap',
          ),
        ).called(1);
      },
    );

    test(
      'still records sequence entries for offline hosts (no gap detection)',
      () async {
        // Even though we skip gap detection for offline hosts, we should still
        // record the sequence entry for their counter (to enable backfill
        // responses later).
        const charlieHostId = 'charlie-host-uuid';
        const vectorClock = VectorClock({aliceHostId: 5, charlieHostId: 10});
        const entryId = 'entry-alice';

        when(
          () => mockDb.getHostLastSeen(aliceHostId),
        ).thenAnswer((_) async => DateTime(2025, 1, 1));
        when(
          () => mockDb.getHostLastSeen(charlieHostId),
        ).thenAnswer((_) async => null);

        when(
          () => mockDb.getLastCounterForHost(aliceHostId),
        ).thenAnswer((_) async => 4);
        when(
          () => mockDb.getLastCounterForHost(charlieHostId),
        ).thenAnswer((_) async => 5); // Would be gap if online
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.getEntryByHostAndCounter(charlieHostId, 10),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        await service.recordReceivedEntry(
          entryId: entryId,
          vectorClock: vectorClock,
          originatingHostId: aliceHostId,
        );

        final captured = verify(
          () => mockDb.recordSequenceEntry(captureAny()),
        ).captured;

        // Should have 2 records: alice:5 and charlie:10 (but no missing entries
        // for charlie:6-9)
        expect(captured.length, 2);

        final hostIds = captured
            .map((c) => (c as SyncSequenceLogCompanion).hostId.value)
            .toSet();
        expect(hostIds, containsAll([aliceHostId, charlieHostId]));
      },
    );
  });

  group('recordReceivedEntry jsonPath', () {
    test(
      'persists jsonPath on both the originator and a covered foreign-host row',
      () async {
        const vectorClock = VectorClock({aliceHostId: 3, bobHostId: 6});
        const entryId = 'entry-with-json';
        const jsonPath = '/json/alice-3.json';

        when(
          () => mockDb.getLastCounterForHost(aliceHostId),
        ).thenAnswer((_) async => 2);
        when(
          () => mockDb.getLastCounterForHost(bobHostId),
        ).thenAnswer((_) async => 5);
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, 3),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.getEntryByHostAndCounter(bobHostId, 6),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        await service.recordReceivedEntry(
          entryId: entryId,
          vectorClock: vectorClock,
          originatingHostId: aliceHostId,
          jsonPath: jsonPath,
        );

        final captured = verify(
          () => mockDb.recordSequenceEntry(captureAny()),
        ).captured.map((c) => c as SyncSequenceLogCompanion).toList();

        final aliceRecord = captured.firstWhere(
          (c) => c.hostId.value == aliceHostId,
        );
        final bobRecord = captured.firstWhere(
          (c) => c.hostId.value == bobHostId,
        );
        // Both the originator (line carrying jsonPath) and the non-originator
        // foreign-host upsert must persist the supplied jsonPath.
        expect(aliceRecord.jsonPath.value, jsonPath);
        expect(bobRecord.jsonPath.value, jsonPath);
      },
    );

    test('leaves jsonPath absent when none is supplied', () async {
      const vectorClock = VectorClock({aliceHostId: 1});
      const entryId = 'entry-no-json';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 1),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      final companion =
          verify(() => mockDb.recordSequenceEntry(captureAny())).captured.single
              as SyncSequenceLogCompanion;
      // The const Value.absent() branch must be taken: no jsonPath present.
      expect(companion.jsonPath.present, isFalse);
    });
  });

  group('gap result list is read-only', () {
    test('the returned gap view rejects length and index mutation with '
        'UnsupportedError', () async {
      const vectorClock = VectorClock({aliceHostId: 4});
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 1);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: 'entry-4',
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      // Sanity: the view exposes the real gaps (2 and 3) before we probe
      // its immutability.
      expect(gaps, [
        (hostId: aliceHostId, counter: 2),
        (hostId: aliceHostId, counter: 3),
      ]);
      expect(() => gaps.length = 0, throwsA(isA<UnsupportedError>()));
      expect(
        () => gaps[0] = (hostId: aliceHostId, counter: 99),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
