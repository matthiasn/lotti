// Real-workflow Level 1 bench for the task agent (ADR 0029, Phase 1).
//
// Mirrors PlannerEvalBench but for `TaskAgentWorkflow.execute(...)`. It seeds an
// `EvalScenario` (one active task) onto the centralized mocks + the existing
// task-agent test helpers, scripts the model response through the proven
// `ScriptedConversationRepository` path, runs the real workflow under
// `withClock`, and maps the result to an `AgentRunOutput` the SAME Level 1
// suite grades.
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
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/workflow/task_source_renderer.dart';
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
import 'scripted_conversation_repository.dart';
import 'tool_call_record_mapper.dart';

/// One wake in a same-task task-agent eval cascade.
///
/// [taskLogEntries] are appended to the session before the wake runs, so each
/// wake can add a small transcript while prior reports/proposals remain
/// durable state.
class TaskAgentEvalCascadeWake {
  const TaskAgentEvalCascadeWake({
    this.behavior = const ScriptedAgentBehavior(),
    this.taskLogEntries = const <MockTaskLogEntry>[],
  });

  final ScriptedAgentBehavior behavior;
  final List<MockTaskLogEntry> taskLogEntries;
}

/// Runs the real task-agent workflow for a single-task wake.
abstract final class TaskAgentEvalBench {
  static const _agentId = 'eval-task-agent';
  static const _runKey = 'eval-run';
  static const _threadId = 'eval-thread';
  static const _decidedTaskPrefix = 'decided_task:';
  static const _baselineDirective = 'You are a diligent task agent.';

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
    final session = _TaskAgentEvalSession(
      scenario,
      profile,
      agentDirectiveVariant: context.agentDirectiveVariant,
      profileConfigOverride: profileConfigOverride,
      providerEnvPresence: providerEnvPresence,
    );
    return session.runWake(
      behavior,
      context: context,
      onUserMessage: onUserMessage,
      conversationRepositoryOverride: conversationRepositoryOverride,
      cloudInferenceRepositoryOverride: cloudInferenceRepositoryOverride,
    );
  }

  /// Runs multiple sequential wakes over one shared task-agent session.
  ///
  /// Unlike `profile.trialCount`, this does not reseed repositories between
  /// wakes. Prior reports, observations, proposals, and linked log entries
  /// remain visible to later wakes.
  static Future<List<AgentRunOutput>> runCascade(
    EvalScenario scenario,
    EvalProfile profile, {
    required List<TaskAgentEvalCascadeWake> wakes,
    EvalTargetRunContext context = EvalTargetRunContext.direct,
    void Function(int wakeIndex, String message)? onUserMessage,
    ConversationRepository Function(int wakeIndex)?
    conversationRepositoryForWake,
    CloudInferenceRepository? cloudInferenceRepositoryOverride,
    EvalProfileConfig? profileConfigOverride,
    Map<String, bool>? providerEnvPresence,
    bool seedScenarioTaskLogEntries = true,
  }) async {
    if (wakes.isEmpty) {
      throw ArgumentError.value(wakes, 'wakes', 'must not be empty');
    }
    final session = _TaskAgentEvalSession(
      scenario,
      profile,
      agentDirectiveVariant: context.agentDirectiveVariant,
      profileConfigOverride: profileConfigOverride,
      providerEnvPresence: providerEnvPresence,
      seedScenarioTaskLogEntries: seedScenarioTaskLogEntries,
    );
    final outputs = <AgentRunOutput>[];
    final baseRunKey = _runKeyFor(context);
    final threadId = _threadIdFor(context);
    for (var wakeIndex = 0; wakeIndex < wakes.length; wakeIndex++) {
      final wake = wakes[wakeIndex];
      session.addTaskLogEntries(wake.taskLogEntries);
      outputs.add(
        await session.runWake(
          wake.behavior,
          context: context,
          runKeyOverride: '$baseRunKey:wake-$wakeIndex',
          threadIdOverride: threadId,
          matrixCellIdOverride: context.cellId,
          onUserMessage: onUserMessage == null
              ? null
              : (message) => onUserMessage(wakeIndex, message),
          conversationRepositoryOverride: conversationRepositoryForWake?.call(
            wakeIndex,
          ),
          cloudInferenceRepositoryOverride: cloudInferenceRepositoryOverride,
        ),
      );
    }
    return outputs;
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

  static void _stubPersistedAgentReads(
    MockAgentRepository repo,
    List<AgentDomainEntity> persistedEntities,
  ) {
    when(() => repo.getLatestReport(any(), any())).thenAnswer((
      invocation,
    ) async {
      final agentId = invocation.positionalArguments.first as String;
      final scope = invocation.positionalArguments[1] as String;
      final reports =
          persistedEntities
              .whereType<AgentReportEntity>()
              .where(
                (report) =>
                    report.agentId == agentId &&
                    report.scope == scope &&
                    report.deletedAt == null,
              )
              .toList()
            ..sort((a, b) {
              final newestFirst = b.createdAt.compareTo(a.createdAt);
              if (newestFirst != 0) return newestFirst;
              return b.id.compareTo(a.id);
            });
      return reports.isEmpty ? null : reports.first;
    });
    when(() => repo.getMessagesByKind(any(), any())).thenAnswer((
      invocation,
    ) async {
      final agentId = invocation.positionalArguments.first as String;
      final kind = invocation.positionalArguments[1] as AgentMessageKind;
      return persistedEntities
          .whereType<AgentMessageEntity>()
          .where(
            (message) =>
                message.agentId == agentId &&
                message.kind == kind &&
                message.deletedAt == null,
          )
          .toList()
        ..sort((a, b) {
          final newestFirst = b.createdAt.compareTo(a.createdAt);
          if (newestFirst != 0) return newestFirst;
          return b.id.compareTo(a.id);
        });
    });
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
    required MockJournalRepository journalRepository,
    required MockChecklistRepository checklistRepository,
    required MockAgentTemplateService templateService,
    required AgentTemplateEntity testTemplate,
    required AgentTemplateVersionEntity testTemplateVersion,
    required List<AgentDomainEntity> persistedEntities,
    required Map<String, AgentDomainEntity> entityStore,
    required Map<String, JournalEntity> journalEntities,
    required Map<String, List<JournalEntity>> linkedEntitiesByTaskId,
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
    ).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as String;
      return linkedEntitiesByTaskId[id] ?? const <JournalEntity>[];
    });
    when(() => journalDb.journalEntityById(any())).thenAnswer((invocation) {
      final id = invocation.positionalArguments.single as String;
      return Future.value(journalEntities[id]);
    });
    when(
      () => journalRepository.updateJournalEntity(any()),
    ).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.single as JournalEntity;
      journalEntities[entity.meta.id] = entity;
      return true;
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
    Map<String, List<JournalEntity>> linkedEntitiesByTaskId,
  })
  _seededJournalState(
    List<MockTask> tasks,
    List<MockTaskLogEntry> taskLogEntries,
    DateTime now, {
    required String defaultTaskId,
  }) {
    final entities = <String, JournalEntity>{};
    final checklistItemsByTaskId = <String, List<ChecklistItem>>{};
    final linkedEntitiesByTaskId = <String, List<JournalEntity>>{};
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
    for (final entry in taskLogEntries) {
      final taskId = entry.taskId ?? defaultTaskId;
      final entity = _taskLogEntryEntityFromMock(entry, now);
      entities[entity.meta.id] = entity;
      linkedEntitiesByTaskId.putIfAbsent(taskId, () => []).add(entity);
    }
    for (final linked in linkedEntitiesByTaskId.values) {
      linked.sort((a, b) {
        final byDate = a.meta.dateFrom.compareTo(b.meta.dateFrom);
        if (byDate != 0) return byDate;
        return a.meta.id.compareTo(b.meta.id);
      });
    }
    return (
      entities: entities,
      checklistItemsByTaskId: checklistItemsByTaskId,
      linkedEntitiesByTaskId: linkedEntitiesByTaskId,
    );
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

  static JournalEntity _taskLogEntryEntityFromMock(
    MockTaskLogEntry entry,
    DateTime now,
  ) {
    final startedAt = entry.createdAt ?? now;
    final endedAt = startedAt.add(Duration(minutes: entry.durationMinutes));
    final meta = Metadata(
      id: entry.id,
      createdAt: startedAt,
      updatedAt: startedAt,
      dateFrom: startedAt,
      dateTo: endedAt,
    );
    return switch (entry.entryType) {
      'text' => JournalEntity.journalEntry(
        meta: meta,
        entryText: EntryText(plainText: entry.transcript),
      ),
      'audio' => JournalEntity.journalAudio(
        meta: meta,
        data: AudioData(
          dateFrom: startedAt,
          dateTo: endedAt,
          duration: Duration(minutes: entry.durationMinutes),
          audioFile: '${entry.id}.m4a',
          audioDirectory: '/eval-audio',
          transcripts: [
            AudioTranscript(
              created: startedAt,
              library: 'eval',
              model: 'fixture',
              detectedLanguage: entry.language,
              transcript: entry.transcript,
            ),
          ],
        ),
      ),
      _ => throw ArgumentError(
        'Unsupported task log entryType "${entry.entryType}"',
      ),
    };
  }

  static String _taskDetailsJson(
    MockTask task, {
    required Iterable<JournalEntity> linkedEntities,
  }) {
    final taskJson = Map<String, dynamic>.from(task.toJson());
    taskJson['logEntries'] = [
      for (final source in renderTaskSources(linkedEntities))
        <String, dynamic>{
          'creationTimestamp': source.sourceCreatedAt.toIso8601String(),
          ...source.content,
        },
    ];
    return const JsonEncoder.withIndent('    ').convert(taskJson);
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

class _TaskAgentEvalSession {
  factory _TaskAgentEvalSession(
    EvalScenario scenario,
    EvalProfile profile, {
    EvalAgentDirectiveVariant agentDirectiveVariant =
        const EvalAgentDirectiveVariant(),
    EvalProfileConfig? profileConfigOverride,
    Map<String, bool>? providerEnvPresence,
    bool seedScenarioTaskLogEntries = true,
  }) {
    if (scenario.appState.tasks.isEmpty) {
      throw ArgumentError(
        'Task-agent scenario "${scenario.id}" needs at least one task',
      );
    }
    final taskId = TaskAgentEvalBench._activeTaskIdFromScenario(scenario);
    final activeTask = TaskAgentEvalBench._taskFixtureFor(scenario, taskId);
    final now = scenario.appState.now;
    final profileConfig = profileConfigOverride ?? evalProfileConfig(profile);
    final persistedEntities = <AgentDomainEntity>[];
    final entityStore = <String, AgentDomainEntity>{};
    final journalState = TaskAgentEvalBench._seededJournalState(
      scenario.appState.tasks,
      seedScenarioTaskLogEntries
          ? scenario.appState.taskLogEntries
          : const <MockTaskLogEntry>[],
      now,
      defaultTaskId: taskId,
    );

    for (final changeSet in TaskAgentEvalBench._seededProposalSets(
      scenario,
      taskId,
    )) {
      entityStore[changeSet.id] = changeSet;
    }
    for (final decision in TaskAgentEvalBench._seededProposalDecisions(
      scenario,
      taskId,
    )) {
      entityStore[decision.id] = decision;
    }

    final testAgentState = makeTestState(
      id: 'state-${TaskAgentEvalBench._agentId}',
      agentId: TaskAgentEvalBench._agentId,
      slots: AgentSlots(activeTaskId: taskId),
      updatedAt: now,
    );
    final testTemplate = makeTestTemplate(
      modelId: 'legacy-template-model-must-not-win',
      profileId: profileConfig.profileId,
    );
    final testTemplateVersion = makeTestTemplateVersion(
      id: TaskAgentEvalBench._templateVersionIdForVariant(
        'version-001',
        agentDirectiveVariant,
      ),
      directives: TaskAgentEvalBench._baselineDirective,
      generalDirective: agentDirectiveVariant.mergedGeneralDirective(
        TaskAgentEvalBench._baselineDirective,
      ),
      reportDirective: agentDirectiveVariant.reportDirective,
      modelId: 'legacy-version-model-must-not-win',
      profileId: profileConfig.profileId,
    );
    final identity =
        AgentDomainEntity.agent(
              id: TaskAgentEvalBench._agentId,
              agentId: TaskAgentEvalBench._agentId,
              kind: 'task_agent',
              displayName: 'Eval Task Agent',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: scenario.appState.allowedCategoryIds,
              currentStateId: 'state-${TaskAgentEvalBench._agentId}',
              config: AgentConfig(profileId: profileConfig.profileId),
              createdAt: DateTime(2024),
              updatedAt: now,
              vectorClock: null,
            )
            as AgentIdentityEntity;

    return _TaskAgentEvalSession._(
      scenario: scenario,
      profileConfig: profileConfig,
      providerEnvPresence: providerEnvPresence,
      taskId: taskId,
      activeTask: activeTask,
      now: now,
      agentRepository: MockAgentRepository(),
      syncService: MockAgentSyncService(),
      aiInputRepository: MockAiInputRepository(),
      aiConfigRepository: MockAiConfigRepository(),
      journalDb: MockJournalDb(),
      journalRepository: MockJournalRepository(),
      checklistRepository: MockChecklistRepository(),
      labelsRepository: MockLabelsRepository(),
      templateService: MockAgentTemplateService(),
      persistedEntities: persistedEntities,
      entityStore: entityStore,
      journalEntities: journalState.entities,
      linkedEntitiesByTaskId: journalState.linkedEntitiesByTaskId,
      checklistItemsByTaskId: journalState.checklistItemsByTaskId,
      testAgentState: testAgentState,
      testTemplate: testTemplate,
      testTemplateVersion: testTemplateVersion,
      identity: identity,
    ).._configureStubs();
  }

  _TaskAgentEvalSession._({
    required this.scenario,
    required this.profileConfig,
    required this.providerEnvPresence,
    required this.taskId,
    required this.activeTask,
    required this.now,
    required this.agentRepository,
    required this.syncService,
    required this.aiInputRepository,
    required this.aiConfigRepository,
    required this.journalDb,
    required this.journalRepository,
    required this.checklistRepository,
    required this.labelsRepository,
    required this.templateService,
    required this.persistedEntities,
    required this.entityStore,
    required this.journalEntities,
    required this.linkedEntitiesByTaskId,
    required this.checklistItemsByTaskId,
    required this.testAgentState,
    required this.testTemplate,
    required this.testTemplateVersion,
    required this.identity,
  });

  final EvalScenario scenario;
  final EvalProfileConfig profileConfig;
  final Map<String, bool>? providerEnvPresence;
  final String taskId;
  final MockTask activeTask;
  final DateTime now;
  final MockAgentRepository agentRepository;
  final MockAgentSyncService syncService;
  final MockAiInputRepository aiInputRepository;
  final MockAiConfigRepository aiConfigRepository;
  final MockJournalDb journalDb;
  final MockJournalRepository journalRepository;
  final MockChecklistRepository checklistRepository;
  final MockLabelsRepository labelsRepository;
  final MockAgentTemplateService templateService;
  final List<AgentDomainEntity> persistedEntities;
  final Map<String, AgentDomainEntity> entityStore;
  final Map<String, JournalEntity> journalEntities;
  final Map<String, List<JournalEntity>> linkedEntitiesByTaskId;
  final Map<String, List<ChecklistItem>> checklistItemsByTaskId;
  final AgentStateEntity testAgentState;
  final AgentTemplateEntity testTemplate;
  final AgentTemplateVersionEntity testTemplateVersion;
  final AgentIdentityEntity identity;

  String? _wakeRunResolvedModelId;
  String? _wakeRunTemplateId;
  String? _wakeRunTemplateVersionId;

  void _configureStubs() {
    TaskAgentEvalBench._applyDefaults(
      agentRepository: agentRepository,
      syncService: syncService,
      aiInputRepository: aiInputRepository,
      journalDb: journalDb,
      journalRepository: journalRepository,
      checklistRepository: checklistRepository,
      templateService: templateService,
      testTemplate: testTemplate,
      testTemplateVersion: testTemplateVersion,
      persistedEntities: persistedEntities,
      entityStore: entityStore,
      journalEntities: journalEntities,
      linkedEntitiesByTaskId: linkedEntitiesByTaskId,
      checklistItemsByTaskId: checklistItemsByTaskId,
      categories: TaskAgentEvalBench._categoryDefinitionsFromScenario(
        scenario,
      ),
      labels: TaskAgentEvalBench._labelDefinitionsFromScenario(scenario),
      targetTaskId: taskId,
    );
    final setupConversationManager = MockConversationManager();
    stubFullExecutePath(
      mockAgentRepository: agentRepository,
      mockAiInputRepository: aiInputRepository,
      mockAiConfigRepository: aiConfigRepository,
      mockConversationManager: setupConversationManager,
      testAgentState: testAgentState,
      geminiModel: profileConfig.model,
      geminiProvider: profileConfig.provider,
      agentId: TaskAgentEvalBench._agentId,
      taskId: taskId,
    );
    TaskAgentEvalBench._stubPersistedAgentReads(
      agentRepository,
      persistedEntities,
    );
    TaskAgentEvalBench._stubInferenceProfile(aiConfigRepository, profileConfig);
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
      _wakeRunTemplateId = invocation.positionalArguments[1] as String;
      _wakeRunTemplateVersionId = invocation.positionalArguments[2] as String;
      _wakeRunResolvedModelId =
          invocation.namedArguments[#resolvedModelId] as String?;
    });
    when(
      () => aiInputRepository.buildTaskDetailsJson(id: taskId),
    ).thenAnswer(
      (_) async => TaskAgentEvalBench._taskDetailsJson(
        activeTask,
        linkedEntities: linkedEntitiesByTaskId[taskId] ?? const [],
      ),
    );
  }

  void addTaskLogEntries(Iterable<MockTaskLogEntry> entries) {
    for (final entry in entries) {
      final targetTaskId = entry.taskId ?? taskId;
      if (journalEntities[targetTaskId] is! Task) {
        throw ArgumentError(
          'Task log entry "${entry.id}" references unknown task '
          '"$targetTaskId"',
        );
      }
      if (journalEntities.containsKey(entry.id)) {
        throw ArgumentError('Duplicate task log entry id: ${entry.id}');
      }
      final entity = TaskAgentEvalBench._taskLogEntryEntityFromMock(entry, now);
      journalEntities[entity.meta.id] = entity;
      linkedEntitiesByTaskId.putIfAbsent(targetTaskId, () => []).add(entity);
      linkedEntitiesByTaskId[targetTaskId]!.sort((a, b) {
        final byDate = a.meta.dateFrom.compareTo(b.meta.dateFrom);
        if (byDate != 0) return byDate;
        return a.meta.id.compareTo(b.meta.id);
      });
    }
  }

  Future<AgentRunOutput> runWake(
    ScriptedAgentBehavior behavior, {
    EvalTargetRunContext context = EvalTargetRunContext.direct,
    String? runKeyOverride,
    String? threadIdOverride,
    String? matrixCellIdOverride,
    void Function(String message)? onUserMessage,
    ConversationRepository? conversationRepositoryOverride,
    CloudInferenceRepository? cloudInferenceRepositoryOverride,
  }) async {
    _wakeRunResolvedModelId = null;
    _wakeRunTemplateId = null;
    _wakeRunTemplateVersionId = null;
    final runKey = runKeyOverride ?? TaskAgentEvalBench._runKeyFor(context);
    final threadId =
        threadIdOverride ?? TaskAgentEvalBench._threadIdFor(context);
    final wakeStartEntityCount = persistedEntities.length;
    String? sentProviderModelId;
    AiConfigInferenceProvider? sentProvider;

    final scriptedConversationRepository =
        conversationRepositoryOverride == null
        ? ScriptedConversationRepository()
        : null;
    final conversationRepository =
        conversationRepositoryOverride ?? scriptedConversationRepository!;
    final cloudInferenceRepository =
        cloudInferenceRepositoryOverride ?? MockCloudInferenceRepository();

    if (scriptedConversationRepository != null) {
      final turns = behavior.isMultiTurn
          ? behavior.turns
          : [
              ScriptedAgentTurn(
                toolCalls: behavior.toolCalls,
                finalResponse: behavior.finalResponse,
                usage: behavior.usage,
              ),
            ];
      scriptedConversationRepository
        ..toolCallsByInvocation = [
          for (final turn in turns)
            TaskAgentEvalBench._toToolCalls(turn.toolCalls),
        ]
        ..usageByInvocation = [
          for (final turn in turns) turn.usage,
        ];
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

    final wakeEntities = persistedEntities.skip(wakeStartEntityCount).toList();
    final observer = conversationRepository is EvalConversationObserver
        ? conversationRepository as EvalConversationObserver
        : null;
    final lastUserMessage = observer?.lastUserMessage;
    if (lastUserMessage != null) {
      onUserMessage?.call(lastUserMessage);
    }

    final executedToolCalls = scriptedConversationRepository == null
        ? toolCallRecordsFromPersistedActions(wakeEntities)
        : behavior.toolCallsForTurns(
            scriptedConversationRepository.sendMessageCount,
          );
    return AgentRunOutput(
      success: result.success,
      error: result.error,
      usage: TaskAgentEvalBench._usageFromPersisted(wakeEntities),
      toolCalls: executedToolCalls,
      toolResults: TaskAgentEvalBench._toolResultsFromPersisted(wakeEntities),
      report:
          TaskAgentEvalBench._reportFromPersisted(wakeEntities) ??
          TaskAgentEvalBench._reportFromPersisted(persistedEntities),
      observations: TaskAgentEvalBench._observationsFromPersisted(
        wakeEntities,
      ),
      proposals: proposalRecordsFromPersisted(entityStore.values),
      resolvedModel: TaskAgentEvalBench._resolvedModelFrom(
        profileConfig: profileConfig,
        providerModelId: observer?.lastModel ?? sentProviderModelId,
        provider: observer?.lastProvider ?? sentProvider,
        templateId: _wakeRunTemplateId ?? testTemplate.id,
        templateVersionId: _wakeRunTemplateVersionId ?? testTemplateVersion.id,
        wakeRunResolvedModelId: _wakeRunResolvedModelId,
        usageModelId: TaskAgentEvalBench._usageModelIdFromPersisted(
          wakeEntities,
        ),
      ),
      providerDecision: profileConfig.toProviderDecisionRecord(
        envPresence:
            providerEnvPresence ??
            EvalProvenance.envPresence(Platform.environment),
      ),
      workflowRun: WorkflowRunRecord(
        runKey: runKey,
        threadId: threadId,
        matrixCellId: matrixCellIdOverride,
      ),
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
      turnCount:
          observer?.sendMessageCount ??
          scriptedConversationRepository?.sendMessageCount ??
          0,
    );
  }
}
