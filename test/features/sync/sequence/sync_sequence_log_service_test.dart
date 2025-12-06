import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
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

    test('marks previously missing entry as backfilled', () async {
      // Entry was marked missing before, now it arrives
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
