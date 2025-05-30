import 'dart:async';

import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:matrix/matrix.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_unverified_provider.g.dart';

@riverpod
class MatrixUnverifiedController extends _$MatrixUnverifiedController {
  MatrixUnverifiedController() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      build();
      ref.onDispose(timer.cancel);
    });
  }

  final MatrixService _matrixService = getIt<MatrixService>();

  @override
  Future<List<DeviceKeys>> build() async {
    return _matrixService.getUnverifiedDevices();
  }
}
