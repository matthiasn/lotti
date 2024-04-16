import 'dart:async';

import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:lotti/sync/matrix/stats.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_stats_provider.g.dart';

@riverpod
Stream<MatrixStats> matrixStatsStream(MatrixStatsStreamRef ref) {
  return getIt<MatrixService>().messageCountsController.stream;
}

@riverpod
class MatrixStatsController extends _$MatrixStatsController {
  final _matrixService = getIt<MatrixService>();

  @override
  Future<MatrixStats> build() async {
    return ref.watch(matrixStatsStreamProvider).value ??
        MatrixStats(
          sentCount: _matrixService.sentCount,
          messageCounts: _matrixService.messageCounts,
        );
  }
}
