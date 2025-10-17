import 'dart:async';

import 'package:lotti/classes/config.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

/// High-level gateway that abstracts access to the Matrix SDK for the sync
/// feature. Encapsulates session management, room membership, timeline
/// streaming, sending, and device verification concerns.
abstract class MatrixSyncGateway {
  /// Underlying Matrix client. This is exposed temporarily while we migrate
  /// existing call-sites; new code should prefer the gateway APIs.
  Client get client;

  /// Initiates a connection to the homeserver using the provided config.
  Future<void> connect(MatrixConfig config);

  /// Performs an interactive login using the provided configuration.
  Future<LoginResponse?> login(MatrixConfig config,
      {String? deviceDisplayName});

  /// Logs the current session out of the homeserver.
  Future<void> logout();

  /// Stream of login state changes.
  Stream<LoginState> get loginStateChanges;

  /// Creates a new encrypted private room.
  Future<String> createRoom(
      {required String name, List<String>? inviteUserIds});

  /// Joins the room with the given ID.
  Future<void> joinRoom(String roomId);

  /// Leaves the current room identified by [roomId].
  Future<void> leaveRoom(String roomId);

  /// Returns a room snapshot by its identifier.
  Room? getRoomById(String roomId);

  /// Stream of invites targeted at this client.
  Stream<RoomInviteEvent> get invites;

  /// Stream of timeline events received for the specified room.
  Stream<MatrixTimelineEvent> timelineEvents(String roomId);

  /// Sends a text event to the given room and returns the event ID.
  Future<String> sendText({
    required String roomId,
    required String message,
    String? messageType,
    bool parseCommands,
    bool parseMarkdown,
  });

  /// Sends a file event to the given room and returns the event ID.
  Future<String> sendFile({
    required String roomId,
    required MatrixFile file,
    Map<String, dynamic>? extraContent,
  });

  /// Stream of key verification requests for this client.
  Stream<KeyVerification> get keyVerificationRequests;

  /// Initiates an interactive key verification flow with the provided device.
  Future<KeyVerification> startKeyVerification(DeviceKeys device);

  /// Returns a list of unverified devices across joined rooms.
  List<DeviceKeys> unverifiedDevices();

  /// Releases any resources (streams, controllers, database connections).
  Future<void> dispose();
}

/// Lightweight representation of a room invite targeted at the current user.
class RoomInviteEvent {
  const RoomInviteEvent({
    required this.roomId,
    required this.senderId,
    this.targetUserId,
    this.event,
  });

  /// The invited room id
  final String roomId;

  /// The user who sent the invite
  final String senderId;

  /// The user this invite targets (Matrix state_key). If present and not equal
  /// to the current client user id, the client should ignore this invite.
  final String? targetUserId;

  /// Optional raw SDK event for debugging contexts.
  final Event? event;
}

/// Wrapper around Matrix timeline events emitted for the sync room.
class MatrixTimelineEvent {
  const MatrixTimelineEvent({
    required this.roomId,
    required this.event,
  });

  final String roomId;
  final Event event;
}
