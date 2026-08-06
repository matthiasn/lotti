import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_agent_identity.dart';
import 'package:lotti/classes/day_agent_trigger_tokens.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/prompt/day_agent_prompt_sections.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_audio_entry_context_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow_models.dart';
import 'package:lotti/features/tasks/repository/task_dependency_resolver.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../agents/test_utils.dart';
import '../prompt/day_agent_prompt_test_utils.dart';

export 'dart:convert';

export 'package:clock/clock.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:lotti/classes/day_agent_identity.dart';
export 'package:lotti/classes/day_agent_plan_models.dart';
export 'package:lotti/classes/day_agent_trigger_tokens.dart';
export 'package:lotti/classes/day_audio_context.dart';
export 'package:lotti/classes/day_directive_models.dart';
export 'package:lotti/classes/day_plan.dart';
export 'package:lotti/classes/journal_entities.dart';
export 'package:lotti/features/agents/database/agent_repository.dart';
export 'package:lotti/features/agents/model/agent_config.dart';
export 'package:lotti/features/agents/model/agent_constants.dart';
export 'package:lotti/features/agents/model/agent_domain_entity.dart';
export 'package:lotti/features/agents/model/agent_enums.dart';
export 'package:lotti/features/agents/model/attention_negotiation.dart';
export 'package:lotti/features/agents/service/wake_prompt_reconstructor.dart';
export 'package:lotti/features/agents/workflow/wake_result.dart';
export 'package:lotti/features/ai/conversation/conversation_manager.dart';
export 'package:lotti/features/ai/conversation/conversation_repository.dart';
export 'package:lotti/features/ai/model/ai_config.dart';
export 'package:lotti/features/ai/model/inference_usage.dart';
export 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
export 'package:lotti/features/ai/repository/inference_repository_interface.dart';
export 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
export 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
export 'package:lotti/features/daily_os_next/agents/domain/week_context.dart';
export 'package:lotti/features/daily_os_next/agents/prompt/day_agent_prompt_sections.dart';
export 'package:lotti/features/daily_os_next/agents/prompt/day_prompt_log_wraps.dart';
export 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
export 'package:lotti/features/daily_os_next/agents/service/day_audio_entry_context_service.dart';
export 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
export 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
export 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow_models.dart';
export 'package:lotti/features/tasks/repository/task_dependency_resolver.dart';
export 'package:lotti/get_it.dart';
export 'package:mocktail/mocktail.dart';
export 'package:openai_dart/openai_dart.dart';

export '../../../../helpers/fallbacks.dart';
export '../../../../mocks/mocks.dart';
export '../../../agents/test_utils.dart';
export '../prompt/day_agent_prompt_test_utils.dart';

/// Registers the shared lifecycle used by every focused day-agent workflow suite.
void configureDayAgentWorkflowTestSuite() {
  setUpAll(registerAllFallbackValues);
  setUp(() {
    repository = MockAgentRepository();
    aiConfigRepository = MockAiConfigRepository();
    cloudInferenceRepository = MockCloudInferenceRepository();
    syncService = MockAgentSyncService();
    templateService = MockAgentTemplateService();
    domainLogger = MockDomainLogger();
    conversationRepository = ConversationHarness();
    currentState = state();
    upsertedEntities = [];
    changedTokens = [];

    stubDomainLogger();
    stubInferenceProfile();

    when(
      () => repository.getAgentState(agentId),
    ).thenAnswer((_) async => currentState);
    when(
      () => repository.getMessagesByKind(
        agentId,
        AgentMessageKind.observation,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getEntitiesByIds(any()),
    ).thenAnswer((_) async => const <String, AgentDomainEntity>{});
    // The memory substrate loads submitted captures each wake (inline
    // events); default to none.
    when(
      () => repository.getEntitiesByAgentId(agentId, type: any(named: 'type')),
    ).thenAnswer((_) async => const <AgentDomainEntity>[]);
    // Capture events are now built from lightweight metadata; transcripts are
    // resolved lazily per id via getEntity. Default: no captures.
    when(
      () =>
          repository.getCaptureEventMetaForDay(agentId: agentId, dayId: dayId),
    ).thenAnswer((_) async => const []);
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
    when(
      () => templateService.getTemplateForAgent(agentId),
    ).thenAnswer((_) async => template());
    when(
      () => templateService.getActiveVersion(templateId),
    ).thenAnswer((_) async => version());
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.single as AgentDomainEntity;
      upsertedEntities.add(entity);
      if (entity is AgentStateEntity) {
        currentState = entity;
      }
    });
    stubAppendMilestone(syncService);
    stubReconciledAgentState(syncService, repository);
  });
}

