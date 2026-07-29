import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fallbacks.dart';
import 'day_agent_wake_benchmark.dart';
import 'day_planner_corpus.dart';

final bool wakeBenchmarkEnabled =
    const String.fromEnvironment('LOTTI_BENCHMARK').isNotEmpty ||
    const bool.fromEnvironment('LOTTI_BENCHMARK');

void main() {
  setUpAll(registerAllFallbackValues);

  test('the full-workflow harness produces every wake metric', () async {
    final report = await DayAgentWakeBenchmark(days: 2).run();

    expect(
      report.keys,
      unorderedEquals(['parse', 'draft', 'refine', 'digest']),
    );
    for (final metric in report.values) {
      expect(metric.promptBytes, greaterThan(0));
      expect(metric.stablePrefixBytes, greaterThan(0));
      expect(metric.stablePrefixBytes, lessThan(metric.promptBytes));
      expect(metric.inputTokens, greaterThan(0));
      expect(metric.outputTokens, greaterThan(0));
      expect(metric.durationMicros, greaterThan(0));
      expect(metric.agentRepositoryReads, greaterThan(0));
    }
    expect(report['parse']!.outputTokenCeiling, 4096);
    expect(report['draft']!.outputTokenCeiling, 8192);
    expect(report['refine']!.outputTokenCeiling, 4096);
    expect(report['digest']!.outputTokenCeiling, 4096);
    expect(report['parse']!.providerTurns, 1);
    expect(report['draft']!.providerTurns, 1);
    expect(report['refine']!.providerTurns, 2);
    expect(report['digest']!.providerTurns, 2);
  });

  test('aged production plans and rollups reach model prompts', () async {
    final benchmark = DayAgentWakeBenchmark(days: 15);

    await benchmark.run();

    expect(
      benchmark.modelPrompts['draft'],
      contains('Mon Jan 14 — draft plan.'),
    );
    expect(
      benchmark.modelPrompts['digest'],
      contains(r'\"daysWithPlans\": 7'),
    );
  });

  test(
    'wake prompt and token cost across 1, 6 and 12 simulated months',
    () async {
      final reports = <String, Map<String, DayAgentWakeMetric>>{};
      for (final corpus in dayPlannerBenchmarkCorpora.entries) {
        reports[corpus.key] = await DayAgentWakeBenchmark(
          days: corpus.value,
        ).run();
      }

      final buffer = StringBuffer()
        ..writeln()
        ..writeln('Day-agent full-workflow cost by simulated install age')
        ..writeln();
      final header = [
        'wake.metric',
        ...dayPlannerBenchmarkCorpora.keys,
      ].join(' | ');
      buffer
        ..writeln(header)
        ..writeln('-' * header.length);
      for (final wake in ['parse', 'draft', 'refine', 'digest']) {
        for (final metricName in [
          'promptBytes',
          'stablePrefixBytes',
          'inputTokens',
          'outputTokens',
          'durationMicros',
          'agentRepositoryReads',
          'outputTokenCeiling',
          'providerTurns',
        ]) {
          buffer.writeln(
            [
              '$wake.$metricName',
              for (final label in dayPlannerBenchmarkCorpora.keys)
                '${reports[label]![wake]!.toJson()[metricName]}',
            ].join(' | '),
          );
        }
      }
      // ignore: avoid_print
      print(buffer);

      for (final report in reports.values) {
        expect(
          report.keys,
          unorderedEquals(['parse', 'draft', 'refine', 'digest']),
        );
      }
    },
    skip: wakeBenchmarkEnabled
        ? false
        : 'Full-workflow corpus benchmark is opt-in: run with '
              '--dart-define=LOTTI_BENCHMARK=1.',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
