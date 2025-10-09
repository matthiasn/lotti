import 'dart:async';

import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_room_provider.g.dart';

@riverpod
class MatrixRoomController extends _$MatrixRoomController {
  MatrixService get _matrixService => ref.read(matrixServiceProvider);

  @override
  Future<String?> build() async {
    return ref.watch(matrixServiceProvider).getRoom();
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
