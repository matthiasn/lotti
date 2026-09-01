import 'dart:async';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

const int kSyncRoomLoadMaxAttempts = 4;
const int kSyncRoomLoadBaseDelayMs = 1000;

/// Handles sync-room persistence and the create/join/hydrate flows.
///
/// Devices never discover a sync room. A pairing bundle carries the room id,
/// so a device joining from one simply joins the room it was told about; the
/// account's very first device, signing in with its own credentials on Linux,
/// creates the room instead (both in `ProvisioningController`). This manager
/// owns the persisted pointer to that room and the retry loop that resolves it
/// once the homeserver has synced.
class SyncRoomManager {
  SyncRoomManager({
    required this._gateway,
    required this._settingsDb,
    required this._loggingService,
  });

  final MatrixSyncGateway _gateway;
  final SettingsDb _settingsDb;
  final DomainLogger _loggingService;

  /// Emits whenever the sync room changes, including when it is cleared.
  ///
  /// `currentRoomId` is a plain field, so UI that gates on "is sync
  /// configured" had nothing to rebuild on. That matters most for the clear
  /// path: `SyncSessionManager.connect()` drops a persisted room the account
  /// can no longer join *after* the login event has already fired, so a
  /// login-only signal leaves the device roster on screen for a room that no
  /// longer exists.
  final StreamController<String?> _roomIdController =
      StreamController<String?>.broadcast();

  Room? _currentRoom;
  String? _currentRoomId;

  /// The currently joined sync room, if any.
  Room? get currentRoom => _currentRoom;

  /// Identifier of the current sync room, if available.
  String? get currentRoomId => _currentRoomId;

  /// The sync room id on every change, null when cleared.
  Stream<String?> get roomIdChanges => _roomIdController.stream;

  /// Single write point for [currentRoomId] so no mutation can skip the
  /// notification. Silent when the value is unchanged.
  void _setCurrentRoomId(String? roomId) {
    if (_currentRoomId == roomId) return;
    _currentRoomId = roomId;
    if (!_roomIdController.isClosed) _roomIdController.add(roomId);
  }

  /// Loads any persisted room identifier and resolves the current room snapshot
  /// if the Matrix client has already synced it.
  Future<void> initialize() async {
    final savedRoomId = await loadPersistedRoomId();
    if (savedRoomId == null) {
      return;
    }

    _resolveRoomSnapshot(savedRoomId, subDomain: 'initialize');
  }

  /// Creates the account's encrypted sync room — the gateway marks it with the
  /// Lotti sync-room state event — persists its identifier and returns it.
  /// Errors bubble up to the caller so they can surface UI feedback.
  Future<String> createRoom({required String name}) async {
    final roomId = await _gateway.createRoom(name: name);
    await _settingsDb.saveSettingsItem(matrixRoomKey, roomId);
    _updateCurrentRoom(roomId);
    _loggingService.log(
      LogDomain.sync,
      'Created sync room $roomId.',
      subDomain: 'createRoom',
    );
    return roomId;
  }

  /// Persistently saves the provided room ID without joining. Useful for manual
  /// entry flows where the join occurs separately.
  Future<void> saveRoomId(String roomId) async {
    await _settingsDb.saveSettingsItem(matrixRoomKey, roomId);
    _updateCurrentRoom(roomId);
  }

  /// Joins the provided room and persists the identifier. Errors bubble up to
  /// the caller so they can surface UI feedback.
  Future<Room?> joinRoom(String roomId) async {
    await _gateway.joinRoom(roomId);
    await _settingsDb.saveSettingsItem(matrixRoomKey, roomId);
    return _updateCurrentRoom(roomId);
  }

  /// Clears any persisted sync room locally without contacting the server.
  /// Useful when the server reports that this device is not invited/in the
  /// room anymore during startup.
  Future<void> clearPersistedRoom({String subDomain = 'clearPersisted'}) async {
    final previous = _currentRoomId;
    await _settingsDb.removeSettingsItem(matrixRoomKey);
    _currentRoom = null;
    _setCurrentRoomId(null);
    _loggingService.log(
      LogDomain.sync,
      'Cleared persisted sync room (was: ${previous ?? 'none'}).',
      subDomain: subDomain,
    );
  }

  /// Loads the persisted room identifier (if any) without altering in-memory
  /// state. Subsequent calls reuse the cached copy.
  Future<String?> loadPersistedRoomId() async {
    if (_currentRoomId != null) {
      return _currentRoomId;
    }

    final savedRoomId = await _settingsDb.itemByKey(matrixRoomKey);
    if (savedRoomId != null) {
      _setCurrentRoomId(savedRoomId);
    }
    return savedRoomId;
  }

  /// Ensures the persisted room is available from the Matrix client, retrying
  /// while the homeserver completes initial sync.
  Future<void> hydrateRoomSnapshot({required Client client}) async {
    final savedRoomId = await loadPersistedRoomId();
    if (savedRoomId == null) {
      _loggingService.log(
        LogDomain.sync,
        'No saved room ID found during hydrateRoomSnapshot.',
        subDomain: 'hydrate',
      );
      return;
    }

    for (var attempt = 0; attempt < kSyncRoomLoadMaxAttempts; attempt++) {
      await client.sync();
      final room = _resolveRoomSnapshot(
        savedRoomId,
        subDomain: 'hydrate',
      );
      if (room != null) {
        return;
      }

      if (attempt < kSyncRoomLoadMaxAttempts - 1) {
        final delay = Duration(
          milliseconds: kSyncRoomLoadBaseDelayMs * (1 << attempt),
        );
        _loggingService.log(
          LogDomain.sync,
          'Room $savedRoomId not yet available, retrying in '
          '${delay.inMilliseconds}ms (attempt ${attempt + 1}/'
          '$kSyncRoomLoadMaxAttempts)',
          subDomain: 'hydrate',
        );
        await Future<void>.delayed(delay);
      }
    }

    _loggingService.log(
      LogDomain.sync,
      'Failed to resolve room $savedRoomId after '
      '$kSyncRoomLoadMaxAttempts attempts. Room may not exist or invite '
      'acceptance pending.',
      subDomain: 'hydrate',
    );
  }

  /// Disposes resources owned by the manager.
  Future<void> dispose() async {
    await _roomIdController.close();
  }

  Room? _updateCurrentRoom(String roomId) {
    _setCurrentRoomId(roomId);
    _currentRoom = _gateway.getRoomById(roomId);

    if (_currentRoom == null) {
      _loggingService.log(
        LogDomain.sync,
        'Joined room $roomId but gateway has not yet hydrated a Room snapshot.',
        subDomain: 'resolveRoom',
      );
    }

    return _currentRoom;
  }

  Room? _resolveRoomSnapshot(
    String roomId, {
    required String subDomain,
  }) {
    final room = _gateway.getRoomById(roomId);
    if (room == null) {
      _loggingService.log(
        LogDomain.sync,
        'Persisted room $roomId not yet available from gateway.',
        subDomain: subDomain,
      );
      return null;
    }

    _currentRoom = room;
    _setCurrentRoomId(roomId);
    return room;
  }
}
