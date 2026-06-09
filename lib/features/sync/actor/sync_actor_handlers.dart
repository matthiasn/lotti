part of 'sync_actor.dart';

/// Internal sync-loop plumbing for [SyncActorCommandHandler]: outbound-queue
/// init, sync/timeline stream wiring, pause handling and event emission.
/// Split from the main file for size; all members are library-private.
extension SyncActorCommandHandlerInternals on SyncActorCommandHandler {
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
}
