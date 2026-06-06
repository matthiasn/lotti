part of 'sync_actor.dart';

/// Device-verification command handlers and peer-device helpers of
/// [SyncActorCommandHandler].
extension SyncActorVerification on SyncActorCommandHandler {
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
      final directVerification = await _gateway!.startKeyVerification(
        peerDevice,
      );
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

  Future<DeviceKeys?> _findUnverifiedPeerDevice() async {
    final gateway = _gateway;
    final client = gateway?.client;
    if (gateway == null || client == null) return null;

    final userId = client.userID;
    final ownDeviceId = client.deviceID;
    if (userId == null || ownDeviceId == null) return null;

    unawaited(_refreshPeerDeviceKeys(userId));

    final discoveryAttempts =
        _verificationPeerDiscoveryAttempts >
            _maxVerificationPeerDiscoveryAttempts
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
}
