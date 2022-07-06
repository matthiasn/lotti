import 'dart:io';

import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:lotti/utils/platform.dart';

Future<String> getLocalTimezone() async {
  final now = DateTime.now();

  if (isTestEnv) {
    return now.timeZoneName;
  }

  if (Platform.isLinux) {
    final timezone = await File('/etc/timezone').readAsString();
    return timezone.trim();
  }

  if (!Platform.isWindows && !Platform.isLinux) {
    return FlutterNativeTimezone.getLocalTimezone();
  }

  return now.timeZoneName;
}
