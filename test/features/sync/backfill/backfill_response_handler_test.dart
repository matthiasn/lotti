import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/backfill/backfill_response_handler.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

class MockOutboxService extends Mock implements OutboxService {}

class MockLoggingService extends Mock implements LoggingService {}

class MockVectorClockService extends Mock implements VectorClockService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockSyncSequenceLogService mockSequenceService;
  late MockOutboxService mockOutboxService;
  late MockLoggingService mockLogging;
  late MockVectorClockService mockVcService;
  late BackfillResponseHandler handler;

  const aliceHostId = 'alice-host-uuid';
  const bobHostId = 'bob-host-uuid';
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
    registerFallbackValue(
      SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: '',
          fromId: '',
          toId: '',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        ),
        status: SyncEntryStatus.initial,
      ),
    );
    registerFallbackValue(const VectorClock({}));
    registerFallbackValue(SyncSequencePayloadType.journalEntity);
  });

  setUp(() {
    // Set up SharedPreferences with backfill enabled
    SharedPreferences.setMockInitialValues({'backfill_enabled': true});

    mockJournalDb = MockJournalDb();
    mockSequenceService = MockSyncSequenceLogService();
    mockOutboxService = MockOutboxService();
    mockLogging = MockLoggingService();
    mockVcService = MockVectorClockService();

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
    when(() => mockVcService.getHost()).thenAnswer((_) async => aliceHostId);

    handler = BackfillResponseHandler(
      journalDb: mockJournalDb,
      sequenceLogService: mockSequenceService,
      outboxService: mockOutboxService,
      loggingService: mockLogging,
      vectorClockService: mockVcService,
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

    test('truncates large requests to maxBackfillResponseBatchSize', () async {
      // Create a request with more entries than maxBackfillResponseBatchSize
      final manyEntries = List.generate(
        100, // More than maxBackfillResponseBatchSize (50)
        (i) => BackfillRequestEntry(hostId: bobHostId, counter: i + 1),
      );
      final request = SyncBackfillRequest(
        entries: manyEntries,
        requesterId: requesterId,
      );

      // All entries are for bob (not our host), so they'll be skipped
      // but the truncation logic should still apply
      when(() => mockSequenceService.getEntryByHostAndCounter(bobHostId, any()))
          .thenAnswer((_) async => null);

      await handler.handleBackfillRequest(request);

      // Should only process maxBackfillResponseBatchSize entries (50), not all 100
      // Since these are bob's counters (not ours), we skip them silently
      // Verify it was called exactly 50 times (truncated), not 100
      verify(
        () => mockSequenceService.getEntryByHostAndCounter(bobHostId, any()),
      ).called(50);

      // Verify truncation was logged
      verify(
        () => mockLogging.captureEvent(
          any<String>(that: contains('(truncated)')),
          domain: 'SYNC_BACKFILL',
          subDomain: 'handleRequest',
        ),
      ).called(1);
    });

    test('ignores request when entry not in sequence log and not our host',
        () async {
      // Request for Bob's counter - we don't have it, skip silently
      // (another device might have it)
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: bobHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(() => mockSequenceService.getEntryByHostAndCounter(bobHostId, 3))
          .thenAnswer((_) async => null);

      await handler.handleBackfillRequest(request);

      // Should not enqueue any messages - we don't own this counter
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });

    test('sends unresolvable when own counter not in sequence log', () async {
      // Request for Alice's counter (our own) - we can't find it
      // Only we can answer for our own counters, so send unresolvable
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: aliceHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(() => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 3))
          .thenAnswer((_) async => null);
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await handler.handleBackfillRequest(request);

      // Should send unresolvable response for our own counter
      verify(
        () => mockOutboxService.enqueueMessage(
          const SyncMessage.backfillResponse(
            hostId: aliceHostId,
            counter: 3,
            deleted: false,
            unresolvable: true,
          ),
        ),
      ).called(1);
    });

    test(
        'ignores request when entry in log but has no entryId and not our host',
        () async {
      // Request for Bob's counter - entry exists but no entryId
      const request = SyncBackfillRequest(
        entries: [
          BackfillRequestEntry(hostId: bobHostId, counter: 3),
        ],
        requesterId: requesterId,
      );

      when(() => mockSequenceService.getEntryByHostAndCounter(bobHostId, 3))
          .thenAnswer(
        (_) async => _createLogItem(bobHostId, 3),
      );

      await handler.handleBackfillRequest(request);

      // Should not enqueue any messages - not our counter
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });

    test('sends unresolvable when own counter in log but has no entryId',
        () async {
      // Request for Alice's counter (our own) - entry exists but no entryId
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
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await handler.handleBackfillRequest(request);

      // Should send unresolvable response for our own counter
      verify(
        () => mockOutboxService.enqueueMessage(
          const SyncMessage.backfillResponse(
            hostId: aliceHostId,
            counter: 3,
            deleted: false,
            unresolvable: true,
          ),
        ),
      ).called(1);
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

      final journalEntry = _createJournalEntry(
        entryId,
        vectorClock: const VectorClock({aliceHostId: 3}),
      );
      when(() => mockJournalDb.journalEntityById(entryId))
          .thenAnswer((_) async => journalEntry);

      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await handler.handleBackfillRequest(request);

      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;

      expect(captured.length, 1);

      // Should send the journal entity
      expect(captured[0], isA<SyncJournalEntity>());
      final syncEntity = captured[0] as SyncJournalEntity;
      expect(syncEntity.id, entryId);
      expect(syncEntity.status, SyncEntryStatus.update);
    });

    test('sends unresolvable when own counter not in entry VC', () async {
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

      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;

      expect(captured.length, 2);
      expect(captured[0], isA<SyncJournalEntity>());
      expect(
        captured[1],
        isA<SyncBackfillResponse>()
            .having((r) => r.hostId, 'hostId', aliceHostId)
            .having((r) => r.counter, 'counter', 3)
            .having((r) => r.deleted, 'deleted', false)
            .having((r) => r.unresolvable, 'unresolvable', true)
            .having((r) => r.payloadType, 'payloadType',
                SyncSequencePayloadType.journalEntity),
      );
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

  group('handleBackfillRequest - EntryLink', () {
    test('sends deleted response when entry link was deleted', () async {
      final logItem = _createEntryLinkLogItem(
        aliceHostId,
        10,
        entryId: 'deleted-link-id',
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 10),
      ).thenAnswer((_) async => logItem);

      when(() => mockJournalDb.entryLinkById('deleted-link-id'))
          .thenAnswer((_) async => null);

      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      const request = SyncBackfillRequest(
        entries: [BackfillRequestEntry(hostId: aliceHostId, counter: 10)],
        requesterId: requesterId,
      );

      await handler.handleBackfillRequest(request);

      verify(
        () => mockOutboxService.enqueueMessage(
          any(
            that: isA<SyncBackfillResponse>()
                .having((r) => r.hostId, 'hostId', aliceHostId)
                .having((r) => r.counter, 'counter', 10)
                .having((r) => r.deleted, 'deleted', true)
                .having((r) => r.payloadType, 'payloadType',
                    SyncSequencePayloadType.entryLink),
          ),
        ),
      ).called(1);
    });

    test('re-sends entry link when it exists', () async {
      final logItem = _createEntryLinkLogItem(
        aliceHostId,
        20,
        entryId: 'existing-link-id',
        originatingHostId: aliceHostId,
      );

      final link = _createEntryLink(
        'existing-link-id',
        vectorClock: const VectorClock({aliceHostId: 20}),
      );

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 20),
      ).thenAnswer((_) async => logItem);

      when(() => mockJournalDb.entryLinkById('existing-link-id'))
          .thenAnswer((_) async => link);

      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      const request = SyncBackfillRequest(
        entries: [BackfillRequestEntry(hostId: aliceHostId, counter: 20)],
        requesterId: requesterId,
      );

      await handler.handleBackfillRequest(request);

      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;

      expect(captured.length, 1);
      expect(captured[0], isA<SyncEntryLink>());
    });

    test('sends unresolvable for entry link when own counter not in VC',
        () async {
      final logItem = _createEntryLinkLogItem(
        aliceHostId,
        20,
        entryId: 'existing-link-id',
        originatingHostId: aliceHostId,
      );

      final link = _createEntryLink('existing-link-id');

      when(
        () => mockSequenceService.getEntryByHostAndCounter(aliceHostId, 20),
      ).thenAnswer((_) async => logItem);

      when(() => mockJournalDb.entryLinkById('existing-link-id'))
          .thenAnswer((_) async => link);

      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      const request = SyncBackfillRequest(
        entries: [BackfillRequestEntry(hostId: aliceHostId, counter: 20)],
        requesterId: requesterId,
      );

      await handler.handleBackfillRequest(request);

      final captured = verify(
        () => mockOutboxService.enqueueMessage(captureAny()),
      ).captured;

      expect(captured.length, 2);
      expect(captured[0], isA<SyncEntryLink>());
      expect(
        captured[1],
        isA<SyncBackfillResponse>()
            .having((r) => r.deleted, 'deleted', false)
            .having((r) => r.unresolvable, 'unresolvable', true)
            .having((r) => r.payloadType, 'payloadType',
                SyncSequencePayloadType.entryLink),
      );
    });
  });

  group('handleBackfillResponse - EntryLink', () {
    test('verifies entry link and marks backfilled when link exists locally',
        () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 30,
        deleted: false,
        payloadType: SyncSequencePayloadType.entryLink,
        payloadId: 'local-link-id',
      );

      final link = _createEntryLink('local-link-id');

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          deleted: any(named: 'deleted'),
          entryId: any(named: 'entryId'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async {});

      when(() => mockJournalDb.entryLinkById('local-link-id'))
          .thenAnswer((_) async => link);

      when(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          entryId: any(named: 'entryId'),
          entryVectorClock: any(named: 'entryVectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async => true);

      await handler.handleBackfillResponse(response);

      verify(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: aliceHostId,
          counter: 30,
          entryId: 'local-link-id',
          entryVectorClock: any(named: 'entryVectorClock'),
          payloadType: SyncSequencePayloadType.entryLink,
        ),
      ).called(1);
    });

    test('stores hint when entry link not found locally', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 40,
        deleted: false,
        payloadType: SyncSequencePayloadType.entryLink,
        payloadId: 'missing-link-id',
      );

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          deleted: any(named: 'deleted'),
          entryId: any(named: 'entryId'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async {});

      when(() => mockJournalDb.entryLinkById('missing-link-id'))
          .thenAnswer((_) async => null);

      await handler.handleBackfillResponse(response);

      // Should store the hint
      verify(
        () => mockSequenceService.handleBackfillResponse(
          hostId: aliceHostId,
          counter: 40,
          deleted: false,
          entryId: 'missing-link-id',
          payloadType: SyncSequencePayloadType.entryLink,
        ),
      ).called(1);

      // Should NOT call verifyAndMarkBackfilled since link not found
      verifyNever(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          entryId: any(named: 'entryId'),
          entryVectorClock: any(named: 'entryVectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      );
    });

    test('skips verification when entry link has null vectorClock', () async {
      const response = SyncBackfillResponse(
        hostId: aliceHostId,
        counter: 50,
        deleted: false,
        payloadType: SyncSequencePayloadType.entryLink,
        payloadId: 'link-no-vc',
      );

      final link = _createEntryLinkWithoutVC('link-no-vc');

      when(
        () => mockSequenceService.handleBackfillResponse(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          deleted: any(named: 'deleted'),
          entryId: any(named: 'entryId'),
          payloadType: any(named: 'payloadType'),
        ),
      ).thenAnswer((_) async {});

      when(() => mockJournalDb.entryLinkById('link-no-vc'))
          .thenAnswer((_) async => link);

      await handler.handleBackfillResponse(response);

      // Should NOT call verifyAndMarkBackfilled since VC is null
      verifyNever(
        () => mockSequenceService.verifyAndMarkBackfilled(
          hostId: any(named: 'hostId'),
          counter: any(named: 'counter'),
          entryId: any(named: 'entryId'),
          entryVectorClock: any(named: 'entryVectorClock'),
          payloadType: any(named: 'payloadType'),
        ),
      );
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
    payloadType: 0, // SyncSequencePayloadType.journalEntity.index
    originatingHostId: originatingHostId,
    status: status.index,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    requestCount: 0,
  );
}

JournalEntity _createJournalEntry(
  String id, {
  VectorClock? vectorClock,
}) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      dateFrom: DateTime(2024),
      dateTo: DateTime(2024),
      vectorClock: vectorClock ?? const VectorClock({'test-host': 1}),
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

SyncSequenceLogItem _createEntryLinkLogItem(
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
    payloadType: SyncSequencePayloadType.entryLink.index,
    originatingHostId: originatingHostId,
    status: status.index,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    requestCount: 0,
  );
}

EntryLink _createEntryLink(
  String id, {
  VectorClock? vectorClock,
}) {
  return EntryLink.basic(
    id: id,
    fromId: 'from-entry',
    toId: 'to-entry',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    vectorClock: vectorClock ?? const VectorClock({'test-host': 1}),
  );
}

EntryLink _createEntryLinkWithoutVC(String id) {
  return EntryLink.basic(
    id: id,
    fromId: 'from-entry',
    toId: 'to-entry',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    vectorClock: null,
  );
}
