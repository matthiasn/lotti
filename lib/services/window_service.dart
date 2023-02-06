import 'dart:ui';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/inbox/inbox_service.dart';
import 'package:lotti/sync/outbox/outbox_service.dart';
import 'package:window_manager/window_manager.dart';

class WindowService implements WindowListener {
  WindowService() {
    windowManager.addListener(this);
  }

  final sizeKey = 'WINDOW_SIZE';
  final offsetKey = 'WINDOW_OFFSET';

  Future<void> restore() async {
    await restoreSize();
    await restoreOffset();
  }

  Future<void> restoreSize() async {
    final sizeString = await getIt<SettingsDb>().itemByKey(sizeKey);
    final values = sizeString?.split(',').map(double.parse).toList();
    final width = values?.first;
    final height = values?.last;
    if (width != null && height != null) {
      await windowManager.setSize(Size(width, height));
    }
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
    getIt<OutboxService>().restartRunner();
    getIt<InboxService>().restartRunner();
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
  void onWindowClose() {}

  @override
  void onWindowMoved() {
    _onMoved();
  }

  @override
  void onWindowResized() {
    _onResized();
  }
}
