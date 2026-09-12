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
/// for every domain except `sync`, which shares `sync-<date>.log`, and the
/// two slow-query stems the database interceptor owns. Lines are then
/// filtered against the exact window, because a file holds a whole day.
class LogFileReader {
  LogFileReader({required this.logsDirectory});

  final Directory logsDirectory;

  static const String slowQueryStem = 'slow_queries';
  static const String superSlowQueryStem = 'super_slow_queries';
  static const String _syncStem = 'sync';

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
          records: records,
          infoCounts: infoCounts,
        );
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

  void _parseLogLines(
    List<String> lines, {
    required LogDomain domain,
    required bool shared,
    required SystemHealthRange range,
    required List<LogRecord> records,
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
      if (level != 'ERROR' && level != 'WARN') {
        infoCounts.update(domain, (count) => count + 1, ifAbsent: () => 1);
        continue;
      }
      continuation = <String>[];
      records.add(
        LogRecord(
          timestamp: timestamp,
          level: level,
          domain: domain,
          subDomain: subDomain,
          message: message,
          continuation: continuation,
        ),
      );
    }
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
