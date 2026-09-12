import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:lotti/features/system_health/domain/log_records.dart';
import 'package:lotti/features/system_health/domain/system_health_range.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:path/path.dart' as p;

/// Everything the reader pulled from disk for one request.
class LogReadResult {
  const LogReadResult({
    required this.records,
    required this.infoCounts,
    required this.slowQueries,
    required this.filesRead,
    required this.linesRead,
  });

  /// Error and warning entries inside the window, oldest first.
  final List<LogRecord> records;

  /// Info-level line counts per domain. Info lines are counted, not kept —
  /// a chatty domain writes hundreds of thousands of them in two weeks.
  final Map<LogDomain, int> infoCounts;

  /// Slow and super-slow query entries inside the window, oldest first.
  final List<SlowQueryRecord> slowQueries;
  final int filesRead;
  final int linesRead;
}

/// Reads the daily log files that cover a window.
///
/// File selection follows the writers' naming: `<domain>-<yyyy-MM-dd>.log`
/// for every domain except `sync`, which shares `sync-<date>.log`, the
/// PII-safe `error-safe-<date>.log`, and the two slow-query stems the
/// database interceptor owns. Lines are then filtered against the exact
/// window, because a file holds a whole day.
///
/// **Error text comes only from the PII-safe error log.** The per-domain
/// files carry the full exception string of every error, which by the
/// logging contract may contain anything — a task title inside a
/// `FormatException`, model output inside a parse failure — and no finite
/// redactor can promise to remove arbitrary prose. `error-safe-*.log` was
/// written for exactly this purpose: message plus error *type*, never the
/// raw error. So the per-domain files contribute info counts, warnings and
/// the application stack frames of their errors, while each error record's
/// text is the safe line matched to those frames by domain, sub-domain and a
/// timestamp within [frameMatchWindow].
class LogFileReader {
  LogFileReader({required this.logsDirectory});

  final Directory logsDirectory;

  static const String slowQueryStem = 'slow_queries';
  static const String superSlowQueryStem = 'super_slow_queries';
  static const String errorSafeStem = 'error-safe';
  static const String _syncStem = 'sync';

  /// How far apart the safe line and the per-domain line of one error may
  /// be. Both are written from the same call with separate clock reads.
  static const Duration frameMatchWindow = Duration(seconds: 1);

  static final Map<String, LogDomain> _domainsByWireName = {
    for (final domain in LogDomain.values) domain.wireName: domain,
  };

  static final DateFormat _fileDate = DateFormat('yyyy-MM-dd');

  /// `<iso> [LEVEL] <subDomain>?: <message>` — the per-domain file shape,
  /// where the domain is the file name.
  static final RegExp _domainLine = RegExp(
    r'^(\d{4}-\d{2}-\d{2}T\S+) \[([A-Z]+)\](?: ([^:\s]+))?: (.*)$',
  );

  /// `<iso> [LEVEL] <domain> <subDomain>?: <message>` — the shared-file
  /// shape used by the sync log.
  static final RegExp _sharedLine = RegExp(
    r'^(\d{4}-\d{2}-\d{2}T\S+) \[([A-Z]+)\] ([^:\s]+)(?: ([^:\s]+))?: (.*)$',
  );

  /// `<iso> [<db>] <op> <elapsed>ms args=<n> <statement>`.
  static final RegExp _slowQueryLine = RegExp(
    r'^(\d{4}-\d{2}-\d{2}T\S+) \[([^\]]+)\] (\S+) ([\d.]+)ms args=\d+ (.*)$',
  );

  static const Utf8Decoder _decoder = Utf8Decoder(allowMalformed: true);

  Future<LogReadResult> read({
    required SystemHealthRange range,
    required Set<LogDomain> domains,
    required bool includeSlowQueries,
  }) async {
    final records = <LogRecord>[];
    final frameSources = <_FrameSource>[];
    final safeErrors = <LogRecord>[];
    final infoCounts = <LogDomain, int>{};
    final slowQueries = <SlowQueryRecord>[];
    var filesRead = 0;
    var linesRead = 0;

    for (final day in range.days) {
      final date = _fileDate.format(day);
      for (final domain in domains) {
        final stem = domain.routesToSyncFile ? _syncStem : domain.wireName;
        final lines = await _readLines('$stem-$date.log');
        if (lines == null) continue;
        filesRead++;
        linesRead += lines.length;
        _parseLogLines(
          lines,
          domain: domain,
          shared: domain.routesToSyncFile,
          range: range,
          warnings: records,
          frameSources: frameSources,
          infoCounts: infoCounts,
        );
      }
      if (domains.isNotEmpty) {
        final lines = await _readLines('$errorSafeStem-$date.log');
        if (lines != null) {
          filesRead++;
          linesRead += lines.length;
          _parseSafeErrorLines(
            lines,
            domains: domains,
            range: range,
            into: safeErrors,
          );
        }
      }
      if (includeSlowQueries) {
        for (final (stem, isSuperSlow) in const [
          (slowQueryStem, false),
          (superSlowQueryStem, true),
        ]) {
          final lines = await _readLines('$stem-$date.log');
          if (lines == null) continue;
          filesRead++;
          linesRead += lines.length;
          _parseSlowQueryLines(
            lines,
            isSuperSlow: isSuperSlow,
            range: range,
            into: slowQueries,
          );
        }
      }
    }

    for (final error in safeErrors) {
      records.add(_withFrames(error, frameSources));
    }
    records.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    slowQueries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return LogReadResult(
      records: records,
      infoCounts: infoCounts,
      slowQueries: slowQueries,
      filesRead: filesRead,
      linesRead: linesRead,
    );
  }

