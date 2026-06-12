// Real-workflow Level 1 bench for the planning agent (ADR 0029, Phase 1).
//
// Drives the REAL `DayAgentWorkflow.execute(...)` for a drafting wake, seeded
// from an `EvalScenario`, with the backend services mocked (as the existing
// day-agent workflow tests do) and the model response scripted via
// `ScriptedConversationRepository`. It then maps `(WakeResult, scripted tool
// calls, persisted entities)` into an `AgentRunOutput` that the SAME Level 1
// assertions grade. Durable output fields are read back through production
// persistence services/entities instead of replaying scripted tool intent.
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
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_config.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../features/agents/test_utils.dart';
import '../../mocks/mocks.dart'
    show
        MockAgentRepository,
        MockAgentSyncService,
        MockAgentTemplateService,
        MockAiConfigRepository,
        MockCloudInferenceRepository,
        MockDomainLogger,
        MockFts5Db,
        MockJournalDb,
        MockJournalRepository,
        MockWakeOrchestrator,
        stubAppendMilestone,
        stubReconciledAgentState;
import 'eval_models.dart';
import 'eval_profile_config.dart';
import 'eval_provenance.dart';
import 'eval_target.dart';
import 'observing_conversation_repository.dart';
import 'proposal_record_mapper.dart';
import 'scripted_agent_behavior.dart';
import 'scripted_conversation_repository.dart';
import 'tool_call_record_mapper.dart';

/// Runs the real planner workflow for a drafting wake.
abstract final class PlannerEvalBench {
  static const _agentId = 'eval-day-agent';
  static const _templateId = 'eval-template-day';
  static const _threadId = 'eval-thread';
  static const _runKey = 'eval-run';
  static const _baselineDirective = 'You are a helpful agent.';

  /// Backwards-compatible name for existing planner drafting tests.
  static Future<AgentRunOutput> runDraftingWake(
    EvalScenario scenario,
    EvalProfile profile,
    ScriptedAgentBehavior behavior, {
    EvalTargetRunContext context = EvalTargetRunContext.direct,
    void Function(String message)? onUserMessage,
  }) => runWake(
    scenario,
    profile,
    behavior,
    context: context,
    onUserMessage: onUserMessage,
  );

