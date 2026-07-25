import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/day_plan.dart';
import 'package:meta/meta.dart';

import 'eval_constraints.dart';
import 'eval_runner.dart';
import 'eval_variant.dart';

/// Aggregates matrix results into a report, and into a bundle a human (or
/// Opus 5 reading the repo) can judge plan *quality* from without re-running.
///
/// The constraint scorers deliberately cover only what is objectively
/// checkable. Whether a day is sensible — the ordering, the realism, whether
/// it is overpacked-but-legal — is not one of those things, and an in-harness
/// LLM judge would bake scoring noise and cost into every run while saying
/// little you can act on. So the report's job is to make the run legible
/// enough that judgement can happen afterwards, from artifacts alone.

/// One constraint's outcome across a set of runs.
///
/// [applicable] is the denominator, and it is not the run count: a constraint
/// that did not apply is neither a pass nor a fail. Reporting `passed/total`
/// would let a scenario that never exercised a dimension inflate the score of
/// a model that never demonstrated anything about it.
@immutable
class EvalConstraintRate {
  const EvalConstraintRate({
    required this.constraintId,
    required this.passed,
    required this.applicable,
  });

  final String constraintId;
  final int passed;
  final int applicable;

  /// Null when nothing exercised this constraint — rendered as `—`, never as
  /// 100%.
  double? get rate => applicable == 0 ? null : passed / applicable;

  String get label => rate == null
      ? '—'
      : '${(rate! * 100).toStringAsFixed(0)}% ($passed/$applicable)';
}

/// Aggregation helper shared by every table in the report.
EvalConstraintRate _rateFor(
  String constraintId,
  Iterable<EvalRunResult> results,
) {
  var passed = 0;
  var applicable = 0;
  for (final result in results) {
    for (final constraint in result.constraints) {
      if (constraint.id != constraintId) continue;
      if (!constraint.isApplicable) continue;
      applicable++;
      if (constraint.passed ?? false) passed++;
    }
  }
  return EvalConstraintRate(
    constraintId: constraintId,
    passed: passed,
    applicable: applicable,
  );
}

/// A model's headline standing.
@immutable
class EvalModelStanding {
  const EvalModelStanding({
    required this.modelId,
    required this.runs,
    required this.failedRuns,
    required this.overall,
    required this.byConstraint,
  });

  final String modelId;
  final int runs;

  /// Runs that ended in an exception rather than a scored plan.
  final int failedRuns;

  /// Pass rate across every applicable constraint result the model produced.
  final EvalConstraintRate overall;
  final List<EvalConstraintRate> byConstraint;
}

/// Cost and prompt size for one (model, scenario) pair.
@immutable
class EvalCostRow {
  const EvalCostRow({
    required this.modelId,
    required this.scenarioId,
    required this.runs,
    required this.meanLatencyMs,
    required this.inputTokens,
    required this.outputTokens,
    required this.thoughtsTokens,
    required this.cachedInputTokens,
    required this.meanPromptBytes,
  });

  final String modelId;
  final String scenarioId;
  final int runs;
  final int meanLatencyMs;
  final int inputTokens;
  final int outputTokens;
  final int thoughtsTokens;
  final int cachedInputTokens;

  /// Mean bytes of system + user prompts actually sent.
  final int meanPromptBytes;
}

/// One violation, with enough context to act on.
@immutable
class EvalFailureExcerpt {
  const EvalFailureExcerpt({
    required this.cell,
    required this.constraintId,
    required this.detail,
    required this.rejections,
  });

  final String cell;
  final String constraintId;

  /// The scorer's own account — names the offending block or task.
  final String detail;

  /// Rejection text the model was handed, which is where a guarded constraint
  /// is actually observable.
  final List<String> rejections;
}

/// The report.
@immutable
class EvalReport {
  const EvalReport({
    required this.results,
    required this.standings,
    required this.costRows,
    required this.failures,
    required this.bundleSamplesPerCell,
    required this.bundledCells,
    required this.droppedSamples,
    required this.generatedAt,
  });

