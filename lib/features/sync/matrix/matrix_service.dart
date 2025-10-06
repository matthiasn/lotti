import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/client_runner.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

const int _kLoadSyncRoomMaxAttempts = 3;
const int _kLoadSyncRoomBaseDelayMs = 1000;

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

    getIt<LoggingService>().captureEvent(
      'MatrixService initialized - deviceId: ${client.deviceID}, '
      'deviceName: ${client.deviceName}, userId: ${client.userID}',
      domain: 'MATRIX_SERVICE',
      subDomain: 'init',
    );

    if (client.onLoginStateChanged.value == LoginState.loggedIn) {
      // Load syncRoom from saved room ID before attaching listeners
      await _loadSyncRoom();
      await listen();
    }
  }

  /// Loads the sync room from saved settings after login.
  /// Waits for client sync and retries if room not immediately available.
  Future<void> _loadSyncRoom() async {
    final savedRoomId = await getMatrixRoom(client: client);

    if (savedRoomId == null) {
      getIt<LoggingService>().captureEvent(
        'No saved room ID found',
        domain: 'MATRIX_SERVICE',
        subDomain: '_loadSyncRoom',
      );
      return;
    }

    // Try to get the room, with retries if not immediately available
    for (var attempt = 0; attempt < _kLoadSyncRoomMaxAttempts; attempt++) {
      // Ensure client has synced at least once
      await client.sync();

      final room = client.getRoomById(savedRoomId);

      if (room != null) {
        syncRoom = room;
        syncRoomId = savedRoomId;

        getIt<LoggingService>().captureEvent(
          'Loaded syncRoom: $savedRoomId (attempt ${attempt + 1})',
          domain: 'MATRIX_SERVICE',
          subDomain: '_loadSyncRoom',
        );
        return;
      }

      // Room not found yet, wait before retry
      if (attempt < _kLoadSyncRoomMaxAttempts - 1) {
        final delay =
            Duration(milliseconds: _kLoadSyncRoomBaseDelayMs * (attempt + 1));
        getIt<LoggingService>().captureEvent(
          'Room $savedRoomId not found, retrying in ${delay.inMilliseconds}ms '
          '(attempt ${attempt + 1}/$_kLoadSyncRoomMaxAttempts)',
          domain: 'MATRIX_SERVICE',
          subDomain: '_loadSyncRoom',
        );
        await Future<void>.delayed(delay);
      }
    }

    // Room still not found after retries
    getIt<LoggingService>().captureEvent(
      '⚠️ Failed to load room $savedRoomId after $_kLoadSyncRoomMaxAttempts attempts. '
      'Room may not exist or device may not be invited.',
      domain: 'MATRIX_SERVICE',
      subDomain: '_loadSyncRoom',
    );
  }

  Future<void> listen() async {
    await startKeyVerificationListener();
    await listenToTimeline();
    listenToMatrixRoomInvites(service: this);

    final savedRoomId = await getMatrixRoom(client: client);
    final joinedRooms = client.rooms.map((r) => r.id).toList();
    getIt<LoggingService>().captureEvent(
      'Sync state - savedRoomId: $savedRoomId, '
      'syncRoomId: $syncRoomId, '
      'joinedRooms: $joinedRooms',
      domain: 'MATRIX_SERVICE',
      subDomain: 'listen',
    );
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

    // Validate deviceId
    if (deviceId == null) {
      throw ArgumentError(
        'Cannot delete device: deviceId is null for device '
        '${deviceKeys.deviceDisplayName ?? 'unknown'}',
      );
    }

    // Validate that we have credentials
    if (matrixConfig == null) {
      throw StateError(
        'Cannot delete device $deviceId: No Matrix configuration available. '
        'User must be logged in to delete devices.',
      );
    }

    // Validate that the device belongs to the current user
    if (deviceKeys.userId != client.userID) {
      throw StateError(
        'Cannot delete device $deviceId: Device belongs to user '
        '${deviceKeys.userId} but current user is ${client.userID}',
      );
    }

    // Check if we have a password for authentication
    if (matrixConfig!.password.isNotEmpty) {
      await client.deleteDevice(
        deviceId,
        auth: AuthenticationPassword(
          password: matrixConfig!.password,
          identifier: AuthenticationUserIdentifier(user: matrixConfig!.user),
        ),
      );
    } else {
      // TODO: Implement non-password UIA flows (SSO/token) to support
      // device deletion when password is not available
      throw UnsupportedError(
        'Cannot delete device $deviceId: Password authentication required '
        'but no password is available. SSO/token authentication not yet '
        'implemented.',
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

  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    final savedRoomId = await getMatrixRoom(client: client);
    final joinedRooms = client.rooms
        .map(
          (r) => {
            'id': r.id,
            'name': r.name,
            'encrypted': r.encrypted,
            'memberCount': r.summary.mJoinedMemberCount,
          },
        )
        .toList();

    final diagnostics = {
      'deviceId': client.deviceID,
      'deviceName': client.deviceName,
      'userId': client.userID,
      'savedRoomId': savedRoomId,
      'syncRoomId': syncRoomId,
      'syncRoom.id': syncRoom?.id,
      'joinedRooms': joinedRooms,
      'isLoggedIn': isLoggedIn(),
    };

    getIt<LoggingService>().captureEvent(
      'Sync diagnostics: ${json.encode(diagnostics)}',
      domain: 'MATRIX_SERVICE',
      subDomain: 'diagnostics',
    );

    return diagnostics;
  }

  Future<MatrixConfig?> loadConfig() => loadMatrixConfig(service: this);
  Future<void> deleteConfig() => deleteMatrixConfig(service: this);
  Future<void> setConfig(MatrixConfig config) =>
      setMatrixConfig(config, service: this);
}
