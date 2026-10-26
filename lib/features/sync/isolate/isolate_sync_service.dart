import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_host.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_stack.dart';
import 'package:lotti/features/sync/matrix/config.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/model/sync_message_too_large_exception.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/models/sync_login_state.dart';
import 'package:lotti/features/sync/models/sync_verification.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/sync_queue_control.dart';
import 'package:lotti/features/sync/sync_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/secure_storage.dart';

/// `SyncService` answered from the sync isolate (ADR 0142, step 4b): every
/// call is a command to the worker that hosts the Matrix stack, every stream
/// is fed from the events it reports, and the plain readers — logged in, the
/// account, the room, the latest ceremonies, the counters — answer from the
/// last event received, so a page reads them without a round trip.
///
/// The keychain stays here: [loadConfig], [setConfig] and [deleteConfig] act
/// on secure storage, which is a plugin, and tell the worker what changed.
/// Connectivity is a plugin too, so this side watches it and forwards it.
///
/// A worker that is starting, or respawning after a crash, answers no
/// command: calls fail fast with [SyncIsolateFailure] `notRunning`, and the
/// outbox retries as it does for any transient failure. When a worker comes
/// up it is handed the current credentials and, if [init] already ran,
/// started again — a respawned worker boots from the config the host was
/// built with and knows nothing else.
class IsolateSyncService implements SyncService {
  IsolateSyncService({
    required SyncIsolateHost host,
    required SecureStorage secureStorage,
    required InboundQueue inboundQueue,
    required AttachmentIndex attachmentIndex,
    required DomainLogger logger,
    Stream<List<ConnectivityResult>>? connectivityStream,
  }) : this._(
         host,
         secureStorage,
         inboundQueue,
         attachmentIndex,
         logger,
         connectivityStream,
       );

  IsolateSyncService._(
    this._host,
    this._secureStorage,
    this.inboundQueue,
    this._attachmentIndex,
    this._logger,
    Stream<List<ConnectivityResult>>? connectivityStream,
  ) {
    _eventSubscription = _host.events.listen(_onEvent);
    _stateSubscription = _host.states.listen(_onState);
    _connectivitySubscription =
        (connectivityStream ?? Connectivity().onConnectivityChanged).listen((
          results,
        ) {
          final online = {
            ConnectivityResult.wifi,
            ConnectivityResult.mobile,
            ConnectivityResult.ethernet,
          }.intersection(results.toSet()).isNotEmpty;
          _tell(SyncIsolateConnectivityChanged(online: online));
        });
    queueControl = _IsolateSyncQueueControl(this);
  }

  static const _subDomain = 'isolate.proxy';

  final SyncIsolateHost _host;
  final SecureStorage _secureStorage;
  final DomainLogger _logger;
  final AttachmentIndex _attachmentIndex;

  /// The UI isolate's own connection to the queue, for the depth the pages
  /// show and the drain the agent runtime waits for. Reads only.
  @override
  final InboundQueue inboundQueue;

  /// The producer side of the pipeline, answered by the worker.
  @override
  late final SyncQueueControl queueControl;

  late final StreamSubscription<SyncIsolateEvent> _eventSubscription;
  late final StreamSubscription<SyncIsolateState> _stateSubscription;
  late final StreamSubscription<List<ConnectivityResult>>
  _connectivitySubscription;

  final _loginStates = StreamController<SyncLoginState>.broadcast();
  final _roomIds = StreamController<String?>.broadcast();
  final _outgoing = StreamController<SyncVerificationState>.broadcast();
  final _incoming = StreamController<SyncVerificationState>.broadcast();
  final _requests = StreamController<SyncVerificationState>.broadcast();
  final _stats = StreamController<MatrixStats>.broadcast();

  var _isLoggedIn = false;
  String? _ownUserId;
  String? _ownDeviceId;
  String? _homeserverHost;
  String? _syncRoomId;
  SyncVerificationState? _outgoingVerification;
  SyncVerificationState? _incomingVerification;
  List<SyncDeviceInfo> _unverifiedDevices = const [];
  MatrixStats _latestStats = const MatrixStats(
    sentCount: 0,
    messageCounts: {},
  );
  bool _isBridgeInFlight = false;
  void Function()? _onBridgeCompleted;

  /// The credentials as this side knows them; null until [loadConfig] read
  /// the keychain or [setConfig] wrote it.
  MatrixConfig? _config;
  var _configKnown = false;

  /// Whether [init] ran, so a respawned worker is started again.
  var _initialized = false;
  var _disposed = false;

