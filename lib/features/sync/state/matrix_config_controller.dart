import 'dart:async';

import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_config_controller.g.dart';

@riverpod
class MatrixConfigController extends _$MatrixConfigController {
  MatrixService get _matrixService => ref.read(matrixServiceProvider);

  @override
  Future<MatrixConfig?> build() async {
    return ref.watch(matrixServiceProvider).loadConfig();
  }

  Future<void> setConfig(MatrixConfig config) =>
      _matrixService.setConfig(config);

  Future<void> deleteConfig() => _matrixService.deleteConfig();
}
