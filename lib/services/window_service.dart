import 'dart:ui';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

class WindowService implements WindowListener {
  WindowService() {
    windowManager.addListener(this);
    if (isDesktop) {
      windowManager.setPreventClose(true);
    }
  }

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
    _handleClose();
  }

  Future<void> _handleClose() async {
    try {
      await _disposeServices();
    } catch (e) {
      // Best-effort cleanup — log but don't block exit.
      try {
        getIt<LoggingService>().captureException(
          e,
          domain: 'WINDOW_SERVICE',
          subDomain: 'onWindowClose',
        );
      } catch (_) {
        // LoggingService itself may already be torn down.
      }
    } finally {
      await windowManager.destroy();
    }
  }

  /// Disposes long-running services in dependency-safe order.
  Future<void> _disposeServices() async {
    // Dispose OutboxService first (depends on MatrixService).
    if (getIt.isRegistered<OutboxService>()) {
      await getIt<OutboxService>().dispose();
    }
    // Then MatrixService (owns sync engine, streams, connectivity sub).
    if (getIt.isRegistered<MatrixService>()) {
      await getIt<MatrixService>().dispose();
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
