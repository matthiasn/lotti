// ignore_for_file: avoid_redundant_argument_values

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
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

    test('only originator gets entryId, others get null', () async {
      // Multi-host VC: only alice (originator) gets the entryId
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

      // Should have 2 records: alice with entryId, bob without
      expect(captured.length, 2);

      final aliceRecord = captured.firstWhere(
        (c) => (c as SyncSequenceLogCompanion).hostId.value == aliceHostId,
      ) as SyncSequenceLogCompanion;
      final bobRecord = captured.firstWhere(
        (c) => (c as SyncSequenceLogCompanion).hostId.value == bobHostId,
      ) as SyncSequenceLogCompanion;

      expect(aliceRecord.entryId.value, entryId);
      expect(bobRecord.entryId.present, isFalse);
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

    test('ignores non-deleted response (backwards compat)', () async {
      // Non-deleted responses are no longer sent - entries arrive via normal
      // sync and recordReceivedEntry handles the status update.
      await service.handleBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        entryId: 'backfilled-entry',
      );

      // Should not call any database methods
      verifyNever(() => mockDb.recordSequenceEntry(any()));
      verifyNever(() => mockDb.updateSequenceStatus(any(), any(), any()));
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
    test('increments request count for each entry', () async {
      when(() => mockDb.incrementRequestCount(any(), any()))
          .thenAnswer((_) async => 1);

      await service.markAsRequested([
        (hostId: aliceHostId, counter: 1),
        (hostId: aliceHostId, counter: 2),
        (hostId: bobHostId, counter: 1),
      ]);

      verify(() => mockDb.incrementRequestCount(aliceHostId, 1)).called(1);
      verify(() => mockDb.incrementRequestCount(aliceHostId, 2)).called(1);
      verify(() => mockDb.incrementRequestCount(bobHostId, 1)).called(1);
    });

    test('handles empty list', () async {
      await service.markAsRequested([]);

      verifyNever(() => mockDb.incrementRequestCount(any(), any()));
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
          latestCounter: 15,
        ),
      ]);

      when(() => mockDb.getBackfillStats()).thenAnswer((_) async => mockStats);

      final result = await service.getBackfillStats();

      expect(result, mockStats);
      verify(() => mockDb.getBackfillStats()).called(1);
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
    originatingHostId: originatingHostId,
    status: status.index,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    requestCount: 0,
  );
}