const agentId = 'day-agent-001';
const threadId = 'thread-001';
const runKey = 'run-001';
const dayId = 'dayplan-2026-05-25';
const templateId = 'template-day';
const versionId = 'template-day-v1';
final now = DateTime(2026, 5, 25, 8);

late MockAgentRepository repository;
late MockAiConfigRepository aiConfigRepository;
late MockCloudInferenceRepository cloudInferenceRepository;
late MockAgentSyncService syncService;
late MockAgentTemplateService templateService;
late MockDomainLogger domainLogger;
late ConversationHarness conversationRepository;
late AgentStateEntity currentState;
late List<AgentDomainEntity> upsertedEntities;
late List<String> changedTokens;

AgentIdentityEntity identity() => makeTestIdentity(
  id: agentId,
  agentId: agentId,
  kind: AgentKinds.dayAgent,
  displayName: 'Shepherd',
  currentStateId: 'state-$agentId',
  config: const AgentConfig(profileId: 'profile-day', maxTurnsPerWake: 5),
  createdAt: now,
  updatedAt: now,
);

AgentStateEntity state({
  String activeDayId = dayId,
  int consecutiveFailureCount = 0,
  Map<String, int> toolCounterByKey = const {},
  DateTime? scheduledWakeAt,
}) {
  return makeTestState(
    id: 'state-$agentId',
    agentId: agentId,
    slots: AgentSlots(activeDayId: activeDayId),
    updatedAt: now,
    consecutiveFailureCount: consecutiveFailureCount,
    toolCounterByKey: toolCounterByKey,
    scheduledWakeAt: scheduledWakeAt,
  );
}

AgentTemplateEntity template() => makeTestTemplate(
  id: templateId,
  agentId: templateId,
  kind: AgentTemplateKind.dayAgent,
  modelId: 'models/day',
  profileId: 'profile-day',
);

AgentTemplateVersionEntity version({
  String generalDirective = 'General day-agent directive.',
  String reportDirective = 'Report day-agent directive.',
  String directives = 'Legacy day-agent directive.',
}) {
  return makeTestTemplateVersion(
    id: versionId,
    agentId: templateId,
    generalDirective: generalDirective,
    reportDirective: reportDirective,
    directives: directives,
    profileId: 'profile-day',
  );
}

void stubDomainLogger() {
  when(
    () => domainLogger.log(
      any(),
      any(),
      subDomain: any(named: 'subDomain'),
      level: any(named: 'level'),
    ),
  ).thenReturn(null);
  when(
    () => domainLogger.error(
      any(),
      any(),
      message: any(named: 'message'),
      stackTrace: any(named: 'stackTrace'),
      subDomain: any(named: 'subDomain'),
    ),
  ).thenReturn(null);
}

void stubInferenceProfile() {
  when(() => aiConfigRepository.getConfigById('profile-day')).thenAnswer(
    (_) async =>
        testInferenceProfile(id: 'profile-day', thinkingModelId: 'models/day'),
  );
  when(
    () => aiConfigRepository.getConfigsByType(AiConfigType.model),
  ).thenAnswer(
    (_) async => [
      testAiModel(
        id: 'model-day',
        providerModelId: 'models/day',
        inferenceProviderId: 'provider-day',
      ),
    ],
  );
  when(() => aiConfigRepository.getConfigById('provider-day')).thenAnswer(
    (_) async =>
        testInferenceProvider(id: 'provider-day', apiKey: 'provider-key'),
  );
}