  // ------------------------------------------------------------ events

  void _onEvent(SyncIsolateEvent event) {
    switch (event) {
      case SyncIsolateSessionChanged(
        :final isLoggedIn,
        :final ownUserId,
        :final ownDeviceId,
        :final homeserverHost,
      ):
        _isLoggedIn = isLoggedIn;
        _ownUserId = ownUserId;
        _ownDeviceId = ownDeviceId;
        _homeserverHost = homeserverHost;
      case SyncIsolateLoginStateChanged(:final state):
        _loginStates.add(state);
      case SyncIsolateRoomIdChanged(:final roomId):
        _syncRoomId = roomId;
        _roomIds.add(roomId);
      case SyncIsolateVerificationChanged(:final stream, :final state):
        switch (stream) {
          case SyncIsolateVerificationStream.outgoing:
            _outgoingVerification = state;
            _outgoing.add(state);
          case SyncIsolateVerificationStream.incoming:
            _incomingVerification = state;
            _incoming.add(state);
          case SyncIsolateVerificationStream.request:
            _requests.add(state);
        }
      case SyncIsolateUnverifiedDevicesChanged(:final devices):
        _unverifiedDevices = devices;
      case SyncIsolateStatsChanged(:final stats):
        _latestStats = stats;
        _stats.add(stats);
      case SyncIsolateAttachmentRecorded(:final descriptor):
        _attachmentIndex.recordDescriptor(descriptor);
      case SyncIsolateBridgeChanged(:final inFlight):
        _isBridgeInFlight = inFlight;
        if (!inFlight) _onBridgeCompleted?.call();
      case SyncIsolateStackChanged():
      case SyncIsolateTablesChanged():
      case SyncIsolateLog():
        break;
    }
  }

  /// A worker that just came up knows only its boot config: hand it the
  /// credentials this side holds, start it if [init] already ran, and take
  /// its snapshot so the plain readers are current.
  void _onState(SyncIsolateState state) {
    if (state != SyncIsolateState.running || _disposed) return;
    // Nobody waits for a resume; it catches its own failures below.
    _resume();
  }

