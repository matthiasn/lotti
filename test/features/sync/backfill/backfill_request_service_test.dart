// ignore_for_file: cascade_invocations, avoid_redundant_argument_values

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

class MockSyncDatabase extends Mock implements SyncDatabase {}

class MockOutboxService extends Mock implements OutboxService {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSyncSequenceLogService mockSequenceService;
  late MockSyncDatabase mockSyncDatabase;
  late MockOutboxService mockOutboxService;
  late MockVectorClockService mockVcService;
  late MockLoggingService mockLogging;

  const myHostId = 'my-host-uuid';
  const aliceHostId = 'alice-host-uuid';

  setUpAll(() {
    registerFallbackValue(
      const SyncMessage.backfillRequest(
        entries: [],
        requesterId: '',
      ),
    );
    registerFallbackValue(<({String hostId, int counter})>[]);
  });

  setUp(() {
    // Set up SharedPreferences with backfill enabled
    SharedPreferences.setMockInitialValues({'backfill_enabled': true});

    mockSequenceService = MockSyncSequenceLogService();
    mockSyncDatabase = MockSyncDatabase();
    mockOutboxService = MockOutboxService();
    mockVcService = MockVectorClockService();
    mockLogging = MockLoggingService();

    when(() => mockVcService.getHost()).thenAnswer((_) async => myHostId);
    // Default: no pending backfill entries in outbox
    when(() => mockSyncDatabase.getPendingBackfillEntries())
        .thenAnswer((_) async => {});
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
  });

