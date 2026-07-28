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
  Future<LoginResponse?> login(
    MatrixConfig config, {
    String? deviceDisplayName,
  });

  /// Logs the current session out of the homeserver.
  Future<void> logout();

  /// Stream of login state changes.
  Stream<LoginState> get loginStateChanges;

  /// Creates a new encrypted private room.
  Future<String> createRoom({
    required String name,
    List<String>? inviteUserIds,
  });

  /// Joins the room with the given ID.
  Future<void> joinRoom(String roomId);

  /// Returns a room snapshot by its identifier.
  Room? getRoomById(String roomId);

  /// Sends a text event to the given room and returns the event ID.
  Future<String> sendText({
    required String roomId,
    required String message,
    String? messageType,
    bool parseCommands,
    bool parseMarkdown,
    bool displayPendingEvent,
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

  /// The device/session id this client is logged in as, or null when logged
  /// out.
  String? get currentDeviceId;

  /// Returns the account's device inventory from the homeserver
  /// (`GET /_matrix/client/v3/devices`) — every session including ones that
  /// never published encryption keys.
  Future<List<Device>> getDevices();

  /// Deletes a device/session on the homeserver. The endpoint is guarded by
  /// user-interactive auth, supplied via [auth].
  Future<void> deleteDevice(String deviceId, {AuthenticationData? auth});

  /// Changes the password for the currently logged-in user.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  /// Releases any resources (streams, controllers, database connections).
  Future<void> dispose();
}
