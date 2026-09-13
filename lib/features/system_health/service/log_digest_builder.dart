import 'dart:math' as math;

import 'package:lotti/features/system_health/domain/log_digest.dart';
import 'package:lotti/features/system_health/domain/log_records.dart';
import 'package:lotti/features/system_health/service/log_file_reader.dart';
import 'package:lotti/features/system_health/service/log_redactor.dart';
import 'package:lotti/services/logging_domains.dart';

/// Collapses parsed log records into the buckets a report is made of.
///
/// Redaction happens here, on every message and statement, before anything
/// is grouped — so the digest never holds a raw line. Grouping keys are the
/// redacted text with volatile fragments (numbers, ids, timestamps) replaced,
/// which is what turns ten thousand "wake failed in 18136ms for [id:95a30c]"
/// lines into one bucket with a count.
class LogDigestBuilder {
  const LogDigestBuilder({
    this.redactor = const LogRedactor(),
    this.maxIssues = 25,
    this.maxSlowQueries = 15,
    this.maxSampleFrames = 6,
    this.maxPlanShapes = 3,
    this.maxTopFrames = 3,
    this.maxErrorBursts = 3,
  });

  final LogRedactor redactor;
  final int maxIssues;
  final int maxSlowQueries;
  final int maxSampleFrames;
  final int maxPlanShapes;
  final int maxTopFrames;
  final int maxErrorBursts;

  static final RegExp _idPlaceholder = RegExp(r'\[id:[0-9a-fA-F]{1,6}\]');
  static final RegExp _isoTimestamp = RegExp(
    r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?',
  );
  static final RegExp _number = RegExp(r'\d+(?:\.\d+)?');
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _quotedLiteral = RegExp(r"'(?:[^'\\]|\\.)*'");
  static final RegExp _placeholderList = RegExp(r'\(\s*\?(?:\s*,\s*\?)+\s*\)');
  static final RegExp _appFrame = RegExp('package:lotti/');

  /// Frames that wrap a statement without being its reason: the agent
  /// repository's and sync service's `runInTransaction`, the vector-clock
  /// scope, and the transaction-marking zone helper. The first frame of every
  /// `BEGIN` is one of these, which attributes every transaction to the
  /// wrapper and none to the code that opened it.
  static final RegExp _wrapperFrame = RegExp(
    r'\b(runInTransaction|withVcScope|_markInTransaction)\b',
  );

  static const int _signatureLength = 200;

  LogDigest build(LogReadResult input) {
    final issueBuckets = _bucketIssues(input.records);
    final slowQueryBuckets = _bucketSlowQueries(input.slowQueries);
    final counts = _countByDomain(input);
    final bursts = _findErrorBursts(input.records);

    final truncated =
        issueBuckets.length > maxIssues ||
        slowQueryBuckets.length > maxSlowQueries;

    return LogDigest(
      domainCounts: counts,
      issues: issueBuckets.take(maxIssues).toList(growable: false),
      slowQueries: slowQueryBuckets
          .take(maxSlowQueries)
          .toList(growable: false),
      errorBursts: bursts,
      filesRead: input.filesRead,
      linesRead: input.linesRead,
      slowQueryCount: input.slowQueries.where((q) => !q.isSuperSlow).length,
      superSlowQueryCount: input.slowQueries.where((q) => q.isSuperSlow).length,
      truncated: truncated,
    );
  }

  /// Grouping key for a log message: redacted, then with ids, timestamps
  /// and numbers replaced so repeats with different values collapse.
  String messageSignature(String redactedMessage) {
    final collapsed = redactedMessage
        .replaceAll(_idPlaceholder, '[id]')
        .replaceAll(_isoTimestamp, '<ts>')
        .replaceAll(_number, '#')
        .replaceAll(_whitespace, ' ')
        .trim();
    return collapsed.length <= _signatureLength
        ? collapsed
        : collapsed.substring(0, _signatureLength);
  }

  /// Grouping key for a SQL statement: whitespace collapsed, literals and
  /// placeholder lists normalised so `IN (?, ?, ?)` and `IN (?, ?)` match.
  String statementSignature(String statement) {
    return statement
        .replaceAll(_quotedLiteral, '?')
        .replaceAll(_whitespace, ' ')
        .replaceAll(_placeholderList, '(?...)')
        .replaceAll(_number, '?')
        .trim();
  }

