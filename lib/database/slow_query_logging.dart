import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:lotti/services/dev_logger.dart';
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
  /// Transactions additionally capture their origin when each transaction is
  /// created, so repeated transactions retain distinct initiating call sites.
  /// Off by default because capturing stack traces adds diagnostic overhead.
  static bool captureFirstCallStack = false;

  /// Internal set of statements already traced for this process.
  static final Set<String> _seenStatements = <String>{};

  /// Returns true the first time [statement] is observed during this
  /// process; false on every subsequent call. Used by the interceptor
  /// to gate one-shot stack capture.
  static bool markStatementSeenAndIsFirst(String statement) {
    return _seenStatements.add(statement);
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
    this.startedAt,
    this.completedAt,
    this.inFlightAtStart,
    this.scope = 'executorAwait',
    this.transactionId,
    this.parentTransactionId,
    this.activeTransactionIdsAtStart,
  });

  final String databaseName;
  final String operation;
  final String statement;
  final List<Object?> arguments;

  /// Awaited executor duration, including scheduling and isolate transport,
  /// or acknowledged transaction lifetime as identified by [scope]. Neither
  /// measures native SQLite execution alone.
  final Duration elapsed;

  /// Wall-clock bounds around the executor await (before EXPLAIN), or the
  /// opening and ending acknowledgements for a transaction lifetime.
  /// Optional for manually constructed and logging-disabled entries.
  final DateTime? startedAt;
  final DateTime? completedAt;

  /// Calls awaiting this interceptor's executor when this call started,
  /// including this call. This is observed concurrency, not a queue length.
  final int? inFlightAtStart;

  /// Identifies executor awaits versus the observed lifetime of a transaction.
  /// Neither scope measures native SQLite execution or exact lock hold time.
  final String scope;

  /// IDs local to this interceptor, correlated by database and timing bounds.
  final int? transactionId;
  final int? parentTransactionId;

  /// Transactions whose opening acknowledgement has arrived but whose end has
  /// not been acknowledged when this operation starts. Overlap is not proof
  /// that these transactions blocked the operation (read pools may bypass it).
  final List<int>? activeTransactionIdsAtStart;

  /// True when the query exceeded the interceptor's super-slow threshold and
  /// should be replicated to the dedicated super-slow log file.
  final bool isSuperSlow;

  /// `EXPLAIN QUERY PLAN` rows captured for super-slow selects, formatted as
  /// `'id|parent|detail'`. Null for non-select operations or when capture
  /// failed.
  final List<String>? queryPlan;

  /// First-invocation statement stack, or the initiating stack for this
  /// transaction's opening and lifetime, when
  /// [SlowQueryLoggingGate.captureFirstCallStack] is enabled.
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
  int _inFlight = 0;
  int _nextTransactionId = 0;
  final _transactions = Map<QueryExecutor, _ObservedTransaction>.identity();

  List<int> _activeTransactionIds() => [
    for (final tx in _transactions.values)
      if (tx.lifetime != null) tx.id,
  ];

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    final executor = parent.beginTransaction();
    if (SlowQueryLoggingGate.isEnabled) {
      _transactions[executor] = _ObservedTransaction(
        id: ++_nextTransactionId,
        parentId: _transactions[parent]?.id,
        callerStack: SlowQueryLoggingGate.captureFirstCallStack
            ? StackTrace.current
            : null,
      );
    }
    return executor;
  }

  @override
  Future<bool> ensureOpen(
    QueryExecutor executor,
    QueryExecutorUser user,
  ) async {
    final tx = _transactions[executor];
    if (tx == null || tx.openRequested) {
      return executor.ensureOpen(user);
    }
    tx.openRequested = true;
    try {
      return await _measure(
        executor: executor,
        operation: 'transaction.open',
        statement: 'BEGIN',
        arguments: const [],
        callerStackOverride: tx.callerStack,
        run: () async {
          final opened = await executor.ensureOpen(user);
          tx
            ..openedAt = clock.now()
            ..lifetime = (Stopwatch()..start())
            ..activeIdsAtOpen = _activeTransactionIds();
          return opened;
        },
      );
    } catch (_) {
      _transactions.remove(executor);
      rethrow;
    }
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await _measure(
      executor: inner,
      operation: 'transaction.commit',
      statement: 'COMMIT',
      arguments: const [],
      run: inner.send,
    );
    // Drift retains the transaction after a failed commit so it can roll back.
    _finishTransaction(inner, 'COMMIT');
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    var succeeded = false;
    try {
      await _measure(
        executor: inner,
        operation: 'transaction.rollback',
        statement: 'ROLLBACK',
        arguments: const [],
        run: inner.rollback,
      );
      succeeded = true;
    } finally {
      // Drift releases remote transactions even when rollback throws.
      _finishTransaction(inner, succeeded ? 'ROLLBACK' : 'ROLLBACK_FAILED');
    }
  }

  void _finishTransaction(QueryExecutor executor, String outcome) {
    final tx = _transactions.remove(executor);
    final lifetime = tx?.lifetime;
    if (tx == null || lifetime == null) return;
    lifetime.stop();
    if (!SlowQueryLoggingGate.isEnabled || lifetime.elapsed < threshold) return;
    _reportSafely(
      SlowQueryLogEntry(
        databaseName: databaseName,
        operation: 'transaction',
        statement: outcome,
        arguments: const [],
        elapsed: lifetime.elapsed,
        scope: 'transactionLifetime',
        isSuperSlow: lifetime.elapsed >= superSlowThreshold,
        startedAt: tx.openedAt,
        completedAt: clock.now(),
        transactionId: tx.id,
        parentTransactionId: tx.parentId,
        activeTransactionIdsAtStart: tx.activeIdsAtOpen,
        callerStack: tx.callerStack,
      ),
    );
  }

  void _reportSafely(SlowQueryLogEntry entry) {
    try {
      reporter(entry);
    } catch (error, stackTrace) {
      // Observability must never turn a successful BEGIN/COMMIT into an
      // apparent failure, or hide the original database exception.
      DevLogger.error(
        name: 'DB_SLOW_QUERY',
        message: 'Failed to report database timing',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

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
      final date = DateFormat('yyyy-MM-dd').format(clock.now());
      final logFile = File(
        p.join(documentsDirectoryPath, 'logs', '$fileStem-$date.log'),
      );
      final line =
          '${clock.now().toIso8601String()} '
          '[${entry.databaseName}] ${entry.operation} '
          '${elapsedMs.toStringAsFixed(3)}ms '
          'args=${entry.arguments.length} '
          '${entry.formattedStatement}'
          '${entry.startedAt == null ? '' : '\n  TIMING: scope=${entry.scope} '
                    'started=${entry.startedAt!.toIso8601String()} '
                    'completed=${entry.completedAt?.toIso8601String()} '
                    'inFlightAtStart=${entry.inFlightAtStart}'}'
          '${entry.transactionId == null && (entry.activeTransactionIdsAtStart?.isEmpty ?? true) ? '' : '\n  TRANSACTION: id=${entry.transactionId} '
                    'parent=${entry.parentTransactionId} '
                    'activeAtStart=${entry.activeTransactionIdsAtStart}'}';
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

  /// Waits for all queued slow-query file writes to reach disk.
  ///
  /// The app shutdown path calls this alongside the general logging flush so
  /// slow-query diagnostics are not lost when the process exits immediately.
  static Future<void> flushPendingFileWrites() {
    return _SlowQueryFileSink.instance.flushAll();
  }

  Future<T> _measure<T>({
    required QueryExecutor executor,
    required String operation,
    required String statement,
    required List<Object?> arguments,
    required Future<T> Function() run,
    Future<List<String>> Function()? capturePlan,
    StackTrace? callerStackOverride,
  }) async {
    // Capture the caller stack BEFORE awaiting `run()`. By the time
    // the interceptor reports, drift's executor is deep in the call
    // stack and the originating frames have been suspended; capturing
    // here keeps the frames that show which provider / widget kicked
    // off the query. Gated to one capture per unique statement so the
    // diagnostic is one-shot.
    var callerStack = callerStackOverride;
    if (callerStack == null &&
        SlowQueryLoggingGate.captureFirstCallStack &&
        SlowQueryLoggingGate.markStatementSeenAndIsFirst(statement)) {
      callerStack = StackTrace.current;
    }
    final startedAt = SlowQueryLoggingGate.isEnabled ? clock.now() : null;
    final tx = _transactions[executor];
    final activeIds = startedAt == null ? null : _activeTransactionIds();
    final inFlightAtStart = ++_inFlight;
    final stopwatch = Stopwatch()..start();
    try {
      return await run();
    } finally {
      stopwatch.stop();
      final completedAt = startedAt == null ? null : clock.now();
      _inFlight--;
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
        _reportSafely(
          SlowQueryLogEntry(
            databaseName: databaseName,
            operation: operation,
            statement: statement,
            arguments: arguments,
            elapsed: elapsed,
            isSuperSlow: isSuperSlow,
            queryPlan: queryPlan,
            callerStack: callerStack,
            startedAt: startedAt,
            completedAt: completedAt,
            inFlightAtStart: inFlightAtStart,
            transactionId: tx?.id,
            parentTransactionId: tx?.parentId,
            activeTransactionIdsAtStart: activeIds,
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
      executor: executor,
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
      executor: executor,
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
      executor: executor,
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
      executor: executor,
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
      executor: executor,
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
      executor: executor,
      operation: 'update',
      statement: statement,
      arguments: args,
      run: () => executor.runUpdate(statement, args),
    );
  }
}

class _ObservedTransaction {
  _ObservedTransaction({
    required this.id,
    required this.parentId,
    this.callerStack,
  });

  final int id;
  final int? parentId;
  final StackTrace? callerStack;
  bool openRequested = false;
  DateTime? openedAt;
  Stopwatch? lifetime;
  List<int>? activeIdsAtOpen;
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

  Future<void> flushAll() async {
    await Future.wait(_pendingWritesByPath.values.toList(growable: false));
  }
}
