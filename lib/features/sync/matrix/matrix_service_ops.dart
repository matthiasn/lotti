import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_engine.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

/// Room, device-verification and diagnostics operations of [MatrixService].
///
/// Extracted into a standalone collaborator so the service file stays under the
/// size limit. The owning [MatrixService] keeps thin public delegators that
/// forward to this class; shared, mutable service state (the pipeline instance
/// and the key-verification subscription) is reached through the injected
/// accessors so the collaborator never has to mutate the service directly.
class MatrixServiceOps {
  MatrixServiceOps({
    required this.gateway,
    required this.loggingService,
    required this.collectSyncMetrics,
    required this.queueCoordinator,
    required this.roomManager,
    required this.sessionManager,
    required this.syncEngine,
    required this.incomingKeyVerificationController,
    required MatrixStreamConsumer? Function() pipeline,
    required this.keyVerificationRequestSubscription,
    required this.setKeyVerificationRequestSubscription,
    required this.service,
    required this.settingsDb,
  }) : _pipelineAccessor = pipeline;

  final MatrixSyncGateway gateway;
  final DomainLogger loggingService;
  final bool collectSyncMetrics;
  final QueuePipelineCoordinator queueCoordinator;
  final SyncRoomManager roomManager;
  final MatrixSessionManager sessionManager;
  final SyncEngine syncEngine;
  final StreamController<KeyVerification> incomingKeyVerificationController;
  final MatrixStreamConsumer? Function() _pipelineAccessor;
  final StreamSubscription<KeyVerification>? Function()
  keyVerificationRequestSubscription;
  final void Function(StreamSubscription<KeyVerification>?)
  setKeyVerificationRequestSubscription;
  final MatrixService Function() service;
  final SettingsDb settingsDb;

  MatrixStreamConsumer? get _pipeline => _pipelineAccessor();
  Client get _client => sessionManager.client;
  MatrixConfig? get _matrixConfig => sessionManager.matrixConfig;

  Future<String?> joinRoom(String roomId) async {
    final room = await roomManager.joinRoom(roomId);
    return room?.id ?? roomId;
  }

  /// Creates the account's encrypted sync room and returns its id. The room is
  /// named by the moment it was created so an account that ends up with a
  /// stray extra room can tell them apart in another client.
  Future<String> createRoom() => roomManager.createRoom(
    name: 'Lotti sync ${clock.now().toIso8601String()}',
  );

