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

class MockOutboxService extends Mock implements OutboxService {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSyncSequenceLogService mockSequenceService;
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
    mockOutboxService = MockOutboxService();
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
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
        );

        when(() => mockSequenceService.getMissingEntriesForActiveHosts(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
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
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
        );

        when(() => mockSequenceService.getMissingEntriesForActiveHosts(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
            )).thenAnswer((_) async => []);

        service.start();
        expect(service.isRunning, isTrue);

        service.stop();
        expect(service.isRunning, isFalse);

        // Elapse time - should not trigger processing
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        verifyNever(() => mockSequenceService.getMissingEntriesForActiveHosts(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
            ));

        service.dispose();
      });
    });

    test('does not process if already processing', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
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
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
        );

        when(() => mockSequenceService.getMissingEntriesForActiveHosts(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
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

        verifyNever(() => mockSequenceService.getMissingEntriesForActiveHosts(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
            ));
      });
    });

    test('handles errors gracefully', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
        );

        when(() => mockSequenceService.getMissingEntriesForActiveHosts(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
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
  });
}

SyncSequenceLogItem _createMissingLogItem(
  String hostId,
  int counter,
) {
  return SyncSequenceLogItem(
    hostId: hostId,
    counter: counter,
    originatingHostId: null,
    status: SyncSequenceStatus.missing.index,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    requestCount: 0,
  );
}
