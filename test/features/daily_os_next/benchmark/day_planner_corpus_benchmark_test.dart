import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';

import 'day_planner_corpus.dart';

/// Set to run the full 1/6/12-month sweep:
///
/// ```sh
/// LOTTI_BENCHMARK=1 fvm flutter test \
///   test/features/daily_os_next/benchmark/
/// ```
///
/// Opt-in because the full timing sweep repeatedly seeds thousands of rows and
/// runs noisy stopwatch samples — worth the seconds when you want the numbers,
/// not worth them on every CI run. The deterministic growth gate below always
/// runs.
final bool benchmarkEnabled =
    const String.fromEnvironment('LOTTI_BENCHMARK').isNotEmpty ||
    const bool.fromEnvironment('LOTTI_BENCHMARK');

Future<Map<String, int>> _runCorpus(int days) async {
  final agentDb = AgentDatabase(inMemoryDatabase: true, background: false);
  final processingDb = DayProcessingDb(inMemoryDatabase: true);
  addTearDown(agentDb.close);
  addTearDown(processingDb.close);

  final corpus = DayPlannerCorpus(
    agentDb: agentDb,
    processingDb: processingDb,
    days: days,
  );
  await corpus.seed();
  return {...await corpus.counts(), ...await corpus.measure()};
}

Future<Map<String, int>> _runOperationCorpus(int days) async {
  final agentDb = AgentDatabase(inMemoryDatabase: true, background: false);
  final processingDb = DayProcessingDb(
    inMemoryDatabase: true,
    background: false,
  );
  addTearDown(agentDb.close);
  addTearDown(processingDb.close);

  final corpus = DayPlannerCorpus(
    agentDb: agentDb,
    processingDb: processingDb,
    days: days,
  );
  await corpus.seed();
  return corpus.operationCosts();
}

void _expectNoHistoryGrowth({
  required String metric,
  required Map<String, int> oneMonth,
  required Map<String, int> twelveMonths,
}) {
  final baseline = oneMonth[metric];
  final aged = twelveMonths[metric];
  expect(
    baseline,
    isNotNull,
    reason: '$metric is missing from the 1-month run',
  );
  expect(aged, isNotNull, reason: '$metric is missing from the 12-month run');
  expect(
    aged,
    lessThanOrEqualTo(baseline!),
    reason:
        '$metric grew with retained history: 1 month=$baseline, '
        '12 months=$aged',
  );
}

