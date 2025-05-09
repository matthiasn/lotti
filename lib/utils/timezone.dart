import 'dart:io';

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

  return now.timeZoneName;
}
