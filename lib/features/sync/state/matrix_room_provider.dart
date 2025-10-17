import 'dart:async';

import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'matrix_room_provider.g.dart';

@riverpod
class MatrixRoomController extends _$MatrixRoomController {
  MatrixService get _matrixService => ref.read(matrixServiceProvider);
  final Set<String> _invitesInFlight = <String>{};

  @override
  Future<String?> build() async {
    return ref.watch(matrixServiceProvider).getRoom();
  }

  Future<void> createRoom() async {
    await _matrixService.createRoom();
    ref.invalidateSelf();
  }

  Future<void> inviteToRoom(String userId) async {
    // Prevent duplicate invites while one is in-flight for the same user.
    // This complements the UI one-shot guard in the QR scanner.
    final roomId = await _matrixService.getRoom();
    final key = '${roomId ?? 'null'}:$userId';
    if (_invitesInFlight.contains(key)) {
      // Silent no-op to avoid spamming the server; the UI already pauses scanning.
      return;
    }
    _invitesInFlight.add(key);
    try {
      await _matrixService.inviteToSyncRoom(userId: userId);
    } finally {
      _invitesInFlight.remove(key);
    }
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
