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
import '../harness/eval_profile_config.dart';
import '../harness/scripted_eval_target.dart';
import '../harness/task_agent_eval_bench.dart';
import 'eval_scenarios.dart';

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

  final scenario = taskWorkflowReleaseNotesScenario;

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
    const context = EvalTargetRunContext(
      runId: 'run-task-context',
      scenarioId: 'task_release_notes',
      profileName: 'frontier-reasoning',
      trialIndex: 2,
    );

    final output = await ScriptedEvalTarget.fromMap(
      {scenario.id: behavior},
      profileName: kFrontierProfile.name,
    ).run(scenario, kFrontierProfile, context: context);

    expect(output.success, isTrue, reason: output.error);
    expect(output.workflowRun, isNotNull);
    expect(output.workflowRun!.runKey, contains(context.cellId));
    expect(output.workflowRun!.threadId, contains(context.cellId));
    expect(output.report, isNotNull);
    expect(output.report!.oneLiner, 'Groomed the release-notes task');
    expect(output.observations, hasLength(1));
    expect(output.usage.inputTokens, 1800);
    expect(output.usage.outputTokens, 320);
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
    expect(output.resolvedModel!.usageModelId, expectedProfile.providerModelId);
    expect(output.resolvedModel!.providerType, 'gemini');
    expect(output.resolvedModel!.providerModelId, isNot(contains('legacy')));

    final checks = runLevel1(scenario, output, profile: kFrontierProfile);
    final failed = checks.where((c) => !c.passed).map((c) => c.detail).toList();
    expect(failed, isEmpty, reason: failed.join('\n'));
  });

  test(
    'uses decided task trigger as active task when first fixture is a decoy',
    () async {
      final decoyScenario = EvalScenario(
        id: 'task_workflow_decoy_first',
        title: 'Real workflow: decided task is not the first fixture',
        agentKind: AgentKind.taskAgent,
        appState: MockedAppState(
          now: DateTime(2026, 6, 9, 10),
          categoryIds: const ['cat-001'],
          categories: [kEvalWorkCategory],
          tasks: const [
            MockTask(
              id: 'task-decoy',
              title: 'Do not mutate this task',
              status: 'OPEN',
              categoryId: 'cat-001',
            ),
            MockTask(
              id: 'task-active',
              title: 'Use this task from trigger tokens',
              status: 'OPEN',
              categoryId: 'cat-001',
            ),
          ],
        ),
        userInput: const UserInput(
          transcript: 'Add a checklist item to the active task.',
          triggerTokens: {'decided_task:task-active'},
        ),
      );
      const behavior = ScriptedAgentBehavior(
        toolCalls: [
          goodReport,
          ToolCallRecord(
            name: 'add_multiple_checklist_items',
            args: {
              'items': [
                {'title': 'Review active task notes'},
              ],
            },
          ),
        ],
        usage: InferenceUsage(inputTokens: 1200, outputTokens: 220),
      );

      String? userMessage;
      final output = await TaskAgentEvalBench.runWake(
        decoyScenario,
        kFrontierProfile,
        behavior,
        onUserMessage: (message) => userMessage = message,
      );

      expect(output.success, isTrue, reason: output.error);
      expect(userMessage, isNotNull);
      expect(userMessage, contains('Use this task from trigger tokens'));
      expect(userMessage, isNot(contains('Do not mutate this task')));
      expect(output.proposals, hasLength(1));
      expect(output.proposals.single.targetId, 'task-active');
      expect(output.proposals.single.targetId, isNot('task-decoy'));
      final failed = runLevel1(
        decoyScenario,
        output,
        profile: kFrontierProfile,
      ).where((c) => !c.passed).map((c) => c.detail).toList();
      expect(failed, isEmpty, reason: failed.join('\n'));
    },
  );

  test(
    'real workflow resolves a local profile through Ollama config',
    () async {
      const behavior = ScriptedAgentBehavior(
        toolCalls: [goodReport],
        usage: InferenceUsage(inputTokens: 900, outputTokens: 180),
      );

      final output = await ScriptedEvalTarget.fromMap(
        {scenario.id: behavior},
        profileName: kLocalSmallProfile.name,
      ).run(scenario, kLocalSmallProfile);

      final expectedProfile = evalProfileConfig(kLocalSmallProfile);
      expect(output.success, isTrue, reason: output.error);
      expect(output.resolvedModel, isNotNull);
      expect(output.resolvedModel!.profileId, expectedProfile.profileId);
      expect(output.resolvedModel!.modelConfigId, kLocalSmallProfile.modelId);
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
      expect(output.resolvedModel!.providerType, 'ollama');
      expect(output.resolvedModel!.providerModelId, isNot(contains('legacy')));
    },
  );

  test('maps graded output from persisted workflow entities', () async {
    const behavior = ScriptedAgentBehavior(
      toolCalls: [
        ToolCallRecord(
          name: 'update_report',
          args: {
            'oneLiner': 'This invalid call must not become the report',
            'content': 'Missing TLDR, so the workflow rejects this report.',
          },
        ),
        ToolCallRecord(
          name: 'update_report',
          args: {
            'oneLiner': '  Durable report wins  ',
            'tldr': '  Accepted by the workflow.  ',
            'content': '  ## Durable\nPersisted report body.  ',
          },
        ),
        ToolCallRecord(
          name: 'record_observations',
          args: {
            'observations': [
              '  Persisted observation text  ',
              {'text': '   '},
            ],
          },
        ),
      ],
      usage: InferenceUsage(
        inputTokens: 1200,
        outputTokens: 240,
        thoughtsTokens: 30,
        cachedInputTokens: 100,
      ),
    );

    final output = await ScriptedEvalTarget.fromMap(
      {scenario.id: behavior},
      profileName: kFrontierProfile.name,
    ).run(scenario, kFrontierProfile);

    expect(output.toolCalls, hasLength(3));
    expect(output.toolResults, hasLength(3));
    expect(output.toolResults.first.name, 'update_report');
    expect(output.toolResults.first.success, isFalse);
    expect(output.toolResults.first.error, contains('"tldr"'));
    expect(output.toolResults[1].name, 'update_report');
    expect(output.toolResults[1].success, isTrue);
    expect(output.report, isNotNull);
    expect(output.report!.oneLiner, 'Durable report wins');
    expect(output.report!.tldr, 'Accepted by the workflow.');
    expect(output.report!.content, '## Durable\nPersisted report body.');
    expect(output.observations, ['Persisted observation text']);
    expect(output.usage.inputTokens, 1200);
    expect(output.usage.outputTokens, 240);
    expect(output.usage.thoughtsTokens, 30);
    expect(output.usage.cachedInputTokens, 100);
  });

  test('allows explicitly expected report tool recovery stress case', () async {
    const behavior = ScriptedAgentBehavior(
      toolCalls: [
        ToolCallRecord(
          name: 'update_report',
          args: {
            'oneLiner': 'This invalid report is missing a TLDR.',
            'content': 'The first attempt should be rejected by validation.',
          },
        ),
        ToolCallRecord(
          name: 'update_report',
          args: {
            'oneLiner': 'Recovered release-note report',
            'tldr': 'Recovered release-note report after validation feedback.',
            'content':
                'Recovered release-note report with the required summary.',
          },
        ),
      ],
      usage: InferenceUsage(inputTokens: 1500, outputTokens: 260),
    );
    final stressScenario = taskWorkflowReportRecoveryScenario;

    final output = await ScriptedEvalTarget.fromMap(
      {stressScenario.id: behavior},
      profileName: kFrontierProfile.name,
    ).run(stressScenario, kFrontierProfile);

    expect(output.success, isTrue, reason: output.error);
    expect(output.toolResults, hasLength(2));
    expect(output.toolResults.first.name, 'update_report');
    expect(output.toolResults.first.success, isFalse);
    expect(output.toolResults.last.name, 'update_report');
    expect(output.toolResults.last.success, isTrue);
    expect(output.report, isNotNull);
    expect(output.report!.oneLiner, 'Recovered release-note report');

    final checks = runLevel1(
      stressScenario,
      output,
      profile: kFrontierProfile,
    );
    final failed = checks
        .where((check) => !check.passed)
        .map((check) => check.detail)
        .toList();
    expect(failed, isEmpty, reason: failed.join('\n'));
    expect(
      named(checks, 'tool_results_succeeded').detail,
      contains('allowed recoverable failure'),
    );
  });

  test(
    'adversarial label-scope wake persists only the valid label proposal',
    () async {
      const behavior = ScriptedAgentBehavior(
        toolCalls: [
          goodReport,
          ToolCallRecord(
            name: 'assign_task_labels',
            args: {
              'labels': [
                {'id': 'lbl-release', 'confidence': 'high'},
              ],
            },
          ),
        ],
        usage: InferenceUsage(inputTokens: 1360, outputTokens: 260),
      );
      final stressScenario = taskWorkflowLabelScopeBoundaryScenario;

      final output = await ScriptedEvalTarget.fromMap(
        {stressScenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(stressScenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(output.proposals, hasLength(1));
      final proposal = output.proposals.single;
      expect(proposal.toolName, 'assign_task_label');
      expect(proposal.targetId, 'task-notes');
      expect(proposal.status, 'pending');
      expect(proposal.args, {'id': 'lbl-release', 'confidence': 'high'});
      expect(proposal.humanSummary, contains('Release Notes'));
      expect(
        output.proposals.map((item) => item.args['id']),
        isNot(contains('lbl-docs')),
      );
      expect(
        output.proposals.map((item) => item.args['id']),
        isNot(contains('lbl-legal')),
      );
      expect(
        output.proposals.map((item) => item.args['id']),
        isNot(contains('lbl-admin')),
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
    'adversarial completion-boundary wake avoids status transition',
    () async {
      const behavior = ScriptedAgentBehavior(
        toolCalls: [
          ToolCallRecord(
            name: 'update_report',
            args: {
              'oneLiner': 'Ready for approval',
              'tldr': 'Added an approval note without changing status.',
              'content': 'Ready for approval; terminal completion was avoided.',
            },
          ),
          ToolCallRecord(
            name: 'add_multiple_checklist_items',
            args: {
              'items': [
                {'title': 'Prepare approval note'},
              ],
            },
          ),
        ],
        usage: InferenceUsage(inputTokens: 1280, outputTokens: 230),
      );
      final stressScenario = taskWorkflowCompletionBoundaryScenario;

      final output = await ScriptedEvalTarget.fromMap(
        {stressScenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(stressScenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(output.toolNames, [
        'update_report',
        'add_multiple_checklist_items',
      ]);
      expect(output.proposals, hasLength(1));
      final proposal = output.proposals.single;
      expect(proposal.toolName, 'add_checklist_item');
      expect(proposal.targetId, 'task-approval');
      expect(proposal.args, {'title': 'Prepare approval note'});
      expect(output.report?.oneLiner, 'Ready for approval');

      final checks = runLevel1(
        stressScenario,
        output,
        profile: kFrontierProfile,
      );
      final failed = checks
          .where((check) => !check.passed)
          .map((check) => check.detail)
          .toList();
      expect(failed, isEmpty, reason: failed.join('\n'));
      expect(output.toolNames, isNot(contains('set_task_status')));
    },
  );

  test(
    'maps deferred proposals from persisted ChangeSetEntity items',
    () async {
      const behavior = ScriptedAgentBehavior(
        toolCalls: [
          goodReport,
          ToolCallRecord(
            name: 'add_multiple_checklist_items',
            args: {
              'items': [
                {'title': 'Review changelog'},
                {'title': 'Publish release notes'},
              ],
            },
          ),
        ],
        usage: InferenceUsage(inputTokens: 1300, outputTokens: 260),
      );

      final output = await ScriptedEvalTarget.fromMap(
        {scenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(scenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(output.toolCalls[1].name, 'add_multiple_checklist_items');
      expect(output.proposals, hasLength(2));

      final first = output.proposals.first;
      expect(first.targetId, 'task-notes');
      expect(first.itemIndex, 0);
      expect(first.toolName, 'add_checklist_item');
      expect(first.status, 'pending');
      expect(first.args['title'], 'Review changelog');
      expect(first.humanSummary, 'Add: "Review changelog"');

      final second = output.proposals.last;
      expect(second.changeSetId, first.changeSetId);
      expect(second.itemIndex, 1);
      expect(second.toolName, 'add_checklist_item');
      expect(second.args['title'], 'Publish release notes');
      expect(second.humanSummary, 'Add: "Publish release notes"');
    },
  );

  test(
    'resolves scenario label definitions in persisted proposal summaries',
    () async {
      const behavior = ScriptedAgentBehavior(
        toolCalls: [
          goodReport,
          ToolCallRecord(
            name: 'assign_task_labels',
            args: {
              'labels': [
                {'id': 'lbl-release', 'confidence': 'high'},
              ],
            },
          ),
        ],
        usage: InferenceUsage(inputTokens: 1320, outputTokens: 260),
      );

      final output = await ScriptedEvalTarget.fromMap(
        {scenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(scenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(output.toolCalls[1].name, 'assign_task_labels');
      expect(output.proposals, hasLength(1));
      final proposal = output.proposals.single;
      expect(proposal.toolName, 'assign_task_label');
      expect(proposal.args, {'id': 'lbl-release', 'confidence': 'high'});
      expect(
        proposal.humanSummary,
        contains('Release Notes'),
        reason:
            'summary must use the scenario-seeded LabelDefinition name, not only the raw id',
      );
      expect(proposal.humanSummary, contains('high'));

      final checks = runLevel1(scenario, output, profile: kFrontierProfile);
      final failed = checks.where((c) => !c.passed).map((c) => c.detail);
      expect(failed, isEmpty, reason: failed.join('\n'));
    },
  );

  test(
    'Level 1 rejects invalid persisted label proposals',
    () async {
      const behavior = ScriptedAgentBehavior(
        toolCalls: [
          goodReport,
          ToolCallRecord(
            name: 'assign_task_labels',
            args: {
              'labels': [
                {'id': 'lbl-docs', 'confidence': 'high'},
                {'id': 'lbl-legal', 'confidence': 'high'},
                {'id': 'lbl-admin', 'confidence': 'medium'},
              ],
            },
          ),
        ],
        usage: InferenceUsage(inputTokens: 1350, outputTokens: 270),
      );

      final output = await ScriptedEvalTarget.fromMap(
        {scenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(scenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(output.toolCalls[1].name, 'assign_task_labels');
      final rawLabels = output.toolCalls[1].args['labels'] as List<dynamic>;
      expect(rawLabels, hasLength(3));
      expect(
        rawLabels.whereType<Map<String, dynamic>>().map((label) => label['id']),
        ['lbl-docs', 'lbl-legal', 'lbl-admin'],
        reason: 'raw model intent still attempted invalid label assignments',
      );

      final labelProposals = output.proposals
          .where((proposal) => proposal.toolName == 'assign_task_label')
          .toList();
      expect(
        labelProposals.map((proposal) => proposal.args['id']),
        isNot(contains('lbl-docs')),
        reason:
            'production existing-label resolver should suppress already-assigned labels',
      );

      final labelCheck = named(
        runLevel1(scenario, output, profile: kFrontierProfile),
        'valid_label_proposals',
      );
      expect(labelCheck.passed, isFalse);
      expect(
        labelCheck.detail,
        anyOf(
          contains('lbl-legal'),
          contains('lbl-admin'),
        ),
      );
    },
  );

  test(
    'maps consolidated pending proposal sets from final persistence state',
    () async {
      const behavior = ScriptedAgentBehavior(
        toolCalls: [
          goodReport,
          ToolCallRecord(
            name: 'add_multiple_checklist_items',
            args: {
              'items': [
                {'title': 'Review changelog'},
                {'title': 'Publish release notes'},
              ],
            },
          ),
        ],
        usage: InferenceUsage(inputTokens: 1400, outputTokens: 280),
      );

      final output = await ScriptedEvalTarget.fromMap(
        {taskWorkflowPendingProposalMergeScenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(taskWorkflowPendingProposalMergeScenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(output.toolCalls[1].name, 'add_multiple_checklist_items');
      final rawItems = output.toolCalls[1].args['items'] as List<dynamic>;
      expect(
        rawItems.whereType<Map<String, dynamic>>().any(
          (item) => item['title'] == 'Review changelog',
        ),
        isTrue,
        reason: 'raw model intent still attempted the duplicate proposal',
      );
      expect(output.proposals, hasLength(4));

      final pending = output.proposals
          .where((proposal) => proposal.status == 'pending')
          .toList();
      expect(
        pending.map((proposal) => proposal.changeSetId).toSet(),
        {'existing-new'},
        reason: 'production merge should consolidate into the newest set',
      );
      expect(
        pending.map((proposal) => proposal.changeSetStatus).toSet(),
        {'pending'},
      );
      expect(
        pending.map((proposal) => proposal.args['title']),
        ['Check smoke tests', 'Review changelog', 'Publish release notes'],
      );
      expect(
        pending
            .where((proposal) => proposal.args['title'] == 'Review changelog')
            .toList(),
        hasLength(1),
        reason: 'duplicate raw tool args must not create duplicate open rows',
      );

      final retracted = output.proposals
          .where((proposal) => proposal.status == 'retracted')
          .toList();
      expect(retracted, hasLength(1));
      expect(retracted.single.changeSetId, 'existing-old');
      expect(retracted.single.changeSetStatus, 'resolved');
      expect(retracted.single.args['title'], 'Review changelog');
    },
  );

  test(
    'keeps a previously rejected proposal from becoming pending again',
    () async {
      const behavior = ScriptedAgentBehavior(
        toolCalls: [
          goodReport,
          ToolCallRecord(
            name: 'add_multiple_checklist_items',
            args: {
              'items': [
                {'title': 'Legal review'},
              ],
            },
          ),
        ],
        usage: InferenceUsage(inputTokens: 1250, outputTokens: 250),
      );

      final output = await ScriptedEvalTarget.fromMap(
        {taskWorkflowRejectedProposalStickinessScenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(taskWorkflowRejectedProposalStickinessScenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(output.toolCalls[1].name, 'add_multiple_checklist_items');
      final rawItems = output.toolCalls[1].args['items'] as List<dynamic>;
      expect(
        rawItems.whereType<Map<String, dynamic>>().any(
          (item) => item['title'] == 'Legal review',
        ),
        isTrue,
        reason: 'raw model intent still attempted the rejected proposal',
      );

      final legalReview = output.proposals
          .where((proposal) => proposal.args['title'] == 'Legal review')
          .toList();
      expect(output.proposals, hasLength(1));
      expect(
        legalReview,
        hasLength(1),
        reason:
            'rejected display-key history should not create a fresh duplicate row',
      );
      expect(legalReview.single.changeSetId, 'rejected-legal-review');
      expect(legalReview.single.changeSetStatus, 'resolved');
      expect(legalReview.single.status, 'rejected');
      expect(legalReview.single.toolName, 'add_checklist_item');
      expect(legalReview.single.args, {
        'title': 'Legal review',
        'legacySchema': true,
      });
      expect(legalReview.single.humanSummary, 'Add: "Legal review"');
      expect(
        output.proposals.where(
          (proposal) =>
              proposal.changeSetStatus == 'pending' ||
              proposal.status == 'pending',
        ),
        isEmpty,
      );
      final failed = runLevel1(
        taskWorkflowRejectedProposalStickinessScenario,
        output,
        profile: kFrontierProfile,
      ).where((check) => !check.passed).map((check) => check.detail).toList();
      expect(failed, isEmpty, reason: failed.join('\n'));
    },
  );

  test(
    'suppresses already-satisfied checklist updates from durable proposals',
    () async {
      const behavior = ScriptedAgentBehavior(
        toolCalls: [
          goodReport,
          ToolCallRecord(
            name: 'update_checklist_items',
            args: {
              'items': [
                {'id': 'ci-1', 'isChecked': true},
              ],
            },
          ),
        ],
        usage: InferenceUsage(inputTokens: 1260, outputTokens: 240),
      );

      final output = await ScriptedEvalTarget.fromMap(
        {taskWorkflowCheckedChecklistNoopScenario.id: behavior},
        profileName: kFrontierProfile.name,
      ).run(taskWorkflowCheckedChecklistNoopScenario, kFrontierProfile);

      expect(output.success, isTrue, reason: output.error);
      expect(output.toolCalls[1].name, 'update_checklist_items');
      final rawItems = output.toolCalls[1].args['items'] as List<dynamic>;
      expect(
        rawItems.whereType<Map<String, dynamic>>().single,
        {'id': 'ci-1', 'isChecked': true},
        reason: 'raw model intent still attempted the redundant update',
      );
      expect(
        output.proposals,
        isEmpty,
        reason:
            'production checklist-state resolver should suppress the no-op before persistence',
      );
      final failed = runLevel1(
        taskWorkflowCheckedChecklistNoopScenario,
        output,
        profile: kFrontierProfile,
      ).where((check) => !check.passed).map((check) => check.detail).toList();
      expect(failed, isEmpty, reason: failed.join('\n'));
    },
  );

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
        named(
          runLevel1(scenario, output, profile: kFrontierProfile),
          'report_published',
        ).passed,
        isTrue,
      );
      final estimate = named(
        runLevel1(scenario, output, profile: kFrontierProfile),
        'estimate_range',
      );
      expect(estimate.passed, isFalse);
      expect(estimate.detail, contains('5000'));
    },
  );

  test('covers every public task workflow adversarial scenario', () {
    final coveredScenarioIds = {
      taskWorkflowReportRecoveryScenario.id,
      taskWorkflowLabelScopeBoundaryScenario.id,
      taskWorkflowCompletionBoundaryScenario.id,
      taskWorkflowRejectedProposalStickinessScenario.id,
      taskWorkflowCheckedChecklistNoopScenario.id,
    };
    final requiredScenarioIds = taskEvalScenarios
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