  Future<void> saveRoom(String roomId) async {
    await roomManager.saveRoomId(roomId);

    // When provisioning saves the room after login, restart the
    // retained consumer's bindings (un-partials the room, attaches
    // diagnostic signals) when present, then drive catch-up through
    // the queue coordinator — which is the mandatory inbound path
    // regardless of whether a consumer pipeline was constructed.
    final pipeline = _pipeline;

    unawaited(() async {
      try {
        // A room switched into may still hold a pre-upgrade outbound megolm
        // session (ADR 0045); rotate before anything is sent to it.
        await rotateOutboundSessionsForExclusionPolicy();
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
        await queueCoordinator.onRoomChanged(roomId);
        await queueCoordinator.triggerBridge();
      } catch (error, stackTrace) {
        loggingService.error(
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
  Future<void> clearPersistedRoom() => roomManager.clearPersistedRoom();

  bool isLoggedIn() => sessionManager.isLoggedIn();

  Future<String?> getRoom() => roomManager.loadPersistedRoomId();

  List<DeviceKeys> getUnverifiedDevices() {
    return gateway.unverifiedDevices();
  }

  Future<void> verifyDevice(DeviceKeys deviceKeys) => verifyMatrixDevice(
    deviceKeys: deviceKeys,
    service: service(),
  );

  /// Runs post-verification recovery so sync resumes without app restart.
  ///
  /// This refreshes cached device keys/trust and nudges the pipeline with a
  /// catch-up rescan to pick up pending encrypted events immediately.
  Future<void> onVerificationCompleted({required String source}) async {
    loggingService.log(
      LogDomain.sync,
      'verification.completed source=$source',
      subDomain: 'verification',
    );

    if (!isLoggedIn()) return;

    await refreshDeviceKeysAndResumeSync(subDomain: 'verification');
  }

  /// Marker prefix recording that a room's outbound megolm session was
  /// rotated when this install adopted `ShareKeysWith.directlyVerifiedOnly`
  /// (ADR 0045). Keyed per room: switching to a room whose pre-upgrade
  /// session was never wiped must still rotate it.
  static String megolmRotatedForExclusionKey(String roomId) =>
      'matrix_megolm_rotated_for_exclusion_v1_$roomId';

  /// One-time upgrade step for ADR 0045, per sync room.
  ///
  /// Before the exclusion policy, an unverified device could already hold the
  /// room's current outbound megolm session key. Withholding *future* keys
  /// does not revoke a key already handed out, so the outbound session is
  /// discarded once per room: the next send starts a fresh session that only
  /// directly verified devices receive.
  ///
  /// The completion marker is written **only** when the session was actually
  /// cleared. If encryption is not ready yet — `Client.encryption` populates
  /// asynchronously — the migration stays pending and a later launch or room
  /// change retries it.
  Future<void> rotateOutboundSessionsForExclusionPolicy() async {
    try {
      final roomId = roomManager.currentRoomId;
      if (roomId == null) return;

      final markerKey = megolmRotatedForExclusionKey(roomId);
      if (await settingsDb.itemByKey(markerKey) == 'true') return;

      final keyManager = _client.encryption?.keyManager;
      if (keyManager == null) {
        loggingService.log(
          LogDomain.sync,
          'encryption not ready for room $roomId - megolm rotation stays '
          'pending and retries on a later launch',
          subDomain: 'exclusionPolicy.rotate.deferred',
        );
        return;
      }

      await keyManager.clearOrUseOutboundGroupSession(
        roomId,
        wipe: true,
        use: false,
      );

      await settingsDb.saveSettingsItem(markerKey, 'true');
      loggingService.log(
        LogDomain.sync,
        'rotated outbound megolm session for room $roomId so keys shared '
        'under the previous permissive policy stop covering new entries',
        subDomain: 'exclusionPolicy.rotate',
      );
    } catch (error, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'exclusionPolicy.rotate',
      );
    }
  }

  /// Refreshes cached device keys and nudges the pipeline so sync reflects a
  /// changed device set without an app restart.
  ///
  /// The send path consults the cached key list on every message, so a stale
  /// cache after a verification or a device deletion keeps blocking outbound
  /// sync even though the homeserver state already changed. Failures are
  /// logged and swallowed: the triggering operation already succeeded and the
  /// cache converges on a later sync anyway.
  Future<void> refreshDeviceKeysAndResumeSync({
    required String subDomain,
  }) async {
    try {
      final userId = _client.userID;
      if (userId != null) {
        await _client.updateUserDeviceKeys(additionalUsers: {userId});
      } else {
        await _client.updateUserDeviceKeys();
      }
    } catch (error, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$subDomain.updateUserDeviceKeys',
      );
    }

    try {
      await syncEngine.lifecycleCoordinator.reconcileLifecycleState();
      await forceRescan();
    } catch (error, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$subDomain.forceRescan',
      );
    }
  }

  /// Deletes the session [deviceId] from the homeserver, then refreshes the
  /// local device-key cache so the removal unblocks sync immediately.
  ///
  /// Works for sessions without published encryption keys too — the id comes
  /// from the account's own device inventory ([getSyncDevices]). Any
  /// in-flight emoji verification against the device is cancelled first: a
  /// dead session can never answer, and the hung ceremony would otherwise
  /// keep polling a device that is about to disappear.
  ///
  /// [reauthPassword] replaces the stored credential for this call's
  /// user-interactive authentication. The UI supplies it after the homeserver
  /// answered `M_FORBIDDEN`, which means the persisted password no longer
  /// matches the account — the password was rotated elsewhere while this
  /// device kept syncing on its access token. A successful deletion proves
  /// the supplied password *is* the account's, so it is written back to the
  /// stored config and every later interactive operation works unprompted.
  Future<void> deleteDeviceById(
    String deviceId, {
    String? reauthPassword,
  }) async {
    if (deviceId == gateway.currentDeviceId) {
      throw ArgumentError(
        'Cannot delete device $deviceId: it is the session this app is '
        'running as. Use logout instead.',
      );
    }

    final config = _matrixConfig;
    if (config == null) {
      throw StateError(
        'Cannot delete device $deviceId: No Matrix configuration available. '
        'User must be logged in to delete devices.',
      );
    }

    final password = reauthPassword ?? config.password;
    if (password.isEmpty) {
      throw UnsupportedError(
        'Cannot delete device $deviceId: Password authentication required '
        'but no password is available. SSO/token authentication not yet '
        'implemented.',
      );
    }

    await _cancelActiveVerificationsFor(deviceId);

    // Only a delete the homeserver actually performed proves the credential
    // was checked. "Already absent" is treated as success below, but it can
    // come back from a peer's concurrent deletion without this password ever
    // having been validated — so it must not authorise a credential repair.
    var credentialValidated = false;
    try {
      await gateway.deleteDevice(
        deviceId,
        auth: AuthenticationPassword(
          password: password,
          identifier: AuthenticationUserIdentifier(user: config.user),
        ),
      );
      credentialValidated = true;
    } on MatrixException catch (error) {
      // A cache-only entry exists precisely because the homeserver no longer
      // knows the session — "not found" means already deleted, and the
      // recovery below (pruning the cached keys) is the part that actually
      // unblocks sync. Anything else still propagates to the caller.
      if (error.errcode != 'M_NOT_FOUND') rethrow;
      loggingService.log(
        LogDomain.sync,
        'device $deviceId already absent on the homeserver - '
        'continuing into cache recovery',
        subDomain: 'deleteDevice.alreadyAbsent',
      );
    }

    loggingService.log(
      LogDomain.sync,
      'device deleted deviceId=$deviceId',
      subDomain: 'deleteDevice',
    );

    if (credentialValidated &&
        reauthPassword != null &&
        reauthPassword != config.password) {
      await _repairStoredPassword(config, reauthPassword);
    }

    // Bounded: the deletion has already succeeded on the homeserver, so a
    // network drop during the cache refresh must not hang the caller — the
    // cache converges on a later sync regardless.
    try {
      await refreshDeviceKeysAndResumeSync(
        subDomain: 'deleteDevice',
      ).timeout(SyncTuning.deleteDeviceRecoveryTimeout);
    } on TimeoutException {
      loggingService.log(
        LogDomain.sync,
        'device-key refresh still running after '
        '${SyncTuning.deleteDeviceRecoveryTimeout.inSeconds}s - deletion '
        'already succeeded, cache converges on a later sync',
        subDomain: 'deleteDevice.refreshTimeout',
      );
    }
  }

  /// Writes a password the homeserver just accepted back into the stored
  /// config, so the next interactive operation no longer has to ask.
  ///
  /// Failures are logged and swallowed: the device is already gone from the
  /// homeserver, and reporting a storage error would tell the user their
  /// removal failed when it did not. A failed write is followed by an attempt
  /// to put the previous config back — `SecureStorage.writeValue` deletes the
  /// key before writing it, so giving up after a half-completed replacement
  /// would leave the account with no persisted credentials at all and no way
  /// to reconnect after a restart.
  Future<void> _repairStoredPassword(
    MatrixConfig config,
    String password,
  ) async {
    try {
      await service().setConfig(config.copyWith(password: password));
      loggingService.log(
        LogDomain.sync,
        'stored sync password replaced after interactive re-authentication',
        subDomain: 'deleteDevice.reauth',
      );
    } catch (error, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'deleteDevice.reauthPersist',
      );
      try {
        await service().setConfig(config);
      } catch (restoreError, restoreStackTrace) {
        loggingService.error(
          LogDomain.sync,
          restoreError,
          stackTrace: restoreStackTrace,
          subDomain: 'deleteDevice.reauthRestore',
        );
      }
    }
  }

  /// Returns every session on the sync account, merging the homeserver's
  /// device inventory (names, last-seen) with the E2EE key cache
  /// (verification state), ordered for display.
  Future<List<SyncDeviceInfo>> getSyncDevices() async {
    // A roster snapshotted while the SDK is still populating device keys
    // would misclassify keyed sessions as keyless; wait (bounded) for the
    // in-flight key load first.
    try {
      final keysLoading = _client.userDeviceKeysLoading;
      if (keysLoading != null) {
        await keysLoading.timeout(SyncTuning.deleteDeviceRecoveryTimeout);
      }
    } catch (error, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'getSyncDevices.userDeviceKeysLoading',
      );
    }

    final serverDevices = await gateway.getDevices();
    final userId = _client.userID;
    final keysById =
        (userId == null ? null : _client.userDeviceKeys[userId]?.deviceKeys) ??
        <String, DeviceKeys>{};
    final ownDeviceId = gateway.currentDeviceId;

    final devices = serverDevices.map((device) {
      final keys = keysById[device.deviceId];
      final isCurrent = device.deviceId == ownDeviceId;
      final lastSeenTs = device.lastSeenTs;
      return SyncDeviceInfo(
        deviceId: device.deviceId,
        displayName: device.displayName,
        lastSeen: lastSeenTs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastSeenTs),
        isCurrentDevice: isCurrent,
        verified: isCurrent || (keys?.verified ?? false),
        keys: keys,
        userId: userId,
      );
    }).toList();

