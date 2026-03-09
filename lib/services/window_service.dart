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
    try {
      await _disposer.disposeAll();
    } catch (e, s) {
      _logDisposalError(e, s, 'disposeAll');
    }

    // Terminate the process immediately after Dart-level disposal.
    //
    // We intentionally avoid `windowManager.destroy()` here because it
    // triggers the Flutter engine teardown path:
    //   Shell::~Shell() → DartVM::~DartVM() → Dart::Cleanup()
    //     → WaitForIsolateShutdown()
    //
    // That path races with native SQLite worker threads that are still
    // executing sqlite3Close / WAL checkpoint / btree cleanup inside
    // Drift's background isolates. When those native threads call
    // `functionDestroy`, the FFI callback metadata lookup
    // (DLRT_GetFfiCallbackMetadata) hits a fatal assertion because the
    // Dart VM is already partially torn down → SIGABRT.
    //
    // exit(0) is safe here because:
    // - All Dart-level resources have been disposed (streams, timers, outbox).
    // - Drift databases have acknowledged their close commands.
    // - SQLite WAL mode guarantees data integrity even if the process exits
    //   during a WAL checkpoint; the WAL is replayed on next open.
    exit(0);
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
