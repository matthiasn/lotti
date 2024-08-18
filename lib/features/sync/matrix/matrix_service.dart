import 'dart:async';

import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/client_runner.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

class MatrixService {
  MatrixService({
    this.matrixConfig,
    this.deviceDisplayName,
    String? dbName,
    JournalDb? overriddenJournalDb,
  })  : keyVerificationController =
            StreamController<KeyVerificationRunner>.broadcast(),
        _client = createMatrixClient(dbName: dbName) {
    clientRunner = ClientRunner<void>(
      callback: (event) async {
        while (getIt<UserActivityService>().msSinceLastActivity < 4000) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }

        await processNewTimelineEvents(
          service: this,
          overriddenJournalDb: overriddenJournalDb,
        );
      },
    );

    getLastReadMatrixEventId().then(
      (value) => lastReadEventContextId = value,
    );

    incomingKeyVerificationRunnerController =
        StreamController<KeyVerificationRunner>.broadcast(
      onListen: publishIncomingRunnerState,
    );

    keyVerificationStream = keyVerificationController.stream;
    incomingKeyVerificationRunnerStream =
        incomingKeyVerificationRunnerController.stream;
  }

  void publishIncomingRunnerState() {
    incomingKeyVerificationRunner?.publishState();
  }

  final String? deviceDisplayName;
  late final Client _client;
  MatrixConfig? matrixConfig;
  LoginResponse? loginResponse;
  String? syncRoomId;
  Room? syncRoom;
  Timeline? timeline;
  String? lastReadEventContextId;

  late final ClientRunner<void> clientRunner;

  final Map<String, int> messageCounts = {};
  int sentCount = 0;

  final StreamController<MatrixStats> messageCountsController =
      StreamController<MatrixStats>.broadcast();
  KeyVerificationRunner? keyVerificationRunner;
  KeyVerificationRunner? incomingKeyVerificationRunner;
  final StreamController<KeyVerificationRunner> keyVerificationController;
  late final StreamController<KeyVerificationRunner>
      incomingKeyVerificationRunnerController;
  late final Stream<KeyVerificationRunner> keyVerificationStream;
  late final Stream<KeyVerificationRunner> incomingKeyVerificationRunnerStream;

  final incomingKeyVerificationController =
      StreamController<KeyVerification>.broadcast();

  Future<void> init() async {
    await loadConfig();
    await connect();
    if (_client.onLoginStateChanged.value == LoginState.loggedIn) {
      await listen();
    }
  }

  Future<void> listen() async {
    await startKeyVerificationListener();
    await listenToTimeline();
    listenToMatrixRoomInvites(service: this);
  }

  Client get client => _client;

  Future<void> login() => matrixConnect(
        service: this,
        shouldAttemptLogin: true,
      );

  Future<void> connect() => matrixConnect(
        service: this,
        shouldAttemptLogin: false,
      );

  Future<String?> joinRoom(String roomId) =>
      joinMatrixRoom(roomId: roomId, service: this);

  Future<void> saveRoom(String roomId) => saveMatrixRoom(
        roomId: roomId,
        client: client,
      );

  bool isLoggedIn() {
    // TODO(unassigned): find non-deprecated solution
    // ignore: deprecated_member_use
    return _client.loginState == LoginState.loggedIn;
  }

  Future<void> listenToTimeline() async {
    await listenToTimelineEvents(service: this);
  }

  Future<String> createRoom({
    List<String>? invite,
  }) =>
      createMatrixRoom(
        service: this,
        invite: invite,
      );

  Future<String?> getRoom() => getMatrixRoom(client: _client);

  Future<void> leaveRoom() => leaveMatrixRoom(client: _client);

  Future<void> inviteToSyncRoom({
    required String userId,
  }) =>
      inviteToMatrixRoom(
        service: this,
        userId: userId,
      );

  List<DeviceKeys> getUnverifiedDevices() {
    final unverifiedDevices = <DeviceKeys>[];

    for (final deviceKeysList in client.userDeviceKeys.values) {
      for (final deviceKeys in deviceKeysList.deviceKeys.values) {
        if (!deviceKeys.verified) {
          unverifiedDevices.add(deviceKeys);
        }
      }
    }

    return unverifiedDevices;
  }

  Future<void> verifyDevice(DeviceKeys deviceKeys) => verifyMatrixDevice(
        deviceKeys: deviceKeys,
        service: this,
      );

  Future<void> deleteDevice(DeviceKeys deviceKeys) async {
    final deviceId = deviceKeys.deviceId;
    if (deviceId != null) {
      await _client.deleteDevice(deviceId, auth: AuthenticationData());
    }
  }

  String? get deviceId => _client.deviceID;
  String? get deviceName => _client.deviceName;

  Stream<KeyVerification> getIncomingKeyVerificationStream() {
    return incomingKeyVerificationController.stream;
  }

  Future<void> startKeyVerificationListener() =>
      listenForKeyVerificationRequests(service: this);

  Future<void> logout() async {
    if (_client.isLogged()) {
      timeline?.cancelSubscriptions();
      await _client.logout();
    }
  }

  Future<void> disposeClient() async {
    if (_client.isLogged()) {
      await _client.dispose();
    }
  }

  Future<MatrixConfig?> loadConfig() => loadMatrixConfig(service: this);
  Future<void> deleteConfig() => deleteMatrixConfig(service: this);
  Future<void> setConfig(MatrixConfig config) =>
      setMatrixConfig(config, service: this);
}
