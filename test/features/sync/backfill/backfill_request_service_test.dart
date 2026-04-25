// ignore_for_file: cascade_invocations, avoid_redundant_argument_values

import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mocks/mocks.dart';

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

class MockSyncDatabase extends Mock implements SyncDatabase {}

class _MockQueuePipelineCoordinator extends Mock
    implements QueuePipelineCoordinator {}

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
    registerFallbackValue(Duration.zero);
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
    when(
      () => mockSyncDatabase.getPendingBackfillEntries(),
    ).thenAnswer((_) async => {});
    // Default: nothing to retire on each cycle. The request service calls
    // this at the top of every `_processBackfillRequests` pass to let the
    // contiguous-prefix watermark advance past permanently stuck counters.
    when(
      () => mockSequenceService.retireExhaustedRequestedEntries(
        maxRequestCount: any(named: 'maxRequestCount'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => mockSequenceService.retireAgedOutRequestedEntries(
        amnestyWindow: any(named: 'amnestyWindow'),
      ),
    ).thenAnswer((_) async => 0);
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
    ).thenAnswer((_) async {});
  });

  group('BackfillRequestService', () {
    test(
      'retires exhausted requested entries before loading the missing batch '
      'so a permanently stuck gap does not block the watermark indefinitely',
      () async {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
        );
        addTearDown(service.dispose);

        // `processFullBackfill` runs with `useLimits: false`, which calls
        // `getMissingEntries` (not the `WithLimits` variant); stub the
        // right selector and assert the retirement fires *before* the
        // batch load so an exhausted row is flipped to `unresolvable`
        // before a new backfill cycle picks it up.
        when(
          () => mockSequenceService.getMissingEntries(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => []);

        await service.processFullBackfill();

        verifyInOrder([
          () => mockSequenceService.retireExhaustedRequestedEntries(
            maxRequestCount: any(named: 'maxRequestCount'),
          ),
          () => mockSequenceService.retireAgedOutRequestedEntries(
            amnestyWindow: any(named: 'amnestyWindow'),
          ),
          () => mockSequenceService.getMissingEntries(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            offset: any(named: 'offset'),
          ),
        ]);
      },
    );

    test(
      'runs the age-based retirement alongside exhaustion-based retirement on '
      'every sweep, so rows that slip into `requested` via backfill-response '
      'hints (request_count bumped but last_requested_at never set) or that '
      'age out of the request window before hitting the cap still get retired',
      () async {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          amnestyWindow: const Duration(days: 3),
        );
        addTearDown(service.dispose);

        when(
          () => mockSequenceService.getMissingEntries(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => []);

        await service.processFullBackfill();

        verify(
          () => mockSequenceService.retireAgedOutRequestedEntries(
            amnestyWindow: const Duration(days: 3),
          ),
        ).called(1);
      },
    );

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
        when(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => []);

        service.start();
        async.flushMicrotasks();

        // Elapse first interval
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        verify(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).called(1);

        // Elapse second interval
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        verify(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).called(1);

        service.dispose();
      });
    });

    test(
      'passes missingDebounce (from SyncTuning) to the sequence log so '
      'rows freshly detected as missing are held back for 10 minutes — '
      'lets the standard sync path deliver out-of-order entries before '
      'backfill fires',
      () {
        fakeAsync((async) {
          final service = BackfillRequestService(
            sequenceLogService: mockSequenceService,
            syncDatabase: mockSyncDatabase,
            outboxService: mockOutboxService,
            vectorClockService: mockVcService,
            loggingService: mockLogging,
            requestInterval: const Duration(seconds: 10),
          );

          when(
            () => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              minAge: any(named: 'minAge'),
              maxPerHost: any(named: 'maxPerHost'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((_) async => []);

          service.start();
          async
            ..elapse(const Duration(seconds: 10))
            ..flushMicrotasks();

          verify(
            () => mockSequenceService.getMissingEntriesWithLimits(
              limit: any(named: 'limit'),
              maxRequestCount: any(named: 'maxRequestCount'),
              maxAge: any(named: 'maxAge'),
              minAge: SyncTuning.backfillMissingDebounce,
              maxPerHost: any(named: 'maxPerHost'),
              offset: any(named: 'offset'),
            ),
          ).called(1);

          service.dispose();
        });
      },
    );

    test(
      'processFullBackfill bypasses the debounce — a user-initiated '
      'full backfill must not be silently held back for 10 minutes',
      () async {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
        );

        when(
          () => mockSequenceService.getMissingEntries(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => []);

        await service.processFullBackfill();

        // getMissingEntries (not the WithLimits variant) is called without
        // any minAge — the manual path does NOT debounce.
        verify(
          () => mockSequenceService.getMissingEntries(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            offset: any(named: 'offset'),
          ),
        ).called(1);
        verifyNever(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        );
      },
    );

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

        when(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => missingEntries);

        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});

        when(
          () => mockSequenceService.markAsRequested(any()),
        ).thenAnswer((_) async {});

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

    test('nudge sends backfill requests immediately', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(minutes: 10),
        );

        final missingEntries = [
          _createMissingLogItem(aliceHostId, 3),
          _createMissingLogItem(aliceHostId, 4),
        ];

        when(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => missingEntries);
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockSequenceService.markAsRequested(any()),
        ).thenAnswer((_) async {});

        service.nudge();
        async.flushMicrotasks();

        verify(
          () => mockOutboxService.enqueueMessage(any()),
        ).called(1);
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

        when(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: maxBatch,
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer(
          (_) async => [
            _createMissingLogItem(aliceHostId, 1),
            _createMissingLogItem(aliceHostId, 2),
          ],
        );

        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockSequenceService.markAsRequested(any()),
        ).thenAnswer((_) async {});

        service.start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        verify(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: maxBatch,
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).called(1);

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

        when(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer(
          (_) async => [
            _createMissingLogItem(aliceHostId, 1),
          ],
        );

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
        when(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          // Simulate slow processing (longer than interval)
          await Future<void>.delayed(const Duration(seconds: 8));
          return [];
        });

        service.start();
        async.flushMicrotasks();

        // Trigger first processing at 5s
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Timer fires again at 10s while still processing - should be ignored
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Complete the first processing at 13s (5s + 8s delay)
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        // Only one call should have been made despite two timer fires
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

        when(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => []);

        service.start();
        async.flushMicrotasks();

        service.dispose();

        // Try to start again after dispose - should not work
        service.start();
        async.flushMicrotasks();

        // Elapse time - timer should not fire after dispose
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        verifyNever(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        );
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

        when(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).thenThrow(Exception('Database error'));

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

        // Service should still be running - verify by elapsing another interval
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        // Exception should be logged again (timer still firing)
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

    test('processFullBackfill uses getMissingEntries without host filtering', () {
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
        when(
          () => mockSequenceService.getMissingEntries(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
          ),
        ).thenAnswer((_) async => missingEntries);

        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockSequenceService.markAsRequested(any()),
        ).thenAnswer((_) async {});

        // Call processFullBackfill (ignores enabled flag)
        service.processFullBackfill();
        async.flushMicrotasks();

        // Should use getMissingEntries (no host activity filter)
        verify(
          () => mockSequenceService.getMissingEntries(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
          ),
        ).called(1);

        // Should NOT use getMissingEntriesWithLimits (that's for automatic backfill)
        verifyNever(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        );

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
        verifyNever(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        );

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

        when(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => missingEntries);

        // Entry 2 is already in outbox
        when(() => mockSyncDatabase.getPendingBackfillEntries()).thenAnswer(
          (_) async => {(hostId: aliceHostId, counter: 2)},
        );

        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockSequenceService.markAsRequested(any()),
        ).thenAnswer((_) async {});

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

        when(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => missingEntries);

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

    test('automatic backfill paginates past a fully queued first page', () {
      fakeAsync((async) {
        final service = BackfillRequestService(
          sequenceLogService: mockSequenceService,
          syncDatabase: mockSyncDatabase,
          outboxService: mockOutboxService,
          vectorClockService: mockVcService,
          loggingService: mockLogging,
          requestInterval: const Duration(seconds: 5),
          maxBatchSize: 2,
        );

        final batch1 = [
          _createMissingLogItem(aliceHostId, 1),
          _createMissingLogItem(aliceHostId, 2),
        ];
        final batch2 = [
          _createMissingLogItem(aliceHostId, 3),
        ];

        when(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((inv) async {
          final offset = inv.namedArguments[#offset] as int;
          if (offset == 0) return batch1;
          if (offset == 2) return batch2;
          return [];
        });

        when(() => mockSyncDatabase.getPendingBackfillEntries()).thenAnswer(
          (_) async => {
            (hostId: aliceHostId, counter: 1),
            (hostId: aliceHostId, counter: 2),
          },
        );
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockSequenceService.markAsRequested(any()),
        ).thenAnswer((_) async {});

        service.start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;
        final request = captured.single as SyncBackfillRequest;
        expect(request.entries.map((e) => e.counter).toList(), [3]);

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

          // Second call returns empty to stop pagination
          when(
            () => mockSequenceService.getRequestedEntries(
              limit: 50,
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((inv) async {
            final offset = inv.namedArguments[#offset] as int;
            if (offset == 0) return requestedEntries;
            return [];
          });

          when(
            () => mockSequenceService.resetRequestCounts(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockSequenceService.markAsRequested(any()),
          ).thenAnswer((_) async {});

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

          when(
            () => mockSequenceService.getRequestedEntries(
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((_) async => []);

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

          when(
            () => mockSequenceService.getRequestedEntries(
              limit: 50,
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((inv) async {
            final offset = inv.namedArguments[#offset] as int;
            return offset == 0 ? requestedEntries : [];
          });

          // Entry 11 is already queued
          when(() => mockSyncDatabase.getPendingBackfillEntries()).thenAnswer(
            (_) async => {(hostId: aliceHostId, counter: 11)},
          );

          when(
            () => mockSequenceService.resetRequestCounts(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockSequenceService.markAsRequested(any()),
          ).thenAnswer((_) async {});

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

      test('paginates past a fully queued first page', () {
        fakeAsync((async) {
          final service = BackfillRequestService(
            sequenceLogService: mockSequenceService,
            syncDatabase: mockSyncDatabase,
            outboxService: mockOutboxService,
            vectorClockService: mockVcService,
            loggingService: mockLogging,
            requestInterval: const Duration(minutes: 5),
            maxBatchSize: 2,
          );

          final batch1 = [
            _createRequestedLogItem(aliceHostId, 10),
            _createRequestedLogItem(aliceHostId, 11),
          ];
          final batch2 = [
            _createRequestedLogItem(aliceHostId, 12),
          ];

          when(
            () => mockSequenceService.getRequestedEntries(
              limit: 2,
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((inv) async {
            final offset = inv.namedArguments[#offset] as int;
            if (offset == 0) return batch1;
            if (offset == 2) return batch2;
            return [];
          });

          when(() => mockSyncDatabase.getPendingBackfillEntries()).thenAnswer(
            (_) async => {
              (hostId: aliceHostId, counter: 10),
              (hostId: aliceHostId, counter: 11),
            },
          );

          when(
            () => mockSequenceService.resetRequestCounts(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockSequenceService.markAsRequested(any()),
          ).thenAnswer((_) async {});

          int? result;
          service.processReRequest().then((r) => result = r);
          async.flushMicrotasks();

          expect(result, 1);
          final captured = verify(
            () => mockOutboxService.enqueueMessage(captureAny()),
          ).captured;
          final request = captured.single as SyncBackfillRequest;
          expect(request.entries.map((e) => e.counter).toList(), [12]);

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
          verifyNever(
            () => mockSequenceService.getRequestedEntries(
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          );

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

          when(
            () => mockSequenceService.getRequestedEntries(
              limit: 50,
              offset: any(named: 'offset'),
            ),
          ).thenThrow(Exception('Database error'));

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
          when(
            () => mockSequenceService.getRequestedEntries(
              limit: 50,
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((_) async {
            getRequestedCallCount++;
            // Simulate slow processing
            await Future<void>.delayed(const Duration(seconds: 2));
            return [];
          });

          // Start first processReRequest
          service.processReRequest();
          async.flushMicrotasks();

          // Try to start another while first is processing - should return 0
          int? result;
          service.processReRequest().then((r) => result = r);
          async.flushMicrotasks();

          // Second call returns 0 immediately since processing is in progress
          expect(result, 0);

          // Complete the first processing
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();

          // Only one call to getRequestedEntries (second was rejected)
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

      test('sweeps agent entity/link files on re-request', () {
        fakeAsync((async) {
          final tmp = Directory.systemTemp.createTempSync('backfill_sweep');
          addTearDown(() => tmp.deleteSync(recursive: true));

          // Pre-create zombie files for agent entities and links
          final agentEntityFile =
              File(
                  '${tmp.path}/agent_entities/entity-1.json',
                )
                ..createSync(recursive: true)
                ..writeAsStringSync('{"stale":"data"}');
          final agentLinkFile =
              File(
                  '${tmp.path}/agent_links/link-2.json',
                )
                ..createSync(recursive: true)
                ..writeAsStringSync('{"stale":"link"}');

          final service = BackfillRequestService(
            sequenceLogService: mockSequenceService,
            syncDatabase: mockSyncDatabase,
            outboxService: mockOutboxService,
            vectorClockService: mockVcService,
            loggingService: mockLogging,
            documentsDirectory: tmp,
            requestInterval: const Duration(minutes: 5),
            maxBatchSize: 50,
          );

          final requestedEntries = [
            _createRequestedLogItemWithPayload(
              aliceHostId,
              10,
              entryId: 'entity-1',
              payloadType: SyncSequencePayloadType.agentEntity,
            ),
            _createRequestedLogItemWithPayload(
              aliceHostId,
              11,
              entryId: 'link-2',
              payloadType: SyncSequencePayloadType.agentLink,
            ),
            _createRequestedLogItemWithPayload(
              aliceHostId,
              12,
              entryId: 'journal-3',
              payloadType: SyncSequencePayloadType.journalEntity,
            ),
          ];

          when(
            () => mockSequenceService.getRequestedEntries(
              limit: 50,
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((inv) async {
            final offset = inv.namedArguments[#offset] as int;
            return offset == 0 ? requestedEntries : [];
          });

          when(
            () => mockSequenceService.resetRequestCounts(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockSequenceService.markAsRequested(any()),
          ).thenAnswer((_) async {});

          service.processReRequest();
          async.flushMicrotasks();

          // Agent entity file should be deleted
          expect(agentEntityFile.existsSync(), isFalse);
          // Agent link file should be deleted
          expect(agentLinkFile.existsSync(), isFalse);

          service.dispose();
        });
      });

      test('sweeps journal entity files using jsonPath from sequence log', () {
        fakeAsync((async) {
          final tmp = Directory.systemTemp.createTempSync('backfill_sweep_jp');
          addTearDown(() => tmp.deleteSync(recursive: true));

          // Pre-create a zombie journal entity file
          final journalFile =
              File(
                  '${tmp.path}/text/2026-03-12/journal-3.text.json',
                )
                ..createSync(recursive: true)
                ..writeAsStringSync('{"stale":"journal"}');

          final service = BackfillRequestService(
            sequenceLogService: mockSequenceService,
            syncDatabase: mockSyncDatabase,
            outboxService: mockOutboxService,
            vectorClockService: mockVcService,
            loggingService: mockLogging,
            documentsDirectory: tmp,
            requestInterval: const Duration(minutes: 5),
            maxBatchSize: 50,
          );

          final requestedEntries = [
            _createRequestedLogItemWithJsonPath(
              aliceHostId,
              12,
              entryId: 'journal-3',
              payloadType: SyncSequencePayloadType.journalEntity,
              jsonPath: '/text/2026-03-12/journal-3.text.json',
            ),
          ];

          when(
            () => mockSequenceService.getRequestedEntries(
              limit: 50,
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((inv) async {
            final offset = inv.namedArguments[#offset] as int;
            return offset == 0 ? requestedEntries : [];
          });

          when(
            () => mockSequenceService.resetRequestCounts(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockSequenceService.markAsRequested(any()),
          ).thenAnswer((_) async {});

          service.processReRequest();
          async.flushMicrotasks();

          // Journal entity file should be deleted using jsonPath
          expect(journalFile.existsSync(), isFalse);

          service.dispose();
        });
      });

      test(
        'blocks path traversal when sweeping derived agent payload paths',
        () {
          fakeAsync((async) {
            final root = Directory.systemTemp.createTempSync(
              'backfill_sweep_safe',
            );
            addTearDown(() => root.deleteSync(recursive: true));
            final tmp = Directory(p.join(root.path, 'docs'))..createSync();

            final escapedPath = p.normalize(
              p.join(tmp.path, 'agent_entities/../../escape.json'),
            );
            expect(p.isWithin(tmp.path, escapedPath), isFalse);
            // The escaped file lands inside root but outside tmp (docs dir)
            final escapedFile = File(escapedPath)
              ..createSync(recursive: true)
              ..writeAsStringSync('keep-me');

            final service = BackfillRequestService(
              sequenceLogService: mockSequenceService,
              syncDatabase: mockSyncDatabase,
              outboxService: mockOutboxService,
              vectorClockService: mockVcService,
              loggingService: mockLogging,
              documentsDirectory: tmp,
              requestInterval: const Duration(minutes: 5),
              maxBatchSize: 50,
            );

            final requestedEntries = [
              _createRequestedLogItemWithPayload(
                aliceHostId,
                10,
                entryId: '../../escape',
                payloadType: SyncSequencePayloadType.agentEntity,
              ),
            ];

            when(
              () => mockSequenceService.getRequestedEntries(
                limit: 50,
                offset: any(named: 'offset'),
              ),
            ).thenAnswer((inv) async {
              final offset = inv.namedArguments[#offset] as int;
              return offset == 0 ? requestedEntries : [];
            });
            when(
              () => mockSequenceService.resetRequestCounts(any()),
            ).thenAnswer((_) async {});
            when(
              () => mockOutboxService.enqueueMessage(any()),
            ).thenAnswer((_) async {});
            when(
              () => mockSequenceService.markAsRequested(any()),
            ).thenAnswer((_) async {});

            service.processReRequest();
            async.flushMicrotasks();

            expect(escapedFile.existsSync(), isTrue);

            service.dispose();
          });
        },
      );

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

          when(
            () => mockSequenceService.getRequestedEntries(
              limit: 2,
              offset: any(named: 'offset'),
            ),
          ).thenAnswer((inv) async {
            final offset = inv.namedArguments[#offset] as int;
            if (offset == 0) return batch1;
            if (offset == 2) return batch2;
            return [];
          });

          when(
            () => mockSequenceService.resetRequestCounts(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockSequenceService.markAsRequested(any()),
          ).thenAnswer((_) async {});

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

    group('bridge-walk suppression', () {
      final missingItems = [
        _createMissingLogItem(aliceHostId, 42),
        _createMissingLogItem(aliceHostId, 43),
      ];

      void stubMissingFetch() {
        when(
          () => mockSequenceService.getMissingEntriesWithLimits(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            maxAge: any(named: 'maxAge'),
            minAge: any(named: 'minAge'),
            maxPerHost: any(named: 'maxPerHost'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => missingItems);
        when(
          () => mockSequenceService.getMissingEntries(
            limit: any(named: 'limit'),
            maxRequestCount: any(named: 'maxRequestCount'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => missingItems);
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockSequenceService.markAsRequested(any()),
        ).thenAnswer((_) async {});
      }

      test(
        'skips analysis+dispatch while the bridge is forward-walking '
        'the timeline — gaps in the sequence log may be closed by '
        'events still in the pipe, so asking peers now would race '
        'ahead of the inbound path and emit a bogus request',
        () {
          fakeAsync((async) {
            stubMissingFetch();
            final coordinator = _MockQueuePipelineCoordinator();
            when(() => coordinator.isBridgeInFlight).thenReturn(true);

            final service = BackfillRequestService(
              sequenceLogService: mockSequenceService,
              syncDatabase: mockSyncDatabase,
              outboxService: mockOutboxService,
              vectorClockService: mockVcService,
              loggingService: mockLogging,
              queueCoordinator: coordinator,
            );
            addTearDown(service.dispose);

            service.nudge();
            async.flushMicrotasks();

            verifyNever(() => mockOutboxService.enqueueMessage(any()));
            verifyNever(
              () => mockSequenceService.getMissingEntriesWithLimits(
                limit: any(named: 'limit'),
                maxRequestCount: any(named: 'maxRequestCount'),
                maxAge: any(named: 'maxAge'),
                maxPerHost: any(named: 'maxPerHost'),
                offset: any(named: 'offset'),
              ),
            );
          });
        },
      );

      test(
        'dispatches normally once the bridge walk has concluded',
        () {
          fakeAsync((async) {
            stubMissingFetch();
            final coordinator = _MockQueuePipelineCoordinator();
            when(() => coordinator.isBridgeInFlight).thenReturn(false);

            final service = BackfillRequestService(
              sequenceLogService: mockSequenceService,
              syncDatabase: mockSyncDatabase,
              outboxService: mockOutboxService,
              vectorClockService: mockVcService,
              loggingService: mockLogging,
              queueCoordinator: coordinator,
            );
            addTearDown(service.dispose);

            service.nudge();
            async.flushMicrotasks();

            verify(() => mockOutboxService.enqueueMessage(any())).called(1);
          });
        },
      );

      test(
        'manual full backfill bypasses the bridge gate so a user '
        'action is never silently swallowed',
        () async {
          stubMissingFetch();
          final coordinator = _MockQueuePipelineCoordinator();
          when(() => coordinator.isBridgeInFlight).thenReturn(true);

          final service = BackfillRequestService(
            sequenceLogService: mockSequenceService,
            syncDatabase: mockSyncDatabase,
            outboxService: mockOutboxService,
            vectorClockService: mockVcService,
            loggingService: mockLogging,
            queueCoordinator: coordinator,
          );
          addTearDown(service.dispose);

          await service.processFullBackfill();

          verify(() => mockOutboxService.enqueueMessage(any())).called(1);
        },
      );
    });

    group('nudgeAfterDrain', () {
      test(
        'collapses the missing-debounce minAge to zero so a row freshly '
        'flagged missing during catch-up is requested as soon as the '
        'inbound queue empties — the original 10-minute debounce only '
        'protects against in-flight reordering and is no longer '
        'load-bearing once the queue is genuinely drained',
        () {
          fakeAsync((async) {
            when(
              () => mockSequenceService.getMissingEntriesWithLimits(
                limit: any(named: 'limit'),
                maxRequestCount: any(named: 'maxRequestCount'),
                maxAge: any(named: 'maxAge'),
                minAge: any(named: 'minAge'),
                maxPerHost: any(named: 'maxPerHost'),
                offset: any(named: 'offset'),
              ),
            ).thenAnswer((_) async => [_createMissingLogItem(aliceHostId, 99)]);
            when(
              () => mockOutboxService.enqueueMessage(any()),
            ).thenAnswer((_) async {});
            when(
              () => mockSequenceService.markAsRequested(any()),
            ).thenAnswer((_) async {});

            final service = BackfillRequestService(
              sequenceLogService: mockSequenceService,
              syncDatabase: mockSyncDatabase,
              outboxService: mockOutboxService,
              vectorClockService: mockVcService,
              loggingService: mockLogging,
              requestInterval: const Duration(minutes: 10),
            );
            addTearDown(service.dispose);

            service.nudgeAfterDrain();
            async.flushMicrotasks();

            final captured = verify(
              () => mockSequenceService.getMissingEntriesWithLimits(
                limit: any(named: 'limit'),
                maxRequestCount: any(named: 'maxRequestCount'),
                maxAge: any(named: 'maxAge'),
                minAge: captureAny(named: 'minAge'),
                maxPerHost: any(named: 'maxPerHost'),
                offset: any(named: 'offset'),
              ),
            ).captured;
            expect(captured.single, Duration.zero);
            verify(() => mockOutboxService.enqueueMessage(any())).called(1);
          });
        },
      );

      test(
        'a periodic timer pass after a drain-bypass call still applies '
        'the debounce — the bypass is a one-shot flavor, not a sticky '
        'mode change',
        () {
          fakeAsync((async) {
            when(
              () => mockSequenceService.getMissingEntriesWithLimits(
                limit: any(named: 'limit'),
                maxRequestCount: any(named: 'maxRequestCount'),
                maxAge: any(named: 'maxAge'),
                minAge: any(named: 'minAge'),
                maxPerHost: any(named: 'maxPerHost'),
                offset: any(named: 'offset'),
              ),
            ).thenAnswer((_) async => []);

            final service = BackfillRequestService(
              sequenceLogService: mockSequenceService,
              syncDatabase: mockSyncDatabase,
              outboxService: mockOutboxService,
              vectorClockService: mockVcService,
              loggingService: mockLogging,
              requestInterval: const Duration(minutes: 10),
              missingDebounce: const Duration(minutes: 7),
            );
            addTearDown(service.dispose);

            service.nudgeAfterDrain();
            async.flushMicrotasks();
            service.nudge();
            async.flushMicrotasks();

            final captured = verify(
              () => mockSequenceService.getMissingEntriesWithLimits(
                limit: any(named: 'limit'),
                maxRequestCount: any(named: 'maxRequestCount'),
                maxAge: any(named: 'maxAge'),
                minAge: captureAny(named: 'minAge'),
                maxPerHost: any(named: 'maxPerHost'),
                offset: any(named: 'offset'),
              ),
            ).captured;
            expect(
              captured,
              equals([Duration.zero, const Duration(minutes: 7)]),
              reason:
                  'first call (drain bypass) clears minAge; second call '
                  '(periodic / nudge) restores the configured debounce',
            );
          });
        },
      );
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

SyncSequenceLogItem _createRequestedLogItemWithPayload(
  String hostId,
  int counter, {
  required String entryId,
  required SyncSequencePayloadType payloadType,
}) {
  return SyncSequenceLogItem(
    hostId: hostId,
    counter: counter,
    entryId: entryId,
    payloadType: payloadType.index,
    originatingHostId: null,
    status: SyncSequenceStatus.requested.index,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    requestCount: 10,
  );
}

SyncSequenceLogItem _createRequestedLogItemWithJsonPath(
  String hostId,
  int counter, {
  required String entryId,
  required SyncSequencePayloadType payloadType,
  required String jsonPath,
}) {
  return SyncSequenceLogItem(
    hostId: hostId,
    counter: counter,
    entryId: entryId,
    payloadType: payloadType.index,
    originatingHostId: null,
    status: SyncSequenceStatus.requested.index,
    jsonPath: jsonPath,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    requestCount: 10,
  );
}
