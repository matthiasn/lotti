// Real-workflow Level 1 bench for the planning agent (ADR 0026, Phase 1).
//
// Drives the REAL `DayAgentWorkflow.execute(...)` for a drafting wake, seeded
// from an `EvalScenario`, with the backend services mocked (as the existing
// day-agent workflow tests do) and the model response scripted via
// `ScriptedConversationRepository`. It then maps `(WakeResult, scripted tool
// calls, persisted entities)` into an `AgentRunOutput` that the SAME Level 1
// assertions grade.
//
// This is the deterministic substrate Level 2 swaps for a live conversation: in
// scripted mode the drafted blocks are fixed by the caller, so the value here is
// (a) exercising the real workflow orchestration end-to-end — profile→provider
// resolution, conversation loop, real strategy tool dispatch, state
// reconciliation, persistence — and (b) the scenario→run→output mapping seam.
//
// Requires `registerAllFallbackValues()` in the test's `setUpAll` (mocktail
// `any()` needs the registered fallbacks).

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../features/agents/test_utils.dart';
import '../../mocks/mocks.dart';
import 'eval_models.dart';
import 'scripted_conversation_repository.dart';

/// The fixed "model output" a scripted run replays: the tool calls the agent
/// would have made, an optional final assistant message, and the token usage.
class ScriptedAgentBehavior {
  const ScriptedAgentBehavior({
    this.toolCalls = const <ToolCallRecord>[],
    this.finalResponse,
    this.usage = const InferenceUsage(inputTokens: 0, outputTokens: 0),
  });

  final List<ToolCallRecord> toolCalls;
  final String? finalResponse;
  final InferenceUsage usage;
}

/// Runs the real planner workflow for a drafting wake.
abstract final class PlannerEvalBench {
  static const _agentId = 'eval-day-agent';
  static const _templateId = 'eval-template-day';
  static const _threadId = 'eval-thread';
  static const _runKey = 'eval-run';
  static const _profileId = 'eval-profile-day';
  static const _modelProviderModelId = 'models/day';

  /// Seeds the scenario, runs `DayAgentWorkflow.execute(...)` for the drafting
  /// wake implied by [behavior], and returns the mapped output.
  static Future<AgentRunOutput> runDraftingWake(
    EvalScenario scenario,
    ScriptedAgentBehavior behavior,
  ) async {
    final dayId = resolvePlannerWakeDay(scenario.userInput.triggerTokens).dayId;
    if (dayId == null) {
      throw ArgumentError(
        'Scenario "${scenario.id}" has no resolvable day token '
        '(expected a drafting:<dayId> trigger token)',
      );
    }
    final now = scenario.appState.now;

    final repository = MockAgentRepository();
    final aiConfigRepository = MockAiConfigRepository();
    final cloudInferenceRepository = MockCloudInferenceRepository();
    final syncService = MockAgentSyncService();
    final templateService = MockAgentTemplateService();
    final domainLogger = MockDomainLogger();
    final planService = MockDayAgentPlanService();
    final conversation = ScriptedConversationRepository()
      ..toolCalls = _toToolCalls(behavior.toolCalls)
      ..finalResponse = behavior.finalResponse
      ..usage = behavior.usage;

    var currentState = makeTestState(
      id: 'state-$_agentId',
      agentId: _agentId,
      slots: AgentSlots(activeDayId: dayId),
      updatedAt: now,
    );

    _stubDomainLogger(domainLogger);
    _stubInferenceProfile(aiConfigRepository);

    when(
      () => repository.getAgentState(_agentId),
    ).thenAnswer((_) async => currentState);
    when(
      () =>
          repository.getMessagesByKind(_agentId, AgentMessageKind.observation),
    ).thenAnswer((_) async => const <AgentMessageEntity>[]);
    when(
      () => repository.getEntitiesByIds(any()),
    ).thenAnswer((_) async => const <String, AgentDomainEntity>{});
    when(
      () => repository.getEntitiesByAgentId(_agentId, type: any(named: 'type')),
    ).thenAnswer((_) async => const <AgentDomainEntity>[]);
    when(
      () => repository.getAttentionPlanningInputsForWindow(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => const AttentionPlanningInputs.empty());
    when(
      () => repository.updateWakeRunTemplate(
        any(),
        any(),
        any(),
        resolvedModelId: any(named: 'resolvedModelId'),
        soulId: any(named: 'soulId'),
        soulVersionId: any(named: 'soulVersionId'),
      ),
    ).thenAnswer((_) async {});

    when(() => templateService.getTemplateForAgent(_agentId)).thenAnswer(
      (_) async => makeTestTemplate(
        id: _templateId,
        agentId: _templateId,
        kind: AgentTemplateKind.dayAgent,
        modelId: _modelProviderModelId,
        profileId: _profileId,
      ),
    );
    when(() => templateService.getActiveVersion(_templateId)).thenAnswer(
      (_) async => makeTestTemplateVersion(
        id: '$_templateId-v1',
        agentId: _templateId,
        profileId: _profileId,
      ),
    );

    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.single as AgentDomainEntity;
      if (entity is AgentStateEntity) currentState = entity;
    });
    stubAppendMilestone(syncService);
    stubReconciledAgentState(syncService, repository);

