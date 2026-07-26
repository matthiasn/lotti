import 'dart:async';
import 'dart:convert';

import 'package:lotti/classes/config.dart';
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

  MatrixStreamConsumer? get _pipeline => _pipelineAccessor();
  Client get _client => sessionManager.client;
  MatrixConfig? get _matrixConfig => sessionManager.matrixConfig;

  Future<String?> joinRoom(String roomId) async {
    final room = await roomManager.joinRoom(roomId);
    return room?.id ?? roomId;
  }

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

  Future<String> createRoom({List<String>? invite}) =>
      roomManager.createRoom(inviteUserIds: invite);

  Future<String?> getRoom() => roomManager.loadPersistedRoomId();

  Future<void> leaveRoom() async {
    loggingService.log(
      LogDomain.sync,
      'leaveRoom requested',
      subDomain: 'room.leave',
    );
    await roomManager.leaveCurrentRoom();
  }

  Future<void> inviteToSyncRoom({required String userId}) async {
    loggingService.log(
      LogDomain.sync,
      'inviteToSyncRoom requested user=$userId room=${roomManager.currentRoomId}',
      subDomain: 'room.invite',
    );
    await roomManager.inviteUser(userId);
  }

  Future<void> acceptInvite(SyncRoomInvite invite) async {
    loggingService.log(
      LogDomain.sync,
      'acceptInvite requested room=${invite.roomId} from=${invite.senderId}',
      subDomain: 'room.acceptInvite',
    );
    await roomManager.acceptInvite(invite);
  }

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

  /// Deletes [deviceKeys]' session from the homeserver after checking it
  /// belongs to the logged-in account. See [deleteDeviceById].
  Future<void> deleteDevice(DeviceKeys deviceKeys) async {
    final deviceId = deviceKeys.deviceId;

    if (deviceId == null) {
      throw ArgumentError(
        'Cannot delete device: deviceId is null for device '
        '${deviceKeys.deviceDisplayName ?? 'unknown'}',
      );
    }

    if (deviceKeys.userId != _client.userID) {
      throw StateError(
        'Cannot delete device $deviceId: Device belongs to user '
        '${deviceKeys.userId} but current user is ${_client.userID}',
      );
    }

    await deleteDeviceById(deviceId);
  }

  /// Deletes the session [deviceId] from the homeserver, then refreshes the
  /// local device-key cache so the removal unblocks sync immediately.
  ///
  /// Works for sessions without published encryption keys too — the id comes
  /// from the account's own device inventory ([getSyncDevices]). Any
  /// in-flight emoji verification against the device is cancelled first: a
  /// dead session can never answer, and the hung ceremony would otherwise
  /// keep polling a device that is about to disappear.
  Future<void> deleteDeviceById(String deviceId) async {
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

    if (config.password.isEmpty) {
      throw UnsupportedError(
        'Cannot delete device $deviceId: Password authentication required '
        'but no password is available. SSO/token authentication not yet '
        'implemented.',
      );
    }

    await _cancelActiveVerificationsFor(deviceId);

    await gateway.deleteDevice(
      deviceId,
      auth: AuthenticationPassword(
        password: config.password,
        identifier: AuthenticationUserIdentifier(user: config.user),
      ),
    );

    loggingService.log(
      LogDomain.sync,
      'device deleted deviceId=$deviceId',
      subDomain: 'deleteDevice',
    );

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

  /// Returns every session on the sync account, merging the homeserver's
  /// device inventory (names, last-seen) with the E2EE key cache
  /// (verification state), ordered for display.
  Future<List<SyncDeviceInfo>> getSyncDevices() async {
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
        ),
      );
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
          map['queueActive'] = stats.total;
          map['queueApplied'] = stats.applied;
          map['queueAbandoned'] = stats.abandoned;
          map['queueRetrying'] = stats.retrying;
        } catch (error, stackTrace) {
          loggingService.error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: 'metrics.queueStats',
          );
        }
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
