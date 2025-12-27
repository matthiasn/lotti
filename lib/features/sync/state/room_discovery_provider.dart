import 'dart:async';

import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'room_discovery_provider.g.dart';

/// Represents the state of room discovery.
sealed class RoomDiscoveryState {
  const RoomDiscoveryState();
}

/// Initial state before discovery has started.
class RoomDiscoveryInitial extends RoomDiscoveryState {
  const RoomDiscoveryInitial();
}

/// Discovery is in progress.
class RoomDiscoveryLoading extends RoomDiscoveryState {
  const RoomDiscoveryLoading();
}

/// Discovery completed with results.
class RoomDiscoverySuccess extends RoomDiscoveryState {
  const RoomDiscoverySuccess(this.rooms);
  final List<SyncRoomCandidate> rooms;

  /// True if exactly one room was found.
  bool get hasSingleRoom => rooms.length == 1;

  /// True if multiple rooms were found.
  bool get hasMultipleRooms => rooms.length > 1;

  /// True if no rooms were found.
  bool get isEmpty => rooms.isEmpty;
}

/// Discovery failed with an error.
class RoomDiscoveryError extends RoomDiscoveryState {
  const RoomDiscoveryError(this.error);
  final Object error;
}

@riverpod
class RoomDiscoveryController extends _$RoomDiscoveryController {
  @override
  RoomDiscoveryState build() {
    return const RoomDiscoveryInitial();
  }

  /// Triggers room discovery and updates state accordingly.
  Future<void> discoverRooms() async {
    state = const RoomDiscoveryLoading();

    try {
      final matrixService = ref.read(matrixServiceProvider);
      final rooms = await matrixService.discoverExistingSyncRooms();
      state = RoomDiscoverySuccess(rooms);
    } catch (e) {
      state = RoomDiscoveryError(e);
    }
  }

  /// Joins the specified room and returns true on success.
  Future<bool> joinRoom(SyncRoomCandidate candidate) async {
    try {
      final matrixService = ref.read(matrixServiceProvider);
      await matrixService.joinRoom(candidate.roomId);
      return true;
    } catch (e) {
      state = RoomDiscoveryError(e);
      return false;
    }
  }

  /// Resets the state to initial.
  void reset() {
    state = const RoomDiscoveryInitial();
  }
}
