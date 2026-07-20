import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/get_it.dart';
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
    @visibleForTesting bool skipWindowManagerSetup = false,
  }) : _exitFn = exitOverride ?? immediateExit,
       _playerDisposer =
           playerDisposerOverride ?? AudioPlayerController.disposeActivePlayer,
       _isMacOS = isMacOSOverride ?? (() => isMacOS) {
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
  final PlatformCheck _isMacOS;

  final sizeKey = 'WINDOW_SIZE';
  final offsetKey = 'WINDOW_OFFSET';

  Future<void> restore() async {
    if (isDesktop) {
      final restoredValues = await getIt<SettingsDb>().itemsByKeys({
        sizeKey,
        offsetKey,
      });
      await _applyRestoredSize(restoredValues[sizeKey]);
      await _applyRestoredOffset(restoredValues[offsetKey]);
    }
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
    await getIt<SettingsDb>().saveSettingsItem(
      offsetKey,
      '${offset.dx},${offset.dy}',
    );
  }

  Future<void> _onResized() async {
    final size = await windowManager.getSize();
    await getIt<SettingsDb>().saveSettingsItem(
      sizeKey,
      '${size.width},${size.height}',
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

  /// Stops native/background work and closes every database exactly once.
  ///
  /// Both Flutter's app-exit callback and the window-manager callback await
  /// this same future. This prevents concurrent or duplicate Drift closes and
  /// ensures a second shutdown signal cannot let engine teardown race ahead of
  /// the first teardown sequence.
  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  Future<void> _shutdown() async {
    try {
      await _disposer.disposeAll();
    } catch (e, s) {
      _logDisposalError(e, s, 'disposeAll');
    }

    try {
      await _playerDisposer();
    } catch (e, s) {
      _logDisposalError(e, s, 'audioPlayer');
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
