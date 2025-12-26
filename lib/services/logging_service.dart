import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:path/path.dart' as p;

class LoggingService {
  bool _enableLogging = !isTestEnv;
  final _dateFmt = DateFormat('yyyy-MM-dd');

  void listenToConfigFlag() {
    getIt<JournalDb>().watchConfigFlag(enableLoggingFlag).listen((value) {
      _enableLogging = value;
    });
  }

  // --- Text file sink -----------------------------------------------------
  Future<void> _appendToFile(String line) async {
    try {
      final dir = getDocumentsDirectory();
      final logDir = Directory(p.join(dir.path, 'logs'));
      final fileName = 'lotti-${_dateFmt.format(DateTime.now())}.log';
      final file = File(p.join(logDir.path, fileName));
      if (isTestEnv) {
        // Synchronous in tests to avoid timing flakes under parallel runners.
        if (!logDir.existsSync()) {
          logDir.createSync(recursive: true);
        }
        file.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
      } else {
        await logDir.create(recursive: true);
        await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
      }
    } catch (_) {
      // Swallow file-sink errors so logging never interferes with app flows.
    }
  }

  String _formatLine({
    required DateTime ts,
    required String level,
    required String domain,
    required String message,
    String? subDomain,
  }) {
    final t = ts.toIso8601String();
    final sd = (subDomain == null || subDomain.isEmpty) ? '' : ' $subDomain';
    return '$t [$level] $domain$sd: $message';
  }

  Future<void> _captureEventAsync(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) async {
    final now = DateTime.now();
    final line = _formatLine(
      ts: now,
      level: level.name.toUpperCase(),
      domain: domain,
      subDomain: subDomain,
      message: event.toString(),
    );

    // DB sink (best-effort). Never throw from logging paths.
    try {
      await getIt<LoggingDb>().log(
        LogEntry(
          id: uuid.v1(),
          createdAt: now.toIso8601String(),
          domain: domain,
          subDomain: subDomain,
          message: event.toString(),
          level: level.name.toUpperCase(),
          type: type.name.toUpperCase(),
        ),
      );
    } catch (e, st) {
      // Swallow DB-sink errors to avoid interfering with app flows, but capture
      // a compact breadcrumb to aid root-cause analysis of SQLITE_CANTOPEN (14)
      try {
        // Avoid path_provider during tests; prefer injected documents directory.
        final doc = getDocumentsDirectory();
        final tmp = Directory.systemTemp;
        final diag =
            'logging.db.write.failed err=$e docDir=${doc.path} tmpDir=${tmp.path}';
        final line = _formatLine(
          ts: now,
          level: InsightLevel.error.name.toUpperCase(),
          domain: 'LOGGING_DB',
          subDomain: 'event.write',
          message: diag,
        );
        unawaited(_appendToFile(line));
      } catch (fileErr, fileSt) {
        // Last resort: surface both the original DB error and the fallback
        // file error to the console so bootstrap failures are not invisible.
        DevLogger.error(
          name: 'LoggingService',
          message: 'CRITICAL: Logging fallback failed!',
        );
        DevLogger.error(
          name: 'LoggingService',
          message: 'Original DB error',
          error: e,
        );
        DevLogger.error(
          name: 'LoggingService',
          message: 'Fallback file error',
          error: fileErr,
          stackTrace: fileSt,
        );
      }
      // Also log to DevLogger
      DevLogger.error(
        name: 'LoggingService',
        message: 'LOGGING_DB event.write failed',
        error: e,
        stackTrace: st,
      );
    }

    // File sink (best-effort). Await to ensure ordering and determinism.
    await _appendToFile(line);
  }

  void captureEvent(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) {
    if (!_enableLogging) {
      return;
    }
    _captureEventAsync(
      event,
      domain: domain,
      subDomain: subDomain,
      level: level,
      type: type,
    );
  }

  Future<void> _captureExceptionAsync(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) async {
    final now = DateTime.now();
    final line = _formatLine(
      ts: now,
      level: level.name.toUpperCase(),
      domain: domain,
      subDomain: subDomain,
      message: '$exception ${stackTrace ?? ''}'.trim(),
    );

    // DB sink (best-effort). Never throw from logging paths.
    try {
      await getIt<LoggingDb>().log(
        LogEntry(
          id: uuid.v1(),
          createdAt: now.toIso8601String(),
          domain: domain,
          subDomain: subDomain,
          message: exception.toString(),
          stacktrace: stackTrace?.toString(),
          level: level.name.toUpperCase(),
          type: type.name.toUpperCase(),
        ),
      );
    } catch (e, st2) {
      try {
        final doc = getDocumentsDirectory();
        final tmp = Directory.systemTemp;
        final diag =
            'logging.db.exception.failed err=$e docDir=${doc.path} tmpDir=${tmp.path}';
        final line = _formatLine(
          ts: now,
          level: InsightLevel.error.name.toUpperCase(),
          domain: 'LOGGING_DB',
          subDomain: 'exception.write',
          message: diag,
        );
        unawaited(_appendToFile(line));
      } catch (fileErr, fileSt) {
        DevLogger.error(
          name: 'LoggingService',
          message: 'CRITICAL: Logging fallback failed!',
        );
        DevLogger.error(
          name: 'LoggingService',
          message: 'Original DB error',
          error: e,
        );
        DevLogger.error(
          name: 'LoggingService',
          message: 'Fallback file error',
          error: fileErr,
          stackTrace: fileSt,
        );
      }
      DevLogger.error(
        name: 'LoggingService',
        message: 'LOGGING_DB exception.write failed',
        error: e,
        stackTrace: st2,
      );
    }

    // File sink (best-effort). Await to ensure ordering and determinism.
    await _appendToFile(line);
  }

  void captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) {
    DevLogger.error(
      name: 'LoggingService',
      message: 'EXCEPTION $domain ${subDomain ?? ''}',
      error: exception,
      stackTrace: stackTrace is StackTrace ? stackTrace : null,
    );
    _captureExceptionAsync(
      exception,
      domain: domain,
      subDomain: subDomain,
      stackTrace: stackTrace,
      level: level,
      type: type,
    );
  }
}
