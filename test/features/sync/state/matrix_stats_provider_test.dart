import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';

void main() {
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
    final container = ProviderContainer(overrides: [
      matrixSyncMetricsFutureProvider.overrideWith((ref) async =>
          SyncMetrics.fromMap(
              const {'processed': 1, 'failures': 0, 'retriesScheduled': 0})),
    ]);
    addTearDown(container.dispose);

    container.read(syncMetricsHistoryProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(syncMetricsHistoryProvider).isNotEmpty, isTrue);
    container.read(syncMetricsHistoryProvider.notifier).clear();
    expect(container.read(syncMetricsHistoryProvider), isEmpty);
  });
}
