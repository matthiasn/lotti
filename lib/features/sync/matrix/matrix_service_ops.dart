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
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
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
        subDomain: 'verification.updateUserDeviceKeys',
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

    final config = _matrixConfig;
    if (config == null) {
      throw StateError(
        'Cannot delete device $deviceId: No Matrix configuration available. '
        'User must be logged in to delete devices.',
      );
    }

    if (deviceKeys.userId != _client.userID) {
      throw StateError(
        'Cannot delete device $deviceId: Device belongs to user '
        '${deviceKeys.userId} but current user is ${_client.userID}',
      );
    }

    if (config.password.isNotEmpty) {
      await _client.deleteDevice(
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