  /// Builds a report from one matrix run.
  ///
  /// [bundleSamplesPerCell] bounds the judge bundle so the whole thing stays
  /// readable in one pass; the highest sample indices are kept, and whatever
  /// was dropped is counted and stated in the output rather than silently
  /// omitted.
  factory EvalReport.fromResults(
    List<EvalRunResult> results, {
    required DateTime generatedAt,
    int bundleSamplesPerCell = 2,
  }) {
    if (bundleSamplesPerCell < 1) {
      throw RangeError.value(
        bundleSamplesPerCell,
        'bundleSamplesPerCell',
        'must be at least 1',
      );
    }
    final modelIds = <String>{
      for (final r in results) r.request.modelId,
    }.toList()..sort();
    final standings =
        [
          for (final modelId in modelIds)
            _standingFor(
              modelId,
              results.where((r) => r.request.modelId == modelId),
            ),
        ]..sort((a, b) {
          final left = a.overall.rate;
          final right = b.overall.rate;
          if (left == null && right == null) {
            return a.modelId.compareTo(b.modelId);
          }
          if (left == null) return 1;
          if (right == null) return -1;
          final byRate = right.compareTo(left);
          // Deterministic ties, or the leaderboard reorders itself between runs
          // that measured exactly the same thing.
          return byRate != 0 ? byRate : a.modelId.compareTo(b.modelId);
        });

    final cells = _groupIntoCells(results);
    var dropped = 0;
    for (final samples in cells.values) {
      if (samples.length > bundleSamplesPerCell) {
        dropped += samples.length - bundleSamplesPerCell;
      }
    }

    return EvalReport(
      results: List.unmodifiable(results),
      standings: List.unmodifiable(standings),
      costRows: List.unmodifiable(_costRows(results)),
      failures: List.unmodifiable(_failures(results)),
      bundleSamplesPerCell: bundleSamplesPerCell,
      bundledCells: cells.length,
      droppedSamples: dropped,
      generatedAt: generatedAt,
    );
  }

  final List<EvalRunResult> results;

  /// Leaderboard, best first.
  final List<EvalModelStanding> standings;
  final List<EvalCostRow> costRows;
  final List<EvalFailureExcerpt> failures;

  final int bundleSamplesPerCell;
  final int bundledCells;

  /// Samples the cap excluded. Stated in the output so a truncated bundle can
  /// never be mistaken for a complete one.
  final int droppedSamples;

  final DateTime generatedAt;

  static EvalModelStanding _standingFor(
    String modelId,
    Iterable<EvalRunResult> runs,
  ) {
    final list = runs.toList();
    var passed = 0;
    var applicable = 0;
    for (final result in list) {
      for (final constraint in result.constraints) {
        if (!constraint.isApplicable) continue;
        applicable++;
        if (constraint.passed ?? false) passed++;
      }
    }
    return EvalModelStanding(
      modelId: modelId,
      runs: list.length,
      failedRuns: list.where((r) => r.failed).length,
      overall: EvalConstraintRate(
        constraintId: 'overall',
        passed: passed,
        applicable: applicable,
      ),
      byConstraint: [
        for (final id in EvalConstraintIds.all) _rateFor(id, list),
      ],
    );
  }

  static List<EvalCostRow> _costRows(List<EvalRunResult> results) {
    // Keyed by the pair itself rather than a joined string: recovering the two
    // ids by splitting a key breaks the moment either contains a space, and
    // model ids come from an env var.
    final byPair = <(String, String), List<EvalRunResult>>{};
    for (final result in results) {
      final key = (result.request.modelId, result.request.scenario.id);
      byPair.putIfAbsent(key, () => []).add(result);
    }
    final keys = byPair.keys.toList()
      ..sort((a, b) {
        final byModel = a.$1.compareTo(b.$1);
        return byModel != 0 ? byModel : a.$2.compareTo(b.$2);
      });
    return [
      for (final key in keys)
        () {
          final runs = byPair[key]!;
          final events = runs.expand((r) => r.consumption);
          return EvalCostRow(
            modelId: key.$1,
            scenarioId: key.$2,
            runs: runs.length,
            meanLatencyMs: _mean(runs.map((r) => r.latency.inMilliseconds)),
            inputTokens: _sum(events.map((e) => e.inputTokens)),
            outputTokens: _sum(events.map((e) => e.outputTokens)),
            thoughtsTokens: _sum(events.map((e) => e.thoughtsTokens)),
            cachedInputTokens: _sum(events.map((e) => e.cachedInputTokens)),
            meanPromptBytes: _mean(runs.map(_promptBytes)),
          );
        }(),
    ];
  }