  List<LogIssueBucket> _bucketIssues(List<LogRecord> records) {
    final buckets = <String, _IssueAccumulator>{};
    for (final record in records) {
      final redacted = redactor.redact(record.message);
      final signature = messageSignature(redacted);
      final key = '${record.domain.wireName}|${record.level}|$signature';
      final existing = buckets[key];
      if (existing != null) {
        existing.add(record.timestamp);
        continue;
      }
      buckets[key] = _IssueAccumulator(
        domain: record.domain,
        level: record.level,
        subDomain: record.subDomain,
        signature: signature,
        sample: redacted,
        sampleFrames: _appFrames(record.continuation),
        firstSeen: record.timestamp,
      );
    }
    final result = buckets.values.map((a) => a.toBucket()).toList()
      ..sort((a, b) {
        // Errors before warnings, then by frequency.
        if (a.level != b.level) return a.level == 'ERROR' ? -1 : 1;
        return b.count.compareTo(a.count);
      });
    return result;
  }

  List<String> _appFrames(List<String> continuation) {
    return continuation
        .map((line) => line.trim())
        .where(_appFrame.hasMatch)
        .map(redactor.redact)
        .take(maxSampleFrames)
        .toList(growable: false);
  }

  List<SlowQueryBucket> _bucketSlowQueries(List<SlowQueryRecord> queries) {
    final buckets = <String, _SlowQueryAccumulator>{};
    for (final query in queries) {
      final statement = redactor.redact(query.statement);
      final signature = statementSignature(statement);
      buckets
          .putIfAbsent(
            '${query.databaseName}|$signature',
            () => _SlowQueryAccumulator(
              databaseName: query.databaseName,
              statement: signature,
              operation: query.operation,
            ),
          )
          .add(query, redactor, _wrapperFrame);
    }
    final result =
        buckets.values
            .map((a) => a.toBucket(maxPlanShapes, maxTopFrames))
            .toList()
          ..sort((a, b) => b.totalMs.compareTo(a.totalMs));
    return result;
  }

  List<DomainCounts> _countByDomain(LogReadResult input) {
    final errors = <LogDomain, int>{};
    final warnings = <LogDomain, int>{};
    for (final record in input.records) {
      (record.isError ? errors : warnings).update(
        record.domain,
        (c) => c + 1,
        ifAbsent: () => 1,
      );
    }
    final domains = <LogDomain>{
      ...errors.keys,
      ...warnings.keys,
      ...input.infoCounts.keys,
    };
    final result =
        [
          for (final domain in domains)
            DomainCounts(
              domain: domain,
              errors: errors[domain] ?? 0,
              warnings: warnings[domain] ?? 0,
              infos: input.infoCounts[domain] ?? 0,
            ),
        ]..sort((a, b) {
          final byErrors = b.errors.compareTo(a.errors);
          if (byErrors != 0) return byErrors;
          return b.total.compareTo(a.total);
        });
    return result;
  }

  /// Minutes whose error count is far above the window's typical minute.
  ///
  /// A burst is at least ten errors in one minute and at least three times
  /// the median over the minutes that saw any error at all — a single flaky
  /// call does not qualify, a retry storm does. The median rather than the
  /// mean keeps one storm from raising the bar for the next.
  List<ErrorBurst> _findErrorBursts(List<LogRecord> records) {
    final perMinute = <DateTime, int>{};
    for (final record in records.where((r) => r.isError)) {
      final t = record.timestamp;
      final minute = DateTime(t.year, t.month, t.day, t.hour, t.minute);
      perMinute.update(minute, (c) => c + 1, ifAbsent: () => 1);
    }
    if (perMinute.isEmpty) return const [];
    final sorted = perMinute.values.toList()..sort();
    // Lower median: with few busy minutes the quiet ones set the bar.
    final median = sorted[(sorted.length - 1) ~/ 2];
    final threshold = math.max(10, median * 3);
    final bursts =
        perMinute.entries
            .where((e) => e.value >= threshold)
            .map((e) => ErrorBurst(minute: e.key, count: e.value))
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    return bursts.take(maxErrorBursts).toList(growable: false);
  }
}

class _IssueAccumulator {
  _IssueAccumulator({
    required this.domain,
    required this.level,
    required this.subDomain,
    required this.signature,
    required this.sample,
    required this.sampleFrames,
    required this.firstSeen,
  }) : lastSeen = firstSeen;

  final LogDomain domain;
  final String level;
  final String? subDomain;
  final String signature;
  final String sample;
  final List<String> sampleFrames;
  final DateTime firstSeen;
  DateTime lastSeen;
  int count = 1;

  void add(DateTime timestamp) {
    count++;
    if (timestamp.isAfter(lastSeen)) lastSeen = timestamp;
  }

