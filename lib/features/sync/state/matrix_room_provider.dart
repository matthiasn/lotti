import 'dart:async';

import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
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

  Future<void> inviteToRoom(String userId) async {
    await _matrixService.inviteToSyncRoom(userId: userId);
  }

  Future<void> joinRoom(String roomId) async {
    await _matrixService.saveRoom(roomId);
    await _matrixService.joinRoom(roomId);
  }

  Future<void> leaveRoom() async {
    await _matrixService.leaveRoom();
    ref.invalidateSelf();
  }
}
