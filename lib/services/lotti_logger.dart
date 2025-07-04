import 'dart:developer';
import 'package:logger/logger.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';
import 'package:uuid/uuid.dart';

/// Custom logger that extends the logger package and internally uses LoggingDb
/// for database persistence. The codebase can use standard logger methods
/// without knowing about the database implementation.
class LottiLogger extends Logger {
  LottiLogger({
    super.level,
    super.filter,
    super.printer,
    super.output,
  }) : super() {
    _enableLogging = !isTestEnv;
    _listenToConfigFlag();
  }

  static const String _defaultDomain = 'APP';
  bool _enableLogging = !isTestEnv;
  final Uuid _uuid = const Uuid();

  void _listenToConfigFlag() {
    try {
      getIt<JournalDb>().watchConfigFlag(enableLoggingFlag).listen((value) {
        _enableLogging = value;
      });
    } catch (e) {
      // Ignore if JournalDb is not registered (e.g., in tests)
    }
  }

  /// Log an informational message
  @override
  void i(dynamic message,
      {Object? error, StackTrace? stackTrace, DateTime? time}) {
    super.i(message, error: error, stackTrace: stackTrace, time: time);
    _logToDatabase(message.toString(), InsightLevel.info,
        error: error, stackTrace: stackTrace);
  }

  /// Log a debug message
  @override
  void d(dynamic message,
      {Object? error, StackTrace? stackTrace, DateTime? time}) {
    super.d(message, error: error, stackTrace: stackTrace, time: time);
    _logToDatabase(message.toString(), InsightLevel.debug,
        error: error, stackTrace: stackTrace);
  }

  /// Log a warning message
  @override
  void w(dynamic message,
      {Object? error, StackTrace? stackTrace, DateTime? time}) {
    super.w(message, error: error, stackTrace: stackTrace, time: time);
    _logToDatabase(message.toString(), InsightLevel.warn,
        error: error, stackTrace: stackTrace);
  }

  /// Log an error message
  @override
  void e(dynamic message,
      {Object? error, StackTrace? stackTrace, DateTime? time}) {
    super.e(message, error: error, stackTrace: stackTrace, time: time);
    _logToDatabase(message.toString(), InsightLevel.error,
        error: error, stackTrace: stackTrace);
  }

  /// Log a fatal error
  @override
  void f(dynamic message,
      {Object? error, StackTrace? stackTrace, DateTime? time}) {
    super.f(message, error: error, stackTrace: stackTrace, time: time);
    _logToDatabase(message.toString(), InsightLevel.fatal,
        error: error, stackTrace: stackTrace);
  }

  /// Log a trace message
  @override
  void t(dynamic message,
      {Object? error, StackTrace? stackTrace, DateTime? time}) {
    super.t(message, error: error, stackTrace: stackTrace, time: time);
    _logToDatabase(message.toString(), InsightLevel.trace,
        error: error, stackTrace: stackTrace);
  }

  /// Log to database if enabled and not in test environment
  void _logToDatabase(
    String message,
    InsightLevel level, {
    Object? error,
    StackTrace? stackTrace,
    String? domain,
    String? subDomain,
  }) {
    if (isTestEnv || !_enableLogging) {
      return;
    }

    try {
      getIt<LoggingDb>().log(
        LogEntry(
          id: _uuid.v1(),
          createdAt: DateTime.now().toIso8601String(),
          domain: domain ?? _defaultDomain,
          subDomain: subDomain,
          message: message,
          stacktrace: stackTrace?.toString(),
          level: level.name.toUpperCase(),
          type: InsightType.log.name.toUpperCase(),
        ),
      );
    } catch (e, s) {
      // Silently fail if LoggingDb is not available and avoid recursion
      log('Failed to log to database: $e\n$s');
    }
  }

  /// Log an exception with domain and subdomain
  void exception(
    dynamic exception, {
    String? domain,
    String? subDomain,
    StackTrace? stackTrace,
    InsightLevel level = InsightLevel.error,
  }) {
    final message = exception.toString();
    super.e(message, error: exception, stackTrace: stackTrace);

    if (isTestEnv || !_enableLogging) {
      return;
    }

    try {
      getIt<LoggingDb>().log(
        LogEntry(
          id: _uuid.v1(),
          createdAt: DateTime.now().toIso8601String(),
          domain: domain ?? _defaultDomain,
          subDomain: subDomain,
          message: message,
          stacktrace: stackTrace?.toString(),
          level: level.name.toUpperCase(),
          type: InsightType.exception.name.toUpperCase(),
        ),
      );
    } catch (e, s) {
      // Silently fail if LoggingDb is not available and avoid recursion
      log('Failed to log exception to database: $e\n$s');
    }
  }

    /// Log an event with domain and subdomain
  void event(
    dynamic event, {
    String? domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
  }) {
    final message = event.toString();
    
    // Log to console with the correct level
    super.log(
      switch (level) {
        InsightLevel.fatal => Level.fatal,
        InsightLevel.error => Level.error,
        InsightLevel.warn => Level.warning,
        InsightLevel.debug => Level.debug,
        InsightLevel.trace => Level.trace,
        InsightLevel.info => Level.info,
      },
      message,
    );
    
    if (isTestEnv || !_enableLogging) {
      return;
    }

    try {
      getIt<LoggingDb>().log(
        LogEntry(
          id: _uuid.v1(),
          createdAt: DateTime.now().toIso8601String(),
          domain: domain ?? _defaultDomain,
          subDomain: subDomain,
          message: message,
          level: level.name.toUpperCase(),
          type: InsightType.log.name.toUpperCase(),
        ),
      );
    } catch (e, s) {
      // Silently fail if LoggingDb is not available and avoid recursion
      log('Failed to log event to database: $e\n$s');
    }
  }
}
