import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

class MatrixService {
  MatrixService({
    required MatrixSyncGateway gateway,
    UserActivityGate? activityGate,
    MatrixConfig? matrixConfig,
    String? deviceDisplayName,
    JournalDb? overriddenJournalDb,
    SettingsDb? overriddenSettingsDb,
    LoggingService? overriddenLoggingService,
    SyncRoomManager? roomManager,
    MatrixSessionManager? sessionManager,
    MatrixTimelineListener? timelineListener,
    SyncLifecycleCoordinator? lifecycleCoordinator,
    SyncEngine? syncEngine,
  })  : _gateway = gateway,
        _loggingService = overriddenLoggingService ?? getIt<LoggingService>(),
        _activityGate = activityGate ??
            (getIt.isRegistered<UserActivityGate>()
                ? getIt<UserActivityGate>()
                : UserActivityGate(
                    activityService: getIt<UserActivityService>(),
                  )),
        _ownsActivityGate = activityGate == null,
        keyVerificationController =
            StreamController<KeyVerificationRunner>.broadcast(),
        messageCountsController = StreamController<MatrixStats>.broadcast(),
        incomingKeyVerificationController =
            StreamController<KeyVerification>.broadcast() {
    final settingsDb = overriddenSettingsDb ?? getIt<SettingsDb>();
    final journalDb = overriddenJournalDb ?? getIt<JournalDb>();

    _roomManager = roomManager ??
        sessionManager?.roomManager ??
        SyncRoomManager(
          gateway: _gateway,
          settingsDb: settingsDb,
          loggingService: _loggingService,
        );
    _sessionManager = sessionManager ??
        MatrixSessionManager(
          gateway: _gateway,
          roomManager: _roomManager,
          loggingService: _loggingService,
        );

    if (sessionManager == null && matrixConfig != null) {
      _sessionManager.matrixConfig = matrixConfig;
    }
    if (sessionManager == null && deviceDisplayName != null) {
      _sessionManager.deviceDisplayName = deviceDisplayName;
    }

    _timelineListener = timelineListener ??
        MatrixTimelineListener(
          sessionManager: _sessionManager,
          roomManager: _roomManager,
          loggingService: _loggingService,
          activityGate: _activityGate,
          overriddenJournalDb: journalDb,
          overriddenSettingsDb: settingsDb,
        );

    if (syncEngine != null) {
      if (lifecycleCoordinator != null &&
          !identical(
            syncEngine.lifecycleCoordinator,
            lifecycleCoordinator,
          )) {
        throw ArgumentError(
          'Provided SyncEngine and SyncLifecycleCoordinator must reference '
          'the same instance.',
        );
      }
      _syncEngine = syncEngine;
    } else {
      final coordinator = lifecycleCoordinator ??
          SyncLifecycleCoordinator(
            gateway: _gateway,
            sessionManager: _sessionManager,
            timelineListener: _timelineListener,
            roomManager: _roomManager,
            loggingService: _loggingService,
          );
      _syncEngine = SyncEngine(
        sessionManager: _sessionManager,
        roomManager: _roomManager,
        timelineListener: _timelineListener,
        lifecycleCoordinator: coordinator,
        loggingService: _loggingService,
      );
    }

    incomingKeyVerificationRunnerController =
        StreamController<KeyVerificationRunner>.broadcast(
      onListen: publishIncomingRunnerState,
    );

    keyVerificationStream = keyVerificationController.stream;
    incomingKeyVerificationRunnerStream =
        incomingKeyVerificationRunnerController.stream;

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      if ({
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
        ConnectivityResult.ethernet,
      }.intersection(result.toSet()).isNotEmpty) {
        _timelineListener.enqueueTimelineRefresh();
      }
    });
  }

  final MatrixSyncGateway _gateway;
  final LoggingService _loggingService;
  final UserActivityGate _activityGate;
  final bool _ownsActivityGate;

  late final SyncRoomManager _roomManager;
  late final MatrixSessionManager _sessionManager;
  late final MatrixTimelineListener _timelineListener;
  late final SyncEngine _syncEngine;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Client get client => _sessionManager.client;

  MatrixConfig? get matrixConfig => _sessionManager.matrixConfig;
  set matrixConfig(MatrixConfig? value) => _sessionManager.matrixConfig = value;

  LoginResponse? get loginResponse => _sessionManager.loginResponse;
  set loginResponse(LoginResponse? value) =>
      _sessionManager.loginResponse = value;

  String? get deviceDisplayName => _sessionManager.deviceDisplayName;
  set deviceDisplayName(String? value) =>
      _sessionManager.deviceDisplayName = value;

  String? get syncRoomId => _roomManager.currentRoomId;
  Room? get syncRoom => _roomManager.currentRoom;
  Timeline? get timeline => _timelineListener.timeline;

  String? get lastReadEventContextId =>
      _timelineListener.lastReadEventContextId;
  set lastReadEventContextId(String? value) =>
      _timelineListener.lastReadEventContextId = value;

  Stream<SyncRoomInvite> get inviteRequests => _roomManager.inviteRequests;

  final Map<String, int> messageCounts = {};
  int sentCount = 0;

  final StreamController<MatrixStats> messageCountsController;
  KeyVerificationRunner? keyVerificationRunner;
  KeyVerificationRunner? incomingKeyVerificationRunner;
  final StreamController<KeyVerificationRunner> keyVerificationController;
  late final StreamController<KeyVerificationRunner>
      incomingKeyVerificationRunnerController;
  late final Stream<KeyVerificationRunner> keyVerificationStream;
  late final Stream<KeyVerificationRunner> incomingKeyVerificationRunnerStream;

  final StreamController<KeyVerification> incomingKeyVerificationController;

  void publishIncomingRunnerState() {
    incomingKeyVerificationRunner?.publishState();
  }

  Future<void> init() async {
    await _syncEngine.initialize(
      onLogin: listen,
      onLogout: _onLifecycleLogout,
    );
    await loadConfig();
    await connect();

    _loggingService.captureEvent(
      'MatrixService initialized - deviceId: ${client.deviceID}, '
      'deviceName: ${client.deviceName}, userId: ${client.userID}',
      domain: 'MATRIX_SERVICE',
      subDomain: 'init',
    );
  }

  Future<void> listen() async {
    await startKeyVerificationListener();
    final savedRoomId = await _roomManager.loadPersistedRoomId();
    final joinedRooms = client.rooms.map((r) => r.id).toList();
    _loggingService.captureEvent(
      'Sync state - savedRoomId: $savedRoomId, '
      'syncRoomId: ${_roomManager.currentRoomId}, '
      'joinedRooms: $joinedRooms',
      domain: 'MATRIX_SERVICE',
      subDomain: 'listen',
    );
  }

  Future<void> _onLifecycleLogout() async {
    _loggingService.captureEvent(
      'Sync lifecycle paused (logged out).',
      domain: 'MATRIX_SERVICE',
      subDomain: 'logoutLifecycle',
    );
  }

  Future<bool> login() => _syncEngine.connect(shouldAttemptLogin: true);

  Future<bool> connect() => _syncEngine.connect(shouldAttemptLogin: false);

  Future<String?> joinRoom(String roomId) async {
    final room = await _roomManager.joinRoom(roomId);
    return room?.id ?? roomId;
  }

  Future<void> saveRoom(String roomId) => _roomManager.saveRoomId(roomId);

  bool isLoggedIn() => _sessionManager.isLoggedIn();

  Future<void> listenToTimeline() async {
    await _timelineListener.start();
  }

  Future<String> createRoom({List<String>? invite}) =>
      _roomManager.createRoom(inviteUserIds: invite);

  Future<String?> getRoom() => _roomManager.loadPersistedRoomId();

  Future<void> leaveRoom() => _roomManager.leaveCurrentRoom();

  Future<void> inviteToSyncRoom({required String userId}) =>
      _roomManager.inviteUser(userId);

  List<DeviceKeys> getUnverifiedDevices() {
    return _gateway.unverifiedDevices();
  }

  Future<void> verifyDevice(DeviceKeys deviceKeys) => verifyMatrixDevice(
        deviceKeys: deviceKeys,
        service: this,
      );

  Future<void> deleteDevice(DeviceKeys deviceKeys) async {
    final deviceId = deviceKeys.deviceId;

    if (deviceId == null) {
      throw ArgumentError(
        'Cannot delete device: deviceId is null for device '
        '${deviceKeys.deviceDisplayName ?? 'unknown'}',
      );
    }

    final config = matrixConfig;
    if (config == null) {
      throw StateError(
        'Cannot delete device $deviceId: No Matrix configuration available. '
        'User must be logged in to delete devices.',
      );
    }

    if (deviceKeys.userId != client.userID) {
      throw StateError(
        'Cannot delete device $deviceId: Device belongs to user '
        '${deviceKeys.userId} but current user is ${client.userID}',
      );
    }

    if (config.password.isNotEmpty) {
      await client.deleteDevice(
        deviceId,
        auth: AuthenticationPassword(
          password: config.password,
          identifier: AuthenticationUserIdentifier(user: config.user),
        ),
      );
    } else {
      throw UnsupportedError(
        'Cannot delete device $deviceId: Password authentication required '
        'but no password is available. SSO/token authentication not yet '
        'implemented.',
      );
    }
  }

  String? get deviceId => client.deviceID;
  String? get deviceName => client.deviceName;

  Stream<KeyVerification> getIncomingKeyVerificationStream() =>
      incomingKeyVerificationController.stream;

  Future<void> startKeyVerificationListener() =>
      listenForKeyVerificationRequests(service: this);

  Future<void> logout() async {
    await _syncEngine.logout();
  }

  Future<void> disposeClient() async {
    if (client.isLogged()) {
      await client.dispose();
    }
  }

  Future<void> dispose() async {
    await messageCountsController.close();
    await keyVerificationController.close();
    await incomingKeyVerificationRunnerController.close();
    await incomingKeyVerificationController.close();
    await _connectivitySubscription?.cancel();
    await _syncEngine.dispose();
    await _timelineListener.dispose();
    await _sessionManager.dispose();
    await _roomManager.dispose();
    if (_ownsActivityGate) {
      await _activityGate.dispose();
    }
  }

  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    final diagnostics = await _syncEngine.diagnostics(log: false);
    _loggingService.captureEvent(
      'Sync diagnostics: ${json.encode(diagnostics)}',
      domain: 'MATRIX_SERVICE',
      subDomain: 'diagnostics',
    );
    return diagnostics;
  }

  Future<MatrixConfig?> loadConfig() =>
      loadMatrixConfig(session: _sessionManager);
  Future<void> deleteConfig() => deleteMatrixConfig(session: _sessionManager);
  Future<void> setConfig(MatrixConfig config) =>
      setMatrixConfig(config, session: _sessionManager);
}
