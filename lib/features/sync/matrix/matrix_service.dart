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
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/matrix/stats_signature.dart';
import 'package:lotti/features/sync/matrix/sync_engine.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/platform.dart' show isTestEnv;
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';

/// MatrixService
///
/// High-level façade for Matrix-based encrypted sync. Composes the SDK gateway,
/// session/room managers, message sender, and the stream-first pipeline
/// (`MatrixStreamConsumer`) that performs catch-up and live ingestion.
///
/// Pipeline highlights
/// - Wires `SyncEventProcessor.applyObserver` to surface DB-apply diagnostics
///   into the pipeline’s typed metrics.
/// - Proactively triggers a `forceRescan(includeCatchUp=true)` shortly after
///   startup to avoid gaps if the consumer starts before the room is fully
///   ready or network is flaky.
/// - On connectivity regain, nudges the pipeline again with a force rescan to
///   recover from offline-created bursts.
/// - Exposes `getSyncMetrics()`, `forceRescan()`, `retryNow()`, and
///   `getSyncDiagnosticsText()` for UI (Matrix Stats) and tooling.
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
    required AttachmentIndex attachmentIndex,
    SentEventRegistry? sentEventRegistry,
    bool collectSyncMetrics = false,
    bool ownsActivityGate = false,
    MatrixConfig? matrixConfig,
    String? deviceDisplayName,
    SyncRoomManager? roomManager,
    MatrixSessionManager? sessionManager,
    SyncLifecycleCoordinator? lifecycleCoordinator,
    SyncEngine? syncEngine,
    // Test-only seam to inject a pipeline instance
    @visibleForTesting MatrixStreamConsumer? pipelineOverride,
    // Optional seam to inject connectivity changes (for tests)
    this.connectivityStream,
  })  : _gateway = gateway,
        _loggingService = loggingService,
        _activityGate = activityGate,
        _messageSender = messageSender,
        _sentEventRegistry =
            sentEventRegistry ?? messageSender.sentEventRegistry,
        _journalDb = journalDb,
        _settingsDb = settingsDb,
        _readMarkerService = readMarkerService,
        _eventProcessor = eventProcessor,
        _secureStorage = secureStorage,
        _ownsActivityGate = ownsActivityGate,
        _collectSyncMetrics = collectSyncMetrics,
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
      final pipeline = pipelineOverride ??
          MatrixStreamConsumer(
            sessionManager: _sessionManager,
            roomManager: _roomManager,
            loggingService: _loggingService,
            journalDb: _journalDb,
            settingsDb: _settingsDb,
            eventProcessor: _eventProcessor,
            readMarkerService: _readMarkerService,
            documentsDirectory: documentsDirectory,
            attachmentIndex: attachmentIndex,
            collectMetrics: collectSyncMetrics,
            sentEventRegistry: _sentEventRegistry,
          );
      _pipeline = pipeline;

      _eventProcessor.applyObserver = pipeline.reportDbApplyDiagnostics;
      // Proactively kick a forceRescan(includeCatchUp=true) shortly after startup
      // to avoid gaps if the consumer started before room readiness or network flakiness.
      unawaited(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        try {
          _loggingService.captureEvent(
            'service.forceRescan.startup includeCatchUp=true',
            domain: 'MATRIX_SERVICE',
            subDomain: 'forceRescan',
          );
          await pipeline.forceRescan();
          _loggingService.captureEvent(
            'service.forceRescan.startup.done',
            domain: 'MATRIX_SERVICE',
            subDomain: 'forceRescan',
          );
        } catch (e, st) {
          _loggingService.captureException(
            e,
            domain: 'MATRIX_SERVICE',
            subDomain: 'forceRescan.startup',
            stackTrace: st,
          );
        }
      }());

      if (syncEngine != null) {
        if (pipelineOverride == null) {
          throw ArgumentError(
            'Providing a SyncEngine requires supplying pipelineOverride so '
            'MatrixService and the engine share the same pipeline instance.',
          );
        }
        final coordinatorFromEngine = syncEngine.lifecycleCoordinator;
        if (lifecycleCoordinator != null &&
            !identical(coordinatorFromEngine, lifecycleCoordinator)) {
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
              roomManager: _roomManager,
              loggingService: _loggingService,
              pipeline: pipeline,
            );
        _syncEngine = SyncEngine(
          sessionManager: _sessionManager,
          roomManager: _roomManager,
          lifecycleCoordinator: coordinator,
          loggingService: _loggingService,
        );
      }
    }

    incomingKeyVerificationRunnerController =
        StreamController<KeyVerificationRunner>.broadcast(
      onListen: publishIncomingRunnerState,
    );

    keyVerificationStream = keyVerificationController.stream;
    incomingKeyVerificationRunnerStream =
        incomingKeyVerificationRunnerController.stream;

    // On connectivity regain, nudge the pipeline with a catch-up + scan and
    // record this as a signal for observability.
    _connectivitySubscription =
        (connectivityStream ?? Connectivity().onConnectivityChanged)
            .listen((List<ConnectivityResult> result) {
      if ({
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
        ConnectivityResult.ethernet,
      }.intersection(result.toSet()).isNotEmpty) {
        // Record connectivity as a signal for metrics/observability.
        _pipeline?.recordConnectivitySignal();

        // Coalesce repeated connectivity events: only trigger a rescan when
        // there isn't one in-flight and we haven't just run one.
        if (_rescanInFlight) {
          _loggingService.captureEvent(
            'service.forceRescan.connectivity.coalesce inFlight=true',
            domain: 'MATRIX_SERVICE',
            subDomain: 'forceRescan',
          );
          return;
        }
        final now = DateTime.now();
        if (_lastRescanAt != null &&
            now.difference(_lastRescanAt!) < _minConnectivityRescanGap) {
          _loggingService.captureEvent(
            'service.forceRescan.connectivity.coalesce recent',
            domain: 'MATRIX_SERVICE',
            subDomain: 'forceRescan',
          );
          return;
        }

        _rescanInFlight = true;
        unawaited(() async {
          try {
            _loggingService.captureEvent(
              'service.forceRescan.connectivity includeCatchUp=true',
              domain: 'MATRIX_SERVICE',
              subDomain: 'forceRescan',
            );
            await _pipeline?.forceRescan();
            _loggingService.captureEvent(
              'service.forceRescan.connectivity.done',
              domain: 'MATRIX_SERVICE',
              subDomain: 'forceRescan',
            );
          } catch (e, st) {
            // Log exceptions to aid debugging, but do not crash.
            _loggingService.captureException(
              e,
              domain: 'MATRIX_SERVICE',
              subDomain: 'connectivity',
              stackTrace: st,
            );
          } finally {
            _lastRescanAt = DateTime.now();
            _rescanInFlight = false;
          }
        }());
      }
    });
  }

  static const Duration _statsDebounceDuration = Duration(
      milliseconds: 500); // Balance UI responsiveness vs emission rate.

  final MatrixSyncGateway _gateway;
  final LoggingService _loggingService;
  final UserActivityGate _activityGate;
  final MatrixMessageSender _messageSender;
  final SentEventRegistry _sentEventRegistry;
  final JournalDb _journalDb;
  final SettingsDb _settingsDb;
  final SyncReadMarkerService _readMarkerService;
  final SyncEventProcessor _eventProcessor;
  final SecureStorage _secureStorage;
  final bool _ownsActivityGate;
  final bool _collectSyncMetrics;

  late final SyncRoomManager _roomManager;
  late final MatrixSessionManager _sessionManager;
  late final SyncEngine _syncEngine;
  MatrixStreamConsumer? _pipeline;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  // Optional seam for tests to inject a connectivity stream.
  final Stream<List<ConnectivityResult>>? connectivityStream;

  // Coalesce connectivity-driven rescans to avoid storms.
  bool _rescanInFlight = false;
  DateTime? _lastRescanAt;
  static const Duration _minConnectivityRescanGap = Duration(seconds: 2);

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
  Stream<SyncRoomInvite> get inviteRequests => _roomManager.inviteRequests;

  final Map<String, int> messageCounts = {};
  int sentCount = 0;

  final StreamController<MatrixStats> messageCountsController;
  Timer? _statsEmitTimer;
  bool _statsDirty = false;
  String? _lastEmittedStatsSig;

  void _emitStatsNow() {
    // Prepare snapshot to avoid consumers mutating our internal map.
    final snapshot = MatrixStats(
      messageCounts: Map<String, int>.from(messageCounts),
      sentCount: sentCount,
    );
    final sig = buildMatrixStatsSignature(snapshot);
    if (sig == _lastEmittedStatsSig) {
      return; // no-op: identical payload as last emission
    }
    _lastEmittedStatsSig = sig;
    messageCountsController.add(snapshot);
  }

  void _scheduleStatsEmit() {
    _statsDirty = true;
    if (isTestEnv) {
      // In tests, emit immediately for determinism.
      _statsEmitTimer?.cancel();
      _statsEmitTimer = null;
      _statsDirty = false;
      _emitStatsNow();
      return;
    }
    if (_statsEmitTimer != null) return;
    _statsEmitTimer = Timer(_statsDebounceDuration, () {
      _statsEmitTimer = null;
      if (_statsDirty) {
        _statsDirty = false;
        _emitStatsNow();
      }
    });
  }

  void incrementSentCountOf(String type) {
    sentCount = sentCount + 1;
    messageCounts.update(type, (v) => v + 1, ifAbsent: () => 1);
    _scheduleStatsEmit();
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

  /// Sends a Matrix sync payload and records basic "sent" metrics.
  ///
  /// Every [`SyncMessage`] variant is mapped to a coarse message-type bucket
  /// (`journalEntity`, `entityDefinition`, `tagEntity`, `entryLink`,
  /// `aiConfig`, `aiConfigDelete`). When the SDK reports a successful send, the
  /// corresponding counter is incremented and debounced stats are emitted to the
  /// Matrix Stats UI.
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

    // Track a coarse-grained sent type for stats
    final sentType = syncMessage.map(
      journalEntity: (_) => 'journalEntity',
      entityDefinition: (_) => 'entityDefinition',
      tagEntity: (_) => 'tagEntity',
      entryLink: (_) => 'entryLink',
      aiConfig: (_) => 'aiConfig',
      aiConfigDelete: (_) => 'aiConfigDelete',
      themingSelection: (_) => 'themingSelection',
    );

    return _messageSender.sendMatrixMessage(
      message: syncMessage,
      context: MatrixMessageContext(
        syncRoomId: targetRoomId,
        syncRoom: targetRoom,
        unverifiedDevices: getUnverifiedDevices(),
      ),
      onSent: (String _, SyncMessage __) => incrementSentCountOf(sentType),
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

  Future<String> createRoom({List<String>? invite}) =>
      _roomManager.createRoom(inviteUserIds: invite);

  Future<String?> getRoom() => _roomManager.loadPersistedRoomId();

  Future<void> leaveRoom() async {
    _loggingService.captureEvent(
      'leaveRoom requested',
      domain: 'MATRIX_SERVICE',
      subDomain: 'room.leave',
    );
    await _roomManager.leaveCurrentRoom();
  }

  Future<void> inviteToSyncRoom({required String userId}) async {
    _loggingService.captureEvent(
      'inviteToSyncRoom requested user=$userId room=${_roomManager.currentRoomId}',
      domain: 'MATRIX_SERVICE',
      subDomain: 'room.invite',
    );
    await _roomManager.inviteUser(userId);
  }

  Future<void> acceptInvite(SyncRoomInvite invite) async {
    _loggingService.captureEvent(
      'acceptInvite requested room=${invite.roomId} from=${invite.senderId}',
      domain: 'MATRIX_SERVICE',
      subDomain: 'room.acceptInvite',
    );
    await _roomManager.acceptInvite(invite);
  }

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
    _statsEmitTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _syncEngine.dispose();

    // Dispose in reverse construction order: pipeline/session depend on the room manager.
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

  Future<SyncMetrics?> getSyncMetrics() async {
    if (_pipeline == null) return null;
    try {
      // If metrics collection is disabled, do not attempt to read metrics.
      if (!_collectSyncMetrics) return null;
      final map = _pipeline!.metricsSnapshot();
      return SyncMetrics.fromMap(map);
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'metrics',
        stackTrace: st,
      );
      return null;
    }
  }

  // Raw map accessor removed in favor of the expanded typed SyncMetrics model.

  Future<void> forceRescan({bool includeCatchUp = true}) async {
    final p = _pipeline;
    if (p == null) return;
    await p.forceRescan(includeCatchUp: includeCatchUp);
    _loggingService.captureEvent(
      'forceRescan(includeCatchUp=$includeCatchUp) invoked',
      domain: 'MATRIX_SERVICE',
      subDomain: 'forceRescan',
    );
  }

  Future<void> retryNow() async {
    final p = _pipeline;
    if (p == null) return;
    await p.retryNow();
    _loggingService.captureEvent(
      'retryNow invoked',
      domain: 'MATRIX_SERVICE',
      subDomain: 'retryNow',
    );
  }

  Future<String> getSyncDiagnosticsText() async {
    final p = _pipeline;
    if (p == null) return 'pipeline disabled';
    // Use raw snapshot so we include diagnostics-only fields
    final map = p.metricsSnapshot();
    final lines = map.entries.map((e) => '${e.key}=${e.value}').toList();
    // Append textual diagnostics if available
    try {
      final extras = p.diagnosticsStrings();
      lines.addAll(extras.entries.map((e) => '${e.key}=${e.value}'));
    } catch (_) {
      // Older pipeline without diagnosticsStrings
    }
    return lines.join('\n');
  }

  // Visible for testing only
  /// Exposes the pipeline instance for tests. Returns `null` when disabled or
  /// the service was constructed without a pipeline.
  @visibleForTesting
  MatrixStreamConsumer? get debugPipeline => _pipeline;

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
