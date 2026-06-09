// Real-workflow Level 1 bench for the task agent (ADR 0029, Phase 1).
//
// Mirrors PlannerEvalBench but for `TaskAgentWorkflow.execute(...)`. It seeds an
// `EvalScenario` (one active task) onto the centralized mocks + the existing
// task-agent test helpers, scripts the model response through the proven
// `MockConversationRepository.sendMessageDelegate` -> `strategy.processToolCalls`
// path (mock ConversationManager), runs the real workflow under `withClock`, and
// maps the result to an `AgentRunOutput` the SAME Level 1 suite grades.
//
// The report is read from the scripted `update_report` tool call (which is also
// what `TaskAgentStrategy.extractReportContent()` parses), so the mapping stays
// consistent with what the workflow actually extracts.
//
// The CALLER must, in `setUpAll`, register fallbacks and GetIt singletons the
// task workflow resolves:
//
//   setUpAll(() async {
//     registerAllFallbackValues();
//     await setUpTestGetIt(additionalSetup: () {
//       getIt
//         ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
//         ..registerSingleton<TimeService>(TimeService());
//     });
//   });
//   tearDownAll(tearDownTestGetIt);

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../features/agents/test_utils.dart';
import '../../features/agents/workflow/task_agent_workflow_test_helpers.dart';
import '../../mocks/mocks.dart';
import 'eval_models.dart';
import 'planner_eval_bench.dart' show ScriptedAgentBehavior;

/// Runs the real task-agent workflow for a single-task wake.
abstract final class TaskAgentEvalBench {
  static const _agentId = 'eval-task-agent';
  static const _runKey = 'eval-run';
  static const _threadId = 'eval-thread';

  /// Seeds the scenario's active task, runs `TaskAgentWorkflow.execute(...)`
  /// replaying [behavior], and returns the mapped output.
  static Future<AgentRunOutput> runWake(
    EvalScenario scenario,
    ScriptedAgentBehavior behavior,
  ) async {
    if (scenario.appState.tasks.isEmpty) {
      throw ArgumentError(
        'Task-agent scenario "${scenario.id}" needs at least one task',
      );
    }
    final taskId = scenario.appState.tasks.first.id;
    final now = scenario.appState.now;

    final agentRepository = MockAgentRepository();
    final syncService = MockAgentSyncService();
    final conversationManager = MockConversationManager();
    final conversationRepository = MockConversationRepository(
      conversationManager,
    );
    final aiInputRepository = MockAiInputRepository();
    final aiConfigRepository = MockAiConfigRepository();
    final journalDb = MockJournalDb();
    final cloudInferenceRepository = MockCloudInferenceRepository();
    final journalRepository = MockJournalRepository();
    final checklistRepository = MockChecklistRepository();
    final labelsRepository = MockLabelsRepository();
    final templateService = MockAgentTemplateService();

    final testAgentState = makeTestState(
      id: 'state-$_agentId',
      agentId: _agentId,
      slots: AgentSlots(activeTaskId: taskId),
      updatedAt: now,
    );
    final testTemplate = makeTestTemplate();
    final testTemplateVersion = makeTestTemplateVersion(
      directives: 'You are a diligent task agent.',
    );
    final geminiProvider =
        AiConfig.inferenceProvider(
              id: 'gemini-provider-eval',
              baseUrl: 'https://generativelanguage.googleapis.com',
              apiKey: 'eval-key',
              name: 'Gemini',
              createdAt: DateTime(2024),
              inferenceProviderType: InferenceProviderType.gemini,
            )
            as AiConfigInferenceProvider;
    final geminiModel =
        AiConfig.model(
              id: 'model-gemini-eval',
              name: 'Gemini',
              providerModelId: testTemplate.modelId,
              inferenceProviderId: 'gemini-provider-eval',
              createdAt: DateTime(2024),
              inputModalities: const [Modality.text],
              outputModalities: const [Modality.text],
              isReasoningModel: true,
              supportsFunctionCalling: true,
            )
            as AiConfigModel;

    final identity =
        AgentDomainEntity.agent(
              id: _agentId,
              agentId: _agentId,
              kind: 'task_agent',
              displayName: 'Eval Task Agent',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {'cat-001'},
              currentStateId: 'state-$_agentId',
              config: const AgentConfig(),
              createdAt: DateTime(2024),
              updatedAt: now,
              vectorClock: null,
            )
            as AgentIdentityEntity;

    _applyDefaults(
      agentRepository: agentRepository,
      syncService: syncService,
      aiInputRepository: aiInputRepository,
      journalDb: journalDb,
      templateService: templateService,
      testTemplate: testTemplate,
      testTemplateVersion: testTemplateVersion,
    );
    stubFullExecutePath(
      mockAgentRepository: agentRepository,
      mockAiInputRepository: aiInputRepository,
      mockAiConfigRepository: aiConfigRepository,
      mockConversationManager: conversationManager,
      testAgentState: testAgentState,
      geminiModel: geminiModel,
      geminiProvider: geminiProvider,
      agentId: _agentId,
      taskId: taskId,
    );

    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          if (strategy is TaskAgentStrategy) {
            await strategy.processToolCalls(
              toolCalls: _toToolCalls(behavior.toolCalls),
              manager: conversationManager,
            );
          }
          return behavior.usage;
        };

