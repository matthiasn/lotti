import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/actor/outbound_queue.dart';
import 'package:lotti/features/sync/actor/verification_handler.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

part 'sync_actor_outbox.dart';
part 'sync_actor_room_commands.dart';
part 'sync_actor_verification.dart';

const _maxVerificationPeerDiscoveryAttempts = 8;
const int _defaultVerificationPeerDiscoveryAttempts =
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
typedef GatewayFactory =
    MatrixSdkGateway Function({
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
typedef MatrixClientFactory =
    Future<Client> Function({
      required Directory documentsDirectory,
      String? deviceDisplayName,
      String? dbName,
    });

typedef TimelineEventStreamFactory = Stream<Event> Function(Client client);
typedef SyncDatabaseFactory = SyncDatabase Function(String dbRootPath);
typedef OutboundQueueFactory =
    OutboundQueue Function({
      required SyncDatabase syncDatabase,
      required MatrixSdkGateway gateway,
      required OutboundQueueEventSink emitEvent,
      Duration leaseDuration,
      Duration retryDelay,
      Duration errorDelay,
      int maxRetries,
      Duration sendTimeout,
      bool connected,
      String? syncRoomId,
    });

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
    this._syncUpdateStreamFactory,
    this._toDeviceEventStreamFactory,
    this._timelineEventStreamFactory,
    this._verificationPeerDiscoveryAttempts =
        _defaultVerificationPeerDiscoveryAttempts,
    this._verificationPeerDiscoveryInterval =
        _defaultVerificationPeerDiscoveryInterval,
    this._enableLogging = true,
    SyncDatabaseFactory? syncDatabaseFactory,
    OutboundQueueFactory? outboundQueueFactory,
    this._retryBaseDelay = const Duration(milliseconds: 250),
  }) : _gatewayFactory = gatewayFactory ?? _defaultGatewayFactory,
       _createMatrixClientFactory =
           createMatrixClientFactory ?? createMatrixClient,
       _vodInitializer = vodInitializer ?? vod.init,
       _syncDatabaseFactory =
           syncDatabaseFactory ??
           ((String dbRootPath) => SyncDatabase(
             documentsDirectoryProvider: () async => Directory(dbRootPath),
             tempDirectoryProvider: () async => Directory(dbRootPath),
             background: false,
           )),
       _outboundQueueFactory = outboundQueueFactory ?? OutboundQueue.new;

  late final VerificationHandler _verificationHandler = VerificationHandler(
    onStateChanged: _emitEvent,
  );

  final GatewayFactory _gatewayFactory;
  final MatrixClientFactory _createMatrixClientFactory;
  final VodInitializer _vodInitializer;
  final Stream<SyncUpdate> Function(Client)? _syncUpdateStreamFactory;
  final Stream<ToDeviceEvent> Function(Client)? _toDeviceEventStreamFactory;
  final TimelineEventStreamFactory? _timelineEventStreamFactory;
  final SyncDatabaseFactory _syncDatabaseFactory;
  final OutboundQueueFactory _outboundQueueFactory;
  final int _verificationPeerDiscoveryAttempts;
  final Duration _verificationPeerDiscoveryInterval;
  final bool _enableLogging;
  final Duration _retryBaseDelay;

  SyncActorState _state = SyncActorState.uninitialized;
  MatrixSdkGateway? _gateway;
  SendPort? _eventPort;
  StreamSubscription<SyncUpdate>? _syncSub;
  StreamSubscription<KeyVerification>? _incomingVerificationSub;
  StreamSubscription<Event>? _timelineEventSub;
  SyncDatabase? _syncDatabase;
  OutboundQueue? _outboundQueue;
  SentEventRegistry? _sentEventRegistry;
  Timer? _outboxPumpTimer;
  bool _outboxPumpActive = false;

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
      case 'kickOutbox':
        return _handleKickOutbox(requestId: requestIdValue);
      case 'connectivityChanged':
        return _handleConnectivityChanged(command, requestId: requestIdValue);
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

      _incomingVerificationSub = _gateway!.keyVerificationRequests.listen((
        verification,
      ) {
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

      await _initializeOutboundQueue(dbRootPath);

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
      await _disposeOutboundQueue();
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

  Future<void> _initializeOutboundQueue(String dbRootPath) async {
    final database = _syncDatabaseFactory(dbRootPath);
    final gateway = _gateway;
    if (gateway == null) {
      throw StateError('Gateway not initialized');
    }

    _syncDatabase = database;
    _outboundQueue = _outboundQueueFactory(
      syncDatabase: database,
      gateway: gateway,
      emitEvent: _emitEvent,
    );

    _kickOutboxQueue();
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

    return _ok(
      requestId: requestId,
      extra: {
        'state': _state.name,
        'loginState': _latestLoginState?.name,
        'encryptionEnabled': client?.encryptionEnabled ?? false,
        'deviceId': client?.deviceID,
        'userId': userId,
        'deviceKeys': deviceKeyInfo,
        'syncLoopActive': _state == SyncActorState.syncing,
        'syncCount': _syncCount,
        'toDeviceEventCount': _toDeviceEventCount,
      },
    );
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

  Future<Map<String, Object?>> _handleStop({String? requestId}) async {
    if (_state == SyncActorState.disposed) {
      return _invalidState('stop', requestId: requestId);
    }

    _log('state: ${_state.name} -> stopping');
    _state = SyncActorState.stopping;
    _gateway?.client.backgroundSync = false;

    try {
      await _syncSub?.cancel();
      await _disposeOutboundQueue();

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
      'requestId': ?requestId,
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
      'errorCode': ?errorCode,
      'requestId': ?requestId,
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
    String expectedTypeName = 'String',
  }) {
    if (value == null) {
      return _error(
        'Missing required parameter: $key',
        requestId: requestId,
        errorCode: 'MISSING_PARAMETER',
      );
    }
    return _error(
      'Parameter "$key" must be a $expectedTypeName, got ${value.runtimeType}',
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
