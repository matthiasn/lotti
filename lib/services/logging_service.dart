import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
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
      await logDir.create(recursive: true);
      final fileName = 'lotti-${_dateFmt.format(DateTime.now())}.log';
      final file = File(p.join(logDir.path, fileName));
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
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

    // DB sink
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

    // File sink (best-effort)
    unawaited(_appendToFile(line));
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

    // DB sink
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

    // File sink (best-effort)
    unawaited(_appendToFile(line));
  }

  void captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) {
    debugPrint('EXCEPTION $domain $subDomain $exception $stackTrace');
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