  static List<EvalFailureExcerpt> _failures(List<EvalRunResult> results) => [
    for (final result in results)
      for (final constraint in result.constraints)
        if (constraint.passed == false)
          EvalFailureExcerpt(
            cell: result.request.label,
            constraintId: constraint.id,
            detail: constraint.detail,
            rejections: [
              for (final call in result.outcome.rejections)
                '${call.name}: ${call.rejectionMessage ?? 'no message'}',
            ],
          ),
  ];

  /// The bundle, one entry per (scenario, model, variant, sample), capped.
  List<Map<String, Object?>> judgeBundle() {
    final cells = _groupIntoCells(results);
    final keys = cells.keys.toList()
      ..sort((a, b) {
        final byScenario = a.$1.compareTo(b.$1);
        if (byScenario != 0) return byScenario;
        final byModel = a.$2.compareTo(b.$2);
        return byModel != 0 ? byModel : a.$3.compareTo(b.$3);
      });
    return [
      for (final key in keys)
        ...(cells[key]!..sort(
              (a, b) => b.request.sample.compareTo(a.request.sample),
            ))
            .take(bundleSamplesPerCell)
            .map(_bundleEntry),
    ];
  }

  Map<String, Object?> toJson() => {
    'kind': 'lotti.dayPlanningEvalReport',
    'generatedAt': generatedAt.toIso8601String(),
    'runs': results.length,
    'bundle': {
      'samplesPerCell': bundleSamplesPerCell,
      'cells': bundledCells,
      'droppedSamples': droppedSamples,
    },
    'leaderboard': [
      for (final standing in standings)
        {
          'modelId': standing.modelId,
          'runs': standing.runs,
          'failedRuns': standing.failedRuns,
          'passed': standing.overall.passed,
          'applicable': standing.overall.applicable,
          'rate': standing.overall.rate,
          'byConstraint': {
            for (final rate in standing.byConstraint)
              rate.constraintId: {
                'passed': rate.passed,
                'applicable': rate.applicable,
                'rate': rate.rate,
              },
          },
        },
    ],
    'promptStability': [
      for (final standing in standings)
        () {
          final runs = results.where(
            (r) => r.request.modelId == standing.modelId,
          );
          final stable = _stablePrefixBytes(runs);
          final mean = _mean(
            runs.map((r) => utf8.encode(r.systemPrompt ?? '').length),
          );
          return {
            'modelId': standing.modelId,
            'wakes': runs.length,
            'meanSystemPromptBytes': mean,
            'stablePrefixBytes': stable,
            'stableFraction': mean == 0 ? null : stable / mean,
          };
        }(),
    ],
    'scenarioMatrix': _scenarioMatrixJson(),
    'variantDelta': _variantDeltaJson(),
    'cost': [
      for (final row in costRows)
        {
          'modelId': row.modelId,
          'scenarioId': row.scenarioId,
          'runs': row.runs,
          'meanLatencyMs': row.meanLatencyMs,
          'inputTokens': row.inputTokens,
          'outputTokens': row.outputTokens,
          'thoughtsTokens': row.thoughtsTokens,
          'cachedInputTokens': row.cachedInputTokens,
          'meanPromptBytes': row.meanPromptBytes,
        },
    ],
    'failures': [
      for (final failure in failures)
        {
          'cell': failure.cell,
          'constraintId': failure.constraintId,
          'detail': failure.detail,
          'rejections': failure.rejections,
        },
    ],
    'judgeBundle': judgeBundle(),
  };

