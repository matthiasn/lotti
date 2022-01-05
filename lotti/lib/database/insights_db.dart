import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'insights_db.g.dart';

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

@DriftDatabase(
  include: {'insights_db.drift'},
)
class InsightsDb extends _$InsightsDb {
  InsightsDb() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> logInsight(Insight insight) async {
    return into(insights).insert(insight);
  }

  Future<void> captureEvent(
    dynamic event, {
    String domain = '',
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) async {
    logInsight(Insight(
      id: uuid.v1(),
      createdAt: DateTime.now().toIso8601String(),
      domain: domain,
      message: event.toString(),
      level: level.name.toUpperCase(),
      type: type.name.toUpperCase(),
    ));
  }

  Future<void> captureException(
    dynamic exception, {
    String domain = '',
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) async {
    logInsight(Insight(
      id: uuid.v1(),
      createdAt: DateTime.now().toIso8601String(),
      domain: domain,
      message: exception.toString(),
      stacktrace: stackTrace.toString(),
      level: level.name.toUpperCase(),
      type: type.name.toUpperCase(),
    ));
  }

  Stream<List<Insight>> watchInsights({
    int limit = 1000,
  }) {
    return allInsights(limit).watch();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'insights_db.sqlite'));
    return NativeDatabase(file);
  });
}
