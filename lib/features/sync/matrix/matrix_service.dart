import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/client_runner.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

class MatrixService {
  MatrixService({
    required this.client,
    this.matrixConfig,
    this.deviceDisplayName,
    JournalDb? overriddenJournalDb,
    SettingsDb? overriddenSettingsDb,
  }) : keyVerificationController =
            StreamController<KeyVerificationRunner>.broadcast() {
    clientRunner = ClientRunner<void>(
      callback: (event) async {
        while (getIt<UserActivityService>().msSinceLastActivity < 1000) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }

        await processNewTimelineEvents(
          service: this,
          overriddenJournalDb: overriddenJournalDb,
          overriddenSettingsDb: overriddenSettingsDb,
        );
      },
    );

    getLastReadMatrixEventId(overriddenSettingsDb).then(
      (value) => lastReadEventContextId = value,
    );

    incomingKeyVerificationRunnerController =
        StreamController<KeyVerificationRunner>.broadcast(
      onListen: publishIncomingRunnerState,
    );

    keyVerificationStream = keyVerificationController.stream;
    incomingKeyVerificationRunnerStream =
        incomingKeyVerificationRunnerController.stream;

    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      if ({
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
        ConnectivityResult.ethernet,
      }.intersection(result.toSet()).isNotEmpty) {
        clientRunner.enqueueRequest(null);
      }
    });
  }

  void publishIncomingRunnerState() {
    incomingKeyVerificationRunner?.publishState();
  }

  final String? deviceDisplayName;
  final Client client;
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
    if (client.onLoginStateChanged.value == LoginState.loggedIn) {
      await listen();
    }
  }

  Future<void> listen() async {
    await startKeyVerificationListener();
    await listenToTimeline();
    listenToMatrixRoomInvites(service: this);
  }

  Future<bool> login() => matrixConnect(
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
    return client.isLogged();
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

  Future<String?> getRoom() => getMatrixRoom(client: client);

  Future<void> leaveRoom() => leaveMatrixRoom(client: client);

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
    if (deviceId != null && matrixConfig != null) {
      await client.deleteDevice(
        deviceId,
        auth: AuthenticationPassword(
          password: matrixConfig!.password,
          identifier: AuthenticationUserIdentifier(user: matrixConfig!.user),
        ),
      );
    }
  }

  String? get deviceId => client.deviceID;
  String? get deviceName => client.deviceName;

  Stream<KeyVerification> getIncomingKeyVerificationStream() {
    return incomingKeyVerificationController.stream;
  }

  Future<void> startKeyVerificationListener() =>
      listenForKeyVerificationRequests(service: this);

  Future<void> logout() async {
    if (client.isLogged()) {
      timeline?.cancelSubscriptions();
      await client.logout();
    }
  }

  Future<void> disposeClient() async {
    if (client.isLogged()) {
      await client.dispose();
    }
  }

  Future<MatrixConfig?> loadConfig() => loadMatrixConfig(service: this);
  Future<void> deleteConfig() => deleteMatrixConfig(service: this);
  Future<void> setConfig(MatrixConfig config) =>
      setMatrixConfig(config, service: this);
}
