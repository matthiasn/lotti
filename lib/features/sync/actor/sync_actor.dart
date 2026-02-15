import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/actor/verification_handler.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

const _maxVerificationPeerDiscoveryAttempts = 8;
const _defaultVerificationPeerDiscoveryAttempts =
    _maxVerificationPeerDiscoveryAttempts;
const _defaultVerificationPeerDiscoveryInterval = Duration(milliseconds: 500);
const _verificationPeerDiscoveryCooldown = Duration(seconds: 1);

/// States of the sync actor isolate.
enum SyncActorState {
  uninitialized,
  initializing,
  idle,
  syncing,
  stopping,
  disposed,
}

/// Typedef for the factory that creates a [MatrixSdkGateway].
///
/// Used for dependency injection in tests.
typedef GatewayFactory = MatrixSdkGateway Function({
  required Client client,
  required SentEventRegistry sentEventRegistry,
});

/// Typedef for the vodozemac initializer.
///
/// Used for dependency injection in tests.
typedef VodInitializer = Future<void> Function();

/// Typedef for the Matrix client factory.
///
/// Used for dependency injection in tests.
typedef MatrixClientFactory = Future<Client> Function({
  required Directory documentsDirectory,
  String? deviceDisplayName,
  String? dbName,
});

typedef TimelineEventStreamFactory = Stream<Event> Function(Client client);

/// Command handler that implements the sync actor's state machine.
///
/// This class is designed to be testable without an isolate — tests can
/// instantiate it directly and call [handleCommand]. In production it is
/// driven by the [syncActorEntrypoint] top-level function.
class SyncActorCommandHandler {
  SyncActorCommandHandler({
    GatewayFactory? gatewayFactory,
    MatrixClientFactory? createMatrixClientFactory,
    VodInitializer? vodInitializer,
    Stream<SyncUpdate> Function(Client)? syncUpdateStreamFactory,
    Stream<ToDeviceEvent> Function(Client)? toDeviceEventStreamFactory,
    TimelineEventStreamFactory? timelineEventStreamFactory,
    int verificationPeerDiscoveryAttempts =
        _defaultVerificationPeerDiscoveryAttempts,
    Duration verificationPeerDiscoveryInterval =
        _defaultVerificationPeerDiscoveryInterval,
    bool enableLogging = true,
  })  : _gatewayFactory = gatewayFactory ?? _defaultGatewayFactory,
        _createMatrixClientFactory =
            createMatrixClientFactory ?? createMatrixClient,
        _vodInitializer = vodInitializer ?? vod.init,
        _syncUpdateStreamFactory = syncUpdateStreamFactory,
        _toDeviceEventStreamFactory = toDeviceEventStreamFactory,
        _timelineEventStreamFactory = timelineEventStreamFactory,
        _verificationPeerDiscoveryAttempts = verificationPeerDiscoveryAttempts,
        _verificationPeerDiscoveryInterval = verificationPeerDiscoveryInterval,
        _enableLogging = enableLogging;

  late final VerificationHandler _verificationHandler = VerificationHandler(
    onStateChanged: _emitEvent,
  );

  final GatewayFactory _gatewayFactory;
  final MatrixClientFactory _createMatrixClientFactory;
  final VodInitializer _vodInitializer;
  final Stream<SyncUpdate> Function(Client)? _syncUpdateStreamFactory;
  final Stream<ToDeviceEvent> Function(Client)? _toDeviceEventStreamFactory;
  final TimelineEventStreamFactory? _timelineEventStreamFactory;
  final int _verificationPeerDiscoveryAttempts;
  final Duration _verificationPeerDiscoveryInterval;
  final bool _enableLogging;

  SyncActorState _state = SyncActorState.uninitialized;
  MatrixSdkGateway? _gateway;
  SendPort? _eventPort;
  StreamSubscription<SyncUpdate>? _syncSub;
  StreamSubscription<KeyVerification>? _incomingVerificationSub;
  StreamSubscription<Event>? _timelineEventSub;
  SentEventRegistry? _sentEventRegistry;

