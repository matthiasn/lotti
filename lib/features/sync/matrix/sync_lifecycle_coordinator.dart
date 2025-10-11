import 'dart:async';

import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_timeline_listener.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_pipeline.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

typedef LifecycleCallback = Future<void> Function();

/// Coordinates lifecycle transitions for the sync subsystem.
///
/// The coordinator observes login state changes from the injected
/// [MatrixSyncGateway] and ensures that timeline listeners and auxiliary
/// lifecycle hooks are activated exactly once per login session. When the user
/// logs out, the coordinator performs the corresponding teardown so the engine
/// can cleanly restart on the next login.
class SyncLifecycleCoordinator {
  SyncLifecycleCoordinator({
    required MatrixSyncGateway gateway,
    required MatrixSessionManager sessionManager,
    required MatrixTimelineListener timelineListener,
    required SyncRoomManager roomManager,
    required LoggingService loggingService,
    SyncPipeline? pipeline,
    LifecycleCallback? onLogin,
    LifecycleCallback? onLogout,
  })  : _gateway = gateway,
        _sessionManager = sessionManager,
        _timelineListener = timelineListener,
        _roomManager = roomManager,
        _loggingService = loggingService,
        _pipeline = pipeline,
        _onLogin = onLogin,
        _onLogout = onLogout;

  final MatrixSyncGateway _gateway;
  final MatrixSessionManager _sessionManager;
  final MatrixTimelineListener _timelineListener;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;
  final SyncPipeline? _pipeline;

  LifecycleCallback? _onLogin;
  LifecycleCallback? _onLogout;
  StreamSubscription<LoginState>? _loginSubscription;
  bool _isActive = false;
  bool _isInitialized = false;
  Future<void>? _pendingTransition;
  Future<void>? _initialization;

  /// Returns whether the coordinator currently considers the sync pipeline
  /// active (i.e. logged in and timeline listeners attached).
  bool get isActive => _isActive;

  /// Updates the lifecycle hooks that are invoked when the login state changes.
  ///
  /// Hooks can safely be updated at runtime; subsequent transitions will use
  /// the latest callbacks.
  void updateHooks({
    LifecycleCallback? onLogin,
    LifecycleCallback? onLogout,
  }) {
    if (onLogin != null) {
      _onLogin = onLogin;
    }
    if (onLogout != null) {
      _onLogout = onLogout;
    }
  }

  /// Initializes the coordinator by priming the timeline listener and
  /// establishing the login-state subscription.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _initialization ??= _performInitialization();
    try {
      await _initialization;
    } finally {
      if (_isInitialized) {
        _initialization = null;
      }
    }
  }

  Future<void> _performInitialization() async {
    if (_isInitialized) {
      return;
    }

    try {
      // Initialize either the provided pipeline or the legacy timeline listener.
      if (_pipeline != null) {
        await _pipeline!.initialize();
      } else {
        await _timelineListener.initialize();
      }
      await _roomManager.initialize();
      _loginSubscription ??=
          _gateway.loginStateChanges.listen(_handleLoginState);

      if (_sessionManager.isLoggedIn()) {
        await _handleLoggedIn();
      }

      _isInitialized = true;
    } catch (error, stackTrace) {
      _isInitialized = false;
      _loggingService.captureException(
        error,
        domain: 'SYNC_LIFECYCLE',
        subDomain: 'initialize',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Reconciles the coordinator state with the current login status. This is
  /// useful after imperative login/logout operations where the gateway might
  /// not emit a fresh state.
  Future<void> reconcileLifecycleState() async {
    if (_sessionManager.isLoggedIn()) {
      await _handleLoggedIn();
    } else {
      await _handleLoggedOut();
    }
  }

  Future<void> _handleLoginState(LoginState state) {
    if (state == LoginState.loggedIn) {
      return _handleLoggedIn();
    }
    if (state == LoginState.loggedOut && _isActive) {
      return _handleLoggedOut();
    }
    return Future<void>.value();
  }

  Future<void> _handleLoggedIn() async {
    if (_isActive) {
      return;
    }

    _pendingTransition ??= _activate();
    try {
      await _pendingTransition;
    } finally {
      _pendingTransition = null;
    }
  }

  Future<void> _activate() async {
    _loggingService.captureEvent(
      'Entering logged-in lifecycle state.',
      domain: 'SYNC_LIFECYCLE',
      subDomain: 'activate',
    );

    try {
      await _roomManager.hydrateRoomSnapshot(client: _sessionManager.client);
      if (_pipeline != null) {
        await _pipeline!.start();
      } else {
        await _timelineListener.start();
      }
      if (_onLogin != null) {
        await _onLogin!();
      }
      _isActive = true;
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'SYNC_LIFECYCLE',
        subDomain: 'activate',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _handleLoggedOut() async {
    if (!_isActive && _pendingTransition == null) {
      return;
    }

    if (_pendingTransition != null) {
      await _pendingTransition;
    }

    if (!_isActive) {
      return;
    }

    _pendingTransition = _deactivate();
    try {
      await _pendingTransition;
    } finally {
      _pendingTransition = null;
    }
  }

  Future<void> _deactivate() async {
    _loggingService.captureEvent(
      'Entering logged-out lifecycle state.',
      domain: 'SYNC_LIFECYCLE',
      subDomain: 'deactivate',
    );

    try {
      if (_pipeline != null) {
        await _pipeline!.dispose();
      } else {
        final timeline = _timelineListener.timeline;
        timeline?.cancelSubscriptions();
      }
      if (_onLogout != null) {
        await _onLogout!();
      }
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'SYNC_LIFECYCLE',
        subDomain: 'deactivate',
        stackTrace: stackTrace,
      );
      // Surface teardown failures so callers can decide whether to retry or
      // halt – mirrors the activation path which also rethrows.
      rethrow;
    } finally {
      _isActive = false;
    }
  }

  /// Cancels the login-state subscription. Callers remain responsible for
  /// disposing the injected dependencies.
  Future<void> dispose() async {
    await _loginSubscription?.cancel();
    _loginSubscription = null;
    _pendingTransition = null;
    _isActive = false;
  }
}
