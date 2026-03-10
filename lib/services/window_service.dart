import 'dart:async';
import 'dart:ui';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/service_disposer.dart';
import 'package:lotti/utils/immediate_exit.dart';
import 'package:lotti/utils/platform.dart';
import 'package:meta/meta.dart';
import 'package:window_manager/window_manager.dart';

/// Function signature for process exit.
typedef ExitCallback = void Function(int code);

/// Function signature for async disposal (e.g. player shutdown).
typedef AsyncDisposer = Future<void> Function();

/// Function signature for platform checks (e.g. macOS detection).
typedef PlatformCheck = bool Function();

class WindowService implements WindowListener {
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
    }
    _disposer = ServiceDisposer(getIt, _logDisposalError);
  }

  late final ServiceDisposer _disposer;
  final ExitCallback _exitFn;
  final AsyncDisposer _playerDisposer;
  final PlatformCheck _isMacOS;

  final sizeKey = 'WINDOW_SIZE';
  final offsetKey = 'WINDOW_OFFSET';

  Future<void> restore() async {
    if (isDesktop) {
      await restoreSize();
      await restoreOffset();
    }
  }

  Future<void> restoreSize() async {
    final sizeString = await getIt<SettingsDb>().itemByKey(sizeKey);
    final values = sizeString?.split(',').map(double.parse).toList();
    final width = values?.first ?? 400;
    final height = values?.last ?? 900;
    await windowManager.setSize(Size(width, height));
  }

  Future<void> restoreOffset() async {
    final offsetString = await getIt<SettingsDb>().itemByKey(offsetKey);
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
    unawaited(_handleClose());
  }

  Future<void> _handleClose() async {
    if (_isMacOS()) {
      // macOS shutdown sequence — three steps, all while the Dart VM is alive:
      //
      // 1. Stop non-database services (outbox, sync, timers).
      // 2. Dispose the media_kit Player so mpv's native core thread stops
      //    cleanly and won't try to invoke FFI callbacks during VM teardown.
      // 3. Call POSIX _exit(0) via FFI. Unlike Dart's exit() (which calls
      //    C exit() → atexit handlers → Dart VM teardown → GC finalizers),
      //    _exit() terminates immediately. This prevents:
      //    - NativeFinalizer on FinalizableDatabase triggering sqlite3_close_v2
      //      → functionDestroy → DLRT_GetFfiCallbackMetadata → SIGABRT
      //    - Any remaining native threads invoking Dart FFI callbacks
      //
      // Safety: SQLite WAL mode guarantees data integrity on abrupt exit;
      // the WAL is replayed on next open. The OS reclaims all resources.
      try {
        await _disposer.disposeServicesOnly();
      } catch (e, s) {
        _logDisposalError(e, s, 'disposeServicesOnly');
      }

      try {
        await _playerDisposer();
      } catch (e, s) {
        _logDisposalError(e, s, 'audioPlayer');
      }

      _exitFn(0);
    } else {
      try {
        await _disposer.disposeAll();
      } catch (e, s) {
        _logDisposalError(e, s, 'disposeAll');
      }
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
      getIt<LoggingService>().captureException(
        error,
        domain: 'WINDOW_SERVICE',
        subDomain: 'dispose_$service',
        stackTrace: stackTrace,
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
