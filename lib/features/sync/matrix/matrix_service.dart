import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/database/sync_key_value_store.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/config.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service_ops.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/matrix/stats_signature.dart';
import 'package:lotti/features/sync/matrix/sync_engine.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/models/sync_login_state.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/queue/sync_queue_control.dart';
import 'package:lotti/features/sync/sync_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/secure_storage.dart';
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
/// State event type the provisioning service reads as rotation proof; must
/// match `ROTATION_EVENT_TYPE` in the service's `bundle_rotation_service.py`.
const String rotationProofEventType = 'com.lotti.sync.provisioning.rotation';

class MatrixService implements SyncService {
  MatrixService({
    required this._gateway,
    required this._loggingService,
    required this._messageSender,
    required this._settingsDb,
    required this._queueCoordinator,
    this._activityGate,
    this._eventProcessor,
    this._secureStorage,
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
        _eventProcessor?.applyObserver = pipeline.reportDbApplyDiagnostics;
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
    // `limited=true` reconnect trigger). A session that never connected —
    // a start without network — is connected now rather than at its next
    // scheduled attempt.
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
            if (_reconnectTimer != null) {
              _reconnectTimer!.cancel();
              _reconnectTimer = null;
              _reconnecting = _connectUntilConnected();
            }
          }
        });

    _ops = MatrixServiceOps(
      gateway: _gateway,
      loggingService: _loggingService,
      collectSyncMetrics: _collectSyncMetrics,
      queueCoordinator: _queueCoordinator,
      roomManager: _roomManager,
      sessionManager: _sessionManager,
      syncEngine: _syncEngine,
      incomingKeyVerificationController: incomingKeyVerificationController,
      pipeline: () => _pipeline,
      keyVerificationRequestSubscription: () =>
          _keyVerificationRequestSubscription,
      setKeyVerificationRequestSubscription: (value) =>
          _keyVerificationRequestSubscription = value,
      service: () => this,
      settingsDb: _settingsDb,
    );
  }

  /// Optional composition-root hook for protocol state that must advance only
  /// after a sync message has been accepted by Matrix.
  @override
  Future<void> Function(SyncMessage message)? onSyncMessageSent;

  /// Room, device-verification and diagnostics operations, delegated to from
  /// the thin public methods below to keep this file under the size limit.
  late final MatrixServiceOps _ops;

  static const Duration _statsDebounceDuration = Duration(
    milliseconds: 500,
  ); // Balance UI responsiveness vs emission rate.

  final MatrixSyncGateway _gateway;
  final DomainLogger _loggingService;

  /// Disposed with the service when it owns it; null in the sync isolate,
  /// where nothing waits for the user (ADR 0142).
  final UserActivityGate? _activityGate;
  final MatrixMessageSender _messageSender;
  final SyncKeyValueStore _settingsDb;

  /// The UI isolate's apply step, for the pipeline's startup marker and
  /// its apply diagnostics; null in the sync isolate, which runs none.
  final SyncEventProcessor? _eventProcessor;

  /// The keychain the credentials live in. Null in the sync isolate —
  /// secure storage is a plugin — where the host hands the config over and
  /// [loadConfig], [setConfig] and [deleteConfig] act on the session only.
  final SecureStorage? _secureStorage;
  final bool _ownsActivityGate;
  final bool _collectSyncMetrics;
  final QueuePipelineCoordinator _queueCoordinator;

  /// Exposes the queue coordinator to tests and the Sync Settings UI.
  QueuePipelineCoordinator get queueCoordinator => _queueCoordinator;

  @override
  SyncQueueControl get queueControl => _queueCoordinator;

  late final SyncRoomManager _roomManager;
  late final MatrixSessionManager _sessionManager;
  late final SyncEngine _syncEngine;
  MatrixStreamConsumer? _pipeline;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<KeyVerification>? _keyVerificationRequestSubscription;
  // Optional seam for tests to inject a connectivity stream.
  final Stream<List<ConnectivityResult>>? connectivityStream;

  Client get client => _sessionManager.client;

  /// The account this session is logged in as, or null when logged out.
  @override
  String? get ownUserId => client.userID;

  /// This session's device id, or null when logged out. With [ownUserId] it
  /// is the identity the SDK orders a verification glare by.
  @override
  String? get ownDeviceId => client.deviceID;

  @override
  String? get syncRoomId => _roomManager.currentRoomId;

  /// The sync room id on every change, null when cleared — for UI that gates
  /// on whether sync is configured. [syncRoomId] is a plain read and cannot
  /// notify on its own.
  @override
  Stream<String?> get syncRoomIdChanges => _roomManager.roomIdChanges;
  Room? get syncRoom => _roomManager.currentRoom;

  @override
  final Map<String, int> messageCounts = {};
  @override
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

  // ------------------------------------------- verification, in plain types
  //
  // The UI never holds a runner or an SDK `KeyVerification` (ADR 0142): it
  // reads [SyncVerificationState] snapshots and acts by ceremony id.

  /// Incoming requests by ceremony id: what [acceptVerification] and
  /// [handOffOutgoingVerificationTo] act on before this device has answered
  /// a request, which is before it has a runner.
  final Map<String, KeyVerification> _incomingRequests =
      <String, KeyVerification>{};

  /// Called by the request listener for every incoming request.
  void rememberIncomingRequest(KeyVerification keyVerification) {
    _incomingRequests[verificationIdOf(keyVerification)] = keyVerification;
    // Bounded: a handful of requests outlive a session at most.
    while (_incomingRequests.length > 16) {
      _incomingRequests.remove(_incomingRequests.keys.first);
    }
  }

  // Created once: a getter that mapped the stream afresh would hand every
  // rebuild of a StreamBuilder a new instance to resubscribe to, and the
  // controller would replay its state on each of those re-listens.
  @override
  late final Stream<SyncVerificationState> outgoingVerifications =
      keyVerificationStream.map((runner) => runner.toState());

  @override
  SyncVerificationState? get outgoingVerification =>
      keyVerificationRunner?.toState();

  @override
  late final Stream<SyncVerificationState> incomingVerifications =
      incomingKeyVerificationRunnerStream.map((runner) => runner.toState());

  @override
  SyncVerificationState? get incomingVerification =>
      incomingKeyVerificationRunner?.toState();

  @override
  late final Stream<SyncVerificationState> incomingVerificationRequests =
      incomingKeyVerificationController.stream.map(_requestState);

  SyncVerificationState _requestState(KeyVerification request) {
    final lastStep = request.lastStep ?? '';
    return SyncVerificationState(
      id: verificationIdOf(request),
      direction: SyncVerificationDirection.incoming,
      peerUserId: request.userId,
      peerDeviceId: request.deviceId,
      lastStep: lastStep,
      outcome: keyVerificationOutcome(
        lastStep: lastStep,
        keyVerification: request,
      ),
    );
  }

  KeyVerificationRunner? _runnerFor(String id) {
    for (final runner in [
      keyVerificationRunner,
      incomingKeyVerificationRunner,
    ]) {
      if (runner != null && runner.id == id) return runner;
    }
    return null;
  }

  @override
  Future<void> acceptVerification(String id) async {
    final runner = _runnerFor(id);
    if (runner != null) return runner.acceptVerification();
    await _incomingRequests[id]?.acceptVerification();
  }

  @override
  Future<void> acceptEmojiVerification(String id) async {
    await _runnerFor(id)?.acceptEmojiVerification();
  }

  @override
  Future<void> cancelVerification(String id) async {
    final runner = _runnerFor(id);
    if (runner != null) {
      await cancelAbandonedVerification(
        runner,
        loggingService: _loggingService,
      );
      return;
    }
    final request = _incomingRequests[id];
    if (request == null || request.isDone) return;
    try {
      await request.cancel();
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'verification.cancelRequest',
      );
    }
  }

  /// Hands the open outgoing sheet over to the incoming request: cancels the
  /// ceremony this device started, wraps the peer's in a runner published on
  /// the **outgoing** stream — the one `VerificationModal` renders — and
  /// accepts it, so the sheet the user is looking at carries on with the
  /// peer's ceremony and the emoji appear in it.
  ///
  /// The old runner is detached before the cancel: a cancel fires the SDK's
  /// `onUpdate`, and a still-attached runner would publish the cancelled
  /// state and make the modal arm its auto-dismiss mid-ceremony.
  @override
  Future<void> handOffOutgoingVerificationTo(String incomingId) async {
    final incoming =
        _incomingRequests[incomingId] ??
        (incomingKeyVerificationRunner?.id == incomingId
            ? incomingKeyVerificationRunner?.keyVerification
            : null);
    if (incoming == null) {
      throw StateError('no incoming verification $incomingId to hand off to');
    }
    final outgoing = keyVerificationRunner;
    if (outgoing != null) {
      outgoing.stopTimer();
      try {
        await outgoing.keyVerification.cancel();
      } catch (error, stackTrace) {
        // The withdrawn ceremony is detached either way; a cancel the
        // homeserver did not take must not leave the peer's request
        // unanswered and the open sheet frozen.
        _loggingService.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: 'verification.handOff.cancel',
        );
      }
    }
    final runner = KeyVerificationRunner(
      incoming,
      controller: keyVerificationController,
      name: 'Outgoing KeyVerificationRunner (handed off)',
      direction: SyncVerificationDirection.outgoing,
      domainLogger: _loggingService,
      onCompleted: (source) => onVerificationCompleted(source: source),
    );
    keyVerificationRunner = runner;
    await runner.acceptVerification();
  }

  @override
  Stream<SyncLoginState> get loginStateChanges =>
      client.onLoginStateChanged.stream.map(
        (state) => switch (state) {
          LoginState.loggedIn => SyncLoginState.loggedIn,
          LoginState.loggedOut => SyncLoginState.loggedOut,
          LoginState.softLoggedOut => SyncLoginState.softLoggedOut,
        },
      );

  @override
  String? get homeserverHost => client.homeserver?.host;

  @override
  Stream<MatrixStats> get stats => messageCountsController.stream;

  @override
  InboundQueue get inboundQueue => _queueCoordinator.queue;

  @override
  Future<void> init() async {
    await _syncEngine.initialize(
      onLogin: listen,
      onLogout: _onLifecycleLogout,
    );
    await loadConfig();
    await _connectUntilConnected();

    await _startQueuePipeline();

    _loggingService.log(
      LogDomain.sync,
      'MatrixService initialized',
      subDomain: 'init',
    );
  }

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
    await ensureExclusionPolicyRotation();
  }

  /// Clears the rotation gate so the next login re-evaluates it for whatever
  /// session and room come back.
  void _resetExclusionRotationGate() => _megolmRotationGate = null;

  Future<void> _onLifecycleLogout() async {
    _resetExclusionRotationGate();
    _loggingService.log(
      LogDomain.sync,
      'Sync lifecycle paused (logged out).',
      subDomain: 'logoutLifecycle',
    );
  }

  /// Completes once the ADR 0045 megolm rotation has run for this session.
  ///
  /// `OutboxService` reacts to `LoginState.loggedIn` independently of
  /// [listen], so a queued row could otherwise be encrypted with the
  /// pre-upgrade outbound session before the wipe finishes. Every send waits
  /// on this gate; the work itself is idempotent and runs at most once per
  /// login.
  Future<void>? _megolmRotationGate;

  Future<void> ensureExclusionPolicyRotation() =>
      _megolmRotationGate ??= _ops.rotateOutboundSessionsForExclusionPolicy();

  /// Sends a Matrix sync payload and records basic "sent" metrics.
  ///
  /// Every [`SyncMessage`] variant is mapped to a coarse message-type bucket:
  /// `journalEntity`, `entityDefinition`, `entryLink`, `aiConfig`,
  /// `aiConfigDelete`, `savedTaskFilter`, `savedTaskFilterDelete`, `configFlag`,
  /// `themingSelection`, `dailyOsUserName`, `companionCustomization`,
  /// `gitHubAccount`, `notification`,
  /// `notificationStateUpdate`, `onboardingSnapshotBegin`,
  /// `onboardingSnapshotAccepted`, `onboardingTerminalCounters`,
  /// `onboardingSnapshotEnd`, `consumptionEvent`, `backfillRequest`,
  /// `mediaRequest`, `deepBackfillInventory`, `deepBackfillRequest`,
  /// `agentWakeCoordination`, `backfillResponse`, `agentEntity`, `agentLink`,
  /// `agentBundle`, `outboxBundle`, and `syncNodeProfile`. When the SDK reports
  /// a successful send, the corresponding counter is incremented and
  /// debounced stats are emitted to the Matrix Stats UI.
  ///
  /// Returns `false` on a retryable failure. Lets
  /// `SyncMessageTooLargeException` through when the payload can never fit
  /// (see [MatrixMessageSender.sendMatrixMessage]).
  @override
  Future<bool> sendMatrixMsg(
    SyncMessage syncMessage, {
    String? myRoomId,
  }) async {
    // Never encrypt with a session that predates the exclusion policy.
    await ensureExclusionPolicyRotation();

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
      savedTaskFilter: (_) => 'savedTaskFilter',
      savedTaskFilterDelete: (_) => 'savedTaskFilterDelete',
      configFlag: (_) => 'configFlag',
      themingSelection: (_) => 'themingSelection',
      dailyOsUserName: (_) => 'dailyOsUserName',
      companionCustomization: (_) => 'companionCustomization',
      gitHubAccount: (_) => 'gitHubAccount',
      notification: (_) => 'notification',
      notificationStateUpdate: (_) => 'notificationStateUpdate',
      onboardingSnapshotBegin: (_) => 'onboardingSnapshotBegin',
      onboardingSnapshotAccepted: (_) => 'onboardingSnapshotAccepted',
      onboardingTerminalCounters: (_) => 'onboardingTerminalCounters',
      onboardingSnapshotEnd: (_) => 'onboardingSnapshotEnd',
      consumptionEvent: (_) => 'consumptionEvent',
      backfillRequest: (_) => 'backfillRequest',
      mediaRequest: (_) => 'mediaRequest',
      deepBackfillInventory: (_) => 'deepBackfillInventory',
      deepBackfillRequest: (_) => 'deepBackfillRequest',
      agentWakeCoordination: (_) => 'agentWakeCoordination',
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
        unverifiedDevices: _gateway.unverifiedDevices(),
      ),
      onSent: (String _, SyncMessage _) async {
        incrementSentCountOf(sentType);
        // The payload sender strips outbox-bundle children into an attachment
        // before transport. Protocol lifecycle hooks need the original
        // logical message so they can observe controls contained in that
        // successfully sent bundle.
        await onSyncMessageSent?.call(syncMessage);
      },
    );
  }

  @override
  Future<bool> login({bool waitForLifecycle = true}) =>
      _syncEngine.connectWithLifecycleOption(
        shouldAttemptLogin: true,
        waitForLifecycle: waitForLifecycle,
      );

  @override
  Future<bool> connect() => _syncEngine.connect(shouldAttemptLogin: false);

  /// The next connect a failed one scheduled, and the attempt it started.
  Timer? _reconnectTimer;
  Future<void>? _reconnecting;
  Duration _reconnectDelay = SyncTuning.matrixReconnectInitialDelay;
  bool _disposed = false;

  /// Connects the stored session, and until that succeeds tries again with
  /// a doubling wait (and at once when connectivity returns): a start
  /// without network used to try once and leave sync off until the next
  /// launch. Stops once the client is logged in by any path, without a
  /// configuration, or on [dispose].
  Future<void> _connectUntilConnected() async {
    _reconnectTimer = null;
    if (_disposed) return;
    if (await connect() || isLoggedIn()) {
      _reconnectDelay = SyncTuning.matrixReconnectInitialDelay;
      return;
    }
    if (_disposed || _sessionManager.matrixConfig == null) return;
    final delay = _reconnectDelay;
    final doubled = delay * 2;
    _reconnectDelay = doubled > SyncTuning.matrixReconnectMaxDelay
        ? SyncTuning.matrixReconnectMaxDelay
        : doubled;
    _loggingService.log(
      LogDomain.sync,
      'connect failed; retrying in ${delay.inSeconds}s',
      subDomain: 'connect.retry',
    );
    _reconnectTimer = Timer(
      delay,
      () => _reconnecting = _connectUntilConnected(),
    );
  }

  @override
  Future<void> logout() async {
    await _syncEngine.logout();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _reconnecting;
    await _keyVerificationRequestSubscription?.cancel();
    _keyVerificationRequestSubscription = null;
    // Live ceremonies poll every 100 ms and publish into the controllers
    // closed below.
    keyVerificationRunner?.stopTimer();
    incomingKeyVerificationRunner?.stopTimer();
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
      await _activityGate?.dispose();
    }
  }

  @override
  Future<MatrixConfig?> loadConfig() {
    final storage = _secureStorage;
    if (storage == null) return Future.value(_sessionManager.matrixConfig);
    return loadMatrixConfig(session: _sessionManager, storage: storage);
  }

  @override
  Future<void> deleteConfig() async {
    final storage = _secureStorage;
    if (storage == null) {
      _sessionManager.matrixConfig = null;
      await _sessionManager.logout();
      return;
    }
    await deleteMatrixConfig(session: _sessionManager, storage: storage);
  }

  /// Changes the password for the currently logged-in user and updates
  /// the stored configuration.
  ///
  /// If the password change succeeds on the server but persisting the new
  /// config fails, attempts to rollback the server-side password. Both the
  /// original persist error and any rollback failure are logged as critical
  /// via `DomainLogger.error`.
  @override
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

  @override
  Future<void> setConfig(MatrixConfig config) {
    final storage = _secureStorage;
    if (storage == null) {
      _sessionManager.matrixConfig = config;
      return Future.value();
    }
    return setMatrixConfig(config, session: _sessionManager, storage: storage);
  }

  // Room, device-verification and diagnostics operations. These thin
  // delegators forward to [MatrixServiceOps] (see matrix_service_ops.dart) and
  // form part of MatrixService's mocked public API — keep the signatures here.

  @override
  Future<String?> joinRoom(String roomId) => _ops.joinRoom(roomId);

  /// Publishes the proof the paid provisioning service reads before it
  /// destroys a bundle's escrow: the challenge derived from the claim secret,
  /// as a state event keyed by the bundle id. Plain state, so it carries
  /// nothing secret — the challenge is only meaningful to the server that
  /// issued the bundle.
  @override
  Future<void> publishRotationProof({
    required String roomId,
    required String bundleId,
    required String challenge,
  }) => _gateway.setRoomState(
    roomId: roomId,
    eventType: rotationProofEventType,
    stateKey: bundleId,
    content: {'challenge': challenge},
  );

  /// Creates the account's encrypted sync room and returns its id, for the
  /// first device signing in with its own credentials rather than a bundle.
  @override
  Future<String> createRoom() => _ops.createRoom();

  /// The sync room the signed-in account already belongs to, if any.
  @override
  Future<String?> findSyncRoom() => _ops.findSyncRoom();

  @override
  Future<void> saveRoom(String roomId) => _ops.saveRoom(roomId);

  /// Clears only the locally persisted sync-room pointer.
  ///
  /// This does not leave the room on the homeserver. It is intended for flows
  /// that switch credentials and must avoid auto-joining a stale room ID
  /// during reconnect.
  @override
  Future<void> clearPersistedRoom() => _ops.clearPersistedRoom();

  @override
  bool isLoggedIn() => _ops.isLoggedIn();

  @override
  Future<String?> getRoom() => _ops.getRoom();

  @override
  List<SyncDeviceInfo> getUnverifiedDevices() => _ops.getUnverifiedDevices();

  @override
  Future<void> verifyDevice({
    required String userId,
    required String deviceId,
  }) => _ops.verifyDevice(userId: userId, deviceId: deviceId);

  /// Runs post-verification recovery so sync resumes without app restart.
  ///
  /// This refreshes cached device keys/trust and nudges the pipeline with a
  /// catch-up rescan to pick up pending encrypted events immediately.
  Future<void> onVerificationCompleted({required String source}) =>
      _ops.onVerificationCompleted(source: source);

  /// Removes the session [deviceId] from the sync account.
  ///
  /// Pass [reauthPassword] to authenticate with a password the user just
  /// entered instead of the stored one — the recovery path after the
  /// homeserver rejected the persisted credential. See
  /// [MatrixServiceOps.deleteDeviceById].
  @override
  Future<void> deleteDeviceById(
    String deviceId, {
    String? reauthPassword,
  }) async {
    try {
      await _ops.deleteDeviceById(deviceId, reauthPassword: reauthPassword);
    } on MatrixException catch (error) {
      // The UI knows no SDK type (ADR 0142): a refused credential becomes
      // the one exception it acts on, everything else passes through.
      if (error.errcode == 'M_FORBIDDEN') {
        throw SyncReauthRequiredException('$error');
      }
      rethrow;
    }
  }

  @override
  Future<List<SyncDeviceInfo>> getSyncDevices() => _ops.getSyncDevices();

  Stream<KeyVerification> getIncomingKeyVerificationStream() =>
      _ops.getIncomingKeyVerificationStream();

  Future<void> startKeyVerificationListener() =>
      _ops.startKeyVerificationListener();

  @override
  Future<Map<String, dynamic>> getDiagnosticInfo() => _ops.getDiagnosticInfo();

  @override
  Future<SyncMetrics?> getSyncMetrics() => _ops.getSyncMetrics();

  @override
  Future<void> forceRescan({bool includeCatchUp = true}) =>
      _ops.forceRescan(includeCatchUp: includeCatchUp);

  /// User-facing "Retry pending failures now" hook. Resurrects every
  /// abandoned ledger row that is still below the per-row resurrection
  /// hard cap (so backed-off / leased items wake up immediately) and
  /// nudges the bridge in case a remote gap is what's holding the worker.
  @override
  Future<void> retryNow() => _ops.retryNow();

  @override
  Future<String> getSyncDiagnosticsText() => _ops.getSyncDiagnosticsText();

  /// Exposes the pipeline instance for integration tests.
  MatrixStreamConsumer? get debugPipeline => _ops.debugPipeline;
}
