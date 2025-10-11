import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/config.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_timeline_listener.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/v2_metrics.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/matrix/sync_engine.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';

class MatrixService {
  MatrixService({
    required MatrixSyncGateway gateway,
    required LoggingService loggingService,
    required UserActivityGate activityGate,
    required MatrixMessageSender messageSender,
    required JournalDb journalDb,
    required SettingsDb settingsDb,
    required SyncReadMarkerService readMarkerService,
    required SyncEventProcessor eventProcessor,
    required SecureStorage secureStorage,
    required Directory documentsDirectory,
    bool enableSyncV2 = false,
    bool collectV2Metrics = false,
    bool ownsActivityGate = false,
    MatrixConfig? matrixConfig,
    String? deviceDisplayName,
    SyncRoomManager? roomManager,
    MatrixSessionManager? sessionManager,
    MatrixTimelineListener? timelineListener,
    SyncLifecycleCoordinator? lifecycleCoordinator,
    SyncEngine? syncEngine,
    // Test-only seam to inject a V2 pipeline
    @visibleForTesting MatrixStreamConsumer? v2PipelineOverride,
  })  : _gateway = gateway,
        _loggingService = loggingService,
        _activityGate = activityGate,
        _messageSender = messageSender,
        _journalDb = journalDb,
        _settingsDb = settingsDb,
        _readMarkerService = readMarkerService,
        _eventProcessor = eventProcessor,
        _secureStorage = secureStorage,
        _ownsActivityGate = ownsActivityGate,
        keyVerificationController =
            StreamController<KeyVerificationRunner>.broadcast(),
        messageCountsController = StreamController<MatrixStats>.broadcast(),
        incomingKeyVerificationController =
            StreamController<KeyVerification>.broadcast() {
    _roomManager = roomManager ??
        sessionManager?.roomManager ??
        SyncRoomManager(
          gateway: _gateway,
          settingsDb: _settingsDb,
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
          journalDb: _journalDb,
          settingsDb: _settingsDb,
          readMarkerService: _readMarkerService,
          eventProcessor: _eventProcessor,
          documentsDirectory: documentsDirectory,
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
      final pipeline = v2PipelineOverride ??
          (enableSyncV2
              ? MatrixStreamConsumer(
                  sessionManager: _sessionManager,
                  roomManager: _roomManager,
                  loggingService: _loggingService,
                  journalDb: _journalDb,
                  settingsDb: _settingsDb,
                  eventProcessor: _eventProcessor,
                  readMarkerService: _readMarkerService,
                  documentsDirectory: documentsDirectory,
                  collectMetrics: collectV2Metrics,
                )
              : null);
      _v2Pipeline = pipeline;
      final coordinator = lifecycleCoordinator ??
          SyncLifecycleCoordinator(
            gateway: _gateway,
            sessionManager: _sessionManager,
            timelineListener: _timelineListener,
            roomManager: _roomManager,
            loggingService: _loggingService,
            pipeline: pipeline,
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
  final MatrixMessageSender _messageSender;
  final JournalDb _journalDb;
  final SettingsDb _settingsDb;
  final SyncReadMarkerService _readMarkerService;
  final SyncEventProcessor _eventProcessor;
  final SecureStorage _secureStorage;
  final bool _ownsActivityGate;

  late final SyncRoomManager _roomManager;
  late final MatrixSessionManager _sessionManager;
  late final MatrixTimelineListener _timelineListener;
  late final SyncEngine _syncEngine;
  MatrixStreamConsumer? _v2Pipeline;

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
  void incrementSentCount() {
    sentCount = sentCount + 1;
    messageCountsController.add(
      MatrixStats(
        messageCounts: messageCounts,
        sentCount: sentCount,
      ),
    );
  }

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

  Future<bool> sendMatrixMsg(
    SyncMessage syncMessage, {
    String? myRoomId,
  }) {
    var targetRoom = syncRoom;
    var targetRoomId = syncRoomId;

    if (myRoomId != null) {
      targetRoomId = myRoomId;
      targetRoom = client.getRoomById(myRoomId) ?? targetRoom;
    }

    return _messageSender.sendMatrixMessage(
      message: syncMessage,
      context: MatrixMessageContext(
        syncRoomId: targetRoomId,
        syncRoom: targetRoom,
        unverifiedDevices: getUnverifiedDevices(),
      ),
      onSent: incrementSentCount,
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
      listenForKeyVerificationRequests(
        service: this,
        loggingService: _loggingService,
      );

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

    // Dispose in reverse construction order: timeline listeners
    // depend on the session, which in turn composes the room manager.
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

  Future<V2Metrics?> getV2Metrics() async {
    if (_v2Pipeline == null) return null;
    final map = _v2Pipeline!.metricsSnapshot();
    return V2Metrics.fromMap(map);
  }

  // Visible for testing only
  @visibleForTesting
  MatrixStreamConsumer? get debugV2Pipeline => _v2Pipeline;

  Future<MatrixConfig?> loadConfig() => loadMatrixConfig(
        session: _sessionManager,
        storage: _secureStorage,
      );
  Future<void> deleteConfig() => deleteMatrixConfig(
        session: _sessionManager,
        storage: _secureStorage,
      );
  Future<void> setConfig(MatrixConfig config) => setMatrixConfig(
        config,
        session: _sessionManager,
        storage: _secureStorage,
      );
}