  Map<String, Object?> _scenarioMatrixJson() {
    final scenarioIds = <String>{
      for (final r in results) r.request.scenario.id,
    }.toList()..sort();
    return {
      for (final standing in standings)
        standing.modelId: {
          for (final scenarioId in scenarioIds)
            scenarioId: {
              for (final id in EvalConstraintIds.all)
                id: _rateFor(
                  id,
                  results.where(
                    (r) =>
                        r.request.modelId == standing.modelId &&
                        r.request.scenario.id == scenarioId,
                  ),
                ).rate,
            },
        },
    };
  }

  /// Baseline vs each variant, per constraint, **within the same model**.
  ///
  /// Comparing across models would confound the two dimensions the matrix
  /// exists to separate.
  Map<String, Object?> _variantDeltaJson() {
    final variantIds = <String>{
      for (final r in results) r.request.variant.id,
    }.where((id) => id != evalBaselineVariantId).toList()..sort();
    return {
      for (final standing in standings)
        standing.modelId: {
          for (final variantId in variantIds)
            variantId: {
              for (final id in EvalConstraintIds.all)
                id: () {
                  final base = _rateFor(
                    id,
                    results.where(
                      (r) =>
                          r.request.modelId == standing.modelId &&
                          r.request.variant.id == evalBaselineVariantId,
                    ),
                  ).rate;
                  final variant = _rateFor(
                    id,
                    results.where(
                      (r) =>
                          r.request.modelId == standing.modelId &&
                          r.request.variant.id == variantId,
                    ),
                  ).rate;
                  // Null when either side never exercised the constraint: a
                  // delta against nothing is not a zero.
                  return base == null || variant == null
                      ? null
                      : variant - base;
                }(),
            },
        },
    };
  }

  Map<String, Object?> _bundleEntry(EvalRunResult result) {
    final scenario = result.request.scenario;
    final inputs = result.outcome.inputs;
    return {
      'cell': result.request.label,
      'scenario': {
        'id': scenario.id,
        // The judge needs to know what the scenario was trying to find out
        // before it can say whether the plan was a good answer.
        'intent': scenario.intent,
        'planDate': result.request.planDate.toIso8601String(),
        'capacityMinutes': inputs.capacityMinutes,
        'workingHours':
            '${inputs.workingHoursStartHour}:00-'
            '${inputs.workingHoursEndHour}:00',
        'draftedAt': inputs.now?.toIso8601String(),
        'decidedTaskIds': inputs.decidedTaskIds,
        'requiredTaskIds': inputs.requiredTaskIds.toList()..sort(),
        'expectedOmissions': inputs.expectedOmissions.toList()..sort(),
        // `visibleToModel` is not decoration. The corpus here is ground
        // truth, and it is rendered only inside the capture context — so on a
        // wake without a capture the model was shown none of it. A judge
        // reading blockedBy and concluding the model ignored a dependency it
        // never received would draw exactly the wrong lesson.
        'corpus': [
          for (final task in inputs.corpus)
            {
              'taskId': task.taskId,
              'title': task.title,
              'status': task.status,
              'estimateMinutes': task.estimateMinutes,
              'blockedBy': task.blockedBy,
              'visibleToModel': inputs.referenceableTaskIds.contains(
                task.taskId,
              ),
            },
        ],
        'captureTranscript': scenario.captureTranscript,
      },
      'prompts': {
        'system': result.systemPrompt,
        'user': result.userPrompts,
        'forcedDraftRetry': result.forcedDraftRetry,
      },
      'toolCalls': [
        for (final call in result.outcome.toolCalls)
          {
            'name': call.name,
            'accepted': call.accepted,
            'rejectionMessage': call.rejectionMessage,
            'arguments': call.arguments,
          },
      ],
      'plan': [
        for (final block in result.outcome.blocks) _blockJson(block),
      ],
      'constraints': {
        for (final constraint in result.constraints)
          constraint.id: {
            'passed': constraint.passed,
            'detail': constraint.detail,
          },
      },
      'job': {
        'status': result.jobStatus,
        'attempts': result.jobAttempts,
        'latencyMs': result.latency.inMilliseconds,
        'error': result.error,
      },
      'cost': {
        'inputTokens': _sum(result.consumption.map((e) => e.inputTokens)),
        'outputTokens': _sum(result.consumption.map((e) => e.outputTokens)),
        'thoughtsTokens': _sum(result.consumption.map((e) => e.thoughtsTokens)),
        'cachedInputTokens': _sum(
          result.consumption.map((e) => e.cachedInputTokens),
        ),
        'promptBytes': _promptBytes(result),
      },
    };
  }

