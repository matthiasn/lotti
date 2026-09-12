import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/system_health/domain/system_health_range.dart';
import 'package:lotti/features/system_health/service/log_file_reader.dart';
import 'package:lotti/services/logging_domains.dart';

import '../system_health_test_fixtures.dart';

void main() {
  late Directory logs;
  late LogFileReader reader;

  setUp(() async {
    logs = await Directory.systemTemp.createTemp('system_health_reader');
    reader = LogFileReader(logsDirectory: logs);
  });

  tearDown(() => logs.delete(recursive: true));

  test('parses per-domain files, keeping errors and warnings only', () async {
    await writeLogFile(logs, 'agentRuntime', fixtureDay, agentRuntimeFixture);

    final result = await reader.read(
      range: fixtureRange(),
      domains: {LogDomain.agentRuntime},
      includeSlowQueries: false,
    );

    expect(result.filesRead, 1);
    expect(result.linesRead, 8);
    expect(result.infoCounts, {LogDomain.agentRuntime: 2});
    expect(result.records.map((r) => r.level), ['ERROR', 'ERROR', 'WARN']);
    final first = result.records.first;
    expect(first.timestamp, DateTime(2026, 9, 12, 0, 5, 23, 82, 870));
    expect(first.domain, LogDomain.agentRuntime);
    expect(first.subDomain, isNull);
    expect(first.message, startsWith('wake failed in 18136ms'));
    expect(first.continuation, hasLength(3));
    expect(first.continuation.first, startsWith('#0      GoalAgentWorkflow'));
    expect(result.records.last.subDomain, 'drain');
    expect(result.records.last.continuation, isEmpty);
  });

  test('records are sorted by timestamp across files', () async {
    await writeLogFile(logs, 'agentRuntime', fixtureDay, agentRuntimeFixture);
    await writeLogFile(logs, 'sync', fixtureDay, syncFixture);

    final result = await reader.read(
      range: fixtureRange(),
      domains: {LogDomain.agentRuntime, LogDomain.sync},
      includeSlowQueries: false,
    );

    final timestamps = result.records.map((r) => r.timestamp).toList();
    expect(timestamps, orderedEquals([...timestamps]..sort()));
  });

  test(
    'the sync domain reads the shared sync file with its domain column',
    () async {
      await writeLogFile(logs, 'sync', fixtureDay, syncFixture);

      final result = await reader.read(
        range: fixtureRange(),
        domains: {LogDomain.sync},
        includeSlowQueries: false,
      );

      expect(result.records, hasLength(2));
      expect(result.records.first.subDomain, 'vc.reserved.audit');
      expect(
        result.records.first.message,
        startsWith('vc.reserved.audit host='),
      );
      expect(result.records.last.subDomain, isNull);
      expect(result.records.last.message, 'user user@example.com retried');
      expect(result.infoCounts, {LogDomain.sync: 1});
    },
  );

  test('only files for selected domains and days are read', () async {
    await writeLogFile(logs, 'agentRuntime', fixtureDay, agentRuntimeFixture);
    await writeLogFile(logs, 'speech', fixtureDay, agentRuntimeFixture);
    await writeLogFile(
      logs,
      'agentRuntime',
      fixtureDay.subtract(const Duration(days: 5)),
      agentRuntimeFixture,
    );

    final result = await reader.read(
      range: fixtureRange(),
      domains: {LogDomain.agentRuntime},
      includeSlowQueries: false,
    );

    expect(result.filesRead, 1);
  });

  test('lines outside the exact window are dropped', () async {
    await writeLogFile(logs, 'agentRuntime', fixtureDay, agentRuntimeFixture);

    final result = await reader.read(
      range: SystemHealthRange(
        preset: SystemHealthPreset.custom,
        start: DateTime(2026, 9, 12, 0, 6),
        end: DateTime(2026, 9, 12, 0, 8),
      ),
      domains: {LogDomain.agentRuntime},
      includeSlowQueries: false,
    );

    expect(result.records.map((r) => r.timestamp.minute), [6, 7]);
    expect(result.infoCounts, isEmpty);
  });

  test('parses slow and super-slow files with plans and stacks', () async {
    await writeLogFile(logs, 'slow_queries', fixtureDay, slowQueriesFixture);
    await writeLogFile(
      logs,
      'super_slow_queries',
      fixtureDay,
      superSlowQueriesFixture,
    );

    final result = await reader.read(
      range: fixtureRange(),
      domains: const {},
      includeSlowQueries: true,
    );

    expect(result.filesRead, 2);
    final slow = result.slowQueries.where((q) => !q.isSuperSlow).toList();
    final superSlow = result.slowQueries.where((q) => q.isSuperSlow).toList();
    expect(slow, hasLength(4));
    expect(superSlow, hasLength(2));
    expect(slow.first.elapsedMs, 388.759);
    expect(slow.first.databaseName, 'db.sqlite');
    expect(slow.first.operation, 'select');
    expect(
      slow.first.statement,
      startsWith('SELECT * FROM journal WHERE deleted'),
    );
    // TIMING continuation lines are not plan rows.
    expect(slow.first.planRows, isEmpty);
    expect(superSlow.first.planRows, hasLength(2));
    expect(superSlow.first.planRows.last, '84|0|USE TEMP B-TREE FOR ORDER BY');
    expect(superSlow.first.stackFrames, hasLength(2));
    expect(
      superSlow.first.stackFrames.first,
      startsWith('#10     JournalDb.getAllDashboards'),
    );
  });

  test('slow-query files are skipped unless requested', () async {
    await writeLogFile(logs, 'slow_queries', fixtureDay, slowQueriesFixture);

    final result = await reader.read(
      range: fixtureRange(),
      domains: const {},
      includeSlowQueries: false,
    );

    expect(result.filesRead, 0);
    expect(result.slowQueries, isEmpty);
  });

  test('malformed and unparsable lines do not abort the read', () async {
    await writeLogFile(
      logs,
      'agentRuntime',
      fixtureDay,
      'garbage line\n'
          '2026-99-99T00:00:00 [ERROR]: not a date\n'
          '2026-09-12T01:00:00.000 [ERROR]: real error\n',
    );
    await writeLogFile(
      logs,
      'slow_queries',
      fixtureDay,
      '2026-09-12T01:00:00.000 [db] select abcms args=0 SELECT 1\n'
          '2026-09-12T01:00:00.000 [db] select 15.000ms args=0 SELECT 2\n',
    );

    final result = await reader.read(
      range: fixtureRange(),
      domains: {LogDomain.agentRuntime},
      includeSlowQueries: true,
    );

    expect(result.records.map((r) => r.message), ['real error']);
    expect(result.slowQueries.map((q) => q.statement), ['SELECT 2']);
  });

  test('a missing logs directory yields an empty result', () async {
    final missing = LogFileReader(
      logsDirectory: Directory('${logs.path}/does-not-exist'),
    );
    final result = await missing.read(
      range: fixtureRange(),
      domains: LogDomain.values.toSet(),
      includeSlowQueries: true,
    );
    expect(result.filesRead, 0);
    expect(result.records, isEmpty);
    expect(result.slowQueries, isEmpty);
  });
}