  // Verification state
  StreamSubscription<LoginState>? _loginStateSub;
  StreamSubscription<ToDeviceEvent>? _toDeviceSub;
  LoginState? _latestLoginState;

  DateTime? _lastVerificationKeyRefresh;
  Future<void>? _verificationKeyRefreshInFlight;

  // Diagnostic counters
  int _toDeviceEventCount = 0;
  int _syncCount = 0;

  /// Current actor state, exposed for testing.
  SyncActorState get state => _state;

  /// Processes a command map and returns a response map.
  Future<Map<String, Object?>> handleCommand(
    Map<String, Object?> command,
  ) async {
    final rawCommand = command['command'];
    if (rawCommand == null) {
      return _error('Missing command field');
    }
    if (rawCommand is! String) {
      final requestId = command['requestId'];
      final requestIdValue = requestId is String ? requestId : null;
      return _error(
        'Invalid command type: expected String',
        errorCode: 'INVALID_PARAMETER',
        requestId: requestIdValue,
      );
    }

    final cmd = rawCommand;
    final dynamic requestId = command['requestId'];
    final requestIdValue = requestId is String ? requestId : null;

    _log('command: $cmd (state=${_state.name})');

    switch (cmd) {
      case 'ping':
        return _ok(requestId: requestIdValue);
      case 'getHealth':
        return _handleGetHealth(requestId: requestIdValue);
      case 'stop':
        return _handleStop(requestId: requestIdValue);
      case 'init':
        return _handleInit(command, requestId: requestIdValue);
      case 'startSync':
        return _handleStartSync(requestId: requestIdValue);
      case 'stopSync':
        return _handleStopSync(requestId: requestIdValue);
      case 'createRoom':
        return _handleCreateRoom(command, requestId: requestIdValue);
      case 'joinRoom':
        return _handleJoinRoom(command, requestId: requestIdValue);
      case 'sendText':
        return _handleSendText(command, requestId: requestIdValue);
      case 'startVerification':
        return _handleStartVerification(
          command: command,
          requestId: requestIdValue,
        );
      case 'acceptVerification':
        return _handleAcceptVerification(requestId: requestIdValue);
      case 'acceptSas':
        return _handleAcceptSas(requestId: requestIdValue);
      case 'cancelVerification':
        return _handleCancelVerification(requestId: requestIdValue);
      case 'getVerificationState':
        return _handleGetVerificationState(requestId: requestIdValue);
      default:
        return _error(
          'Unknown command: $cmd',
          requestId: requestIdValue,
          errorCode: 'UNKNOWN_COMMAND',
        );
    }
  }

