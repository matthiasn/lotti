import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/lotti_logger.dart';

class LoggingService {
  LoggingService();





  /// Log an informational message
  void info(String message, {String? domain, String? subDomain}) {
    getIt<LottiLogger>().event(message, domain: domain, subDomain: subDomain);
  }

  /// Log a debug message (for development debugging, stored with debug level)
  void debug(String message, {String? domain, String? subDomain}) {
    getIt<LottiLogger>().event(message, domain: domain, subDomain: subDomain, level: InsightLevel.debug);
  }

  /// Log a warning message
  void warning(String message, {String? domain, String? subDomain}) {
    getIt<LottiLogger>().event(message, domain: domain, subDomain: subDomain, level: InsightLevel.warn);
  }

  /// Log an error message
  void error(
    String message, {
    String? domain,
    String? subDomain,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    getIt<LottiLogger>().exception(error ?? message,
        domain: domain,
        subDomain: subDomain,
        stackTrace: stackTrace);
  }

  /// Log a fatal error (highest severity level for critical failures)
  void fatal(
    String message, {
    String? domain,
    String? subDomain,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    getIt<LottiLogger>().exception(error ?? message,
        domain: domain,
        subDomain: subDomain,
        stackTrace: stackTrace,
        level: InsightLevel.fatal);
  }

  /// Log a trace message (lowest level logging for detailed debugging)
  void trace(String message, {String? domain, String? subDomain}) {
    getIt<LottiLogger>().event(message, domain: domain, subDomain: subDomain, level: InsightLevel.trace);
  }

  void captureEvent(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
  }) {
    getIt<LottiLogger>().event(
      event,
      domain: domain,
      subDomain: subDomain,
      level: level,
    );
  }

  void captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    StackTrace? stackTrace,
    InsightLevel level = InsightLevel.error,
  }) {
    getIt<LottiLogger>().exception(
      exception,
      domain: domain,
      subDomain: subDomain,
      stackTrace: stackTrace,
      level: level,
    );
  }
}
