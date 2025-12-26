import 'package:flutter/foundation.dart';

/// Centralized development logging utility with configurable output.
///
/// This class provides a single point of control for debug logging throughout
/// the application. It allows:
/// - Suppressing output in tests to keep test output clean
/// - Capturing logs for test verification when needed
/// - Consistent logging format across the codebase
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
  static void log({
    required String name,
    required String message,
  }) {
    final formattedMessage = '[$name] $message';
    capturedLogs.add(formattedMessage);

    if (!suppressOutput) {
      debugPrint(formattedMessage);
    }
  }

  /// Logs a warning message.
  static void warning({
    required String name,
    required String message,
  }) {
    log(name: name, message: 'WARNING: $message');
  }

  /// Logs an error message with optional exception and stack trace.
  static void error({
    required String name,
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final errorDetails = error != null ? ' $error' : '';
    final stackDetails = stackTrace != null ? '\n$stackTrace' : '';
    log(name: name, message: 'ERROR: $message$errorDetails$stackDetails');
  }
}
