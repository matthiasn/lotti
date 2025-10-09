import 'dart:async';

import 'package:lotti/providers/service_providers.dart';
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

  @override
  Future<List<DeviceKeys>> build() async {
    return ref.watch(matrixServiceProvider).getUnverifiedDevices();
  }
}
