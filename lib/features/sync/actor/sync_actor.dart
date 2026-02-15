import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

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

/// Command handler that implements the sync actor's state machine.
///
/// This class is designed to be testable without an isolate — tests can
/// instantiate it directly and call [handleCommand]. In production it is
/// driven by the [syncActorEntrypoint] top-level function.
class SyncActorCommandHandler {
  SyncActorCommandHandler({
    GatewayFactory? gatewayFactory,
    VodInitializer? vodInitializer,
    bool enableLogging = true,
  })  : _gatewayFactory = gatewayFactory ?? _defaultGatewayFactory,
        _vodInitializer = vodInitializer ?? vod.init,
        _enableLogging = enableLogging;

  final GatewayFactory _gatewayFactory;
  final VodInitializer _vodInitializer;
  final bool _enableLogging;

  SyncActorState _state = SyncActorState.uninitialized;
  MatrixSdkGateway? _gateway;
  SendPort? _eventPort;
  StreamSubscription<SyncUpdate>? _syncSub;

  // Verification state
  KeyVerification? _outgoingVerification;
  KeyVerification? _incomingVerification;
  StreamSubscription<KeyVerification>? _verificationSub;
  StreamSubscription<LoginState>? _loginStateSub;
  StreamSubscription<ToDeviceEvent>? _toDeviceSub;

  // Diagnostic counters
  int _toDeviceEventCount = 0;
  int _syncCount = 0;

  /// Current actor state, exposed for testing.
  SyncActorState get state => _state;

