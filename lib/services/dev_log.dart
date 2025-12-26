import 'dart:developer' as developer;

import 'package:lotti/services/dev_logger.dart';

/// Lightweight dev logging helper.
///
/// Writes to `developer.log` for DevTools and uses [DevLogger] for console
/// output. The console output can be suppressed in tests by setting
/// [DevLogger.suppressOutput] to true, while still capturing logs for
/// verification via [DevLogger.capturedLogs].
void lottiDevLog({
  required String name,
  required String message,
  int level = 0,
  Object? error,
  StackTrace? stackTrace,
}) {
  // Always write to developer.log for DevTools
  developer.log(
    message,
    name: name,
    level: level,
    error: error,
    stackTrace: stackTrace,
  );

  // Use DevLogger for console output (respects suppressOutput setting)
  assert(() {
    DevLogger.log(name: name, message: message);
    return true;
  }(), 'log to console in debug builds');
}
