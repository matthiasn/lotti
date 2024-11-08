import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_stats_provider.g.dart';

@riverpod
Stream<MatrixStats> matrixStatsStream(Ref ref) {
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
