// Merges agent-eval JSON artifacts (one per model×sample process, as written
// by the goal- and relationship-agent live eval drivers) into a single
// markdown report: leaderboard, scenario×model matrix, failures, and observed
// cost with the cost-per-subject-month extrapolation.
//
// One merger rather than one per agent: the artifacts already share a shape
// (kind / results / modelId / scenarioId / wakesPerDayAssumption), and the
// only things that legitimately differ are the subject noun a wake is billed
// against and its wakes-per-day default. Both are derived from the artifact
// `kind`, so a new suite registers a row in [_subjects] instead of forking
// this file.
//
// Usage:
//   fvm dart run tool/agent_eval_report.dart eval_artifacts/goal_agent_*.json
//   fvm dart run tool/agent_eval_report.dart eval_artifacts/relationship_agent_*.json
//
// Pure Dart on purpose: runnable without a Flutter context, testable from
// test/tool/agent_eval_report_test.dart.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final paths = args.where((arg) => !arg.startsWith('--')).toList();
  if (paths.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/agent_eval_report.dart <artifact.json>...',
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
  stdout.write(buildAgentEvalMergedReport(artifacts));
}

/// What a suite is billed against, derived from the artifact `kind`.
///
/// The noun drives every per-month column and the printed assumption; the
/// wakes-per-day default only applies to artifacts written before the field
/// existed, and matches each live driver's own default.
class _EvalSubject {
  const _EvalSubject({
    required this.title,
    required this.noun,
    required this.defaultWakesPerDay,
  });

  final String title;
  final String noun;
  final int defaultWakesPerDay;
}

const _subjects = <String, _EvalSubject>{
  'lotti.goalAgentInferenceEvalReport': _EvalSubject(
    title: 'Goal-agent eval',
    noun: 'goal',
    defaultWakesPerDay: 3,
  ),
  'lotti.goalAgentOutcomeEvalReport': _EvalSubject(
    title: 'Goal-agent outcome eval',
    noun: 'goal',
    defaultWakesPerDay: 3,
  ),
  'lotti.relationshipAgentInferenceEvalReport': _EvalSubject(
    title: 'Relationship-agent eval',
    noun: 'relationship',
    defaultWakesPerDay: 1,
  ),
};

