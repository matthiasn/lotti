import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

class MockOutboxService extends Mock implements OutboxService {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockSyncSequenceLogService mockSequenceService;
  late MockOutboxService mockOutboxService;
  late MockLoggingService mockLogging;
  late BackfillResponseHandler handler;

  const aliceHostId = 'alice-host-uuid';
  const requesterId = 'requester-uuid';
  const entryId = 'test-entry-id';

  setUpAll(() {
    registerFallbackValue(
      const SyncMessage.backfillRequest(
        entries: [],
        requesterId: '',
      ),
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
    registerFallbackValue(const VectorClock({}));
  });

  setUp(() {
    // Set up SharedPreferences with backfill enabled
    SharedPreferences.setMockInitialValues({'backfill_enabled': true});

    mockJournalDb = MockJournalDb();
    mockSequenceService = MockSyncSequenceLogService();
    mockOutboxService = MockOutboxService();
    mockLogging = MockLoggingService();

    when(
      () => mockLogging.captureEvent(
        any<String>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => mockLogging.captureException(
        any<Object>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenReturn(null);

    handler = BackfillResponseHandler(
      journalDb: mockJournalDb,
      sequenceLogService: mockSequenceService,
      outboxService: mockOutboxService,
      loggingService: mockLogging,
    );
  });

  group('handleBackfillRequest', () {
    test('ignores request when backfill is disabled', () async {
      // Set backfill_enabled to false
      SharedPreferences.setMockInitialValues({'backfill_enabled': false});

      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      await handler.handleBackfillRequest(request);

      // Should not call any database methods
      verifyNever(
        () => mockSequenceService.getEntryByHostAndCounter(any(), any()),
      );
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });

    test('ignores request when entry not in sequence log', () async {
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(() => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3))
          .thenAnswer((_) async => null);

      await handler.handleBackfillRequest(request);

      // Should not enqueue any messages
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });

    test('ignores request when entry in log but has no entryId', () async {
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(() => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3))
          .thenAnswer(
        (_) async => _createLogItem(aliceHostId, 3),
      );

      await handler.handleBackfillRequest(request);

      // Should not enqueue any messages
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });

    test('sends deleted response when journal entry was deleted', () async {
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(() => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3))
          .thenAnswer(
        (_) async => _createLogItem(aliceHostId, 3, entryId: entryId),
      );

      when(() => mockJournalDb.journalEntityById(entryId))
          .thenAnswer((_) async => null);

      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await handler.handleBackfillRequest(request);

      // Should send a deleted response
      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;

      expect(captured.length, 1);
      final response = captured[0] as SyncMessage;
      expect(
        response,
        isA<SyncBackfillResponse>()
            .having((r) => r.hostId, 'hostId', aliceHostId)
            .having((r) => r.counter, 'counter', 3)
            .having((r) => r.deleted, 'deleted', true),
      );
    });

    test('re-sends entry via normal sync when entry exists', () async {
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(() => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3))
          .thenAnswer(
        (_) async => _createLogItem(aliceHostId, 3, entryId: entryId),
      );

      final journalEntry = _createJournalEntry(entryId);
      when(() => mockJournalDb.journalEntityById(entryId))
          .thenAnswer((_) async => journalEntry);

      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await handler.handleBackfillRequest(request);

      // Should send both the journal entity AND a BackfillResponse with entryId
      // The BackfillResponse is needed for the case where the entry's VC has
      // evolved and no longer contains the original (hostId, counter)
      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;

      expect(captured.length, 2);

      // First should be the journal entity
      expect(captured[0], isA<SyncJournalEntity>());
      final syncEntity = captured[0] as SyncJournalEntity;
      expect(syncEntity.id, entryId);
      expect(syncEntity.status, SyncEntryStatus.update);

      // Second should be the BackfillResponse with entryId
      expect(captured[1], isA<SyncBackfillResponse>());
      final response = captured[1] as SyncBackfillResponse;
      expect(response.hostId, aliceHostId);
      expect(response.counter, 3);
      expect(response.deleted, false);
      expect(response.entryId, entryId);
    });

    test('handles errors gracefully', () async {
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(() => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3))
          .thenThrow(Exception('Database error'));

      // Should not throw
      await handler.handleBackfillRequest(request);

      // Should log the exception
      verify(
        () => mockLogging.captureException(
          any<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('handleBackfillResponse', () {
    test('delegates to sequenceLogService for deleted response', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: true,
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: true,
        ),
      ).thenAnswer((_) async {});

      await handler.handleBackfillResponse(response);

      verify(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: true,
        ),
      ).called(1);
    });

    test('stores hint and verifies entry when it exists locally', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        entryId: entryId,
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
          entryId: entryId,
        ),
      ).thenAnswer((_) async {});

      // Entry exists locally
      final journalEntry = _createJournalEntry(entryId);
      when(() => mockJournalDb.journalEntityById(entryId))
          .thenAnswer((_) async => journalEntry);

      when(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: aliceHostId,
          counter: 3,
          entryId: entryId,
          entryVectorClock: any(named: 'entryVectorClock'),
        ),
      ).thenAnswer((_) async => true);

      await handler.handleBackfillResponse(response);

      // Should store the hint
      verify(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
          entryId: entryId,
        ),
      ).called(1);

