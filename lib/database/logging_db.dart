import 'dart:async';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';

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

  Future<int> log(LogEntry logEntry) async {
    return into(logEntries).insert(logEntry);
  }

  Stream<List<LogEntry>> watchLogEntryById(String id) {
    return logEntryById(id).watch();
  }

  Stream<List<LogEntry>> watchLogEntries({
    int limit = 1000,
  }) {
    return allLogEntries(limit).watch();
  }
}
