import 'dart:convert';

import 'package:lotti/features/sync/matrix/matrix_timeline_listener.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';

typedef SyncEngineHook = Future<void> Function();

/// High-level orchestrator for the sync subsystem.
///
/// The engine composes the session manager, room manager, and timeline
/// listener, delegating lifecycle transitions to [SyncLifecycleCoordinator].
/// Callers can supply hooks that run whenever the sync pipeline transitions
/// between logged-in and logged-out states.
class SyncEngine {
  SyncEngine({
    required MatrixSessionManager sessionManager,
    required SyncRoomManager roomManager,
    required MatrixTimelineListener timelineListener,
    required SyncLifecycleCoordinator lifecycleCoordinator,
    required LoggingService loggingService,
  })  : _sessionManager = sessionManager,
        _roomManager = roomManager,
        _timelineListener = timelineListener,
        _lifecycleCoordinator = lifecycleCoordinator,
        _loggingService = loggingService;

  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final MatrixTimelineListener _timelineListener;
  final SyncLifecycleCoordinator _lifecycleCoordinator;
  final LoggingService _loggingService;

  bool _initialized = false;
  Future<void>? _initialization;

  MatrixSessionManager get sessionManager => _sessionManager;
  SyncRoomManager get roomManager => _roomManager;
  MatrixTimelineListener get timelineListener => _timelineListener;
  SyncLifecycleCoordinator get lifecycleCoordinator => _lifecycleCoordinator;

  /// Initializes the engine and primes the lifecycle coordinator.
  Future<void> initialize({
    SyncEngineHook? onLogin,
    SyncEngineHook? onLogout,
  }) async {
    _lifecycleCoordinator.updateHooks(
      onLogin: onLogin,
      onLogout: onLogout,
    );

    if (_initialized) {
      await _lifecycleCoordinator.reconcileLifecycleState();
      return;
    }

    _initialization ??= _initializeCoordinator();
    try {
      await _initialization;
    } finally {
      if (_initialized) {
        _initialization = null;
      }
    }
  }

  Future<void> _initializeCoordinator() async {
    if (_initialized) {
      return;
    }
    await _lifecycleCoordinator.initialize();
    await _lifecycleCoordinator.reconcileLifecycleState();
    _initialized = true;
  }

  /// Attempts to establish a connection (and optionally login) via the session
  /// manager. After the connection attempt, the lifecycle coordinator is asked
  /// to sync its view of the world so hooks run even if no new login event is
  /// emitted.
  Future<bool> connect({required bool shouldAttemptLogin}) async {
    final success = await _sessionManager.connect(
      shouldAttemptLogin: shouldAttemptLogin,
    );
    if (success) {
      await _lifecycleCoordinator.reconcileLifecycleState();
    }
    return success;
  }

  /// Logs out the underlying session manager and synchronises lifecycle state.
  Future<void> logout() async {
    await _sessionManager.logout();
    await _lifecycleCoordinator.reconcileLifecycleState();
  }

  /// Releases coordinator resources. Callers are responsible for disposing
  /// injected collaborators.
  Future<void> dispose() => _lifecycleCoordinator.dispose();

  /// Emits diagnostic information about the current sync state. Consumers can
  /// surface this for debugging or support tooling.
  Future<Map<String, dynamic>> diagnostics({bool log = true}) async {
    Map<String, dynamic> info;
    try {
      final client = _sessionManager.client;
      final savedRoomId = await _roomManager.loadPersistedRoomId();
      final joinedRooms = client.rooms
          .map(
            (room) => {
              'id': room.id,
              'name': room.name,
              'encrypted': room.encrypted,
              'memberCount': room.summary.mJoinedMemberCount,
            },
          )
          .toList();

      String? loginState;
      try {
        loginState = client.onLoginStateChanged.value.toString();
      } catch (error, stackTrace) {
        _loggingService.captureException(
          error,
          domain: 'SYNC_ENGINE',
          subDomain: 'diagnostics.loginState',
          stackTrace: stackTrace,
        );
        loginState = null;
      }

      info = <String, dynamic>{
        'deviceId': client.deviceID,
        'deviceName': client.deviceName,
        'userId': client.userID,
        'savedRoomId': savedRoomId,
        'syncRoomId': _roomManager.currentRoomId,
        'syncRoom.id': _roomManager.currentRoom?.id,
        'joinedRooms': joinedRooms,
        'isLoggedIn': _sessionManager.isLoggedIn(),
        'timelineActive': _lifecycleCoordinator.isActive,
        'loginState': loginState,
      };
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'SYNC_ENGINE',
        subDomain: 'diagnostics.snapshot',
        stackTrace: stackTrace,
      );
      info = <String, dynamic>{
        'error': error.toString(),
        'isLoggedIn': _sessionManager.isLoggedIn(),
        'timelineActive': _lifecycleCoordinator.isActive,
      };
    }

    if (log) {
      _loggingService.captureEvent(
        'Sync diagnostics: ${json.encode(info)}',
        domain: 'SYNC_ENGINE',
        subDomain: 'diagnostics',
      );
    }

    return info;
  }
}