  Future<Map<String, Object?>> _handleInit(
    Map<String, Object?> command, {
    String? requestId,
  }) async {
    if (_state != SyncActorState.uninitialized) {
      return _invalidState('init', requestId: requestId);
    }

    final homeServer = command['homeServer'];
    if (homeServer is! String) {
      return _paramError('homeServer', homeServer, requestId: requestId);
    }
    final user = command['user'];
    if (user is! String) {
      return _paramError('user', user, requestId: requestId);
    }
    final password = command['password'];
    if (password is! String) {
      return _paramError('password', password, requestId: requestId);
    }
    final dbRootPath = command['dbRootPath'];
    if (dbRootPath is! String) {
      return _paramError('dbRootPath', dbRootPath, requestId: requestId);
    }

    _state = SyncActorState.initializing;
    _log('state: uninitialized -> initializing');

    try {
      final deviceDisplayName =
          command['deviceDisplayName'] as String? ?? 'SyncActor';
      final eventPort = command['eventPort'] as SendPort?;

      _eventPort = eventPort;

      _log('init: vodozemac init starting');
      await _vodInitializer();
      _log('init: vodozemac init done');

      final dbRoot = Directory(dbRootPath);
      await dbRoot.create(recursive: true);
      _log('init: db root created at $dbRootPath');

      _log('init: creating matrix client');
      final client = await _createMatrixClientFactory(
        documentsDirectory: dbRoot,
        deviceDisplayName: deviceDisplayName,
        dbName: 'sync_actor_${deviceDisplayName.replaceAll(' ', '_')}',
      );
      _log('init: matrix client created');

      _sentEventRegistry = SentEventRegistry();
      _gateway = _gatewayFactory(
        client: client,
        sentEventRegistry: _sentEventRegistry!,
      );

      final config = MatrixConfig(
        homeServer: homeServer,
        user: user,
        password: password,
      );

      _log('init: connecting to $homeServer');
      await _gateway!.connect(config);
      _log('init: connected');

      _log('init: logging in as $user');
      await _gateway!.login(config, deviceDisplayName: deviceDisplayName);
      _log('init: logged in, deviceId=${client.deviceID}');
      _latestLoginState = LoginState.loggedIn;

      _loginStateSub = _gateway!.loginStateChanges.listen((loginState) {
        _log('event: loginStateChanged -> ${loginState.name}');
        _latestLoginState = loginState;
        _emitEvent({
          'event': 'loginStateChanged',
          'loginState': loginState.name,
        });
      });

      _incomingVerificationSub =
          _gateway!.keyVerificationRequests.listen((verification) {
        _log(
          'event: incoming verification, '
          'step=${verification.lastStep}, '
          'isDone=${verification.isDone}',
        );
        _verificationHandler.trackIncoming(verification);
      });

      _timelineEventSub = _timelineEventStreamFor(_gateway!.client).listen(
        _handleTimelineEvent,
      );

      // Track all to-device events for diagnostics.
      final toDeviceStream = _toDeviceEventStreamFor(_gateway!.client);
      _toDeviceSub = toDeviceStream.listen((event) {
        _toDeviceEventCount++;
        final sender = event.sender;
        final toDeviceType = event.type;
        _emitEvent({
          'event': 'toDevice',
          'type': toDeviceType,
          'sender': sender,
        });

        // Keep this hot path lightweight; avoid DB-heavy key refresh work here.
      });

      // Enable the background sync loop now that startup is complete.
      // The actor path starts syncing by default for parity with the current
      // non-actor lifecycle behavior; startSync/stopSync remain explicit
      // control points for tests and teardown.
      await _startSyncStreamListening();
      _gateway!.client.backgroundSync = true;

      _state = SyncActorState.syncing;
      _log('state: initializing -> syncing');
      _emitEvent({'event': 'ready'});

      _latestLoginState ??= LoginState.loggedIn;

      return _ok(requestId: requestId);
    } catch (e, stackTrace) {
      _log('init FAILED: $e\n$stackTrace');

      // Clean up partially-initialized resources to avoid leaking DB
      // connections on repeated init attempts.
      await _loginStateSub?.cancel();
      _loginStateSub = null;
      await _incomingVerificationSub?.cancel();
      _incomingVerificationSub = null;
      await _toDeviceSub?.cancel();
      _toDeviceSub = null;
      await _timelineEventSub?.cancel();
      _timelineEventSub = null;
      await _verificationHandler.dispose();
      await _gateway?.dispose();
      _latestLoginState = null;
      _sentEventRegistry = null;
      _gateway = null;
      _eventPort = null;

      _state = SyncActorState.uninitialized;
      return _error(
        'Init failed: $e',
        requestId: requestId,
        stackTrace: stackTrace,
      );
    }
  }