  static Map<String, Object?> _blockJson(PlannedBlock block) => {
    'id': block.id,
    'title': block.title,
    'type': block.type.name,
    'state': block.state.name,
    'start': block.startTime.toIso8601String(),
    'end': block.endTime.toIso8601String(),
    'taskId': block.taskId,
    'reason': block.reason,
  };

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Day-planning eval')
      ..writeln()
      ..writeln(
        'Generated ${generatedAt.toIso8601String()} · '
        '${results.length} run(s)',
      )
      ..writeln()
      ..writeln('## Model leaderboard')
      ..writeln()
      ..writeln('| Model | Pass rate | Runs | Failed runs |')
      ..writeln('| --- | ---: | ---: | ---: |');
    for (final standing in standings) {
      buffer.writeln(
        '| `${standing.modelId}` | ${standing.overall.label} | '
        '${standing.runs} | ${standing.failedRuns} |',
      );
    }
    buffer
      ..writeln()
      ..writeln(
        'Rates are over *applicable* results only — a constraint that did '
        'not apply is neither a pass nor a fail, so a scenario that never '
        'exercised a dimension cannot inflate a score.',
      )
      ..writeln()
      ..writeln('## Constraints by model')
      ..writeln()
      ..writeln(
        '| Constraint | ${standings.map((s) => '`${s.modelId}`').join(' | ')} |',
      )
      ..writeln('| --- | ${standings.map((_) => '---:').join(' | ')} |');
    for (final id in EvalConstraintIds.all) {
      final cells = [
        for (final standing in standings)
          standing.byConstraint
              .firstWhere((rate) => rate.constraintId == id)
              .label,
      ];
      buffer.writeln('| $id | ${cells.join(' | ')} |');
    }

    buffer
      ..writeln()
      ..writeln('## Cost')
      ..writeln()
      ..writeln(
        '| Model | Scenario | Runs | Mean latency | In | Out | Thoughts | '
        'Cached | Prompt bytes |',
      )
      ..writeln(
        '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
      );
    for (final row in costRows) {
      buffer.writeln(
        '| `${row.modelId}` | ${row.scenarioId} | ${row.runs} | '
        '${row.meanLatencyMs} ms | ${row.inputTokens} | ${row.outputTokens} | '
        '${row.thoughtsTokens} | ${row.cachedInputTokens} | '
        '${row.meanPromptBytes} |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## Prompt stability')
      ..writeln()
      ..writeln(
        'How much of the system prompt is identical across *every* wake — '
        'the part a provider could cache. Measured across scenarios on '
        'purpose: within one scenario the prompt barely varies, so a per-cell '
        'figure would just restate the prompt size.',
      )
      ..writeln()
      ..writeln(
        '| Model | Wakes | Mean system prompt | Stable prefix | Stable |',
      )
      ..writeln('| --- | ---: | ---: | ---: | ---: |');
    for (final standing in standings) {
      final runs = results.where(
        (r) => r.request.modelId == standing.modelId,
      );
      final stable = _stablePrefixBytes(runs);
      final mean = _mean(
        runs.map((r) => utf8.encode(r.systemPrompt ?? '').length),
      );
      final fraction = mean == 0
          ? '—'
          : '${(stable / mean * 100).toStringAsFixed(0)}%';
      buffer.writeln(
        '| `${standing.modelId}` | ${runs.length} | $mean | $stable | '
        '$fraction |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## Failures')
      ..writeln();
    if (failures.isEmpty) {
      buffer.writeln('None.');
    } else {
      for (final failure in failures) {
        buffer
          ..writeln('- **${failure.cell}** · `${failure.constraintId}`')
          ..writeln('  - ${failure.detail}');
        for (final rejection in failure.rejections) {
          buffer.writeln('  - rejected: $rejection');
        }
      }
    }

    buffer
      ..writeln()
      ..writeln('## Judge bundle')
      ..writeln()
      ..writeln(
        'The JSON alongside this file carries $bundledCells cell(s) at up to '
        '$bundleSamplesPerCell sample(s) each'
        '${droppedSamples == 0 ? '' : ', with $droppedSamples sample(s) '
                  'excluded by that cap'}. '
        'Each entry is self-sufficient: the scenario and its intent, the exact '
        'prompts, every tool call including rejections and their text, the '
        "persisted plan, and each run's constraint results and cost.",
      );
    return buffer.toString();
  }

