import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
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

/// Typed metrics provider. Use [ref.invalidate(matrixSyncMetricsFutureProvider)]
/// to trigger a refresh in the UI.
final matrixSyncMetricsFutureProvider =
    FutureProvider<SyncMetrics?>((ref) async {
  final svc = ref.watch(matrixServiceProvider);
  return svc.getSyncMetrics();
});

/// Copy-diagnostics text provider for additional runtime info not represented
/// in SyncMetrics (e.g., lastIgnored, lastPrefetched, dbMissingBase when not
/// included in the typed model).
final matrixDiagnosticsTextProvider = FutureProvider<String>((ref) async {
  final svc = ref.watch(matrixServiceProvider);
  return svc.getSyncDiagnosticsText();
});

/// Rolling in-memory history for a few KPI metrics to power sparklines.
/// Kept UI-side to avoid coupling to the pipeline internals.
class SyncMetricsHistory extends StateNotifier<Map<String, List<int>>> {
  SyncMetricsHistory(this.ref) : super(<String, List<int>>{}) {
    // Listen for typed metrics updates and append KPI values.
    ref.listen<AsyncValue<SyncMetrics?>>(matrixSyncMetricsFutureProvider,
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

final syncMetricsHistoryProvider =
    StateNotifierProvider<SyncMetricsHistory, Map<String, List<int>>>(
  SyncMetricsHistory.new,
);