DayAgentWorkflow workflow({
  MockSoulDocumentService? soulDocumentService,
  MockDayAgentCaptureService? captureService,
  MockDayAgentPlanService? planService,
  MockDayAgentKnowledgeService? knowledgeService,
  MockDayAgentWeekContextService? weekContextService,
  MockDayAgentDirectiveService? directiveService,
  TaskDependencyResolver? dependencyResolver,
  DayAudioEntryContextService? dayAudioEntryContextService,
  DayAgentOutputTokenBudgetPolicy outputTokenBudgets =
      const DayAgentOutputTokenBudgetPolicy(),
}) {
  return DayAgentWorkflow(
    agentRepository: repository,
    conversationRepository: conversationRepository,
    aiConfigRepository: aiConfigRepository,
    cloudInferenceRepository: cloudInferenceRepository,
    syncService: syncService,
    templateService: templateService,
    soulDocumentService: soulDocumentService,
    captureService: captureService,
    planService: planService,
    knowledgeService: knowledgeService,
    weekContextService: weekContextService,
    directiveService: directiveService,
    dependencyResolver: dependencyResolver,
    dayAudioEntryContextService: dayAudioEntryContextService,
    outputTokenBudgets: outputTokenBudgets,
    domainLogger: domainLogger,
    onPersistedStateChanged: changedTokens.add,
  );
}

/// Parses the last sent user message as a tagged-plaintext payload.
ParsedDayAgentPrompt sentPrompt() =>
    ParsedDayAgentPrompt(conversationRepository.lastUserMessage!);

Future<WakeResult> execute(DayAgentWorkflow sut, {Set<String>? triggerTokens}) {
  return withClock(
    Clock.fixed(now),
    () => sut.execute(
      agentIdentity: identity(),
      runKey: runKey,
      triggerTokens: triggerTokens ?? {dayAgentPlanningDayToken(dayId)},
      threadId: threadId,
    ),
  );
}

