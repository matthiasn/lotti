import 'package:lotti/services/logging_domains.dart';

/// Repeated log entries collapsed to one signature.
class LogIssueBucket {
  const LogIssueBucket({
    required this.domain,
    required this.level,
    required this.signature,
    required this.count,
    required this.firstSeen,
    required this.lastSeen,
    required this.sample,
    this.subDomain,
    this.sampleFrames = const [],
  });

  final LogDomain domain;
  final String level;
  final String? subDomain;

  /// Normalised message with volatile fragments replaced, used to group.
  final String signature;
  final int count;
  final DateTime firstSeen;
  final DateTime lastSeen;

  /// The first redacted message that landed in this bucket.
  final String sample;

  /// Application stack frames from the first entry, if any were logged.
  final List<String> sampleFrames;
}

/// Queue depth seen by the statements in a bucket when they started.
///
/// Elapsed time in the slow-query log is measured from the moment drift
/// accepts a request, so a statement that queued behind others reports the
/// wait as its own cost. These counters say how deep that queue was.
class QueueDepthStats {
  const QueueDepthStats({
    required this.inFlightP50,
    required this.inFlightMax,
    required this.openTransactionsP50,
    required this.openTransactionsMax,
  });

  /// Statements already awaiting the interceptor.
  final int inFlightP50;
  final int inFlightMax;

  /// Transactions already open on the database — what a `BEGIN` waits behind.
  final int openTransactionsP50;
  final int openTransactionsMax;
}

/// Repeated slow queries collapsed to one normalised statement.
class SlowQueryBucket {
  const SlowQueryBucket({
    required this.databaseName,
    required this.statement,
    required this.operation,
    required this.count,
    required this.superSlowCount,
    required this.p50Ms,
    required this.p95Ms,
    required this.maxMs,
    required this.totalMs,
    required this.firstSeen,
    required this.lastSeen,
    this.planShapes = const [],
    this.topFrames = const [],
    this.queueDepth,
  });

  /// The database file the statement ran against. Part of the grouping key:
  /// a `BEGIN` on the agent database and one on the sync database queue
  /// behind different writer locks and must not share a row.
  final String databaseName;
  final String statement;
  final String operation;
  final int count;
  final int superSlowCount;
  final double p50Ms;
  final double p95Ms;
  final double maxMs;
  final double totalMs;
  final DateTime firstSeen;
  final DateTime lastSeen;

  /// Distinct `EXPLAIN QUERY PLAN` shapes seen for the statement.
  final List<String> planShapes;

  /// Distinct application frames that issued the statement — the first frame
  /// below the transaction and vector-clock wrappers, so a `BEGIN` names the
  /// code that opened the transaction rather than `runInTransaction`.
  final List<String> topFrames;

  /// Null when no entry in the bucket carried timing bookkeeping.
  final QueueDepthStats? queueDepth;
}

/// Per-domain line counts by level.
class DomainCounts {
  const DomainCounts({
    required this.domain,
    required this.errors,
    required this.warnings,
    required this.infos,
  });

  final LogDomain domain;
  final int errors;
  final int warnings;
  final int infos;

  int get total => errors + warnings + infos;
}

/// A minute in which the error rate spiked well above the window's average.
class ErrorBurst {
  const ErrorBurst({required this.minute, required this.count});

  final DateTime minute;
  final int count;
}

/// The aggregated, redacted view of the selected logs.
///
/// This is what the report renders and what the model receives. Nothing in
/// it is a raw log line; every message went through the redactor first.
class LogDigest {
  const LogDigest({
    required this.domainCounts,
    required this.issues,
    required this.slowQueries,
    required this.errorBursts,
    required this.filesRead,
    required this.linesRead,
    required this.slowQueryCount,
    required this.superSlowQueryCount,
    required this.truncated,
  });

  final List<DomainCounts> domainCounts;

  /// Error and warning buckets, most frequent first.
  final List<LogIssueBucket> issues;

  /// Slow-query buckets, most total time first.
  final List<SlowQueryBucket> slowQueries;
  final List<ErrorBurst> errorBursts;
  final int filesRead;
  final int linesRead;
  final int slowQueryCount;
  final int superSlowQueryCount;

  /// True when the size budget dropped lower-priority buckets.
  final bool truncated;

  int get errorCount =>
      domainCounts.fold(0, (sum, counts) => sum + counts.errors);
  int get warningCount =>
      domainCounts.fold(0, (sum, counts) => sum + counts.warnings);
  bool get isEmpty =>
      issues.isEmpty && slowQueries.isEmpty && domainCounts.isEmpty;
}
