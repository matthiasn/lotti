import 'dart:async';
import 'dart:convert';

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
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
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
    required AttachmentIndex attachmentIndex,
    // Phase-2 queue pipeline. Owns inbound ingestion; the retained
    // [MatrixStreamConsumer] handles encryption, attachments and
    // diagnostics with its live ingestion disabled.
    required QueuePipelineCoordinator queueCoordinator,
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
  }) : _gateway = gateway,
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
       _queueCoordinator = queueCoordinator,
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
      final pipeline =
          pipelineOverride ??
          MatrixStreamConsumer(
            sessionManager: _sessionManager,
            roomManager: _roomManager,
            loggingService: _loggingService,
            journalDb: _journalDb,
            settingsDb: _settingsDb,
            eventProcessor: _eventProcessor,
            readMarkerService: _readMarkerService,
            attachmentIndex: attachmentIndex,
            collectMetrics: collectSyncMetrics,
            sentEventRegistry: _sentEventRegistry,
            documentsDirectory: getDocumentsDirectory(),
            verboseAttachmentLogging: false,
            suppressLiveIngestion: true,
          );
      _pipeline = pipeline;

      _eventProcessor.applyObserver = pipeline.reportDbApplyDiagnostics;

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
        final coordinator =
            lifecycleCoordinator ??
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
  final QueuePipelineCoordinator _queueCoordinator;

  /// Exposes the Phase-2 queue coordinator to tests and the Sync
  /// Settings UI.
  QueuePipelineCoordinator get queueCoordinator => _queueCoordinator;

  late final SyncRoomManager _roomManager;
  late final MatrixSessionManager _sessionManager;
  late final SyncEngine _syncEngine;
  MatrixStreamConsumer? _pipeline;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<KeyVerification>? _keyVerificationRequestSubscription;
  // Optional seam for tests to inject a connectivity stream.
  final Stream<List<ConnectivityResult>>? connectivityStream;

  Client get client => _sessionManager.client;

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

    _loggingService.captureEvent(
      'MatrixService initialized - deviceId: ${client.deviceID}, '
      'deviceName: ${client.deviceName}, userId: ${client.userID}',
      domain: 'MATRIX_SERVICE',
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
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'queue.init',
        stackTrace: stackTrace,
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
  /// (`journalEntity`, `entityDefinition`, `entryLink`,
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
      entryLink: (_) => 'entryLink',
      aiConfig: (_) => 'aiConfig',
      aiConfigDelete: (_) => 'aiConfigDelete',
      themingSelection: (_) => 'themingSelection',
      backfillRequest: (_) => 'backfillRequest',
      backfillResponse: (_) => 'backfillResponse',
      agentEntity: (_) => 'agentEntity',
      agentLink: (_) => 'agentLink',
      agentBundle: (_) => 'agentBundle',
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

  Future<String?> joinRoom(String roomId) async {
    final room = await _roomManager.joinRoom(roomId);
    return room?.id ?? roomId;
  }

  Future<void> saveRoom(String roomId) async {
    await _roomManager.saveRoomId(roomId);

    // When provisioning saves the room after login, restart the
    // retained consumer's bindings (un-partials the room, attaches
    // diagnostic signals) when present, then drive catch-up through
    // the queue coordinator — which is the mandatory inbound path
    // regardless of whether a consumer pipeline was constructed.
    final pipeline = _pipeline;

    unawaited(() async {
      try {
        if (pipeline != null) {
          await pipeline.start();
        }
        // The coordinator's `start()` only seeds/prunes for whatever
        // room was current at start time. If the service started
        // before the user picked a room — or the user is now switching
        // rooms — the new room never gets its marker seeded and rows
        // from the previous room remain queued. Both are replayed
        // against the wrong room once the worker resolves the new
        // current room. Run the room-change hook before kicking the
        // bridge so catch-up walks history into a properly seeded
        // queue.
        await _queueCoordinator.onRoomChanged(roomId);
        await _queueCoordinator.triggerBridge();
      } catch (error, stackTrace) {
        _loggingService.captureException(
          error,
          domain: 'MATRIX_SERVICE',
          subDomain: 'saveRoom.bootstrap',
          stackTrace: stackTrace,
        );
      }
    }());
  }

  /// Clears only the locally persisted sync-room pointer.
  ///
  /// This does not leave the room on the homeserver. It is intended for flows
  /// that switch credentials and must avoid auto-joining a stale room ID
  /// during reconnect.
  Future<void> clearPersistedRoom() => _roomManager.clearPersistedRoom();

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

  /// Runs post-verification recovery so sync resumes without app restart.
  ///
  /// This refreshes cached device keys/trust and nudges the pipeline with a
  /// catch-up rescan to pick up pending encrypted events immediately.
  Future<void> onVerificationCompleted({required String source}) async {
    _loggingService.captureEvent(
      'verification.completed source=$source',
      domain: 'MATRIX_SERVICE',
      subDomain: 'verification',
    );

    if (!isLoggedIn()) return;

    try {
      final userId = client.userID;
      if (userId != null) {
        await client.updateUserDeviceKeys(additionalUsers: {userId});
      } else {
        await client.updateUserDeviceKeys();
      }
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'verification.updateUserDeviceKeys',
        stackTrace: stackTrace,
      );
    }

    try {
      await _syncEngine.lifecycleCoordinator.reconcileLifecycleState();
      await forceRescan();
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'verification.forceRescan',
        stackTrace: stackTrace,
      );
    }
  }

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

  Stream<KeyVerification> getIncomingKeyVerificationStream() =>
      incomingKeyVerificationController.stream;

  Future<void> startKeyVerificationListener() async {
    if (_keyVerificationRequestSubscription != null) {
      return;
    }
    _keyVerificationRequestSubscription =
        await listenForKeyVerificationRequestsWithSubscription(
          service: this,
          loggingService: _loggingService,
        );
  }

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
        _loggingService.captureException(
          error,
          domain: 'MATRIX_SERVICE',
          subDomain: 'queue.dispose',
          stackTrace: stackTrace,
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
      final map = Map<String, dynamic>.from(_pipeline!.metricsSnapshot());
      // Overlay queue ledger counts — queueActive/applied/abandoned/
      // retrying surface in Matrix Stats alongside the consumer's own
      // counters.
      if (_queueCoordinator.isRunning) {
        try {
          final stats = await _queueCoordinator.queue.stats();
          map['queueActive'] = stats.total;
          map['queueApplied'] = stats.applied;
          map['queueAbandoned'] = stats.abandoned;
          map['queueRetrying'] = stats.retrying;
        } catch (error, stackTrace) {
          _loggingService.captureException(
            error,
            domain: 'MATRIX_SERVICE',
            subDomain: 'metrics.queueStats',
            stackTrace: stackTrace,
          );
        }
      }
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
    // The queue coordinator owns catch-up; route `includeCatchUp`
    // rescans to its bridge. Live-only rescans are a no-op since the
    // consumer's own live ingestion is suppressed.
    if (!includeCatchUp) {
      _loggingService.captureEvent(
        'forceRescan.suppressed includeCatchUp=false',
        domain: 'MATRIX_SERVICE',
        subDomain: 'forceRescan',
      );
      return;
    }
    try {
      await _queueCoordinator.triggerBridge();
      _loggingService.captureEvent(
        'forceRescan.triggerBridge invoked',
        domain: 'MATRIX_SERVICE',
        subDomain: 'forceRescan',
      );
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'forceRescan.triggerBridge',
        stackTrace: stackTrace,
      );
    }
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

  /// Exposes the pipeline instance for integration tests.
  MatrixStreamConsumer? get debugPipeline => _pipeline;

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
  /// via [LoggingService.captureException].
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
      _loggingService.captureException(
        persistError,
        domain: 'MATRIX_SERVICE',
        subDomain: 'changePassword.persist',
        stackTrace: persistStack,
      );
      // Attempt to rollback the server-side password change.
      try {
        await _gateway.changePassword(
          oldPassword: newPassword,
          newPassword: oldPassword,
        );
      } catch (rollbackError, rollbackStack) {
        _loggingService.captureException(
          rollbackError,
          domain: 'MATRIX_SERVICE',
          subDomain: 'changePassword.rollback',
          stackTrace: rollbackStack,
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