  Map<String, Object?> _handleGetHealth({String? requestId}) {
    final client = _gateway?.client;
    final userId = client?.userID;

    // Gather device key info (reads current cached state only).
    Map<String, Object?>? deviceKeyInfo;
    if (userId != null && client != null) {
      final keysMap = client.userDeviceKeys[userId]?.deviceKeys;
      if (keysMap != null) {
        deviceKeyInfo = {
          'count': keysMap.length,
          'devices': keysMap.entries
              .map(
                (e) => '${e.key}(verified=${e.value.verified})',
              )
              .toList(),
        };
      }
    }

    return _ok(requestId: requestId, extra: {
      'state': _state.name,
      'loginState': _latestLoginState?.name,
      'encryptionEnabled': client?.encryptionEnabled ?? false,
      'deviceId': client?.deviceID,
      'userId': userId,
      'deviceKeys': deviceKeyInfo,
      'syncLoopActive': _state == SyncActorState.syncing,
      'syncCount': _syncCount,
      'toDeviceEventCount': _toDeviceEventCount,
    });
  }

  Future<Map<String, Object?>> _handleStartSync({String? requestId}) async {
    if (_state == SyncActorState.syncing) {
      return _ok(requestId: requestId);
    }

    if (_state != SyncActorState.idle) {
      return _invalidState('startSync', requestId: requestId);
    }

    await _startSyncStreamListening();

    // Enable the SDK's built-in background sync loop.
    _gateway!.client.backgroundSync = true;

    _state = SyncActorState.syncing;
    _log('state: idle -> syncing');
    return _ok(requestId: requestId);
  }

  Future<void> _startSyncStreamListening() async {
    final client = _gateway?.client;
    if (client == null) {
      return;
    }
    await _syncSub?.cancel();
    _syncSub = null;
    final syncStream = _syncUpdateStreamFor(client);
    _syncSub = syncStream.listen((_) {
      _syncCount++;
      _log('sync update #$_syncCount');
      _emitEvent({'event': 'syncUpdate'});
    });
  }

  Stream<SyncUpdate> _syncUpdateStreamFor(Client client) {
    return _syncUpdateStreamFactory?.call(client) ?? client.onSync.stream;
  }

  Stream<ToDeviceEvent> _toDeviceEventStreamFor(Client client) {
    return _toDeviceEventStreamFactory?.call(client) ??
        client.onToDeviceEvent.stream;
  }

  Future<void> _pauseSyncLoop() async {
    _gateway?.client.backgroundSync = false;
    await _syncSub?.cancel();
    _syncSub = null;
  }

  Future<void> _pauseSyncLoopForSend() async {
    final client = _gateway?.client;
    if (client == null) return;

    client.backgroundSync = false;
    await _pauseSyncLoop();
    await client.abortSync();
  }

  Future<T> _sendWithTransientSyncPause<T>(
      Future<T> Function() operation) async {
    final wasSyncing = _state == SyncActorState.syncing;
    if (!wasSyncing) {
      return operation();
    }

    await _pauseSyncLoopForSend();
    try {
      return await operation();
    } finally {
      if (_state == SyncActorState.syncing) {
        _gateway?.client.backgroundSync = true;
        await _startSyncStreamListening();
      }
    }
  }

  bool _isRetryableSqliteError(Object error) {
    final message = error.toString();
    return message.contains('SqliteException(21)') ||
        message.contains('SqliteFfiException') ||
        message.contains('bad parameter or other API misuse');
  }

