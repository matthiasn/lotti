import 'dart:async';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/stream_helpers.dart';
import 'package:lotti/utils/file_utils.dart';

part 'logging_db.g.dart';

const loggingDbFileName = 'logging_db.sqlite';

enum InsightLevel {
  error,
  warn,
  info,
  trace,
}

enum InsightType {
  log,
  exception,
}

@DriftDatabase(include: {'logging_db.drift'})
class LoggingDb extends _$LoggingDb {
  LoggingDb({this.inMemoryDatabase = false})
      : super(
          openDbConnection(
            loggingDbFileName,
            inMemoryDatabase: inMemoryDatabase,
          ),
        );

  LoggingDb.connect(super.connection) : super.connect();

  bool inMemoryDatabase = false;

  @override
  int get schemaVersion => 1;

  Future<int> _logAsync(LogEntry logEntry) async {
    return into(logEntries).insert(logEntry);
  }

  void log(LogEntry logEntry) {
    unawaited(_logAsync(logEntry));
  }

  Future<void> _captureEventAsync(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) async {
    log(
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
    unawaited(
      _captureEventAsync(
        event,
        domain: domain,
        subDomain: subDomain,
        level: level,
        type: type,
      ),
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
    log(
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
    _captureExceptionAsync(
      exception,
      domain: domain,
      subDomain: subDomain,
      stackTrace: stackTrace,
      level: level,
      type: type,
    );
  }

  Stream<List<LogEntry>> watchLogEntryById(String id) {
    return logEntryById(id).watch().where(makeDuplicateFilter());
  }

  Stream<List<LogEntry>> watchLogEntries({
    int limit = 1000,
  }) {
    return allLogEntries(limit).watch();
  }
}

LoggingDb getLoggingDb() {
  return LoggingDb.connect(getDatabaseConnection(loggingDbFileName));
}
