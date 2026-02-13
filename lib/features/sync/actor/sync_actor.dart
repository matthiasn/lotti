import 'dart:async';
import 'dart:io';
import 'dart:isolate';

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
  })  : _gatewayFactory = gatewayFactory ?? _defaultGatewayFactory,
        _vodInitializer = vodInitializer ?? vod.init;

  final GatewayFactory _gatewayFactory;
  final VodInitializer _vodInitializer;

  SyncActorState _state = SyncActorState.uninitialized;
  MatrixSdkGateway? _gateway;
  SendPort? _eventPort;
  bool _syncLoopActive = false;

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

    _state = SyncActorState.initializing;

    try {
      final homeServer = command['homeServer']! as String;
      final user = command['user']! as String;
      final password = command['password']! as String;
      final dbRootPath = command['dbRootPath']! as String;
      final deviceDisplayName =
          command['deviceDisplayName'] as String? ?? 'SyncActor';
      final eventPort = command['eventPort'] as SendPort?;

      _eventPort = eventPort;

      await _vodInitializer();

      final dbRoot = Directory(dbRootPath);
      await dbRoot.create(recursive: true);

      final client = await createMatrixClient(
        documentsDirectory: dbRoot,
        deviceDisplayName: deviceDisplayName,
        dbName: 'sync_actor_${deviceDisplayName.replaceAll(' ', '_')}',
      );

      _gateway = _gatewayFactory(
        client: client,
        sentEventRegistry: SentEventRegistry(),
      );

      final config = MatrixConfig(
        homeServer: homeServer,
        user: user,
        password: password,
      );

      await _gateway!.connect(config);
      await _gateway!.login(config, deviceDisplayName: deviceDisplayName);

      _loginStateSub = _gateway!.loginStateChanges.listen((loginState) {
        _emitEvent({
          'event': 'loginStateChanged',
          'loginState': loginState.name,
        });
      });

      _verificationSub =
          _gateway!.keyVerificationRequests.listen((verification) {
        _incomingVerification = verification;
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
        _emitEvent({
          'event': 'toDevice',
          'type': event.type,
          'sender': event.sender,
        });
      });

      _state = SyncActorState.idle;
      _emitEvent({'event': 'ready'});

      return _ok(requestId: requestId);
    } catch (e) {
      _state = SyncActorState.uninitialized;
      return _error('Init failed: $e', requestId: requestId);
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
      'syncLoopActive': _syncLoopActive,
      'syncCount': _syncCount,
      'toDeviceEventCount': _toDeviceEventCount,
    });
  }

  Future<Map<String, Object?>> _handleStartSync({String? requestId}) async {
    if (_state != SyncActorState.idle) {
      return _invalidState('startSync', requestId: requestId);
    }
    _state = SyncActorState.syncing;
    unawaited(_runSyncLoop());
    return _ok(requestId: requestId);
  }

  Future<Map<String, Object?>> _handleStopSync({String? requestId}) async {
    if (_state != SyncActorState.syncing) {
      return _invalidState('stopSync', requestId: requestId);
    }
    _syncLoopActive = false;
    _state = SyncActorState.idle;
    return _ok(requestId: requestId);
  }

  Future<Map<String, Object?>> _handleCreateRoom(
    Map<String, Object?> command, {
    String? requestId,
  }) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('createRoom', requestId: requestId);
    }

    try {
      final name = command['name']! as String;
      final inviteUserIds =
          (command['inviteUserIds'] as List<dynamic>?)?.cast<String>();

      final roomId = await _gateway!.createRoom(
        name: name,
        inviteUserIds: inviteUserIds,
      );
      return _ok(requestId: requestId, extra: {'roomId': roomId});
    } catch (e) {
      return _error('createRoom failed: $e', requestId: requestId);
    }
  }

  Future<Map<String, Object?>> _handleJoinRoom(
    Map<String, Object?> command, {
    String? requestId,
  }) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('joinRoom', requestId: requestId);
    }

    try {
      final roomId = command['roomId']! as String;
      await _gateway!.joinRoom(roomId);
      return _ok(requestId: requestId);
    } catch (e) {
      return _error('joinRoom failed: $e', requestId: requestId);
    }
  }

  Future<Map<String, Object?>> _handleSendText(
    Map<String, Object?> command, {
    String? requestId,
  }) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('sendText', requestId: requestId);
    }

    try {
      final roomId = command['roomId']! as String;
      final message = command['message']! as String;
      final messageType = command['messageType'] as String?;

      final eventId = await _gateway!.sendText(
        roomId: roomId,
        message: message,
        messageType: messageType,
      );
      return _ok(requestId: requestId, extra: {'eventId': eventId});
    } catch (e) {
      return _error('sendText failed: $e', requestId: requestId);
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
    } catch (e) {
      return _error('startVerification failed: $e', requestId: requestId);
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
    } catch (e) {
      return _error('acceptVerification failed: $e', requestId: requestId);
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
    } catch (e) {
      return _error('acceptSas failed: $e', requestId: requestId);
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
    } catch (e) {
      return _error('cancelVerification failed: $e', requestId: requestId);
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

    _state = SyncActorState.stopping;
    _syncLoopActive = false;

    await _verificationSub?.cancel();
    await _loginStateSub?.cancel();
    await _toDeviceSub?.cancel();
    await _gateway?.dispose();

    _gateway = null;
    _eventPort = null;
    _outgoingVerification = null;
    _incomingVerification = null;

    _state = SyncActorState.disposed;
    return _ok(requestId: requestId);
  }

  Future<void> _runSyncLoop() async {
    _syncLoopActive = true;
    final client = _gateway!.client;
    while (_syncLoopActive && _state == SyncActorState.syncing) {
      try {
        await client.sync();
        _syncCount++;
        _emitEvent({'event': 'syncUpdate'});
      } catch (e) {
        _emitEvent({
          'event': 'error',
          'message': '$e',
          'code': 'SYNC_ERROR',
          'fatal': false,
        });
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
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
  }) {
    return <String, Object?>{
      'ok': false,
      'error': message,
      if (errorCode != null) 'errorCode': errorCode,
      if (requestId != null) 'requestId': requestId,
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
void syncActorEntrypoint(SendPort readyPort) {
  final commandPort = ReceivePort();
  readyPort.send(commandPort.sendPort);

  final handler = SyncActorCommandHandler();

  commandPort.listen((dynamic raw) async {
    if (raw is! Map) return;

    final command = raw.cast<String, Object?>();
    final replyTo = command['replyTo'] as SendPort?;

    final response = await handler.handleCommand(command);

    replyTo?.send(response);

    if (handler.state == SyncActorState.disposed) {
      commandPort.close();
    }
  });
}
