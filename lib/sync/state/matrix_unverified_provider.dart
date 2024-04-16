import 'dart:async';

import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:matrix/matrix.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_unverified_provider.g.dart';

@riverpod
class MatrixUnverifiedController extends _$MatrixUnverifiedController {
  final _matrixService = getIt<MatrixService>();

  @override
  Future<List<DeviceKeys>> build() async {
    return _matrixService.getUnverifiedDevices();
  }
}
