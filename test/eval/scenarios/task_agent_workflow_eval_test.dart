// Phase 1 example: runs the REAL TaskAgentWorkflow for a single-task wake via
// TaskAgentEvalBench, then grades the mapped output with the Level 1 suite.
//
// Exercises the real workflow orchestration (provider resolution, the
// conversation loop, real TaskAgentStrategy tool dispatch + change-set
// deferral, report extraction, state persistence) with the model response
// scripted. result.success is the real signal; Level 1 gates the output.

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/time_service.dart';

import '../../helpers/fallbacks.dart';
import '../../mocks/mocks.dart' show MockPersistenceLogic;
import '../../widget_test_utils.dart';
import '../harness/eval_harness.dart';
import '../harness/planner_eval_bench.dart' show ScriptedAgentBehavior;
import '../harness/scripted_eval_target.dart';

void main() {
  setUpAll(() async {
    registerAllFallbackValues();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<TimeService>(TimeService());
      },
    );
  });

  tearDownAll(tearDownTestGetIt);

  final scenario = EvalScenario(
    id: 'task_workflow_release_notes',
    title: 'Real workflow: groom the release-notes task',
    agentKind: AgentKind.taskAgent,
    appState: MockedAppState(
      now: DateTime(2026, 6, 9, 9),
      categoryIds: const ['cat-001'],
      tasks: const [
        MockTask(
          id: 'task-notes',
          title: 'Write release notes for 0.x',
          status: 'IN PROGRESS',
          categoryId: 'cat-001',
          checklist: [MockChecklistItem(id: 'ci-1', title: 'Draft summary')],
        ),
      ],
    ),
    userInput: const UserInput(
      transcript: 'Help me get the release notes ready.',
      triggerTokens: {'decided_task:task-notes'},
    ),
  );

  const goodReport = ToolCallRecord(
    name: 'update_report',
    args: {
      'oneLiner': 'Groomed the release-notes task',
      'tldr': 'Set a 90m estimate and noted the next step.',
      'content': '## ✅ Achieved\nEstimate set.',
    },
  );

  EvalCheck named(List<EvalCheck> checks, String name) =>
      checks.firstWhere((c) => c.name == name);

  test('real workflow publishes a report and passes Level 1', () async {
    const behavior = ScriptedAgentBehavior(
      toolCalls: [
        goodReport,
        ToolCallRecord(
          name: 'update_task_estimate',
          args: {'minutes': 90},
        ),
        ToolCallRecord(
          name: 'record_observations',
          args: {
            'observations': ['User wants the release notes finished today.'],
          },
        ),
      ],
      usage: InferenceUsage(inputTokens: 1800, outputTokens: 320),
    );

    final output = await ScriptedEvalTarget.fromMap(
      {scenario.id: behavior},
      profileName: kFrontierProfile.name,
    ).run(scenario, kFrontierProfile);

    expect(output.success, isTrue, reason: output.error);
    expect(output.report, isNotNull);
    expect(output.report!.oneLiner, 'Groomed the release-notes task');
    expect(output.observations, hasLength(1));

    final checks = runLevel1(scenario, output, profile: kFrontierProfile);
    final failed = checks.where((c) => !c.passed).map((c) => c.detail).toList();
    expect(failed, isEmpty, reason: failed.join('\n'));
  });

  test(
    'real workflow succeeds but Level 1 catches an out-of-range estimate',
    () async {
      const behavior = ScriptedAgentBehavior(
        toolCalls: [
          goodReport,
          ToolCallRecord(
            name: 'update_task_estimate',
            args: {'minutes': 5000}, // > 1440
          ),
        ],
        usage: InferenceUsage(inputTokens: 1800, outputTokens: 320),
      );

      final output = await ScriptedEvalTarget.fromMap(
        {scenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(scenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(
        named(runLevel1(scenario, output), 'report_published').passed,
        isTrue,
      );
      final estimate = named(runLevel1(scenario, output), 'estimate_range');
      expect(estimate.passed, isFalse);
      expect(estimate.detail, contains('5000'));
    },
  );
}
