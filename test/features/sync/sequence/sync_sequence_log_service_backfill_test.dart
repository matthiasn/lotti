// ignore_for_file: avoid_redundant_argument_values

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
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

  group('handleBackfillResponse', () {
    test('marks entry as deleted when deleted=true', () async {
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 3),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.updateSequenceStatus(any(), any(), any()),
      ).thenAnswer((_) async => 1);

      await service.handleBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: true,
      );

      verify(
        () => mockDb.updateSequenceStatus(
          aliceHostId,
          3,
          SyncSequenceStatus.deleted,
        ),
      ).called(1);
    });

    test('records a burned row when unresolvable=true and no row exists yet — '
        'proactive burn broadcasts must land on peers that never materialized '
        '(hostId, counter)', () async {
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 3),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.handleBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        unresolvable: true,
      );

      verifyNever(() => mockDb.updateSequenceStatus(any(), any(), any()));
      verify(
        () => mockDb.recordSequenceEntry(
          any(
            that: isA<SyncSequenceLogCompanion>()
                .having((c) => c.hostId, 'hostId', const Value(aliceHostId))
                .having((c) => c.counter, 'counter', const Value(3))
                .having((c) => c.entryId, 'entryId', const Value<String?>(null))
                .having(
                  (c) => c.status,
                  'status',
                  Value(SyncSequenceStatus.burned.index),
                ),
          ),
        ),
      ).called(1);
    });

    test(
      'unresolvable upsert ignores rows with authoritative success state '
      "(received / backfilled / deleted) — the originator's hint must "
      'never downgrade a better outcome obtained through another route',
      () async {
        when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
          (_) async => createLogItem(
            aliceHostId,
            3,
            entryId: 'existing',
            status: SyncSequenceStatus.received,
          ),
        );

        await service.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
          unresolvable: true,
        );

        verifyNever(() => mockDb.recordSequenceEntry(any()));
        verifyNever(() => mockDb.updateSequenceStatus(any(), any(), any()));
      },
    );

    test('unresolvable upsert clears a stale entryId on an existing row — '
        'so a lingering covered-VC mapping does not let later verify/reset '
        'paths reopen the counter', () async {
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async => createLogItem(
          aliceHostId,
          3,
          entryId: 'stale-entity',
          status: SyncSequenceStatus.missing,
        ),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.handleBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        unresolvable: true,
      );

      verify(
        () => mockDb.recordSequenceEntry(
          any(
            that: isA<SyncSequenceLogCompanion>()
                .having((c) => c.entryId, 'entryId', const Value<String?>(null))
                .having(
                  (c) => c.status,
                  'status',
                  Value(SyncSequenceStatus.burned.index),
                ),
          ),
        ),
      ).called(1);
    });

    test(
      'stores entryId hint on missing entry but does not change status',
      () async {
        // Non-deleted responses now just store the hint (entryId) without
        // changing status. The actual backfill confirmation happens in
        // verifyAndMarkBackfilled after the entry is verified to exist locally.
        when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
          (_) async => createLogItem(
            aliceHostId,
            3,
            status: SyncSequenceStatus.missing,
          ),
        );
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        await service.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
          entryId: 'backfilled-entry',
        );

        // Should store the entryId hint but keep status as missing
        final captured = verify(
          () => mockDb.recordSequenceEntry(captureAny()),
        ).captured;
        expect(captured.length, 1);
        final companion = captured[0] as SyncSequenceLogCompanion;
        expect(companion.hostId.value, aliceHostId);
        expect(companion.counter.value, 3);
        expect(companion.entryId.value, 'backfilled-entry');
        // Status stays as missing - will be updated when entry is verified
        expect(companion.status.value, SyncSequenceStatus.missing.index);
      },
    );

    test('inserts new entry with hint as requested when not found', () async {
      // If the entry doesn't exist in our log, insert it with the hint
      // but as "requested" status until we verify we have the entry locally
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 3),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.handleBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        entryId: 'backfilled-entry',
      );

      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;
      expect(captured.length, 1);
      final companion = captured[0] as SyncSequenceLogCompanion;
      // Should be "requested" not "backfilled" until verified
      expect(companion.status.value, SyncSequenceStatus.requested.index);
      expect(companion.entryId.value, 'backfilled-entry');
    });

    test('does not overwrite already received entry', () async {
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async =>
            createLogItem(aliceHostId, 3, status: SyncSequenceStatus.received),
      );

      await service.handleBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        entryId: 'backfilled-entry',
      );

      // Should not update - already received
      verifyNever(() => mockDb.recordSequenceEntry(any()));
    });

    test('does not overwrite already backfilled entry', () async {
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async => createLogItem(
          aliceHostId,
          3,
          status: SyncSequenceStatus.backfilled,
        ),
      );

      await service.handleBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        entryId: 'other-entry',
      );

      // Should not update - already backfilled
      verifyNever(() => mockDb.recordSequenceEntry(any()));
    });

    test('does not overwrite deleted entry', () async {
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async =>
            createLogItem(aliceHostId, 3, status: SyncSequenceStatus.deleted),
      );

      await service.handleBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        entryId: 'backfilled-entry',
      );

      // Should not update - entry is deleted (cannot be restored)
      verifyNever(() => mockDb.recordSequenceEntry(any()));
    });

    test('reopens unresolvable entry when valid hint arrives', () async {
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async => createLogItem(
          aliceHostId,
          3,
          status: SyncSequenceStatus.unresolvable,
        ),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.handleBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        entryId: 'valid-hint-entry',
      );

      // Should reset status to requested so hint can be verified
      final captured =
          verify(() => mockDb.recordSequenceEntry(captureAny())).captured.single
              as SyncSequenceLogCompanion;
      expect(captured.status.value, SyncSequenceStatus.requested.index);
      expect(captured.entryId.value, 'valid-hint-entry');
    });

    test('unresolvable=true leaves an already-burned row untouched — burned is '
        'terminal, so re-applying it would only churn updated_at', () async {
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async =>
            createLogItem(aliceHostId, 3, status: SyncSequenceStatus.burned),
      );

      await service.handleBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        unresolvable: true,
      );

      verifyNever(() => mockDb.recordSequenceEntry(any()));
      verifyNever(() => mockDb.updateSequenceStatus(any(), any(), any()));
    });

    test('a later hint never reopens a burned row — unlike an unresolvable '
        'give-up, burned is the authoritative terminal non-event', () async {
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async =>
            createLogItem(aliceHostId, 3, status: SyncSequenceStatus.burned),
      );

      await service.handleBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        entryId: 'late-hint-entry',
      );

      verifyNever(() => mockDb.recordSequenceEntry(any()));
    });

    glados.Glados(
      AnySequenceGapScenario(glados.any).backfillResponseStateScenario,
      // The scenario space is a small finite enum product; 120 runs cover
      // it as well as 180 did at two-thirds the cost.
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'matches generated backfill response state and payload transitions',
      (scenario) async {
        final bench = RealSequenceLogTestBench.create(myHostId: myHostId);
        const counter = 3;

        try {
          if (scenario.hasExistingEntry) {
            await bench.database.recordSequenceEntry(
              SyncSequenceLogCompanion(
                hostId: const Value(aliceHostId),
                counter: const Value(counter),
                entryId: const Value(
                  BackfillResponseStateScenario.existingEntryId,
                ),
                payloadType: Value(scenario.existingPayloadType.index),
                status: Value(scenario.existingState.syncStatus.index),
                createdAt: Value(DateTime(2024, 3, 15, 10)),
                updatedAt: Value(DateTime(2024, 3, 15, 10)),
              ),
            );
          }

          await bench.service.handleBackfillResponse(
            hostId: aliceHostId,
            counter: counter,
            deleted: scenario.responseKind == BackfillResponseKind.deleted,
            unresolvable:
                scenario.responseKind == BackfillResponseKind.unresolvable,
            entryId: scenario.responseKind == BackfillResponseKind.hint
                ? BackfillResponseStateScenario.hintEntryId
                : null,
            payloadType: scenario.responsePayloadType,
          );

          final entry = await bench.database.getEntryByHostAndCounter(
            aliceHostId,
            counter,
          );
          final expectedStatus = scenario.expectedStatus;
          if (expectedStatus == null) {
            expect(entry, isNull);
          } else {
            expect(entry, isNotNull);
            expect(entry?.status, expectedStatus.index);
            expect(entry?.entryId, scenario.expectedEntryId);
            expect(entry?.payloadType, scenario.expectedPayloadType?.index);
          }
        } finally {
          await bench.close();
        }
      },
      tags: 'glados',
    );
  });

  group('verifyAndMarkBackfilled', () {
    test('marks entry as backfilled when VC covers the counter', () async {
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-to-verify';

      // Entry exists and is in requested status
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.requested,
        ),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final result = await service.verifyAndMarkBackfilled(
        hostId: aliceHostId,
        counter: 5,
        entryId: entryId,
        entryVectorClock: vectorClock,
      );

      expect(result, true);
      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;
      expect(captured.length, 1);
      final companion = captured[0] as SyncSequenceLogCompanion;
      expect(companion.status.value, SyncSequenceStatus.backfilled.index);
      expect(companion.entryId.value, entryId);
    });

    test('returns false when VC does not cover the counter', () async {
      const vectorClock = VectorClock({aliceHostId: 3}); // Counter 3, not 5
      const entryId = 'entry-to-verify';

      final result = await service.verifyAndMarkBackfilled(
        hostId: aliceHostId,
        counter: 5, // Asking for counter 5
        entryId: entryId,
        entryVectorClock: vectorClock,
      );

      expect(result, false);
      verifyNever(() => mockDb.recordSequenceEntry(any()));
    });

    test('returns false when host not in VC', () async {
      const vectorClock = VectorClock({bobHostId: 10}); // Only bob, no alice
      const entryId = 'entry-to-verify';

      final result = await service.verifyAndMarkBackfilled(
        hostId: aliceHostId,
        counter: 5,
        entryId: entryId,
        entryVectorClock: vectorClock,
      );

      expect(result, false);
      verifyNever(() => mockDb.recordSequenceEntry(any()));
    });

    test('returns false when entry does not exist', () async {
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-to-verify';

      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => null);

      final result = await service.verifyAndMarkBackfilled(
        hostId: aliceHostId,
        counter: 5,
        entryId: entryId,
        entryVectorClock: vectorClock,
      );

      expect(result, false);
      verifyNever(() => mockDb.recordSequenceEntry(any()));
    });

    test('returns false when entry already received', () async {
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-to-verify';

      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.received, // Already received
        ),
      );

      final result = await service.verifyAndMarkBackfilled(
        hostId: aliceHostId,
        counter: 5,
        entryId: entryId,
        entryVectorClock: vectorClock,
      );

      expect(result, false);
      verifyNever(() => mockDb.recordSequenceEntry(any()));
    });

    test('returns false when entry already backfilled', () async {
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-to-verify';

      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.backfilled, // Already backfilled
        ),
      );

      final result = await service.verifyAndMarkBackfilled(
        hostId: aliceHostId,
        counter: 5,
        entryId: entryId,
        entryVectorClock: vectorClock,
      );

      expect(result, false);
      verifyNever(() => mockDb.recordSequenceEntry(any()));
    });

    test('marks missing entry as backfilled', () async {
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-to-verify';

      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.missing, // Missing, not requested
        ),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final result = await service.verifyAndMarkBackfilled(
        hostId: aliceHostId,
        counter: 5,
        entryId: entryId,
        entryVectorClock: vectorClock,
      );

      expect(result, true);
      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });
  });

  group('resolvePendingHints', () {
    test('resolves pending entries when entry arrives', () async {
      const vectorClock = VectorClock({aliceHostId: 5, bobHostId: 3});
      const entryId = 'arrived-entry';

      // Two pending entries that can be resolved by this entry
      final pendingEntries = [
        createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.requested,
          entryId: entryId,
        ),
        createLogItem(
          bobHostId,
          3,
          status: SyncSequenceStatus.requested,
          entryId: entryId,
        ),
      ];

      when(
        () => mockDb.getPendingEntriesByPayloadId(
          payloadType: SyncSequencePayloadType.journalEntity,
          payloadId: entryId,
        ),
      ).thenAnswer((_) async => pendingEntries);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => pendingEntries[0]);
      when(
        () => mockDb.getEntryByHostAndCounter(bobHostId, 3),
      ).thenAnswer((_) async => pendingEntries[1]);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final resolved = await service.resolvePendingHints(
        payloadType: SyncSequencePayloadType.journalEntity,
        payloadId: entryId,
        payloadVectorClock: vectorClock,
      );

      expect(resolved, 2);
      verify(() => mockDb.recordSequenceEntry(any())).called(2);
    });

    test('returns zero when no pending entries', () async {
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'arrived-entry';

      when(
        () => mockDb.getPendingEntriesByPayloadId(
          payloadType: SyncSequencePayloadType.journalEntity,
          payloadId: entryId,
        ),
      ).thenAnswer((_) async => []);

      final resolved = await service.resolvePendingHints(
        payloadType: SyncSequencePayloadType.journalEntity,
        payloadId: entryId,
        payloadVectorClock: vectorClock,
      );

      expect(resolved, 0);
      verifyNever(() => mockDb.recordSequenceEntry(any()));
    });

    test('only resolves entries covered by VC', () async {
      const vectorClock = VectorClock({aliceHostId: 5}); // Only alice:5
      const entryId = 'arrived-entry';

      // Two pending entries, but only one is covered by VC
      final pendingEntries = [
        createLogItem(
          aliceHostId,
          5, // Covered
          status: SyncSequenceStatus.requested,
          entryId: entryId,
        ),
        createLogItem(
          bobHostId,
          10, // Not covered (bob not in VC)
          status: SyncSequenceStatus.requested,
          entryId: entryId,
        ),
      ];

      when(
        () => mockDb.getPendingEntriesByPayloadId(
          payloadType: SyncSequencePayloadType.journalEntity,
          payloadId: entryId,
        ),
      ).thenAnswer((_) async => pendingEntries);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => pendingEntries[0]);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final resolved = await service.resolvePendingHints(
        payloadType: SyncSequencePayloadType.journalEntity,
        payloadId: entryId,
        payloadVectorClock: vectorClock,
      );

      // Only alice:5 should be resolved
      expect(resolved, 1);
      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });
  });

  group('resetUnresolvableEntries', () {
    test('delegates to syncDatabase and returns count', () async {
      when(
        () => mockDb.resetUnresolvableWithKnownPayload(),
      ).thenAnswer((_) async => 42);

      final count = await service.resetUnresolvableEntries();

      expect(count, 42);
      verify(() => mockDb.resetUnresolvableWithKnownPayload()).called(1);
    });

    test('logs when entries are reset', () async {
      when(
        () => mockDb.resetUnresolvableWithKnownPayload(),
      ).thenAnswer((_) async => 5);

      await service.resetUnresolvableEntries();

      verify(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(that: contains('reset 5 entries')),
          subDomain: 'sequence.resetUnresolvable',
        ),
      ).called(1);
    });

    test('does not log when no entries reset', () async {
      when(
        () => mockDb.resetUnresolvableWithKnownPayload(),
      ).thenAnswer((_) async => 0);

      await service.resetUnresolvableEntries();

      verifyNever(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(),
          subDomain: 'sequence.resetUnresolvable',
        ),
      );
    });
  });

  group('resetAllUnresolvableEntries', () {
    test(
      'delegates to syncDatabase and logs under sequence.resetAllUnresolvable '
      'when entries were reset — distinct subDomain from the known-payload '
      'variant so logs can tell the two paths apart',
      () async {
        when(
          () => mockDb.resetAllUnresolvableEntries(),
        ).thenAnswer((_) async => 13);
        when(
          () => mockLogging.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenReturn(null);

        final count = await service.resetAllUnresolvableEntries();

        expect(count, 13);
        verify(() => mockDb.resetAllUnresolvableEntries()).called(1);
        verify(
          () => mockLogging.log(
            LogDomain.sync,
            any<String>(that: contains('reset 13 entries')),
            subDomain: 'sequence.resetAllUnresolvable',
          ),
        ).called(1);
      },
    );

    test('does not log when no entries reset', () async {
      when(
        () => mockDb.resetAllUnresolvableEntries(),
      ).thenAnswer((_) async => 0);

      await service.resetAllUnresolvableEntries();

      verifyNever(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(),
          subDomain: 'sequence.resetAllUnresolvable',
        ),
      );
    });
  });

  group('retireExhaustedRequestedEntries', () {
    test('delegates to syncDatabase with maxRequestCount and grace and returns '
        'count', () async {
      const grace = Duration(seconds: 30);
      when(
        () => mockDb.retireExhaustedRequestedEntries(
          maxRequestCount: 7,
          grace: grace,
        ),
      ).thenAnswer((_) async => 3);

      final count = await service.retireExhaustedRequestedEntries(
        maxRequestCount: 7,
        grace: grace,
      );

      expect(count, 3);
      verify(
        () => mockDb.retireExhaustedRequestedEntries(
          maxRequestCount: 7,
          grace: grace,
        ),
      ).called(1);
    });

    test(
      'logs and clears the materialized-bound cache when entries are retired '
      'so a stuck gap can be rescanned once the retirement advances the '
      'watermark',
      () async {
        // Prime the materialized-bound cache by running a large-gap
        // materialization. Unlike `_lastCounterCache` (invalidated on every
        // `recordSequenceEntry`), `_materializedUpperBound` only clears on
        // TTL expiry or retirement — so a repeat-scan assertion against it
        // actually proves retirement did the clearing work.
        const lastSeen = 10;
        const observedCounter = lastSeen + SyncTuning.maxGapSize + 2;
        const primingVc = VectorClock({aliceHostId: observedCounter});
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
          entryId: 'priming-entry',
          vectorClock: primingVc,
          originatingHostId: aliceHostId,
        );

        // Sanity check: a second identical-counter record hits the cached
        // bound and does NOT rescan the range.
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
          entryId: 'pre-retire-check',
          vectorClock: primingVc,
          originatingHostId: aliceHostId,
        );
        verifyNever(
          () => mockDb.getCountersForHostInRange(any(), any(), any()),
        );

        // Retire: this must clear the materialized-bound cache.
        clearInteractions(mockDb);
        clearInteractions(mockLogging);
        when(
          () => mockDb.retireExhaustedRequestedEntries(
            maxRequestCount: any(named: 'maxRequestCount'),
            grace: any(named: 'grace'),
          ),
        ).thenAnswer((_) async => 12);
        when(
          () => mockLogging.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenReturn(null);

        final count = await service.retireExhaustedRequestedEntries();

        expect(count, 12);
        verify(
          () => mockLogging.log(
            LogDomain.sync,
            any<String>(that: contains('retired 12 entries')),
            subDomain: 'sequence.retireExhausted',
          ),
        ).called(1);

        // After retirement, the same identical-counter scenario must now
        // rescan the range — the bound was cleared. This is the assertion
        // that can ONLY pass if retirement actually invalidated
        // `_materializedUpperBound`, since `_lastCounterCache` is already
        // invalidated by any concurrent `recordSequenceEntry` path.
        clearInteractions(mockDb);
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
          () => mockDb.getCountersForHostInRange(any(), any(), any()),
        ).thenAnswer((_) async => <int>{});
        when(
          () => mockDb.batchInsertSequenceEntries(any()),
        ).thenAnswer((_) async {});

        await service.recordReceivedEntry(
          entryId: 'post-retire',
          vectorClock: primingVc,
          originatingHostId: aliceHostId,
        );
        verify(
          () => mockDb.getCountersForHostInRange(aliceHostId, any(), any()),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    test('does not log when no entries retired', () async {
      when(
        () => mockDb.retireExhaustedRequestedEntries(
          maxRequestCount: any(named: 'maxRequestCount'),
          grace: any(named: 'grace'),
        ),
      ).thenAnswer((_) async => 0);

      await service.retireExhaustedRequestedEntries();

      verifyNever(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(),
          subDomain: 'sequence.retireExhausted',
        ),
      );
    });
  });

  group('retireAgedOutRequestedEntries', () {
    test(
      'delegates to syncDatabase with amnestyWindow and returns count',
      () async {
        const window = Duration(days: 7);
        when(
          () => mockDb.retireAgedOutRequestedEntries(amnestyWindow: window),
        ).thenAnswer((_) async => 4);

        final count = await service.retireAgedOutRequestedEntries(
          amnestyWindow: window,
        );

        expect(count, 4);
        verify(
          () => mockDb.retireAgedOutRequestedEntries(amnestyWindow: window),
        ).called(1);
      },
    );

    test(
      'logs under sequence.retireAgedOut when entries are retired — '
      'distinguishes age-based retirement from exhaustion-based in logs',
      () async {
        when(
          () => mockDb.retireAgedOutRequestedEntries(
            amnestyWindow: any(named: 'amnestyWindow'),
          ),
        ).thenAnswer((_) async => 9);
        when(
          () => mockLogging.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenReturn(null);

        await service.retireAgedOutRequestedEntries();

        verify(
          () => mockLogging.log(
            LogDomain.sync,
            any<String>(that: contains('retired 9 entries')),
            subDomain: 'sequence.retireAgedOut',
          ),
        ).called(1);
      },
    );

    test('does not log when no entries retired', () async {
      when(
        () => mockDb.retireAgedOutRequestedEntries(
          amnestyWindow: any(named: 'amnestyWindow'),
        ),
      ).thenAnswer((_) async => 0);

      await service.retireAgedOutRequestedEntries();

      verifyNever(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(),
          subDomain: 'sequence.retireAgedOut',
        ),
      );
    });
  });
}
