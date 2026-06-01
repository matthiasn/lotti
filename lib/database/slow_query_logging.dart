import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

typedef SlowQueryReporter = void Function(SlowQueryLogEntry entry);

/// Runtime gate for slow-query file logging.
///
/// The interceptor is installed on every Drift connection, but the actual
/// write path is opt-in and controlled by the same advanced logging settings
/// used for other domains.
abstract final class SlowQueryLoggingGate {
  static bool isEnabled = false;

  /// Default cutoff above which a slow query is also classified as
  /// "super slow": EXPLAIN QUERY PLAN is captured and the entry is duplicated
  /// to a dedicated daily log file. Constructor-injected on the interceptor
  /// so tests can force every query down the super-slow path.
  static const Duration defaultSuperSlowThreshold = Duration(milliseconds: 200);

  /// One-shot diagnostic: when true, the slow-query interceptor captures
  /// `StackTrace.current` at the moment each *unique* statement first
  /// fires and attaches it to the log entry. Subsequent occurrences of
  /// the same statement do **not** capture again, so the boot wave
  /// produces one trace per unique query shape — exactly what we need
  /// to identify which Riverpod provider / widget mounted each fetch.
  /// Off by default because capturing stack traces costs a few hundred
  /// microseconds per first call.
  static bool captureFirstCallStack = false;

  /// Internal set of statements already traced. Cleared by
  /// [resetForTest] so each test starts with an empty seen-set.
  static final Set<String> _seenStatements = <String>{};

  /// Returns true the first time [statement] is observed during this
  /// process; false on every subsequent call. Used by the interceptor
  /// to gate one-shot stack capture.
  static bool markStatementSeenAndIsFirst(String statement) {
    return _seenStatements.add(statement);
  }

  @visibleForTesting
  static void resetForTest() {
    isEnabled = false;
    captureFirstCallStack = false;
    _seenStatements.clear();
  }
}

/// Structured metadata for a slow query observed through drift.
class SlowQueryLogEntry {
  const SlowQueryLogEntry({
    required this.databaseName,
    required this.operation,
    required this.statement,
    required this.arguments,
    required this.elapsed,
    this.isSuperSlow = false,
    this.queryPlan,
    this.callerStack,
  });

  final String databaseName;
  final String operation;
  final String statement;
  final List<Object?> arguments;
  final Duration elapsed;

  /// True when the query exceeded the interceptor's super-slow threshold and
  /// should be replicated to the dedicated super-slow log file.
  final bool isSuperSlow;

  /// `EXPLAIN QUERY PLAN` rows captured for super-slow selects, formatted as
  /// `'id|parent|detail'`. Null for non-select operations or when capture
  /// failed.
  final List<String>? queryPlan;

  /// Stack trace captured at the *first* invocation of this statement
  /// when [SlowQueryLoggingGate.captureFirstCallStack] is enabled. Lets
  /// us pinpoint the Riverpod provider / widget that originates each
  /// boot-wave query. Null on subsequent invocations or when capture is
  /// disabled.
  final StackTrace? callerStack;

  String get formattedStatement =>
      statement.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Logs queries whose execution time crosses [threshold].
///
/// Drift's `QueryInterceptor` API wraps every executor method, which makes it a
/// good place to capture database-wide timings without changing individual DAOs
/// or query call sites. The interceptor is always installed, but actual writes
/// are gated behind [SlowQueryLoggingGate] so slow-query logging can stay off
/// by default and be enabled from advanced logging settings.
class SlowQueryInterceptor extends QueryInterceptor {
  SlowQueryInterceptor({
    required this.databaseName,
    required this.threshold,
    required this.reporter,
    this.superSlowThreshold = SlowQueryLoggingGate.defaultSuperSlowThreshold,
  });

  final String databaseName;
  final Duration threshold;
  final SlowQueryReporter reporter;

  /// Queries whose elapsed time crosses this threshold also have their
  /// `EXPLAIN QUERY PLAN` captured (selects only) and are duplicated to the
  /// super-slow log file. Set to `Duration.zero` from tests to force every
  /// reported query down the super-slow path.
  final Duration superSlowThreshold;

