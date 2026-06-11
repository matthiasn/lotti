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

import '../../features/daily_os_next/agents/prompt/day_agent_prompt_test_utils.dart';
import '../../helpers/fallbacks.dart';
import '../harness/eval_harness.dart';
import '../harness/eval_profile_config.dart';
import '../harness/planner_eval_bench.dart';
import '../harness/scripted_eval_target.dart';
import 'eval_scenarios.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final scenario = plannerWorkflowDraftingScenario;

  Map<String, dynamic> block({
    required String categoryId,
    required DateTime start,
    required DateTime end,
    required String taskId,
    required String title,
    String? id,
    String? reason = 'scripted eval baseline',
  }) => <String, dynamic>{
    ...id == null ? const <String, dynamic>{} : {'id': id},
    'categoryId': categoryId,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'taskId': taskId,
    'title': title,
    'type': 'ai',
    ...reason == null ? const <String, dynamic>{} : {'reason': reason},
  };

  test(
    'real workflow drafts a within-capacity plan and passes Level 1',
    () async {
      final behavior = ScriptedAgentBehavior(
        toolCalls: [
          ToolCallRecord(
            name: 'draft_day_plan',
            args: {
              'dayId': kPlannerWorkflowDayId,
              'capacityMinutes': scenario.appState.capacityMinutes,
              'decidedTaskIds': ['task-run', 'task-adr'],
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
      const context = EvalTargetRunContext(
        runId: 'run-planner-context',
        scenarioId: 'planner_workflow_drafting',
        profileName: 'frontier-reasoning',
        trialIndex: 1,
      );

      final output = await ScriptedEvalTarget.fromMap(
        {scenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(scenario, kFrontierProfile, context: context);

      // The real workflow ran end-to-end.
      expect(output.success, isTrue, reason: output.error);
      expect(output.workflowRun, isNotNull);
      expect(output.workflowRun!.runKey, contains(context.cellId));
      expect(output.workflowRun!.threadId, contains(context.cellId));
      expect(output.turnCount, greaterThanOrEqualTo(1));
      expect(output.plannedBlocks, hasLength(2));
      final expectedProfile = evalProfileConfig(kFrontierProfile);
      expect(output.resolvedModel, isNotNull);
      expect(output.resolvedModel!.profileId, expectedProfile.profileId);
      expect(output.resolvedModel!.modelConfigId, kFrontierProfile.modelId);
      expect(
        output.resolvedModel!.providerModelId,
        expectedProfile.providerModelId,
      );
      expect(
        output.resolvedModel!.wakeRunResolvedModelId,
        expectedProfile.providerModelId,
      );
      expect(
        output.resolvedModel!.usageModelId,
        expectedProfile.providerModelId,
      );
      expect(output.resolvedModel!.providerType, 'gemini');
      expect(
        output.resolvedModel!.providerModelId,
        isNot(contains('legacy')),
      );

      final checks = runLevel1(scenario, output, profile: kFrontierProfile);
      final failed = checks
          .where((c) => !c.passed)
          .map((c) => c.detail)
          .toList();
      expect(failed, isEmpty, reason: failed.join('\n'));
    },
  );

  test(
    'maps planner observations from persisted message payloads',
    () async {
      final behavior = ScriptedAgentBehavior(
        toolCalls: [
          const ToolCallRecord(
            name: 'record_observations',
            args: {
              'observations': [
                '  User protects the morning focus block.  ',
                {'text': '   '},
                {'text': '  Planner should keep runs before deep work.  '},
              ],
            },
          ),
          ToolCallRecord(
            name: 'draft_day_plan',
            args: {
              'dayId': kPlannerWorkflowDayId,
              'capacityMinutes': scenario.appState.capacityMinutes,
              'decidedTaskIds': ['task-run'],
              'blocks': [
                block(
                  categoryId: 'cat-health',
                  start: DateTime(2026, 6, 9, 7, 30),
                  end: DateTime(2026, 6, 9, 8, 10),
                  taskId: 'task-run',
                  title: 'Morning run',
                ),
              ],
            },
          ),
        ],
        finalResponse: 'Recorded observations and drafted the day.',
        usage: const InferenceUsage(inputTokens: 3600, outputTokens: 520),
      );

      final output = await ScriptedEvalTarget.fromMap(
        {scenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(scenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(output.observations, [
        'User protects the morning focus block.',
        'Planner should keep runs before deep work.',
      ]);
      expect(output.observations, isNot(contains('')));
    },
  );

  test(
    'adversarial carry-over wake avoids stale admin work',
    () async {
      final stressScenario = plannerWorkflowAmbiguousCarryoverScenario;
      final behavior = ScriptedAgentBehavior(
        toolCalls: [
          ToolCallRecord(
            name: 'draft_day_plan',
            args: {
              'dayId': kPlannerAmbiguousCarryoverDayId,
              'capacityMinutes': stressScenario.appState.capacityMinutes,
              'decidedTaskIds': ['task-client-review'],
              'blocks': [
                block(
                  categoryId: 'cat-work',
                  start: DateTime(2026, 6, 11, 9),
                  end: DateTime(2026, 6, 11, 10),
                  taskId: 'task-client-review',
                  title: 'Client review follow-up',
                  reason: 'Resolve the ambiguous follow-up as client work.',
                ),
              ],
            },
          ),
        ],
        finalResponse: 'Scheduled the client review and left admin alone.',
        usage: const InferenceUsage(inputTokens: 3800, outputTokens: 520),
      );

      final output = await ScriptedEvalTarget.fromMap(
        {stressScenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(stressScenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(output.plannedBlocks, hasLength(1));
      expect(output.plannedBlocks.single.taskId, 'task-client-review');
      expect(
        output.plannedBlocks.map((block) => block.taskId),
        isNot(contains('task-admin-followup')),
      );
      final failed = runLevel1(
        stressScenario,
        output,
        profile: kFrontierProfile,
      ).where((check) => !check.passed).map((check) => check.detail).toList();
      expect(failed, isEmpty, reason: failed.join('\n'));
    },
  );

  test(
    'adversarial focus-boundary wake preserves fixed appointment',
    () async {
      final stressScenario = plannerWorkflowFocusBoundaryScenario;
      final behavior = ScriptedAgentBehavior(
        toolCalls: [
          ToolCallRecord(
            name: 'draft_day_plan',
            args: {
              'dayId': kPlannerFocusBoundaryDayId,
              'capacityMinutes': stressScenario.appState.capacityMinutes,
              'decidedTaskIds': [
                'task-client-brief',
                'task-doctor-appointment',
              ],
              'blocks': [
                block(
                  id: 'client-brief-block',
                  categoryId: 'cat-work',
                  start: DateTime(2026, 6, 12, 8, 30),
                  end: DateTime(2026, 6, 12, 9, 45),
                  taskId: 'task-client-brief',
                  title: 'Prepare client brief',
                  reason: 'Schedule focus work before the fixed appointment.',
                ),
                block(
                  id: 'fixed-doctor-appointment',
                  categoryId: 'cat-health',
                  start: DateTime(2026, 6, 12, 10),
                  end: DateTime(2026, 6, 12, 11),
                  taskId: 'task-doctor-appointment',
                  title: 'Doctor appointment',
                  reason: 'Preserve the fixed calendar commitment.',
                ),
              ],
            },
          ),
        ],
        finalResponse: 'Scheduled the client brief around the appointment.',
        usage: const InferenceUsage(inputTokens: 3900, outputTokens: 560),
      );

      final output = await ScriptedEvalTarget.fromMap(
        {stressScenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(stressScenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(output.plannedBlocks, hasLength(2));
      expect(
        output.plannedBlocks.map((block) => block.id),
        ['client-brief-block', 'fixed-doctor-appointment'],
      );
      expect(
        output.plannedBlocks.map((block) => block.taskId),
        containsAll(['task-client-brief', 'task-doctor-appointment']),
      );
      final failed = runLevel1(
        stressScenario,
        output,
        profile: kFrontierProfile,
      ).where((check) => !check.passed).map((check) => check.detail).toList();
      expect(failed, isEmpty, reason: failed.join('\n'));
    },
  );

  test(
    'seeds capture, parsed decisions, baseline plan, and capacity into prompt',
    () async {
      final behavior = ScriptedAgentBehavior(
        toolCalls: [
          ToolCallRecord(
            name: 'draft_day_plan',
            args: {
              'dayId': kPlannerWorkflowDayId,
              'captureId': kPlannerWorkflowCaptureId,
              'capacityMinutes': scenario.appState.capacityMinutes,
              'decidedTaskIds': ['task-adr', 'task-run'],
              'blocks': [
                block(
                  id: 'baseline-pr-review',
                  categoryId: 'cat-work',
                  start: DateTime(2026, 6, 9, 8),
                  end: DateTime(2026, 6, 9, 8, 45),
                  taskId: 'task-adr',
                  title: 'Existing ADR review block',
                  reason: 'Preserve the seeded baseline review slot.',
                ),
                block(
                  id: 'adr-focus',
                  categoryId: 'cat-work',
                  start: DateTime(2026, 6, 9, 9),
                  end: DateTime(2026, 6, 9, 10, 30),
                  taskId: 'task-adr',
                  title: 'Finish the planner ADR',
                ),
                block(
                  id: 'morning-run',
                  categoryId: 'cat-health',
                  start: DateTime(2026, 6, 9, 10, 45),
                  end: DateTime(2026, 6, 9, 11, 25),
                  taskId: 'task-run',
                  title: 'Morning run',
                ),
              ],
            },
          ),
        ],
        finalResponse: 'Drafted the day from the capture context.',
        usage: const InferenceUsage(inputTokens: 4300, outputTokens: 720),
      );

      String? userMessage;
      final output = await PlannerEvalBench.runDraftingWake(
        scenario,
        kFrontierProfile,
        behavior,
        onUserMessage: (message) => userMessage = message,
      );

      expect(output.success, isTrue, reason: output.error);
      expect(output.plannedCapacityMinutes, scenario.appState.capacityMinutes);
      final prompt = userMessage;
      expect(prompt, isNotNull);
      final parsedPrompt = ParsedDayAgentPrompt(prompt!);
      final capture = parsedPrompt.json('capture')! as Map<String, dynamic>;
      final taskCorpus = (capture['taskCorpus'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final drafting = parsedPrompt.json('drafting')! as Map<String, dynamic>;
      final baselinePlan = drafting['baselinePlan'] as Map<String, dynamic>;
      final baselineBlocks = (baselinePlan['blocks'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final decidedTasks = (drafting['decidedTasks'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final decidedCaptureItems =
          (drafting['decidedCaptureItems'] as List<dynamic>)
              .cast<Map<String, dynamic>>();

      expect(capture['captureId'], kPlannerWorkflowCaptureId);
      expect(capture['transcript'], contains('review the slow-query PR'));
      expect(taskCorpus.map((task) => task['taskId']), contains('task-adr'));
      expect(taskCorpus.map((task) => task['taskId']), contains('task-run'));
      expect(baselinePlan['capacityMinutes'], 240);
      expect(baselineBlocks.single['id'], 'baseline-pr-review');
      expect(baselineBlocks.single['taskId'], 'task-adr');
      expect(decidedTasks.map((task) => task['id']), contains('task-adr'));
      expect(decidedCaptureItems.single['id'], kPlannerWorkflowParsedRunId);

      final promptVisibleTaskIds = <String>{
        for (final task in taskCorpus) task['taskId'] as String,
        for (final task in decidedTasks) task['id'] as String,
        for (final block in baselineBlocks)
          if (block['taskId'] case final String taskId) taskId,
      };
      expect(
        output.plannedBlocks
            .map((block) => block.taskId)
            .whereType<String>()
            .every(promptVisibleTaskIds.contains),
        isTrue,
        reason: 'planned task ids must be visible in production prompt state',
      );

      final failed = runLevel1(
        scenario,
        output,
        profile: kFrontierProfile,
      ).where((c) => !c.passed).map((c) => c.detail).toList();
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
              'dayId': kPlannerWorkflowDayId,
              'capacityMinutes': scenario.appState.capacityMinutes,
              'decidedTaskIds': ['task-adr'],
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

  test(
    'capture-only wake resolves day from capture and persists parsed items',
    () async {
      final captureOnly = plannerCaptureOnlyScenario;
      const behavior = ScriptedAgentBehavior(
        toolCalls: [
          ToolCallRecord(
            name: 'parse_capture_to_items',
            args: {
              'captureId': kPlannerCaptureOnlyCaptureId,
              'items': [
                {
                  'kind': 'matched',
                  'title': 'Finish the planner ADR',
                  'categoryId': 'cat-work',
                  'confidenceScore': 0.91,
                  'spokenPhrase': 'finish the planner ADR',
                  'matchedTaskId': 'task-adr-capture',
                  'estimateMinutes': 90,
                },
                {
                  'kind': 'newTask',
                  'title': 'Quick walk',
                  'categoryId': 'cat-health',
                  'confidenceScore': 0.32,
                  'spokenPhrase': 'take a quick walk',
                  'estimateMinutes': 20,
                  'timeAnchor': 'today',
                },
              ],
            },
          ),
        ],
        finalResponse: 'Parsed the capture.',
        usage: InferenceUsage(inputTokens: 2100, outputTokens: 360),
      );

      String? userMessage;
      final output = await PlannerEvalBench.runWake(
        captureOnly,
        kFrontierProfile,
        behavior,
        onUserMessage: (message) => userMessage = message,
      );

      expect(output.success, isTrue, reason: output.error);
      expect(output.plannedBlocks, isEmpty);
      expect(output.parsedCaptureItems, hasLength(2));
      expect(
        output.parsedCaptureItems.map((item) => item.title),
        containsAll([
          'Finish the planner ADR',
          'Quick walk',
        ]),
      );
      final matchedItem = output.parsedCaptureItems.firstWhere(
        (item) => item.title == 'Finish the planner ADR',
      );
      expect(matchedItem.matchedTaskId, 'task-adr-capture');
      expect(output.toolNames, ['parse_capture_to_items']);

      final prompt = userMessage;
      expect(prompt, isNotNull);
      final parsedPrompt = ParsedDayAgentPrompt(prompt!);
      expect(parsedPrompt.section('day_id'), kPlannerCaptureOnlyDayId);
      final triggerTokens =
          (parsedPrompt.json('trigger_tokens')! as List<dynamic>)
              .cast<String>();
      expect(triggerTokens, [
        'capture_submitted:$kPlannerCaptureOnlyCaptureId',
      ]);
      expect(parsedPrompt.has('drafting'), isFalse);
      final capture = parsedPrompt.json('capture')! as Map<String, dynamic>;
      expect(capture['captureId'], kPlannerCaptureOnlyCaptureId);
      expect(capture['transcript'], contains('quick walk'));
      final taskCorpus = (capture['taskCorpus'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(
        taskCorpus.map((task) => task['taskId']),
        contains('task-adr-capture'),
      );

      final failed = runLevel1(
        captureOnly,
        output,
        profile: kFrontierProfile,
      ).where((c) => !c.passed).map((c) => c.detail).toList();
      expect(failed, isEmpty, reason: failed.join('\n'));
    },
  );

  test(
    'ambiguous capture wake persists a low-confidence new item',
    () async {
      final ambiguousCapture = plannerCaptureAmbiguousPersonScenario;
      const behavior = ScriptedAgentBehavior(
        toolCalls: [
          ToolCallRecord(
            name: 'parse_capture_to_items',
            args: {
              'captureId': kPlannerAmbiguousCaptureId,
              'items': [
                {
                  'kind': 'newTask',
                  'title': 'Call Sam',
                  'categoryId': 'cat-admin',
                  'confidenceScore': 0.34,
                  'spokenPhrase': 'Call Sam about the thing',
                  'estimateMinutes': 15,
                  'timeAnchor': 'after lunch',
                },
              ],
            },
          ),
        ],
        finalResponse: 'Parsed an ambiguous call reminder.',
        usage: InferenceUsage(inputTokens: 2200, outputTokens: 300),
      );

      final output = await PlannerEvalBench.runWake(
        ambiguousCapture,
        kFrontierProfile,
        behavior,
      );

      expect(output.success, isTrue, reason: output.error);
      expect(output.parsedCaptureItems, hasLength(1));
      final item = output.parsedCaptureItems.single;
      expect(item.title, 'Call Sam');
      expect(item.matchedTaskId, isNull);
      expect(item.confidence, 'low');
      expect(item.lowConfidence, isFalse);
      expect(item.confidenceScore, lessThanOrEqualTo(0.5));
      final failed = runLevel1(
        ambiguousCapture,
        output,
        profile: kFrontierProfile,
      ).where((check) => !check.passed).map((check) => check.detail).toList();
      expect(failed, isEmpty, reason: failed.join('\n'));
    },
  );

  test('maps planned block order from persisted DayPlanEntity', () async {
    final behavior = ScriptedAgentBehavior(
      toolCalls: [
        ToolCallRecord(
          name: 'draft_day_plan',
          args: {
            'dayId': kPlannerWorkflowDayId,
            'capacityMinutes': scenario.appState.capacityMinutes,
            'decidedTaskIds': ['task-run', 'task-adr'],
            'blocks': [
              block(
                id: 'late-script',
                categoryId: 'cat-work',
                start: DateTime(2026, 6, 9, 10),
                end: DateTime(2026, 6, 9, 11),
                taskId: 'task-adr',
                title: 'Late scripted block',
              ),
              block(
                id: 'early-script',
                categoryId: 'cat-health',
                start: DateTime(2026, 6, 9, 7, 30),
                end: DateTime(2026, 6, 9, 8),
                taskId: 'task-run',
                title: 'Early persisted block',
              ),
            ],
          },
        ),
      ],
      usage: const InferenceUsage(inputTokens: 1000, outputTokens: 200),
    );

    final output = await ScriptedEvalTarget.fromMap(
      {scenario.id: behavior},
      profileName: kFrontierProfile.name,
    ).run(scenario, kFrontierProfile);

    expect(output.success, isTrue, reason: output.error);
    expect(
      (output.toolCalls.single.args['blocks'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((block) => block['id']),
      ['late-script', 'early-script'],
    );
    expect(
      output.plannedBlocks.map((block) => block.id),
      ['early-script', 'late-script'],
    );
  });

  test('maps plan-diff proposals from persisted ChangeSetEntity', () async {
    final behavior = ScriptedAgentBehavior(
      toolCalls: [
        ToolCallRecord(
          name: 'draft_day_plan',
          args: {
            'dayId': kPlannerWorkflowDayId,
            'capacityMinutes': scenario.appState.capacityMinutes,
            'decidedTaskIds': ['task-adr'],
            'blocks': [
              block(
                id: 'adr-block',
                categoryId: 'cat-work',
                start: DateTime(2026, 6, 9, 9),
                end: DateTime(2026, 6, 9, 10),
                taskId: 'task-adr',
                title: 'Finish the planner ADR',
              ),
            ],
          },
        ),
        ToolCallRecord(
          name: 'propose_plan_diff',
          args: {
            'dayId': kPlannerWorkflowDayId,
            'changes': [
              {
                'action': 'added',
                'reason': 'Protect review time after drafting.',
                'to': {
                  'start': DateTime(2026, 6, 9, 10).toIso8601String(),
                  'end': DateTime(2026, 6, 9, 10, 30).toIso8601String(),
                  'title': 'Review the ADR diff',
                  'categoryId': 'cat-work',
                  'taskId': 'task-adr',
                  'type': 'ai',
                },
              },
            ],
          },
        ),
      ],
      usage: const InferenceUsage(inputTokens: 1400, outputTokens: 300),
    );

    final output = await ScriptedEvalTarget.fromMap(
      {scenario.id: behavior},
      profileName: kFrontierProfile.name,
    ).run(scenario, kFrontierProfile);

    expect(output.success, isTrue, reason: output.error);
    expect(output.toolNames, ['draft_day_plan', 'propose_plan_diff']);
    expect(output.proposals, hasLength(1));

    final proposal = output.proposals.single;
    expect(proposal.changeSetId, startsWith('plan_diff:'));
    expect(proposal.targetId, 'day_agent_plan:$kPlannerWorkflowDayId');
    expect(proposal.itemIndex, 0);
    expect(proposal.toolName, 'add_block');
    expect(proposal.status, 'pending');
    expect(proposal.args['action'], 'added');
    expect(
      proposal.args['toStart'],
      DateTime(2026, 6, 9, 10).toIso8601String(),
    );
    expect(proposal.args['title'], 'Review the ADR diff');
    expect(proposal.humanSummary, contains('Review the ADR diff'));
  });

  test(
    'failed plan-diff tool results stay out of durable proposals',
    () async {
      final behavior = ScriptedAgentBehavior(
        toolCalls: [
          ToolCallRecord(
            name: 'draft_day_plan',
            args: {
              'dayId': kPlannerWorkflowDayId,
              'capacityMinutes': scenario.appState.capacityMinutes,
              'decidedTaskIds': ['task-adr'],
              'blocks': [
                block(
                  id: 'adr-block',
                  categoryId: 'cat-work',
                  start: DateTime(2026, 6, 9, 9),
                  end: DateTime(2026, 6, 9, 10),
                  taskId: 'task-adr',
                  title: 'Finish the planner ADR',
                ),
              ],
            },
          ),
          ToolCallRecord(
            name: 'propose_plan_diff',
            args: {
              'dayId': kPlannerWorkflowDayId,
              'changes': [
                {
                  'action': 'added',
                  'reason': 'Protect review time after drafting.',
                  'to': {
                    'start': DateTime(2026, 6, 9, 10, 30).toIso8601String(),
                    'end': DateTime(2026, 6, 9, 10).toIso8601String(),
                    'title': 'Review the ADR diff',
                    'categoryId': 'cat-work',
                    'taskId': 'task-adr',
                    'type': 'ai',
                  },
                },
              ],
            },
          ),
        ],
        usage: const InferenceUsage(inputTokens: 1400, outputTokens: 300),
      );

      final output = await ScriptedEvalTarget.fromMap(
        {scenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(scenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(output.toolNames, ['draft_day_plan', 'propose_plan_diff']);
      expect(output.toolResults, hasLength(2));
      expect(output.toolResults.first.success, isTrue);
      final failedDiff = output.toolResults.last;
      expect(failedDiff.name, 'propose_plan_diff');
      expect(failedDiff.success, isFalse);
      expect(failedDiff.error, contains('to.end'));
      expect(
        output.plannedBlocks,
        hasLength(1),
        reason: 'the valid draft should still be read from durable state',
      );
      expect(
        output.proposals,
        isEmpty,
        reason: 'production rejected the malformed diff before persistence',
      );

      final checks = runLevel1(scenario, output, profile: kFrontierProfile);
      final toolResults = checks.firstWhere(
        (check) => check.name == 'tool_results_succeeded',
      );
      expect(toolResults.passed, isFalse);
      expect(toolResults.detail, contains('propose_plan_diff'));
      expect(toolResults.detail, contains('to.end'));
    },
  );

  test(
    'maps planned blocks from the persisted DayPlanEntity after retry',
    () async {
      final behavior = ScriptedAgentBehavior.turns([
        ScriptedAgentTurn(
          toolCalls: [
            ToolCallRecord(
              name: 'draft_day_plan',
              args: {
                'dayId': kPlannerWorkflowDayId,
                'capacityMinutes': scenario.appState.capacityMinutes,
                'decidedTaskIds': ['task-adr'],
                'blocks': [
                  block(
                    categoryId: 'cat-work',
                    start: DateTime(2026, 6, 9, 8),
                    end: DateTime(2026, 6, 9, 9),
                    taskId: 'task-adr',
                    title: 'Rejected missing-reason block',
                    reason: null,
                  ),
                ],
              },
            ),
          ],
          usage: const InferenceUsage(inputTokens: 1000, outputTokens: 100),
        ),
        ScriptedAgentTurn(
          toolCalls: [
            ToolCallRecord(
              name: 'draft_day_plan',
              args: {
                'dayId': kPlannerWorkflowDayId,
                'capacityMinutes': scenario.appState.capacityMinutes,
                'decidedTaskIds': ['task-adr'],
                'blocks': [
                  block(
                    categoryId: 'cat-work',
                    start: DateTime(2026, 6, 9, 10),
                    end: DateTime(2026, 6, 9, 11),
                    taskId: 'task-adr',
                    title: 'Accepted persisted block',
                  ),
                ],
              },
            ),
          ],
          usage: const InferenceUsage(inputTokens: 2000, outputTokens: 200),
        ),
      ]);

      final output = await ScriptedEvalTarget.fromMap(
        {scenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(scenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(output.turnCount, 2);
      expect(output.toolCalls, hasLength(2));
      expect(output.plannedBlocks, hasLength(1));
      expect(output.plannedBlocks.single.start, DateTime(2026, 6, 9, 10));
      expect(output.plannedBlocks.single.taskId, 'task-adr');
      expect(output.usage.inputTokens, 3000);
      expect(output.usage.outputTokens, 300);
    },
  );

  test('covers every public planner workflow adversarial scenario', () {
    final coveredScenarioIds = {
      plannerWorkflowAmbiguousCarryoverScenario.id,
      plannerWorkflowFocusBoundaryScenario.id,
      plannerCaptureAmbiguousPersonScenario.id,
    };
    final requiredScenarioIds = planningEvalScenarios
        .where(
          (scenario) =>
              scenario.metadata.isAdversarial &&
              scenario.metadata.tags.contains('workflow'),
        )
        .map((scenario) => scenario.id)
        .toSet();

    expect(coveredScenarioIds, requiredScenarioIds);
  });
}
