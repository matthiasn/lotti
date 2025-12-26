import 'dart:developer' as developer;

/// Centralized development logging utility with configurable output.
///
/// This class provides a single point of control for debug logging throughout
/// the application. It allows:
/// - Suppressing output in tests to keep test output clean
/// - Capturing logs for test verification when needed
/// - Consistent logging format across the codebase
/// - Structured logging for DevTools via dart:developer.log
///
/// Usage in production code:
/// ```dart
/// DevLogger.log(name: 'MyClass', message: 'Something happened');
/// ```
///
/// Usage in tests:
/// ```dart
/// // Suppress all output (call in setUpAll or setUp)
/// DevLogger.suppressOutput = true;
///
/// // Or capture logs for verification
/// DevLogger.capturedLogs.clear();
/// // ... run code that logs ...
/// expect(DevLogger.capturedLogs, contains(contains('expected message')));
/// ```
class DevLogger {
  DevLogger._(); // Private constructor - use static methods

  /// When true, logs are captured but not printed.
  /// Set this to true in test setup to silence debug output.
  static bool suppressOutput = false;

  /// Captured log messages. Logs are always added here regardless of
  /// [suppressOutput], allowing tests to verify logging behavior.
  static final List<String> capturedLogs = [];

  /// Clears all captured logs. Call this in test setUp/tearDown.
  static void clear() {
    capturedLogs.clear();
  }

  /// Logs a message with the given name prefix.
  ///
  /// The message is always added to [capturedLogs] for test verification.
  /// It is only printed to console if [suppressOutput] is false.
  ///
  /// Uses dart:developer.log for structured logging in DevTools.
  static void log({
    required String name,
    required String message,
    int level = 0,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final fullMessage = StringBuffer('[$name] $message');
    if (error != null) {
      fullMessage.write(' | error: $error');
    }
    if (stackTrace != null) {
      fullMessage.write(' | stackTrace: $stackTrace');
    }
    capturedLogs.add(fullMessage.toString());

    if (!suppressOutput) {
      developer.log(
        message,
        name: name,
        level: level,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Logs a warning message.
  static void warning({
    required String name,
    required String message,
  }) {
    log(name: name, message: 'WARNING: $message', level: 900);
  }

  /// Logs an error message with optional exception and stack trace.
  static void error({
    required String name,
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      name: name,
      message: 'ERROR: $message',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
