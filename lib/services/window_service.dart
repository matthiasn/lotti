import 'dart:ui';

import 'package:lotti/sync/secure_storage.dart';
import 'package:window_manager/window_manager.dart';

class WindowService implements WindowListener {
  WindowService() {
    windowManager.addListener(this);
  }

  final sizeKey = 'sizeKey';
  final offsetKey = 'offsetKey';

  Future<void> restore() async {
    await restoreSize();
    await restoreOffset();
  }

  Future<void> restoreSize() async {
    final sizeString = await SecureStorage.readValue(sizeKey);
    final values = sizeString?.split(',').map(double.parse).toList();
    final width = values?.first;
    final height = values?.last;
    if (width != null && height != null) {
      await windowManager.setSize(Size(width, height));
    }
  }

  Future<void> restoreOffset() async {
    final offsetString = await SecureStorage.readValue(offsetKey);
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

  @override
  Future<void> onWindowMove() async {
    final offset = await windowManager.getPosition();
    await SecureStorage.writeValue(offsetKey, '${offset.dx},${offset.dy}');
  }

  @override
  Future<void> onWindowResize() async {
    final size = await windowManager.getSize();
    await SecureStorage.writeValue(sizeKey, '${size.width},${size.height}');
  }

  @override
  void onWindowRestore() {}

  @override
  void onWindowUnmaximize() {}

  @override
  void onWindowClose() {}

  @override
  void onWindowMoved() {}

  @override
  void onWindowResized() {}
}
