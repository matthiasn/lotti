import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/config.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/matrix/stats_signature.dart';
import 'package:lotti/features/sync/matrix/sync_engine.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/domain_logging.dart';
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
part 'matrix_service_ops.dart';

/// Field-access contract for [MatrixService] operations, implemented by
/// the concrete fields/getters and consumed by [_MatrixServiceOps].
abstract class _MatrixServiceBase {
  MatrixSyncGateway get _gateway;
  DomainLogger get _loggingService;
  bool get _collectSyncMetrics;
  QueuePipelineCoordinator get _queueCoordinator;
  SyncRoomManager get _roomManager;
  MatrixSessionManager get _sessionManager;
  SyncEngine get _syncEngine;
  MatrixStreamConsumer? get _pipeline;
  StreamController<KeyVerification> get incomingKeyVerificationController;
  StreamSubscription<KeyVerification>? get _keyVerificationRequestSubscription;
  set _keyVerificationRequestSubscription(
    StreamSubscription<KeyVerification>? value,
  );
  Client get client;
  MatrixConfig? get matrixConfig;
}

class MatrixService extends _MatrixServiceBase with _MatrixServiceOps {
  MatrixService({
    required this._gateway,
    required this._loggingService,
    required this._activityGate,
    required this._messageSender,
    required this._settingsDb,
    required this._eventProcessor,
    required this._secureStorage,
    required this._queueCoordinator,
    bool collectSyncMetrics = false,
    this._ownsActivityGate = false,
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
  }) : _collectSyncMetrics = collectSyncMetrics,
       keyVerificationController =
           StreamController<KeyVerificationRunner>.broadcast(),
       messageCountsController = StreamController<MatrixStats>.broadcast(),
       incomingKeyVerificationController =
           StreamController<KeyVerification>.broadcast() {
    _roomManager =
        roomManager ??
        sessionManager?.roomManager ??
        SyncRoomManager(
          gateway: _gateway,
          settingsDb: _settingsDb,
          loggingService: _loggingService,
        );
    _sessionManager =
        sessionManager ??
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
      // Share a single pipeline instance between the coordinator (which drives
      // its lifecycle) and this service (which observes its metrics and
      // diagnostics). Constructing a separate local pipeline while the injected
      // coordinator drives its own would split-brain the two.
      final SyncLifecycleCoordinator coordinator;
      final MatrixStreamConsumer? pipeline;
      if (lifecycleCoordinator != null) {
        coordinator = lifecycleCoordinator;
        // The coordinator already owns a pipeline; adopt it as the effective
        // pipeline so saveRoom/metrics/diagnostics observe the same instance
        // the coordinator drives.
        pipeline = lifecycleCoordinator.pipeline as MatrixStreamConsumer?;
      } else {
        pipeline =
            pipelineOverride ??
            MatrixStreamConsumer(
              sessionManager: _sessionManager,
              roomManager: _roomManager,
              loggingService: _loggingService,
              settingsDb: _settingsDb,
              eventProcessor: _eventProcessor,
              collectMetrics: collectSyncMetrics,
            );
        coordinator = SyncLifecycleCoordinator(
          gateway: _gateway,
          sessionManager: _sessionManager,
          roomManager: _roomManager,
          loggingService: _loggingService,
          pipeline: pipeline,
        );
      }
      _pipeline = pipeline;

      if (pipeline != null) {
        _eventProcessor.applyObserver = pipeline.reportDbApplyDiagnostics;
      }

      _syncEngine = SyncEngine(
        sessionManager: _sessionManager,
        roomManager: _roomManager,
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

    // On connectivity regain, record a signal for metrics/observability.
    // Catch-up itself is driven by the queue coordinator's bridge (the
    // `limited=true` reconnect trigger), so nothing further is needed
    // here.
    _connectivitySubscription =
        (connectivityStream ?? Connectivity().onConnectivityChanged).listen((
          List<ConnectivityResult> result,
        ) {
          if ({
            ConnectivityResult.wifi,
            ConnectivityResult.mobile,
            ConnectivityResult.ethernet,
          }.intersection(result.toSet()).isNotEmpty) {
            _pipeline?.recordConnectivitySignal();
          }
        });
  }

  static const Duration _statsDebounceDuration = Duration(
    milliseconds: 500,
  ); // Balance UI responsiveness vs emission rate.

  @override
  final MatrixSyncGateway _gateway;
  @override
  final DomainLogger _loggingService;
  final UserActivityGate _activityGate;
  final MatrixMessageSender _messageSender;
  final SettingsDb _settingsDb;
  final SyncEventProcessor _eventProcessor;
  final SecureStorage _secureStorage;
  final bool _ownsActivityGate;
  @override
  final bool _collectSyncMetrics;
  @override
  final QueuePipelineCoordinator _queueCoordinator;

  /// Exposes the queue coordinator to tests and the Sync Settings UI.
  QueuePipelineCoordinator get queueCoordinator => _queueCoordinator;

  @override
  late final SyncRoomManager _roomManager;
  @override
  late final MatrixSessionManager _sessionManager;
  @override
  late final SyncEngine _syncEngine;
  @override
  MatrixStreamConsumer? _pipeline;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  @override
  StreamSubscription<KeyVerification>? _keyVerificationRequestSubscription;
  // Optional seam for tests to inject a connectivity stream.
  final Stream<List<ConnectivityResult>>? connectivityStream;

  @override
  Client get client => _sessionManager.client;

  @override
  MatrixConfig? get matrixConfig => _sessionManager.matrixConfig;

  String? get syncRoomId => _roomManager.currentRoomId;
  Room? get syncRoom => _roomManager.currentRoom;
  Stream<SyncRoomInvite> get inviteRequests => _roomManager.inviteRequests;

  /// Discovers existing Lotti sync rooms the user is already a member of.
  ///
  /// Used for the single-user multi-device flow where Device B can discover
  /// and join an existing sync room instead of waiting for an invite.
  Future<List<SyncRoomCandidate>> discoverExistingSyncRooms() =>
      _roomManager.discoverExistingSyncRooms();

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

  @override
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

    await _startQueuePipeline();

    _loggingService.log(
      LogDomain.sync,
      'MatrixService initialized - deviceId: ${client.deviceID}, '
      'deviceName: ${client.deviceName}, userId: ${client.userID}',
      subDomain: 'init',
    );
  }