  Future<List<String>?> _readLines(String fileName) async {
    final file = File(p.join(logsDirectory.path, fileName));
    if (!file.existsSync()) return null;
    final bytes = await file.readAsBytes();
    return const LineSplitter().convert(_decoder.convert(bytes));
  }

  /// Per-domain and sync files: info is counted, warnings are kept, and an
  /// error contributes only its application stack frames — its text is
  /// taken from the PII-safe log instead.
  void _parseLogLines(
    List<String> lines, {
    required LogDomain domain,
    required bool shared,
    required SystemHealthRange range,
    required List<LogRecord> warnings,
    required List<_FrameSource> frameSources,
    required Map<LogDomain, int> infoCounts,
  }) {
    List<String>? continuation;
    for (final line in lines) {
      final match = shared
          ? _sharedLine.firstMatch(line)
          : _domainLine.firstMatch(line);
      if (match == null) {
        // Stack frames and diagnostics follow the entry they belong to.
        continuation?.add(line);
        continue;
      }
      continuation = null;
      final timestamp = DateTime.tryParse(match.group(1)!);
      if (timestamp == null || !range.contains(timestamp)) continue;
      final level = match.group(2)!;
      final subDomain = shared ? match.group(4) : match.group(3);
      final message = shared ? match.group(5)! : match.group(4)!;
      switch (level) {
        case 'ERROR':
          continuation = <String>[];
          frameSources.add(
            _FrameSource(
              timestamp: timestamp,
              domain: domain,
              subDomain: subDomain,
              continuation: continuation,
            ),
          );
        case 'WARN':
          warnings.add(
            LogRecord(
              timestamp: timestamp,
              level: level,
              domain: domain,
              subDomain: subDomain,
              message: message,
            ),
          );
        default:
          infoCounts.update(domain, (count) => count + 1, ifAbsent: () => 1);
      }
    }
  }

  /// `error-safe-*.log`: shared format with a domain column; only errors of
  /// the selected domains inside the window are kept.
  void _parseSafeErrorLines(
    List<String> lines, {
    required Set<LogDomain> domains,
    required SystemHealthRange range,
    required List<LogRecord> into,
  }) {
    for (final line in lines) {
      final match = _sharedLine.firstMatch(line);
      if (match == null) continue;
      final timestamp = DateTime.tryParse(match.group(1)!);
      if (timestamp == null || !range.contains(timestamp)) continue;
      if (match.group(2) != 'ERROR') continue;
      final domain = _domainsByWireName[match.group(3)!];
      if (domain == null || !domains.contains(domain)) continue;
      into.add(
        LogRecord(
          timestamp: timestamp,
          level: 'ERROR',
          domain: domain,
          subDomain: match.group(4),
          message: match.group(5)!,
        ),
      );
    }
  }

  /// Attaches the app-code frames of the nearest per-domain error entry
  /// with the same domain and sub-domain inside [frameMatchWindow].
  LogRecord _withFrames(LogRecord error, List<_FrameSource> sources) {
    _FrameSource? best;
    Duration? bestDistance;
    for (final source in sources) {
      if (source.domain != error.domain ||
          source.subDomain != error.subDomain) {
        continue;
      }
      final distance = source.timestamp.difference(error.timestamp).abs();
      if (distance > frameMatchWindow) continue;
      if (bestDistance == null || distance < bestDistance) {
        best = source;
        bestDistance = distance;
      }
    }
    if (best == null) return error;
    return LogRecord(
      timestamp: error.timestamp,
      level: error.level,
      domain: error.domain,
      subDomain: error.subDomain,
      message: error.message,
      continuation: best.continuation,
    );
  }

  void _parseSlowQueryLines(
    List<String> lines, {
    required bool isSuperSlow,
    required SystemHealthRange range,
    required List<SlowQueryRecord> into,
  }) {
    List<String>? planRows;
    List<String>? stackFrames;
    for (final line in lines) {
      final match = _slowQueryLine.firstMatch(line);
      if (match == null) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('PLAN: ')) {
          planRows?.add(trimmed.substring('PLAN: '.length));
        } else if (trimmed.startsWith('STACK: ')) {
          stackFrames?.add(trimmed.substring('STACK: '.length));
        }
        continue;
      }
      planRows = null;
      stackFrames = null;
      final timestamp = DateTime.tryParse(match.group(1)!);
      if (timestamp == null || !range.contains(timestamp)) continue;
      final elapsed = double.tryParse(match.group(4)!);
      if (elapsed == null) continue;
      planRows = <String>[];
      stackFrames = <String>[];
      into.add(
        SlowQueryRecord(
          timestamp: timestamp,
          databaseName: match.group(2)!,
          operation: match.group(3)!,
          elapsedMs: elapsed,
          statement: match.group(5)!,
          isSuperSlow: isSuperSlow,
          planRows: planRows,
          stackFrames: stackFrames,
        ),
      );
    }
  }
}

/// An error entry from a per-domain file, kept for its stack frames only.
class _FrameSource {
  const _FrameSource({
    required this.timestamp,
    required this.domain,
    required this.subDomain,
    required this.continuation,
  });

  final DateTime timestamp;
  final LogDomain domain;
  final String? subDomain;
  final List<String> continuation;
}
