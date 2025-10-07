import 'dart:async';

import 'package:intl/intl.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

const int kSyncRoomLoadMaxAttempts = 4;
const int kSyncRoomLoadBaseDelayMs = 1000;

/// Represents a pending invite that requires user confirmation before the
/// device joins a Matrix room.
class SyncRoomInvite {
  SyncRoomInvite({
    required this.roomId,
    required this.senderId,
    required this.matchesExistingRoom,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String roomId;
  final String senderId;
  final bool matchesExistingRoom;
  final DateTime timestamp;
}

/// Handles sync-room persistence, invite filtering, and safe join/leave flows.
///
/// This manager replaces the legacy auto-join logic that subscribed directly to
/// `Client.onRoomState` events. It ensures that only valid invite events are
/// surfaced to the UI and requires explicit confirmation before joining.
class SyncRoomManager {
  SyncRoomManager({
    required MatrixSyncGateway gateway,
    required SettingsDb settingsDb,
    required LoggingService loggingService,
  })  : _gateway = gateway,
        _settingsDb = settingsDb,
        _loggingService = loggingService {
    _inviteSubscription = _gateway.invites.listen(_handleInvite);
  }

  final MatrixSyncGateway _gateway;
  final SettingsDb _settingsDb;
  final LoggingService _loggingService;

  final StreamController<SyncRoomInvite> _inviteController =
      StreamController<SyncRoomInvite>.broadcast();

  StreamSubscription<RoomInviteEvent>? _inviteSubscription;
  Room? _currentRoom;
  String? _currentRoomId;

  /// The currently joined sync room, if any.
  Room? get currentRoom => _currentRoom;

  /// Identifier of the current sync room, if available.
  String? get currentRoomId => _currentRoomId;

  /// Emits invite requests that passed validation. The UI is expected to prompt
  /// the user and explicitly call [acceptInvite] when appropriate.
  Stream<SyncRoomInvite> get inviteRequests => _inviteController.stream;

  /// Loads any persisted room identifier and resolves the current room snapshot
  /// if the Matrix client has already synced it.
  Future<void> initialize() async {
    final savedRoomId = await loadPersistedRoomId();
    if (savedRoomId == null) {
      return;
    }

    _resolveRoomSnapshot(savedRoomId, subDomain: 'initialize');
  }

  /// Creates a new encrypted private sync room and persists its identifier.
  Future<String> createRoom({List<String>? inviteUserIds}) async {
    final name = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final roomId = await _gateway.createRoom(
      name: name,
      inviteUserIds: inviteUserIds,
    );

    await _settingsDb.saveSettingsItem(matrixRoomKey, roomId);
    _updateCurrentRoom(roomId);

    _loggingService.captureEvent(
      'Created sync room $roomId (invitees: ${inviteUserIds?.length ?? 0})',
      domain: 'SYNC_ROOM_MANAGER',
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

  /// Leaves the currently configured room (if any) and clears persisted state.
  Future<void> leaveCurrentRoom() async {
    final roomId = _currentRoomId ?? await _settingsDb.itemByKey(matrixRoomKey);
    if (roomId == null) {
      return;
    }

    await _settingsDb.removeSettingsItem(matrixRoomKey);
    await _gateway.leaveRoom(roomId);

    _currentRoom = null;
    _currentRoomId = null;

    _loggingService.captureEvent(
      'Left sync room $roomId and cleared persisted state.',
      domain: 'SYNC_ROOM_MANAGER',
      subDomain: 'leaveRoom',
    );
  }

  /// Accepts a pending invite by joining the room and persisting the room ID.
  Future<void> acceptInvite(SyncRoomInvite invite) async {
    _loggingService.captureEvent(
      'Accepting invite to ${invite.roomId} from ${invite.senderId} '
      '(matchesExistingRoom: ${invite.matchesExistingRoom})',
      domain: 'SYNC_ROOM_MANAGER',
      subDomain: 'acceptInvite',
    );
    await joinRoom(invite.roomId);
  }

  /// Loads the persisted room identifier (if any) without altering in-memory
  /// state. Subsequent calls reuse the cached copy.
  Future<String?> loadPersistedRoomId() async {
    if (_currentRoomId != null) {
      return _currentRoomId;
    }

    final savedRoomId = await _settingsDb.itemByKey(matrixRoomKey);
    if (savedRoomId != null) {
      _currentRoomId = savedRoomId;
    }
    return savedRoomId;
  }

  /// Ensures the persisted room is available from the Matrix client, retrying
  /// while the homeserver completes initial sync.
  Future<void> hydrateRoomSnapshot({required Client client}) async {
    final savedRoomId = await loadPersistedRoomId();
    if (savedRoomId == null) {
      _loggingService.captureEvent(
        'No saved room ID found during hydrateRoomSnapshot.',
        domain: 'SYNC_ROOM_MANAGER',
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
        final delay =
            Duration(milliseconds: kSyncRoomLoadBaseDelayMs * (1 << attempt));
        _loggingService.captureEvent(
          'Room $savedRoomId not yet available, retrying in '
          '${delay.inMilliseconds}ms (attempt ${attempt + 1}/'
          '$kSyncRoomLoadMaxAttempts)',
          domain: 'SYNC_ROOM_MANAGER',
          subDomain: 'hydrate',
        );
        await Future<void>.delayed(delay);
      }
    }

    _loggingService.captureEvent(
      'Failed to resolve room $savedRoomId after '
      '$kSyncRoomLoadMaxAttempts attempts. Room may not exist or invite '
      'acceptance pending.',
      domain: 'SYNC_ROOM_MANAGER',
      subDomain: 'hydrate',
    );
  }

  /// Invites the specified user to the current sync room.
  Future<void> inviteUser(String userId) async {
    final room = _currentRoom;
    if (room == null) {
      throw StateError(
        'Cannot invite $userId: no active sync room configured.',
      );
    }
    await room.invite(userId);
  }

  /// Disposes resources owned by the manager.
  Future<void> dispose() async {
    await _inviteSubscription?.cancel();
    await _inviteController.close();
  }

  Room? _updateCurrentRoom(String roomId) {
    _currentRoomId = roomId;
    _currentRoom = _gateway.getRoomById(roomId);

    if (_currentRoom == null) {
      _loggingService.captureEvent(
        'Joined room $roomId but gateway has not yet hydrated a Room snapshot.',
        domain: 'SYNC_ROOM_MANAGER',
        subDomain: 'resolveRoom',
      );
    }

    return _currentRoom;
  }

  void _handleInvite(RoomInviteEvent event) {
    if (!_isValidRoomId(event.roomId)) {
      _loggingService.captureEvent(
        'Discarding invite with invalid roomId ${event.roomId} from '
        '${event.senderId}',
        domain: 'SYNC_ROOM_MANAGER',
        subDomain: 'inviteFiltered',
      );
      return;
    }

    final matchesExisting = _currentRoomId == event.roomId;
    _loggingService.captureEvent(
      'Received invite for room ${event.roomId} from ${event.senderId} '
      '(matchesExistingRoom: $matchesExisting)',
      domain: 'SYNC_ROOM_MANAGER',
      subDomain: 'inviteReceived',
    );

    _inviteController.add(
      SyncRoomInvite(
        roomId: event.roomId,
        senderId: event.senderId,
        matchesExistingRoom: matchesExisting,
      ),
    );
  }

  bool _isValidRoomId(String roomId) {
    return roomId.startsWith('!');
  }

  Room? _resolveRoomSnapshot(
    String roomId, {
    required String subDomain,
  }) {
    final room = _gateway.getRoomById(roomId);
    if (room == null) {
      _loggingService.captureEvent(
        'Persisted room $roomId not yet available from gateway.',
        domain: 'SYNC_ROOM_MANAGER',
        subDomain: subDomain,
      );
      return null;
    }

    _currentRoom = room;
    _currentRoomId = roomId;
    return room;
  }
}
