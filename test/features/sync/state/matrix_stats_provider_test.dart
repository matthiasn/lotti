import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/v2_metrics.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';

void main() {
  test('V2MetricsHistory appends values and enforces 24-sample cap', () async {
    final metricsStateProvider =
        StateProvider<Map<String, int>>((ref) => const {
              'processed': 1,
              'failures': 0,
              'retriesScheduled': 0,
            });

    final container = ProviderContainer(overrides: [
      matrixV2MetricsFutureProvider.overrideWith((ref) async {
        final m = ref.watch(metricsStateProvider);
        return V2Metrics.fromMap(m);
      }),
    ]);
    addTearDown(container.dispose);

    // Instantiate notifier and allow first append
    container.read(v2MetricsHistoryProvider);
    await Future<void>.delayed(Duration.zero);

    // Append 30 updates; history should cap at 24.
    for (var i = 2; i <= 31; i++) {
      container.read(metricsStateProvider.notifier).state = {
        'processed': i,
        'failures': i % 3,
        'retriesScheduled': i % 5,
      };
      await Future<void>.delayed(Duration.zero);
    }

    final hist = container.read(v2MetricsHistoryProvider);
    expect(hist['processed']!.length, 24);
    expect(hist['failures']!.length, 24);
    expect(hist['retriesScheduled']!.length, 24);

    // The last value should be the final update (31)
    expect(hist['processed']!.last, 31);
  });

  test('V2MetricsHistory.clear resets state', () async {
    final container = ProviderContainer(overrides: [
      matrixV2MetricsFutureProvider.overrideWith((ref) async =>
          V2Metrics.fromMap(
              const {'processed': 1, 'failures': 0, 'retriesScheduled': 0})),
    ]);
    addTearDown(container.dispose);

    container.read(v2MetricsHistoryProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(v2MetricsHistoryProvider).isNotEmpty, isTrue);
    container.read(v2MetricsHistoryProvider.notifier).clear();
    expect(container.read(v2MetricsHistoryProvider), isEmpty);
  });
}
