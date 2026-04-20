import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_live_scan.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_processor.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class _MockProcessor extends Mock implements MatrixStreamProcessor {}

class _MockTimeline extends Mock implements Timeline {}

class _MockEvent extends Mock implements Event {}

void main() {
  late LoggingService loggingService;
  late MetricsCounters metrics;
  late _MockProcessor processor;

  setUp(() {
    loggingService = LoggingService();
    metrics = MetricsCounters(collect: true);
    processor = _MockProcessor();
  });

  MatrixStreamLiveScanController createController({
    bool initialCatchUpCompleted = true,
    bool catchUpInFlight = false,
    bool wakeCatchUpPending = false,
    bool collectMetrics = true,
    bool dropOldPayloads = false,
  }) {
    return MatrixStreamLiveScanController(
      loggingService: loggingService,
      metrics: metrics,
      collectMetrics: collectMetrics,
      dropOldPayloadsInLiveScan: dropOldPayloads,
      processor: processor,
      isInitialCatchUpCompleted: () => initialCatchUpCompleted,
      isCatchUpInFlight: () => catchUpInFlight,
      isWakeCatchUpPending: () => wakeCatchUpPending,
      startWakeCatchUp: () {},
      withInstance: (msg) => 'inst: $msg',
    );
  }

  group('MatrixStreamLiveScanController', () {
    test('can be constructed', () {
      final controller = createController();

      expect(controller, isNotNull);
    });

    test('dispose cancels timer and clears timeline', () {
      fakeAsync((async) {
        final controller = createController()
          ..scheduleLiveScan()
          ..dispose();

        // Timer should be cancelled; no crash after dispose
        async.elapse(const Duration(seconds: 1));

        // Suppress unused variable hint
        controller.hashCode;
      });
    });

    group('scheduleLiveScan', () {
      test('defers when initial catch-up not completed', () {
        fakeAsync((async) {
          createController(initialCatchUpCompleted: false).scheduleLiveScan();

          // Should record deferred metrics
          expect(
            metrics.signalLiveScanDeferredInitialCatchupIncomplete,
            greaterThan(0),
          );
        });
      });

      test('defers when catch-up is in flight', () {
        fakeAsync((async) {
          createController(catchUpInFlight: true).scheduleLiveScan();

          expect(
            metrics.signalLiveScanDeferredCatchupInFlight,
            greaterThan(0),
          );
        });
      });

      test('increments noTimeline metric when liveTimeline is null', () {
        fakeAsync((async) {
          createController().scheduleLiveScan();

          expect(metrics.signalNoTimelineCount, greaterThan(0));
        });
      });
    });

    group('flushDeferredLiveScan', () {
      test('no-op when not deferred', () {
        fakeAsync((async) {
          // Should not throw
          createController().flushDeferredLiveScan('test');
        });
      });
    });

    group('scheduleRescan', () {
      test('schedules a scan after given delay', () {
        fakeAsync((async) {
          when(() => processor.lastProcessedEventId).thenReturn(null);
          when(() => processor.lastProcessedTs).thenReturn(null);
          when(
            () => processor.wasCompletedSync(any()),
          ).thenReturn(false);

          createController().scheduleRescan(const Duration(seconds: 1));

          // Before the timer fires, there should be a pending timer
          expect(async.pendingTimers, hasLength(1));

          // After full duration, the timer fires and is consumed
          async.elapse(const Duration(seconds: 2));
          expect(async.pendingTimers, isEmpty);
        });
      });
    });

    group('scanLiveTimeline', () {
      test('returns early when liveTimeline is null', () async {
        // Should complete without error
        await createController().scanLiveTimeline();
      });

      test('returns early when initial catch-up incomplete', () async {
        await createController(
          initialCatchUpCompleted: false,
        ).scanLiveTimeline();
      });

      test('returns early when catch-up in flight', () async {
        await createController(catchUpInFlight: true).scanLiveTimeline();
      });
    });

    group('stuck-scan watchdog', () {
      test(
        'releases the guard and falls through to a fresh scan when the '
        'in-flight scan has been running past the stuck threshold',
        () async {
          // Build a minimal mock Timeline with one sync-payload event so
          // the scan reaches processOrdered.
          final logging = MockLoggingService();
          when(
            () => logging.captureEvent(
              any<String>(),
              domain: any<String>(named: 'domain'),
              subDomain: any<String>(named: 'subDomain'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => logging.captureException(
              any<Object>(),
              domain: any<String>(named: 'domain'),
              subDomain: any<String>(named: 'subDomain'),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
            ),
          ).thenAnswer((_) async {});

          final event = _MockEvent();
          when(() => event.eventId).thenReturn(r'$stuck-ev');
          when(
            () => event.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
          when(
            () => event.content,
          ).thenReturn({'msgtype': 'com.lotti.sync.message'});

          final timeline = _MockTimeline();
          when(() => timeline.events).thenReturn([event]);

          when(() => processor.lastProcessedEventId).thenReturn(null);
          when(() => processor.lastProcessedTs).thenReturn(null);
          when(() => processor.wasCompletedSync(any())).thenReturn(false);

          final hang = Completer<void>();
          when(
            () => processor.processOrdered(any()),
          ).thenAnswer((_) => hang.future);

          final controller = MatrixStreamLiveScanController(
            loggingService: logging,
            metrics: metrics,
            collectMetrics: true,
            dropOldPayloadsInLiveScan: false,
            processor: processor,
            isInitialCatchUpCompleted: () => true,
            isCatchUpInFlight: () => false,
            isWakeCatchUpPending: () => false,
            startWakeCatchUp: () {},
            withInstance: (msg) => 'inst: $msg',
          )..liveTimeline = timeline;

          final start = DateTime(2026, 4, 22, 10);
          final stuck = start.add(
            SyncTuning.liveScanStuckThreshold + const Duration(seconds: 10),
          );

          // Enter the scan under a fixed clock so `_scanStartedAt == start`.
          await withClock(Clock.fixed(start), () async {
            unawaited(controller.scanLiveTimeline());
            await Future<void>.delayed(Duration.zero);
          });

          // Schedule a new scan AFTER the stuck threshold elapsed. The
          // watchdog should detect the hang, release the guard, emit a
          // `liveScan.stuck.released` log, and schedule a fresh scan
          // instead of coalescing into the deferred counter.
          final beforeDeferred = metrics.signalLiveScanDeferredInFlight;
          withClock(Clock.fixed(stuck), controller.scheduleLiveScan);

          expect(
            metrics.signalLiveScanDeferredInFlight,
            beforeDeferred,
            reason: 'stuck-release path must NOT coalesce into deferred',
          );
          final stuckLogs = verify(
            () => logging.captureEvent(
              captureAny<String>(
                that: contains('liveScan.stuck.released'),
              ),
              domain: any<String>(named: 'domain'),
              subDomain: 'liveScan.stuck',
            ),
          ).captured;
          expect(stuckLogs, hasLength(1));
          expect(stuckLogs.single, contains('epoch=1'));

          // Release the hung scan: its finally must see the bumped epoch
          // and short-circuit without corrupting the fresh scan's state.
          hang.complete();
          await Future<void>.delayed(Duration.zero);

          // A subsequent `scheduleLiveScan` must NOT defer — i.e. the
          // stale finally did not spuriously re-assert the guard.
          final deferredBefore = metrics.signalLiveScanDeferredInFlight;
          controller.scheduleLiveScan();
          expect(
            metrics.signalLiveScanDeferredInFlight,
            deferredBefore,
            reason:
                'fresh scheduleLiveScan must not land in deferred — the '
                'stale finally from the hung scan should have been a no-op',
          );

          controller.dispose();
        },
      );

      test(
        'under the stuck threshold, a second schedule call still '
        'coalesces into the deferred counter',
        () async {
          // Guards against accidentally loosening the stuck-release path
          // to fire too eagerly. A scan that has only been running a
          // second or two must still coalesce newcomers into deferred.
          final logging = MockLoggingService();
          when(
            () => logging.captureEvent(
              any<String>(),
              domain: any<String>(named: 'domain'),
              subDomain: any<String>(named: 'subDomain'),
            ),
          ).thenAnswer((_) async {});

          final event = _MockEvent();
          when(() => event.eventId).thenReturn(r'$short-ev');
          when(
            () => event.originServerTs,
          ).thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
          when(
            () => event.content,
          ).thenReturn({'msgtype': 'com.lotti.sync.message'});

          final timeline = _MockTimeline();
          when(() => timeline.events).thenReturn([event]);

          when(() => processor.lastProcessedEventId).thenReturn(null);
          when(() => processor.lastProcessedTs).thenReturn(null);
          when(() => processor.wasCompletedSync(any())).thenReturn(false);

          final hang = Completer<void>();
          when(
            () => processor.processOrdered(any()),
          ).thenAnswer((_) => hang.future);

          final controller = MatrixStreamLiveScanController(
            loggingService: logging,
            metrics: metrics,
            collectMetrics: true,
            dropOldPayloadsInLiveScan: false,
            processor: processor,
            isInitialCatchUpCompleted: () => true,
            isCatchUpInFlight: () => false,
            isWakeCatchUpPending: () => false,
            startWakeCatchUp: () {},
            withInstance: (msg) => 'inst: $msg',
          )..liveTimeline = timeline;

          final start = DateTime(2026, 4, 22, 10);
          final short = start.add(const Duration(seconds: 2));

          await withClock(Clock.fixed(start), () async {
            unawaited(controller.scanLiveTimeline());
            await Future<void>.delayed(Duration.zero);
          });

          final before = metrics.signalLiveScanDeferredInFlight;
          withClock(Clock.fixed(short), controller.scheduleLiveScan);

          expect(
            metrics.signalLiveScanDeferredInFlight,
            before + 1,
            reason:
                'well before the stuck threshold, a concurrent '
                'scheduleLiveScan must coalesce into deferred',
          );
          verifyNever(
            () => logging.captureEvent(
              any<String>(that: contains('liveScan.stuck.released')),
              domain: any<String>(named: 'domain'),
              subDomain: any<String>(named: 'subDomain'),
            ),
          );

          hang.complete();
          await Future<void>.delayed(Duration.zero);
          controller.dispose();
        },
      );
    });

    group('test hooks', () {
      test('scheduleLiveScanTestHook is called during scheduleLiveScan', () {
        fakeAsync((async) {
          var hookCalled = false;
          final controller = createController()
            ..scheduleLiveScanTestHook = () {
              hookCalled = true;
            }
            ..scheduleLiveScan();

          expect(hookCalled, isTrue);

          controller.hashCode; // suppress unused variable
        });
      });

      test('scheduleLiveScanTestHook exception is logged, not thrown', () {
        fakeAsync((async) {
          // Should not throw
          createController()
            ..scheduleLiveScanTestHook = () {
              throw Exception('test hook error');
            }
            ..scheduleLiveScan();
        });
      });
    });
  });
}
