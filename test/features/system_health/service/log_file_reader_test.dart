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

  test('per-domain files yield warnings and info counts; error text does '
      'not come from them', () async {
    await writeLogFile(logs, 'agentRuntime', fixtureDay, agentRuntimeFixture);

    final result = await reader.read(
      range: fixtureRange(),
      domains: {LogDomain.agentRuntime},
      includeSlowQueries: false,
    );

    expect(result.filesRead, 1);
    expect(result.linesRead, 8);
    expect(result.infoCounts, {LogDomain.agentRuntime: 2});
    // The full exception strings in the per-domain file are never exported.
    expect(result.records.map((r) => r.level), ['WARN']);
    expect(result.records.single.subDomain, 'drain');
    expect(result.records.single.message, 'drain skipped, queue.length=3');
    expect(result.records.single.continuation, isEmpty);
  });

  test(
    'errors come from the PII-safe log with frames from the domain file',
    () async {
      await writeLogFile(logs, 'agentRuntime', fixtureDay, agentRuntimeFixture);
      await writeLogFile(logs, 'error-safe', fixtureDay, errorSafeFixture);

      final result = await reader.read(
        range: fixtureRange(),
        domains: {LogDomain.agentRuntime},
        includeSlowQueries: false,
      );

      expect(result.filesRead, 2);
      final errors = result.records.where((r) => r.isError).toList();
      expect(errors, hasLength(2));
      final first = errors.first;
      expect(first.timestamp, DateTime(2026, 9, 12, 0, 5, 23, 83, 100));
      expect(first.domain, LogDomain.agentRuntime);
      expect(first.subDomain, isNull);
      // Safe text: message and error type, not the raw "Bad state: …" string.
      expect(
        first.message,
        'wake failed in 18136ms for [id:95a30c] (errorType=StateError)',
      );
      expect(first.message, isNot(contains('Bad state')));
      // Frames matched from the per-domain entry 300 µs away.
      expect(first.continuation, hasLength(3));
      expect(first.continuation.first, startsWith('#0      GoalAgentWorkflow'));
      expect(errors.last.continuation, isEmpty);
      // Other domains' safe lines and non-error lines are ignored.
      expect(
        result.records.where((r) => r.domain == LogDomain.speech),
        isEmpty,
      );
      expect(result.records.where((r) => r.isWarning), hasLength(1));
    },
  );

  test(
    'frames are only matched within one second and the same sub-domain',
    () async {
      await writeLogFile(
        logs,
        'agentRuntime',
        fixtureDay,
        '2026-09-12T00:05:23.000000 [ERROR] execute: raw error text\n'
            '#0      A.b (package:lotti/a.dart:1:1)\n'
            '2026-09-12T00:10:00.000000 [ERROR]: raw error text\n'
            '#0      C.d (package:lotti/c.dart:1:1)\n',
      );
      await writeLogFile(
        logs,
        'error-safe',
        fixtureDay,
        '2026-09-12T00:05:23.400000 [ERROR] agentRuntime: safe one (errorType=X)\n'
            '2026-09-12T00:10:02.000000 [ERROR] agentRuntime: safe two (errorType=X)\n',
      );

      final result = await reader.read(
        range: fixtureRange(),
        domains: {LogDomain.agentRuntime},
        includeSlowQueries: false,
      );

      final errors = result.records.where((r) => r.isError).toList();
      expect(errors.map((r) => r.message), [
        'safe one (errorType=X)',
        'safe two (errorType=X)',
      ]);
      // Sub-domain "execute" ≠ none, so no frames despite the close timestamp.
      expect(errors.first.continuation, isEmpty);
      // Two seconds apart: outside the match window.
      expect(errors.last.continuation, isEmpty);
    },
  );

  test('the nearest per-domain entry lends its frames', () async {
    await writeLogFile(
      logs,
      'agentRuntime',
      fixtureDay,
      '2026-09-12T00:05:22.700000 [ERROR]: earlier raw\n'
          '#0      Far.away (package:lotti/far.dart:1:1)\n'
          '2026-09-12T00:05:23.100000 [ERROR]: nearer raw\n'
          '#0      Near.by (package:lotti/near.dart:1:1)\n'
          '2026-09-12T00:05:23.900000 [ERROR]: later raw\n'
          '#0      Later.on (package:lotti/later.dart:1:1)\n',
    );
    await writeLogFile(
      logs,
      'error-safe',
      fixtureDay,
      '2026-09-12T00:05:23.000000 [ERROR] agentRuntime: safe (errorType=X)\n',
    );

    final result = await reader.read(
      range: fixtureRange(),
      domains: {LogDomain.agentRuntime},
      includeSlowQueries: false,
    );

    expect(result.records.single.continuation, [
      '#0      Near.by (package:lotti/near.dart:1:1)',
    ]);
  });

  test('the safe log is not read when no domain is selected', () async {
    await writeLogFile(logs, 'error-safe', fixtureDay, errorSafeFixture);
    final result = await reader.read(
      range: fixtureRange(),
      domains: const {},
      includeSlowQueries: false,
    );
    expect(result.filesRead, 0);
  });

  test('records are sorted by timestamp across files', () async {
    await writeLogFile(logs, 'agentRuntime', fixtureDay, agentRuntimeFixture);
    await writeLogFile(logs, 'sync', fixtureDay, syncFixture);
    await writeLogFile(logs, 'error-safe', fixtureDay, errorSafeFixture);

    final result = await reader.read(
      range: fixtureRange(),
      domains: {LogDomain.agentRuntime, LogDomain.sync},
      includeSlowQueries: false,
    );

    expect(result.records, hasLength(5));
    final timestamps = result.records.map((r) => r.timestamp).toList();
    expect(timestamps, orderedEquals([...timestamps]..sort()));
  });

  test(
    'the sync domain reads the shared sync file with its domain column',
    () async {
      await writeLogFile(logs, 'sync', fixtureDay, syncFixture);
      await writeLogFile(logs, 'error-safe', fixtureDay, errorSafeFixture);

      final result = await reader.read(
        range: fixtureRange(),
        domains: {LogDomain.sync},
        includeSlowQueries: false,
      );

      expect(result.records, hasLength(2));
      expect(result.records.first.isError, isTrue);
      expect(result.records.first.subDomain, 'vc.reserved.audit');
      expect(
        result.records.first.message,
        endsWith('count=12 (errorType=String)'),
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

    expect(result.records.map((r) => r.timestamp.minute), [7]);
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
    // TIMING continuation lines are not plan rows; they carry the queue
    // depth. No TRANSACTION row with a TIMING row means nothing was open.
    expect(slow.first.planRows, isEmpty);
    expect(slow.first.inFlightAtStart, 4);
    expect(slow.first.openTransactionsAtStart, 0);
    // An entry written without timing bookkeeping carries neither.
    expect(slow[1].inFlightAtStart, isNull);
    expect(slow[1].openTransactionsAtStart, isNull);
    expect(superSlow.first.planRows, hasLength(2));
    expect(superSlow.first.planRows.last, '84|0|USE TEMP B-TREE FOR ORDER BY');
    expect(superSlow.first.stackFrames, hasLength(2));
    expect(
      superSlow.first.stackFrames.first,
      startsWith('#10     JournalDb.getAllDashboards'),
    );
  });

  test('a BEGIN keeps the open-transaction count it waited behind', () async {
    await writeLogFile(
      logs,
      'slow_queries',
      fixtureDay,
      transactionSlowQueriesFixture,
    );

    final result = await reader.read(
      range: fixtureRange(),
      domains: const {},
      includeSlowQueries: true,
    );

    expect(result.slowQueries, hasLength(2));
    final queued = result.slowQueries.first;
    expect(queued.databaseName, 'agent.sqlite');
    expect(queued.operation, 'transaction.open');
    expect(queued.statement, 'BEGIN');
    expect(queued.inFlightAtStart, 12);
    expect(queued.openTransactionsAtStart, 2);
    // The last entry of a file is flushed too, timing rows or not.
    final plain = result.slowQueries.last;
    expect(plain.elapsedMs, 20);
    expect(plain.inFlightAtStart, isNull);
    expect(plain.openTransactionsAtStart, isNull);
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
          '2026-99-99T00:00:00 [WARN]: not a date\n'
          '2026-09-12T01:00:00.000 [WARN]: real warning\n',
    );
    await writeLogFile(
      logs,
      'error-safe',
      fixtureDay,
      'garbage\n'
          '2026-99-99T00:00:00 [ERROR] agentRuntime: not a date\n'
          '2026-09-12T01:00:00.000 [ERROR] unknownDomain: not a domain\n'
          '2026-09-12T01:00:01.000 [ERROR] agentRuntime: real error\n',
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

    expect(result.records.map((r) => r.message), [
      'real warning',
      'real error',
    ]);
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
