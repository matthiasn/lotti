import 'package:flutter_test/flutter_test.dart';

import '../../tool/goal_agent_eval_report.dart';

Map<String, dynamic> _artifact({
  required String modelId,
  required List<Map<String, dynamic>> results,
  int wakesPerDay = 3,
}) => {
  'kind': 'lotti.goalAgentInferenceEvalReport',
  'modelIds': [modelId],
  'wakesPerDayAssumption': wakesPerDay,
  'results': results,
};

Map<String, dynamic> _case({
  required String modelId,
  required String scenarioId,
  bool passed = true,
  String failureCategory = 'none',
  double? credits,
  double? energyWh,
  List<String> toolNames = const [],
  String? errorMessage,
}) => {
  'modelId': modelId,
  'scenarioId': scenarioId,
  'passed': passed,
  'failureCategory': failureCategory,
  'credits': credits,
  'energyWh': energyWh,
  'toolCalls': [
    for (final name in toolNames) {'name': name, 'argumentsJson': '{}'},
  ],
  'errorMessage': errorMessage,
};

void main() {
  test('merges artifacts into a ranked leaderboard with credits', () {
    final report = buildGoalAgentEvalMergedReport([
      _artifact(
        modelId: 'glm-5.2',
        results: [
          _case(
            modelId: 'glm-5.2',
            scenarioId: 'gp_noop',
            credits: 0.001,
            energyWh: 0.3,
          ),
          _case(
            modelId: 'glm-5.2',
            scenarioId: 'gp_on_track',
            credits: 0.003,
            energyWh: 0.6,
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
    final glmIndex = report.indexOf('| `glm-5.2` | 2 | 2 | 1.00 |');
    final qwenIndex = report.indexOf('| `qwen3.6-27b` | 2 | 1 | 0.50 |');
    expect(glmIndex, greaterThanOrEqualTo(0), reason: report);
    expect(qwenIndex, greaterThan(glmIndex));

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
  });

  test('multiple samples of one cell aggregate into the same matrix cell', () {
    final report = buildGoalAgentEvalMergedReport([
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
    final report = buildGoalAgentEvalMergedReport([
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
    final report = buildGoalAgentEvalMergedReport([
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
}
