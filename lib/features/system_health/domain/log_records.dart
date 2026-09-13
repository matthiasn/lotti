import 'package:lotti/services/logging_domains.dart';

/// One entry parsed from a domain, sync or error log file.
///
/// Lines that do not open with an ISO timestamp — stack frames, diagnostics
/// dumps — belong to the entry above them and are collected in
/// [continuation].
class LogRecord {
  const LogRecord({
    required this.timestamp,
    required this.level,
    required this.domain,
    required this.message,
    this.subDomain,
    this.continuation = const [],
  });

  final DateTime timestamp;

  /// `ERROR`, `WARN` or `INFO`, exactly as written in the file.
  final String level;
  final LogDomain domain;
  final String? subDomain;
  final String message;
  final List<String> continuation;

  bool get isError => level == 'ERROR';
  bool get isWarning => level == 'WARN';
}

/// One entry parsed from `slow_queries-*.log` or `super_slow_queries-*.log`.
class SlowQueryRecord {
  const SlowQueryRecord({
    required this.timestamp,
    required this.databaseName,
    required this.operation,
    required this.elapsedMs,
    required this.statement,
    required this.isSuperSlow,
    this.planRows = const [],
    this.stackFrames = const [],
    this.inFlightAtStart,
    this.openTransactionsAtStart,
  });

  final DateTime timestamp;
  final String databaseName;
  final String operation;
  final double elapsedMs;
  final String statement;

  /// True for entries read from the super-slow file, which carries
  /// `EXPLAIN QUERY PLAN` rows and application stack frames.
  final bool isSuperSlow;
  final List<String> planRows;
  final List<String> stackFrames;

  /// Statements already awaiting the interceptor when this one started, from
  /// the `TIMING:` row. Null for entries written without timing bookkeeping.
  ///
  /// Elapsed time is measured from the moment drift accepts a request, so a
  /// statement that waited in a queue reports the wait as its own cost; this
  /// is the queue's depth at that moment.
  final int? inFlightAtStart;

  /// Transactions already open on the database when this statement started,
  /// from the `TRANSACTION:` row's `activeAtStart` list. Zero when the row was
  /// omitted (the interceptor writes it only when there was something to
  /// say), null when there was no timing bookkeeping at all.
  ///
  /// For a `BEGIN` this is what the transaction waited behind: drift holds the
  /// writer lock for a transaction's whole lifetime, so the next one waits.
  final int? openTransactionsAtStart;
}
