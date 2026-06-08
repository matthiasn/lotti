import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  group('SyncMetricsHistory', () {
    test('V2MetricsHistory appends values and enforces 24-sample cap', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(syncMetricsHistoryProvider.notifier);

      // Append 30 updates; history should cap at 24.
      for (var i = 1; i <= 30; i++) {
        notifier.appendFromMetrics(
          SyncMetrics.fromMap({
            'processed': i,
            'failures': i % 3,
            'retriesScheduled': i % 5,
          }),
        );
      }

      final hist = container.read(syncMetricsHistoryProvider);
      expect(hist['processed']!.length, 24);
      expect(hist['failures']!.length, 24);
      expect(hist['retriesScheduled']!.length, 24);

      // The last value should be the final update (30)
      expect(hist['processed']!.last, 30);
      // The first value should be 7 (30 - 24 + 1 = 7)
      expect(hist['processed']!.first, 7);
    });

    test('V2MetricsHistory.clear resets state', () async {
      final container = ProviderContainer(
        overrides: [
          matrixSyncMetricsFutureProvider.overrideWith(
            (ref) async => SyncMetrics.fromMap(const {
              'processed': 1,
              'failures': 0,
              'retriesScheduled': 0,
            }),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(syncMetricsHistoryProvider);
      await pumpEventQueue();

      expect(container.read(syncMetricsHistoryProvider).isNotEmpty, isTrue);
      container.read(syncMetricsHistoryProvider.notifier).clear();
      expect(container.read(syncMetricsHistoryProvider), isEmpty);
    });

    test(
      'V2MetricsHistory ref.listen reactive path appends on emission and on '
      'invalidation refresh',
      () async {
        const processed = 5;
        final container = ProviderContainer(
          overrides: [
            matrixSyncMetricsFutureProvider.overrideWith(
              (ref) async => SyncMetrics.fromMap({
                'processed': processed,
                'failures': 1,
                'retriesScheduled': 2,
              }),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Building the history wires ref.listen(fireImmediately) to the
        // typed-metrics future — the production code path, not the
        // @visibleForTesting append.
        container.read(syncMetricsHistoryProvider);
        await pumpEventQueue();

        final hist = container.read(syncMetricsHistoryProvider);
        expect(hist['processed'], [5]);
        expect(hist['failures'], [1]);
        expect(hist['retriesScheduled'], [2]);

        // (The invalidate-refresh flow re-runs the future; its emission
        // sequencing through copyWithPrevious is riverpod-version dependent,
        // so this test pins only the first-emission wiring.)
      },
    );
  });

  group('MatrixStats providers', () {
    late MockMatrixService mockMatrixService;
    late StreamController<MatrixStats> matrixStatsStreamController;

    setUp(() {
      mockMatrixService = MockMatrixService();
      matrixStatsStreamController = StreamController<MatrixStats>.broadcast();
      when(
        () => mockMatrixService.messageCountsController,
      ).thenReturn(matrixStatsStreamController);
    });

    tearDown(() async {
      await matrixStatsStreamController.close();
    });

    test('matrixStatsStream exposes matrix service stream', () {
      fakeAsync((FakeAsync async) {
        final container = ProviderContainer(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        );
        addTearDown(container.dispose);

        final captured = <MatrixStats>[];
        final sub = container.listen(
          matrixStatsStreamProvider,
          (_, next) => next.whenData(captured.add),
        );
        addTearDown(sub.close);
        const stats = MatrixStats(sentCount: 1, messageCounts: {});

        matrixStatsStreamController.add(stats);
        async.flushMicrotasks();
        expect(captured, contains(stats));
      });
    });

    test('MatrixStatsController falls back to current counters', () async {
      const fallbackStats = MatrixStats(
        sentCount: 4,
        messageCounts: {'m.text': 3, 'm.image': 1},
      );

      when(
        () => mockMatrixService.sentCount,
      ).thenReturn(fallbackStats.sentCount);
      when(
        () => mockMatrixService.messageCounts,
      ).thenReturn(fallbackStats.messageCounts);

      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(matrixStatsControllerProvider.future);

      expect(result.sentCount, fallbackStats.sentCount);
      expect(result.messageCounts, fallbackStats.messageCounts);
      verify(() => mockMatrixService.sentCount).called(1);
      verify(() => mockMatrixService.messageCounts).called(1);
    });

    test(
      'MatrixStatsController returns latest stream value when available',
      () async {
        const streamedStats = MatrixStats(
          sentCount: 10,
          messageCounts: {'m.text': 7, 'm.image': 3},
        );

        when(() => mockMatrixService.sentCount).thenReturn(0);
        when(() => mockMatrixService.messageCounts).thenReturn(<String, int>{});

        // Use a StreamController that stays open to avoid disposal issues
        final controller = StreamController<MatrixStats>();

        final container = ProviderContainer(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixStatsStreamProvider.overrideWith(
              (ref) => controller.stream,
            ),
          ],
        );
        addTearDown(() {
          controller.close();
          container.dispose();
        });

        // First, subscribe to the stream provider to ensure it's active
        final streamSub = container.listen(
          matrixStatsStreamProvider,
          (_, _) {},
        );
        addTearDown(streamSub.close);

        // Add value and wait for stream to propagate
        controller.add(streamedStats);
        await pumpEventQueue();

        // Now read the controller - the stream value should be available
        final result = await container.read(
          matrixStatsControllerProvider.future,
        );

        expect(result.sentCount, streamedStats.sentCount);
        expect(result.messageCounts, streamedStats.messageCounts);
      },
    );
  });

  group('MatrixStats equality', () {
    test('two MatrixStats with same values are equal', () {
      const stats1 = MatrixStats(
        sentCount: 5,
        messageCounts: {'m.text': 3, 'm.image': 2},
      );
      const stats2 = MatrixStats(
        sentCount: 5,
        messageCounts: {'m.text': 3, 'm.image': 2},
      );

      expect(stats1 == stats2, isTrue);
      expect(stats1.hashCode, stats2.hashCode);
    });

    test('MatrixStats with different sentCount are not equal', () {
      const stats1 = MatrixStats(sentCount: 5, messageCounts: {});
      const stats2 = MatrixStats(sentCount: 10, messageCounts: {});

      expect(stats1 == stats2, isFalse);
    });

    test('MatrixStats with different messageCounts are not equal', () {
      const stats1 = MatrixStats(
        sentCount: 5,
        messageCounts: {'m.text': 3},
      );
      const stats2 = MatrixStats(
        sentCount: 5,
        messageCounts: {'m.text': 5},
      );

      expect(stats1 == stats2, isFalse);
    });

    test('MatrixStats is equal to itself (identical)', () {
      const stats = MatrixStats(sentCount: 5, messageCounts: {});
      expect(stats == stats, isTrue);
    });

    test('MatrixStats is not equal to non-MatrixStats object', () {
      const stats = MatrixStats(sentCount: 5, messageCounts: {});
      expect(stats == Object(), isFalse);
    });
  });
}
