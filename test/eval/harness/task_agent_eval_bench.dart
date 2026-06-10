// Real-workflow Level 1 bench for the task agent (ADR 0029, Phase 1).
//
// Mirrors PlannerEvalBench but for `TaskAgentWorkflow.execute(...)`. It seeds an
// `EvalScenario` (one active task) onto the centralized mocks + the existing
// task-agent test helpers, scripts the model response through the proven
// `MockConversationRepository.sendMessageDelegate` -> `strategy.processToolCalls`
// path (mock ConversationManager), runs the real workflow under `withClock`, and
// maps the result to an `AgentRunOutput` the SAME Level 1 suite grades.
//
// Durable output fields are read from the entities the workflow persisted, not
// from replayed scripted intent: reports from `AgentReportEntity`, observations
// from `AgentMessageEntity` + payload, token usage from `WakeTokenUsageEntity`,
// and confirmable proposals from `ChangeSetEntity.items`.
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
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../features/agents/test_utils.dart';
import '../../features/agents/workflow/task_agent_workflow_test_helpers.dart';
import '../../mocks/mocks.dart' hide MockTask;
import 'eval_models.dart';
import 'eval_profile_config.dart';
import 'eval_provenance.dart';
import 'eval_target.dart';
import 'observing_conversation_repository.dart';
import 'proposal_record_mapper.dart';
import 'scripted_agent_behavior.dart';
import 'tool_call_record_mapper.dart';

/// Runs the real task-agent workflow for a single-task wake.
abstract final class TaskAgentEvalBench {
  static const _agentId = 'eval-task-agent';
  static const _runKey = 'eval-run';
  static const _threadId = 'eval-thread';
  static const _decidedTaskPrefix = 'decided_task:';

  /// Seeds the scenario's active task, runs `TaskAgentWorkflow.execute(...)`
  /// replaying [behavior], and returns the mapped output.
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
    if (scenario.appState.tasks.isEmpty) {
      throw ArgumentError(
        'Task-agent scenario "${scenario.id}" needs at least one task',
      );
    }
    final taskId = _activeTaskIdFromScenario(scenario);
    final activeTask = _taskFixtureFor(scenario, taskId);
    final now = scenario.appState.now;
    final runKey = _runKeyFor(context);
    final threadId = _threadIdFor(context);

    final agentRepository = MockAgentRepository();
    final syncService = MockAgentSyncService();
    final conversationManager = MockConversationManager();
    final scriptedConversationRepository =
        conversationRepositoryOverride == null
        ? MockConversationRepository(conversationManager)
        : null;
    final conversationRepository =
        conversationRepositoryOverride ?? scriptedConversationRepository!;
    final aiInputRepository = MockAiInputRepository();
    final aiConfigRepository = MockAiConfigRepository();
    final journalDb = MockJournalDb();
    final cloudInferenceRepository =
        cloudInferenceRepositoryOverride ?? MockCloudInferenceRepository();
    final journalRepository = MockJournalRepository();
    final checklistRepository = MockChecklistRepository();
    final labelsRepository = MockLabelsRepository();
    final templateService = MockAgentTemplateService();
    final persistedEntities = <AgentDomainEntity>[];
    final entityStore = <String, AgentDomainEntity>{};
    final profileConfig = profileConfigOverride ?? evalProfileConfig(profile);
    final journalState = _seededJournalState(
      scenario.appState.tasks,
      now,
    );
    String? sentProviderModelId;
    AiConfigInferenceProvider? sentProvider;
    String? wakeRunResolvedModelId;
    String? wakeRunTemplateId;
    String? wakeRunTemplateVersionId;

    final testAgentState = makeTestState(
      id: 'state-$_agentId',
      agentId: _agentId,
      slots: AgentSlots(activeTaskId: taskId),
      updatedAt: now,
    );
    final testTemplate = makeTestTemplate(
      modelId: 'legacy-template-model-must-not-win',
      profileId: profileConfig.profileId,
    );
    final testTemplateVersion = makeTestTemplateVersion(
      directives: 'You are a diligent task agent.',
      modelId: 'legacy-version-model-must-not-win',
      profileId: profileConfig.profileId,
    );
    for (final changeSet in _seededProposalSets(scenario, taskId)) {
      entityStore[changeSet.id] = changeSet;
    }
    for (final decision in _seededProposalDecisions(scenario, taskId)) {
      entityStore[decision.id] = decision;
    }

