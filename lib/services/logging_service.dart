import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/platform.dart';

class LoggingService {
  bool _enableLogging = !isTestEnv;

  void listenToConfigFlag() {
    getIt<JournalDb>().watchConfigFlag(enableLoggingFlag).listen((value) {
      _enableLogging = value;
    });
  }

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
    await getIt<LoggingDb>().log(
      LogEntry(
        id: uuid.v1(),
        createdAt: DateTime.now().toIso8601String(),
        domain: domain,
        subDomain: subDomain,
        message: exception.toString(),
        stacktrace: stackTrace.toString(),
        level: level.name.toUpperCase(),
        type: type.name.toUpperCase(),
      ),
    );
  }

  void captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) {
    if (!_enableLogging) {
      return;
    }
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
