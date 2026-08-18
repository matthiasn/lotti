/// The cost table both goal-agent eval tiers report through.
///
/// Extracted rather than copied: the "missing telemetry widens uncertainty,
/// it is never counted as zero" rule is the whole point of the table, and two
/// implementations of it would eventually publish two different €/goal-month
/// figures for the same run.
library;

/// The cost surface a case must expose to appear in the table. Both
/// `GoalAgentEvalCaseResult` (tier 1, scores tool calls) and
/// `GoalOutcomeEvalCaseResult` (tier 2, scores persisted outcomes) implement
/// it, so a model's cost is quoted the same way whichever tier measured it.
abstract class GoalEvalCostCase {
  String get modelId;
  int? get inputTokens;
  int? get outputTokens;

  /// Billed credits, or null when the provider reported none. Never
  /// zero-defaulted: a missing bill is not a free run.
  double? get credits;

  /// Reported energy in watt-hours, or null when none was reported.
  double? get energyWh;
}

/// Renders the shared cost table, including the €/goal-month and Wh/goal-month
/// extrapolations and the paragraph that prints their assumption.
String renderGoalEvalCostTable({
  required List<String> modelIds,
  required List<GoalEvalCostCase> cases,
  required int wakesPerDayAssumption,
}) {
  final buffer = StringBuffer()
    ..writeln('## Cost (observed, not a target)')
    ..writeln()
    ..writeln(
      '| Model | Cases | In | Out | Credits | Credits/goal-month* | '
      'Wh | Wh/goal-month* |',
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
    final perGoalMonth = credits == null
        ? null
        : credits / creditValues.length * wakesPerDayAssumption * 30;
    final energyValues = modelCases
        .map((c) => c.energyWh)
        .whereType<double>()
        .toList();
    final energyWh = energyValues.isEmpty
        ? null
        : energyValues.reduce((a, b) => a + b);
    final energyPerGoalMonth = energyWh == null
        ? null
        : energyWh / energyValues.length * wakesPerDayAssumption * 30;
    buffer.writeln(
      '| `$modelId` | ${modelCases.length} | $inTokens | $outTokens | '
      '${credits?.toStringAsFixed(4) ?? 'not reported'} | '
      '${perGoalMonth?.toStringAsFixed(4) ?? 'not reported'} | '
      '${energyWh?.toStringAsFixed(2) ?? 'not reported'} | '
      '${energyPerGoalMonth?.toStringAsFixed(1) ?? 'not reported'} |',
    );
  }
  buffer
    ..writeln()
    ..writeln(
      '*Extrapolation assumes $wakesPerDayAssumption LLM wakes '
      'per goal per day — a printed assumption, not a measurement — '
      'and divides by cases that actually reported the figure: missing '
      'telemetry widens uncertainty, it is never counted as zero. '
      'Credits and energy are Melious-reported; "not reported" means '
      'the provider sent no data, never that the run was free. Banner '
      'creation itself (ADR 0058) adds no image inference on top of '
      'the Phase B text turn.',
    );
  return buffer.toString();
}
