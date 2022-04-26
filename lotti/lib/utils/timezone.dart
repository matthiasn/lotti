import 'dart:io';

import 'package:flutter_native_timezone/flutter_native_timezone.dart';

Future<String> getLocalTimezone() async {
  DateTime now = DateTime.now();

  return (!Platform.isWindows && !Platform.isLinux)
      ? await FlutterNativeTimezone.getLocalTimezone()
      : now.timeZoneName;
}
