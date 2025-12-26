import 'dart:async';

import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

class MatrixSdkGateway implements MatrixSyncGateway {
  /// Creates a new [MatrixSdkGateway].
  ///
  /// The gateway assumes ownership of the provided [client] instance and will
  /// call [Client.dispose] during [dispose]. Callers must not dispose the
  /// client separately once it is passed here.
  MatrixSdkGateway({
    required Client client,
    required SentEventRegistry sentEventRegistry,
    Stream<({String roomId, StrippedStateEvent state})>? roomStateStream,
    Stream<LoginState>? loginStateStream,
    Stream<KeyVerification>? keyVerificationRequestStream,
  })  : _client = client,
        _sentEventRegistry = sentEventRegistry,
        _roomStateStream = roomStateStream,
        _loginStateStream = loginStateStream,
        _keyVerificationRequests = keyVerificationRequestStream {
    _inviteSubscription =
        (_roomStateStream ?? _client.onRoomState.stream).listen(
      _handleRoomState,
    );
  }

  final Client _client;
  final SentEventRegistry _sentEventRegistry;

  late final StreamSubscription<({String roomId, StrippedStateEvent state})>
      _inviteSubscription;
  final StreamController<RoomInviteEvent> _inviteController =
      StreamController<RoomInviteEvent>.broadcast();
  final Stream<({String roomId, StrippedStateEvent state})>? _roomStateStream;
  final Stream<LoginState>? _loginStateStream;
  final Stream<KeyVerification>? _keyVerificationRequests;

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
      _loginStateStream ?? _client.onLoginStateChanged.stream;

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
    final stateKey = event.state.stateKey;
    if (event.state.type == 'm.room.member' && membership == 'invite') {
      final target = stateKey;
      // Only surface invites targeted at this client (state_key == userID)
      if (target == _client.userID) {
        _inviteController.add(
          RoomInviteEvent(
            roomId: event.roomId,
            senderId: event.state.senderId,
          ),
        );
      }
    }
  }

  @override
  Stream<RoomInviteEvent> get invites => _inviteController.stream;

  @override
  Stream<Event> timelineEvents(String roomId) {
    // TODO: implement timeline streaming via Matrix SDK. For now the new
    // architecture does not depend on this yet, so return an empty stream to
    // keep the interface stable while we migrate call-sites.
    return const Stream<Event>.empty();
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
    _sentEventRegistry.register(eventId, source: SentEventSource.text);
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
    _sentEventRegistry.register(eventId, source: SentEventSource.file);
    return eventId;
  }

  @override
  Stream<KeyVerification> get keyVerificationRequests =>
      _keyVerificationRequests ?? _client.onKeyVerificationRequest.stream;

  @override
  Future<KeyVerification> startKeyVerification(DeviceKeys device) {
    return device.startVerification();
  }

  @override
  List<DeviceKeys> unverifiedDevices() {
    return _client.userDeviceKeys.values
        .expand((deviceKeysList) => deviceKeysList.deviceKeys.values)
        .where((device) => !device.verified)
        .toList();
  }

  @override
  Future<void> dispose() async {
    await _inviteSubscription.cancel();
    await _inviteController.close();
    await _client.dispose();
  }
}
