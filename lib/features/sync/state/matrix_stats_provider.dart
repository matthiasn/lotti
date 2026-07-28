import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/providers/service_providers.dart';

/// Streams live message-count [MatrixStats] from the Matrix service for the
/// stats UI.
final StreamProvider<MatrixStats> matrixStatsStreamProvider =
    StreamProvider.autoDispose<MatrixStats>(
      matrixStatsStream,
      name: 'matrixStatsStreamProvider',
    );
Stream<MatrixStats> matrixStatsStream(Ref ref) {
  return ref.watch(matrixServiceProvider).messageCountsController.stream;
}

/// Exposes the latest [MatrixStats], seeded from the service's current counts
/// and then kept live by [matrixStatsStream].
final AsyncNotifierProvider<MatrixStatsController, MatrixStats>
matrixStatsControllerProvider =
    AsyncNotifierProvider.autoDispose<MatrixStatsController, MatrixStats>(
      MatrixStatsController.new,
      name: 'matrixStatsControllerProvider',
    );

class MatrixStatsController extends AsyncNotifier<MatrixStats> {
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
final matrixSyncMetricsFutureProvider = FutureProvider<SyncMetrics?>((
  ref,
) async {
  final svc = ref.watch(matrixServiceProvider);
  return svc.getSyncMetrics();
});

/// Copy-diagnostics text provider for additional runtime info not represented
/// in SyncMetrics (e.g., lastIgnored, dbMissingBase when not
/// included in the typed model).
final matrixDiagnosticsTextProvider = FutureProvider<String>((ref) async {
  final svc = ref.watch(matrixServiceProvider);
  return svc.getSyncDiagnosticsText();
});
