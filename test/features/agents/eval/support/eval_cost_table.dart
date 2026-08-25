/// The cost table every agent-eval tier reports through.
///
/// Extracted rather than copied: the "missing telemetry widens uncertainty,
/// it is never counted as zero" rule is the whole point of the table, and two
/// implementations of it would eventually publish two different per-month
/// figures for the same run. That is not hypothetical — the relationship
/// suite shipped with an inlined copy of this renderer, which is why it is
/// now shared across subjects rather than owned by the goal suite.
library;

/// The cost surface a case must expose to appear in the table.
///
/// `GoalAgentEvalCaseResult` (goal tier 1, scores tool calls),
/// `GoalOutcomeEvalCaseResult` (goal tier 2, scores persisted outcomes) and
/// `RelationshipAgentEvalCaseResult` all implement it, so a model's cost is
/// quoted the same way whichever tier measured it.
abstract class AgentEvalCostCase {
  String get modelId;
  int? get inputTokens;
  int? get outputTokens;

  /// Billed credits, or null when the provider reported none. Never
  /// zero-defaulted: a missing bill is not a free run.
  double? get credits;

  /// Reported energy in watt-hours, or null when none was reported.
  double? get energyWh;
}

/// Renders the shared cost table, including the per-subject-month
/// extrapolations and the paragraph that prints their assumption.
///
/// [subject] is the thing a wake is billed against — `goal` or
/// `relationship` — and appears in both the column headers and the printed
/// assumption. [closingNote] is the one sentence that legitimately differs
/// per suite: what the surrounding runtime adds on top of the measured turn.
String renderAgentEvalCostTable({
  required List<String> modelIds,
  required List<AgentEvalCostCase> cases,
  required int wakesPerDayAssumption,
  required String subject,
  required String closingNote,
}) {
  final buffer = StringBuffer()
    ..writeln('## Cost (observed, not a target)')
    ..writeln()
    ..writeln(
      '| Model | Cases | In | Out | Credits | Credits/$subject-month* | '
      'Wh | Wh/$subject-month* |',
    )
    ..writeln('| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |');
  for (final modelId in modelIds) {
    final modelCases = cases.where((c) => c.modelId == modelId).toList();
    final inTokens = modelCases.fold<int>(
      0,
      (sum, c) => sum + (c.inputTokens ?? 0),
    );
    final outTokens = modelCases.fold<int>(
      0,
      (sum, c) => sum + (c.outputTokens ?? 0),
    );
    final creditValues = modelCases
        .map((c) => c.credits)
        .whereType<double>()
        .toList();
    final credits = creditValues.isEmpty
        ? null
        : creditValues.reduce((a, b) => a + b);
    // Per-month figures divide by REPORTED cases only: missing telemetry
    // must widen uncertainty, never masquerade as zero cost.
    final perSubjectMonth = credits == null
        ? null
        : credits / creditValues.length * wakesPerDayAssumption * 30;
    final energyValues = modelCases
        .map((c) => c.energyWh)
        .whereType<double>()
        .toList();
    final energyWh = energyValues.isEmpty
        ? null
        : energyValues.reduce((a, b) => a + b);
    final energyPerSubjectMonth = energyWh == null
        ? null
        : energyWh / energyValues.length * wakesPerDayAssumption * 30;
    buffer.writeln(
      '| `$modelId` | ${modelCases.length} | $inTokens | $outTokens | '
      '${credits?.toStringAsFixed(4) ?? 'not reported'} | '
      '${perSubjectMonth?.toStringAsFixed(4) ?? 'not reported'} | '
      '${energyWh?.toStringAsFixed(2) ?? 'not reported'} | '
      '${energyPerSubjectMonth?.toStringAsFixed(1) ?? 'not reported'} |',
    );
  }
  buffer
    ..writeln()
    ..writeln(
      '*Extrapolation assumes $wakesPerDayAssumption LLM wakes '
      'per $subject per day — a printed assumption, not a measurement — '
      'and divides by cases that actually reported the figure: missing '
      'telemetry widens uncertainty, it is never counted as zero. '
      'Credits and energy are Melious-reported; "not reported" means '
      'the provider sent no data, never that the run was free. '
      '$closingNote',
    );
  return buffer.toString();
}
