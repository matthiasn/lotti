import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/v2_metrics.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_stats_provider.g.dart';

@riverpod
Stream<MatrixStats> matrixStatsStream(Ref ref) {
  return ref.watch(matrixServiceProvider).messageCountsController.stream;
}

@riverpod
class MatrixStatsController extends _$MatrixStatsController {
  MatrixService get _matrixService => ref.read(matrixServiceProvider);

  @override
  Future<MatrixStats> build() async {
    return ref.watch(matrixStatsStreamProvider).value ??
        MatrixStats(
          sentCount: _matrixService.sentCount,
          messageCounts: _matrixService.messageCounts,
        );
  }
}

/// Typed V2 metrics provider. Use [ref.invalidate(matrixV2MetricsFutureProvider)]
/// to trigger a refresh in the UI.
final matrixV2MetricsFutureProvider = FutureProvider<V2Metrics?>((ref) async {
  final svc = ref.watch(matrixServiceProvider);
  return svc.getV2Metrics();
});

/// Copy-diagnostics text provider for additional runtime info not represented
/// in V2Metrics (e.g., lastIgnored, lastPrefetched, dbMissingBase when not
/// included in the typed model).
final matrixDiagnosticsTextProvider = FutureProvider<String>((ref) async {
  final svc = ref.watch(matrixServiceProvider);
  return svc.getSyncDiagnosticsText();
});

/// Rolling in-memory history for a few KPI metrics to power sparklines.
/// Kept UI-side to avoid coupling to the pipeline internals.
class V2MetricsHistory extends StateNotifier<Map<String, List<int>>> {
  V2MetricsHistory(this.ref) : super(<String, List<int>>{}) {
    // Listen for typed metrics updates and append KPI values.
    ref.listen<AsyncValue<V2Metrics?>>(matrixV2MetricsFutureProvider,
        (prev, next) {
      next.whenData((v) {
        if (v == null) return;
        final map = v.toMap();
        const keys = ['processed', 'failures', 'retriesScheduled'];
        final updated = Map<String, List<int>>.from(state);
        for (final k in keys) {
          final val = map[k] ?? 0;
          final list = List<int>.from(updated[k] ?? const <int>[])..add(val);
          if (list.length > 24) list.removeAt(0);
          updated[k] = list;
        }
        state = updated;
      });
    });
  }

  final Ref ref;

  void clear() => state = <String, List<int>>{};
}

final v2MetricsHistoryProvider =
    StateNotifierProvider<V2MetricsHistory, Map<String, List<int>>>(
  V2MetricsHistory.new,
);