  /// Test seam exposing [_startQueuePipeline] without requiring a full
  /// `init()` flow (which drags in gateway login, connectivity, etc.).
  @visibleForTesting
  Future<void> debugStartQueuePipelineForTest() => _startQueuePipeline();

  Future<void> _startQueuePipeline() async {
    try {
      await _queueCoordinator.start();
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'queue.init',
      );
      // The queue coordinator is the only inbound path, so surface the
      // failure to the caller instead of silently running with nothing
      // ingesting.
      rethrow;
    }
  }

  Future<void> listen() async {
    await startKeyVerificationListener();
    final savedRoomId = await _roomManager.loadPersistedRoomId();
    final joinedRooms = client.rooms.map((r) => r.id).toList();
    _loggingService.log(
      LogDomain.sync,
      'Sync state - savedRoomId: $savedRoomId, '
      'syncRoomId: ${_roomManager.currentRoomId}, '
      'joinedRooms: $joinedRooms',
      subDomain: 'listen',
    );
  }

  Future<void> _onLifecycleLogout() async {
    _loggingService.log(
      LogDomain.sync,
      'Sync lifecycle paused (logged out).',
      subDomain: 'logoutLifecycle',
    );
  }

  /// Sends a Matrix sync payload and records basic "sent" metrics.
  ///
  /// Every [`SyncMessage`] variant is mapped to a coarse message-type bucket
  /// (`journalEntity`, `entityDefinition`, `entryLink`, `aiConfig`,
  /// `aiConfigDelete`, `configFlag`, `themingSelection`, `notification`,
  /// `notificationStateUpdate`, `backfillRequest`, `backfillResponse`,
  /// `agentEntity`, `agentLink`, `agentBundle`, `outboxBundle`). When the SDK
  /// reports a successful send, the corresponding counter is incremented and
  /// debounced stats are emitted to the Matrix Stats UI.
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
      entryLink: (_) => 'entryLink',
      aiConfig: (_) => 'aiConfig',
      aiConfigDelete: (_) => 'aiConfigDelete',
      configFlag: (_) => 'configFlag',
      themingSelection: (_) => 'themingSelection',
      notification: (_) => 'notification',
      notificationStateUpdate: (_) => 'notificationStateUpdate',
      backfillRequest: (_) => 'backfillRequest',
      backfillResponse: (_) => 'backfillResponse',
      agentEntity: (_) => 'agentEntity',
      agentLink: (_) => 'agentLink',
      agentBundle: (_) => 'agentBundle',
      outboxBundle: (_) => 'outboxBundle',
      syncNodeProfile: (_) => 'syncNodeProfile',
    );

    return _messageSender.sendMatrixMessage(
      message: syncMessage,
      context: MatrixMessageContext(
        syncRoomId: targetRoomId,
        syncRoom: targetRoom,
        unverifiedDevices: getUnverifiedDevices(),
      ),
      onSent: (String _, SyncMessage _) => incrementSentCountOf(sentType),
    );
  }

  Future<bool> login({bool waitForLifecycle = true}) =>
      _syncEngine.connectWithLifecycleOption(
        shouldAttemptLogin: true,
        waitForLifecycle: waitForLifecycle,
      );

  Future<bool> connect() => _syncEngine.connect(shouldAttemptLogin: false);

  Future<void> logout() async {
    await _syncEngine.logout();
  }

  Future<void> dispose() async {
    await _keyVerificationRequestSubscription?.cancel();
    _keyVerificationRequestSubscription = null;
    await messageCountsController.close();
    await keyVerificationController.close();
    await incomingKeyVerificationRunnerController.close();
    await incomingKeyVerificationController.close();
    _statsEmitTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _syncEngine.dispose();

    // Drain the queue pipeline before the session/room teardown so
    // `commitApplied` can still advance markers.
    if (_queueCoordinator.isRunning) {
      try {
        await _queueCoordinator.stop(drainFirst: true);
      } catch (error, stackTrace) {
        _loggingService.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: 'queue.dispose',
        );
      }
    }

    // Dispose in reverse construction order: pipeline/session depend on the room manager.
    await _sessionManager.dispose();
    await _roomManager.dispose();
    if (_ownsActivityGate) {
      await _activityGate.dispose();
    }
  }

  Future<MatrixConfig?> loadConfig() => loadMatrixConfig(
    session: _sessionManager,
    storage: _secureStorage,
  );
  Future<void> deleteConfig() => deleteMatrixConfig(
    session: _sessionManager,
    storage: _secureStorage,
  );

  /// Changes the password for the currently logged-in user and updates
  /// the stored configuration.
  ///
  /// If the password change succeeds on the server but persisting the new
  /// config fails, attempts to rollback the server-side password. Both the
  /// original persist error and any rollback failure are logged as critical
  /// via `DomainLogger.error`.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _gateway.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    try {
      final config = await loadConfig();
      if (config != null) {
        await setConfig(config.copyWith(password: newPassword));
      }
    } catch (persistError, persistStack) {
      _loggingService.error(
        LogDomain.sync,
        persistError,
        stackTrace: persistStack,
        subDomain: 'changePassword.persist',
      );
      // Attempt to rollback the server-side password change.
      try {
        await _gateway.changePassword(
          oldPassword: newPassword,
          newPassword: oldPassword,
        );
      } catch (rollbackError, rollbackStack) {
        _loggingService.error(
          LogDomain.sync,
          rollbackError,
          stackTrace: rollbackStack,
          subDomain: 'changePassword.rollback',
        );
      }
      rethrow;
    }
  }

  Future<void> setConfig(MatrixConfig config) => setMatrixConfig(
    config,
    session: _sessionManager,
    storage: _secureStorage,
  );
}
