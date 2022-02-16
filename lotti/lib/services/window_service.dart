import 'dart:ui';

import 'package:lotti/sync/secure_storage.dart';
import 'package:window_manager/window_manager.dart';

class WindowService implements WindowListener {
  final String sizeKey = 'sizeKey';
  final String offsetKey = 'offsetKey';

  WindowService() {
    windowManager.addListener(this);
  }

  Future<void> restore() async {
    await restoreOffset();
    await restoreSize();
  }

  Future<void> restoreSize() async {
    String? sizeString = await SecureStorage.readValue(sizeKey);
    List<double>? values =
        sizeString?.split(',').map((e) => double.parse(e)).toList();
    double? width = values?.first;
    double? height = values?.last;
    if (width != null && height != null) {
      await windowManager.setSize(Size(width, height));
    }
  }

  Future<void> restoreOffset() async {
    String? offsetString = await SecureStorage.readValue(offsetKey);
    List<double>? values =
        offsetString?.split(',').map((e) => double.parse(e)).toList();
    double? dx = values?.first;
    double? dy = values?.last;
    if (dx != null && dy != null) {
      windowManager.setPosition(Offset(dx, dy));
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
  void onWindowMove() async {
    Offset offset = await windowManager.getPosition();
    SecureStorage.writeValue(offsetKey, '${offset.dx},${offset.dy}');
  }

  @override
  void onWindowResize() async {
    Size size = await windowManager.getSize();
    SecureStorage.writeValue(sizeKey, '${size.width},${size.height}');
  }

  @override
  void onWindowRestore() {}

  @override
  void onWindowUnmaximize() {}
}
