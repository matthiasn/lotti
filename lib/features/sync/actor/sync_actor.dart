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
part 'sync_actor_handlers.dart';

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
  // Listened/cancelled in the sync_actor_handlers part; the single-file
  // cancel_subscriptions heuristic can't see the cancel across part files.
  // ignore: cancel_subscriptions
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
