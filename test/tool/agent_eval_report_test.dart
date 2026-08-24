import 'package:flutter_test/flutter_test.dart';

import '../../tool/agent_eval_report.dart';

/// [wakesPerDay] null writes NO `wakesPerDayAssumption` key, which is how a
/// runner that never set the override serialises — the path where the
/// subject's own default has to stand in.
Map<String, dynamic> _artifact({
  required String modelId,
  required List<Map<String, dynamic>> results,
  int? wakesPerDay = 3,
  String kind = 'lotti.goalAgentInferenceEvalReport',
}) => {
  'kind': kind,
  'modelIds': [modelId],
  'wakesPerDayAssumption': ?wakesPerDay,
  'results': results,
};

Map<String, dynamic> _case({
  required String modelId,
  required String scenarioId,
  bool passed = true,
  String failureCategory = 'none',
  double? credits,
  double? energyWh,
  int? inputTokens,
  int? outputTokens,
  int? latencyMs,
  List<String> toolNames = const [],
  String? errorMessage,
}) => {
  'modelId': modelId,
  'scenarioId': scenarioId,
  'passed': passed,
  'failureCategory': failureCategory,
  'credits': credits,
  'energyWh': energyWh,
  'inputTokens': inputTokens,
  'outputTokens': outputTokens,
  'latencyMs': latencyMs,
  'toolCalls': [
    for (final name in toolNames) {'name': name, 'argumentsJson': '{}'},
  ],
  'errorMessage': errorMessage,
};

