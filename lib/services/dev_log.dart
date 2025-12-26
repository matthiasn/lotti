import 'package:lotti/services/dev_logger.dart';

/// Lightweight dev logging helper.
///
/// Delegates to [DevLogger] which handles logging to DevTools via
/// dart:developer.log and capturing logs for test verification.
/// Console output can be suppressed in tests by setting
/// [DevLogger.suppressOutput] to true.
void lottiDevLog({
  required String name,
  required String message,
  int level = 0,
  Object? error,
  StackTrace? stackTrace,
}) {
  // DevLogger handles logging to DevTools and capturing for tests.
  assert(() {
    DevLogger.log(
      name: name,
      message: message,
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  }(), 'log to console in debug builds');
}
