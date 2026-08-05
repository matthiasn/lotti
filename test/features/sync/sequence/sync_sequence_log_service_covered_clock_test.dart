// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
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

  group('coveredVectorClocks processing', () {
    test('marks covered counters as received', () async {
      // Scenario: Entry arrives with coveredVectorClocks containing VC5 and VC6
      // where counters 5 and 6 were previously marked as missing.
      const vectorClock = VectorClock({aliceHostId: 7});
      const entryId = 'entry-7';
      final coveredClocks = [
        const VectorClock({aliceHostId: 5}),
        const VectorClock({aliceHostId: 6}),
      ];

      // Setup: entry 5 and 6 are missing
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 6);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 7),
      ).thenAnswer((_) async => null);
      final missing5 = createLogItem(
        aliceHostId,
        5,
        status: SyncSequenceStatus.missing,
      );
      final missing6 = createLogItem(
        aliceHostId,
        6,
        status: SyncSequenceStatus.missing,
      );
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => missing5);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 6),
      ).thenAnswer((_) async => missing6);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
        coveredVectorClocks: coveredClocks,
      );

      // Verify the missing counters 5 and 6 were marked as received
      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      // Should have 3 records: entry 7, and covered counters 5, 6
      expect(captured.length, 3);

      final counter5Record =
          captured.firstWhere(
                (c) => (c as SyncSequenceLogCompanion).counter.value == 5,
              )
              as SyncSequenceLogCompanion;
      final counter6Record =
          captured.firstWhere(
                (c) => (c as SyncSequenceLogCompanion).counter.value == 6,
              )
              as SyncSequenceLogCompanion;

      expect(counter5Record.status.value, SyncSequenceStatus.received.index);
      expect(counter6Record.status.value, SyncSequenceStatus.received.index);
      expect(counter5Record.createdAt.present, isTrue);
      expect(counter5Record.createdAt.value, missing5.createdAt);
      expect(counter6Record.createdAt.present, isTrue);
      expect(counter6Record.createdAt.value, missing6.createdAt);
    });

    test('ignores covered vector clock matching current payload', () async {
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-5';
      final coveredClocks = [
        const VectorClock({aliceHostId: 5}),
      ];

      final insertedRecords = <SyncSequenceLogCompanion>[];

      when(() => mockDb.getLastCounterForHost(aliceHostId)).thenAnswer((
        _,
      ) async {
        var maxCounter = 2;
        for (final record in insertedRecords) {
          if (record.counter.value > maxCounter) {
            maxCounter = record.counter.value;
          }
        }
        return maxCounter;
      });
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
      ).thenAnswer((invocation) async {
        final counter = invocation.positionalArguments[1] as int;
        for (final record in insertedRecords) {
          if (record.counter.value == counter) {
            return createLogItem(
              aliceHostId,
              counter,
              status: SyncSequenceStatus.received,
            );
          }
        }
        return null;
      });
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((
        invocation,
      ) async {
        insertedRecords.add(
          invocation.positionalArguments[0] as SyncSequenceLogCompanion,
        );
        return 1;
      });
      when(() => mockDb.batchInsertSequenceEntries(any())).thenAnswer((
        invocation,
      ) async {
        insertedRecords.addAll(
          invocation.positionalArguments[0] as List<SyncSequenceLogCompanion>,
        );
      });

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
        coveredVectorClocks: coveredClocks,
      );

      final missingCounters = insertedRecords
          .where(
            (record) => record.status.value == SyncSequenceStatus.missing.index,
          )
          .map((record) => record.counter.value)
          .toSet();
      expect(missingCounters, containsAll([3, 4]));

      final counter5Records = insertedRecords.where(
        (record) => record.counter.value == 5,
      );
      expect(counter5Records, hasLength(1));
    });

    test('marks covered requested counters as received', () async {
      // Scenario: Entry arrives with coveredVectorClocks containing VC5
      // where counter 5 was previously marked as requested.
      const vectorClock = VectorClock({aliceHostId: 7});
      const entryId = 'entry-7';
      final coveredClocks = [
        const VectorClock({aliceHostId: 5}),
      ];

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 6);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 7),
      ).thenAnswer((_) async => null);
      final requested5 = createLogItem(
        aliceHostId,
        5,
        status: SyncSequenceStatus.requested,
      );
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => requested5);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
        coveredVectorClocks: coveredClocks,
      );

      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      final counter5Record =
          captured.firstWhere(
                (c) => (c as SyncSequenceLogCompanion).counter.value == 5,
              )
              as SyncSequenceLogCompanion;

      expect(counter5Record.status.value, SyncSequenceStatus.received.index);
      expect(counter5Record.createdAt.present, isTrue);
      expect(counter5Record.createdAt.value, requested5.createdAt);
    });

    test('does not downgrade backfilled status from covered clocks', () async {
      // Scenario: Entry arrives with coveredVectorClocks containing VC5
      // where counter 5 was already backfilled - should NOT be downgraded
      const vectorClock = VectorClock({aliceHostId: 7});
      const entryId = 'entry-7';
      final coveredClocks = [
        const VectorClock({aliceHostId: 5}),
      ];

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 6);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 7),
      ).thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.backfilled, // Already backfilled
        ),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
        coveredVectorClocks: coveredClocks,
      );

      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      // Should only record entry 7, not update counter 5 (already backfilled)
      expect(captured.length, 1);
      final record = captured[0] as SyncSequenceLogCompanion;
      expect(record.counter.value, 7);
    });

    test('does not modify received status from covered clocks', () async {
      // Scenario: Entry arrives with coveredVectorClocks containing VC5
      // where counter 5 was already received - should not be modified
      const vectorClock = VectorClock({aliceHostId: 7});
      const entryId = 'entry-7';
      final coveredClocks = [
        const VectorClock({aliceHostId: 5}),
      ];

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 6);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 7),
      ).thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.received, // Already received
        ),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
        coveredVectorClocks: coveredClocks,
      );

      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      // Should only record entry 7, not update counter 5
      expect(captured.length, 1);
      final record = captured[0] as SyncSequenceLogCompanion;
      expect(record.counter.value, 7);
    });

    test('inserts covered counters that do not exist in sequence log', () async {
      // Scenario: Entry arrives with coveredVectorClocks containing counters
      // from a DIFFERENT host (bob) that don't exist in our sequence log yet.
      // This tests the case where an entry was created and updated rapidly on
      // sender before being sent, resulting in superseded counters that we've
      // never seen. The fix ensures we INSERT them as received to pre-empt gap
      // detection from marking them as missing.
      //
      // Using bob's counters in covered VCs ensures gap detection for alice
      // doesn't create them first, allowing us to test the true "doesn't exist"
      // code path.
      const vectorClock = VectorClock({aliceHostId: 7, bobHostId: 10});
      const entryId = 'entry-7';
      final coveredClocks = [
        // Bob's counters 8 and 9 were superseded before sending
        const VectorClock({bobHostId: 8}),
        const VectorClock({bobHostId: 9}),
      ];

      // Setup for alice (the originator)
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 6); // No gap for alice
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 7),
      ).thenAnswer((_) async => null);

      // Setup for bob (another host in the VC)
      // Set lastSeen to 9 so there's no gap detection when we receive bob:10
      // This ensures bob:8 and bob:9 truly don't exist when covered VCs are processed
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 9); // No gap (10-9=1)
      when(
        () => mockDb.getEntryByHostAndCounter(bobHostId, 10),
      ).thenAnswer((_) async => null);
      // Bob's counters 8 and 9 do NOT exist yet - this is what we're testing
      // (they were superseded on bob before being sent, so we never saw them)
      when(
        () => mockDb.getEntryByHostAndCounter(bobHostId, 8),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getEntryByHostAndCounter(bobHostId, 9),
      ).thenAnswer((_) async => null);

      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
        coveredVectorClocks: coveredClocks,
      );

      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      // Should have 4 records:
      // - entry for alice:7 (originator)
      // - entry for bob:10 (other host in VC)
      // - INSERTED covered counter bob:8
      // - INSERTED covered counter bob:9
      expect(captured.length, 4);

      final bobCounter8Record =
          captured.firstWhere(
                (c) =>
                    (c as SyncSequenceLogCompanion).hostId.value == bobHostId &&
                    c.counter.value == 8,
              )
              as SyncSequenceLogCompanion;
      final bobCounter9Record =
          captured.firstWhere(
                (c) =>
                    (c as SyncSequenceLogCompanion).hostId.value == bobHostId &&
                    c.counter.value == 9,
              )
              as SyncSequenceLogCompanion;

      // Covered counters should be INSERTED as received (not updated)
      expect(bobCounter8Record.status.value, SyncSequenceStatus.received.index);
      expect(bobCounter8Record.hostId.value, bobHostId);
      expect(bobCounter8Record.entryId.value, entryId);
      expect(
        bobCounter8Record.createdAt.value,
        isNotNull,
      ); // New record has createdAt

      expect(bobCounter9Record.status.value, SyncSequenceStatus.received.index);
      expect(bobCounter9Record.hostId.value, bobHostId);
      expect(bobCounter9Record.entryId.value, entryId);
      expect(bobCounter9Record.createdAt.value, isNotNull);
    });

    test('skips own host in covered clocks', () async {
      // Covered clocks should skip our own host (myHostId)
      const vectorClock = VectorClock({aliceHostId: 7});
      const entryId = 'entry-7';
      final coveredClocks = [
        const VectorClock({aliceHostId: 5, myHostId: 10}), // Includes our host
      ];

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 6);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 7),
      ).thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async =>
            createLogItem(aliceHostId, 5, status: SyncSequenceStatus.missing),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
        coveredVectorClocks: coveredClocks,
      );

      // Should NOT try to look up myHostId:10
      verifyNever(() => mockDb.getEntryByHostAndCounter(myHostId, 10));
    });

    test('handles null coveredVectorClocks gracefully', () async {
      const vectorClock = VectorClock({aliceHostId: 7});
      const entryId = 'entry-7';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 6);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 7),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      // Should not throw when coveredVectorClocks is null
      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
        coveredVectorClocks: null,
      );

      // Should only record the entry itself
      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });

    test('handles empty coveredVectorClocks list gracefully', () async {
      const vectorClock = VectorClock({aliceHostId: 7});
      const entryId = 'entry-7';

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 6);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 7),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      // Should not throw when coveredVectorClocks is empty
      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
        coveredVectorClocks: [],
      );

      // Should only record the entry itself
      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });

    test('logs when marking covered counters', () async {
      const vectorClock = VectorClock({aliceHostId: 7});
      const entryId = 'entry-7';
      final coveredClocks = [
        const VectorClock({aliceHostId: 5}),
      ];

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 6);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 7),
      ).thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async =>
            createLogItem(aliceHostId, 5, status: SyncSequenceStatus.missing),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
        coveredVectorClocks: coveredClocks,
      );

      verify(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(that: contains('markCoveredCountersAsReceived')),
          subDomain: 'sequence.coveredClocks',
        ),
      ).called(1);
    });

    test('recordReceivedEntryLink passes coveredVectorClocks', () async {
      const vectorClock = VectorClock({aliceHostId: 7});
      const linkId = 'link-7';
      final coveredClocks = [
        const VectorClock({aliceHostId: 5}),
      ];

      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 6);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 7),
      ).thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async =>
            createLogItem(aliceHostId, 5, status: SyncSequenceStatus.missing),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntryLink(
        linkId: linkId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
        coveredVectorClocks: coveredClocks,
      );

      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      // Should have 2 records: link 7, and covered counter 5
      expect(captured.length, 2);

      final counter5Record =
          captured.firstWhere(
                (c) => (c as SyncSequenceLogCompanion).counter.value == 5,
              )
              as SyncSequenceLogCompanion;

      expect(counter5Record.status.value, SyncSequenceStatus.received.index);
      expect(
        counter5Record.payloadType.value,
        SyncSequencePayloadType.entryLink.index,
      );
    });

    test(
      'covered clocks processed BEFORE gap detection prevents false positives',
      () async {
        // This test verifies the fix for the race condition where gap detection
        // would mark covered counters as missing before they were processed.
        //
        // Scenario: Entry rapidly updated on sender (counters 10→12→15→20)
        // Only ONE message sent with counter 20 and coveredVectorClocks=[10, 12, 15]
        // Without the fix: gap detection sees lastSeen=5, marks 6-19 as missing
        // With the fix: covered clocks (10, 12, 15) are inserted first,
        //              then gap detection skips them (existing != null)
        const vectorClock = VectorClock({aliceHostId: 20});
        const entryId = 'rapidly-updated-entry';
        final coveredClocks = [
          const VectorClock({aliceHostId: 10}),
          const VectorClock({aliceHostId: 12}),
          const VectorClock({aliceHostId: 15}),
        ];

        // Setup: lastSeen is 5, so gap detection would normally mark 6-19 as missing
        when(
          () => mockDb.getLastCounterForHost(aliceHostId),
        ).thenAnswer((_) async => 5);

        // Track all recordSequenceEntry calls in order
        final insertedRecords = <SyncSequenceLogCompanion>[];

        // Mock getEntryByHostAndCounter to check if the counter was already inserted
        // in THIS test run (simulating the database state)
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
        ).thenAnswer((invocation) async {
          final counter = invocation.positionalArguments[1] as int;
          // Check if this counter was already inserted
          final existingRecord = insertedRecords.where(
            (r) => r.counter.value == counter,
          );
          if (existingRecord.isNotEmpty) {
            return createLogItem(
              aliceHostId,
              counter,
              status: SyncSequenceStatus.received,
            );
          }
          return null;
        });
        when(
          () => mockDb.getCountersForHostInRange(aliceHostId, any(), any()),
        ).thenAnswer((invocation) async {
          final start = invocation.positionalArguments[1] as int;
          final end = invocation.positionalArguments[2] as int;
          return insertedRecords
              .where(
                (record) =>
                    record.counter.value >= start &&
                    record.counter.value <= end,
              )
              .map((record) => record.counter.value)
              .toSet();
        });

        // When recordSequenceEntry is called, track the record
        when(() => mockDb.recordSequenceEntry(any())).thenAnswer((
          invocation,
        ) async {
          final companion =
              invocation.positionalArguments[0] as SyncSequenceLogCompanion;
          insertedRecords.add(companion);
          return 1;
        });
        when(() => mockDb.batchInsertSequenceEntries(any())).thenAnswer((
          invocation,
        ) async {
          insertedRecords.addAll(
            invocation.positionalArguments[0] as List<SyncSequenceLogCompanion>,
          );
        });

        await service.recordReceivedEntry(
          entryId: entryId,
          vectorClock: vectorClock,
          originatingHostId: aliceHostId,
          coveredVectorClocks: coveredClocks,
        );

        // Analyze the insertion order and statuses
        final missingCounters = <int>[];
        final receivedCounters = <int>[];

        for (final record in insertedRecords) {
          if (record.status.value == SyncSequenceStatus.missing.index) {
            missingCounters.add(record.counter.value);
          } else if (record.status.value == SyncSequenceStatus.received.index) {
            receivedCounters.add(record.counter.value);
          }
        }

        // KEY ASSERTION: The FIRST 3 records should be the covered counters (10, 12, 15)
        // because covered clocks are processed BEFORE gap detection
        expect(insertedRecords.length, greaterThanOrEqualTo(3));
        final firstThreeCounters = insertedRecords
            .take(3)
            .map((r) => r.counter.value)
            .toSet();
        expect(
          firstThreeCounters,
          containsAll([10, 12, 15]),
          reason:
              'Covered counters should be inserted FIRST before gap detection',
        );

        // Covered counters should be marked as received, not missing
        expect(
          receivedCounters,
          containsAll([10, 12, 15]),
          reason: 'Covered counters should be marked as received',
        );
        expect(
          missingCounters,
          isNot(contains(10)),
          reason: 'Counter 10 is covered, should not be marked as missing',
        );
        expect(
          missingCounters,
          isNot(contains(12)),
          reason: 'Counter 12 is covered, should not be marked as missing',
        );
        expect(
          missingCounters,
          isNot(contains(15)),
          reason: 'Counter 15 is covered, should not be marked as missing',
        );

        // Non-covered gaps should be marked as missing
        expect(
          missingCounters,
          containsAll([6, 7, 8, 9, 11, 13, 14, 16, 17, 18, 19]),
          reason: 'Non-covered gaps should be marked as missing',
        );
      },
    );
  });
}
