import 'dart:async';

import 'package:collection/collection.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/sync/client_runner.dart';
import 'package:lotti/sync/matrix/client.dart';
import 'package:lotti/sync/matrix/config.dart';
import 'package:lotti/sync/matrix/key_verification_runner.dart';
import 'package:lotti/sync/matrix/last_read.dart';
import 'package:lotti/sync/matrix/room.dart';
import 'package:lotti/sync/matrix/send_message.dart';
import 'package:lotti/sync/matrix/stats.dart';
import 'package:lotti/sync/matrix/timeline.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

class MatrixService {
  MatrixService({
    this.matrixConfig,
    this.deviceDisplayName,
    String? hiveDbName,
    JournalDb? overriddenJournalDb,
  })  : keyVerificationController =
            StreamController<KeyVerificationRunner>.broadcast(),
        _client = createMatrixClient(hiveDbName: hiveDbName) {
    clientRunner = ClientRunner<void>(
      callback: (event) async {
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

  Future<void> loginAndListen() async {
    await loadConfig();
    await login();
    await startKeyVerificationListener();
    await listenToTimeline();
  }

  Client get client => _client;
  Future<void> login() => matrixLogin(service: this);
  Future<String?> joinRoom(String roomId) =>
      joinMatrixRoom(roomId: roomId, service: this);

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
        client: _client,
        invite: invite,
      );

  Future<void> inviteToSyncRoom({
    required String userId,
  }) =>
      inviteToMatrixRoom(
        service: this,
        userId: userId,
      );

  DeviceKeys? findUnverified() {
    return client.userDeviceKeys.values
        .firstWhereOrNull(
          (item) => item.deviceKeys.values.firstOrNull?.verified == false,
        )
        ?.deviceKeys
        .values
        .firstOrNull;
  }

  List<DeviceKeys> getUnverified() => _client.unverifiedDevices;

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

  Future<void> sendMatrixMsg(
    SyncMessage syncMessage, {
    String? myRoomId,
  }) =>
      sendMessage(
        syncMessage,
        service: this,
        myRoomId: myRoomId,
      );

  Future<void> logout() async {
    if (_client.isLogged()) {
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
