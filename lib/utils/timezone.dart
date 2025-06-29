import 'dart:io';

import 'package:lotti/utils/platform.dart';

Future<String> getLocalTimezone({String? linuxTimezoneFilePath}) async {
  final now = DateTime.now();

  if (isTestEnv) {
    return now.timeZoneName;
  }

  if (Platform.isLinux) {
    final filePath = linuxTimezoneFilePath ?? '/etc/timezone';
    final timezone = await File(filePath).readAsString();
    return timezone.trim();
  }

  return now.timeZoneName;
}