/// Stubs the reads a coordinator-identity wake performs (the shared
/// setUp keys everything by the per-day [agentId]).
void stubCoordinatorReads() {
  when(() => repository.getAgentState(dailyOsPlannerAgentId)).thenAnswer(
    (_) async => makeTestState(
      id: 'state-$dailyOsPlannerAgentId',
      agentId: dailyOsPlannerAgentId,
      slots: const AgentSlots(activeDayId: dayId),
      updatedAt: now,
    ),
  );
  when(
    () => repository.getMessagesByKind(
      dailyOsPlannerAgentId,
      AgentMessageKind.observation,
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => []);
  when(
    () => repository.getEntitiesByAgentId(
      dailyOsPlannerAgentId,
      type: any(named: 'type'),
    ),
  ).thenAnswer((_) async => const <AgentDomainEntity>[]);
  when(
    () => repository.getCaptureEventMetaForDay(
      agentId: dailyOsPlannerAgentId,
      dayId: dayId,
    ),
  ).thenAnswer((_) async => const []);
  when(
    () => templateService.getTemplateForAgent(dailyOsPlannerAgentId),
  ).thenAnswer((_) async => template());
}

Future<WakeResult> executeAsCoordinator(
  DayAgentWorkflow sut, {
  Set<String>? triggerTokens,
  DateTime? at,
}) {
  stubCoordinatorReads();
  return withClock(
    Clock.fixed(at ?? now),
    () => sut.execute(
      agentIdentity: makeTestIdentity(
        id: dailyOsPlannerAgentId,
        agentId: dailyOsPlannerAgentId,
        kind: AgentKinds.dayAgent,
        displayName: 'Shepherd',
        currentStateId: 'state-$dailyOsPlannerAgentId',
        config: const AgentConfig(profileId: 'profile-day', maxTurnsPerWake: 5),
        createdAt: now,
        updatedAt: now,
      ),
      runKey: runKey,
      triggerTokens: triggerTokens ?? {dayAgentPlanningDayToken(dayId)},
      threadId: threadId,
    ),
  );
}

/// Stubs the drafting-context lookups: the baseline plan (default none)
/// and the decided-tasks hydration (default empty).
void stubDraftingPlanContext(
  MockDayAgentPlanService planService, {
  DayPlanEntity? baselinePlan,
  List<DecidedTaskRef> decidedTasks = const [],
}) {
  when(
    () => planService.draftPlanForDay(agentId: agentId, dayId: dayId),
  ).thenAnswer((_) async => baselinePlan);
  when(
    () => planService.hydrateDecidedTasks(
      allowedCategoryIds: any(named: 'allowedCategoryIds'),
      explicitTaskIds: any(named: 'explicitTaskIds'),
      parsedItems: any(named: 'parsedItems'),
      dependencyResolver: any(named: 'dependencyResolver'),
    ),
  ).thenAnswer((_) async => decidedTasks);
}

void stubSuccessfulDraftToolCall(MockDayAgentPlanService planService) {
  when(
    () => planService.executeTool(
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      toolName: DayAgentToolNames.draftDayPlan,
      args: any(named: 'args'),
      planningConfig: any(named: 'planningConfig'),
      planningSnapshotAt: any(named: 'planningSnapshotAt'),
      planningBaselinePlan: any(named: 'planningBaselinePlan'),
    ),
  ).thenAnswer(
    (_) async => DayAgentDirectToolResult.success(const {
      'planId': 'day_agent_plan:dayplan-2026-05-25',
    }),
  );
  conversationRepository.toolCalls = [
    toolCall(
      id: 'draft-call',
      name: DayAgentToolNames.draftDayPlan,
      args: {'dayId': dayId, 'blocks': <Object?>[]},
    ),
  ];
}

PlannedBlock closedBaselineBlock({String? taskId}) => PlannedBlock(
  id: 'baseline-block',
  categoryId: 'work',
  startTime: DateTime(2026, 5, 25, 9),
  endTime: DateTime(2026, 5, 25, 10),
  taskId: taskId,
  title: taskId == null ? 'Existing focus block' : 'Represented task',
  reason: 'Existing plan.',
);

DayPlanEntity closedBaselinePlan(PlannedBlock block) => makeTestDayPlan(
  agentId: agentId,
  planDate: DateTime(2026, 5, 25),
  data: DayPlanData(
    planDate: DateTime(2026, 5, 25),
    status: const DayPlanStatus.draft(),
    plannedBlocks: [block],
  ),
  scheduledMinutes: 60,
);

Map<String, Object?> closedBaselineBlockArgs(PlannedBlock block) => {
  'id': block.id,
  'categoryId': block.categoryId,
  'start': block.startTime.toIso8601String(),
  'end': block.endTime.toIso8601String(),
  'taskId': block.taskId,
  'title': block.title,
  'type': block.type.name,
  'state': block.state.name,
  'reason': block.reason,
  'note': block.note,
};

void stubCaptureContext(
  MockDayAgentCaptureService captureService, {
  String captureId = 'capture-1',
}) {
  when(() => captureService.getCapture(captureId)).thenAnswer(
    (_) async => makeTestCapture(
      id: captureId,
      agentId: agentId,
      transcript: 'Prep demo and buy milk',
      capturedAt: DateTime(2026, 5, 25, 7, 45),
      createdAt: DateTime(2026, 5, 25, 7, 45),
    ),
  );
  when(
    () => captureService.buildTaskCorpusSnapshot(
      allowedCategoryIds: any(named: 'allowedCategoryIds'),
      day: any(named: 'day'),
      dependencyResolver: any(named: 'dependencyResolver'),
    ),
  ).thenAnswer((_) async => const []);
}

void stubEntitiesByIds(Map<String, AgentDomainEntity> entitiesById) {
  when(() => repository.getEntitiesByIds(any<Iterable<String>>())).thenAnswer((
    invocation,
  ) async {
    final ids = invocation.positionalArguments.single as Iterable<String>;
    return <String, AgentDomainEntity>{
      for (final id in ids)
        if (entitiesById[id] case final AgentDomainEntity entity) id: entity,
    };
  });
}

/// Pins the cache invariant the prompt-section vocabulary declares: the
/// payload's sections must appear exactly in the canonical stable→volatile
/// order of [DayAgentPromptTags.all]. Any reordering that would hurt the
/// prefix cache (e.g. a volatile section drifting ahead of `day_log`) fails
/// here by name.
void expectCanonicalSectionOrder(ParsedDayAgentPrompt sent) {
  expect(sent.tagsInOrder, DayAgentPromptTags.all.where(sent.has).toList());
}

ChatCompletionMessageToolCall toolCall({
  required String name,
  required Map<String, dynamic> args,
  String id = 'call-1',
}) {
  return ChatCompletionMessageToolCall(
    id: id,
    type: ChatCompletionMessageToolCallType.function,
    function: ChatCompletionMessageFunctionCall(
      name: name,
      arguments: jsonEncode(args),
    ),
  );
}

class ToolValidationScenario {
  const ToolValidationScenario({
    required this.name,
    required this.args,
    required this.expectedResponse,
  });

  final String name;
  final Map<String, dynamic> args;
  final String expectedResponse;
}

class ConversationHarness extends ConversationRepository {
  final Map<String, ConversationManager> _managers =
      <String, ConversationManager>{};
  int createdConversationCount = 0;
  int deletedConversationCount = 0;

  List<ChatCompletionMessageToolCall> toolCalls = const [];
  String? finalResponse;
  InferenceUsage? usage;
  Exception? errorToThrow;
  String? lastSystemMessage;
  String? lastUserMessage;
  List<ChatCompletionTool> lastTools = const [];
  final sendMessageCalls =
      <
        ({
          InferenceRepositoryInterface inferenceRepo,
          String message,
          String model,
          ChatCompletionToolChoiceOption? toolChoice,
          List<ChatCompletionTool> tools,
          String? consumptionAgentId,
          String? consumptionWakeRunKey,
          String? consumptionThreadId,
        })
      >[];
  List<List<ChatCompletionMessageToolCall>> toolCallsByInvocation = const [];
  List<InferenceUsage?> usageByInvocation = const [];
  final toolResponses = <String>[];

  @override
  String createConversation({String? systemMessage, int maxTurns = 20}) {
    createdConversationCount++;
    lastSystemMessage = systemMessage;
    final id = 'conversation-$createdConversationCount';
    _managers[id] = ConversationManager(maxTurns: maxTurns)
      ..initialize(systemMessage: systemMessage);
    return id;
  }

  @override
  ConversationManager? getConversation(String conversationId) {
    return _managers[conversationId];
  }

  @override
  Future<InferenceUsage?> sendMessage({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    double temperature = 0.7,
    ConversationStrategy? strategy,
    String? consumptionAgentId,
    String? consumptionTaskId,
    String? consumptionCategoryId,
    String? consumptionWakeRunKey,
    String? consumptionThreadId,
    bool rethrowInferenceErrors = false,
  }) async {
    final thrown = errorToThrow;
    if (thrown != null) throw thrown;

    lastUserMessage = message;
    lastTools = tools ?? const [];
    sendMessageCalls.add((
      inferenceRepo: inferenceRepo,
      message: message,
      model: model,
      toolChoice: toolChoice,
      tools: tools ?? const <ChatCompletionTool>[],
      consumptionAgentId: consumptionAgentId,
      consumptionWakeRunKey: consumptionWakeRunKey,
      consumptionThreadId: consumptionThreadId,
    ));
    final invocationIndex = sendMessageCalls.length - 1;
    final manager = _managers[conversationId]!..addUserMessage(message);
    final selectedToolCalls = invocationIndex < toolCallsByInvocation.length
        ? toolCallsByInvocation[invocationIndex]
        : toolCalls;
    if (selectedToolCalls.isNotEmpty) {
      manager.addAssistantMessage(toolCalls: selectedToolCalls);
      await strategy!.processToolCalls(
        toolCalls: selectedToolCalls,
        manager: manager,
      );
      toolResponses
        ..clear()
        ..addAll(
          manager.messages
              .where(
                (message) => message.role == ChatCompletionMessageRole.tool,
              )
              .map((message) => message.content)
              .whereType<String>(),
        );
    }
    if (finalResponse != null) {
      manager.addAssistantMessage(content: finalResponse);
    }
    if (invocationIndex < usageByInvocation.length) {
      return usageByInvocation[invocationIndex];
    }
    return usage;
  }

  @override
  void deleteConversation(String conversationId) {
    deletedConversationCount++;
    _managers.remove(conversationId);
  }
}