  Future<T> _runWithRetries<T>(
    Future<T> Function() operation, {
    int maxRetries = 5,
    Duration baseDelay = const Duration(milliseconds: 250),
    bool Function(Object)? isRetryable,
  }) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await operation();
      } on Object catch (e, stackTrace) {
        if (isRetryable == null || !isRetryable(e)) {
          Error.throwWithStackTrace(e, stackTrace);
        }
        if (attempt >= maxRetries - 1) {
          Error.throwWithStackTrace(e, stackTrace);
        }

        await Future<void>.delayed(
          Duration(
            milliseconds: baseDelay.inMilliseconds * (1 << attempt),
          ),
        );
      }
    }
  }

  Future<Map<String, Object?>> _handleStopSync({String? requestId}) async {
    if (_state == SyncActorState.idle) {
      return _ok(requestId: requestId);
    }

    if (_state != SyncActorState.syncing) {
      return _invalidState('stopSync', requestId: requestId);
    }

    await _pauseSyncLoop();

    _state = SyncActorState.idle;
    _log('state: syncing -> idle');
    return _ok(requestId: requestId);
  }

  Future<Map<String, Object?>> _handleCreateRoom(
    Map<String, Object?> command, {
    String? requestId,
  }) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('createRoom', requestId: requestId);
    }

    final name = command['name'];
    if (name is! String) {
      return _paramError('name', name, requestId: requestId);
    }

    try {
      final inviteUserIds =
          (command['inviteUserIds'] as List<dynamic>?)?.cast<String>();

      final roomId = await _gateway!.createRoom(
        name: name,
        inviteUserIds: inviteUserIds,
      );
      _log('createRoom ok: $roomId');
      return _ok(requestId: requestId, extra: {'roomId': roomId});
    } catch (e, stackTrace) {
      _log('createRoom FAILED: $e\n$stackTrace');
      return _error(
        'createRoom failed: $e',
        requestId: requestId,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, Object?>> _handleJoinRoom(
    Map<String, Object?> command, {
    String? requestId,
  }) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('joinRoom', requestId: requestId);
    }

    final roomId = command['roomId'];
    if (roomId is! String) {
      return _paramError('roomId', roomId, requestId: requestId);
    }

    try {
      _log('joinRoom: $roomId');
      await _gateway!.joinRoom(roomId);
      _log('joinRoom ok: $roomId');
      return _ok(requestId: requestId);
    } catch (e, stackTrace) {
      _log('joinRoom FAILED: $e\n$stackTrace');
      return _error(
        'joinRoom failed: $e',
        requestId: requestId,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, Object?>> _handleSendText(
    Map<String, Object?> command, {
    String? requestId,
  }) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('sendText', requestId: requestId);
    }

    final roomId = command['roomId'];
    if (roomId is! String) {
      return _paramError('roomId', roomId, requestId: requestId);
    }
    final message = command['message'];
    if (message is! String) {
      return _paramError('message', message, requestId: requestId);
    }

    try {
      final messageType = command['messageType'] as String?;
      _log('sendText: room=$roomId msg=${message.length} chars');

      final eventId = await _runWithRetries(
        () => _sendWithTransientSyncPause(
          () => _gateway!.sendText(
            roomId: roomId,
            message: message,
            messageType: messageType,
            displayPendingEvent: false,
          ),
        ),
        isRetryable: _isRetryableSqliteError,
      );

      _log('sendText ok: eventId=$eventId');
      return _ok(requestId: requestId, extra: {'eventId': eventId});
    } catch (e, stackTrace) {
      _log('sendText FAILED: $e\n$stackTrace');
      return _error(
        'sendText failed: $e',
        requestId: requestId,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, Object?>> _handleStartVerification({
    required Map<String, Object?> command,
    String? requestId,
  }) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('startVerification', requestId: requestId);
    }

    if (_verificationHandler.hasIncoming || _verificationHandler.hasOutgoing) {
      return _ok(
        requestId: requestId,
        extra: {'started': false},
      );
    }

    try {
      final roomId = command['roomId'];
      if (roomId != null && roomId is! String) {
        return _paramError('roomId', roomId, requestId: requestId);
      }
      if (roomId is String && roomId.isEmpty) {
        return _paramError('roomId', roomId, requestId: requestId);
      }

      final peerDevice = await _findUnverifiedPeerDevice();
      if (peerDevice == null) {
        return _ok(requestId: requestId, extra: {'started': false});
      }

      final verification = await _startVerification(peerDevice, roomId: roomId);
      _verificationHandler.trackOutgoing(verification);

      return _ok(requestId: requestId, extra: {'started': true});
    } catch (e, stackTrace) {
      return _error(
        'startVerification failed: $e',
        requestId: requestId,
        stackTrace: stackTrace,
      );
    }
  }

  Future<KeyVerification> _startVerification(
    DeviceKeys peerDevice, {
    Object? roomId,
  }) async {
    final clientUserId = _gateway!.client.userID;
    final shouldUseDirectVerification =
        roomId == null || peerDevice.userId == clientUserId;

    if (shouldUseDirectVerification) {
      final directVerification =
          await _gateway!.startKeyVerification(peerDevice);
      return _ensureVerificationRequestProgress(directVerification);
    }

    final peerUserId = peerDevice.userId;
    final roomIdValue = roomId as String;

    final client = _gateway!.client;
    final encryption = client.encryption;
    if (encryption == null) {
      throw Exception('startKeyVerification requires enabled encryption');
    }

    final room = client.getRoomById(roomIdValue);
    if (room == null) {
      throw Exception('Room verification requires existing room $roomIdValue');
    }

    final verification = KeyVerification(
      encryption: encryption,
      room: room,
      userId: peerUserId,
    );

    await verification.start();
    return _ensureVerificationRequestProgress(verification);
  }

  Future<KeyVerification> _ensureVerificationRequestProgress(
    KeyVerification verification,
  ) async {
    final wasStarted = verification.startedVerification;
    await verification.openSSSS(skip: true);
    if (!wasStarted && !verification.startedVerification) {
      throw StateError('Verification request did not start');
    }
    return verification;
  }

  Future<void> _refreshPeerDeviceKeys(String userId) async {
    final client = _gateway?.client;
    if (client == null) return;

    final inFlight = _verificationKeyRefreshInFlight;
    if (inFlight != null) {
      return;
    }

    final now = DateTime.now();
    final lastRefresh = _lastVerificationKeyRefresh;
    if (lastRefresh != null &&
        now.difference(lastRefresh) < _verificationPeerDiscoveryCooldown) {
      return;
    }

    Future<void> refreshTask() async {
      _lastVerificationKeyRefresh = now;
      final beforeCount = client.userDeviceKeys[userId]?.deviceKeys.length ?? 0;

      await _updateUserDeviceKeysBestEffort(
        client,
        userId,
        additionalUsers: <String>{userId},
      );

      try {
        final loading = client.userDeviceKeysLoading;
        if (loading != null) {
          await loading.timeout(const Duration(seconds: 2));
        }
      } catch (_) {
        // Best-effort only.
      }

      final afterCount = client.userDeviceKeys[userId]?.deviceKeys.length ?? 0;
      if (afterCount != beforeCount) {
        _log(
          'verification device keys updated for $userId: '
          '$beforeCount -> $afterCount',
        );
      }
    }

    final inFlightTask = refreshTask();
    _verificationKeyRefreshInFlight = inFlightTask;
    try {
      await inFlightTask;
    } finally {
      if (_verificationKeyRefreshInFlight == inFlightTask) {
        _verificationKeyRefreshInFlight = null;
      }
    }
  }

  Future<void> _updateUserDeviceKeysBestEffort(
    Client client,
    String userId, {
    required Set<String> additionalUsers,
  }) async {
    try {
      await client
          .updateUserDeviceKeys(additionalUsers: additionalUsers)
          .timeout(const Duration(seconds: 3));
    } catch (error, stackTrace) {
      _log(
        'verification key refresh failed '
        '(scope=additional user=$userId): $error\n$stackTrace',
      );
      _emitEvent({
        'event': 'verificationKeyRefreshError',
        'scope': 'additional',
        'userId': userId,
        'error': error.toString(),
      });
    }
  }

  Future<Map<String, Object?>> _handleAcceptVerification({
    String? requestId,
  }) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('acceptVerification', requestId: requestId);
    }

    try {
      await _verificationHandler.acceptVerification();
      return _ok(requestId: requestId);
    } catch (e, stackTrace) {
      if (e is StateError) {
        return _error(
          'No incoming verification to accept',
          requestId: requestId,
        );
      }
      return _error(
        'acceptVerification failed: $e',
        requestId: requestId,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, Object?>> _handleAcceptSas({String? requestId}) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('acceptSas', requestId: requestId);
    }

    try {
      await _verificationHandler.acceptSas();
      return _ok(requestId: requestId);
    } catch (e, stackTrace) {
      if (e is StateError) {
        return _error(
          'No active verification for acceptSas',
          requestId: requestId,
        );
      }
      return _error(
        'acceptSas failed: $e',
        requestId: requestId,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, Object?>> _handleCancelVerification({
    String? requestId,
  }) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('cancelVerification', requestId: requestId);
    }

    try {
      await _verificationHandler.cancel();
      return _ok(requestId: requestId);
    } catch (e, stackTrace) {
      return _error(
        'cancelVerification failed: $e',
        requestId: requestId,
        stackTrace: stackTrace,
      );
    }
  }

  Map<String, Object?> _handleGetVerificationState({
    String? requestId,
  }) {
    return _ok(requestId: requestId, extra: _verificationHandler.snapshot());
  }

  Future<Map<String, Object?>> _handleStop({String? requestId}) async {
    if (_state == SyncActorState.disposed) {
      return _invalidState('stop', requestId: requestId);
    }

    _log('state: ${_state.name} -> stopping');
    _state = SyncActorState.stopping;

    _gateway?.client.backgroundSync = false;

    try {
      await _syncSub?.cancel();

      await _incomingVerificationSub?.cancel();
      await _loginStateSub?.cancel();
      await _toDeviceSub?.cancel();
      await _timelineEventSub?.cancel();
      await _verificationHandler.dispose();
      await _gateway?.dispose();
    } catch (e, stackTrace) {
      _log('stop: cleanup error (continuing): $e\n$stackTrace');
    } finally {
      _syncSub = null;
      _incomingVerificationSub = null;
      _loginStateSub = null;
      _toDeviceSub = null;
      _timelineEventSub = null;
      _sentEventRegistry = null;
      _gateway = null;
      _eventPort = null;
    }

    _state = SyncActorState.disposed;
    _log('state: stopping -> disposed');
    return _ok(requestId: requestId);
  }

  Future<DeviceKeys?> _findUnverifiedPeerDevice() async {
    final gateway = _gateway;
    final client = gateway?.client;
    if (gateway == null || client == null) return null;

    final userId = client.userID;
    final ownDeviceId = client.deviceID;
    if (userId == null || ownDeviceId == null) return null;

    unawaited(_refreshPeerDeviceKeys(userId));

    final discoveryAttempts =
        _verificationPeerDiscoveryAttempts > _maxVerificationPeerDiscoveryAttempts
            ? _maxVerificationPeerDiscoveryAttempts
            : _verificationPeerDiscoveryAttempts;

    for (var attempt = 0; attempt < discoveryAttempts; attempt++) {
      final remoteUnverifiedDevices = gateway
          .unverifiedDevices()
          .where((device) => device.deviceId != ownDeviceId)
          .toList();

      if (remoteUnverifiedDevices.isNotEmpty) {
        return remoteUnverifiedDevices.first;
      }

      if (attempt == discoveryAttempts - 1) return null;
      await Future<void>.delayed(_verificationPeerDiscoveryInterval);
    }

    return null;
  }

  Stream<Event> _timelineEventStreamFor(Client client) {
    return _timelineEventStreamFactory?.call(client) ??
        client.onTimelineEvent.stream;
  }

  void _handleTimelineEvent(Event event) {
    if (event.type != 'm.room.message') {
      return;
    }

    final eventId = event.eventId;
    if (eventId.isEmpty || event.room.id.isEmpty || event.senderId.isEmpty) {
      return;
    }

    if (_sentEventRegistry?.consume(eventId) ?? false) {
      return;
    }

    _emitEvent({
      'event': 'incomingMessage',
      'roomId': event.room.id,
      'eventId': eventId,
      'sender': event.senderId,
      'text': event.text,
      'messageType': event.messageType,
    });
  }

  void _log(String message) {
    if (!_enableLogging) return;
    debugPrint('[SyncActor] $message');
    _emitEvent({'event': 'log', 'message': message});
  }

  void _emitEvent(Map<String, Object?> event) {
    _eventPort?.send(event);
  }

  Map<String, Object?> _ok({
    String? requestId,
    Map<String, Object?>? extra,
  }) {
    return <String, Object?>{
      'ok': true,
      if (requestId != null) 'requestId': requestId,
      ...?extra,
    };
  }

  Map<String, Object?> _error(
    String message, {
    String? requestId,
    String? errorCode,
    StackTrace? stackTrace,
  }) {
    return <String, Object?>{
      'ok': false,
      'error': message,
      if (errorCode != null) 'errorCode': errorCode,
      if (requestId != null) 'requestId': requestId,
      if (stackTrace != null) 'stackTrace': '$stackTrace',
    };
  }

  Map<String, Object?> _invalidState(
    String command, {
    String? requestId,
  }) {
    return _error(
      'Command "$command" not valid in state ${_state.name}',
      requestId: requestId,
      errorCode: 'INVALID_STATE',
    );
  }

  /// Returns a structured error for a missing or wrongly-typed parameter.
  Map<String, Object?> _paramError(
    String key,
    Object? value, {
    String? requestId,
  }) {
    if (value == null) {
      return _error(
        'Missing required parameter: $key',
        requestId: requestId,
        errorCode: 'MISSING_PARAMETER',
      );
    }
    return _error(
      'Parameter "$key" must be a String, got ${value.runtimeType}',
      requestId: requestId,
      errorCode: 'INVALID_PARAMETER',
    );
  }

  static MatrixSdkGateway _defaultGatewayFactory({
    required Client client,
    required SentEventRegistry sentEventRegistry,
  }) {
    return MatrixSdkGateway(
      client: client,
      sentEventRegistry: sentEventRegistry,
    );
  }
}

/// Top-level entrypoint for the sync actor isolate.
///
/// Receives a [SendPort] on which it sends back the command port's [SendPort].
/// Then listens for command maps and dispatches them to a
/// [SyncActorCommandHandler].
void syncActorEntrypoint(
  SendPort readyPort, {
  VodInitializer vodInitializer = vod.init,
  bool enableLogging = false,
}) {
  final commandPort = ReceivePort();
  readyPort.send(commandPort.sendPort);

  final handler = SyncActorCommandHandler(
    vodInitializer: vodInitializer,
    enableLogging: enableLogging,
  );

  commandPort.listen((dynamic raw) async {
    if (raw is! Map) return;

    SendPort? replyTo;
    try {
      replyTo = raw['replyTo'] is SendPort ? raw['replyTo'] as SendPort : null;

      if (replyTo == null) {
        return;
      }

      final command = <String, Object?>{};
      for (final entry in raw.entries) {
        if (entry.key is String) {
          command[entry.key as String] = entry.value as Object?;
        }
      }

      if (!command.containsKey('command')) {
        replyTo.send(
          <String, Object?>{
            'ok': false,
            'error': 'Missing command field',
            'errorCode': 'MISSING_PARAMETER',
          },
        );
        return;
      }
      final response = await handler.handleCommand(command);
      replyTo.send(response);
    } catch (e, stackTrace) {
      debugPrint('[SyncActor] entrypoint error: $e\n$stackTrace');
      replyTo?.send(<String, Object?>{
        'ok': false,
        'error': 'Internal actor error: $e',
        'errorCode': 'INTERNAL_ERROR',
        'stackTrace': '$stackTrace',
      });
    }

    if (handler.state == SyncActorState.disposed) {
      commandPort.close();
    }
  });
}
