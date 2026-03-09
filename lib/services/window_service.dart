import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/service_disposer.dart';
import 'package:lotti/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

class WindowService implements WindowListener {
  WindowService() {
    windowManager.addListener(this);
    if (isDesktop) {
      windowManager.setPreventClose(true);
    }
    _disposer = ServiceDisposer(getIt, _logDisposalError);
  }

  late final ServiceDisposer _disposer;

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
  void onWindowFocus() {
    //getIt<OutboxService>().restartRunner();
  }

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
    if (isMacOS) {
      // On macOS, dispose only non-database services, then exit(0).
      //
      // We must NOT call Drift's db.close() because sqlite3_close_v2
      // triggers functionDestroy for registered custom SQL functions,
      // which invokes DLRT_GetFfiCallbackMetadata — a Dart FFI runtime
      // lookup that hits a fatal assertion (SIGABRT) during VM teardown.
      //
      // We also skip windowManager.destroy() because it triggers the
      // Flutter engine teardown (Shell::~Shell → DartVM::~DartVM) which
      // races with native SQLite threads still running.
      //
      // This is safe because:
      // - Non-database services (outbox, sync, timers) are stopped first.
      // - SQLite WAL mode guarantees data integrity on abrupt exit;
      //   the WAL is replayed on next open.
      // - The OS reclaims all file handles and memory.
      try {
        await _disposer.disposeServicesOnly();
      } catch (e, s) {
        _logDisposalError(e, s, 'disposeServicesOnly');
      }
      exit(0);
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
