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
/// Opt-in because seeding twelve simulated months writes tens of thousands of
/// rows — worth the seconds when you want the numbers, not worth them on every
/// CI run. The smoke test below always runs so the harness itself cannot rot.
final bool benchmarkEnabled =
    const String.fromEnvironment('LOTTI_BENCHMARK').isNotEmpty ||
    const bool.fromEnvironment('LOTTI_BENCHMARK');

/// Corpus ages to compare, in days.
const Map<String, int> _corpora = {
  '1 month': 30,
  '6 months': 182,
  '12 months': 365,
};

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

  test(
    'per-action cost across 1, 6 and 12 simulated months',
    () async {
      final reports = <String, Map<String, int>>{};
      for (final entry in _corpora.entries) {
        reports[entry.key] = await _runCorpus(entry.value);
      }

      final metrics = reports.values.first.keys
          .where((key) => key.contains('.'))
          .toList();
      final buffer = StringBuffer()
        ..writeln()
        ..writeln('Day planner cost by simulated install age (microseconds)')
        ..writeln();
      final header = ['metric', ..._corpora.keys].join(' | ');
      buffer
        ..writeln(header)
        ..writeln('-' * header.length);
      for (final metric in metrics) {
        buffer.writeln(
          [
            metric,
            for (final label in _corpora.keys) '${reports[label]![metric]}',
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
              'writes tens of thousands of rows).',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
