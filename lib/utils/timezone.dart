import 'dart:io';

import 'package:flutter_native_timezone/flutter_native_timezone.dart';

Future<String> getLocalTimezone() async {
  DateTime now = DateTime.now();

  if (Platform.isLinux) {
    String timezone = await File('/etc/timezone').readAsString();
    return timezone.trim();
  }

  if (!Platform.isWindows && !Platform.isLinux) {
    return FlutterNativeTimezone.getLocalTimezone();
  }

  return now.timeZoneName;
}