      // Should verify and mark as backfilled
      verify(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: aliceHostId,
          counter: 3,
          entryId: entryId,
          entryVectorClock: any(named: 'entryVectorClock'),
        ),
      ).called(1);
    });

    test('stores hint but skips verification when entry not found locally',
        () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        entryId: entryId,
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
          entryId: entryId,
        ),
      ).thenAnswer((_) async {});

      // Entry does NOT exist locally
      when(() => mockJournalDb.journalEntityById(entryId))
          .thenAnswer((_) async => null);

      await handler.handleBackfillResponse(response);

      // Should store the hint
      verify(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
          entryId: entryId,
        ),
      ).called(1);

      // Should NOT try to verify (entry not found)
      verifyNever(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          entryId: any(named: 'entryId'),
          entryVectorClock: any(named: 'entryVectorClock'),
        ),
      );
    });

    test('skips verification when response has no entryId', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        // No entryId
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
        ),
      ).thenAnswer((_) async {});

      await handler.handleBackfillResponse(response);

      // Should store the hint
      verify(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
        ),
      ).called(1);

      // Should NOT try to verify (no entryId)
      verifyNever(() => mockJournalDb.journalEntityById(any()));
    });

    test('skips verification when entry has null vectorClock', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: false,
        entryId: entryId,
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 3,
          deleted: false,
          entryId: entryId,
        ),
      ).thenAnswer((_) async {});

      // Entry exists but has null vectorClock
      final journalEntry = _createJournalEntryWithoutVC(entryId);
      when(() => mockJournalDb.journalEntityById(entryId))
          .thenAnswer((_) async => journalEntry);

      await handler.handleBackfillResponse(response);

      // Should NOT try to verify (no VC)
      verifyNever(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          entryId: any(named: 'entryId'),
          entryVectorClock: any(named: 'entryVectorClock'),
        ),
      );
    });

    test('handles errors gracefully', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 3,
        deleted: true,
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          deleted: any(named: 'deleted'),
          entryId: any(named: 'entryId'),
        ),
      ).thenThrow(Exception('Database error'));

      // Should not throw
      await handler.handleBackfillResponse(response);

      // Should log the exception
      verify(
        () => mockLogging.captureException(
          any<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });
}

SyncSequenceLogItem _createLogItem(
  String hostId,
  int counter, {
  String? entryId,
  String? originatingHostId,
  SyncSequenceStatus status = SyncSequenceStatus.received,
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

JournalEntity _createJournalEntry(String id) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      dateFrom: DateTime(2024),
      dateTo: DateTime(2024),
      vectorClock: const VectorClock({'test-host': 1}),
    ),
    entryText: const EntryText(plainText: 'Test entry'),
  );
}

JournalEntity _createJournalEntryWithoutVC(String id) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      dateFrom: DateTime(2024),
      dateTo: DateTime(2024),
      // vectorClock is null
    ),
    entryText: const EntryText(plainText: 'Test entry'),
  );
}
