import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/system_health/domain/log_records.dart';
import 'package:lotti/features/system_health/service/log_digest_builder.dart';
import 'package:lotti/features/system_health/service/log_file_reader.dart';
import 'package:lotti/services/logging_domains.dart';

import '../system_health_test_fixtures.dart';

void main() {
  const builder = LogDigestBuilder();
  final t0 = DateTime(2026, 9, 12, 10);

  LogReadResult input({
    List<LogRecord> records = const [],
    Map<LogDomain, int> infoCounts = const {},
    List<SlowQueryRecord> slowQueries = const [],
  }) => LogReadResult(
    records: records,
    infoCounts: infoCounts,
    slowQueries: slowQueries,
    filesRead: 2,
    linesRead: 20,
  );

  group('messageSignature', () {
    test('collapses ids, timestamps and numbers', () {
      expect(
        builder.messageSignature(
          'wake failed in 18136ms for [id:95a30c] at 2026-09-12T00:05:23.082',
        ),
        'wake failed in #ms for [id] at <ts>',
      );
    });

    test('is capped in length', () {
      expect(builder.messageSignature('x' * 500).length, 200);
    });
  });

  test('statementSignature normalises literals, numbers and lists', () {
    expect(
      builder.statementSignature(
        "SELECT  *  FROM journal WHERE id IN (?, ?, ?) AND type = 'Task' LIMIT 20",
      ),
      'SELECT * FROM journal WHERE id IN (?...) AND type = ? LIMIT ?',
    );
  });

  group('issues', () {
    test('groups repeats by domain, level and signature', () {
      final digest = builder.build(
        input(
          records: [
            logRecord(
              timestamp: t0,
              message: 'wake failed in 18136ms for [id:95a30c]',
            ),
            logRecord(
              timestamp: t0.add(const Duration(minutes: 5)),
              message: 'wake failed in 2000ms for [id:77aa00]',
            ),
            logRecord(
              timestamp: t0.add(const Duration(minutes: 1)),
              domain: LogDomain.speech,
              message: 'wake failed in 1ms for [id:000000]',
            ),
            logRecord(timestamp: t0, level: 'WARN', message: 'drain skipped'),
          ],
        ),
      );

      expect(digest.issues, hasLength(3));
      final top = digest.issues.first;
      expect(top.count, 2);
      expect(top.domain, LogDomain.agentRuntime);
      expect(top.firstSeen, t0);
      expect(top.lastSeen, t0.add(const Duration(minutes: 5)));
      expect(top.sample, 'wake failed in 18136ms for [id:95a30c]');
      // Errors before warnings regardless of count.
      expect(digest.issues.last.level, 'WARN');
    });

    test('redacts the sample and keeps only app stack frames', () {
      final digest = builder.build(
        input(
          records: [
            logRecord(
              timestamp: t0,
              message:
                  'sync failed for host 19d6f0b3-7d45-4ca1-aeb2-8829cac4b42e',
              continuation: const [
                '#0      Foo.bar (package:lotti/features/sync/foo.dart:1:1)',
                '<asynchronous suspension>',
                '#1      _rootRun (dart:async/zone.dart:1399:13)',
                '#2      Baz.qux (package:lotti/features/sync/baz.dart:2:2)',
              ],
            ),
          ],
        ),
      );

      final issue = digest.issues.single;
      expect(issue.sample, 'sync failed for host [id:19d6f0]');
      expect(issue.sampleFrames, [
        '#0      Foo.bar (package:lotti/features/sync/foo.dart:1:1)',
        '#2      Baz.qux (package:lotti/features/sync/baz.dart:2:2)',
      ]);
    });

    test('caps the number of buckets and flags truncation', () {
      const small = LogDigestBuilder(maxIssues: 2);
      final digest = small.build(
        input(
          records: [
            for (var i = 0; i < 5; i++)
              logRecord(
                timestamp: t0,
                message: 'distinct error ${String.fromCharCode(97 + i)}',
              ),
          ],
        ),
      );
      expect(digest.issues, hasLength(2));
      expect(digest.truncated, isTrue);
    });
  });

  group('slow queries', () {
    test('computes percentiles and totals per normalised statement', () {
      final digest = builder.build(
        input(
          slowQueries: [
            for (final ms in [10.0, 20.0, 30.0, 40.0, 100.0])
              slowQuery(timestamp: t0, elapsedMs: ms),
            slowQuery(timestamp: t0, elapsedMs: 15, statement: 'SELECT 1'),
          ],
        ),
      );

      expect(digest.slowQueries, hasLength(2));
      final top = digest.slowQueries.first;
      expect(top.statement, 'SELECT * FROM journal WHERE id = ?');
      expect(top.count, 5);
      expect(top.p50Ms, 30);
      expect(top.p95Ms, 100);
      expect(top.maxMs, 100);
      expect(top.totalMs, 200);
      expect(top.superSlowCount, 0);
      expect(digest.slowQueryCount, 6);
    });

    test('super-slow duplicates enrich a bucket without double counting', () {
      final digest = builder.build(
        input(
          slowQueries: [
            slowQuery(timestamp: t0, elapsedMs: 300),
            slowQuery(timestamp: t0),
            slowQuery(
              timestamp: t0,
              elapsedMs: 300,
              isSuperSlow: true,
              planRows: const ['4|0|SCAN journal'],
              stackFrames: const [
                '#10 JournalDb.get (package:lotti/database/database.dart:1:1)',
                '#11 Provider (package:lotti/x.dart:2:2)',
              ],
            ),
          ],
        ),
      );

      final bucket = digest.slowQueries.single;
      expect(bucket.count, 2);
      expect(bucket.superSlowCount, 1);
      expect(bucket.totalMs, 320);
      expect(bucket.planShapes, ['4|0|SCAN journal']);
      expect(bucket.topFrames, [
        '#10 JournalDb.get (package:lotti/database/database.dart:1:1)',
      ]);
      expect(digest.superSlowQueryCount, 1);
    });

    test('a super-slow entry without its slow-file twin is still counted', () {
      final digest = builder.build(
        input(
          slowQueries: [
            slowQuery(timestamp: t0),
            // Same timestamp, elapsed and statement: the duplicate copy.
            slowQuery(timestamp: t0, isSuperSlow: true),
            // A later day whose slow file is gone: only the super copy exists.
            slowQuery(
              timestamp: t0.add(const Duration(days: 1)),
              elapsedMs: 400,
              isSuperSlow: true,
            ),
          ],
        ),
      );
      final bucket = digest.slowQueries.single;
      expect(bucket.count, 2);
      expect(bucket.superSlowCount, 2);
      expect(bucket.maxMs, 400);
      expect(bucket.totalMs, 420);
    });

    test('a statement seen only in the super-slow file still gets stats', () {
      final digest = builder.build(
        input(
          slowQueries: [
            slowQuery(timestamp: t0, elapsedMs: 500, isSuperSlow: true),
          ],
        ),
      );
      final bucket = digest.slowQueries.single;
      expect(bucket.count, 1);
      expect(bucket.p50Ms, 500);
      expect(bucket.maxMs, 500);
    });

    test('the same statement on two databases makes two buckets', () {
      // A BEGIN on the agent database and one on the sync database queue
      // behind different writer locks; merged, neither can be diagnosed.
      final digest = builder.build(
        input(
          slowQueries: [
            for (var i = 0; i < 3; i++)
              slowQuery(
                timestamp: t0,
                elapsedMs: 1000,
                statement: 'BEGIN',
                operation: 'transaction.open',
                databaseName: 'agent.sqlite',
              ),
            slowQuery(
              timestamp: t0,
              elapsedMs: 15,
              statement: 'BEGIN',
              operation: 'transaction.open',
              databaseName: 'sync.sqlite',
            ),
          ],
        ),
      );

      expect(digest.slowQueries, hasLength(2));
      final agent = digest.slowQueries.first;
      expect(agent.databaseName, 'agent.sqlite');
      expect(agent.count, 3);
      expect(agent.p50Ms, 1000);
      final sync = digest.slowQueries.last;
      expect(sync.databaseName, 'sync.sqlite');
      expect(sync.count, 1);
      expect(sync.maxMs, 15);
    });

    test('the caller frame is the first below the transaction wrappers', () {
      const wrapper =
          '#8 AgentRepoCore.runInTransaction '
          '(package:lotti/features/agents/database/agent_repo_core.dart:110:5)';
      const scope =
          '#9 VectorClockService.withVcScope '
          '(package:lotti/services/vector_clock_service.dart:309:5)';
      const caller =
          '#10 DayAgentPlanWriter.persist '
          '(package:lotti/features/daily_os_next/agents/service/day_agent_plan_writer.dart:44:7)';
      final digest = builder.build(
        input(
          slowQueries: [
            slowQuery(
              timestamp: t0,
              elapsedMs: 300,
              statement: 'BEGIN',
              isSuperSlow: true,
              stackFrames: const [wrapper, scope, caller],
            ),
            // A capture holding nothing but wrappers still names something.
            slowQuery(
              timestamp: t0.add(const Duration(minutes: 1)),
              elapsedMs: 300,
              statement: 'BEGIN',
              isSuperSlow: true,
              stackFrames: const [wrapper],
            ),
          ],
        ),
      );

      expect(digest.slowQueries.single.topFrames, [caller, wrapper]);
    });

    test('concurrency at start is summarised when the entries carry it', () {
      final digest = builder.build(
        input(
          slowQueries: [
            slowQuery(
              timestamp: t0,
              elapsedMs: 1000,
              statement: 'BEGIN',
              inFlightAtStart: 60,
              openTransactionsAtStart: 3,
            ),
            slowQuery(
              timestamp: t0,
              elapsedMs: 900,
              statement: 'BEGIN',
              inFlightAtStart: 5,
              openTransactionsAtStart: 1,
            ),
            // Timing without a TRANSACTION row: nothing was open, and an
            // in-flight count of one is the statement itself.
            slowQuery(
              timestamp: t0,
              elapsedMs: 15,
              statement: 'BEGIN',
              inFlightAtStart: 1,
            ),
            slowQuery(timestamp: t0, elapsedMs: 15, statement: 'SELECT 1'),
          ],
        ),
      );

      final begin = digest.slowQueries.first;
      expect(begin.statement, 'BEGIN');
      final stats = begin.concurrency!;
      expect(stats.othersInFlightP50, 4);
      expect(stats.othersInFlightMax, 59);
      expect(stats.openTransactionsP50, 1);
      expect(stats.openTransactionsMax, 3);
      // No entry with timing bookkeeping: nothing to summarise.
      expect(digest.slowQueries.last.concurrency, isNull);
    });

    test('the super-slow copy of an entry does not double its sample', () {
      // Both files carry the same TIMING rows for one query; counting both
      // would pull the percentiles toward the slowest entries, which are
      // exactly the ones that reach the super-slow file.
      final digest = builder.build(
        input(
          slowQueries: [
            for (final (ms, inFlight) in [(15.0, 1), (20.0, 5), (300.0, 60)])
              slowQuery(
                timestamp: t0.add(Duration(milliseconds: ms.toInt())),
                elapsedMs: ms,
                statement: 'BEGIN',
                inFlightAtStart: inFlight,
              ),
            slowQuery(
              timestamp: t0.add(const Duration(milliseconds: 300)),
              elapsedMs: 300,
              statement: 'BEGIN',
              isSuperSlow: true,
              inFlightAtStart: 60,
            ),
            // A super-slow entry whose slow-file twin is gone still counts.
            slowQuery(
              timestamp: t0.add(const Duration(days: 1)),
              elapsedMs: 400,
              statement: 'BEGIN',
              isSuperSlow: true,
              inFlightAtStart: 2,
              openTransactionsAtStart: 1,
            ),
          ],
        ),
      );

      final stats = digest.slowQueries.single.concurrency!;
      // Samples: others = [0, 4, 59, 1] → sorted [0, 1, 4, 59].
      expect(stats.othersInFlightP50, 4);
      expect(stats.othersInFlightMax, 59);
      expect(stats.openTransactionsMax, 1);
    });

    test('buckets are ordered by total time', () {
      final digest = builder.build(
        input(
          slowQueries: [
            slowQuery(timestamp: t0, elapsedMs: 15, statement: 'SELECT a'),
            slowQuery(timestamp: t0, elapsedMs: 15, statement: 'SELECT a'),
            slowQuery(timestamp: t0, elapsedMs: 100, statement: 'SELECT b'),
          ],
        ),
      );
      expect(
        digest.slowQueries.map((q) => q.statement),
        ['SELECT b', 'SELECT a'],
      );
    });
  });

  group('domain counts', () {
    test('merges error, warning and info counts and sorts by errors', () {
      final digest = builder.build(
        input(
          records: [
            logRecord(timestamp: t0, domain: LogDomain.speech),
            logRecord(timestamp: t0, domain: LogDomain.speech),
            logRecord(timestamp: t0, level: 'WARN', domain: LogDomain.ai),
          ],
          infoCounts: {LogDomain.ai: 50, LogDomain.tasks: 7},
        ),
      );

      expect(
        digest.domainCounts.map((c) => c.domain),
        [LogDomain.speech, LogDomain.ai, LogDomain.tasks],
      );
      expect(digest.domainCounts[1].warnings, 1);
      expect(digest.domainCounts[1].infos, 50);
      expect(digest.domainCounts[1].errors, 0);
      expect(digest.errorCount, 2);
      expect(digest.warningCount, 1);
      expect(digest.filesRead, 2);
      expect(digest.linesRead, 20);
    });
  });

  group('error bursts', () {
    test('reports minutes far above the mean, highest first', () {
      final digest = builder.build(
        input(
          records: [
            for (var i = 0; i < 12; i++)
              logRecord(timestamp: t0.add(Duration(seconds: i))),
            for (var i = 0; i < 30; i++)
              logRecord(timestamp: t0.add(Duration(hours: 1, seconds: i))),
            logRecord(timestamp: t0.add(const Duration(hours: 2))),
            logRecord(timestamp: t0.add(const Duration(hours: 3))),
          ],
        ),
      );

      // The median minute is quiet, so both busy minutes stand out.
      expect(digest.errorBursts.map((b) => b.count), [30, 12]);
      expect(digest.errorBursts.first.minute, t0.add(const Duration(hours: 1)));
    });

    test('a busy baseline raises the bar', () {
      final digest = builder.build(
        input(
          records: [
            for (var minute = 0; minute < 6; minute++)
              for (var i = 0; i < 8; i++)
                logRecord(
                  timestamp: t0.add(Duration(minutes: minute, seconds: i)),
                ),
            for (var i = 0; i < 20; i++)
              logRecord(timestamp: t0.add(Duration(minutes: 30, seconds: i))),
          ],
        ),
      );
      // 20 is twice the busy median of 8, not three times.
      expect(digest.errorBursts, isEmpty);
    });

    test('a steady trickle is not a burst', () {
      final digest = builder.build(
        input(
          records: [
            for (var i = 0; i < 20; i++)
              logRecord(timestamp: t0.add(Duration(minutes: i))),
          ],
        ),
      );
      expect(digest.errorBursts, isEmpty);
    });

    test('no errors means no bursts', () {
      expect(builder.build(input()).errorBursts, isEmpty);
    });
  });
}
