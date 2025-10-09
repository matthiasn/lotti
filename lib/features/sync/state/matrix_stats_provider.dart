import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix.dart';
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