    final identity =
        AgentDomainEntity.agent(
              id: _agentId,
              agentId: _agentId,
              kind: 'task_agent',
              displayName: 'Eval Task Agent',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: scenario.appState.allowedCategoryIds,
              currentStateId: 'state-$_agentId',
              config: AgentConfig(profileId: profileConfig.profileId),
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
      checklistRepository: checklistRepository,
      templateService: templateService,
      testTemplate: testTemplate,
      testTemplateVersion: testTemplateVersion,
      persistedEntities: persistedEntities,
      entityStore: entityStore,
      journalEntities: journalState.entities,
      checklistItemsByTaskId: journalState.checklistItemsByTaskId,
      categories: _categoryDefinitionsFromScenario(scenario),
      labels: _labelDefinitionsFromScenario(scenario),
      targetTaskId: taskId,
    );
    stubFullExecutePath(
      mockAgentRepository: agentRepository,
      mockAiInputRepository: aiInputRepository,
      mockAiConfigRepository: aiConfigRepository,
      mockConversationManager: conversationManager,
      testAgentState: testAgentState,
      geminiModel: profileConfig.model,
      geminiProvider: profileConfig.provider,
      agentId: _agentId,
      taskId: taskId,
    );
    _stubInferenceProfile(aiConfigRepository, profileConfig);
    when(
      () => agentRepository.updateWakeRunTemplate(
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
    when(
      () => aiInputRepository.buildTaskDetailsJson(id: taskId),
    ).thenAnswer(
      (_) async => jsonEncode(activeTask.toJson()),
    );

    if (scriptedConversationRepository != null) {
      scriptedConversationRepository
        ..maxDelegateCalls = behavior.isMultiTurn ? behavior.turns.length : 1
        ..sendMessageDelegate =
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
              onUserMessage?.call(message);
              sentProviderModelId = model;
              sentProvider = provider;
              final turnIndex =
                  scriptedConversationRepository.sendMessageDelegateCallCount -
                  1;
              final toolCalls = behavior.isMultiTurn
                  ? behavior.turns[turnIndex].toolCalls
                  : behavior.toolCalls;
              if (strategy is TaskAgentStrategy) {
                await strategy.processToolCalls(
                  toolCalls: _toToolCalls(toolCalls),
                  manager: conversationManager,
                );
              }
              return behavior.isMultiTurn
                  ? behavior.turns[turnIndex].usage
                  : behavior.usage;
            };
    }

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
        runKey: runKey,
        triggerTokens: scenario.userInput.triggerTokens.isEmpty
            ? {taskId}
            : scenario.userInput.triggerTokens,
        threadId: threadId,
      ),
    );

    final observer = conversationRepository is EvalConversationObserver
        ? conversationRepository as EvalConversationObserver
        : null;
    final lastUserMessage = observer?.lastUserMessage;
    if (lastUserMessage != null) {
      onUserMessage?.call(lastUserMessage);
    }

    final executedToolCalls = scriptedConversationRepository == null
        ? toolCallRecordsFromPersistedActions(persistedEntities)
        : behavior.toolCallsForTurns(
            scriptedConversationRepository.sendMessageDelegateCallCount,
          );
    return AgentRunOutput(
      success: result.success,
      error: result.error,
      usage: _usageFromPersisted(persistedEntities),
      toolCalls: executedToolCalls,
      toolResults: _toolResultsFromPersisted(persistedEntities),
      report: _reportFromPersisted(persistedEntities),
      observations: _observationsFromPersisted(persistedEntities),
      proposals: proposalRecordsFromPersisted(entityStore.values),
      resolvedModel: _resolvedModelFrom(
        profileConfig: profileConfig,
        providerModelId: observer?.lastModel ?? sentProviderModelId,
        provider: observer?.lastProvider ?? sentProvider,
        templateId: wakeRunTemplateId ?? testTemplate.id,
        templateVersionId: wakeRunTemplateVersionId ?? testTemplateVersion.id,
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
      mutatedEntryIds: result.mutatedEntries.keys.toSet(),
      turnCount:
          observer?.sendMessageCount ??
          scriptedConversationRepository?.sendMessageDelegateCallCount ??
          0,
    );
  }

  static String _activeTaskIdFromScenario(EvalScenario scenario) {
    final knownTaskIds = scenario.appState.knownTaskIds;
    final triggeredTaskIds = <String>{};
    for (final token in scenario.userInput.triggerTokens) {
      if (!token.startsWith(_decidedTaskPrefix)) continue;
      final taskId = token.substring(_decidedTaskPrefix.length);
      if (!knownTaskIds.contains(taskId)) {
        throw ArgumentError(
          'Task-agent scenario "${scenario.id}" references unknown '
          'decided task "$taskId"',
        );
      }
      triggeredTaskIds.add(taskId);
    }
    if (triggeredTaskIds.length > 1) {
      throw ArgumentError(
        'Task-agent scenario "${scenario.id}" references multiple decided '
        'tasks: ${triggeredTaskIds.join(', ')}',
      );
    }
    if (triggeredTaskIds.length == 1) return triggeredTaskIds.single;
    return scenario.appState.tasks.first.id;
  }

  static MockTask _taskFixtureFor(EvalScenario scenario, String taskId) {
    return scenario.appState.tasks.firstWhere(
      (task) => task.id == taskId,
      orElse: () => throw ArgumentError(
        'Task-agent scenario "${scenario.id}" has no task "$taskId"',
      ),
    );
  }

  static String _runKeyFor(EvalTargetRunContext context) =>
      context == EvalTargetRunContext.direct
      ? _runKey
      : '$_runKey:${context.cellId}';

  static String _threadIdFor(EvalTargetRunContext context) =>
      context == EvalTargetRunContext.direct
      ? _threadId
      : '$_threadId:${context.cellId}';

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

  static ResolvedModelRecord? _resolvedModelFrom({
    required EvalProfileConfig profileConfig,
    required String? providerModelId,
    required AiConfigInferenceProvider? provider,
    required String templateId,
    required String templateVersionId,
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

  /// The shared stubs the task workflow performs that are not covered by
  /// `stubFullExecutePath` (verbatim from the day-/task-agent test setUp).
  static void _applyDefaults({
    required MockAgentRepository agentRepository,
    required MockAgentSyncService syncService,
    required MockAiInputRepository aiInputRepository,
    required MockJournalDb journalDb,
    required MockChecklistRepository checklistRepository,
    required MockAgentTemplateService templateService,
    required AgentTemplateEntity testTemplate,
    required AgentTemplateVersionEntity testTemplateVersion,
    required List<AgentDomainEntity> persistedEntities,
    required Map<String, AgentDomainEntity> entityStore,
    required Map<String, JournalEntity> journalEntities,
    required Map<String, List<ChecklistItem>> checklistItemsByTaskId,
    required List<CategoryDefinition> categories,
    required List<LabelDefinition> labels,
    required String targetTaskId,
  }) {
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.single as AgentDomainEntity;
      entityStore[entity.id] = entity;
      persistedEntities.add(entity);
    });
    when(() => syncService.repository).thenReturn(agentRepository);
    stubAppendMilestone(syncService);
    stubReconciledAgentState(syncService, agentRepository);

    when(() => agentRepository.getEntity(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as String;
      return entityStore[id];
    });
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
    ).thenAnswer((invocation) async {
      final agentId = invocation.positionalArguments.first as String;
      final taskId =
          invocation.namedArguments[const Symbol('taskId')] as String? ??
          targetTaskId;
      final limit = invocation.namedArguments[const Symbol('limit')] as int?;
      return _recentDecisions(
        entityStore.values,
        agentId: agentId,
        taskId: taskId,
        limit: limit,
      );
    });
    when(
      () => agentRepository.getPendingChangeSets(
        any(),
        taskId: any(named: 'taskId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      final agentId = invocation.positionalArguments.first as String;
      final taskId =
          invocation.namedArguments[const Symbol('taskId')] as String? ??
          targetTaskId;
      return _pendingChangeSets(
        entityStore.values,
        agentId: agentId,
        taskId: taskId,
      );
    });
    when(
      () => agentRepository.getProposalLedger(
        any(),
        taskId: any(named: 'taskId'),
        changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
        resolvedLimit: any(named: 'resolvedLimit'),
      ),
    ).thenAnswer((invocation) async {
      final agentId = invocation.positionalArguments.first as String;
      final taskId =
          invocation.namedArguments[const Symbol('taskId')] as String? ??
          targetTaskId;
      final resolvedLimit =
          invocation.namedArguments[const Symbol('resolvedLimit')] as int?;
      return _proposalLedger(
        entityStore.values,
        agentId: agentId,
        taskId: taskId,
        resolvedLimit: resolvedLimit,
      );
    });
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
    when(() => journalDb.journalEntityById(any())).thenAnswer((invocation) {
      final id = invocation.positionalArguments.single as String;
      return Future.value(journalEntities[id]);
    });
    when(() => journalDb.getAllLabelDefinitions()).thenAnswer(
      (_) async => labels,
    );
    when(() => journalDb.getLabelDefinitionById(any())).thenAnswer((
      invocation,
    ) async {
      final id = invocation.positionalArguments.single as String;
      for (final label in labels) {
        if (label.id == id) return label;
      }
      return null;
    });
    when(() => journalDb.getCategoryById(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as String;
      for (final category in categories) {
        if (category.id == id) return category;
      }
      return null;
    });
    for (final task in journalEntities.values.whereType<Task>()) {
      when(
        () => checklistRepository.getChecklistItemsForTask(task: task),
      ).thenAnswer(
        (_) async => checklistItemsByTaskId[task.meta.id] ?? const [],
      );
    }

    when(
      () => templateService.getTemplateForAgent(_agentId),
    ).thenAnswer((_) async => testTemplate);
    when(
      () => templateService.getActiveVersion(testTemplate.id),
    ).thenAnswer((_) async => testTemplateVersion);
  }

  static ({
    Map<String, JournalEntity> entities,
    Map<String, List<ChecklistItem>> checklistItemsByTaskId,
  })
  _seededJournalState(List<MockTask> tasks, DateTime now) {
    final entities = <String, JournalEntity>{};
    final checklistItemsByTaskId = <String, List<ChecklistItem>>{};
    for (final task in tasks) {
      final taskEntity = _taskEntityFromMock(task, now);
      entities[taskEntity.meta.id] = taskEntity;
      final items = [
        for (final item in task.checklist)
          _checklistItemEntityFromMock(
            item,
            taskId: task.id,
            now: now,
          ),
      ];
      for (final item in items) {
        entities[item.meta.id] = item;
      }
      checklistItemsByTaskId[task.id] = items;
    }
    return (entities: entities, checklistItemsByTaskId: checklistItemsByTaskId);
  }

  static List<CategoryDefinition> _categoryDefinitionsFromScenario(
    EvalScenario scenario,
  ) {
    final now = scenario.appState.now;
    return [
      for (final category in scenario.appState.categories)
        CategoryDefinition(
          id: category.id,
          createdAt: now,
          updatedAt: now,
          name: category.name,
          vectorClock: null,
          private: category.private,
          active: category.active,
          color: category.color,
          deletedAt: category.deletedAt,
          isAvailableForDayPlan: category.isAvailableForDayPlan,
          correctionExamples: [
            for (final example in category.correctionExamples)
              ChecklistCorrectionExample(
                before: example.before,
                after: example.after,
                capturedAt: example.capturedAt,
              ),
          ],
        ),
    ];
  }

  static List<LabelDefinition> _labelDefinitionsFromScenario(
    EvalScenario scenario,
  ) {
    final now = scenario.appState.now;
    return [
      for (final label in scenario.appState.labels)
        LabelDefinition(
          id: label.id,
          createdAt: now,
          updatedAt: now,
          name: label.name,
          color: label.color,
          vectorClock: null,
          applicableCategoryIds: label.applicableCategoryIds,
          deletedAt: label.deletedAt,
        ),
    ];
  }

  static Task _taskEntityFromMock(MockTask task, DateTime now) {
    final status = _taskStatusFromMock(task.status, now);
    final checklistIds = task.checklist.isEmpty
        ? null
        : <String>['checklist-${task.id}'];
    return JournalEntity.task(
          meta: Metadata(
            id: task.id,
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
            categoryId: task.categoryId,
            labelIds: task.labelIds.isEmpty ? null : task.labelIds,
          ),
          data: TaskData(
            status: status,
            dateFrom: now,
            dateTo: now,
            statusHistory: [status],
            title: task.title,
            due: task.due,
            estimate: task.estimateMinutes == null
                ? null
                : Duration(minutes: task.estimateMinutes!),
            checklistIds: checklistIds,
            aiSuppressedLabelIds: task.aiSuppressedLabelIds.isEmpty
                ? null
                : task.aiSuppressedLabelIds,
          ),
        )
        as Task;
  }

  static ChecklistItem _checklistItemEntityFromMock(
    MockChecklistItem item, {
    required String taskId,
    required DateTime now,
  }) {
    return JournalEntity.checklistItem(
          meta: Metadata(
            id: item.id,
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: ChecklistItemData(
            title: item.title,
            isChecked: item.isChecked,
            linkedChecklists: ['checklist-$taskId'],
          ),
        )
        as ChecklistItem;
  }

  static TaskStatus _taskStatusFromMock(String status, DateTime now) {
    final id = 'status-${status.toLowerCase().replaceAll(' ', '-')}';
    return switch (status) {
      'DONE' => TaskStatus.done(
        id: id,
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      'GROOMED' => TaskStatus.groomed(
        id: id,
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      'IN PROGRESS' => TaskStatus.inProgress(
        id: id,
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      'BLOCKED' => TaskStatus.blocked(
        id: id,
        createdAt: now,
        reason: 'blocked in eval scenario',
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      'ON HOLD' => TaskStatus.onHold(
        id: id,
        createdAt: now,
        reason: 'on hold in eval scenario',
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      'REJECTED' => TaskStatus.rejected(
        id: id,
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      _ => TaskStatus.open(
        id: id,
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
    };
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

  static AgentReportRecord? _reportFromPersisted(
    List<AgentDomainEntity> persistedEntities,
  ) {
    final reports = persistedEntities
        .whereType<AgentReportEntity>()
        .where((report) => report.deletedAt == null)
        .toList();
    if (reports.isEmpty) return null;
    final report = reports.last;
    return AgentReportRecord(
      oneLiner: report.oneLiner ?? '',
      tldr: report.tldr ?? '',
      content: report.content,
    );
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

  static List<ChangeSetEntity> _seededProposalSets(
    EvalScenario scenario,
    String defaultTaskId,
  ) {
    return [
      for (var i = 0; i < scenario.appState.proposalSets.length; i++)
        _proposalSetFromMock(
          scenario.appState.proposalSets[i],
          defaultTaskId: defaultTaskId,
          defaultCreatedAt: scenario.appState.now.subtract(
            Duration(minutes: scenario.appState.proposalSets.length - i),
          ),
        ),
    ];
  }

  static ChangeSetEntity _proposalSetFromMock(
    MockProposalSet set, {
    required String defaultTaskId,
    required DateTime defaultCreatedAt,
  }) {
    return AgentDomainEntity.changeSet(
          id: set.id,
          agentId: _agentId,
          taskId: set.targetId ?? defaultTaskId,
          threadId: _threadId,
          runKey: _runKey,
          status: _changeSetStatus(set.status),
          items: [
            for (final item in set.items)
              ChangeItem(
                toolName: item.toolName,
                args: item.args,
                humanSummary: item.humanSummary,
                status: _changeItemStatus(item.status),
                groupId: item.groupId,
              ),
          ],
          createdAt: set.createdAt ?? defaultCreatedAt,
          resolvedAt: set.resolvedAt,
          deletedAt: set.deletedAt,
          vectorClock: null,
        )
        as ChangeSetEntity;
  }

  static List<ChangeDecisionEntity> _seededProposalDecisions(
    EvalScenario scenario,
    String defaultTaskId,
  ) {
    return [
      for (var i = 0; i < scenario.appState.proposalDecisions.length; i++)
        _proposalDecisionFromMock(
          scenario.appState.proposalDecisions[i],
          defaultTaskId: defaultTaskId,
          defaultCreatedAt: scenario.appState.now.subtract(
            Duration(minutes: scenario.appState.proposalDecisions.length - i),
          ),
        ),
    ];
  }

  static ChangeDecisionEntity _proposalDecisionFromMock(
    MockProposalDecision decision, {
    required String defaultTaskId,
    required DateTime defaultCreatedAt,
  }) {
    final verdict = _changeDecisionVerdict(decision.verdict);
    return AgentDomainEntity.changeDecision(
          id: decision.id,
          agentId: _agentId,
          changeSetId: decision.changeSetId,
          itemIndex: decision.itemIndex,
          toolName: decision.toolName,
          verdict: verdict,
          actor: _decisionActor(decision.actor),
          taskId: decision.targetId ?? defaultTaskId,
          rejectionReason: verdict == ChangeDecisionVerdict.rejected
              ? decision.reason
              : null,
          retractionReason: verdict == ChangeDecisionVerdict.retracted
              ? decision.reason
              : null,
          humanSummary: decision.humanSummary,
          args: decision.args.isEmpty ? null : decision.args,
          createdAt: decision.createdAt ?? defaultCreatedAt,
          vectorClock: null,
        )
        as ChangeDecisionEntity;
  }

  static List<ChangeSetEntity> _pendingChangeSets(
    Iterable<AgentDomainEntity> entities, {
    required String agentId,
    required String taskId,
  }) {
    return _changeSetsFor(
      entities,
      agentId: agentId,
      taskId: taskId,
    ).where(_isActivePendingSet).toList();
  }

  static List<ChangeDecisionEntity> _recentDecisions(
    Iterable<AgentDomainEntity> entities, {
    required String agentId,
    required String taskId,
    int? limit,
  }) {
    final decisions =
        entities
            .whereType<ChangeDecisionEntity>()
            .where(
              (decision) =>
                  decision.deletedAt == null &&
                  decision.agentId == agentId &&
                  decision.taskId == taskId,
            )
            .toList()
          ..sort((a, b) {
            final newestFirst = b.createdAt.compareTo(a.createdAt);
            if (newestFirst != 0) return newestFirst;
            return b.id.compareTo(a.id);
          });
    return limit == null ? decisions : decisions.take(limit).toList();
  }

  static ProposalLedger _proposalLedger(
    Iterable<AgentDomainEntity> entities, {
    required String agentId,
    required String taskId,
    int? resolvedLimit,
  }) {
    final sets = _changeSetsFor(entities, agentId: agentId, taskId: taskId);
    final rawPendingSets = sets.where((set) => _isPendingLike(set.status));
    final decisions = _recentDecisions(
      entities,
      agentId: agentId,
      taskId: taskId,
    );
    final decisionByKey = <String, ChangeDecisionEntity>{};
    for (final decision in decisions) {
      decisionByKey.putIfAbsent(
        '${decision.changeSetId}:${decision.itemIndex}',
        () => decision,
      );
    }

    final open = <LedgerEntry>[];
    final resolved = <LedgerEntry>[];
    final pendingSetIds = {for (final set in rawPendingSets) set.id};
    final sanitizedItemsBySetId = <String, List<ChangeItem>>{};

    for (final set in sets) {
      final setIsActive = _isPendingLike(set.status);
      final sanitizedItems = pendingSetIds.contains(set.id)
          ? <ChangeItem>[]
          : null;
      for (var i = 0; i < set.items.length; i++) {
        final item = set.items[i];
        final decision = decisionByKey['${set.id}:$i'];
        final effectiveStatus = _effectiveLedgerStatus(
          setIsActive: setIsActive,
          item: item,
          decision: decision,
        );
        if (sanitizedItems != null) {
          sanitizedItems.add(
            effectiveStatus == item.status
                ? item
                : item.copyWith(status: effectiveStatus),
          );
        }
        final isOpen =
            setIsActive && effectiveStatus == ChangeItemStatus.pending;
        final hasResolvedSignal =
            effectiveStatus != ChangeItemStatus.pending || decision != null;
        if (!isOpen && !hasResolvedSignal) continue;
        final entry = _ledgerEntry(
          set: set,
          itemIndex: i,
          item: item,
          status: effectiveStatus,
          decision: decision,
        );
        if (isOpen) {
          open.add(entry);
        } else {
          resolved.add(entry);
        }
      }
      if (sanitizedItems != null) {
        sanitizedItemsBySetId[set.id] = sanitizedItems;
      }
    }

    open.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    resolved.sort((a, b) {
      final aResolved = a.resolvedAt ?? a.createdAt;
      final bResolved = b.resolvedAt ?? b.createdAt;
      return bResolved.compareTo(aResolved);
    });

    final sanitizedPendingSets = <ChangeSetEntity>[];
    for (final set in rawPendingSets) {
      final items = sanitizedItemsBySetId[set.id];
      if (items == null) continue;
      if (items.any((item) => item.status == ChangeItemStatus.pending)) {
        sanitizedPendingSets.add(set.copyWith(items: items));
      }
    }

    return ProposalLedger(
      open: open,
      resolved: resolvedLimit == null
          ? resolved
          : resolved.take(resolvedLimit).toList(),
      pendingSets: sanitizedPendingSets,
    );
  }

  static List<ChangeSetEntity> _changeSetsFor(
    Iterable<AgentDomainEntity> entities, {
    required String agentId,
    required String taskId,
  }) {
    return entities
        .whereType<ChangeSetEntity>()
        .where(
          (set) =>
              set.deletedAt == null &&
              set.agentId == agentId &&
              set.taskId == taskId,
        )
        .toList()
      ..sort((a, b) {
        final newestFirst = b.createdAt.compareTo(a.createdAt);
        if (newestFirst != 0) return newestFirst;
        return b.id.compareTo(a.id);
      });
  }

  static bool _isActivePendingSet(ChangeSetEntity set) {
    return _isPendingLike(set.status) &&
        set.items.any((item) => item.status == ChangeItemStatus.pending);
  }

  static bool _isPendingLike(ChangeSetStatus status) {
    return status == ChangeSetStatus.pending ||
        status == ChangeSetStatus.partiallyResolved;
  }

  static ChangeItemStatus _effectiveLedgerStatus({
    required bool setIsActive,
    required ChangeItem item,
    required ChangeDecisionEntity? decision,
  }) {
    if (item.status != ChangeItemStatus.pending) return item.status;

    final verdict = decision?.verdict;
    if (verdict == null) return item.status;

    if (setIsActive && verdict == ChangeDecisionVerdict.confirmed) {
      return item.status;
    }
    return _statusForDecision(verdict);
  }

  static LedgerEntry _ledgerEntry({
    required ChangeSetEntity set,
    required int itemIndex,
    required ChangeItem item,
    required ChangeItemStatus status,
    required ChangeDecisionEntity? decision,
  }) {
    return LedgerEntry(
      changeSetId: set.id,
      itemIndex: itemIndex,
      toolName: item.toolName,
      args: item.args,
      humanSummary: item.humanSummary,
      fingerprint: ChangeItem.fingerprint(item),
      status: status,
      createdAt: set.createdAt,
      resolvedAt: decision?.createdAt ?? set.resolvedAt,
      resolvedBy: decision?.actor,
      verdict: decision?.verdict,
      reason: decision?.retractionReason ?? decision?.rejectionReason,
      groupId: item.groupId,
    );
  }

  static ChangeItemStatus _statusForDecision(ChangeDecisionVerdict verdict) {
    return switch (verdict) {
      ChangeDecisionVerdict.confirmed => ChangeItemStatus.confirmed,
      ChangeDecisionVerdict.rejected => ChangeItemStatus.rejected,
      ChangeDecisionVerdict.deferred => ChangeItemStatus.deferred,
      ChangeDecisionVerdict.retracted => ChangeItemStatus.retracted,
    };
  }

  static ChangeSetStatus _changeSetStatus(String name) =>
      ChangeSetStatus.values.firstWhere((status) => status.name == name);

  static ChangeItemStatus _changeItemStatus(String name) =>
      ChangeItemStatus.values.firstWhere((status) => status.name == name);

  static ChangeDecisionVerdict _changeDecisionVerdict(String name) =>
      ChangeDecisionVerdict.values.firstWhere(
        (verdict) => verdict.name == name,
      );

  static DecisionActor _decisionActor(String name) =>
      DecisionActor.values.firstWhere((actor) => actor.name == name);
}
