// Phase 1 example: runs the REAL DayAgentWorkflow for a drafting wake via
// PlannerEvalBench, then grades the mapped output with the Level 1 suite.
//
// Unlike the FixtureEvalTarget example, this exercises the actual workflow
// orchestration end-to-end (profile->provider resolution, conversation loop,
// real strategy tool dispatch, state reconciliation, persistence) with the model
// response scripted. result.success is the real signal that the whole pipeline
// ran; the Level 1 suite then gates the (scripted) plan's quality.

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../../helpers/fallbacks.dart';
import '../harness/eval_harness.dart';
import '../harness/planner_eval_bench.dart' show ScriptedAgentBehavior;
import '../harness/scripted_eval_target.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const dayId = 'dayplan-2026-06-09';
  final today = DateTime(2026, 6, 9, 7);

  EvalScenario scenarioWith(MockedAppState state) => EvalScenario(
    id: 'planner_workflow_drafting',
    title: 'Real workflow drafting wake within capacity',
    agentKind: AgentKind.planningAgent,
    appState: state,
    userInput: const UserInput(
      transcript: 'Finish the planner ADR and fit in a morning run.',
      triggerTokens: {'drafting:$dayId'},
    ),
    expectations: const EvalExpectations(mustCallTools: {'draft_day_plan'}),
  );

  final appState = MockedAppState(
    now: today,
    categoryIds: const ['cat-work', 'cat-health'],
    tasks: [
      MockTask(
        id: 'task-adr',
        title: 'Finish the planner ADR',
        status: 'IN PROGRESS',
        due: DateTime(2026, 6, 9),
        estimateMinutes: 120,
        categoryId: 'cat-work',
      ),
      const MockTask(
        id: 'task-run',
        title: 'Morning run',
        status: 'OPEN',
        estimateMinutes: 40,
        categoryId: 'cat-health',
      ),
    ],
  );

  Map<String, dynamic> block({
    required String categoryId,
    required DateTime start,
    required DateTime end,
    required String taskId,
    required String title,
  }) => <String, dynamic>{
    'categoryId': categoryId,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'taskId': taskId,
    'title': title,
    'type': 'ai',
  };

  test(
    'real workflow drafts a within-capacity plan and passes Level 1',
    () async {
      final behavior = ScriptedAgentBehavior(
        toolCalls: [
          ToolCallRecord(
            name: 'draft_day_plan',
            args: {
              'dayId': dayId,
              'blocks': [
                block(
                  categoryId: 'cat-health',
                  start: DateTime(2026, 6, 9, 7, 30),
                  end: DateTime(2026, 6, 9, 8, 10),
                  taskId: 'task-run',
                  title: 'Morning run',
                ),
                block(
                  categoryId: 'cat-work',
                  start: DateTime(2026, 6, 9, 9),
                  end: DateTime(2026, 6, 9, 11),
                  taskId: 'task-adr',
                  title: 'Finish the planner ADR',
                ),
              ],
            },
          ),
        ],
        finalResponse: 'Drafted the day.',
        usage: const InferenceUsage(inputTokens: 4200, outputTokens: 700),
      );

      final scenario = scenarioWith(appState);
      final output = await ScriptedEvalTarget.fromMap(
        {scenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(scenario, kFrontierProfile);

      // The real workflow ran end-to-end.
      expect(output.success, isTrue, reason: output.error);
      expect(output.turnCount, greaterThanOrEqualTo(1));
      expect(output.plannedBlocks, hasLength(2));

      final checks = runLevel1(scenario, output, profile: kFrontierProfile);
      final failed = checks
          .where((c) => !c.passed)
          .map((c) => c.detail)
          .toList();
      expect(failed, isEmpty, reason: failed.join('\n'));
    },
  );

  test(
    'real workflow still succeeds on an over-capacity plan, Level 1 catches it',
    () async {
      final behavior = ScriptedAgentBehavior(
        toolCalls: [
          ToolCallRecord(
            name: 'draft_day_plan',
            args: {
              'dayId': dayId,
              'blocks': [
                block(
                  categoryId: 'cat-work',
                  start: DateTime(2026, 6, 9, 9),
                  end: DateTime(2026, 6, 9, 17), // 480 min
                  taskId: 'task-adr',
                  title: 'Finish the planner ADR',
                ),
                block(
                  categoryId: 'cat-work',
                  start: DateTime(2026, 6, 9, 17),
                  end: DateTime(2026, 6, 9, 21), // +240 -> 720 total
                  taskId: 'task-adr',
                  title: 'More ADR',
                ),
              ],
            },
          ),
        ],
        finalResponse: 'Drafted the day.',
        usage: const InferenceUsage(inputTokens: 4200, outputTokens: 700),
      );

      final scenario = scenarioWith(appState);
      final output = await ScriptedEvalTarget.fromMap(
        {scenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(scenario, kFrontierProfile);

      // Workflow plumbing succeeded — over-capacity is a quality gate, not a
      // crash.
      expect(output.success, isTrue, reason: output.error);

      final checks = runLevel1(scenario, output, profile: kFrontierProfile);
      final capacity = checks.firstWhere((c) => c.name == 'within_capacity');
      expect(capacity.passed, isFalse);
      expect(capacity.detail, contains('720'));
    },
  );
}