  LogIssueBucket toBucket() => LogIssueBucket(
    domain: domain,
    level: level,
    subDomain: subDomain,
    signature: signature,
    count: count,
    firstSeen: firstSeen,
    lastSeen: lastSeen,
    sample: sample,
    sampleFrames: sampleFrames,
  );
}

class _SlowQueryAccumulator {
  _SlowQueryAccumulator({
    required this.databaseName,
    required this.statement,
    required this.operation,
  });

  final String databaseName;
  final String statement;
  final String operation;

  /// Elapsed values from the slow file, keyed so the super-slow copy of the
  /// same entry can be recognised.
  final List<double> slowElapsed = [];
  final Set<String> slowKeys = {};

  /// Super-slow entries, with the key that identifies their slow-file twin.
  final List<(String key, double elapsedMs)> superEntries = [];
  final Set<String> planShapes = {};
  final Set<String> topFrames = {};
  final List<int> inFlight = [];
  final List<int> openTransactions = [];
  DateTime? firstSeen;
  DateTime? lastSeen;

  void add(SlowQueryRecord query, LogRedactor redactor, RegExp wrapperFrame) {
    // Both files write the same timestamp, elapsed and statement for one
    // query, which is identity enough to spot the duplicate.
    final key =
        '${query.timestamp.toIso8601String()}|${query.elapsedMs}|'
        '${query.statement}';
    if (query.isSuperSlow) {
      superEntries.add((key, query.elapsedMs));
    } else {
      slowElapsed.add(query.elapsedMs);
      slowKeys.add(key);
    }
    if (query.planRows.isNotEmpty) {
      planShapes.add(query.planRows.join(' | '));
    }
    if (query.stackFrames.isNotEmpty) {
      // The first frame that is not a wrapper; the wrapper itself when the
      // capture holds nothing else.
      final frame = query.stackFrames.firstWhere(
        (f) => !wrapperFrame.hasMatch(f),
        orElse: () => query.stackFrames.first,
      );
      topFrames.add(redactor.redact(frame));
    }
    final inFlightAtStart = query.inFlightAtStart;
    if (inFlightAtStart != null) inFlight.add(inFlightAtStart);
    final openAtStart = query.openTransactionsAtStart;
    if (openAtStart != null) openTransactions.add(openAtStart);
    final first = firstSeen;
    if (first == null || query.timestamp.isBefore(first)) {
      firstSeen = query.timestamp;
    }
    final last = lastSeen;
    if (last == null || query.timestamp.isAfter(last)) {
      lastSeen = query.timestamp;
    }
  }

  SlowQueryBucket toBucket(int maxPlanShapes, int maxTopFrames) {
    // A query above the super-slow cutoff is written to both files. Count
    // each entry once: the slow file's series, plus any super-slow entry
    // whose twin is missing (a deleted or rotated slow file).
    final series = [
      ...slowElapsed,
      for (final (key, elapsed) in superEntries)
        if (!slowKeys.contains(key)) elapsed,
    ]..sort();
    return SlowQueryBucket(
      databaseName: databaseName,
      statement: statement,
      operation: operation,
      count: series.length,
      superSlowCount: superEntries.length,
      p50Ms: _percentile(series, 0.5),
      p95Ms: _percentile(series, 0.95),
      maxMs: series.last,
      totalMs: series.fold(0, (sum, v) => sum + v),
      firstSeen: firstSeen!,
      lastSeen: lastSeen!,
      planShapes: planShapes.take(maxPlanShapes).toList(growable: false),
      topFrames: topFrames.take(maxTopFrames).toList(growable: false),
      queueDepth: _queueDepth(),
    );
  }

  QueueDepthStats? _queueDepth() {
    if (inFlight.isEmpty) return null;
    final inFlightSorted = [...inFlight]..sort();
    // Entries without a TRANSACTION row predate the timing rows, or the
    // interceptor had nothing to say: read as no open transaction.
    final openSorted = [
      ...openTransactions,
      for (var i = openTransactions.length; i < inFlight.length; i++) 0,
    ]..sort();
    return QueueDepthStats(
      inFlightP50: _percentileInt(inFlightSorted, 0.5),
      inFlightMax: inFlightSorted.last,
      openTransactionsP50: _percentileInt(openSorted, 0.5),
      openTransactionsMax: openSorted.last,
    );
  }

  static double _percentile(List<double> sorted, double fraction) {
    if (sorted.length == 1) return sorted.first;
    final index = (fraction * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  static int _percentileInt(List<int> sorted, double fraction) {
    if (sorted.length == 1) return sorted.first;
    final index = (fraction * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}
