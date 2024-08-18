import 'dart:async';

import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_config_provider.g.dart';

@riverpod
class MatrixConfigController extends _$MatrixConfigController {
  final _matrixService = getIt<MatrixService>();

  @override
  Future<MatrixConfig?> build() async {
    return _matrixService.loadConfig();
  }

  Future<void> setConfig(MatrixConfig config) =>
      _matrixService.setConfig(config);

  Future<void> deleteConfig() => _matrixService.deleteConfig();
}
