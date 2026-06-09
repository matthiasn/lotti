part of 'matrix_service.dart';

/// Room, device-verification and diagnostics operations of [MatrixService].
/// Extracted into a part-file mixin to keep the service file under the size
/// limit; shared state is reached through the [_MatrixServiceBase] accessors.
mixin _MatrixServiceOps on _MatrixServiceBase {
  Future<String?> joinRoom(String roomId) async {
    final room = await _roomManager.joinRoom(roomId);
    return room?.id ?? roomId;
  }

  Future<void> saveRoom(String roomId) async {
    await _roomManager.saveRoomId(roomId);

    // When provisioning saves the room after login, restart the
    // retained consumer's bindings (un-partials the room, attaches
    // diagnostic signals) when present, then drive catch-up through
    // the queue coordinator — which is the mandatory inbound path
    // regardless of whether a consumer pipeline was constructed.
    final pipeline = _pipeline;

    unawaited(() async {
      try {
        if (pipeline != null) {
          await pipeline.start();
        }
        // The coordinator's `start()` only seeds/prunes for whatever
        // room was current at start time. If the service started
        // before the user picked a room — or the user is now switching
        // rooms — the new room never gets its marker seeded and rows
        // from the previous room remain queued. Both are replayed
        // against the wrong room once the worker resolves the new
        // current room. Run the room-change hook before kicking the
        // bridge so catch-up walks history into a properly seeded
        // queue.
        await _queueCoordinator.onRoomChanged(roomId);
        await _queueCoordinator.triggerBridge();
      } catch (error, stackTrace) {
        _loggingService.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: 'saveRoom.bootstrap',
        );
      }
    }());
  }

  /// Clears only the locally persisted sync-room pointer.
  ///
  /// This does not leave the room on the homeserver. It is intended for flows
  /// that switch credentials and must avoid auto-joining a stale room ID
  /// during reconnect.
  Future<void> clearPersistedRoom() => _roomManager.clearPersistedRoom();

  bool isLoggedIn() => _sessionManager.isLoggedIn();

  Future<String> createRoom({List<String>? invite}) =>
      _roomManager.createRoom(inviteUserIds: invite);

  Future<String?> getRoom() => _roomManager.loadPersistedRoomId();

  Future<void> leaveRoom() async {
    _loggingService.log(
      LogDomain.sync,
      'leaveRoom requested',
      subDomain: 'room.leave',
    );
    await _roomManager.leaveCurrentRoom();
  }

  Future<void> inviteToSyncRoom({required String userId}) async {
    _loggingService.log(
      LogDomain.sync,
      'inviteToSyncRoom requested user=$userId room=${_roomManager.currentRoomId}',
      subDomain: 'room.invite',
    );
    await _roomManager.inviteUser(userId);
  }

  Future<void> acceptInvite(SyncRoomInvite invite) async {
    _loggingService.log(
      LogDomain.sync,
      'acceptInvite requested room=${invite.roomId} from=${invite.senderId}',
      subDomain: 'room.acceptInvite',
    );
    await _roomManager.acceptInvite(invite);
  }

  List<DeviceKeys> getUnverifiedDevices() {
    return _gateway.unverifiedDevices();
  }

  Future<void> verifyDevice(DeviceKeys deviceKeys) => verifyMatrixDevice(
    deviceKeys: deviceKeys,
    service: this as MatrixService,
  );

  /// Runs post-verification recovery so sync resumes without app restart.
  ///
  /// This refreshes cached device keys/trust and nudges the pipeline with a
  /// catch-up rescan to pick up pending encrypted events immediately.
  Future<void> onVerificationCompleted({required String source}) async {
    _loggingService.log(
      LogDomain.sync,
      'verification.completed source=$source',
      subDomain: 'verification',
    );

    if (!isLoggedIn()) return;

    try {
      final userId = client.userID;
      if (userId != null) {
        await client.updateUserDeviceKeys(additionalUsers: {userId});
      } else {
        await client.updateUserDeviceKeys();
      }
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'verification.updateUserDeviceKeys',
      );
    }

    try {
      await _syncEngine.lifecycleCoordinator.reconcileLifecycleState();
      await forceRescan();
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'verification.forceRescan',
      );
    }
  }

  Future<void> deleteDevice(DeviceKeys deviceKeys) async {
    final deviceId = deviceKeys.deviceId;

    if (deviceId == null) {
      throw ArgumentError(
        'Cannot delete device: deviceId is null for device '
        '${deviceKeys.deviceDisplayName ?? 'unknown'}',
      );
    }

    final config = matrixConfig;
    if (config == null) {
      throw StateError(
        'Cannot delete device $deviceId: No Matrix configuration available. '
        'User must be logged in to delete devices.',
      );
    }

    if (deviceKeys.userId != client.userID) {
      throw StateError(
        'Cannot delete device $deviceId: Device belongs to user '
        '${deviceKeys.userId} but current user is ${client.userID}',
      );
    }

    if (config.password.isNotEmpty) {
      await client.deleteDevice(
        deviceId,
        auth: AuthenticationPassword(
          password: config.password,
          identifier: AuthenticationUserIdentifier(user: config.user),
        ),
      );
    } else {
      throw UnsupportedError(
        'Cannot delete device $deviceId: Password authentication required '
        'but no password is available. SSO/token authentication not yet '
        'implemented.',
      );
    }
  }

  Stream<KeyVerification> getIncomingKeyVerificationStream() =>
      incomingKeyVerificationController.stream;

  Future<void> startKeyVerificationListener() async {
    if (_keyVerificationRequestSubscription != null) {
      return;
    }
    _keyVerificationRequestSubscription =
        await listenForKeyVerificationRequestsWithSubscription(
          service: this as MatrixService,
          loggingService: _loggingService,
        );
  }

  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    final diagnostics = await _syncEngine.diagnostics(log: false);
    _loggingService.log(
      LogDomain.sync,
      'Sync diagnostics: ${json.encode(diagnostics)}',
      subDomain: 'diagnostics',
    );
    return diagnostics;
  }

  Future<SyncMetrics?> getSyncMetrics() async {
    if (_pipeline == null) return null;
    try {
      // If metrics collection is disabled, do not attempt to read metrics.
      if (!_collectSyncMetrics) return null;
      final map = Map<String, dynamic>.from(_pipeline!.metricsSnapshot());
      // Overlay queue ledger counts — queueActive/applied/abandoned/
      // retrying surface in Matrix Stats alongside the consumer's own
      // counters.
      if (_queueCoordinator.isRunning) {
        try {
          final stats = await _queueCoordinator.queue.stats();
          map['queueActive'] = stats.total;
          map['queueApplied'] = stats.applied;
          map['queueAbandoned'] = stats.abandoned;
          map['queueRetrying'] = stats.retrying;
        } catch (error, stackTrace) {
          _loggingService.error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: 'metrics.queueStats',
          );
        }
      }
      return SyncMetrics.fromMap(map);
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'metrics',
      );
      return null;
    }
  }

  // Raw map accessor removed in favor of the expanded typed SyncMetrics model.

  Future<void> forceRescan({bool includeCatchUp = true}) async {
    // The queue coordinator owns catch-up; route `includeCatchUp`
    // rescans to its bridge. Live-only rescans are a no-op since the
    // consumer's own live ingestion is suppressed.
    if (!includeCatchUp) {
      _loggingService.log(
        LogDomain.sync,
        'forceRescan.suppressed includeCatchUp=false',
        subDomain: 'forceRescan',
      );
      return;
    }
    await _nudgeBridge(
      subDomain: 'forceRescan',
      successMessage: 'forceRescan.triggerBridge invoked',
    );
  }

  /// User-facing "Retry pending failures now" hook. Resurrects every
  /// abandoned ledger row that is still below the per-row resurrection
  /// hard cap (so backed-off / leased items wake up immediately) and
  /// nudges the bridge in case a remote gap is what's holding the worker.
  Future<void> retryNow() async {
    try {
      final resurrected = await _queueCoordinator.queue.resurrectAll();
      _loggingService.log(
        LogDomain.sync,
        'retryNow.resurrectAll resurrected=$resurrected',
        subDomain: 'retryNow',
      );
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'retryNow.resurrectAll',
      );
    }
    await _nudgeBridge(
      subDomain: 'retryNow',
      successMessage: 'retryNow.triggerBridge invoked',
    );
  }

  Future<void> _nudgeBridge({
    required String subDomain,
    required String successMessage,
  }) async {
    try {
      await _queueCoordinator.triggerBridge();
      _loggingService.log(
        LogDomain.sync,
        successMessage,
        subDomain: subDomain,
      );
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$subDomain.triggerBridge',
      );
    }
  }

  Future<String> getSyncDiagnosticsText() async {
    final p = _pipeline;
    if (p == null) return 'pipeline disabled';
    // Use raw snapshot so we include diagnostics-only fields
    final map = p.metricsSnapshot();
    final lines = map.entries.map((e) => '${e.key}=${e.value}').toList();
    // Append textual diagnostics if available
    try {
      final extras = p.diagnosticsStrings();
      lines.addAll(extras.entries.map((e) => '${e.key}=${e.value}'));
    } catch (_) {
      // Older pipeline without diagnosticsStrings
    }
    return lines.join('\n');
  }

  /// Exposes the pipeline instance for integration tests.
  MatrixStreamConsumer? get debugPipeline => _pipeline;
}
