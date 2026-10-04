import 'package:flutter/widgets.dart';

/// Owns the app-exit listener across generations. The listener is created
/// after each bootstrap and disposed during window teardown (via the
/// WindowService beforeLogFlush hook) or a profile switch.
class AppLifecycleHolder {
  AppLifecycleListener? listener;

  void dispose() {
    listener?.dispose();
    listener = null;
  }
}
