// ignore_for_file: avoid_redundant_argument_values

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncDatabase extends Mock implements SyncDatabase {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSyncDatabase mockDb;
  late MockVectorClockService mockVcService;
  late MockLoggingService mockLogging;
  late SyncSequenceLogService service;

  const myHostId = 'my-host-uuid';
  const aliceHostId = 'alice-host-uuid';
  const bobHostId = 'bob-host-uuid';

  setUpAll(() {
    registerFallbackValue(
      SyncSequenceLogCompanion(
        hostId: const Value(''),
        counter: const Value(0),
        status: const Value(0),
        createdAt: Value(DateTime(2024)),
        updatedAt: Value(DateTime(2024)),
      ),
    );
    registerFallbackValue(SyncSequenceStatus.received);
    registerFallbackValue(SyncSequencePayloadType.journalEntity);
  });

  setUp(() {
    mockDb = MockSyncDatabase();
    mockVcService = MockVectorClockService();
    mockLogging = MockLoggingService();

    when(() => mockVcService.getHost()).thenAnswer((_) async => myHostId);
    when(
      () => mockLogging.captureEvent(
        any<String>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    // Stub updateHostActivity for all tests
    when(() => mockDb.updateHostActivity(any(), any()))
        .thenAnswer((_) async => 1);

    // Stub getHostLastSeen for all tests - by default alice and bob are "online"
    // (have been seen before). Tests for offline hosts will override this.
    when(() => mockDb.getHostLastSeen(aliceHostId))
        .thenAnswer((_) async => DateTime(2025, 1, 1));
    when(() => mockDb.getHostLastSeen(bobHostId))
        .thenAnswer((_) async => DateTime(2025, 1, 1));

    // Stub getPendingEntriesByPayloadId for resolvePendingHints (default: no pending)
    when(
      () => mockDb.getPendingEntriesByPayloadId(
        payloadType: any(named: 'payloadType'),
        payloadId: any(named: 'payloadId'),
      ),
    ).thenAnswer((_) async => []);

    service = SyncSequenceLogService(
      syncDatabase: mockDb,
      vectorClockService: mockVcService,
      loggingService: mockLogging,
    );
  });

  group('recordReceivedEntry', () {
    test('records entry without gaps when sequential', () async {
      // Alice counter 1, first entry we've seen from Alice
      const vectorClock = VectorClock({aliceHostId: 1});
      const entryId = 'entry-1';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 1))
          .thenAnswer((_) async => null);
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

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 2);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 4))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps.length, 2);
      expect(gaps[0], (hostId: aliceHostId, counter: 3));
      expect(gaps[1], (hostId: aliceHostId, counter: 4));

      // Should record: missing 3, missing 4, received 5
      verify(() => mockDb.recordSequenceEntry(any())).called(3);
    });

    test('skips own host in vector clock', () async {
      // VC includes our own host - should be skipped
      const vectorClock = VectorClock({myHostId: 10, aliceHostId: 5});
      const entryId = 'entry-x';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 4);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => null);
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

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 4);
      when(() => mockDb.getLastCounterForHost(bobHostId))
          .thenAnswer((_) async => 6);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 7))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 8))
          .thenAnswer((_) async => null);
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

      // Should record: alice:5 with entryId, bob:7 as missing, bob:8 as observed
      verify(() => mockDb.recordSequenceEntry(any())).called(3);
    });

    test('ALL hosts in VC get entryId (enables backfill responses)', () async {
      // Multi-host VC: ALL hosts get the entryId so we can respond to
      // backfill requests for any (host, counter) in the entry's VC
      const vectorClock = VectorClock({aliceHostId: 5, bobHostId: 3});
      const entryId = 'entry-alice';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 4);
      when(() => mockDb.getLastCounterForHost(bobHostId))
          .thenAnswer((_) async => 2);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 3))
          .thenAnswer((_) async => null);
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

      final aliceRecord = captured.firstWhere(
        (c) => (c as SyncSequenceLogCompanion).hostId.value == aliceHostId,
      ) as SyncSequenceLogCompanion;
      final bobRecord = captured.firstWhere(
        (c) => (c as SyncSequenceLogCompanion).hostId.value == bobHostId,
      ) as SyncSequenceLogCompanion;

      // Both hosts should have the entryId set
      expect(aliceRecord.entryId.value, entryId);
      expect(bobRecord.entryId.value, entryId);
    });

    test('does not duplicate missing entries', () async {
      // Alice counter 3 was already marked missing, counter 5 arrives
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-5';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 2);
      // Counter 3 already exists as missing
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3))
          .thenAnswer((_) async => _createLogItem(aliceHostId, 3));
      // Counter 4 doesn't exist
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 4))
          .thenAnswer((_) async => null);
      // Counter 5 doesn't exist
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      // Should still report gaps but not insert duplicate
      expect(gaps.length, 2);
      // Only 2 records: missing 4 and received 5 (3 already exists)
      verify(() => mockDb.recordSequenceEntry(any())).called(2);
    });

    test('marks previously missing entry as received', () async {
      // Entry was marked missing before, now it arrives via normal sync
      // (not via backfill request). Missing entries become received.
      const vectorClock = VectorClock({aliceHostId: 3});
      const entryId = 'entry-3';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 2);
      // Entry 3 exists and is missing
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3))
          .thenAnswer((_) async => _createLogItem(aliceHostId, 3));
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

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 2);
      // Entry 3 exists and is requested
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async => _createLogItem(
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
        () => mockLogging.captureEvent(
          any<String>(that: contains('backfilled hostId=$aliceHostId')),
          domain: 'SYNC_SEQUENCE',
          subDomain: 'backfillArrived',
        ),
      ).called(1);
    });

    test('does not downgrade backfilled entry to received', () async {
      // Entry was already backfilled, receiving it again should NOT change status
      const vectorClock = VectorClock({aliceHostId: 3});
      const entryId = 'entry-3';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 2);
      // Entry 3 exists and is already backfilled
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async => _createLogItem(
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

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 1))
          .thenAnswer((_) async => null);
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

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 4);
      when(() => mockDb.getLastCounterForHost(bobHostId))
          .thenAnswer((_) async => 2);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => null);
      // Bob:3 was previously marked as missing
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 3)).thenAnswer(
        (_) async => _createLogItem(
          bobHostId,
          3,
          status: SyncSequenceStatus.missing,
        ),
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
      final bobRecord = captured.firstWhere(
        (c) => (c as SyncSequenceLogCompanion).hostId.value == bobHostId,
      ) as SyncSequenceLogCompanion;

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

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 4);
      when(() => mockDb.getLastCounterForHost(bobHostId))
          .thenAnswer((_) async => 2);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => null);
      // Bob:3 was previously marked as requested
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 3)).thenAnswer(
        (_) async => _createLogItem(
          bobHostId,
          3,
          status: SyncSequenceStatus.requested,
        ),
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
      final bobRecord = captured.firstWhere(
        (c) => (c as SyncSequenceLogCompanion).hostId.value == bobHostId,
      ) as SyncSequenceLogCompanion;

      // Bob's requested entry should now be backfilled with the entryId
      expect(bobRecord.status.value, SyncSequenceStatus.backfilled.index);
      expect(bobRecord.entryId.value, entryId);

      // Verify non-originator backfill arrival was logged
      verify(
        () => mockLogging.captureEvent(
          any<String>(that: contains('backfilled (non-originator)')),
          domain: 'SYNC_SEQUENCE',
          subDomain: 'backfillArrived',
        ),
      ).called(1);
    });

    test('does not downgrade non-originator backfilled entry', () async {
      // If (bob:3) is already backfilled, receiving another entry
      // with bob:3 in the VC should NOT downgrade it
      const vectorClock = VectorClock({aliceHostId: 5, bobHostId: 3});
      const entryId = 'entry-modified';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 4);
      when(() => mockDb.getLastCounterForHost(bobHostId))
          .thenAnswer((_) async => 2);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => null);
      // Bob:3 was already backfilled
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 3)).thenAnswer(
        (_) async => _createLogItem(
          bobHostId,
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

      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      // Find bob's record
      final bobRecord = captured.firstWhere(
        (c) => (c as SyncSequenceLogCompanion).hostId.value == bobHostId,
      ) as SyncSequenceLogCompanion;

      // Bob's entry should stay backfilled (not downgraded to received)
      expect(bobRecord.status.value, SyncSequenceStatus.backfilled.index);
    });

    test('limits gap detection to maxGapSize entries', () async {
      // Large gap: lastSeen=10, counter=500 would normally create 489 missing entries
      // With maxGapSize=100, should only create entries for counters 400-499
      const vectorClock = VectorClock({aliceHostId: 500});
      const entryId = 'entry-500';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 10);
      // Stub all potential getEntryByHostAndCounter calls to return null
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, any()))
          .thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      // Should detect gaps but limited to maxGapSize (100)
      expect(gaps.length, SyncTuning.maxGapSize);
      // Gaps should be for the most recent counters (400-499)
      expect(gaps.first.counter, 500 - SyncTuning.maxGapSize);
      expect(gaps.last.counter, 499);

      // Verify large gap was logged
      verify(
        () => mockLogging.captureEvent(
          any<String>(that: contains('largeGapDetected')),
          domain: 'SYNC_SEQUENCE',
          subDomain: 'largeGap',
        ),
      ).called(1);
    });

    test('does not log largeGap when gap is within limits', () async {
      // Gap of 2 is well within maxGapSize
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-5';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 2);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, any()))
          .thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      // Should NOT log largeGapDetected
      verifyNever(
        () => mockLogging.captureEvent(
          any<String>(that: contains('largeGapDetected')),
          domain: 'SYNC_SEQUENCE',
          subDomain: 'largeGap',
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
      when(() => mockDb.getHostLastSeen(aliceHostId))
          .thenAnswer((_) async => DateTime(2025, 1, 1));
      // Charlie has NEVER been online (never sent us a message)
      when(() => mockDb.getHostLastSeen(charlieHostId))
          .thenAnswer((_) async => null);

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 4); // No gap for alice
      when(() => mockDb.getLastCounterForHost(charlieHostId)).thenAnswer(
          (_) async => 5); // Would be a gap (5 -> 10) if we detected it
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(charlieHostId, 10))
          .thenAnswer((_) async => null);
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
        () => mockLogging.captureEvent(
          any<String>(that: contains('skipGapDetection')),
          domain: 'SYNC_SEQUENCE',
          subDomain: 'skipGap',
        ),
      ).called(1);

      // Should NOT check for missing entries for charlie (counters 6-9)
      verifyNever(() => mockDb.getEntryByHostAndCounter(charlieHostId, 6));
      verifyNever(() => mockDb.getEntryByHostAndCounter(charlieHostId, 7));
      verifyNever(() => mockDb.getEntryByHostAndCounter(charlieHostId, 8));
      verifyNever(() => mockDb.getEntryByHostAndCounter(charlieHostId, 9));
    });

    test('detects gaps for originating host even if not previously online',
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
      when(() => mockDb.getHostLastSeen(newHostId))
          .thenAnswer((_) async => null);

      when(() => mockDb.getLastCounterForHost(newHostId))
          .thenAnswer((_) async => 5); // Gap: 6, 7, 8, 9
      when(() => mockDb.getEntryByHostAndCounter(newHostId, any()))
          .thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

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
    });

    test('detects gaps for known online hosts in multi-host VC', () async {
      // Scenario: Both alice and bob are known online hosts. We should detect
      // gaps for both of them.
      const vectorClock = VectorClock({aliceHostId: 10, bobHostId: 8});
      const entryId = 'entry-alice';

      // Both hosts are online
      when(() => mockDb.getHostLastSeen(aliceHostId))
          .thenAnswer((_) async => DateTime(2025, 1, 1));
      when(() => mockDb.getHostLastSeen(bobHostId))
          .thenAnswer((_) async => DateTime(2025, 1, 1));

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 7); // Gap: 8, 9
      when(() => mockDb.getLastCounterForHost(bobHostId))
          .thenAnswer((_) async => 5); // Gap: 6, 7
      when(() => mockDb.getEntryByHostAndCounter(any(), any()))
          .thenAnswer((_) async => null);
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

    test('mixed online/offline hosts in VC - only detect gaps for online',
        () async {
      // Scenario: VC contains alice (online), bob (online), and charlie
      // (offline). Should only detect gaps for alice and bob.
      const charlieHostId = 'charlie-host-uuid';
      const vectorClock =
          VectorClock({aliceHostId: 10, bobHostId: 8, charlieHostId: 15});
      const entryId = 'entry-alice';

      // Alice and bob are online, charlie is not
      when(() => mockDb.getHostLastSeen(aliceHostId))
          .thenAnswer((_) async => DateTime(2025, 1, 1));
      when(() => mockDb.getHostLastSeen(bobHostId))
          .thenAnswer((_) async => DateTime(2025, 1, 1));
      when(() => mockDb.getHostLastSeen(charlieHostId))
          .thenAnswer((_) async => null);

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 8); // Gap: 9
      when(() => mockDb.getLastCounterForHost(bobHostId))
          .thenAnswer((_) async => 6); // Gap: 7
      when(() => mockDb.getLastCounterForHost(charlieHostId))
          .thenAnswer((_) async => 10); // Would be gap: 11-14 if online
      when(() => mockDb.getEntryByHostAndCounter(any(), any()))
          .thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

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
        () => mockLogging.captureEvent(
          any<String>(that: contains('skipGapDetection')),
          domain: 'SYNC_SEQUENCE',
          subDomain: 'skipGap',
        ),
      ).called(1);
    });

    test('still records sequence entries for offline hosts (no gap detection)',
        () async {
      // Even though we skip gap detection for offline hosts, we should still
      // record the sequence entry for their counter (to enable backfill
      // responses later).
      const charlieHostId = 'charlie-host-uuid';
      const vectorClock = VectorClock({aliceHostId: 5, charlieHostId: 10});
      const entryId = 'entry-alice';

      when(() => mockDb.getHostLastSeen(aliceHostId))
          .thenAnswer((_) async => DateTime(2025, 1, 1));
      when(() => mockDb.getHostLastSeen(charlieHostId))
          .thenAnswer((_) async => null);

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 4);
      when(() => mockDb.getLastCounterForHost(charlieHostId))
          .thenAnswer((_) async => 5); // Would be gap if online
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(charlieHostId, 10))
          .thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

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
    });
  });

  group('recordSentEntry', () {
    test('records sent entry for own host', () async {
      const vectorClock = VectorClock({myHostId: 10});
      const entryId = 'my-entry';

      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordSentEntry(
        entryId: entryId,
        vectorClock: vectorClock,
      );

      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });

    test('ignores other hosts in sent entry', () async {
      // When sending, we only care about our own counter
      const vectorClock = VectorClock({myHostId: 5, aliceHostId: 10});
      const entryId = 'my-entry';

      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordSentEntry(
        entryId: entryId,
        vectorClock: vectorClock,
      );

      // Should only record our own host
      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });
  });

  group('handleBackfillResponse', () {
    test('marks entry as deleted when deleted=true', () async {
      when(
        () => mockDb.updateSequenceStatus(
          any(),
          any(),
          any(),
        ),
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

    test('marks entry as unresolvable when unresolvable=true', () async {
      when(
        () => mockDb.updateSequenceStatus(
          any(),
          any(),
          any(),
        ),
      ).thenAnswer((_) async => 1);

      await service.handleBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        unresolvable: true,
      );

      verify(
        () => mockDb.updateSequenceStatus(
          aliceHostId,
          3,
          SyncSequenceStatus.unresolvable,
        ),
      ).called(1);
    });

    test('stores entryId hint on missing entry but does not change status',
        () async {
      // Non-deleted responses now just store the hint (entryId) without
      // changing status. The actual backfill confirmation happens in
      // verifyAndMarkBackfilled after the entry is verified to exist locally.
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async => _createLogItem(
          aliceHostId,
          3,
          status: SyncSequenceStatus.missing,
        ),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

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
    });

    test('inserts new entry with hint as requested when not found', () async {
      // If the entry doesn't exist in our log, insert it with the hint
      // but as "requested" status until we verify we have the entry locally
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3))
          .thenAnswer((_) async => null);
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
        (_) async => _createLogItem(
          aliceHostId,
          3,
          status: SyncSequenceStatus.received,
        ),
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
        (_) async => _createLogItem(
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
        (_) async => _createLogItem(
          aliceHostId,
          3,
          status: SyncSequenceStatus.deleted,
        ),
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
  });

  group('markAsReceived', () {
    test('updates missing entry to backfilled', () async {
      final existingMissing = _createLogItem(
        aliceHostId,
        3,
      );

      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3))
          .thenAnswer((_) async => existingMissing);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.markAsReceived(
        hostId: aliceHostId,
        counter: 3,
        entryId: 'arrived-entry',
      );

      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });

    test('does nothing for already received entry', () async {
      final existingReceived = _createLogItem(
        aliceHostId,
        3,
        status: SyncSequenceStatus.received,
      );

      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3))
          .thenAnswer((_) async => existingReceived);

      await service.markAsReceived(
        hostId: aliceHostId,
        counter: 3,
        entryId: 'arrived-entry',
      );

      verifyNever(() => mockDb.recordSequenceEntry(any()));
    });

    test('does nothing when entry does not exist', () async {
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 99))
          .thenAnswer((_) async => null);

      await service.markAsReceived(
        hostId: aliceHostId,
        counter: 99,
        entryId: 'new-entry',
      );

      verifyNever(() => mockDb.recordSequenceEntry(any()));
    });

    test('updates requested entry to backfilled', () async {
      final existingRequested = _createLogItem(
        aliceHostId,
        5,
        status: SyncSequenceStatus.requested,
      );

      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => existingRequested);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.markAsReceived(
        hostId: aliceHostId,
        counter: 5,
        entryId: 'arrived-entry',
      );

      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });
  });

  group('markAsRequested', () {
    test('delegates to batchIncrementRequestCounts', () async {
      final entries = [
        (hostId: aliceHostId, counter: 1),
        (hostId: aliceHostId, counter: 2),
        (hostId: bobHostId, counter: 1),
      ];
      when(() => mockDb.batchIncrementRequestCounts(any()))
          .thenAnswer((_) async {});

      await service.markAsRequested(entries);

      verify(() => mockDb.batchIncrementRequestCounts(entries)).called(1);
    });

    test('handles empty list', () async {
      when(() => mockDb.batchIncrementRequestCounts(any()))
          .thenAnswer((_) async {});

      await service.markAsRequested([]);

      verify(() => mockDb.batchIncrementRequestCounts([])).called(1);
    });
  });

  group('getMissingEntriesForActiveHosts', () {
    test('delegates to database with default parameters', () async {
      when(
        () => mockDb.getMissingEntriesForActiveHosts(
          limit: any(named: 'limit'),
          maxRequestCount: any(named: 'maxRequestCount'),
        ),
      ).thenAnswer((_) async => []);

      await service.getMissingEntriesForActiveHosts();

      verify(
        () => mockDb.getMissingEntriesForActiveHosts(
          limit: 50,
          maxRequestCount: 10,
        ),
      ).called(1);
    });

    test('passes custom parameters', () async {
      when(
        () => mockDb.getMissingEntriesForActiveHosts(
          limit: any(named: 'limit'),
          maxRequestCount: any(named: 'maxRequestCount'),
        ),
      ).thenAnswer((_) async => []);

      await service.getMissingEntriesForActiveHosts(
        limit: 20,
        maxRequestCount: 5,
      );

      verify(
        () => mockDb.getMissingEntriesForActiveHosts(
          limit: 20,
          maxRequestCount: 5,
        ),
      ).called(1);
    });
  });

  group('getMissingEntries', () {
    test('delegates to database with default parameters', () async {
      when(
        () => mockDb.getMissingEntries(
          limit: any(named: 'limit'),
          maxRequestCount: any(named: 'maxRequestCount'),
        ),
      ).thenAnswer((_) async => []);

      await service.getMissingEntries();

      verify(
        () => mockDb.getMissingEntries(
          limit: 50,
          maxRequestCount: 10,
        ),
      ).called(1);
    });

    test('passes custom parameters', () async {
      when(
        () => mockDb.getMissingEntries(
          limit: any(named: 'limit'),
          maxRequestCount: any(named: 'maxRequestCount'),
        ),
      ).thenAnswer((_) async => []);

      await service.getMissingEntries(limit: 25, maxRequestCount: 8);

      verify(
        () => mockDb.getMissingEntries(
          limit: 25,
          maxRequestCount: 8,
        ),
      ).called(1);
    });
  });

  group('getEntryByHostAndCounter', () {
    test('delegates to database and returns result', () async {
      final item = _createLogItem(aliceHostId, 5);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => item);

      final result = await service.getEntryByHostAndCounter(aliceHostId, 5);

      expect(result, item);
      verify(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).called(1);
    });

    test('returns null when entry does not exist', () async {
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 99))
          .thenAnswer((_) async => null);

      final result = await service.getEntryByHostAndCounter(aliceHostId, 99);

      expect(result, isNull);
    });
  });

  group('watchMissingCount', () {
    test('delegates to database stream', () async {
      when(() => mockDb.watchMissingCount())
          .thenAnswer((_) => Stream.value(42));

      final count = await service.watchMissingCount().first;

      expect(count, 42);
      verify(() => mockDb.watchMissingCount()).called(1);
    });
  });

  group('populateFromJournal', () {
    test('populates sequence log for ALL hosts in vector clock', () async {
      when(() => mockDb.getCountersForHost(any()))
          .thenAnswer((_) async => <int>{});
      when(() => mockDb.batchInsertSequenceEntries(any()))
          .thenAnswer((_) async {});

      final entries = [
        // Entry with 2 hosts in VC = 2 sequence log entries
        (id: 'entry-1', vectorClock: {myHostId: 10, aliceHostId: 5}),
        // Entry with 1 host = 1 sequence log entry
        (id: 'entry-2', vectorClock: {myHostId: 20}),
      ];

      final count = await service.populateFromJournal(
        entryStream: Stream.value(entries),
        getTotalCount: () async => 2,
      );

      // 2 entries from entry-1 + 1 entry from entry-2 = 3 total
      expect(count, 3);
      verify(() => mockDb.batchInsertSequenceEntries(any())).called(1);
    });

    test('skips entries that already exist in log', () async {
      when(() => mockDb.getCountersForHost(myHostId))
          .thenAnswer((_) async => {10}); // Counter 10 already exists
      when(() => mockDb.getCountersForHost(aliceHostId))
          .thenAnswer((_) async => <int>{});
      when(() => mockDb.batchInsertSequenceEntries(any()))
          .thenAnswer((_) async {});

      final entries = [
        (id: 'entry-1', vectorClock: {myHostId: 10, aliceHostId: 5}),
      ];

      final count = await service.populateFromJournal(
        entryStream: Stream.value(entries),
        getTotalCount: () async => 1,
      );

      // myHostId:10 exists, but aliceHostId:5 doesn't = 1 new entry
      expect(count, 1);
      verify(() => mockDb.batchInsertSequenceEntries(any())).called(1);
    });

    test('skips entries with null or empty vectorClock', () async {
      when(() => mockDb.getCountersForHost(any()))
          .thenAnswer((_) async => <int>{});

      final entries = [
        (id: 'entry-1', vectorClock: <String, int>{}), // Empty
        (id: 'entry-2', vectorClock: null), // Null
      ];

      final count = await service.populateFromJournal(
        entryStream: Stream.value(entries),
        getTotalCount: () async => 2,
      );

      expect(count, 0);
      verifyNever(() => mockDb.batchInsertSequenceEntries(any()));
    });

    test('works even when host is not set', () async {
      // populateFromJournal no longer requires myHost
      when(() => mockDb.getCountersForHost(any()))
          .thenAnswer((_) async => <int>{});
      when(() => mockDb.batchInsertSequenceEntries(any()))
          .thenAnswer((_) async {});

      final entries = [
        (id: 'entry-1', vectorClock: {aliceHostId: 5}),
      ];

      final count = await service.populateFromJournal(
        entryStream: Stream.value(entries),
        getTotalCount: () async => 1,
      );

      expect(count, 1);
    });

    test('reports progress after each batch', () async {
      when(() => mockDb.getCountersForHost(any()))
          .thenAnswer((_) async => <int>{});
      when(() => mockDb.batchInsertSequenceEntries(any()))
          .thenAnswer((_) async {});

      final batch1 = [
        (id: 'entry-1', vectorClock: {myHostId: 10}),
        (id: 'entry-2', vectorClock: {myHostId: 20}),
      ];
      final batch2 = [
        (id: 'entry-3', vectorClock: {myHostId: 30}),
      ];

      final progressValues = <double>[];

      await service.populateFromJournal(
        entryStream: Stream.fromIterable([batch1, batch2]),
        getTotalCount: () async => 3,
        onProgress: progressValues.add,
      );

      expect(progressValues.length, 2);
      expect(progressValues[0], closeTo(2 / 3, 0.01));
      expect(progressValues[1], closeTo(1.0, 0.01));
    });
  });

  group('getBackfillStats', () {
    test('delegates to database', () async {
      final mockStats = BackfillStats.fromHostStats([
        const BackfillHostStats(
          hostId: aliceHostId,
          receivedCount: 10,
          missingCount: 2,
          requestedCount: 1,
          backfilledCount: 3,
          deletedCount: 0,
          unresolvableCount: 0,
          latestCounter: 15,
        ),
      ]);

      when(() => mockDb.getBackfillStats()).thenAnswer((_) async => mockStats);

      final result = await service.getBackfillStats();

      expect(result, mockStats);
      verify(() => mockDb.getBackfillStats()).called(1);
    });
  });

  group('getRequestedEntries', () {
    test('delegates to database with default limit', () async {
      when(
        () => mockDb.getRequestedEntries(limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      await service.getRequestedEntries();

      verify(
        () => mockDb.getRequestedEntries(limit: 50),
      ).called(1);
    });

    test('passes custom limit', () async {
      when(
        () => mockDb.getRequestedEntries(limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);

      await service.getRequestedEntries(limit: 25);

      verify(
        () => mockDb.getRequestedEntries(limit: 25),
      ).called(1);
    });

    test('returns requested entries from database', () async {
      final entries = [
        _createLogItem(aliceHostId, 1, status: SyncSequenceStatus.requested),
        _createLogItem(aliceHostId, 2, status: SyncSequenceStatus.requested),
      ];

      when(
        () => mockDb.getRequestedEntries(limit: any(named: 'limit')),
      ).thenAnswer((_) async => entries);

      final result = await service.getRequestedEntries();

      expect(result, entries);
      expect(result.length, 2);
    });
  });

  group('resetRequestCounts', () {
    test('delegates to database', () async {
      when(() => mockDb.resetRequestCounts(any())).thenAnswer((_) async {});

      final entries = [
        (hostId: aliceHostId, counter: 1),
        (hostId: aliceHostId, counter: 2),
        (hostId: bobHostId, counter: 3),
      ];

      await service.resetRequestCounts(entries);

      verify(() => mockDb.resetRequestCounts(entries)).called(1);
    });

    test('handles empty list', () async {
      when(() => mockDb.resetRequestCounts(any())).thenAnswer((_) async {});

      await service.resetRequestCounts([]);

      verify(() => mockDb.resetRequestCounts([])).called(1);
    });

    test('logs the reset operation', () async {
      when(() => mockDb.resetRequestCounts(any())).thenAnswer((_) async {});

      final entries = [
        (hostId: aliceHostId, counter: 1),
        (hostId: aliceHostId, counter: 2),
      ];

      await service.resetRequestCounts(entries);

      verify(
        () => mockLogging.captureEvent(
          any<String>(that: contains('reset 2 entries')),
          domain: 'SYNC_SEQUENCE',
          subDomain: 'reRequest',
        ),
      ).called(1);
    });
  });

  group('verifyAndMarkBackfilled', () {
    test('marks entry as backfilled when VC covers the counter', () async {
      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-to-verify';

      // Entry exists and is in requested status
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => _createLogItem(
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

      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => null);

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
        (_) async => _createLogItem(
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
        (_) async => _createLogItem(
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
        (_) async => _createLogItem(
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
        _createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.requested,
          entryId: entryId,
        ),
        _createLogItem(
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
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => pendingEntries[0],
      );
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 3)).thenAnswer(
        (_) async => pendingEntries[1],
      );
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
        _createLogItem(
          aliceHostId,
          5, // Covered
          status: SyncSequenceStatus.requested,
          entryId: entryId,
        ),
        _createLogItem(
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
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => pendingEntries[0],
      );
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

  group('getMissingEntriesWithLimits', () {
    test('delegates to database with default parameters', () async {
      when(
        () => mockDb.getMissingEntriesWithLimits(
          limit: any(named: 'limit'),
          maxRequestCount: any(named: 'maxRequestCount'),
          maxAge: any(named: 'maxAge'),
          maxPerHost: any(named: 'maxPerHost'),
        ),
      ).thenAnswer((_) async => []);

      await service.getMissingEntriesWithLimits();

      verify(
        () => mockDb.getMissingEntriesWithLimits(
          limit: 50,
          maxRequestCount: 10,
          maxAge: null,
          maxPerHost: null,
        ),
      ).called(1);
    });

    test('passes custom parameters', () async {
      when(
        () => mockDb.getMissingEntriesWithLimits(
          limit: any(named: 'limit'),
          maxRequestCount: any(named: 'maxRequestCount'),
          maxAge: any(named: 'maxAge'),
          maxPerHost: any(named: 'maxPerHost'),
        ),
      ).thenAnswer((_) async => []);

      await service.getMissingEntriesWithLimits(
        limit: 25,
        maxRequestCount: 5,
        maxAge: const Duration(hours: 12),
        maxPerHost: 100,
      );

      verify(
        () => mockDb.getMissingEntriesWithLimits(
          limit: 25,
          maxRequestCount: 5,
          maxAge: const Duration(hours: 12),
          maxPerHost: 100,
        ),
      ).called(1);
    });

    test('returns missing entries', () async {
      final entries = [
        _createLogItem(aliceHostId, 1),
        _createLogItem(aliceHostId, 2),
      ];

      when(
        () => mockDb.getMissingEntriesWithLimits(
          limit: any(named: 'limit'),
          maxRequestCount: any(named: 'maxRequestCount'),
          maxAge: any(named: 'maxAge'),
          maxPerHost: any(named: 'maxPerHost'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await service.getMissingEntriesWithLimits();

      expect(result, entries);
      expect(result.length, 2);
    });
  });

  group('recordReceivedEntryLink', () {
    test('records entry link with correct payload type', () async {
      const vectorClock = VectorClock({aliceHostId: 1});
      const linkId = 'link-1';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 1))
          .thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntryLink(
        linkId: linkId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps, isEmpty);

      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      expect(captured.length, 1);
      final record = captured[0] as SyncSequenceLogCompanion;
      expect(record.entryId.value, linkId);
      expect(
        record.payloadType.value,
        SyncSequencePayloadType.entryLink.index,
      );
    });

    test('detects gaps when link counter jumps', () async {
      // Alice counter was 2, now we get link counter 5 - missing 3 and 4
      const vectorClock = VectorClock({aliceHostId: 5});
      const linkId = 'link-5';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 2);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 4))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntryLink(
        linkId: linkId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps.length, 2);
      expect(gaps[0], (hostId: aliceHostId, counter: 3));
      expect(gaps[1], (hostId: aliceHostId, counter: 4));

      // Should record: missing 3, missing 4, received link 5
      verify(() => mockDb.recordSequenceEntry(any())).called(3);
    });
  });

  group('EntryLink resolves ghost missing rows', () {
    test('receiving entry link resolves previously missing journal counter',
        () async {
      // Scenario: A journal entry created a gap at counter 3, but counter 3
      // was actually an entry link operation. When the link arrives, it should
      // resolve the "ghost missing" row.

      const vectorClock = VectorClock({aliceHostId: 3});
      const linkId = 'link-3';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 2);
      // Counter 3 already exists as missing (created by journal gap detection)
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3)).thenAnswer(
        (_) async => _createLogItem(
          aliceHostId,
          3,
          status: SyncSequenceStatus.missing,
        ),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntryLink(
        linkId: linkId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps, isEmpty);

      // The missing row should be updated to received with the link ID
      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      expect(captured.length, 1);
      final record = captured[0] as SyncSequenceLogCompanion;
      expect(record.entryId.value, linkId);
      expect(record.status.value, SyncSequenceStatus.received.index);
      expect(
        record.payloadType.value,
        SyncSequencePayloadType.entryLink.index,
      );
    });

    test('receiving journal entry resolves missing row created by link gap',
        () async {
      // Scenario: An entry link operation created a gap at counter 5, but
      // counter 5 was actually a journal entry. When the journal entry arrives,
      // it should resolve the "ghost missing" row.

      const vectorClock = VectorClock({aliceHostId: 5});
      const entryId = 'entry-5';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 4);
      // Counter 5 already exists as missing (created by link gap detection)
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => _createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.missing,
        ),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps, isEmpty);

      // The missing row should be updated to received with journal entry ID
      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;

      expect(captured.length, 1);
      final record = captured[0] as SyncSequenceLogCompanion;
      expect(record.entryId.value, entryId);
      expect(record.status.value, SyncSequenceStatus.received.index);
      expect(
        record.payloadType.value,
        SyncSequencePayloadType.journalEntity.index,
      );
    });
  });

  group('Interleaved link/journal operations', () {
    test('interleaved operations do not create permanent missing gaps',
        () async {
      // Scenario: Operations happen in order journal:1, link:2, journal:3
      // We receive them in order 1, 3, then 2 - no permanent gaps should remain

      // Step 1: Receive journal entry at counter 1
      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 1))
          .thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      var gaps = await service.recordReceivedEntry(
        entryId: 'journal-1',
        vectorClock: const VectorClock({aliceHostId: 1}),
        originatingHostId: aliceHostId,
      );
      expect(gaps, isEmpty);

      // Step 2: Receive journal entry at counter 3 (creates gap at 2)
      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 1);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 2))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 3))
          .thenAnswer((_) async => null);

      gaps = await service.recordReceivedEntry(
        entryId: 'journal-3',
        vectorClock: const VectorClock({aliceHostId: 3}),
        originatingHostId: aliceHostId,
      );
      expect(gaps.length, 1);
      expect(gaps[0], (hostId: aliceHostId, counter: 2));

      // Step 3: Receive entry link at counter 2 (resolves the gap)
      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 3);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 2)).thenAnswer(
        (_) async => _createLogItem(
          aliceHostId,
          2,
          status: SyncSequenceStatus.missing,
        ),
      );

      gaps = await service.recordReceivedEntryLink(
        linkId: 'link-2',
        vectorClock: const VectorClock({aliceHostId: 2}),
        originatingHostId: aliceHostId,
      );
      expect(gaps, isEmpty);

      // Verify the link was recorded with correct type
      final lastCaptured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured.last as SyncSequenceLogCompanion;
      expect(lastCaptured.entryId.value, 'link-2');
      expect(
        lastCaptured.payloadType.value,
        SyncSequencePayloadType.entryLink.index,
      );
      expect(lastCaptured.status.value, SyncSequenceStatus.received.index);
    });

    test('multi-host VC with mixed payload types tracks all counters',
        () async {
      // Scenario: Entry with VC {alice:5, bob:3} where alice's counter was
      // from a journal edit and bob's was from a link creation
      const vectorClock = VectorClock({aliceHostId: 5, bobHostId: 3});
      const entryId = 'journal-entry';

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 4);
      when(() => mockDb.getLastCounterForHost(bobHostId))
          .thenAnswer((_) async => 2);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 3))
          .thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final gaps = await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps, isEmpty);

      // Both hosts should be recorded with the same entryId
      final captured = verify(
        () => mockDb.recordSequenceEntry(captureAny()),
      ).captured;
      expect(captured.length, 2);

      for (final record in captured.cast<SyncSequenceLogCompanion>()) {
        expect(record.entryId.value, entryId);
        // Default payload type for recordReceivedEntry is journalEntity
        expect(
          record.payloadType.value,
          SyncSequencePayloadType.journalEntity.index,
        );
      }
    });
  });

  group('populateFromEntryLinks', () {
    test('populates sequence log from entry links stream', () async {
      final linkStream = Stream.fromIterable([
        [
          (id: 'link-1', vectorClock: <String, int>{aliceHostId: 1}),
          (id: 'link-2', vectorClock: <String, int>{aliceHostId: 2}),
        ],
      ]);

      when(() => mockDb.getCountersForHost(any()))
          .thenAnswer((_) async => <int>{});
      when(() => mockDb.batchInsertSequenceEntries(any()))
          .thenAnswer((_) async {});

      var progressCalled = false;
      final populated = await service.populateFromEntryLinks(
        linkStream: linkStream,
        getTotalCount: () async => 2,
        onProgress: (progress) {
          progressCalled = true;
        },
      );

      expect(populated, 2);
      expect(progressCalled, true);

      final captured = verify(
        () => mockDb.batchInsertSequenceEntries(captureAny()),
      ).captured;

      expect(captured.length, 1);
      final entries = captured[0] as List<SyncSequenceLogCompanion>;
      expect(entries.length, 2);

      // All entries should have entryLink payload type
      for (final entry in entries) {
        expect(
          entry.payloadType.value,
          SyncSequencePayloadType.entryLink.index,
        );
      }
    });

    test('skips existing counters', () async {
      final linkStream = Stream.fromIterable([
        [
          (id: 'link-1', vectorClock: <String, int>{aliceHostId: 1}),
          (id: 'link-2', vectorClock: <String, int>{aliceHostId: 2}),
        ],
      ]);

      // Counter 1 already exists
      when(() => mockDb.getCountersForHost(aliceHostId))
          .thenAnswer((_) async => {1});
      when(() => mockDb.batchInsertSequenceEntries(any()))
          .thenAnswer((_) async {});

      final populated = await service.populateFromEntryLinks(
        linkStream: linkStream,
        getTotalCount: () async => 2,
      );

      // Only counter 2 should be inserted
      expect(populated, 1);

      final captured = verify(
        () => mockDb.batchInsertSequenceEntries(captureAny()),
      ).captured;

      final entries = captured[0] as List<SyncSequenceLogCompanion>;
      expect(entries.length, 1);
      expect(entries[0].counter.value, 2);
    });

    test('handles multi-host vector clocks', () async {
      final linkStream = Stream.fromIterable([
        [
          (
            id: 'link-1',
            vectorClock: <String, int>{aliceHostId: 5, bobHostId: 3}
          ),
        ],
      ]);

      when(() => mockDb.getCountersForHost(any()))
          .thenAnswer((_) async => <int>{});
      when(() => mockDb.batchInsertSequenceEntries(any()))
          .thenAnswer((_) async {});

      final populated = await service.populateFromEntryLinks(
        linkStream: linkStream,
        getTotalCount: () async => 1,
      );

      // Should insert 2 entries (one for each host in the VC)
      expect(populated, 2);

      final captured = verify(
        () => mockDb.batchInsertSequenceEntries(captureAny()),
      ).captured;

      final entries = captured[0] as List<SyncSequenceLogCompanion>;
      expect(entries.length, 2);

      final aliceEntry = entries.firstWhere(
        (e) => e.hostId.value == aliceHostId,
      );
      final bobEntry = entries.firstWhere(
        (e) => e.hostId.value == bobHostId,
      );

      expect(aliceEntry.counter.value, 5);
      expect(bobEntry.counter.value, 3);
      expect(aliceEntry.entryId.value, 'link-1');
      expect(bobEntry.entryId.value, 'link-1');
    });

    test('returns zero when stream is empty', () async {
      const linkStream =
          Stream<List<({String id, Map<String, int>? vectorClock})>>.empty();

      final populated = await service.populateFromEntryLinks(
        linkStream: linkStream,
        getTotalCount: () async => 0,
      );

      expect(populated, 0);
      verifyNever(() => mockDb.batchInsertSequenceEntries(any()));
    });

    test('skips links with null vector clock', () async {
      final linkStream = Stream.fromIterable([
        [
          (id: 'link-1', vectorClock: null),
          (id: 'link-2', vectorClock: <String, int>{aliceHostId: 2}),
        ],
      ]);

      when(() => mockDb.getCountersForHost(any()))
          .thenAnswer((_) async => <int>{});
      when(() => mockDb.batchInsertSequenceEntries(any()))
          .thenAnswer((_) async {});

      final populated = await service.populateFromEntryLinks(
        linkStream: linkStream,
        getTotalCount: () async => 2,
      );

      // Only link-2 should be inserted
      expect(populated, 1);
    });
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
      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 6);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 7))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => _createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.missing,
        ),
      );
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 6)).thenAnswer(
        (_) async => _createLogItem(
          aliceHostId,
          6,
          status: SyncSequenceStatus.missing,
        ),
      );
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

      final counter5Record = captured.firstWhere(
        (c) => (c as SyncSequenceLogCompanion).counter.value == 5,
      ) as SyncSequenceLogCompanion;
      final counter6Record = captured.firstWhere(
        (c) => (c as SyncSequenceLogCompanion).counter.value == 6,
      ) as SyncSequenceLogCompanion;

      expect(counter5Record.status.value, SyncSequenceStatus.received.index);
      expect(counter6Record.status.value, SyncSequenceStatus.received.index);
    });

    test('marks covered requested counters as received', () async {
      // Scenario: Entry arrives with coveredVectorClocks containing VC5
      // where counter 5 was previously marked as requested.
      const vectorClock = VectorClock({aliceHostId: 7});
      const entryId = 'entry-7';
      final coveredClocks = [
        const VectorClock({aliceHostId: 5}),
      ];

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 6);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 7))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => _createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.requested,
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

      final counter5Record = captured.firstWhere(
        (c) => (c as SyncSequenceLogCompanion).counter.value == 5,
      ) as SyncSequenceLogCompanion;

      expect(counter5Record.status.value, SyncSequenceStatus.received.index);
    });

    test('does not downgrade backfilled status from covered clocks', () async {
      // Scenario: Entry arrives with coveredVectorClocks containing VC5
      // where counter 5 was already backfilled - should NOT be downgraded
      const vectorClock = VectorClock({aliceHostId: 7});
      const entryId = 'entry-7';
      final coveredClocks = [
        const VectorClock({aliceHostId: 5}),
      ];

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 6);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 7))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => _createLogItem(
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

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 6);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 7))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => _createLogItem(
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

    test('inserts covered counters that do not exist in sequence log',
        () async {
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
      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 6); // No gap for alice
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 7))
          .thenAnswer((_) async => null);

      // Setup for bob (another host in the VC)
      // Set lastSeen to 9 so there's no gap detection when we receive bob:10
      // This ensures bob:8 and bob:9 truly don't exist when covered VCs are processed
      when(() => mockDb.getLastCounterForHost(bobHostId))
          .thenAnswer((_) async => 9); // No gap (10-9=1)
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 10))
          .thenAnswer((_) async => null);
      // Bob's counters 8 and 9 do NOT exist yet - this is what we're testing
      // (they were superseded on bob before being sent, so we never saw them)
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 8))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(bobHostId, 9))
          .thenAnswer((_) async => null);

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

      final bobCounter8Record = captured.firstWhere(
        (c) =>
            (c as SyncSequenceLogCompanion).hostId.value == bobHostId &&
            c.counter.value == 8,
      ) as SyncSequenceLogCompanion;
      final bobCounter9Record = captured.firstWhere(
        (c) =>
            (c as SyncSequenceLogCompanion).hostId.value == bobHostId &&
            c.counter.value == 9,
      ) as SyncSequenceLogCompanion;

      // Covered counters should be INSERTED as received (not updated)
      expect(bobCounter8Record.status.value, SyncSequenceStatus.received.index);
      expect(bobCounter8Record.hostId.value, bobHostId);
      expect(bobCounter8Record.entryId.value, entryId);
      expect(bobCounter8Record.createdAt.value,
          isNotNull); // New record has createdAt

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

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 6);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 7))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => _createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.missing,
        ),
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

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 6);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 7))
          .thenAnswer((_) async => null);
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

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 6);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 7))
          .thenAnswer((_) async => null);
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

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 6);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 7))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => _createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.missing,
        ),
      );
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
        coveredVectorClocks: coveredClocks,
      );

      verify(
        () => mockLogging.captureEvent(
          any<String>(that: contains('markCoveredCountersAsReceived')),
          domain: 'SYNC_SEQUENCE',
          subDomain: 'coveredClocks',
        ),
      ).called(1);
    });

    test('recordReceivedEntryLink passes coveredVectorClocks', () async {
      const vectorClock = VectorClock({aliceHostId: 7});
      const linkId = 'link-7';
      final coveredClocks = [
        const VectorClock({aliceHostId: 5}),
      ];

      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 6);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 7))
          .thenAnswer((_) async => null);
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, 5)).thenAnswer(
        (_) async => _createLogItem(
          aliceHostId,
          5,
          status: SyncSequenceStatus.missing,
        ),
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

      final counter5Record = captured.firstWhere(
        (c) => (c as SyncSequenceLogCompanion).counter.value == 5,
      ) as SyncSequenceLogCompanion;

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
      when(() => mockDb.getLastCounterForHost(aliceHostId))
          .thenAnswer((_) async => 5);

      // Track all recordSequenceEntry calls in order
      final insertedRecords = <SyncSequenceLogCompanion>[];

      // Mock getEntryByHostAndCounter to check if the counter was already inserted
      // in THIS test run (simulating the database state)
      when(() => mockDb.getEntryByHostAndCounter(aliceHostId, any()))
          .thenAnswer((invocation) async {
        final counter = invocation.positionalArguments[1] as int;
        // Check if this counter was already inserted
        final existingRecord = insertedRecords.where(
          (r) => r.counter.value == counter,
        );
        if (existingRecord.isNotEmpty) {
          return _createLogItem(aliceHostId, counter,
              status: SyncSequenceStatus.received);
        }
        return null;
      });

      // When recordSequenceEntry is called, track the record
      when(() => mockDb.recordSequenceEntry(any()))
          .thenAnswer((invocation) async {
        final companion =
            invocation.positionalArguments[0] as SyncSequenceLogCompanion;
        insertedRecords.add(companion);
        return 1;
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
      final firstThreeCounters =
          insertedRecords.take(3).map((r) => r.counter.value).toSet();
      expect(firstThreeCounters, containsAll([10, 12, 15]),
          reason:
              'Covered counters should be inserted FIRST before gap detection');

      // Covered counters should be marked as received, not missing
      expect(receivedCounters, containsAll([10, 12, 15]),
          reason: 'Covered counters should be marked as received');
      expect(missingCounters, isNot(contains(10)),
          reason: 'Counter 10 is covered, should not be marked as missing');
      expect(missingCounters, isNot(contains(12)),
          reason: 'Counter 12 is covered, should not be marked as missing');
      expect(missingCounters, isNot(contains(15)),
          reason: 'Counter 15 is covered, should not be marked as missing');

      // Non-covered gaps should be marked as missing
      expect(missingCounters,
          containsAll([6, 7, 8, 9, 11, 13, 14, 16, 17, 18, 19]),
          reason: 'Non-covered gaps should be marked as missing');
    });
  });
}

SyncSequenceLogItem _createLogItem(
  String hostId,
  int counter, {
  SyncSequenceStatus status = SyncSequenceStatus.missing,
  String? entryId,
  String? originatingHostId,
}) {
  return SyncSequenceLogItem(
    hostId: hostId,
    counter: counter,
    entryId: entryId,
    payloadType: 0, // SyncSequencePayloadType.journalEntity.index
    originatingHostId: originatingHostId,
    status: status.index,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    requestCount: 0,
  );
}