  Future<void> _resume() async {
    try {
      if (_configKnown) {
        await _host.send(SyncIsolateConfigure(_config));
      }
      if (_initialized) {
        await _host.send(const SyncIsolateInitStack());
      }
      await _refreshSnapshot();
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_subDomain.resume',
      );
    }
  }

  Future<void> _refreshSnapshot() async {
    final snapshot =
        (await _host.send(const SyncIsolateGetSnapshot()))!
            as SyncIsolateSnapshot;
    _isLoggedIn = snapshot.isLoggedIn;
    _ownUserId = snapshot.ownUserId;
    _ownDeviceId = snapshot.ownDeviceId;
    _homeserverHost = snapshot.homeserverHost;
    _syncRoomId = snapshot.syncRoomId;
    _outgoingVerification = snapshot.outgoingVerification;
    _incomingVerification = snapshot.incomingVerification;
    _latestStats = snapshot.stats;
    _isBridgeInFlight = snapshot.isBridgeInFlight;
  }

  // ---------------------------------------------------------- commands

  /// Sends [command] and returns the worker's result, rethrowing the
  /// exception types a caller acts on as themselves.
  Future<Object?> command(SyncIsolateCommand command) async {
    try {
      return await _host.send(command);
    } on SyncIsolateFailure catch (failure) {
      _rethrow(failure);
    }
  }

  /// A command whose outcome the caller does not act on: a failure is
  /// logged, and a worker that is not running is nothing to report — it is
  /// handed what it missed when it comes back ([_resume]).
  Future<void> _notify(SyncIsolateCommand command) async {
    try {
      await _host.send(command);
    } on SyncIsolateFailure catch (failure) {
      if (failure.code == SyncIsolateErrorCode.notRunning) return;
      _logger.error(
        LogDomain.sync,
        failure,
        subDomain: '$_subDomain.${command.runtimeType}',
      );
    }
  }

  /// [_notify] from code that cannot await — a stream callback, a
  /// synchronous reader. The future handles its own errors, so nothing
  /// reaches the zone, and nothing waits for it.
  void _tell(SyncIsolateCommand command) {
    _notify(command);
  }

  /// Throws [failure] as the exception the worker caught when the caller
  /// acts on its type, else as itself.
  static Never _rethrow(SyncIsolateFailure failure) {
    final detail = failure.detail;
    switch (failure.thrown) {
      case SyncIsolateThrown.messageTooLarge:
        const marker = SyncIsolateStack.inlineBodyMarker;
        final inlineBody = detail?.endsWith(marker) ?? false;
        throw SyncMessageTooLargeException(
          detail == null
              ? failure.message
              : inlineBody
              ? detail.substring(0, detail.length - marker.length).trimRight()
              : detail,
          inlineBody: inlineBody,
        );
      case SyncIsolateThrown.reauthRequired:
        throw SyncReauthRequiredException(detail ?? failure.message);
      case SyncIsolateThrown.fileSystem:
        throw FileSystemException(failure.message, detail);
      case SyncIsolateThrown.state:
        throw StateError(failure.message);
      case SyncIsolateThrown.none:
        throw failure;
    }
  }

  Future<void> _run(SyncIsolateCommand c) async => command(c);

  // ------------------------------------------------------------- SyncService

  @override
  Future<void> init() async {
    _initialized = true;
    if (!_configKnown) await loadConfig();
    // Startup does not wait for the spawn; init does, because it is the
    // tracked startup task that says sync is up.
    if (_host.state != SyncIsolateState.running) {
      await _host.states.firstWhere((s) => s == SyncIsolateState.running);
    }
    await command(SyncIsolateConfigure(_config));
    await command(const SyncIsolateInitStack());
    await _refreshSnapshot();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _eventSubscription.cancel();
    await _stateSubscription.cancel();
    await _connectivitySubscription.cancel();
    await Future.wait([
      _loginStates.close(),
      _roomIds.close(),
      _outgoing.close(),
      _incoming.close(),
      _requests.close(),
      _stats.close(),
    ]);
  }

  @override
  bool isLoggedIn() => _isLoggedIn;

  @override
  Stream<SyncLoginState> get loginStateChanges => _loginStates.stream;

  @override
  String? get ownUserId => _ownUserId;

  @override
  String? get ownDeviceId => _ownDeviceId;

  @override
  String? get homeserverHost => _homeserverHost;

  @override
  Future<bool> login({bool waitForLifecycle = true}) async =>
      (await command(SyncIsolateLogin(waitForLifecycle: waitForLifecycle)))!
          as bool;

  @override
  Future<bool> connect() async =>
      (await command(const SyncIsolateConnect()))! as bool;

  @override
  Future<void> logout() => _run(const SyncIsolateLogout());

  @override
  Future<MatrixConfig?> loadConfig() async {
    if (_configKnown) return _config;
    _config = await readStoredMatrixConfig(_secureStorage);
    _configKnown = true;
    return _config;
  }

  @override
  Future<void> setConfig(MatrixConfig config) async {
    _config = config;
    _configKnown = true;
    await _secureStorage.write(
      key: matrixConfigKey,
      value: jsonEncode(config),
    );
    await _notify(SyncIsolateConfigure(config));
  }

  @override
  Future<void> deleteConfig() async {
    _config = null;
    _configKnown = true;
    await _secureStorage.delete(key: matrixConfigKey);
    await _notify(const SyncIsolateConfigure(null));
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await command(
      SyncIsolateChangePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      ),
    );
    final config = await loadConfig();
    if (config != null) {
      await setConfig(config.copyWith(password: newPassword));
    }
  }

  @override
  String? get syncRoomId => _syncRoomId;

  @override
  Stream<String?> get syncRoomIdChanges => _roomIds.stream;

  @override
  Future<String?> getRoom() async =>
      await command(const SyncIsolateGetRoom()) as String?;

  @override
  Future<String?> joinRoom(String roomId) async =>
      await command(SyncIsolateJoinRoom(roomId)) as String?;

  @override
  Future<String> createRoom() async =>
      (await command(const SyncIsolateCreateRoom()))! as String;

  @override
  Future<String?> findSyncRoom() async =>
      await command(const SyncIsolateFindSyncRoom()) as String?;

  @override
  Future<void> saveRoom(String roomId) => _run(SyncIsolateSaveRoom(roomId));

  @override
  Future<void> clearPersistedRoom() =>
      _run(const SyncIsolateClearPersistedRoom());

  @override
  Future<void> publishRotationProof({
    required String roomId,
    required String bundleId,
    required String challenge,
  }) => _run(
    SyncIsolatePublishRotationProof(
      roomId: roomId,
      bundleId: bundleId,
      challenge: challenge,
    ),
  );

  /// The roster as the worker last reported it. Reading it asks for a fresh
  /// one in the background, so the next read — the modal polls — is current.
  @override
  List<SyncDeviceInfo> getUnverifiedDevices() {
    _tell(const SyncIsolateGetUnverifiedDevices());
    return _unverifiedDevices;
  }

  @override
  Future<List<SyncDeviceInfo>> getSyncDevices() async =>
      (await command(const SyncIsolateGetSyncDevices()))!
          as List<SyncDeviceInfo>;

  @override
  Future<void> deleteDeviceById(String deviceId, {String? reauthPassword}) =>
      _run(
        SyncIsolateDeleteDevice(
          deviceId: deviceId,
          reauthPassword: reauthPassword,
        ),
      );

  @override
  Future<void> verifyDevice({
    required String userId,
    required String deviceId,
  }) => _run(SyncIsolateVerifyDevice(userId: userId, deviceId: deviceId));

  @override
  Stream<SyncVerificationState> get outgoingVerifications => _outgoing.stream;

  @override
  SyncVerificationState? get outgoingVerification => _outgoingVerification;

  @override
  Stream<SyncVerificationState> get incomingVerifications => _incoming.stream;

  @override
  SyncVerificationState? get incomingVerification => _incomingVerification;

  @override
  Stream<SyncVerificationState> get incomingVerificationRequests =>
      _requests.stream;

  Future<void> _ceremony(SyncIsolateVerificationActionKind kind, String id) =>
      _run(SyncIsolateVerificationAction(kind: kind, id: id));

  @override
  Future<void> acceptVerification(String id) =>
      _ceremony(SyncIsolateVerificationActionKind.accept, id);

  @override
  Future<void> acceptEmojiVerification(String id) =>
      _ceremony(SyncIsolateVerificationActionKind.acceptEmoji, id);

  @override
  Future<void> cancelVerification(String id) =>
      _ceremony(SyncIsolateVerificationActionKind.cancel, id);

  @override
  Future<void> handOffOutgoingVerificationTo(String incomingId) => _ceremony(
    SyncIsolateVerificationActionKind.handOffOutgoingTo,
    incomingId,
  );

  @override
  Future<bool> sendMatrixMsg(
    SyncMessage syncMessage, {
    String? myRoomId,
  }) async {
    final sent =
        (await command(SyncIsolateSendMessage(syncMessage, roomId: myRoomId)))!
            as bool;
    // In-process the sender runs this hook once the server accepted the
    // event; a true reply is that acceptance.
    if (sent) await onSyncMessageSent?.call(syncMessage);
    return sent;
  }

  @override
  Future<void> Function(SyncMessage message)? onSyncMessageSent;

  @override
  Stream<MatrixStats> get stats => _stats.stream;

  @override
  int get sentCount => _latestStats.sentCount;

  @override
  Map<String, int> get messageCounts => _latestStats.messageCounts;

  @override
  Future<SyncMetrics?> getSyncMetrics() async =>
      await command(const SyncIsolateGetSyncMetrics()) as SyncMetrics?;

  @override
  Future<String> getSyncDiagnosticsText() async =>
      (await command(const SyncIsolateGetDiagnosticsText()))! as String;

  @override
  Future<Map<String, dynamic>> getDiagnosticInfo() async =>
      (await command(const SyncIsolateGetDiagnosticInfo()))!
          as Map<String, dynamic>;

  @override
  Future<void> forceRescan({bool includeCatchUp = true}) =>
      _run(SyncIsolateForceRescan(includeCatchUp: includeCatchUp));

  @override
  Future<void> retryNow() => _run(const SyncIsolateRetryNow());

  /// The UI isolate wrote the journal: rows waiting for a base may apply.
  Future<void> journalChanged() => _notify(const SyncIsolateJournalChanged());
}

/// The producer side of the pipeline over the proxy.
class _IsolateSyncQueueControl implements SyncQueueControl {
  _IsolateSyncQueueControl(this._service);

  final IsolateSyncService _service;

  @override
  Future<void> triggerBridge() =>
      _service._run(const SyncIsolateTriggerBridge());

  @override
  void maybeStartGapRecovery() =>
      _service._tell(const SyncIsolateMaybeStartGapRecovery());

  @override
  bool get isBridgeInFlight => _service._isBridgeInFlight;

  @override
  void Function()? get onBridgeCompleted => _service._onBridgeCompleted;

  @override
  set onBridgeCompleted(void Function()? callback) =>
      _service._onBridgeCompleted = callback;

  @override
  Future<int> retrySkipped() async =>
      (await _service.command(const SyncIsolateRetrySkipped()))! as int;
}
