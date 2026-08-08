// Merges goal-agent eval JSON artifacts (one per model×sample process, as
// written by goal_agent_eval_live_test.dart) into a single markdown report:
// leaderboard, scenario×model matrix, failures, and observed cost with the
// cost-per-goal-month extrapolation.
//
// Usage:
//   fvm dart run tool/goal_agent_eval_report.dart eval_artifacts/goal_agent_*.json
//
// Pure Dart on purpose: runnable without a Flutter context, testable from
// test/tool/goal_agent_eval_report_test.dart.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final paths = args.where((arg) => !arg.startsWith('--')).toList();
  if (paths.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/goal_agent_eval_report.dart <artifact.json>...',
    );
    exitCode = 2;
    return;
  }
  final missing = paths.where((path) => !File(path).existsSync()).toList();
  if (missing.isNotEmpty) {
    // An unexpanded glob lands here verbatim when no artifact was written —
    // i.e. every eval process failed before producing a report.
    stderr.writeln(
      'No such artifact file(s): ${missing.join(', ')}. '
      'Did every eval process fail before writing its JSON?',
    );
    exitCode = 2;
    return;
  }
  final artifacts = [
    for (final path in paths)
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
  ];
  stdout.write(buildGoalAgentEvalMergedReport(artifacts));
}

/// Builds the merged markdown report from parsed artifact JSON maps.
String buildGoalAgentEvalMergedReport(List<Map<String, dynamic>> artifacts) {
  final results = <Map<String, dynamic>>[
    for (final artifact in artifacts)
      ...(artifact['results']! as List).cast<Map<String, dynamic>>(),
  ];
  final modelIds = {
    for (final result in results) result['modelId']! as String,
  }.toList()..sort();
  final scenarioIds = <String>[];
  for (final result in results) {
    final id = result['scenarioId']! as String;
    if (!scenarioIds.contains(id)) scenarioIds.add(id);
  }
  final wakesPerDay = artifacts.isEmpty
      ? 3
      : artifacts.first['wakesPerDayAssumption'] as int? ?? 3;

  Iterable<Map<String, dynamic>> casesFor(
    String modelId, [
    String? scenarioId,
  ]) => results.where(
    (r) =>
        r['modelId'] == modelId &&
        (scenarioId == null || r['scenarioId'] == scenarioId),
  );

  double? sumOf(Iterable<Map<String, dynamic>> cases, String key) {
    final values = cases
        .map((r) => r[key])
        .whereType<num>()
        .map((v) => v.toDouble())
        .toList();
    return values.isEmpty ? null : values.reduce((a, b) => a + b);
  }

  final buffer = StringBuffer()
    ..writeln('# Goal-agent eval — merged report')
    ..writeln()
    ..writeln(
      '${artifacts.length} artifact(s), ${results.length} cases, '
      '${modelIds.length} model(s), ${scenarioIds.length} scenario(s).',
    )
    ..writeln()
    ..writeln('## Leaderboard (objective checks only)')
    ..writeln()
    ..writeln(
      '| Model | Cases | Pass | Pass rate | Credits | '
      'Credits/goal-month* | Wh | Wh/goal-month* |',
    )
    ..writeln('| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |');

  final ranked = [...modelIds]
    ..sort((a, b) {
      double rate(String modelId) {
        final cases = casesFor(modelId).toList();
        if (cases.isEmpty) return 0;
        return cases.where((r) => r['passed'] == true).length / cases.length;
      }

      return rate(b).compareTo(rate(a));
    });
  for (final modelId in ranked) {
    final cases = casesFor(modelId).toList();
    final passedCount = cases.where((r) => r['passed'] == true).length;
    final credits = sumOf(cases, 'credits');
    final perGoalMonth = credits == null || cases.isEmpty
        ? null
        : credits / cases.length * wakesPerDay * 30;
    final energyWh = sumOf(cases, 'energyWh');
    final energyPerGoalMonth = energyWh == null || cases.isEmpty
        ? null
        : energyWh / cases.length * wakesPerDay * 30;
    final rate = cases.isEmpty
        ? '—'
        : (passedCount / cases.length).toStringAsFixed(2);
    buffer.writeln(
      '| `$modelId` | ${cases.length} | $passedCount | $rate | '
      '${credits?.toStringAsFixed(4) ?? 'not reported'} | '
      '${perGoalMonth?.toStringAsFixed(4) ?? 'not reported'} | '
      '${energyWh?.toStringAsFixed(2) ?? 'not reported'} | '
      '${energyPerGoalMonth?.toStringAsFixed(1) ?? 'not reported'} |',
    );
  }

  buffer
    ..writeln()
    ..writeln('## Scenario × model matrix')
    ..writeln()
    ..writeln('| Scenario | ${ranked.map((m) => '`$m`').join(' | ')} |')
    ..writeln('| --- |${' ---: |' * ranked.length}');
  for (final scenarioId in scenarioIds) {
    final cells = ranked.map((modelId) {
      final cases = casesFor(modelId, scenarioId).toList();
      if (cases.isEmpty) return '—';
      final passedCount = cases.where((r) => r['passed'] == true).length;
      return '$passedCount/${cases.length}';
    });
    buffer.writeln('| $scenarioId | ${cells.join(' | ')} |');
  }

  buffer
    ..writeln()
    ..writeln('## Failures')
    ..writeln();
  final failures = results.where((r) => r['passed'] != true).toList();
  if (failures.isEmpty) {
    buffer.writeln('None.');
  }
  for (final failure in failures) {
    final toolNames = ((failure['toolCalls'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((call) => call['name'])
        .join(', ');
    buffer.writeln(
      '- ${failure['scenarioId']} × `${failure['modelId']}` — '
      '${failure['failureCategory']}'
      '${toolNames.isEmpty ? '' : ' (tools: $toolNames)'}'
      '${failure['errorMessage'] == null ? '' : ' — ${failure['errorMessage']}'}',
    );
  }

  buffer
    ..writeln()
    ..writeln(
      '*Per-goal-month figures extrapolate the per-case mean × '
      '$wakesPerDay LLM wakes/day × 30 days. The wakes/day figure is a '
      'printed assumption, not a measurement; deterministic Phase A ticks '
      'and procedural banner rendering (ADR 0058) cost nothing. All '
      'figures are observations for monitoring — never targets or caps. '
      '"not reported" means the provider returned no data, not that the '
      'run was free.',
    );
  return buffer.toString();
}