void main() {
  test('the harness produces its full metric set', () async {
    // Deliberately tiny: this asserts the harness still measures what it
    // claims to, so a renamed repository method breaks here rather than
    // silently dropping a column from a report nobody reads closely.
    final result = await _runCorpus(2);

    expect(
      result.keys,
      containsAll(<String>[
        'days',
        'agentEntities',
        'processingJobs',
        'outbox.claimNext',
        'dayView.captures',
        'dayView.statusEvents',
        'dayView.plannerOwnsDay',
        'planEditor.pendingDiffs',
        'planWriter.lookback',
      ]),
    );
    expect(result['days'], 2);
    // Two days of the documented per-day shape: plan + 3 captures + 6 status
    // events + 2 change sets.
    expect(result['agentEntities'], 2 * (1 + 3 + 6 + 2));
    expect(result['processingJobs'], 2 * 3);
  });

  test('query-plan classifier requires bounded retained-history indexes', () {
    expect(
      DayPlannerCorpus.debugIsUnboundedHistoryPlanDetail(
        'SCAN agent_entities',
      ),
      isTrue,
    );
    expect(
      DayPlannerCorpus.debugIsUnboundedHistoryPlanDetail(
        'SEARCH agent_entities USING INDEX idx_agent_entities_agent_id',
      ),
      isTrue,
    );
    expect(
      DayPlannerCorpus.debugIsUnboundedHistoryPlanDetail(
        'SEARCH agent_entities USING INDEX '
        'idx_agent_entities_active_agent_type_sub_created_id',
      ),
      isFalse,
    );
    expect(
      DayPlannerCorpus.debugIsUnboundedHistoryPlanDetail(
        'SCAN agent_entities USING INDEX '
        'idx_agent_entities_active_agent_type_sub_created_id',
      ),
      isTrue,
    );
    expect(
      DayPlannerCorpus.debugIsUnboundedHistoryPlanDetail(
        'SCAN day_processing_jobs USING INDEX '
        'idx_day_processing_jobs_retention',
      ),
      isTrue,
    );
    expect(
      DayPlannerCorpus.debugIsUnboundedHistoryPlanDetail(
        'SCAN day_processing_jobs USING INDEX '
        'idx_day_processing_jobs_pending',
      ),
      isFalse,
    );
    expect(
      DayPlannerCorpus.debugIsUnboundedHistoryPlanDetail(
        'SCAN day_processing_jobs USING INDEX '
        'sqlite_autoindex_day_processing_jobs_1',
      ),
      isTrue,
    );
    expect(
      DayPlannerCorpus.debugIsUnboundedHistoryPlanDetail(
        'SEARCH day_processing_jobs USING INDEX '
        'sqlite_autoindex_day_processing_jobs_1 (id=?)',
      ),
      isFalse,
    );
  });

  test('SQL counter observes every executor statement hook', () async {
    final db = AgentDatabase(inMemoryDatabase: true, background: false);
    addTearDown(db.close);
    final counter = SqlOperationCounter();

    await db.runWithInterceptor(() async {
      await db.customStatement(
        'CREATE TEMP TABLE operation_probe '
        '(id INTEGER PRIMARY KEY, value TEXT NOT NULL)',
      );
      await db.customInsert(
        'INSERT INTO operation_probe (id, value) VALUES (?1, ?2)',
        variables: [
          const Variable<int>(1),
          const Variable<String>('one'),
        ],
      );
      await db.customUpdate(
        'UPDATE operation_probe SET value = ?1 WHERE id = ?2',
        variables: [
          const Variable<String>('updated'),
          const Variable<int>(1),
        ],
      );
      await db.customSelect('SELECT value FROM operation_probe').get();
      await db.batch((batch) {
        batch
          ..customStatement(
            'INSERT INTO operation_probe (id, value) VALUES (?, ?)',
            [2, 'two'],
          )
          ..customStatement(
            'INSERT INTO operation_probe (id, value) VALUES (?, ?)',
            [3, 'three'],
          );
      });
      await (db.delete(
        db.agentEntities,
      )..where((row) => row.id.equals('missing'))).go();
    }, interceptor: counter);

    expect(counter.statements, 7);
    expect(counter.rowsReturned, 1);
  });

  test(
    'current-day storage operations do not grow from 1 to 12 months',
    () async {
      final oneMonth = await _runOperationCorpus(
        dayPlannerBenchmarkCorpora['1 month']!,
      );
      final twelveMonths = await _runOperationCorpus(
        dayPlannerBenchmarkCorpora['12 months']!,
      );

      expect(oneMonth, {
        'outbox.claimNext.statements': 1,
        'outbox.claimNext.rowsReturned': 1,
        'outbox.claimNext.unboundedPlanSteps': 0,
        'dayView.captures.statements': 1,
        'dayView.captures.rowsReturned': DayPlannerCorpus.capturesPerDay,
        'dayView.captures.unboundedPlanSteps': 0,
        'dayView.statusEvents.statements': 1,
        'dayView.statusEvents.rowsReturned':
            DayPlannerCorpus.statusEventsPerDay,
        'dayView.statusEvents.unboundedPlanSteps': 0,
        'dayView.plannerOwnsDay.statements': 1,
        'dayView.plannerOwnsDay.rowsReturned': 1,
        'dayView.plannerOwnsDay.unboundedPlanSteps': 0,
        'planEditor.pendingDiffs.statements': 1,
        'planEditor.pendingDiffs.rowsReturned': 0,
        'planEditor.pendingDiffs.unboundedPlanSteps': 0,
        'planWriter.lookback.statements': 1,
        'planWriter.lookback.rowsReturned': 7,
        'planWriter.lookback.unboundedPlanSteps': 0,
      });

      // Zero additional statements, rows and unbounded query-plan steps is
      // the deliberate threshold:
      // both corpora have the same three captures, six status events, one
      // ownership row, empty pending-diff set, seven-day lookback and pending
      // outbox head. Only terminal history grows, so any positive delta means
      // a user action has started reading or querying retained history.
      for (final metric in oneMonth.keys) {
        _expectNoHistoryGrowth(
          metric: metric,
          oneMonth: oneMonth,
          twelveMonths: twelveMonths,
        );
      }
      expect(
        twelveMonths.keys,
        unorderedEquals(oneMonth.keys),
        reason:
            'The 1-month and 12-month operation reports must cover the '
            'same metrics.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'per-action cost across 1, 6 and 12 simulated months',
    () async {
      final reports = <String, Map<String, int>>{};
      for (final entry in dayPlannerBenchmarkCorpora.entries) {
        reports[entry.key] = await _runCorpus(entry.value);
      }

      final metrics = reports.values.first.keys
          .where((key) => key.contains('.'))
          .toList();
      final buffer = StringBuffer()
        ..writeln()
        ..writeln('Day planner cost by simulated install age (microseconds)')
        ..writeln();
      final header = [
        'metric',
        ...dayPlannerBenchmarkCorpora.keys,
      ].join(' | ');
      buffer
        ..writeln(header)
        ..writeln('-' * header.length);
      for (final metric in metrics) {
        buffer.writeln(
          [
            metric,
            for (final label in dayPlannerBenchmarkCorpora.keys)
              '${reports[label]![metric]}',
          ].join(' | '),
        );
      }
      buffer.writeln();
      for (final entry in reports.entries) {
        buffer.writeln(
          '${entry.key}: ${entry.value['agentEntities']} agent entities, '
          '${entry.value['processingJobs']} processing jobs',
        );
      }
      // ignore: avoid_print
      print(buffer);

      // The report is the deliverable; assert only that every corpus produced
      // a full row, so a silently-failing measurement cannot masquerade as a
      // fast one.
      for (final report in reports.values) {
        for (final metric in metrics) {
          expect(report[metric], isNotNull);
        }
      }
    },
    skip: benchmarkEnabled
        ? false
        : 'Corpus benchmark is opt-in: run with '
              '--dart-define=LOTTI_BENCHMARK=1 (seeding 12 simulated months '
              'writes thousands of rows).',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
