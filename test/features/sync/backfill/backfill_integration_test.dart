// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockOutboxService extends Mock implements OutboxService {}

class MockLoggingService extends Mock implements LoggingService {}

class MockVectorClockService extends Mock implements VectorClockService {}

/// Integration test for the full backfill flow.
///
/// Tests the complete cycle:
/// 1. Alice sends an entry (recorded in her sequence log)
/// 2. Bob receives a message with a gap (counter jump from 1 to 3)
/// 3. Bob detects the gap and records counter 2 as missing
/// 4. Bob's backfill request is captured
/// 5. Alice's handler processes the request and re-sends the entry
/// 6. Bob processes the response and marks the entry as backfilled
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const aliceHostId = 'alice-host-uuid';
  const bobHostId = 'bob-host-uuid';
  const entryId1 = 'entry-id-1';
  const entryId2 = 'entry-id-2';
  const entryId3 = 'entry-id-3';

  late SyncDatabase aliceSyncDb;
  late SyncDatabase bobSyncDb;
  late JournalDb aliceJournalDb;
  late MockOutboxService aliceOutbox;
  late MockOutboxService bobOutbox;
  late MockLoggingService aliceLogging;
  late MockLoggingService bobLogging;
  late MockVectorClockService aliceVcService;
  late MockVectorClockService bobVcService;
  late SyncSequenceLogService aliceSequenceService;
  late SyncSequenceLogService bobSequenceService;
  late BackfillResponseHandler aliceResponseHandler;

  setUpAll(() {
    registerFallbackValue(
      const SyncMessage.backfillRequest(entries: [], requesterId: ''),
    );
    registerFallbackValue(
      const SyncMessage.backfillResponse(
        hostId: '',
        counter: 0,
        deleted: false,
      ),
    );
    registerFallbackValue(
      const SyncMessage.journalEntity(
        id: '',
        jsonPath: '',
        vectorClock: VectorClock({}),
        status: SyncEntryStatus.initial,
      ),
    );
  });

  setUp(() async {
    // Set up SharedPreferences with backfill enabled
    SharedPreferences.setMockInitialValues({'backfill_enabled': true});

    // Create in-memory databases for both devices
    aliceSyncDb = SyncDatabase(inMemoryDatabase: true);
    bobSyncDb = SyncDatabase(inMemoryDatabase: true);
    aliceJournalDb = JournalDb(inMemoryDatabase: true);

    // Create mocks
    aliceOutbox = MockOutboxService();
    bobOutbox = MockOutboxService();
    aliceLogging = MockLoggingService();
    bobLogging = MockLoggingService();
    aliceVcService = MockVectorClockService();
    bobVcService = MockVectorClockService();

    // Configure vector clock services
    when(() => aliceVcService.getHost()).thenAnswer((_) async => aliceHostId);
    when(() => bobVcService.getHost()).thenAnswer((_) async => bobHostId);

    // Configure logging (no-op)
    for (final logging in [aliceLogging, bobLogging]) {
      when(
        () => logging.captureEvent(
          any<String>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);
      when(
        () => logging.captureException(
          any<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenReturn(null);
    }

    // Configure outbox mocks
    when(() => aliceOutbox.enqueueMessage(any())).thenAnswer((_) async {});
    when(() => bobOutbox.enqueueMessage(any())).thenAnswer((_) async {});

    // Create services
    aliceSequenceService = SyncSequenceLogService(
      syncDatabase: aliceSyncDb,
      vectorClockService: aliceVcService,
      loggingService: aliceLogging,
    );

    bobSequenceService = SyncSequenceLogService(
      syncDatabase: bobSyncDb,
      vectorClockService: bobVcService,
      loggingService: bobLogging,
    );

    aliceResponseHandler = BackfillResponseHandler(
      journalDb: aliceJournalDb,
      sequenceLogService: aliceSequenceService,
      outboxService: aliceOutbox,
      loggingService: aliceLogging,
    );
  });

  tearDown(() async {
    await aliceSyncDb.close();
    await bobSyncDb.close();
    await aliceJournalDb.close();
  });

  group('Backfill Integration', () {
    test('full backfill flow: gap detection → request → response', () async {
      // === STEP 1: Alice sends entries 1, 2, 3 ===
      // Alice records sent entries in her sequence log

      // Entry 1
      await aliceSequenceService.recordSentEntry(
        entryId: entryId1,
        vectorClock: const VectorClock({aliceHostId: 1}),
      );

      // Entry 2
      await aliceSequenceService.recordSentEntry(
        entryId: entryId2,
        vectorClock: const VectorClock({aliceHostId: 2}),
      );

      // Entry 3
      await aliceSequenceService.recordSentEntry(
        entryId: entryId3,
        vectorClock: const VectorClock({aliceHostId: 3}),
      );

      // Verify Alice has all 3 entries
      final aliceEntry1 =
          await aliceSyncDb.getEntryByHostAndCounter(aliceHostId, 1);
      final aliceEntry2 =
          await aliceSyncDb.getEntryByHostAndCounter(aliceHostId, 2);
      final aliceEntry3 =
          await aliceSyncDb.getEntryByHostAndCounter(aliceHostId, 3);

      expect(aliceEntry1, isNotNull);
      expect(aliceEntry1!.entryId, entryId1);
      expect(aliceEntry2, isNotNull);
      expect(aliceEntry2!.entryId, entryId2);
      expect(aliceEntry3, isNotNull);
      expect(aliceEntry3!.entryId, entryId3);

      // Store the journal entry in Alice's database (for backfill response)
      final journalEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId2,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
          vectorClock: const VectorClock({aliceHostId: 2}),
        ),
        entryText: const EntryText(plainText: 'Test entry 2'),
      );
      await aliceJournalDb.upsertJournalDbEntity(toDbEntity(journalEntry));

      // === STEP 2: Bob receives entry 1, then entry 3 (skipping 2) ===

      // Bob receives entry 1 (no gap)
      final gaps1 = await bobSequenceService.recordReceivedEntry(
        entryId: entryId1,
        vectorClock: const VectorClock({aliceHostId: 1}),
        originatingHostId: aliceHostId,
      );
      expect(gaps1, isEmpty, reason: 'No gap for first entry');

      // Verify Bob recorded entry 1
      final bobEntry1 =
          await bobSyncDb.getEntryByHostAndCounter(aliceHostId, 1);
      expect(bobEntry1, isNotNull);
      expect(bobEntry1!.status, SyncSequenceStatus.received.index);

      // Bob receives entry 3 (gap detected - missing entry 2)
      final gaps3 = await bobSequenceService.recordReceivedEntry(
        entryId: entryId3,
        vectorClock: const VectorClock({aliceHostId: 3}),
        originatingHostId: aliceHostId,
      );

      expect(gaps3, hasLength(1), reason: 'Should detect 1 gap');
      expect(gaps3[0].hostId, aliceHostId);
      expect(gaps3[0].counter, 2);

      // Verify Bob has entry 2 marked as missing
      final bobEntry2 =
          await bobSyncDb.getEntryByHostAndCounter(aliceHostId, 2);
      expect(bobEntry2, isNotNull);
      expect(bobEntry2!.status, SyncSequenceStatus.missing.index);
      expect(bobEntry2.entryId, isNull, reason: 'Missing entry has no entryId');

      // Verify Bob has entry 3 as received
      final bobEntry3 =
          await bobSyncDb.getEntryByHostAndCounter(aliceHostId, 3);
      expect(bobEntry3, isNotNull);
      expect(bobEntry3!.status, SyncSequenceStatus.received.index);

      // === STEP 3: Bob queries for missing entries ===
      final missingEntries = await bobSequenceService.getMissingEntries();
      expect(missingEntries, hasLength(1));
      expect(missingEntries[0].hostId, aliceHostId);
      expect(missingEntries[0].counter, 2);

      // === STEP 4: Bob creates a backfill request ===
      final backfillRequest = SyncBackfillRequest(
        entries: missingEntries
            .map(
              (e) => BackfillRequestEntry(hostId: e.hostId, counter: e.counter),
            )
            .toList(),
        requesterId: bobHostId,
      );

      expect(backfillRequest.entries, hasLength(1));
      expect(backfillRequest.entries[0].hostId, aliceHostId);
      expect(backfillRequest.entries[0].counter, 2);

      // Mark as requested
      await bobSequenceService.markAsRequested([
        (hostId: aliceHostId, counter: 2),
      ]);

      // Verify status updated
      final bobEntry2AfterRequest =
          await bobSyncDb.getEntryByHostAndCounter(aliceHostId, 2);
      expect(
        bobEntry2AfterRequest!.status,
        SyncSequenceStatus.requested.index,
      );
      expect(bobEntry2AfterRequest.requestCount, 1);

      // === STEP 5: Alice receives and handles the backfill request ===
      await aliceResponseHandler.handleBackfillRequest(backfillRequest);

      // Verify Alice enqueued only the journal entity (no BackfillResponse)
      final capturedMessages = verify(
        () => aliceOutbox.enqueueMessage(captureAny()),
      ).captured;

      expect(capturedMessages, hasLength(1));

      // Should be the journal entity
      expect(capturedMessages[0], isA<SyncJournalEntity>());
      final journalEntity = capturedMessages[0] as SyncJournalEntity;
      expect(journalEntity.id, entryId2);
      expect(journalEntity.status, SyncEntryStatus.update);

      // === STEP 6: Bob receives the entry via normal sync ===
      // When the entry arrives, recordReceivedEntry updates the status to backfilled
      await bobSequenceService.recordReceivedEntry(
        entryId: entryId2,
        vectorClock: const VectorClock({aliceHostId: 2}),
        originatingHostId: aliceHostId,
      );

      // Verify Bob's sequence log is updated to backfilled
      final bobEntry2Final =
          await bobSyncDb.getEntryByHostAndCounter(aliceHostId, 2);
      expect(bobEntry2Final, isNotNull);
      expect(bobEntry2Final!.status, SyncSequenceStatus.backfilled.index);
      expect(bobEntry2Final.entryId, entryId2);

      // Verify no more missing entries
      final remainingMissing = await bobSequenceService.getMissingEntries();
      expect(remainingMissing, isEmpty);
    });

    test('backfill response for deleted entry', () async {
      // Alice had entry 2 but it was deleted
      await aliceSequenceService.recordSentEntry(
        entryId: entryId2,
        vectorClock: const VectorClock({aliceHostId: 2}),
      );
      // Note: We don't add the journal entry to simulate deletion

      // Bob has a gap
      await bobSequenceService.recordReceivedEntry(
        entryId: entryId1,
        vectorClock: const VectorClock({aliceHostId: 1}),
        originatingHostId: aliceHostId,
      );
      await bobSequenceService.recordReceivedEntry(
        entryId: entryId3,
        vectorClock: const VectorClock({aliceHostId: 3}),
        originatingHostId: aliceHostId,
      );

      // Verify gap detected
      final bobEntry2 =
          await bobSyncDb.getEntryByHostAndCounter(aliceHostId, 2);
      expect(bobEntry2!.status, SyncSequenceStatus.missing.index);

      // Bob requests backfill
      const request = SyncBackfillRequest(
        entries: [BackfillRequestEntry(hostId: aliceHostId, counter: 2)],
        requesterId: bobHostId,
      );

      // Alice handles request - entry is not in journal (deleted)
      await aliceResponseHandler.handleBackfillRequest(request);

      // Verify Alice sent a deleted response
      final capturedMessages = verify(
        () => aliceOutbox.enqueueMessage(captureAny()),
      ).captured;

      expect(capturedMessages, hasLength(1));
      expect(capturedMessages[0], isA<SyncBackfillResponse>());
      final response = capturedMessages[0] as SyncBackfillResponse;
      expect(response.deleted, true);
      expect(response.entryId, isNull);

      // Bob handles deleted response
      await bobSequenceService.handleBackfillResponse(
        hostId: response.hostId,
        counter: response.counter,
        deleted: response.deleted,
      );

      // Verify Bob's entry is marked as deleted
      final bobEntry2Final =
          await bobSyncDb.getEntryByHostAndCounter(aliceHostId, 2);
      expect(bobEntry2Final!.status, SyncSequenceStatus.deleted.index);

      // No more missing entries (deleted counts as resolved)
      final missing = await bobSequenceService.getMissingEntries();
      expect(missing, isEmpty);
    });

    test('multiple gaps in single message are all detected', () async {
      // Bob receives entry 1
      await bobSequenceService.recordReceivedEntry(
        entryId: entryId1,
        vectorClock: const VectorClock({aliceHostId: 1}),
        originatingHostId: aliceHostId,
      );

      // Bob receives entry 5 (missing 2, 3, 4)
      final gaps = await bobSequenceService.recordReceivedEntry(
        entryId: 'entry-id-5',
        vectorClock: const VectorClock({aliceHostId: 5}),
        originatingHostId: aliceHostId,
      );

      expect(gaps, hasLength(3));
      expect(gaps.map((g) => g.counter).toList(), [2, 3, 4]);

      // All should be marked as missing
      for (var counter = 2; counter <= 4; counter++) {
        final entry =
            await bobSyncDb.getEntryByHostAndCounter(aliceHostId, counter);
        expect(entry!.status, SyncSequenceStatus.missing.index);
      }
    });

    test('batched backfill request with multiple entries', () async {
      // Setup: Bob has multiple missing entries
      await bobSequenceService.recordReceivedEntry(
        entryId: entryId1,
        vectorClock: const VectorClock({aliceHostId: 1}),
        originatingHostId: aliceHostId,
      );
      await bobSequenceService.recordReceivedEntry(
        entryId: 'entry-id-5',
        vectorClock: const VectorClock({aliceHostId: 5}),
        originatingHostId: aliceHostId,
      );

      // Get missing entries
      final missing = await bobSequenceService.getMissingEntries();
      expect(missing, hasLength(3)); // counters 2, 3, 4

      // Create batched request
      final request = SyncBackfillRequest(
        entries: missing
            .map(
              (e) => BackfillRequestEntry(hostId: e.hostId, counter: e.counter),
            )
            .toList(),
        requesterId: bobHostId,
      );

      expect(request.entries, hasLength(3));
      expect(request.entries.map((e) => e.counter).toList(), [2, 3, 4]);
    });

    test('host activity is updated when receiving entries', () async {
      // Bob receives an entry from Alice
      await bobSequenceService.recordReceivedEntry(
        entryId: entryId1,
        vectorClock: const VectorClock({aliceHostId: 1}),
        originatingHostId: aliceHostId,
      );

      // Check that host activity was recorded
      final lastSeen = await bobSyncDb.getHostLastSeen(aliceHostId);
      expect(lastSeen, isNotNull);
      expect(
        lastSeen!.difference(DateTime.now()).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('exponential backoff respects request count', () async {
      // Setup gap
      await bobSequenceService.recordReceivedEntry(
        entryId: entryId1,
        vectorClock: const VectorClock({aliceHostId: 1}),
        originatingHostId: aliceHostId,
      );
      await bobSequenceService.recordReceivedEntry(
        entryId: entryId3,
        vectorClock: const VectorClock({aliceHostId: 3}),
        originatingHostId: aliceHostId,
      );

      // Mark as requested multiple times
      for (var i = 0; i < 5; i++) {
        await bobSequenceService.markAsRequested([
          (hostId: aliceHostId, counter: 2),
        ]);
      }

      // Check request count
      final entry = await bobSyncDb.getEntryByHostAndCounter(aliceHostId, 2);
      expect(entry!.requestCount, 5);

      // With maxRequestCount=3, this entry should be filtered out
      final missing = await bobSequenceService.getMissingEntries(
        maxRequestCount: 3,
      );
      expect(missing, isEmpty);

      // But with higher limit it should be included
      final missingHighLimit = await bobSequenceService.getMissingEntries(
        maxRequestCount: 10,
      );
      expect(missingHighLimit, hasLength(1));
    });
  });
}