    // The send path gates on the key cache, not the server inventory — an
    // unverified cached device missing from `GET /devices` (deleted by
    // another client, or a failed post-delete refresh) still blocks sends.
    // Keep such blockers in the roster so the paused banner can never clear
    // while sending is still refused.
    final serverIds = serverDevices.map((device) => device.deviceId).toSet();
    for (final entry in keysById.entries) {
      if (serverIds.contains(entry.key) ||
          entry.key == ownDeviceId ||
          entry.value.verified) {
        continue;
      }
      devices.add(
        SyncDeviceInfo(
          deviceId: entry.key,
          displayName: entry.value.deviceDisplayName,
          isCurrentDevice: false,
          verified: false,
          keys: entry.value,
          onServer: false,
          userId: userId,
        ),
      );
    }

    // The sender's gate spans every cached user (legacy one-user-per-device
    // rooms), so foreign unverified devices must appear here too — otherwise
    // the banner could clear while sends still fail. They can be verified,
    // never deleted.
    for (final userEntry in _client.userDeviceKeys.entries) {
      if (userEntry.key == userId) continue;
      for (final keyEntry in userEntry.value.deviceKeys.entries) {
        if (keyEntry.value.verified) continue;
        devices.add(
          SyncDeviceInfo(
            deviceId: keyEntry.key,
            displayName: keyEntry.value.deviceDisplayName,
            isCurrentDevice: false,
            verified: false,
            keys: keyEntry.value,
            onServer: false,
            ownAccount: false,
            userId: userEntry.key,
          ),
        );
      }
    }

