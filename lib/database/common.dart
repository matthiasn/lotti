import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/sync/matrix/timeline.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

Future<File> getDatabaseFile(String dbFileName) async {
  final dbFolder = getDocumentsDirectory();
  return File(p.join(dbFolder.path, dbFileName));
}

Future<void> createDbBackup(String fileName) async {
  final file = await getDatabaseFile(fileName);
  final ts = DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(DateTime.now());
  final backupDir =
      await Directory('${file.parent.path}/backup').create(recursive: true);
  await file.copy('${backupDir.path}/db.$ts.sqlite');
}

LazyDatabase openDbConnection(
  String fileName, {
  bool inMemoryDatabase = false,
}) {
  return LazyDatabase(() async {
    if (inMemoryDatabase) {
      return NativeDatabase.memory();
    }

    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, fileName));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

    final database = NativeDatabase.createInBackground(file);

    return database;
    //return kDebugMode ? database.interceptWith(LogInterceptor()) : database;
  });
}

class LogInterceptor extends QueryInterceptor {
  Future<T> _run<T>(
    String description,
    FutureOr<T> Function() operation,
  ) async {
    final startTime = DateTime.now();
    final stopwatch = Stopwatch()..start();

    try {
      final result = await operation();
      final duration = stopwatch.elapsedMilliseconds;
      if (duration > 100) {
        debugPrint(
          '$startTime ${description.truncate(500)} => took $duration ms',
        );
      }

      return result;
    } on Object catch (e) {
      debugPrint(
        '$description => failed after ${stopwatch.elapsedMilliseconds}ms ($e)',
      );
      rethrow;
    }
  }

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    debugPrint('begin');
    return super.beginTransaction(parent);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) {
    return _run('commit', () => inner.send());
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) {
    return _run('rollback', () => inner.rollback());
  }

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    return _run(
      'batch with $statements',
      () => executor.runBatched(statements),
    );
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _run(
      '$statement with $args',
      () => executor.runInsert(statement, args),
    );
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _run(
      '$statement with $args',
      () => executor.runUpdate(statement, args),
    );
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _run(
      '$statement with $args',
      () => executor.runDelete(statement, args),
    );
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _run(
      '$statement with $args',
      () => executor.runCustom(statement, args),
    );
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _run(
      '$statement with $args',
      () => executor.runSelect(statement, args),
    );
  }
}