  static int _promptBytes(EvalRunResult result) =>
      utf8.encode(result.systemPrompt ?? '').length +
      result.userPrompts.fold<int>(
        0,
        (sum, prompt) => sum + utf8.encode(prompt).length,
      );

  /// Bytes shared by every system prompt in [results] — the portion a
  /// provider could cache across wakes.
  ///
  /// With a single run this is the whole prompt, which is honest: nothing
  /// varied, so nothing has been shown to be unstable.
  static int _stablePrefixBytes(Iterable<EvalRunResult> results) {
    final prompts = [
      for (final result in results)
        if (result.systemPrompt != null) result.systemPrompt!,
    ];
    if (prompts.isEmpty) return 0;
    var prefix = prompts.first;
    for (final prompt in prompts.skip(1)) {
      var i = 0;
      while (i < prefix.length && i < prompt.length && prefix[i] == prompt[i]) {
        i++;
      }
      prefix = prefix.substring(0, i);
      if (prefix.isEmpty) break;
    }
    return utf8.encode(prefix).length;
  }

  static Map<(String, String, String), List<EvalRunResult>> _groupIntoCells(
    List<EvalRunResult> results,
  ) {
    final cells = <(String, String, String), List<EvalRunResult>>{};
    for (final result in results) {
      final key = (
        result.request.scenario.id,
        result.request.modelId,
        result.request.variant.id,
      );
      cells.putIfAbsent(key, () => []).add(result);
    }
    return cells;
  }

  static int _sum(Iterable<int?> values) =>
      values.fold<int>(0, (sum, value) => sum + (value ?? 0));

  static int _mean(Iterable<int> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) ~/ list.length;
  }
}

/// Where a report is written.
///
/// Defaults under the git-ignored `tmp/` directory so runs accumulate and can
/// be diffed, and both paths are env-overridable for a CI or scratch run.
@immutable
class EvalReportPaths {
  const EvalReportPaths({required this.jsonPath, required this.markdownPath});

  factory EvalReportPaths.fromEnvironment({
    Map<String, String>? environment,
    String defaultDirectory = 'tmp/day-planning-eval',
  }) {
    final env = environment ?? Platform.environment;
    final directory = env['DAY_PLANNING_EVAL_DIR'] ?? defaultDirectory;
    return EvalReportPaths(
      jsonPath:
          env['DAY_PLANNING_EVAL_JSON'] ?? '$directory/day-planning-eval.json',
      markdownPath:
          env['DAY_PLANNING_EVAL_MARKDOWN'] ??
          '$directory/day-planning-eval.md',
    );
  }

  final String jsonPath;
  final String markdownPath;
}

/// Writes [report] as JSON and Markdown, creating parent directories.
///
/// Returns the paths written, so a caller can point at them from a failure
/// message.
EvalReportPaths writeEvalReport(EvalReport report, {EvalReportPaths? paths}) {
  final target = paths ?? EvalReportPaths.fromEnvironment();
  (File(target.jsonPath)..parent.createSync(recursive: true)).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report.toJson()),
  );
  (File(
    target.markdownPath,
  )..parent.createSync(recursive: true)).writeAsStringSync(report.toMarkdown());
  return target;
}