    final workflow = createTestWorkflow(
      agentRepository: agentRepository,
      conversationRepository: conversationRepository,
      aiInputRepository: aiInputRepository,
      aiConfigRepository: aiConfigRepository,
      journalDb: journalDb,
      cloudInferenceRepository: cloudInferenceRepository,
      journalRepository: journalRepository,
      checklistRepository: checklistRepository,
      labelsRepository: labelsRepository,
      syncService: syncService,
      templateService: templateService,
    );

    final result = await withClock(
      Clock.fixed(now),
      () => workflow.execute(
        agentIdentity: identity,
        runKey: _runKey,
        triggerTokens: scenario.userInput.triggerTokens.isEmpty
            ? {taskId}
            : scenario.userInput.triggerTokens,
        threadId: _threadId,
      ),
    );

    return AgentRunOutput(
      success: result.success,
      error: result.error,
      usage: behavior.usage,
      toolCalls: behavior.toolCalls,
      report: _reportFrom(behavior.toolCalls),
      observations: _observationsFrom(behavior.toolCalls),
      mutatedEntryIds: result.mutatedEntries.keys.toSet(),
      turnCount: conversationRepository.sendMessageDelegateCallCount,
    );
  }

  /// The shared stubs the task workflow performs that are not covered by
  /// `stubFullExecutePath` (verbatim from the day-/task-agent test setUp).
  static void _applyDefaults({
    required MockAgentRepository agentRepository,
    required MockAgentSyncService syncService,
    required MockAiInputRepository aiInputRepository,
    required MockJournalDb journalDb,
    required MockAgentTemplateService templateService,
    required AgentTemplateEntity testTemplate,
    required AgentTemplateVersionEntity testTemplateVersion,
  }) {
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    stubAppendMilestone(syncService);
    stubReconciledAgentState(syncService, agentRepository);

    when(() => agentRepository.getEntity(any())).thenAnswer((_) async => null);
    when(() => agentRepository.getEntitiesByIds(any())).thenAnswer((
      invocation,
    ) async {
      final ids = invocation.positionalArguments.first as Iterable<String>;
      final result = <String, AgentDomainEntity>{};
      for (final id in ids) {
        final entity = await agentRepository.getEntity(id);
        if (entity != null) result[id] = entity;
      }
      return result;
    });
    when(
      () => agentRepository.getLinksToMultiple(any(), type: any(named: 'type')),
    ).thenAnswer((invocation) async {
      final ids = invocation.positionalArguments.first as List<String>;
      final type = invocation.namedArguments[const Symbol('type')] as String?;
      final result = <String, List<AgentLink>>{};
      for (final id in ids) {
        final links = await agentRepository.getLinksTo(id, type: type);
        if (links.isNotEmpty) result[id] = links;
      }
      return result;
    });
    when(
      () => agentRepository.getLatestReportsByAgentIds(any(), any()),
    ).thenAnswer((invocation) async {
      final ids = invocation.positionalArguments.first as List<String>;
      final scope = invocation.positionalArguments[1] as String;
      final result = <String, AgentReportEntity>{};
      for (final id in ids) {
        final report = await agentRepository.getLatestReport(id, scope);
        if (report != null) result[id] = report;
      }
      return result;
    });
    when(
      () => agentRepository.updateWakeRunTemplate(
        any(),
        any(),
        any(),
        resolvedModelId: any(named: 'resolvedModelId'),
        soulId: any(named: 'soulId'),
        soulVersionId: any(named: 'soulVersionId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => agentRepository.getLinksTo(any(), type: 'agent_task'),
    ).thenAnswer((_) async => <AgentLink>[]);
    when(
      () => agentRepository.getRecentDecisions(
        any(),
        taskId: any(named: 'taskId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <ChangeDecisionEntity>[]);
    when(
      () => agentRepository.getPendingChangeSets(
        any(),
        taskId: any(named: 'taskId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <ChangeSetEntity>[]);
    when(
      () => agentRepository.getProposalLedger(
        any(),
        taskId: any(named: 'taskId'),
        changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
        resolvedLimit: any(named: 'resolvedLimit'),
      ),
    ).thenAnswer((_) async => const ProposalLedger.empty());
    when(
      () => agentRepository.getAttentionClaimsForTarget(
        targetKind: any(named: 'targetKind'),
        targetId: any(named: 'targetId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const <AttentionRequestEntity>[]);
    when(
      () => aiInputRepository.buildLinkedFromContext(any()),
    ).thenAnswer((_) async => <AiLinkedTaskContext>[]);
    when(
      () => aiInputRepository.buildLinkedToContext(any()),
    ).thenAnswer((_) async => <AiLinkedTaskContext>[]);
    when(
      () => aiInputRepository.buildProjectContextJsonForTask(any()),
    ).thenAnswer((_) async => '{}');
    when(
      () => aiInputRepository.buildRelatedProjectTasksJson(
        taskId: any(named: 'taskId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => '{}');
    when(
      () => journalDb.getLinkedEntities(any()),
    ).thenAnswer((_) async => <JournalEntity>[]);

    when(
      () => templateService.getTemplateForAgent(_agentId),
    ).thenAnswer((_) async => testTemplate);
    when(
      () => templateService.getActiveVersion(testTemplate.id),
    ).thenAnswer((_) async => testTemplateVersion);
  }

  static List<ChatCompletionMessageToolCall> _toToolCalls(
    List<ToolCallRecord> records,
  ) {
    return [
      for (var i = 0; i < records.length; i++)
        ChatCompletionMessageToolCall(
          id: 'call-$i',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: records[i].name,
            arguments: jsonEncode(records[i].args),
          ),
        ),
    ];
  }

  static AgentReportRecord? _reportFrom(List<ToolCallRecord> calls) {
    for (final call in calls) {
      if (call.name != TaskAgentToolNames.updateReport) continue;
      return AgentReportRecord(
        oneLiner: (call.args['oneLiner'] as String?) ?? '',
        tldr: (call.args['tldr'] as String?) ?? '',
        content: (call.args['content'] as String?) ?? '',
      );
    }
    return null;
  }

  static List<String> _observationsFrom(List<ToolCallRecord> calls) {
    final observations = <String>[];
    for (final call in calls) {
      if (call.name != TaskAgentToolNames.recordObservations) continue;
      final raw = call.args['observations'];
      if (raw is! List) continue;
      for (final item in raw) {
        if (item is String) {
          observations.add(item);
        } else if (item is Map<String, dynamic> && item['text'] is String) {
          observations.add(item['text'] as String);
        }
      }
    }
    return observations;
  }
}
