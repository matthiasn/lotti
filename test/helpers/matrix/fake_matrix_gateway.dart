import 'dart:async';

import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class FakeMatrixGateway implements MatrixSyncGateway {
  FakeMatrixGateway({Client? client}) : _client = client ?? _FakeClient();

  final Client _client;

  final StreamController<LoginState> _loginStateController =
      StreamController<LoginState>.broadcast();
  final StreamController<RoomInviteEvent> _inviteController =
      StreamController<RoomInviteEvent>.broadcast();
  final StreamController<MatrixTimelineEvent> _timelineController =
      StreamController<MatrixTimelineEvent>.broadcast();
  final StreamController<KeyVerification> _verificationController =
      StreamController<KeyVerification>.broadcast();

  bool logoutCalled = false;
  bool disposed = false;
  final List<DeviceKeys> _unverifiedDevices = <DeviceKeys>[];

  void emitLoginState(LoginState state) => _loginStateController.add(state);

  void emitInvite(RoomInviteEvent event) => _inviteController.add(event);

  void emitTimeline(MatrixTimelineEvent event) =>
      _timelineController.add(event);

  void emitVerification(KeyVerification request) =>
      _verificationController.add(request);

  void setUnverifiedDevices(List<DeviceKeys> devices) {
    _unverifiedDevices
      ..clear()
      ..addAll(devices);
  }

  @override
  Client get client => _client;

  @override
  Future<void> connect(MatrixConfig config) async {}

  @override
  Future<LoginResponse?> login(
    MatrixConfig config, {
    String? deviceDisplayName,
  }) async {
    return null;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Stream<LoginState> get loginStateChanges => _loginStateController.stream;

  @override
  Future<String> createRoom({
    required String name,
    List<String>? inviteUserIds,
  }) async {
    return '!fakeRoom:server';
  }

  @override
  Future<void> joinRoom(String roomId) async {}

  @override
  Future<void> leaveRoom(String roomId) async {}

  @override
  Room? getRoomById(String roomId) => null;

  @override
  Stream<RoomInviteEvent> get invites => _inviteController.stream;

  @override
  Stream<MatrixTimelineEvent> timelineEvents(String roomId) =>
      _timelineController.stream;

  @override
  Future<String> sendText({
    required String roomId,
    required String message,
    String? messageType,
    bool parseCommands = false,
    bool parseMarkdown = false,
  }) async {
    return 'fake-event';
  }

  @override
  Future<String> sendFile({
    required String roomId,
    required MatrixFile file,
    Map<String, dynamic>? extraContent,
  }) async {
    return 'fake-file-event';
  }

  @override
  Stream<KeyVerification> get keyVerificationRequests =>
      _verificationController.stream;

  @override
  Future<KeyVerification> startKeyVerification(DeviceKeys device) async {
    final verification = _FakeKeyVerification();
    emitVerification(verification);
    return verification;
  }

  @override
  List<DeviceKeys> unverifiedDevices() =>
      List<DeviceKeys>.from(_unverifiedDevices);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _loginStateController.close();
    await _inviteController.close();
    await _timelineController.close();
    await _verificationController.close();
  }
}

class _FakeClient extends Fake implements Client {}

class _FakeKeyVerification extends Fake implements KeyVerification {}
