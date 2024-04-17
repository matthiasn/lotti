import 'dart:async';

import 'package:lotti/get_it.dart';
import 'package:lotti/sync/matrix/matrix_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_room_provider.g.dart';

@riverpod
class MatrixRoomController extends _$MatrixRoomController {
  final _matrixService = getIt<MatrixService>();

  @override
  Future<String?> build() async {
    return _matrixService.getRoom();
  }

  Future<void> createRoom() async {
    await _matrixService.createRoom();
    ref.invalidateSelf();
  }

  Future<void> leaveRoom() async {
    await _matrixService.leaveRoom();
    ref.invalidateSelf();
  }
}