  /// Seeds the scenario, runs `DayAgentWorkflow.execute(...)`, and returns the
  /// mapped output for drafting, refine, or capture-submitted wakes.
  static Future<AgentRunOutput> runWake(
    EvalScenario scenario,
    EvalProfile profile,
    ScriptedAgentBehavior behavior, {
    EvalTargetRunContext context = EvalTargetRunContext.direct,
    void Function(String message)? onUserMessage,
    ConversationRepository? conversationRepositoryOverride,
    CloudInferenceRepository? cloudInferenceRepositoryOverride,
    EvalProfileConfig? profileConfigOverride,
    Map<String, bool>? providerEnvPresence,
  }) async {
    final resolvedDayId = resolvePlannerWakeDay(
      scenario.userInput.triggerTokens,
    ).dayId;
    final dayId = resolvedDayId ?? _captureDayIdFromScenario(scenario);
    if (dayId == null) {
      throw ArgumentError(
        'Scenario "${scenario.id}" has no resolvable day token or seeded '
        'capture dayId',
      );
    }
    final now = scenario.appState.now;
    final runKey = _runKeyFor(context);
    final threadId = _threadIdFor(context);

    final repository = MockAgentRepository();
    final aiConfigRepository = MockAiConfigRepository();
    final cloudInferenceRepository =
        cloudInferenceRepositoryOverride ?? MockCloudInferenceRepository();
    final syncService = MockAgentSyncService();
    final templateService = MockAgentTemplateService();
    final domainLogger = MockDomainLogger();
    final journalDb = MockJournalDb();
    final journalRepository = MockJournalRepository();
    final fts5Db = MockFts5Db();
    final orchestrator = MockWakeOrchestrator();
    final persistedEntities = <AgentDomainEntity>[];
    final entityStore = <String, AgentDomainEntity>{};
    final linkStore = <AgentLink>[];
    final profileConfig = profileConfigOverride ?? evalProfileConfig(profile);
    final agentDirectiveVariant = context.agentDirectiveVariant;
    String? wakeRunResolvedModelId;
    String? wakeRunTemplateId;
    String? wakeRunTemplateVersionId;
    final scriptedConversation = conversationRepositoryOverride == null
        ? (ScriptedConversationRepository()
            ..toolCalls = _toToolCalls(behavior.firstToolCalls)
            ..toolCallsByInvocation = [
              for (final turn in behavior.turns) _toToolCalls(turn.toolCalls),
            ]
            ..finalResponse = behavior.firstFinalResponse
            ..usage = behavior.firstUsage
            ..usageByInvocation = [
              for (final turn in behavior.turns) turn.usage,
            ])
        : null;
    final conversation =
        conversationRepositoryOverride ?? scriptedConversation!;

    var currentState = makeTestState(
      id: 'state-$_agentId',
      agentId: _agentId,
      updatedAt: now,
    );
    entityStore[currentState.id] = currentState;
    final journalEntitiesById = _journalEntitiesFromScenario(scenario);
    _seedCaptures(
      scenario: scenario,
      dayId: dayId,
      entityStore: entityStore,
      linkStore: linkStore,
    );
    _seedBaselinePlan(
      scenario: scenario,
      dayId: dayId,
      entityStore: entityStore,
    );

    _stubDomainLogger(domainLogger);
    _stubInferenceProfile(aiConfigRepository, profileConfig);

    when(
      () => repository.getAgentState(_agentId),
    ).thenAnswer((_) async => currentState);
    when(
      () =>
          repository.getMessagesByKind(_agentId, AgentMessageKind.observation),
    ).thenAnswer((_) async => const <AgentMessageEntity>[]);
    when(
      () => repository.getEntity(any()),
    ).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as String;
      return entityStore[id];
    });
    when(() => repository.getEntitiesByIds(any())).thenAnswer((invocation) {
      final ids = invocation.positionalArguments.first as Iterable<String>;
      return Future.value(<String, AgentDomainEntity>{
        for (final id in ids)
          if (entityStore[id] != null) id: entityStore[id]!,
      });
    });
    when(
      () => repository.getEntitiesByAgentId(_agentId, type: any(named: 'type')),
    ).thenAnswer((invocation) {
      final type = invocation.namedArguments[const Symbol('type')] as String?;
      return Future.value([
        for (final entity in entityStore.values)
          if (entity.agentId == _agentId && _matchesEntityType(entity, type))
            entity,
      ]);
    });
    when(
      () => repository.getLinksFrom(any(), type: any(named: 'type')),
    ).thenAnswer((invocation) async {
      final fromId = invocation.positionalArguments.single as String;
      final type = invocation.namedArguments[#type] as String?;
      return [
        for (final link in linkStore)
          if (link.fromId == fromId &&
              link.deletedAt == null &&
              _matchesLinkType(link, type))
            link,
      ];
    });
    when(
      () => repository.getAttentionPlanningInputsForWindow(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => const AttentionPlanningInputs.empty());
    when(
      () => repository.getCaptureEventMetaByAgentId(_agentId),
    ).thenAnswer((_) async {
      return [
        for (final capture in entityStore.values.whereType<CaptureEntity>())
          if (capture.deletedAt == null)
            (
              id: capture.id,
              createdAt: capture.createdAt,
              capturedAt: capture.capturedAt,
            ),
      ];
    });
    when(
      () => repository.updateWakeRunTemplate(
        any(),
        any(),
        any(),
        resolvedModelId: any(named: 'resolvedModelId'),
        soulId: any(named: 'soulId'),
        soulVersionId: any(named: 'soulVersionId'),
      ),
    ).thenAnswer((invocation) async {
      wakeRunTemplateId = invocation.positionalArguments[1] as String;
      wakeRunTemplateVersionId = invocation.positionalArguments[2] as String;
      wakeRunResolvedModelId =
          invocation.namedArguments[#resolvedModelId] as String?;
    });

    when(() => templateService.getTemplateForAgent(_agentId)).thenAnswer(
      (_) async => makeTestTemplate(
        id: _templateId,
        agentId: _templateId,
        kind: AgentTemplateKind.dayAgent,
        modelId: 'legacy-template-model-must-not-win',
        profileId: profileConfig.profileId,
      ),
    );
    when(() => templateService.getActiveVersion(_templateId)).thenAnswer(
      (_) async => makeTestTemplateVersion(
        id: _templateVersionIdForVariant(
          '$_templateId-v1',
          agentDirectiveVariant,
        ),
        agentId: _templateId,
        directives: _baselineDirective,
        generalDirective: agentDirectiveVariant.mergedGeneralDirective(
          _baselineDirective,
        ),
        reportDirective: agentDirectiveVariant.reportDirective,
        modelId: 'legacy-version-model-must-not-win',
        profileId: profileConfig.profileId,
      ),
    );

    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.single as AgentDomainEntity;
      persistedEntities.add(entity);
      entityStore[entity.id] = entity;
      if (entity is AgentStateEntity) currentState = entity;
    });
    when(() => syncService.upsertLink(any())).thenAnswer((invocation) async {
      final link = invocation.positionalArguments.single as AgentLink;
      linkStore
        ..removeWhere((existing) => existing.id == link.id)
        ..add(link);
    });
    stubAppendMilestone(syncService);
    stubReconciledAgentState(syncService, repository);

    when(
      () => journalDb.journalEntityMapForIds(any()),
    ).thenAnswer((invocation) async {
      final ids = invocation.positionalArguments.first as Iterable<String>;
      return <String, JournalEntity>{
        for (final id in ids)
          if (journalEntitiesById[id] != null) id: journalEntitiesById[id]!,
      };
    });
    when(() => journalDb.journalEntityById(any())).thenAnswer((invocation) {
      final id = invocation.positionalArguments.single as String;
      return Future.value(journalEntitiesById[id]);
    });
    when(
      () => journalDb.getOpenTasksForDayAgentCorpus(
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      final categoryIds =
          invocation.namedArguments[#categoryIds] as Set<String>;
      return _tasksForCorpus(
        journalEntitiesById.values,
        allowedCategoryIds: categoryIds,
      );
    });
    when(() => journalDb.getTasksDueOnOrBefore(any())).thenAnswer((
      invocation,
    ) async {
      final date = invocation.positionalArguments.single as DateTime;
      return [
        for (final entity in journalEntitiesById.values)
          if (entity is Task &&
              entity.data.due != null &&
              !entity.data.due!.isAfter(date))
            entity,
      ];
    });
    when(() => journalDb.getCategoryById(any())).thenAnswer((_) async => null);

    final captureService = DayAgentCaptureService(
      agentRepository: repository,
      syncService: syncService,
      journalDb: journalDb,
      journalRepository: journalRepository,
      fts5Db: fts5Db,
      orchestrator: orchestrator,
      domainLogger: domainLogger,
    );
    final planService = DayAgentPlanService(
      agentRepository: repository,
      syncService: syncService,
      journalDb: journalDb,
      domainLogger: domainLogger,
    );

    final workflow = DayAgentWorkflow(
      agentRepository: repository,
      conversationRepository: conversation,
      aiConfigRepository: aiConfigRepository,
      cloudInferenceRepository: cloudInferenceRepository,
      syncService: syncService,
      templateService: templateService,
      domainLogger: domainLogger,
      captureService: captureService,
      planService: planService,
      config: DayAgentConfig(
        capacityMinutes: scenario.appState.capacityMinutes,
      ),
    );

    final identity = makeTestIdentity(
      id: _agentId,
      agentId: _agentId,
      kind: AgentKinds.dayAgent,
      displayName: 'Eval Planner',
      allowedCategoryIds: scenario.appState.allowedCategoryIds,
      currentStateId: 'state-$_agentId',
      config: AgentConfig(
        profileId: profileConfig.profileId,
        maxTurnsPerWake: 5,
      ),
      createdAt: now,
      updatedAt: now,
    );
    entityStore[identity.id] = identity;

    final triggerTokens = <String>{...scenario.userInput.triggerTokens};
    if (resolvedDayId != null) triggerTokens.add(dayId);

    final result = await withClock(
      Clock.fixed(now),
      () => workflow.execute(
        agentIdentity: identity,
        runKey: runKey,
        triggerTokens: triggerTokens,
        threadId: threadId,
      ),
    );
    final observer = conversation is EvalConversationObserver
        ? conversation as EvalConversationObserver
        : null;
    final lastUserMessage = observer?.lastUserMessage;
    if (lastUserMessage != null) {
      onUserMessage?.call(lastUserMessage);
    }

    final executedToolCalls = scriptedConversation == null
        ? toolCallRecordsFromPersistedActions(persistedEntities)
        : behavior.toolCallsForTurns(scriptedConversation.sendMessageCount);
    final persistedPlan = await planService.draftPlanForDay(
      agentId: _agentId,
      dayId: dayId,
    );
    return AgentRunOutput(
      success: result.success,
      error: result.error,
      usage: _usageFromPersisted(persistedEntities),
      toolCalls: executedToolCalls,
      toolResults: _toolResultsFromPersisted(persistedEntities),
      plannedBlocks: _blocksFromPlan(persistedPlan),
      parsedCaptureItems: _parsedCaptureItemsFrom(entityStore),
      plannedCapacityMinutes: persistedPlan?.capacityMinutes,
      observations: _observationsFromPersisted(persistedEntities),
      proposals: proposalRecordsFromPersisted(persistedEntities),
      resolvedModel: _resolvedModelFrom(
        profileConfig: profileConfig,
        providerModelId: observer?.lastModel,
        provider: observer?.lastProvider,
        templateId: wakeRunTemplateId,
        templateVersionId: wakeRunTemplateVersionId,
        wakeRunResolvedModelId: wakeRunResolvedModelId,
        usageModelId: _usageModelIdFromPersisted(persistedEntities),
      ),
      providerDecision: profileConfig.toProviderDecisionRecord(
        envPresence:
            providerEnvPresence ??
            EvalProvenance.envPresence(Platform.environment),
      ),
      workflowRun: WorkflowRunRecord(runKey: runKey, threadId: threadId),
      runtimePrompt: observer == null
          ? null
          : EvalProvenance.runtimePrompt(
              systemMessage: observer.lastSystemMessage,
              userMessage: observer.lastUserMessage,
              tools: observer.lastTools,
            ),
      modelInvocations: observer?.modelInvocations ?? const [],
      providerRequests: observer?.providerRequests ?? const [],
      providerResponses: observer?.providerResponses ?? const [],
      mutatedEntryIds: result.mutatedEntries.keys.toSet(),
      turnCount: observer?.sendMessageCount ?? 0,
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

  static String _runKeyFor(EvalTargetRunContext context) =>
      context == EvalTargetRunContext.direct
      ? _runKey
      : '$_runKey:${context.cellId}';

  static String _threadIdFor(EvalTargetRunContext context) =>
      context == EvalTargetRunContext.direct
      ? _threadId
      : '$_threadId:${context.cellId}';

  static String _templateVersionIdForVariant(
    String defaultId,
    EvalAgentDirectiveVariant variant,
  ) {
    if (variant.isDefault) return defaultId;
    final digest = EvalProvenance.agentDirectiveVariantDigest(variant);
    final shortDigest = digest.substring(
      'sha256:'.length,
      'sha256:'.length + 12,
    );
    final safeName = variant.name.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    return '$defaultId-$safeName-$shortDigest';
  }

  static void _stubInferenceProfile(
    MockAiConfigRepository repo,
    EvalProfileConfig profileConfig,
  ) {
    when(() => repo.getConfigById(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as String;
      return profileConfig.configById(id);
    });
    when(() => repo.getConfigsByType(AiConfigType.model)).thenAnswer(
      (_) async => profileConfig.modelRows,
    );
  }

  static void _seedCaptures({
    required EvalScenario scenario,
    required String dayId,
    required Map<String, AgentDomainEntity> entityStore,
    required List<AgentLink> linkStore,
  }) {
    for (final capture in scenario.appState.captures) {
      final capturedAt = capture.capturedAt ?? scenario.appState.now;
      final createdAt = capture.createdAt ?? capturedAt;
      final entity =
          AgentDomainEntity.capture(
                id: capture.id,
                agentId: _agentId,
                transcript: capture.transcript,
                capturedAt: capturedAt,
                createdAt: createdAt,
                dayId: capture.dayId ?? dayId,
                audioRef: capture.audioRef,
                deletedAt: capture.deletedAt,
                vectorClock: null,
              )
              as CaptureEntity;
      entityStore[entity.id] = entity;

      for (var i = 0; i < capture.parsedItems.length; i++) {
        final item = capture.parsedItems[i];
        final parsed =
            AgentDomainEntity.parsedItem(
                  id: item.id,
                  agentId: _agentId,
                  captureId: capture.id,
                  kind:
                      parseEnumByName(ParsedItemKind.values, item.kind) ??
                      ParsedItemKind.newTask,
                  title: item.title,
                  categoryId: item.categoryId,
                  confidence:
                      parseEnumByName(
                        ParsedItemConfidence.values,
                        item.confidence,
                      ) ??
                      ParsedItemConfidence.high,
                  confidenceScore: item.confidenceScore,
                  lowConfidence: item.lowConfidence,
                  spokenPhrase: item.spokenPhrase,
                  matchedTaskId: item.matchedTaskId,
                  estimateMinutes: item.estimateMinutes,
                  timeAnchor: item.timeAnchor,
                  proposedUpdate: item.proposedUpdate,
                  createdAt:
                      item.createdAt ?? createdAt.add(Duration(seconds: i)),
                  deletedAt: item.deletedAt,
                  vectorClock: null,
                )
                as ParsedItemEntity;
        entityStore[parsed.id] = parsed;
        linkStore.add(
          AgentLink.captureToParsedItem(
            id: 'capture_to_parsed_item:${capture.id}:${parsed.id}',
            fromId: capture.id,
            toId: parsed.id,
            createdAt: parsed.createdAt,
            updatedAt: parsed.createdAt,
            vectorClock: null,
          ),
        );
        final matchedTaskId = parsed.matchedTaskId;
        if (matchedTaskId != null) {
          linkStore.add(
            AgentLink.parsedItemToTask(
              id: 'parsed_item_to_task:${parsed.id}:$matchedTaskId',
              fromId: parsed.id,
              toId: matchedTaskId,
              createdAt: parsed.createdAt,
              updatedAt: parsed.createdAt,
              vectorClock: null,
            ),
          );
        }
      }
    }
  }

  static void _seedBaselinePlan({
    required EvalScenario scenario,
    required String dayId,
    required Map<String, AgentDomainEntity> entityStore,
  }) {
    if (scenario.appState.existingBlocks.isEmpty) return;

    final taskById = {
      for (final task in scenario.appState.tasks) task.id: task,
    };
    final planDate = _dateFromDayId(dayId);
    final blocks =
        [
          for (final block in scenario.appState.existingBlocks)
            PlannedBlock(
              id: block.id,
              categoryId: block.categoryId,
              startTime: block.start,
              endTime: block.end,
              taskId: block.taskId,
              title:
                  block.title ??
                  (block.taskId == null
                      ? null
                      : taskById[block.taskId]?.title) ??
                  'Existing eval block',
              type: _enumByName(
                PlannedBlockType.values,
                block.type,
                PlannedBlockType.manual,
              ),
              state: _enumByName(
                PlannedBlockState.values,
                block.state,
                PlannedBlockState.drafted,
              ),
              reason: block.reason,
              note: block.note,
            ),
        ]..sort((a, b) {
          final byStart = a.startTime.compareTo(b.startTime);
          if (byStart != 0) return byStart;
          return a.id.compareTo(b.id);
        });
    final scheduledMinutes = blocks.fold<int>(
      0,
      (sum, block) => sum + block.duration.inMinutes,
    );
    final plan =
        AgentDomainEntity.dayPlan(
              id: dayAgentPlanEntityId(dayId),
              agentId: _agentId,
              dayId: dayId,
              planDate: planDate,
              data: DayPlanData(
                planDate: planDate,
                status: const DayPlanStatus.draft(),
                plannedBlocks: blocks,
              ),
              capacityMinutes: scenario.appState.capacityMinutes,
              scheduledMinutes: scheduledMinutes,
              createdAt: scenario.appState.now,
              updatedAt: scenario.appState.now,
              vectorClock: null,
            )
            as DayPlanEntity;
    entityStore[plan.id] = plan;
  }

  static List<Task> _tasksForCorpus(
    Iterable<JournalEntity> entities, {
    required Set<String> allowedCategoryIds,
  }) {
    return [
      for (final entity in entities)
        if (entity is Task &&
            !_isClosedTaskEntity(entity) &&
            _categoryAllowed(entity.meta.categoryId, allowedCategoryIds))
          entity,
    ];
  }

  static ResolvedModelRecord? _resolvedModelFrom({
    required EvalProfileConfig profileConfig,
    required String? providerModelId,
    required AiConfigInferenceProvider? provider,
    required String? templateId,
    required String? templateVersionId,
    required String? wakeRunResolvedModelId,
    required String? usageModelId,
  }) {
    if (providerModelId == null || provider == null) return null;
    return profileConfig.toResolvedModelRecord(
      providerModelId: providerModelId,
      providerId: provider.id,
      providerType: provider.inferenceProviderType,
      templateId: templateId,
      templateVersionId: templateVersionId,
      wakeRunResolvedModelId: wakeRunResolvedModelId,
      usageModelId: usageModelId,
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

  static InferenceUsage _usageFromPersisted(
    List<AgentDomainEntity> persistedEntities,
  ) {
    final usages = persistedEntities.whereType<WakeTokenUsageEntity>();
    var usage = InferenceUsage.empty;
    for (final entity in usages) {
      usage = usage.merge(
        InferenceUsage(
          inputTokens: entity.inputTokens,
          outputTokens: entity.outputTokens,
          thoughtsTokens: entity.thoughtsTokens,
          cachedInputTokens: entity.cachedInputTokens,
        ),
      );
    }
    return usage;
  }

  static String? _usageModelIdFromPersisted(
    List<AgentDomainEntity> persistedEntities,
  ) {
    final usages = persistedEntities.whereType<WakeTokenUsageEntity>().toList();
    if (usages.isEmpty) return null;
    return usages.last.modelId;
  }

  static List<ToolResultRecord> _toolResultsFromPersisted(
    List<AgentDomainEntity> persistedEntities,
  ) {
    return [
      for (final message in persistedEntities.whereType<AgentMessageEntity>())
        if (message.kind == AgentMessageKind.toolResult &&
            message.deletedAt == null)
          ToolResultRecord(
            name: message.metadata.toolName ?? 'unknown_tool',
            success: message.metadata.errorMessage == null,
            error: message.metadata.errorMessage,
          ),
    ];
  }

  static List<PlannedBlockRecord> _blocksFromPlan(DayPlanEntity? plan) {
    if (plan == null) return const <PlannedBlockRecord>[];
    return [
      for (final block in plan.data.plannedBlocks)
        PlannedBlockRecord(
          id: block.id,
          categoryId: block.categoryId,
          start: block.startTime,
          end: block.endTime,
          taskId: block.taskId,
        ),
    ];
  }

  static List<ParsedCaptureItemRecord> _parsedCaptureItemsFrom(
    Map<String, AgentDomainEntity> entityStore,
  ) {
    final items =
        [
          for (final entity in entityStore.values)
            if (entity is ParsedItemEntity && entity.deletedAt == null) entity,
        ]..sort((a, b) {
          final byCreatedAt = a.createdAt.compareTo(b.createdAt);
          if (byCreatedAt != 0) return byCreatedAt;
          return a.id.compareTo(b.id);
        });
    return [
      for (final item in items)
        ParsedCaptureItemRecord(
          id: item.id,
          captureId: item.captureId,
          kind: item.kind.name,
          title: item.title,
          categoryId: item.categoryId,
          confidence: item.confidence.name,
          confidenceScore: item.confidenceScore,
          lowConfidence: item.lowConfidence,
          spokenPhrase: item.spokenPhrase,
          matchedTaskId: item.matchedTaskId,
          estimateMinutes: item.estimateMinutes,
          timeAnchor: item.timeAnchor,
          proposedUpdate: item.proposedUpdate,
        ),
    ];
  }

  static bool _matchesEntityType(AgentDomainEntity entity, String? type) {
    if (type == null) return true;
    return entity.toJson()['runtimeType'] == type;
  }

  static bool _matchesLinkType(AgentLink link, String? type) {
    if (type == null) return true;
    return switch (link) {
      CaptureToParsedItemLink() => type == AgentLinkTypes.captureToParsedItem,
      ParsedItemToTaskLink() => type == AgentLinkTypes.parsedItemToTask,
      CaptureToPlanLink() => type == AgentLinkTypes.captureToPlan,
      _ => false,
    };
  }

  static Map<String, JournalEntity> _journalEntitiesFromScenario(
    EvalScenario scenario,
  ) {
    return <String, JournalEntity>{
      for (final task in scenario.appState.tasks)
        task.id: JournalEntity.task(
          meta: Metadata(
            id: task.id,
            createdAt: scenario.appState.now,
            updatedAt: scenario.appState.now,
            dateFrom: scenario.appState.now,
            dateTo: scenario.appState.now,
            categoryId: task.categoryId,
            labelIds: task.labelIds.isEmpty ? null : task.labelIds,
            utcOffset: 0,
          ),
          data: TaskData(
            status: _taskStatus(task.status, scenario.appState.now),
            dateFrom: scenario.appState.now,
            dateTo: scenario.appState.now,
            statusHistory: [_taskStatus(task.status, scenario.appState.now)],
            title: task.title,
            due: task.due,
            estimate: task.estimateMinutes == null
                ? null
                : Duration(minutes: task.estimateMinutes!),
            checklistIds: [
              for (final item in task.checklist) item.id,
            ],
            aiSuppressedLabelIds: task.aiSuppressedLabelIds.isEmpty
                ? null
                : task.aiSuppressedLabelIds,
          ),
        ),
    };
  }

  static DateTime _dateFromDayId(String dayId) {
    const prefix = 'dayplan-';
    if (!dayId.startsWith(prefix)) {
      throw ArgumentError('Invalid dayId "$dayId"');
    }
    return DateTime.parse(dayId.substring(prefix.length));
  }

  static String? _captureDayIdFromScenario(EvalScenario scenario) {
    final captureById = {
      for (final capture in scenario.appState.captures) capture.id: capture,
    };
    final dayIds = {
      for (final captureId in captureIdsFromTriggerTokens(
        scenario.userInput.triggerTokens,
      ))
        if (captureById[captureId] case final MockCapture capture)
          _dayIdForCaptureFixture(capture, scenario.appState.now),
    };
    if (dayIds.length == 1) return dayIds.single;
    return null;
  }

  static String _dayIdForCaptureFixture(MockCapture capture, DateTime now) {
    final explicit = capture.dayId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return dayAgentIdForDate(capture.capturedAt ?? now);
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String name,
    T fallback,
  ) {
    final normalized = name.trim().replaceAll('_', '').toLowerCase();
    for (final value in values) {
      if (value.name.toLowerCase() == normalized) return value;
    }
    return fallback;
  }

  static bool _isClosedTaskEntity(Task task) {
    final status = task.data.status.toDbString;
    return status == 'DONE' || status == 'REJECTED';
  }

  static bool _categoryAllowed(String? categoryId, Set<String> allowed) {
    if (allowed.isEmpty) return true;
    return categoryId != null && allowed.contains(categoryId);
  }

  static TaskStatus _taskStatus(String status, DateTime now) {
    final normalized = status.toUpperCase();
    return switch (normalized) {
      'DONE' => TaskStatus.done(
        id: 'status-done',
        createdAt: now,
        utcOffset: 0,
      ),
      'GROOMED' => TaskStatus.groomed(
        id: 'status-groomed',
        createdAt: now,
        utcOffset: 0,
      ),
      'IN PROGRESS' => TaskStatus.inProgress(
        id: 'status-in-progress',
        createdAt: now,
        utcOffset: 0,
      ),
      'BLOCKED' => TaskStatus.blocked(
        id: 'status-blocked',
        createdAt: now,
        utcOffset: 0,
        reason: 'eval fixture',
      ),
      'ON HOLD' => TaskStatus.onHold(
        id: 'status-on-hold',
        createdAt: now,
        utcOffset: 0,
        reason: 'eval fixture',
      ),
      'REJECTED' => TaskStatus.rejected(
        id: 'status-rejected',
        createdAt: now,
        utcOffset: 0,
      ),
      _ => TaskStatus.open(
        id: 'status-open',
        createdAt: now,
        utcOffset: 0,
      ),
    };
  }

  static List<String> _observationsFromPersisted(
    List<AgentDomainEntity> persistedEntities,
  ) {
    final payloadsById = <String, AgentMessagePayloadEntity>{
      for (final payload
          in persistedEntities.whereType<AgentMessagePayloadEntity>())
        payload.id: payload,
    };
    final observations = <String>[];
    for (final message in persistedEntities.whereType<AgentMessageEntity>()) {
      if (message.kind != AgentMessageKind.observation ||
          message.deletedAt != null) {
        continue;
      }
      final contentEntryId = message.contentEntryId;
      if (contentEntryId == null) continue;
      final text = payloadsById[contentEntryId]?.content['text'];
      if (text is String && text.trim().isNotEmpty) {
        observations.add(text);
      }
    }
    return observations;
  }
}
