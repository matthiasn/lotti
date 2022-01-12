import 'dart:io';

import 'package:flutter_native_timezone/flutter_native_timezone.dart';

Future<String> getLocalTimezone() async {
  return (!Platform.isWindows && !Platform.isLinux)
      ? await FlutterNativeTimezone.getLocalTimezone()
      : '';
}