/// Thrown when the artifact list cannot be merged into one honest report.
class AgentEvalMergeException implements Exception {
  const AgentEvalMergeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Builds the merged markdown report from parsed artifact JSON maps.
///
/// Throws [AgentEvalMergeException] when the artifacts do not all come from
/// the same suite: merging a goal run into a relationship run would average
/// two different subjects into one per-month column and one leaderboard, and
/// the resulting table would read as a measurement rather than a mistake.
/// Same-suite artifacts that disagree about `wakesPerDayAssumption` are
/// refused for the same reason — the assumption multiplies every per-month
/// figure, so mixing two of them produces a column true of neither run.
String buildAgentEvalMergedReport(List<Map<String, dynamic>> artifacts) {
  final kinds = {
    for (final artifact in artifacts) artifact['kind'] as String? ?? 'unknown',
  };
  if (kinds.length > 1) {
    throw AgentEvalMergeException(
      'Refusing to merge artifacts of different kinds: '
      '${(kinds.toList()..sort()).join(', ')}. Merge each suite separately.',
    );
  }
  final kind = kinds.isEmpty ? 'unknown' : kinds.first;
  final subject = _subjects[kind];
  if (subject == null) {
    throw AgentEvalMergeException(
      'Unknown eval artifact kind "$kind". Known kinds: '
      '${(_subjects.keys.toList()..sort()).join(', ')}.',
    );
  }
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
  // Every per-month column is this number times a per-wake figure, so two
  // artifacts that disagree about it cannot be averaged into one honest
  // column — and taking the first artifact's value would make the report
  // depend on the order the files happened to be listed in. Refuse, the way
  // a mixed-kind merge is refused.
  final assumptions = {
    for (final artifact in artifacts)
      artifact['wakesPerDayAssumption'] as int? ?? subject.defaultWakesPerDay,
  };
  if (assumptions.length > 1) {
    throw AgentEvalMergeException(
      'Refusing to merge artifacts with different wakes/day assumptions: '
      '${(assumptions.toList()..sort()).join(', ')}. '
      'Report each assumption separately.',
    );
  }
  final wakesPerDay = assumptions.isEmpty
      ? subject.defaultWakesPerDay
      : assumptions.first;

  Iterable<Map<String, dynamic>> casesFor(
    String modelId, [
    String? scenarioId,
  ]) => results.where(
    (r) =>
        r['modelId'] == modelId &&
        (scenarioId == null || r['scenarioId'] == scenarioId),
  );

  /// Sum and reporting count for [key] — per-month figures divide by the
  /// REPORTED count: missing telemetry widens uncertainty, it never
  /// masquerades as zero.
  (double, int)? sumOf(Iterable<Map<String, dynamic>> cases, String key) {
    final values = cases
        .map((r) => r[key])
        .whereType<num>()
        .map((v) => v.toDouble())
        .toList();
    if (values.isEmpty) return null;
    return (values.reduce((a, b) => a + b), values.length);
  }

  final buffer = StringBuffer()
    ..writeln('# ${subject.title} — merged report')
    ..writeln()
    ..writeln(
      '${artifacts.length} artifact(s), ${results.length} cases, '
      '${modelIds.length} model(s), ${scenarioIds.length} scenario(s).',
    )
    ..writeln()
    ..writeln('## Leaderboard (objective checks only)')
    ..writeln()
    ..writeln(
      '| Model | Cases | Pass | Pass rate | Mean in | Mean out | Credits | '
      'Credits/${subject.noun}-month* | Wh | Wh/${subject.noun}-month* | '
      'Mean latency | '
      'P95 latency |',
    )
    ..writeln(
      '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | '
      '---: | ---: | ---: |',
    );

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
    final creditsSum = sumOf(cases, 'credits');
    final credits = creditsSum?.$1;
    final inputTokens = sumOf(cases, 'inputTokens');
    final outputTokens = sumOf(cases, 'outputTokens');
    final latencyValues = cases
        .map((result) => result['latencyMs'])
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList();
    final perSubjectMonth = creditsSum == null
        ? null
        : creditsSum.$1 / creditsSum.$2 * wakesPerDay * 30;
    final energySum = sumOf(cases, 'energyWh');
    final energyWh = energySum?.$1;
    final energyPerSubjectMonth = energySum == null
        ? null
        : energySum.$1 / energySum.$2 * wakesPerDay * 30;
    final rate = cases.isEmpty
        ? '—'
        : (passedCount / cases.length).toStringAsFixed(2);
    buffer.writeln(
      '| `$modelId` | ${cases.length} | $passedCount | $rate | '
      '${_meanCount(inputTokens)} | ${_meanCount(outputTokens)} | '
      '${credits?.toStringAsFixed(4) ?? 'not reported'} | '
      '${perSubjectMonth?.toStringAsFixed(4) ?? 'not reported'} | '
      '${energyWh?.toStringAsFixed(2) ?? 'not reported'} | '
      '${energyPerSubjectMonth?.toStringAsFixed(1) ?? 'not reported'} | '
      '${_meanDuration(latencyValues)} | ${_p95Duration(latencyValues)} |',
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
      '*Per-${subject.noun}-month figures extrapolate the per-case mean × '
      '$wakesPerDay LLM wakes/day × 30 days. The wakes/day figure is a '
      'printed assumption, not a measurement; deterministic Phase A ticks '
      'and procedural banner rendering (ADR 0058) cost nothing. All '
      'figures are observations for monitoring — never targets or caps. '
      '"not reported" means the provider returned no data, not that the '
      'run was free. Latency is wall-clock time per scenario, including '
      'every follow-up turn.',
    );
  return buffer.toString();
}

String _meanCount((double, int)? totalAndCount) => totalAndCount == null
    ? 'not reported'
    : (totalAndCount.$1 / totalAndCount.$2).round().toString();

String _meanDuration(List<double> milliseconds) {
  if (milliseconds.isEmpty) return 'not reported';
  final mean = milliseconds.reduce((a, b) => a + b) / milliseconds.length;
  return _formatDuration(mean);
}

String _p95Duration(List<double> milliseconds) {
  if (milliseconds.isEmpty) return 'not reported';
  final sorted = [...milliseconds]..sort();
  final index = (sorted.length * 0.95).ceil() - 1;
  return _formatDuration(sorted[index]);
}

String _formatDuration(double milliseconds) =>
    '${(milliseconds / 1000).toStringAsFixed(2)}s';