  static SlowQueryReporter fileReporter({
    required String documentsDirectoryPath,
    String fileStem = 'slow_queries',
    String superFileStem = 'super_slow_queries',
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

      if (entry.isSuperSlow) {
        final superLogFile = File(
          p.join(documentsDirectoryPath, 'logs', '$superFileStem-$date.log'),
        );
        // Plan rows render as indented lines under the query so a single
        // logical entry occupies one query line + N plan lines in the file.
        final planRows = entry.queryPlan;
        final stack = entry.callerStack;
        final buf = StringBuffer(line);
        if (planRows != null && planRows.isNotEmpty) {
          for (final row in planRows) {
            buf
              ..write('\n  PLAN: ')
              ..write(row);
          }
        }
        if (stack != null) {
          // Trim drift / async-runtime frames so only application
          // frames make it into the log. The first ~10 frames of every
          // capture were the same drift `LazyDatabase`, async-runtime
          // and `_rootRunUnary` boilerplate; they made the super-slow
          // log unreadable without telling us anything new. Keep frames
          // that point at app code (`package:lotti/...`) and drop
          // everything else, including the `<asynchronous suspension>`
          // separators between them.
          final lines = stack.toString().split('\n');
          for (final stackLine in lines) {
            final trimmed = stackLine.trimRight();
            if (trimmed.isEmpty) continue;
            // App-code frames look like:
            //   "#10     JournalDb.getAllDashboards (package:lotti/...:n:m)"
            // Drift / dart-runtime / riverpod / matrix frames (and the
            // `<asynchronous suspension>` markers) all lack
            // `package:lotti/`. The interceptor + the slow-query
            // logger itself sit in `package:lotti/database/...` so we
            // also drop frames pointing at the slow-query plumbing
            // since they are constant per entry.
            if (!trimmed.contains('package:lotti/')) continue;
            if (trimmed.contains('package:lotti/database/slow_query_logging')) {
              continue;
            }
            buf
              ..write('\n  STACK: ')
              ..write(trimmed);
          }
        }
        _SlowQueryFileSink.instance.append(superLogFile, buf.toString());
      }
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

  /// Number of paths with an in-flight (or not-yet-cleaned-up) chained write.
  ///
  /// Exposed only so tests can assert that completed writes are removed from
  /// the per-path tracking map instead of leaking forever.
  @visibleForTesting
  static int get pendingWriteCountForTest =>
      _SlowQueryFileSink.instance.pendingWriteCount;

  Future<T> _measure<T>({
    required String operation,
    required String statement,
    required List<Object?> arguments,
    required Future<T> Function() run,
    Future<List<String>> Function()? capturePlan,
  }) async {
    // Capture the caller stack BEFORE awaiting `run()`. By the time
    // the interceptor reports, drift's executor is deep in the call
    // stack and the originating frames have been suspended; capturing
    // here keeps the frames that show which provider / widget kicked
    // off the query. Gated to one capture per unique statement so the
    // diagnostic is one-shot.
    StackTrace? callerStack;
    if (SlowQueryLoggingGate.captureFirstCallStack &&
        SlowQueryLoggingGate.markStatementSeenAndIsFirst(statement)) {
      callerStack = StackTrace.current;
    }
    final stopwatch = Stopwatch()..start();
    try {
      return await run();
    } finally {
      stopwatch.stop();
      final elapsed = stopwatch.elapsed;
      if (SlowQueryLoggingGate.isEnabled && elapsed >= threshold) {
        final isSuperSlow = elapsed >= superSlowThreshold;
        List<String>? queryPlan;
        if (isSuperSlow && capturePlan != null) {
          try {
            queryPlan = await capturePlan();
          } catch (error, stackTrace) {
            DevLogger.error(
              name: 'DB_SLOW_QUERY',
              message:
                  'Failed to capture EXPLAIN QUERY PLAN for super-slow query',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
        reporter(
          SlowQueryLogEntry(
            databaseName: databaseName,
            operation: operation,
            statement: statement,
            arguments: arguments,
            elapsed: elapsed,
            isSuperSlow: isSuperSlow,
            queryPlan: queryPlan,
            callerStack: callerStack,
          ),
        );
      }
    }
  }

  Future<List<String>> _captureQueryPlan(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(
      'EXPLAIN QUERY PLAN $statement',
      args,
    );
    return rows
        .map((row) {
          final id = row['id'];
          final parent = row['parent'];
          final detail = row['detail'];
          return '$id|$parent|$detail';
        })
        .toList(growable: false);
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
      capturePlan: () => _captureQueryPlan(executor, statement, args),
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

    late final Future<void> tracked;
    tracked = next.whenComplete(() {
      // Only drop the entry if no newer write has superseded this one. The
      // stored value and the compared value must be the SAME object, so we
      // compare against `tracked` (what we put in the map), not `next` (the
      // inner future, which is a distinct object after `whenComplete`).
      if (identical(_pendingWritesByPath[path], tracked)) {
        _pendingWritesByPath.remove(path);
      }
    });
    _pendingWritesByPath[path] = tracked;
  }

  int get pendingWriteCount => _pendingWritesByPath.length;

  Future<void> flushAll() async {
    await Future.wait(_pendingWritesByPath.values.toList(growable: false));
  }
}
