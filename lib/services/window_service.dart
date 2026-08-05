import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/service_disposer.dart';
import 'package:lotti/utils/immediate_exit.dart';
import 'package:lotti/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

/// Function signature for process exit.
typedef ExitCallback = void Function(int code);

/// Function signature for async disposal (e.g. player shutdown).
typedef AsyncDisposer = Future<void> Function();

/// Function signature for platform checks (e.g. macOS detection).
typedef PlatformCheck = bool Function();

class WindowService with WidgetsBindingObserver implements WindowListener {
  WindowService({
    @visibleForTesting ExitCallback? exitOverride,
    @visibleForTesting AsyncDisposer? playerDisposerOverride,
    @visibleForTesting PlatformCheck? isMacOSOverride,
    AsyncDisposer? beforeLogFlush,
    @visibleForTesting bool skipWindowManagerSetup = false,
    @visibleForTesting AppPrefs? prefsOverride,
  }) : _exitFn = exitOverride ?? immediateExit,
       _playerDisposer =
           playerDisposerOverride ?? AudioPlayerController.disposeActivePlayer,
       _beforeLogFlush = beforeLogFlush ?? (() async {}),
       _isMacOS = isMacOSOverride ?? (() => isMacOS),
       _prefs = prefsOverride ?? makeSharedPrefsService() {
    if (!skipWindowManagerSetup) {
      windowManager.addListener(this);
      if (isDesktop) {
        windowManager.setPreventClose(true);
      }
      // Catches platform shutdown signals (SIGTERM, macOS logout, applicationWillTerminate)
      // that bypass the windowManager close path.
      WidgetsBinding.instance.addObserver(this);
    }
    _disposer = ServiceDisposer(getIt, _logDisposalError);
  }

  late final ServiceDisposer _disposer;
  Future<void>? _shutdownFuture;
  Future<void>? _closeFuture;
  final ExitCallback _exitFn;
  final AsyncDisposer _playerDisposer;
  final AsyncDisposer _beforeLogFlush;
  final PlatformCheck _isMacOS;
  final AppPrefs _prefs;

  final sizeKey = 'WINDOW_SIZE';
  final offsetKey = 'WINDOW_OFFSET';

  /// Window geometry is device state, not world state: it lives in
  /// SharedPreferences so it survives profile switches, with a one-time
  /// read-through migration from the legacy per-profile SettingsDb rows.
  Future<void> restore() async {
    if (isDesktop) {
      final (size, offset) = await resolveGeometry();
      await _applyRestoredSize(size);
      await _applyRestoredOffset(offset);
    }
  }

  /// Reads persisted window geometry, migrating legacy SettingsDb rows into
  /// SharedPreferences when the prefs entries are absent.
  @visibleForTesting
  Future<(String?, String?)> resolveGeometry() async {
    var size = await _prefs.getString(sizeKey);
    var offset = await _prefs.getString(offsetKey);
    if (size == null || offset == null) {
      final legacy = await getIt<SettingsDb>().itemsByKeys({
        sizeKey,
        offsetKey,
      });
      final legacySize = legacy[sizeKey];
      final legacyOffset = legacy[offsetKey];
      if (size == null && legacySize != null) {
        size = legacySize;
        await _prefs.setString(key: sizeKey, value: legacySize);
      }
      if (offset == null && legacyOffset != null) {
        offset = legacyOffset;
        await _prefs.setString(key: offsetKey, value: legacyOffset);
      }
    }
    return (size, offset);
  }

  Future<void> _applyRestoredSize(String? sizeString) async {
    final values = sizeString?.split(',').map(double.parse).toList();
    final width = values?.first ?? 400;
    final height = values?.last ?? 900;
    await windowManager.setSize(Size(width, height));
  }

  Future<void> _applyRestoredOffset(String? offsetString) async {
    final values = offsetString?.split(',').map(double.parse).toList();
    final dx = values?.first;
    final dy = values?.last;
    if (dx != null && dy != null) {
      await windowManager.setPosition(Offset(dx, dy));
    }
  }

  @override
  void onWindowBlur() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowEvent(String eventName) {}

  @override
  void onWindowFocus() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowMinimize() {}

  Future<void> _onMoved() async {
    final offset = await windowManager.getPosition();
    await _prefs.setString(
      key: offsetKey,
      value: '${offset.dx},${offset.dy}',
    );
  }

  Future<void> _onResized() async {
    final size = await windowManager.getSize();
    await _prefs.setString(
      key: sizeKey,
      value: '${size.width},${size.height}',
    );
  }

  @override
  Future<void> onWindowMove() async {}

  @override
  Future<void> onWindowResize() async {}

  @override
  void onWindowRestore() {}

  @override
  void onWindowUnmaximize() {}

  @override
  void onWindowClose() {
    unawaited(closeWindow());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(closeWindow());
    }
  }

  /// Detaches this instance from the window manager and the widgets binding
  /// without tearing the window down. Called during an in-app profile
  /// switch: the outgoing generation's WindowService must stop observing
  /// window events, or it would keep writing geometry after its service
  /// generation is disposed.
  void detachForRestart() {
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    if (isDesktop) {
      // Without this, a switch that fails after teardown would leave
      // preventClose set with no listener to honor the close request.
      unawaited(windowManager.setPreventClose(false));
    }
  }

  /// Stops native/background work and closes every database exactly once.
  ///
  /// Both Flutter's app-exit callback and the window-manager callback await
  /// this same future. This prevents concurrent or duplicate Drift closes and
  /// ensures a second shutdown signal cannot let engine teardown race ahead of
  /// the first teardown sequence. Pending framework summaries drain after
  /// service/player teardown and immediately before the final log flush.
  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  Future<void> _shutdown() async {
    await _disposer.disposeAll();

    try {
      await _playerDisposer();
    } catch (e, s) {
      _logDisposalError(e, s, 'audioPlayer');
    }

    try {
      await _beforeLogFlush();
    } catch (e, s) {
      _logDisposalError(e, s, 'frameworkErrorSummaries');
    }

    // Bounded so a hung file flush cannot indefinitely delay shutdown.
    try {
      if (getIt.isRegistered<LoggingService>()) {
        await getIt<LoggingService>().flush().timeout(
          const Duration(seconds: 1),
        );
      }
    } catch (_) {
      // Logging is best-effort during shutdown.
    }
  }

  /// Runs the shared teardown and then terminates the desktop window once.
  Future<void> closeWindow() => _closeFuture ??= _closeWindow();

  Future<void> _closeWindow() async {
    await shutdown();
    if (_isMacOS()) {
      // All SQLite handles have been released while Dart FFI callbacks are
      // still valid. Avoid a second native-finalizer pass during VM teardown.
      _exitFn(0);
    } else {
      try {
        await windowManager.destroy();
      } catch (e, s) {
        _logDisposalError(e, s, 'windowManager.destroy');
      }
    }
  }

  void _logDisposalError(
    dynamic error,
    StackTrace stackTrace,
    String service,
  ) {
    try {
      getIt<DomainLogger>().error(
        LogDomain.general,
        error as Object,
        stackTrace: stackTrace,
        subDomain: 'dispose_$service',
      );
    } catch (_) {
      // LoggingService itself may already be torn down.
    }
  }

  @override
  void onWindowMoved() {
    _onMoved();
  }

  @override
  void onWindowResized() {
    _onResized();
  }

  @override
  void onWindowDocked() {}

  @override
  void onWindowUndocked() {}
}