  group('BackfillRequestService', () {
    test('timer fires at configured interval', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 30),
        );

        // Automatic backfill uses getMissingEntriesWithLimits
        when(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).thenAnswer((_) async => []);

        service.start();
        expect(service.isRunning, isTrue);

        async.flushMicrotasks();

        // Elapse first interval
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        verify(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).called(1);

        // Elapse second interval
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        verify(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).called(1);

        service.dispose();
        expect(service.isRunning, isFalse);
      });
    });

    test('sends backfill requests for missing entries', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 10),
        );

        final missingEntries = [
          _createMissingLogItem(aliceHostId, 3),
          _createMissingLogItem(aliceHostId, 4),
        ];

        when(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).thenAnswer((_) async => missingEntries);

        when(() => mockOutboxService.enqueueMessage(any()))
            .thenAnswer((_) async {});

        when(() => mockSequenceService.markAsRequested(any()))
            .thenAnswer((_) async {});

        service.start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        // Should have enqueued 1 batched backfill request containing 2 entries
        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;
        expect(captured.length, 1);
        final request = captured[0] as SyncBackfillRequest;
        expect(request.entries.length, 2);
        expect(request.entries[0].hostId, aliceHostId);
        expect(request.entries[0].counter, 3);
        expect(request.entries[1].hostId, aliceHostId);
        expect(request.entries[1].counter, 4);

        // Should have marked entries as requested
        verify(() => mockSequenceService.markAsRequested(any())).called(1);

        service.dispose();
      });
    });

    test('respects maxBatchSize limit', () {
      fakeAsync((async) {
        const maxBatch = 2;
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
          maxBatchSize: maxBatch,
        );

        when(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: maxBatch,
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).thenAnswer((_) async => [
              _createMissingLogItem(aliceHostId, 1),
              _createMissingLogItem(aliceHostId, 2),
            ]);

        when(() => mockOutboxService.enqueueMessage(any()))
            .thenAnswer((_) async {});
        when(() => mockSequenceService.markAsRequested(any()))
            .thenAnswer((_) async {});

        service.start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        verify(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: maxBatch,
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).called(1);

        service.dispose();
      });
    });

    test('processNow triggers immediate processing', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(minutes: 5),
        );

        when(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).thenAnswer((_) async => []);

        // Call processNow without starting the timer
        service.processNow();
        async.flushMicrotasks();

        verify(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).called(1);

        service.dispose();
      });
    });

    test('skips processing when no host ID available', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
        );

        when(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).thenAnswer((_) async => [
              _createMissingLogItem(aliceHostId, 1),
            ]);

        // Return null for host ID
        when(() => mockVcService.getHost()).thenAnswer((_) async => null);

        service.start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Should not enqueue any messages
        verifyNever(() => mockOutboxService.enqueueMessage(any()));

        service.dispose();
      });
    });

    test('stop cancels the timer', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
        );

        when(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).thenAnswer((_) async => []);

        service.start();
        expect(service.isRunning, isTrue);

        service.stop();
        expect(service.isRunning, isFalse);

        // Elapse time - should not trigger processing
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        verifyNever(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            ));

        service.dispose();
      });
    });

    test('does not process if already processing', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
        );

        var callCount = 0;
        when(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).thenAnswer((_) async {
          callCount++;
          // Simulate slow processing
          await Future<void>.delayed(const Duration(seconds: 3));
          return [];
        });

        service.start();
        async.flushMicrotasks();

        // Trigger first processing
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Start processing (isProcessing should be true)
        expect(service.isProcessing, isTrue);

        // Call processNow while still processing - should be ignored
        service.processNow();
        async.flushMicrotasks();

        // Complete the first processing
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(service.isProcessing, isFalse);
        expect(callCount, 1);

        service.dispose();
      });
    });

    test('does not run after dispose', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
        );

        when(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).thenAnswer((_) async => []);

        service.start();
        async.flushMicrotasks();

        service.dispose();

        // Try to start again after dispose
        service.start();
        expect(service.isRunning, isFalse);

        // processNow should also not work
        service.processNow();
        async.flushMicrotasks();

        verifyNever(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            ));
      });
    });

    test('handles errors gracefully', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
        );

        when(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).thenThrow(Exception('Database error'));

        service.start();
        async.flushMicrotasks();

        // Should not throw
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Should log the exception
        verify(
          () => mockLogging.captureException(
            any<Object>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);

        // Service should still be running
        expect(service.isRunning, isTrue);
        expect(service.isProcessing, isFalse);

        service.dispose();
      });
    });

    test('processFullBackfill uses getMissingEntries without host filtering',
        () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(minutes: 5),
        );

        final missingEntries = [
          _createMissingLogItem(aliceHostId, 1),
          _createMissingLogItem(aliceHostId, 2),
        ];

        // Full backfill should use getMissingEntries (no host activity filter)
        when(() => mockSequenceService.getMissingEntries(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
            )).thenAnswer((_) async => missingEntries);

        when(() => mockOutboxService.enqueueMessage(any()))
            .thenAnswer((_) async {});
        when(() => mockSequenceService.markAsRequested(any()))
            .thenAnswer((_) async {});

        // Call processFullBackfill (ignores enabled flag)
        service.processFullBackfill();
        async.flushMicrotasks();

        // Should use getMissingEntries (no host activity filter)
        verify(() => mockSequenceService.getMissingEntries(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
            )).called(1);

        // Should NOT use getMissingEntriesWithLimits (that's for automatic backfill)
        verifyNever(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            ));

        service.dispose();
      });
    });

    test('skips processing when backfill is disabled', () {
      fakeAsync((async) {
        // Disable backfill
        SharedPreferences.setMockInitialValues({'backfill_enabled': false});

        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
        );

        service.start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Should not fetch missing entries when disabled
        verifyNever(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            ));

        service.dispose();
      });
    });

    test('filters out already-queued entries from outbox', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
        );

        final missingEntries = [
          _createMissingLogItem(aliceHostId, 1),
          _createMissingLogItem(aliceHostId, 2),
          _createMissingLogItem(aliceHostId, 3),
        ];

        when(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).thenAnswer((_) async => missingEntries);

        // Entry 2 is already in outbox
        when(() => mockSyncDatabase.getPendingBackfillEntries()).thenAnswer(
          (_) async => {(hostId: aliceHostId, counter: 2)},
        );

        when(() => mockOutboxService.enqueueMessage(any()))
            .thenAnswer((_) async {});
        when(() => mockSequenceService.markAsRequested(any()))
            .thenAnswer((_) async {});

        service.start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Should only request entries 1 and 3 (entry 2 filtered out)
        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;
        expect(captured.length, 1);
        final request = captured[0] as SyncBackfillRequest;
        expect(request.entries.length, 2);
        expect(request.entries.map((e) => e.counter), containsAll([1, 3]));
        expect(request.entries.map((e) => e.counter), isNot(contains(2)));

        service.dispose();
      });
    });

    test('returns zero when all entries already queued', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
        );

        final missingEntries = [
          _createMissingLogItem(aliceHostId, 1),
        ];

        when(() => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              maxPerHost: any(named: 'maxPerHost'),
            )).thenAnswer((_) async => missingEntries);

        // Entry 1 is already in outbox
        when(() => mockSyncDatabase.getPendingBackfillEntries()).thenAnswer(
          (_) async => {(hostId: aliceHostId, counter: 1)},
        );

        service.start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Should not enqueue any message
        verifyNever(() => mockOutboxService.enqueueMessage(any()));

        service.dispose();
      });
    });

    group('processReRequest', () {
      test('sends backfill requests for entries in requested status', () {
        fakeAsync((async) {
          final service = BackfillRequestService(
            sequenceLogService: mockSequenceService,
            syncDatabase: mockSyncDatabase,
            outboxService: mockOutboxService,
            vectorClockService: mockVcService,
            loggingService: mockLogging,
            requestInterval: const Duration(minutes: 5),
            maxBatchSize: 50,
          );

          final requestedEntries = [
            _createRequestedLogItem(aliceHostId, 10),
            _createRequestedLogItem(aliceHostId, 11),
          ];

          when(() => mockSequenceService.getRequestedEntries(limit: 50))
              .thenAnswer((_) async => requestedEntries);

          // Second call returns empty to stop pagination
          var callCount = 0;
          when(() => mockSequenceService.getRequestedEntries(limit: 50))
              .thenAnswer((_) async {
            callCount++;
            return callCount == 1 ? requestedEntries : [];
          });

          when(() => mockSequenceService.resetRequestCounts(any()))
              .thenAnswer((_) async {});
          when(() => mockOutboxService.enqueueMessage(any()))
              .thenAnswer((_) async {});
          when(() => mockSequenceService.markAsRequested(any()))
              .thenAnswer((_) async {});

          service.processReRequest();
          async.flushMicrotasks();

          // Should have reset request counts
          verify(() => mockSequenceService.resetRequestCounts(any())).called(1);

          // Should have sent backfill request
          final captured = verify(
            () => mockOutboxService.enqueueMessage(captureAny()),
          ).captured;
          expect(captured.length, 1);
          final request = captured[0] as SyncBackfillRequest;
          expect(request.entries.length, 2);
          expect(request.requesterId, myHostId);

          // Should have marked as requested again
          verify(() => mockSequenceService.markAsRequested(any())).called(1);

          service.dispose();
        });
      });

      test('returns zero when no requested entries', () {
        fakeAsync((async) {
          final service = BackfillRequestService(
            sequenceLogService: mockSequenceService,
            syncDatabase: mockSyncDatabase,
            outboxService: mockOutboxService,
            vectorClockService: mockVcService,
            loggingService: mockLogging,
            requestInterval: const Duration(minutes: 5),
          );

          when(() => mockSequenceService.getRequestedEntries(
                limit: any(named: 'limit'),
              )).thenAnswer((_) async => []);

          int? result;
          service.processReRequest().then((r) => result = r);
          async.flushMicrotasks();

          expect(result, 0);
          verifyNever(() => mockOutboxService.enqueueMessage(any()));

          service.dispose();
        });
      });

      test('skips entries already queued in outbox', () {
        fakeAsync((async) {
          final service = BackfillRequestService(
            sequenceLogService: mockSequenceService,
            syncDatabase: mockSyncDatabase,
            outboxService: mockOutboxService,
            vectorClockService: mockVcService,
            loggingService: mockLogging,
            requestInterval: const Duration(minutes: 5),
            maxBatchSize: 50,
          );

          final requestedEntries = [
            _createRequestedLogItem(aliceHostId, 10),
            _createRequestedLogItem(aliceHostId, 11),
            _createRequestedLogItem(aliceHostId, 12),
          ];

          var callCount = 0;
          when(() => mockSequenceService.getRequestedEntries(limit: 50))
              .thenAnswer((_) async {
            callCount++;
            return callCount == 1 ? requestedEntries : [];
          });

          // Entry 11 is already queued
          when(() => mockSyncDatabase.getPendingBackfillEntries()).thenAnswer(
            (_) async => {(hostId: aliceHostId, counter: 11)},
          );

          when(() => mockSequenceService.resetRequestCounts(any()))
              .thenAnswer((_) async {});
          when(() => mockOutboxService.enqueueMessage(any()))
              .thenAnswer((_) async {});
          when(() => mockSequenceService.markAsRequested(any()))
              .thenAnswer((_) async {});

          service.processReRequest();
          async.flushMicrotasks();

          // Should only request entries 10 and 12 (entry 11 filtered out)
          final captured = verify(
            () => mockOutboxService.enqueueMessage(captureAny()),
          ).captured;
          expect(captured.length, 1);
          final request = captured[0] as SyncBackfillRequest;
          expect(request.entries.length, 2);
          expect(request.entries.map((e) => e.counter), containsAll([10, 12]));
          expect(request.entries.map((e) => e.counter), isNot(contains(11)));

          service.dispose();
        });
      });

      test('returns zero when no host ID available', () {
        fakeAsync((async) {
          final service = BackfillRequestService(
            sequenceLogService: mockSequenceService,
            syncDatabase: mockSyncDatabase,
            outboxService: mockOutboxService,
            vectorClockService: mockVcService,
            loggingService: mockLogging,
            requestInterval: const Duration(minutes: 5),
          );

          when(() => mockVcService.getHost()).thenAnswer((_) async => null);

          int? result;
          service.processReRequest().then((r) => result = r);
          async.flushMicrotasks();

          expect(result, 0);
          verifyNever(() => mockSequenceService.getRequestedEntries(
                limit: any(named: 'limit'),
              ));

          service.dispose();
        });
      });

      test('handles errors gracefully and returns partial count', () {
        fakeAsync((async) {
          final service = BackfillRequestService(
            sequenceLogService: mockSequenceService,
            syncDatabase: mockSyncDatabase,
            outboxService: mockOutboxService,
            vectorClockService: mockVcService,
            loggingService: mockLogging,
            requestInterval: const Duration(minutes: 5),
            maxBatchSize: 50,
          );

          when(() => mockSequenceService.getRequestedEntries(limit: 50))
              .thenThrow(Exception('Database error'));

          int? result;
          service.processReRequest().then((r) => result = r);
          async.flushMicrotasks();

          expect(result, 0);

          // Should log the exception
          verify(
            () => mockLogging.captureException(
              any<Object>(),
              domain: any(named: 'domain'),
              subDomain: any(named: 'subDomain'),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
            ),
          ).called(1);

          service.dispose();
        });
      });

      test('does not process if already processing', () {
        fakeAsync((async) {
          final service = BackfillRequestService(
            sequenceLogService: mockSequenceService,
            syncDatabase: mockSyncDatabase,
            outboxService: mockOutboxService,
            vectorClockService: mockVcService,
            loggingService: mockLogging,
            requestInterval: const Duration(seconds: 5),
            maxBatchSize: 50,
          );

          var getRequestedCallCount = 0;
          when(() => mockSequenceService.getRequestedEntries(limit: 50))
              .thenAnswer((_) async {
            getRequestedCallCount++;
            // Simulate slow processing
            await Future<void>.delayed(const Duration(seconds: 2));
            return [];
          });

          // Start first processReRequest
          service.processReRequest();
          async.flushMicrotasks();

          expect(service.isProcessing, isTrue);

          // Try to start another - should be ignored
          int? result;
          service.processReRequest().then((r) => result = r);
          async.flushMicrotasks();

          expect(result, 0);

          // Complete the first processing
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();

          // Only one call to getRequestedEntries
          expect(getRequestedCallCount, 1);

          service.dispose();
        });
      });

      test('does not run after dispose', () {
        fakeAsync((async) {
          final service = BackfillRequestService(
            sequenceLogService: mockSequenceService,
            syncDatabase: mockSyncDatabase,
            outboxService: mockOutboxService,
            vectorClockService: mockVcService,
            loggingService: mockLogging,
            requestInterval: const Duration(minutes: 5),
          );

          service.dispose();

          int? result;
          service.processReRequest().then((r) => result = r);
          async.flushMicrotasks();

          expect(result, 0);
          verifyNever(() => mockVcService.getHost());

          // Already disposed, no need to call dispose again
        });
      });

      test('paginates through all requested entries', () {
        fakeAsync((async) {
          final service = BackfillRequestService(
            sequenceLogService: mockSequenceService,
            syncDatabase: mockSyncDatabase,
            outboxService: mockOutboxService,
            vectorClockService: mockVcService,
            loggingService: mockLogging,
            requestInterval: const Duration(minutes: 5),
            maxBatchSize: 2, // Small batch size to test pagination
          );

          final batch1 = [
            _createRequestedLogItem(aliceHostId, 1),
            _createRequestedLogItem(aliceHostId, 2),
          ];
          final batch2 = [
            _createRequestedLogItem(aliceHostId, 3),
          ];

          var callCount = 0;
          when(() => mockSequenceService.getRequestedEntries(limit: 2))
              .thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return batch1;
            if (callCount == 2) return batch2;
            return [];
          });

          when(() => mockSequenceService.resetRequestCounts(any()))
              .thenAnswer((_) async {});
          when(() => mockOutboxService.enqueueMessage(any()))
              .thenAnswer((_) async {});
          when(() => mockSequenceService.markAsRequested(any()))
              .thenAnswer((_) async {});

          int? result;
          service.processReRequest().then((r) => result = r);
          async.flushMicrotasks();

          // Should have processed 3 entries total (2 batches)
          expect(result, 3);

          // Should have sent 2 backfill requests
          verify(() => mockOutboxService.enqueueMessage(any())).called(2);

          service.dispose();
        });
      });
    });
  });
}

SyncSequenceLogItem _createMissingLogItem(
  String hostId,
  int counter,
) {
  return SyncSequenceLogItem(
    hostId: hostId,
    counter: counter,
    payloadType: 0, // SyncSequencePayloadType.journalEntity.index
    originatingHostId: null,
    status: SyncSequenceStatus.missing.index,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    requestCount: 0,
  );
}

SyncSequenceLogItem _createRequestedLogItem(
  String hostId,
  int counter,
) {
  return SyncSequenceLogItem(
    hostId: hostId,
    counter: counter,
    payloadType: 0, // SyncSequencePayloadType.journalEntity.index
    originatingHostId: null,
    status: SyncSequenceStatus.requested.index,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    requestCount: 10, // Hit max retries
  );
}
