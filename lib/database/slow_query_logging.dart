import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

typedef SlowQueryReporter = void Function(SlowQueryLogEntry entry);

/// Structured metadata for a slow query observed through drift.
class SlowQueryLogEntry {
  const SlowQueryLogEntry({
    required this.databaseName,
    required this.operation,
    required this.statement,
    required this.arguments,
    required this.elapsed,
  });

  final String databaseName;
  final String operation;
  final String statement;
  final List<Object?> arguments;
  final Duration elapsed;

  String get formattedStatement =>
      statement.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Logs queries whose execution time crosses [threshold].
///
/// Drift's `QueryInterceptor` API wraps every executor method, which makes it a
/// good place to capture database-wide timings without changing individual DAOs
/// or query call sites.
class SlowQueryInterceptor extends QueryInterceptor {
  SlowQueryInterceptor({
    required this.databaseName,
    required this.threshold,
    required this.reporter,
  });

  final String databaseName;
  final Duration threshold;
  final SlowQueryReporter reporter;

  static SlowQueryReporter fileReporter({
    required String documentsDirectoryPath,
    String fileStem = 'slow_queries',
  }) {
    return (entry) {
      final elapsedMs =
          entry.elapsed.inMicroseconds / Duration.microsecondsPerMillisecond;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final logFile = File(
        p.join(documentsDirectoryPath, 'logs', '$fileStem-$date.log'),
      );
      final line =
          '${DateTime.now().toIso8601String()} '
          '[${entry.databaseName}] ${entry.operation} '
          '${elapsedMs.toStringAsFixed(3)}ms '
          'args=${entry.arguments.length} '
          '${entry.formattedStatement}';
      _SlowQueryFileSink.instance.append(logFile, line);
    };
  }

  static SlowQueryReporter devLoggerReporter() {
    return (entry) {
      DevLogger.warning(
        name: 'DB_SLOW_QUERY',
        message:
            '[${entry.databaseName}] ${entry.operation} '
            '${entry.elapsed.inMicroseconds / Duration.microsecondsPerMillisecond}ms '
            'args=${entry.arguments.length} '
            '${entry.formattedStatement}',
      );
    };
  }

  @visibleForTesting
  static Future<void> flushFileSinkForTest() {
    return _SlowQueryFileSink.instance.flushAll();
  }

  Future<T> _measure<T>({
    required String operation,
    required String statement,
    required List<Object?> arguments,
    required Future<T> Function() run,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await run();
    } finally {
      stopwatch.stop();
      if (stopwatch.elapsed >= threshold) {
        reporter(
          SlowQueryLogEntry(
            databaseName: databaseName,
            operation: operation,
            statement: statement,
            arguments: arguments,
            elapsed: stopwatch.elapsed,
          ),
        );
      }
    }
  }

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    final statementCount = statements.arguments.length;
    final preview = statements.statements.isEmpty
        ? '<empty batch>'
        : statements.statements.first;
    final allArguments = statements.arguments
        .expand((statement) => statement.arguments)
        .toList(growable: false);

    return _measure(
      operation: 'batch[$statementCount]',
      statement: preview,
      arguments: allArguments,
      run: () => executor.runBatched(statements),
    );
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _measure(
      operation: 'custom',
      statement: statement,
      arguments: args,
      run: () => executor.runCustom(statement, args),
    );
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _measure(
      operation: 'delete',
      statement: statement,
      arguments: args,
      run: () => executor.runDelete(statement, args),
    );
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _measure(
      operation: 'insert',
      statement: statement,
      arguments: args,
      run: () => executor.runInsert(statement, args),
    );
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _measure(
      operation: 'select',
      statement: statement,
      arguments: args,
      run: () => executor.runSelect(statement, args),
    );
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _measure(
      operation: 'update',
      statement: statement,
      arguments: args,
      run: () => executor.runUpdate(statement, args),
    );
  }
}

class _SlowQueryFileSink {
  _SlowQueryFileSink._();

  static final _SlowQueryFileSink instance = _SlowQueryFileSink._();

  final Map<String, Future<void>> _pendingWritesByPath =
      <String, Future<void>>{};

  void append(File file, String line) {
    final path = file.path;
    final current = _pendingWritesByPath[path] ?? Future<void>.value();
    final next = current.then((_) async {
      try {
        await file.parent.create(recursive: true);
        await file.writeAsString('$line\n', mode: FileMode.append);
      } catch (error, stackTrace) {
        DevLogger.error(
          name: 'DB_SLOW_QUERY',
          message: 'Failed to append slow query log line',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });

    _pendingWritesByPath[path] = next.whenComplete(() {
      if (identical(_pendingWritesByPath[path], next)) {
        _pendingWritesByPath.remove(path);
      }
    });
  }

  Future<void> flushAll() async {
    await Future.wait(_pendingWritesByPath.values.toList(growable: false));
  }
}
