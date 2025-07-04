import 'dart:async';

import 'package:logger/logger.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/platform.dart';

class LoggingService {
  LoggingService() {
    // Configure logger based on environment
    if (isTestEnv) {
      // In tests, disable all logging for maximum performance
      _logger = Logger(level: Level.off);
    } else {
      // In production/development, use pretty printer with colors
      _logger = Logger(
        printer: PrettyPrinter(),
      );
    }
  }

  late final Logger _logger;
  bool _enableLogging = !isTestEnv;

  void listenToConfigFlag() {
    getIt<JournalDb>().watchConfigFlag(enableLoggingFlag).listen((value) {
      _enableLogging = value;
    });
  }

  /// Log an informational message
  void info(String message, {String? domain, String? subDomain}) {
    _logger.i('${domain ?? 'APP'}: $message');
    
    // Only use database logging in production
    if (!isTestEnv && _enableLogging) {
      _captureEventAsync(
        message,
        domain: domain ?? 'APP',
        subDomain: subDomain,
      );
    }
  }

  /// Log a debug message
  void debug(String message, {String? domain, String? subDomain}) {
    _logger.d('${domain ?? 'APP'}: $message');
    
    if (!isTestEnv && _enableLogging) {
      _captureEventAsync(
        message,
        domain: domain ?? 'APP',
        subDomain: subDomain,
        level: InsightLevel.trace,
      );
    }
  }

  /// Log a warning message
  void warning(String message, {String? domain, String? subDomain}) {
    _logger.w('${domain ?? 'APP'}: $message');
    
    if (!isTestEnv && _enableLogging) {
      _captureEventAsync(
        message,
        domain: domain ?? 'APP',
        subDomain: subDomain,
        level: InsightLevel.warn,
      );
    }
  }

  /// Log an error message
  void error(String message, {
    String? domain, 
    String? subDomain,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.e('${domain ?? 'APP'}: $message', error: error, stackTrace: stackTrace);
    
    if (!isTestEnv && _enableLogging) {
      _captureExceptionAsync(
        error ?? message,
        domain: domain ?? 'APP',
        subDomain: subDomain,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log a fatal error
  void fatal(String message, {
    String? domain, 
    String? subDomain,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.f('${domain ?? 'APP'}: $message', error: error, stackTrace: stackTrace);
    
    if (!isTestEnv && _enableLogging) {
      _captureExceptionAsync(
        error ?? message,
        domain: domain ?? 'APP',
        subDomain: subDomain,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log a trace message
  void trace(String message, {String? domain, String? subDomain}) {
    _logger.t('${domain ?? 'APP'}: $message');
    
    if (!isTestEnv && _enableLogging) {
      _captureEventAsync(
        message,
        domain: domain ?? 'APP',
        subDomain: subDomain,
        level: InsightLevel.trace,
      );
    }
  }

  // Legacy methods for backward compatibility
  Future<void> _captureEventAsync(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) async {
    await getIt<LoggingDb>().log(
      LogEntry(
        id: uuid.v1(),
        createdAt: DateTime.now().toIso8601String(),
        domain: domain,
        subDomain: subDomain,
        message: event.toString(),
        level: level.name.toUpperCase(),
        type: type.name.toUpperCase(),
      ),
    );
  }

  void captureEvent(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) {
    // Use the new info method for better performance
    info(event.toString(), domain: domain, subDomain: subDomain);
  }

  Future<void> _captureExceptionAsync(
    dynamic exception, {
    required String domain,
    String? subDomain,
    StackTrace? stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) async {
    await getIt<LoggingDb>().log(
      LogEntry(
        id: uuid.v1(),
        createdAt: DateTime.now().toIso8601String(),
        domain: domain,
        subDomain: subDomain,
        message: exception.toString(),
        stacktrace: stackTrace?.toString(),
        level: level.name.toUpperCase(),
        type: type.name.toUpperCase(),
      ),
    );
  }

  void captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    StackTrace? stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) {
    // Use the new error method for better performance
    error(
      exception.toString(),
      domain: domain,
      subDomain: subDomain,
      error: exception,
      stackTrace: stackTrace,
    );
  }

  /// Get the underlying logger instance for advanced usage
  Logger get logger => _logger;
}