  /// Processes a command map and returns a response map.
  Future<Map<String, Object?>> handleCommand(
    Map<String, Object?> command,
  ) async {
    final cmd = command['command'] as String?;
    final requestId = command['requestId'] as String?;

    if (cmd == null) {
      return _error('Missing command field', requestId: requestId);
    }

    _log('command: $cmd (state=${_state.name})');

    switch (cmd) {
      case 'ping':
        return _ok(requestId: requestId);
      case 'getHealth':
        return _handleGetHealth(requestId: requestId);
      case 'stop':
        return _handleStop(requestId: requestId);
      case 'init':
        return _handleInit(command, requestId: requestId);
      case 'startSync':
        return _handleStartSync(requestId: requestId);
      case 'stopSync':
        return _handleStopSync(requestId: requestId);
      case 'createRoom':
        return _handleCreateRoom(command, requestId: requestId);
      case 'joinRoom':
        return _handleJoinRoom(command, requestId: requestId);
      case 'sendText':
        return _handleSendText(command, requestId: requestId);
      case 'startVerification':
        return _handleStartVerification(requestId: requestId);
      case 'acceptVerification':
        return _handleAcceptVerification(requestId: requestId);
      case 'acceptSas':
        return _handleAcceptSas(requestId: requestId);
      case 'cancelVerification':
        return _handleCancelVerification(requestId: requestId);
      case 'getVerificationState':
        return _handleGetVerificationState(requestId: requestId);
      default:
        return _error(
          'Unknown command: $cmd',
          requestId: requestId,
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
      final client = await createMatrixClient(
        documentsDirectory: dbRoot,
        deviceDisplayName: deviceDisplayName,
        dbName: 'sync_actor_${deviceDisplayName.replaceAll(' ', '_')}',
      );
      _log('init: matrix client created');

      _gateway = _gatewayFactory(
        client: client,
        sentEventRegistry: SentEventRegistry(),
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

      _loginStateSub = _gateway!.loginStateChanges.listen((loginState) {
        _log('event: loginStateChanged -> ${loginState.name}');
        _emitEvent({
          'event': 'loginStateChanged',
          'loginState': loginState.name,
        });
      });

      _verificationSub =
          _gateway!.keyVerificationRequests.listen((verification) {
        _incomingVerification = verification;
        _log(
          'event: incoming verification, '
          'step=${verification.lastStep}, '
          'isDone=${verification.isDone}',
        );
        _emitEvent({
          'event': 'verificationState',
          'step': verification.lastStep,
          'isDone': verification.isDone,
          'isCanceled': verification.canceled,
          'direction': 'incoming',
        });
      });

      // Track all to-device events for diagnostics.
      _toDeviceSub = client.onToDeviceEvent.stream.listen((event) {
        _toDeviceEventCount++;
        _log('event: toDevice type=${event.type} sender=${event.sender}');
        _emitEvent({
          'event': 'toDevice',
          'type': event.type,
          'sender': event.sender,
        });
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

      return _ok(requestId: requestId);
    } catch (e, stackTrace) {
      _log('init FAILED: $e\n$stackTrace');

      // Clean up partially-initialized resources to avoid leaking DB
      // connections on repeated init attempts.
      await _loginStateSub?.cancel();
      _loginStateSub = null;
      await _verificationSub?.cancel();
      _verificationSub = null;
      await _toDeviceSub?.cancel();
      _toDeviceSub = null;
      await _gateway?.dispose();
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
      'loginState': client?.onLoginStateChanged.value?.name,
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
    _syncSub = client.onSync.stream.listen((_) {
      _syncCount++;
      _log('sync update #$_syncCount');
      _emitEvent({'event': 'syncUpdate'});
    });
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
    Object? lastError;
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation();
      } on Object catch (e, stackTrace) {
        lastError = e;
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

    final error = lastError;
    if (error is Exception) {
      throw error;
    }
    if (error is Error) {
      throw error;
    }
    throw Exception('$error');
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
    String? requestId,
  }) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('startVerification', requestId: requestId);
    }

    try {
      final peerDevice = await _findUnverifiedPeerDevice();
      if (peerDevice == null) {
        return _ok(requestId: requestId, extra: {'started': false});
      }

      _outgoingVerification = await _gateway!.startKeyVerification(peerDevice);

      return _ok(requestId: requestId, extra: {'started': true});
    } catch (e, stackTrace) {
      return _error(
        'startVerification failed: $e',
        requestId: requestId,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, Object?>> _handleAcceptVerification({
    String? requestId,
  }) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('acceptVerification', requestId: requestId);
    }

    final verification = _incomingVerification;
    if (verification == null) {
      return _error(
        'No incoming verification to accept',
        requestId: requestId,
      );
    }

    try {
      await verification.acceptVerification();
      return _ok(requestId: requestId);
    } catch (e, stackTrace) {
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

    // Accept SAS on whichever verification is active.
    final verification = _outgoingVerification ?? _incomingVerification;
    if (verification == null) {
      return _error('No active verification for acceptSas',
          requestId: requestId);
    }

    try {
      await verification.acceptSas();
      return _ok(requestId: requestId);
    } catch (e, stackTrace) {
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
      await _outgoingVerification?.cancel();
      await _incomingVerification?.cancel();
      _outgoingVerification = null;
      _incomingVerification = null;
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
    String emojisToString(Iterable<KeyVerificationEmoji>? emojis) {
      if (emojis == null) return '';
      try {
        return emojis.map((e) => e.emoji).join(' ');
      } catch (_) {
        return '';
      }
    }

    return _ok(requestId: requestId, extra: {
      'hasOutgoing': _outgoingVerification != null,
      'hasIncoming': _incomingVerification != null,
      'outgoingStep': _outgoingVerification?.lastStep,
      'incomingStep': _incomingVerification?.lastStep,
      'outgoingEmojis': emojisToString(_outgoingVerification?.sasEmojis),
      'incomingEmojis': emojisToString(_incomingVerification?.sasEmojis),
      'outgoingDone': _outgoingVerification?.isDone ?? false,
      'incomingDone': _incomingVerification?.isDone ?? false,
      'outgoingCanceled': _outgoingVerification?.canceled ?? false,
      'incomingCanceled': _incomingVerification?.canceled ?? false,
    });
  }

  Future<Map<String, Object?>> _handleStop({String? requestId}) async {
    if (_state == SyncActorState.disposed) {
      return _invalidState('stop', requestId: requestId);
    }

    _log('state: ${_state.name} -> stopping');
    _state = SyncActorState.stopping;

    _gateway?.client.backgroundSync = false;
    await _syncSub?.cancel();
    _syncSub = null;

    try {
      await _verificationSub?.cancel();
      await _loginStateSub?.cancel();
      await _toDeviceSub?.cancel();
      await _gateway?.dispose();
    } catch (e, stackTrace) {
      _log('stop: cleanup error (continuing): $e\n$stackTrace');
    }

    _verificationSub = null;
    _loginStateSub = null;
    _toDeviceSub = null;
    _gateway = null;
    _eventPort = null;
    _outgoingVerification = null;
    _incomingVerification = null;

    _state = SyncActorState.disposed;
    _log('state: stopping -> disposed');
    return _ok(requestId: requestId);
  }

  Future<DeviceKeys?> _findUnverifiedPeerDevice() async {
    final client = _gateway?.client;
    if (client == null) return null;

    final userId = client.userID;
    if (userId == null) return null;

    await client.userOwnsEncryptionKeys(userId);
    await client.userDeviceKeysLoading;

    final keysMap = client.userDeviceKeys[userId]?.deviceKeys;
    if (keysMap == null || keysMap.isEmpty) return null;

    for (final device in keysMap.values) {
      if (device.deviceId == client.deviceID) continue;
      if (!device.verified) return device;
    }
    return null;
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
}) {
  final commandPort = ReceivePort();
  readyPort.send(commandPort.sendPort);

  final handler = SyncActorCommandHandler(vodInitializer: vodInitializer);

  commandPort.listen((dynamic raw) async {
    if (raw is! Map) return;

    SendPort? replyTo;
    try {
      final command = raw.cast<String, Object?>();
      replyTo = command['replyTo'] as SendPort?;

      final response = await handler.handleCommand(command);
      replyTo?.send(response);
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
