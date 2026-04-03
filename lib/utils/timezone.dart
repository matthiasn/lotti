import 'dart:io';

import 'package:lotti/utils/platform.dart';

/// Returns the local timezone string.
///
/// [overrideIsTestEnv] is intended for tests only — it bypasses the
/// `isTestEnv` early-return so the platform-specific branches can be
/// exercised.
Future<String> getLocalTimezone({
  String? linuxTimezoneFilePath,
  bool? overrideIsTestEnv,
}) async {
  final now = DateTime.now();
  final effectiveIsTestEnv = overrideIsTestEnv ?? isTestEnv;

  if (effectiveIsTestEnv) {
    return now.timeZoneName;
  }

  if (Platform.isLinux) {
    final filePath = linuxTimezoneFilePath ?? '/etc/timezone';
    final timezone = await File(filePath).readAsString();
    return timezone.trim();
  }

  return now.timeZoneName;
}
