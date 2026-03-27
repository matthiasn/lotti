import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_live_scan.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_processor.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockProcessor extends Mock implements MatrixStreamProcessor {}

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