    when(
      () => planService.draftPlanForDay(agentId: _agentId, dayId: dayId),
    ).thenAnswer((_) async => null);
    when(
      () => planService.hydrateDecidedTasks(
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
        explicitTaskIds: any(named: 'explicitTaskIds'),
        parsedItems: any(named: 'parsedItems'),
      ),
    ).thenAnswer((_) async => const <DecidedTaskRef>[]);
    when(
      () => planService.executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.draftDayPlan,
        args: any(named: 'args'),
      ),
    ).thenAnswer(
      (_) async => DayAgentDirectToolResult.success(
        <String, Object?>{'planId': 'day_agent_plan:$dayId'},
      ),
    );

    final workflow = DayAgentWorkflow(
      agentRepository: repository,
      conversationRepository: conversation,
      aiConfigRepository: aiConfigRepository,
      cloudInferenceRepository: cloudInferenceRepository,
      syncService: syncService,
      templateService: templateService,
      domainLogger: domainLogger,
      planService: planService,
    );

    final identity = makeTestIdentity(
      id: _agentId,
      agentId: _agentId,
      kind: AgentKinds.dayAgent,
      displayName: 'Eval Planner',
      currentStateId: 'state-$_agentId',
      config: const AgentConfig(profileId: _profileId, maxTurnsPerWake: 5),
      createdAt: now,
      updatedAt: now,
    );

    final triggerTokens = <String>{...scenario.userInput.triggerTokens, dayId};

    final result = await withClock(
      Clock.fixed(now),
      () => workflow.execute(
        agentIdentity: identity,
        runKey: _runKey,
        triggerTokens: triggerTokens,
        threadId: _threadId,
      ),
    );

    return AgentRunOutput(
      success: result.success,
      error: result.error,
      usage: behavior.usage,
      toolCalls: behavior.toolCalls,
      plannedBlocks: _blocksFrom(behavior.toolCalls),
      observations: _observationsFrom(behavior.toolCalls),
      mutatedEntryIds: result.mutatedEntries.keys.toSet(),
      turnCount: conversation.sendMessageCount,
    );
  }

  static void _stubDomainLogger(MockDomainLogger logger) {
    when(
      () => logger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    ).thenReturn(null);
    when(
      () => logger.error(
        any(),
        any(),
        message: any(named: 'message'),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
  }

  static void _stubInferenceProfile(MockAiConfigRepository repo) {
    when(() => repo.getConfigById(_profileId)).thenAnswer(
      (_) async => testInferenceProfile(
        id: _profileId,
        thinkingModelId: _modelProviderModelId,
      ),
    );
    when(() => repo.getConfigsByType(AiConfigType.model)).thenAnswer(
      (_) async => [
        testAiModel(
          id: 'model-day',
          providerModelId: _modelProviderModelId,
          inferenceProviderId: 'provider-day',
        ),
      ],
    );
    when(() => repo.getConfigById('provider-day')).thenAnswer(
      (_) async =>
          testInferenceProvider(id: 'provider-day', apiKey: 'eval-key'),
    );
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

  static List<PlannedBlockRecord> _blocksFrom(List<ToolCallRecord> calls) {
    final blocks = <PlannedBlockRecord>[];
    for (final call in calls) {
      if (call.name != DayAgentToolNames.draftDayPlan) continue;
      final raw = call.args['blocks'];
      if (raw is! List) continue;
      for (var i = 0; i < raw.length; i++) {
        final block = raw[i];
        if (block is! Map<String, dynamic>) continue;
        blocks.add(
          PlannedBlockRecord(
            id: (block['id'] as String?) ?? 'block-$i',
            categoryId: (block['categoryId'] as String?) ?? '',
            start: DateTime.parse(block['start'] as String),
            end: DateTime.parse(block['end'] as String),
            taskId: block['taskId'] as String?,
          ),
        );
      }
    }
    return blocks;
  }

  static List<String> _observationsFrom(List<ToolCallRecord> calls) {
    final observations = <String>[];
    for (final call in calls) {
      if (call.name != DayAgentToolNames.recordObservations) continue;
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
