part of 'sync_actor.dart';

/// Room/send command handlers of [SyncActorCommandHandler].
extension SyncActorRoomCommands on SyncActorCommandHandler {
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
      final inviteUserIds = (command['inviteUserIds'] as List<dynamic>?)
          ?.cast<String>();

      final roomId = await _gateway!.createRoom(
        name: name,
        inviteUserIds: inviteUserIds,
      );
      _outboundQueue?.updateSyncRoomId(roomId);
      _kickOutboxQueue();
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
      _outboundQueue?.updateSyncRoomId(roomId);
      _kickOutboxQueue();
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

  Future<Map<String, Object?>> _handleKickOutbox({String? requestId}) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('kickOutbox', requestId: requestId);
    }

    _kickOutboxQueue();
    return _ok(requestId: requestId);
  }

  Future<Map<String, Object?>> _handleConnectivityChanged(
    Map<String, Object?> command, {
    String? requestId,
  }) async {
    if (_state != SyncActorState.idle && _state != SyncActorState.syncing) {
      return _invalidState('connectivityChanged', requestId: requestId);
    }

    final connected = command['connected'];
    if (connected is! bool) {
      return _paramError(
        'connected',
        connected,
        requestId: requestId,
        expectedTypeName: 'bool',
      );
    }

    _outboundQueue?.updateConnectivity(isConnected: connected);
    if (connected) {
      _kickOutboxQueue();
    }

    return _ok(requestId: requestId);
  }
}