    return sortSyncDevicesForDisplay(devices);
  }

  Future<void> _cancelActiveVerificationsFor(String deviceId) async {
    final svc = service();
    for (final runner in <KeyVerificationRunner?>[
      svc.keyVerificationRunner,
      svc.incomingKeyVerificationRunner,
    ]) {
      if (runner == null || runner.keyVerification.deviceId != deviceId) {
        continue;
      }
      try {
        await runner.cancelVerification();
      } catch (error, stackTrace) {
        loggingService.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: 'deleteDevice.cancelVerification',
        );
      }
    }
  }

  Stream<KeyVerification> getIncomingKeyVerificationStream() =>
      incomingKeyVerificationController.stream;

  Future<void> startKeyVerificationListener() async {
    if (keyVerificationRequestSubscription() != null) {
      return;
    }
    setKeyVerificationRequestSubscription(
      await listenForKeyVerificationRequestsWithSubscription(
        service: service(),
        loggingService: loggingService,
      ),
    );
  }

  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    final diagnostics = await syncEngine.diagnostics(log: false);
    loggingService.log(
      LogDomain.sync,
      'Sync diagnostics: ${json.encode(diagnostics)}',
      subDomain: 'diagnostics',
    );
    return diagnostics;
  }

  /// Last successful queue-ledger read, reused when a later
  /// `queue.stats()` call fails so the panel keeps showing the established
  /// depth instead of dropping to zero. Null until the first success.
  Map<String, int>? _lastQueueCounts;

  Future<SyncMetrics?> getSyncMetrics() async {
    final pipeline = _pipeline;
    if (pipeline == null) return null;
    try {
      // If metrics collection is disabled, do not attempt to read metrics.
      if (!collectSyncMetrics) return null;
      final map = Map<String, dynamic>.from(pipeline.metricsSnapshot());
      // Overlay queue ledger counts — queueActive/applied/abandoned/
      // retrying surface in Matrix Stats alongside the consumer's own
      // counters.
      if (queueCoordinator.isRunning) {
        try {
          final stats = await queueCoordinator.queue.stats();
          _lastQueueCounts = <String, int>{
            'queueActive': stats.total,
            'queueApplied': stats.applied,
            'queueAbandoned': stats.abandoned,
            'queueRetrying': stats.retrying,
          };
        } catch (error, stackTrace) {
          loggingService.error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: 'metrics.queueStats',
          );
        }
        // Carry the last successful read forward when this one failed.
        // `SyncMetrics.fromMap` reads an absent key as 0, so dropping the
        // overlay would replace an established queue depth with a confident
        // zero — the same "nothing is happening" lie this panel was cleaned
        // up to stop telling, and a full-value flash on a background refresh.
        map.addAll(_lastQueueCounts ?? const <String, int>{});
      }
      return SyncMetrics.fromMap(map);
    } catch (e, st) {
      loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'metrics',
      );
      return null;
    }
  }

  Future<void> forceRescan({bool includeCatchUp = true}) async {
    // The queue coordinator owns catch-up; route `includeCatchUp`
    // rescans to its bridge. Live-only rescans are a no-op since the
    // consumer's own live ingestion is suppressed.
    if (!includeCatchUp) {
      loggingService.log(
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
      final resurrected = await queueCoordinator.queue.resurrectAll();
      loggingService.log(
        LogDomain.sync,
        'retryNow.resurrectAll resurrected=$resurrected',
        subDomain: 'retryNow',
      );
    } catch (error, stackTrace) {
      loggingService.error(
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
      await queueCoordinator.triggerBridge();
      loggingService.log(
        LogDomain.sync,
        successMessage,
        subDomain: subDomain,
      );
    } catch (error, stackTrace) {
      loggingService.error(
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
