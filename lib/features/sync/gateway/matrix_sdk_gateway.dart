import 'dart:async';

import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

class MatrixSdkGateway implements MatrixSyncGateway {
  MatrixSdkGateway({required Client client}) : _client = client {
    _inviteSubscription = _client.onRoomState.stream.listen(_handleRoomState);
  }

  final Client _client;

  late final StreamSubscription<({String roomId, StrippedStateEvent state})>
      _inviteSubscription;
  final StreamController<RoomInviteEvent> _inviteController =
      StreamController<RoomInviteEvent>.broadcast();

  @override
  Client get client => _client;

  @override
  Future<void> connect(MatrixConfig config) async {
    await _client.checkHomeserver(Uri.parse(config.homeServer));
    await _client.init(
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );
  }

  @override
  Future<LoginResponse?> login(
    MatrixConfig config, {
    String? deviceDisplayName,
  }) async {
    return _client.login(
      LoginType.mLoginPassword,
      identifier: AuthenticationUserIdentifier(user: config.user),
      password: config.password,
      initialDeviceDisplayName: deviceDisplayName,
    );
  }

  @override
  Future<void> logout() async {
    if (_client.isLogged()) {
      await _client.logout();
    }
  }

  @override
  Stream<LoginState> get loginStateChanges =>
      _client.onLoginStateChanged.stream;

  @override
  Future<String> createRoom({
    required String name,
    List<String>? inviteUserIds,
  }) async {
    final roomId = await _client.createRoom(
      visibility: Visibility.private,
      name: name,
      invite: inviteUserIds,
      preset: CreateRoomPreset.trustedPrivateChat,
    );
    final room = _client.getRoomById(roomId);
    await room?.enableEncryption();
    return roomId;
  }

  @override
  Future<void> joinRoom(String roomId) async {
    await _client.joinRoom(roomId);
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    await _client.leaveRoom(roomId);
  }

  @override
  Room? getRoomById(String roomId) => _client.getRoomById(roomId);

  void _handleRoomState(
      ({
        String roomId,
        StrippedStateEvent state,
      }) event) {
    final content = event.state.content as Map<String, dynamic>?;
    final membership = content?['membership'];
    if (event.state.type == 'm.room.member' && membership == 'invite') {
      _inviteController.add(
        RoomInviteEvent(
          roomId: event.roomId,
          senderId: event.state.senderId,
        ),
      );
    }
  }

  @override
  Stream<RoomInviteEvent> get invites => _inviteController.stream;

  @override
  Stream<MatrixTimelineEvent> timelineEvents(String roomId) {
    // TODO: implement timeline streaming via Matrix SDK. For now the new
    // architecture does not depend on this yet, so return an empty stream to
    // keep the interface stable while we migrate call-sites.
    return const Stream<MatrixTimelineEvent>.empty();
  }

  @override
  Future<String> sendText({
    required String roomId,
    required String message,
    String? messageType,
    bool parseCommands = false,
    bool parseMarkdown = false,
  }) async {
    final room = _client.getRoomById(roomId);
    final content = <String, dynamic>{
      'msgtype': messageType ?? MessageTypes.Text,
      'body': message,
    };

    final eventId = await room?.sendEvent(content);
    if (eventId == null) {
      throw Exception('Failed to send text message to room $roomId');
    }
    return eventId;
  }

  @override
  Future<String> sendFile({
    required String roomId,
    required MatrixFile file,
    Map<String, dynamic>? extraContent,
  }) async {
    final room = _client.getRoomById(roomId);
    final eventId = extraContent == null
        ? await room?.sendFileEvent(file)
        : await room?.sendFileEvent(
            file,
            extraContent: extraContent,
          );
    if (eventId == null) {
      throw Exception('Failed to send file message to room $roomId');
    }
    return eventId;
  }

  @override
  Stream<KeyVerification> get keyVerificationRequests =>
      _client.onKeyVerificationRequest.stream;

  @override
  Future<KeyVerification> startKeyVerification(DeviceKeys device) {
    return device.startVerification();
  }

  @override
  List<DeviceKeys> unverifiedDevices() {
    final result = <DeviceKeys>[];
    for (final deviceKeysList in _client.userDeviceKeys.values) {
      for (final device in deviceKeysList.deviceKeys.values) {
        if (!device.verified) {
          result.add(device);
        }
      }
    }
    return result;
  }

  @override
  Future<void> dispose() async {
    await _inviteSubscription.cancel();
    await _inviteController.close();
    if (_client.isLogged()) {
      await _client.dispose();
    }
  }
}