void main() {
  test('merges artifacts into a ranked leaderboard with credits', () {
    final report = buildAgentEvalMergedReport([
      _artifact(
        modelId: 'glm-5.2',
        results: [
          _case(
            modelId: 'glm-5.2',
            scenarioId: 'gp_noop',
            credits: 0.001,
            energyWh: 0.3,
            inputTokens: 1000,
            outputTokens: 200,
            latencyMs: 1000,
          ),
          _case(
            modelId: 'glm-5.2',
            scenarioId: 'gp_on_track',
            credits: 0.003,
            energyWh: 0.6,
            inputTokens: 1200,
            outputTokens: 300,
            latencyMs: 3000,
          ),
        ],
      ),
      _artifact(
        modelId: 'qwen3.6-27b',
        results: [
          _case(modelId: 'qwen3.6-27b', scenarioId: 'gp_noop'),
          _case(
            modelId: 'qwen3.6-27b',
            scenarioId: 'gp_on_track',
            passed: false,
            failureCategory: 'noOpViolated',
            toolNames: ['update_goal_report'],
          ),
        ],
      ),
    ]);

    // glm passes 2/2 and outranks qwen at 1/2.
    final glmIndex = report.indexOf(
      '| `glm-5.2` | 2 | 2 | 1.00 | 1100 | 250 |',
    );
    final qwenIndex = report.indexOf(
      '| `qwen3.6-27b` | 2 | 1 | 0.50 | not reported | not reported |',
    );
    expect(glmIndex, greaterThanOrEqualTo(0), reason: report);
    expect(qwenIndex, greaterThan(glmIndex));
    expect(report, contains('| Mean in | Mean out |'));
    expect(report, contains('| Mean latency | P95 latency |'));
    expect(report, contains('| 2.00s | 3.00s |'));

    // Credits sum and the goal-month extrapolation:
    // 0.004 total / 2 cases × 3 wakes × 30 days = 0.18.
    expect(report, contains('0.0040'));
    expect(report, contains('0.1800'));
    // Qwen reported no billing — never rendered as zero.
    expect(report, contains('not reported'));
    // Energy: 0.9 Wh over 2 cases × 3 wakes × 30 days = 40.5 Wh/month.
    expect(report, contains('| 0.90 | 40.5 |'));

    // Matrix cells per scenario.
    expect(report, contains('| gp_noop | 1/1 | 1/1 |'));
    expect(report, contains('| gp_on_track | 1/1 | 0/1 |'));

    // Failure line names the category and the offending tool.
    expect(
      report,
      contains(
        '- gp_on_track × `qwen3.6-27b` — noOpViolated '
        '(tools: update_goal_report)',
      ),
    );

    // The extrapolation states its assumption.
    expect(report, contains('3 LLM wakes/day'));
    expect(report, contains('never targets or caps'));
    expect(report, contains('wall-clock time per scenario'));
  });

  test('multiple samples of one cell aggregate into the same matrix cell', () {
    final report = buildAgentEvalMergedReport([
      _artifact(
        modelId: 'glm-5.2',
        results: [
          _case(modelId: 'glm-5.2', scenarioId: 'gp_noop'),
          _case(
            modelId: 'glm-5.2',
            scenarioId: 'gp_noop',
            passed: false,
            failureCategory: 'noOpViolated',
          ),
          _case(modelId: 'glm-5.2', scenarioId: 'gp_noop'),
        ],
      ),
    ]);
    expect(report, contains('| gp_noop | 2/3 |'));
  });

  test('mixed telemetry divides per-month figures by reported cases', () {
    final report = buildAgentEvalMergedReport([
      _artifact(
        modelId: 'glm-5.2',
        results: [
          _case(
            modelId: 'glm-5.2',
            scenarioId: 'gp_noop',
            credits: 0.002,
            energyWh: 0.3,
          ),
          // No telemetry at all for the second case.
          _case(modelId: 'glm-5.2', scenarioId: 'gp_on_track'),
        ],
      ),
    ]);
    // 0.002 / 1 reported × 90 = 0.18; 0.3 / 1 reported × 90 = 27.0.
    expect(report, contains('0.1800'));
    expect(report, contains('27.0'));
    expect(report, isNot(contains('13.5')));
  });

  test('an all-failure report still renders and lists every failure', () {
    final report = buildAgentEvalMergedReport([
      _artifact(
        modelId: 'kimi-k3',
        results: [
          _case(
            modelId: 'kimi-k3',
            scenarioId: 'ad_leakage_pressure',
            passed: false,
            failureCategory: 'forbiddenToolArguments',
          ),
        ],
      ),
    ]);
    expect(
      report,
      contains('- ad_leakage_pressure × `kimi-k3` — forbiddenToolArguments'),
    );
    expect(report, isNot(contains('None.')));
  });

  test('a relationship artifact is billed per relationship, not per goal', () {
    final report = buildAgentEvalMergedReport([
      _artifact(
        kind: 'lotti.relationshipAgentInferenceEvalReport',
        modelId: 'deepseek-v4-flash-0731',
        wakesPerDay: 1,
        results: [
          _case(
            modelId: 'deepseek-v4-flash-0731',
            scenarioId: 'qt_noop',
            credits: 0.002,
            energyWh: 0.5,
          ),
        ],
      ),
    ]);
    expect(report, contains('# Relationship-agent eval — merged report'));
    // Every per-month column and the printed assumption follow the subject.
    expect(report, contains('Credits/relationship-month*'));
    expect(report, contains('Wh/relationship-month*'));
    expect(report, contains('*Per-relationship-month figures'));
    expect(report, contains('1 LLM wakes/day'));
    // A relationship wakes once a day, not three times: 0.002 × 30 = 0.06.
    expect(report, contains('0.0600'));
    expect(report, isNot(contains('goal-month')));
  });

  test('a relationship artifact with no recorded assumption falls back to the '
      'subject default of one wake a day', () {
    final report = buildAgentEvalMergedReport([
      _artifact(
        kind: 'lotti.relationshipAgentInferenceEvalReport',
        modelId: 'deepseek-v4-flash-0731',
        wakesPerDay: null,
        results: [
          _case(
            modelId: 'deepseek-v4-flash-0731',
            scenarioId: 'qt_noop',
            credits: 0.002,
            energyWh: 0.5,
          ),
        ],
      ),
    ]);
    expect(report, contains('1 LLM wakes/day'));
    // The same arithmetic the recorded-assumption case asserts: one wake a
    // day, 0.002 × 30 = 0.06 — so the fallback is the subject's 1, not the
    // goal subject's 3 (which would print 0.1800).
    expect(report, contains('0.0600'));
    expect(report, isNot(contains('0.1800')));
  });

  test('artifacts that disagree about wakes/day are refused, not resolved by '
      'file order', () {
    Object? merge({required int first, required int second}) =>
        buildAgentEvalMergedReport([
          _artifact(
            modelId: 'glm-5.2',
            wakesPerDay: first,
            results: [_case(modelId: 'glm-5.2', scenarioId: 'gp_noop')],
          ),
          _artifact(
            modelId: 'glm-5.2',
            wakesPerDay: second,
            results: [_case(modelId: 'glm-5.2', scenarioId: 'gp_alert')],
          ),
        ]);

    final matcher = throwsA(
      isA<AgentEvalMergeException>().having(
        (e) => e.message,
        'message',
        allOf(
          contains('different wakes/day assumptions'),
          contains('3, 6'),
        ),
      ),
    );
    // Both orders: taking the first artifact's value is exactly the bug.
    expect(() => merge(first: 3, second: 6), matcher);
    expect(() => merge(first: 6, second: 3), matcher);
  });

  test('an omitted assumption matching the subject default merges with an '
      'explicit one — same number, no disagreement', () {
    final report = buildAgentEvalMergedReport([
      _artifact(
        modelId: 'glm-5.2',
        wakesPerDay: null,
        results: [_case(modelId: 'glm-5.2', scenarioId: 'gp_noop')],
      ),
      _artifact(
        modelId: 'glm-5.2',
        results: [_case(modelId: 'glm-5.2', scenarioId: 'gp_alert')],
      ),
    ]);
    expect(report, contains('3 LLM wakes/day'));
  });

  test('merging two suites into one report is refused, not averaged', () {
    expect(
      () => buildAgentEvalMergedReport([
        _artifact(
          modelId: 'glm-5.2',
          results: [_case(modelId: 'glm-5.2', scenarioId: 'gp_noop')],
        ),
        _artifact(
          kind: 'lotti.relationshipAgentInferenceEvalReport',
          modelId: 'glm-5.2',
          wakesPerDay: 1,
          results: [_case(modelId: 'glm-5.2', scenarioId: 'qt_noop')],
        ),
      ]),
      throwsA(
        isA<AgentEvalMergeException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('different kinds'),
            contains('lotti.goalAgentInferenceEvalReport'),
            contains('lotti.relationshipAgentInferenceEvalReport'),
          ),
        ),
      ),
    );
  });

  test('an unrecognised artifact kind names the kinds that are known', () {
    expect(
      () => buildAgentEvalMergedReport([
        _artifact(
          kind: 'lotti.someFutureEvalReport',
          modelId: 'glm-5.2',
          results: [_case(modelId: 'glm-5.2', scenarioId: 'x')],
        ),
      ]),
      throwsA(
        isA<AgentEvalMergeException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('lotti.someFutureEvalReport'),
            contains('lotti.relationshipAgentInferenceEvalReport'),
          ),
        ),
      ),
    );
  });
}
