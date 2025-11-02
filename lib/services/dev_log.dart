// ignore_for_file: avoid_print
import 'dart:developer' as developer;

/// Lightweight dev logging helper that mirrors messages to print in debug/test.
/// This allows tests to capture logs via ZoneSpecification while keeping
/// production behavior (developer.log) intact.
void lottiDevLog({
  required String name,
  required String message,
  int level = 0,
  Object? error,
  StackTrace? stackTrace,
}) {
  developer.log(message,
      name: name, level: level, error: error, stackTrace: stackTrace);
  assert(() {
    // Mirror to print in debug/test only
    // Prefix with logger name for easier matching in tests
    print('[$name] $message');
    return true;
  }(), 'mirror log to test output');
}
