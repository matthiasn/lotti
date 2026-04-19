import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/service/suggestion_retraction_service.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/correction_examples_builder.dart';
import 'package:lotti/features/agents/tools/task_label_handler.dart';
import 'package:lotti/features/agents/workflow/change_proposal_filter.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/time_service.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

export 'package:lotti/features/agents/workflow/wake_result.dart';

/// Assembles context, runs a conversation, and persists results for a single
/// Task Agent wake cycle.
///
/// ## Lifecycle
///
/// 1. Load agent identity, state, current report, and agentJournal observations.
/// 2. Build task context from journal domain via [AiInputRepository].
/// 3. Resolve the agent's template and active version.
/// 4. Resolve an inference profile (or legacy modelId fallback) to a
///    thinking model/provider.
/// 5. Assemble conversation context (system prompt + user message).
/// 6. Create a [ConversationRepository] conversation with tool definitions.
/// 7. Persist the user message as an [AgentMessageKind.user] entity for
///    inspectability (non-fatal if it fails).
/// 8. Invoke the LLM and execute tool calls via [AgentToolExecutor].
/// 9. Persist the final assistant response as a thought message.
/// 10. Extract and persist the updated report (from `update_report` tool call).
/// 11. Persist new observation notes (agentJournal entries).
/// 12. Persist updated agent state (revision, wake counter, failure count).
/// 13. Clean up the in-memory conversation in a `finally` block.
class TaskAgentWorkflow {
  TaskAgentWorkflow({
    required this.agentRepository,
    required this.conversationRepository,
    required this.aiInputRepository,
    required this.aiConfigRepository,
    required this.journalDb,
    required this.cloudInferenceRepository,
    required this.journalRepository,
    required this.checklistRepository,
    required this.labelsRepository,
    required this.syncService,
    required this.templateService,
    this.soulDocumentService,
    this.domainLogger,
    this.embeddingStore,
    this.embeddingRepository,
    this.taskAgentService,
    this.projectRepository,
  });

  final AgentRepository agentRepository;

  /// Sync-aware write service. All entity writes go through this so they
  /// are automatically enqueued for cross-device sync.
  final AgentSyncService syncService;
  final ConversationRepository conversationRepository;
  final AiInputRepository aiInputRepository;
  final AiConfigRepository aiConfigRepository;
  final JournalDb journalDb;
  final CloudInferenceRepository cloudInferenceRepository;
  final JournalRepository journalRepository;
  final ChecklistRepository checklistRepository;
  final LabelsRepository labelsRepository;
  final AgentTemplateService templateService;
  final SoulDocumentService? soulDocumentService;

  /// Optional domain logger for structured, PII-safe logging.
  final DomainLogger? domainLogger;

  /// Optional embedding dependencies. When both are provided, agent reports
  /// are embedded for vector search after persistence. The pipeline is
  /// non-essential — if unavailable, reports are still persisted normally.
  final EmbeddingStore? embeddingStore;
  final OllamaEmbeddingRepository? embeddingRepository;

  /// Optional task agent service for auto-assigning agents to follow-up tasks.
  final TaskAgentService? taskAgentService;

  /// Optional project repository for inheriting projects on follow-up tasks.
  final ProjectRepository? projectRepository;

  static const _uuid = Uuid();

  void _log(String message, {String? subDomain}) {
    domainLogger?.log(
      LogDomains.agentWorkflow,
      message,
      subDomain: subDomain,
    );
  }

  void _logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (domainLogger != null) {
      domainLogger!.error(
        LogDomains.agentWorkflow,
        message,
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      developer.log(
        '$message${error != null ? ': $error' : ''}',
        name: 'TaskAgentWorkflow',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Execute a full wake cycle for the given agent.
  ///
  /// [agentIdentity] is the agent's identity entity.
  /// [runKey] is the deterministic run key for this wake cycle.
  /// [triggerTokens] is the set of entity IDs that triggered this wake.
  /// [threadId] is the conversation thread ID for this wake.
  ///
  /// Returns the set of mutated entity IDs and their vector clocks, for
  /// self-notification suppression by the orchestrator.
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
  }) async {
    final agentId = agentIdentity.id;

    _log(
      'wake start: agent=${DomainLogger.sanitizeId(agentId)}, '
      'triggers=${triggerTokens.length}',
      subDomain: 'execute',
    );

    // 1. Load current state + both memory types.
    final state = await agentRepository.getAgentState(agentId);
    if (state == null) {
      _log('no agent state found — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'No agent state found');
    }

    final taskId = state.slots.activeTaskId;
    if (taskId == null) {
      _log('no active task ID — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'No active task ID');
    }

    _log(
      'state resolved, taskId=${DomainLogger.sanitizeId(taskId)}',
      subDomain: 'execute',
    );

    final lastReport = await agentRepository.getLatestReport(
      agentId,
      AgentReportScopes.current,
    );
    final journalObservations = await agentRepository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
    );

    // 2. Build task context from journal domain (independent fetches in
    //    parallel).
    // NOTE: Related-project task enrichment is intentionally disabled here.
    // Injecting sibling-task TLDRs polluted the context window, and the
    // related-task drill-down tool is currently hidden from the LLM until it
    // can be backed by a better retrieval path.
    final (
      taskDetailsJson,
      projectContextJson,
      linkedTasksJson,
    ) = await (
      aiInputRepository.buildTaskDetailsJson(id: taskId),
      aiInputRepository.buildProjectContextJsonForTask(taskId),
      _buildLinkedTasksContextJson(taskId),
    ).wait;

    if (taskDetailsJson == null) {
      _log('task not found in journal — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'Task not found');
    }

    // 3. Resolve the agent's template and active version.
    final templateCtx = await _resolveTemplate(agentId);
    if (templateCtx == null) {
      _log('no template assigned — aborting wake', subDomain: 'execute');
      return const WakeResult(
        success: false,
        error: 'No template assigned to agent',
      );
    }

    _log(
      'template=${DomainLogger.sanitizeId(templateCtx.template.id)}, '
      'version=${DomainLogger.sanitizeId(templateCtx.version.id)}, '
      'model=${templateCtx.version.modelId ?? templateCtx.template.modelId}',
      subDomain: 'execute',
    );

    // 4. Resolve inference profile (or legacy modelId) → provider.
    final profileResolver = ProfileResolver(
      aiConfigRepository: aiConfigRepository,
    );
    final resolvedProfile = await profileResolver.resolve(
      agentConfig: agentIdentity.config,
      template: templateCtx.template,
      version: templateCtx.version,
    );
    if (resolvedProfile == null) {
      final modelId =
          templateCtx.version.modelId ?? templateCtx.template.modelId;
      _log(
        'no provider configured for model $modelId — aborting wake',
        subDomain: 'execute',
      );
      return const WakeResult(
        success: false,
        error: 'No inference provider configured',
      );
    }
    final modelId = resolvedProfile.thinkingModelId;
    final provider = resolvedProfile.thinkingProvider;

    // 5. Assemble conversation context.
    // One ledger fetch feeds both the LLM prompt (status-sorted view of
    // the agent's own history) and the ChangeSetBuilder (open pending
    // sets for cross-wake dedup).
    final ledger = await agentRepository.getProposalLedger(
      agentId,
      taskId: taskId,
    );
    final pendingSets = ledger.pendingSets;

    final systemPrompt = _buildSystemPrompt(templateCtx);
    final userMessage = await _buildUserMessage(
      agentId: agentId,
      lastReport: lastReport,
      journalObservations: journalObservations,
      taskDetailsJson: taskDetailsJson,
      projectContextJson: projectContextJson,
      linkedTasksJson: linkedTasksJson,
      triggerTokens: triggerTokens,
      taskId: taskId,
      ledger: ledger,
    );

    // 6. Create conversation and run with strategy.
    final conversationId = conversationRepository.createConversation(
      systemMessage: systemPrompt,
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

    // Capture timestamp once for all persistence in this wake (both success
    // and failure paths) so causality tracking is consistent.
    final now = clock.now();

    // 6a. Persist the user message for inspectability before sending to LLM.
    try {
      final userPayloadId = _uuid.v4();
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: userPayloadId,
          agentId: agentId,
          createdAt: now,
          vectorClock: null,
          content: <String, Object?>{'text': userMessage},
        ),
      );
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: _uuid.v4(),
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.user,
          createdAt: now,
          vectorClock: null,
          contentEntryId: userPayloadId,
          metadata: AgentMessageMetadata(runKey: runKey),
        ),
      );
    } catch (e) {
      _logError('failed to persist user message', error: e);
      // Non-fatal: continue with execution even if audit fails.
    }

    try {
      final executor = AgentToolExecutor(
        syncService: syncService,
        allowedCategoryIds: agentIdentity.allowedCategoryIds,
        runKey: runKey,
        agentId: agentId,
        threadId: threadId,
      );

      final toolDispatcher = TaskToolDispatcher(
        journalDb: journalDb,
        journalRepository: journalRepository,
        checklistRepository: checklistRepository,
        labelsRepository: labelsRepository,
        persistenceLogic: getIt<PersistenceLogic>(),
        timeService: getIt<TimeService>(),
        taskAgentService: taskAgentService,
        projectRepository: projectRepository,
      );

      final changeSetBuilder = ChangeSetBuilder(
        agentId: agentId,
        taskId: taskId,
        threadId: threadId,
        runKey: runKey,
        domainLogger: domainLogger,
        checklistItemStateResolver: (itemId) async {
          final entity = await journalDb.journalEntityById(itemId);
          if (entity is ChecklistItem) {
            return (
              title: entity.data.title,
              isChecked: entity.data.isChecked,
            );
          }
          return null;
        },
        existingChecklistTitlesResolver: () async {
          final entity = await journalDb.journalEntityById(taskId);
          if (entity is! Task) return {};
          final items = await checklistRepository.getChecklistItemsForTask(
            task: entity,
            deletedOnly: false,
          );
          return items
              .map((item) => item.data.title.toLowerCase().trim())
              .toSet();
        },
        labelNameResolver: (labelId) async {
          final label = await journalDb.getLabelDefinitionById(labelId);
          return label?.name;
        },
        existingLabelIdsResolver: () async {
          final entity = await journalDb.journalEntityById(taskId);
          return entity?.meta.labelIds?.toSet() ?? {};
        },
      );

      final strategy = TaskAgentStrategy(
        executor: executor,
        syncService: syncService,
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        taskId: taskId,
        changeSetBuilder: changeSetBuilder,
        retractionService: SuggestionRetractionService(
          syncService: syncService,
          domainLogger: domainLogger,
        ),
        resolveTaskMetadata: () =>
            ChangeProposalFilter.resolveTaskMetadata(journalDb, taskId),
        resolveCategoryId: (entityId) async {
          final entity = await journalDb.journalEntityById(entityId);
          return entity?.categoryId;
        },
        readVectorClock: (entityId) async {
          final entity = await journalDb.journalEntityById(entityId);
          return entity?.meta.vectorClock;
        },
        executeToolHandler: (toolName, args, manager) =>
            toolDispatcher.dispatch(toolName, args, taskId),
        resolveRelatedTaskDetails: (requestedTaskId) {
          return aiInputRepository.buildRelatedTaskDetailsJson(
            currentTaskId: taskId,
            requestedTaskId: requestedTaskId,
          );
        },
      );

      final tools = _buildToolDefinitions();
      final inferenceRepo = CloudInferenceWrapper(
        cloudRepository: cloudInferenceRepository,
      );

      // Record template + soul provenance and the resolved model on the wake
      // run log entry so that modelIdForThread can return an accurate model
      // even for failed/incomplete wakes that never persist token usage.
      try {
        await agentRepository.updateWakeRunTemplate(
          runKey,
          templateCtx.template.id,
          templateCtx.version.id,
          resolvedModelId: modelId,
          soulId: templateCtx.soulVersion?.agentId,
          soulVersionId: templateCtx.soulVersion?.id,
        );
      } catch (e) {
        _logError('failed to record template provenance', error: e);
        // Non-fatal: the wake can proceed without provenance tracking.
      }

      // 7. Invoke the LLM and execute tool calls via AgentToolExecutor.
      var usage = await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: userMessage,
        model: modelId,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: 0.3,
        strategy: strategy,
      );

      // 7b. Forced-report retry (see [_forceUpdateReportIfMissing]).
      if (strategy.extractReportContent().isEmpty) {
        final retryUsage = await _forceUpdateReportIfMissing(
          conversationId: conversationId,
          modelId: modelId,
          provider: provider,
          inferenceRepo: inferenceRepo,
          tools: tools,
          strategy: strategy,
        );
        if (retryUsage != null) {
          usage = usage == null ? retryUsage : usage.merge(retryUsage);
        }
      }

      // Persist token usage as a synced entity (non-fatal on failure).
      await _persistTokenUsage(
        usage: usage,
        agentId: agentId,
        runKey: runKey,
        threadId: threadId,
        modelId: modelId,
        templateCtx: templateCtx,
        now: now,
      );

      // Capture the final assistant response from the conversation manager.
      final manager = conversationRepository.getConversation(conversationId);
      final finalContent = _extractFinalAssistantContent(manager);
      strategy.recordFinalResponse(finalContent);

      // 7–11. Persist all wake outputs atomically. Wrapping in a transaction
      // ensures the state revision is only bumped if all outputs (thought,
      // report, observations) are successfully written.
      final reportContent = strategy.extractReportContent();
      final reportTldr = strategy.extractReportTldr();
      final reportOneLiner = strategy.extractReportOneLiner();
      if (reportContent.isEmpty) {
        _log(
          'no report published (violates update_report contract)',
          subDomain: 'execute',
        );
      }

      final observations = strategy.extractObservations();

      // Collects report details inside the transaction for post-commit
      // embedding. Declared outside so it survives the transaction scope.
      ({
        String reportId,
        String reportContent,
        String taskId,
        String? previousReportId,
      })?
      reportToEmbed;

      await syncService.runInTransaction(() async {
        // 8. Persist the final assistant response as a thought message.
        final thoughtText = strategy.finalResponse;
        if (thoughtText != null) {
          final thoughtPayloadId = _uuid.v4();
          await syncService.upsertEntity(
            AgentDomainEntity.agentMessagePayload(
              id: thoughtPayloadId,
              agentId: agentId,
              createdAt: now,
              vectorClock: null,
              content: <String, Object?>{'text': thoughtText},
            ),
          );
          await syncService.upsertEntity(
            AgentDomainEntity.agentMessage(
              id: _uuid.v4(),
              agentId: agentId,
              threadId: threadId,
              kind: AgentMessageKind.thought,
              createdAt: now,
              vectorClock: null,
              contentEntryId: thoughtPayloadId,
              metadata: AgentMessageMetadata(runKey: runKey),
            ),
          );
        }

        // 9. Extract and persist updated report (from update_report tool call).
        if (reportContent.isNotEmpty) {
          final reportId = _uuid.v4();

          await syncService.upsertEntity(
            AgentDomainEntity.agentReport(
              id: reportId,
              agentId: agentId,
              scope: AgentReportScopes.current,
              createdAt: now,
              vectorClock: null,
              content: reportContent,
              tldr: reportTldr,
              oneLiner: reportOneLiner,
              threadId: threadId,
            ),
          );

          // Update the report head pointer.
          final existingHead = await agentRepository.getReportHead(
            agentId,
            AgentReportScopes.current,
          );
          final headId = existingHead?.id ?? _uuid.v4();

          await syncService.upsertEntity(
            AgentDomainEntity.agentReportHead(
              id: headId,
              agentId: agentId,
              scope: AgentReportScopes.current,
              reportId: reportId,
              updatedAt: now,
              vectorClock: null,
            ),
          );

          // Capture report details for post-transaction embedding.
          reportToEmbed = (
            reportId: reportId,
            reportContent: reportContent,
            taskId: taskId,
            previousReportId: existingHead?.reportId,
          );
        }

        // 10. Persist new observation notes (agentJournal entries).
        for (final observation in observations) {
          final payloadId = _uuid.v4();
          await syncService.upsertEntity(
            AgentDomainEntity.agentMessagePayload(
              id: payloadId,
              agentId: agentId,
              createdAt: now,
              vectorClock: null,
              content: <String, Object?>{
                'text': observation.text,
                'priority': observation.priority.name,
                'category': observation.category.name,
              },
            ),
          );

          await syncService.upsertEntity(
            AgentDomainEntity.agentMessage(
              id: _uuid.v4(),
              agentId: agentId,
              threadId: threadId,
              kind: AgentMessageKind.observation,
              createdAt: now,
              vectorClock: null,
              contentEntryId: payloadId,
              metadata: AgentMessageMetadata(runKey: runKey),
            ),
          );
        }

        // 10b. Persist deferred change set (if any items were accumulated).
        // Pass the full pending sets so the builder can merge into an
        // existing one rather than creating a duplicate entity.
        //
        // Reuse the proposal ledger we already fetched at step 5 to derive
        // rejected fingerprints — avoids a second round-trip to the
        // repository for the same data.
        final rejectedFingerprints = ledger.resolved
            .where((e) => e.verdict == ChangeDecisionVerdict.rejected)
            .map((e) => e.fingerprint)
            .toSet();

        await changeSetBuilder.build(
          syncService,
          existingPendingSets: pendingSets,
          rejectedFingerprints: rejectedFingerprints,
        );

        // 11. Persist state.
        await syncService.upsertEntity(
          state.copyWith(
            revision: state.revision + 1,
            lastWakeAt: now,
            updatedAt: now,
            consecutiveFailureCount: 0,
            wakeCounter: state.wakeCounter + 1,
          ),
        );
      });

      // 9b. Embed the report for vector search (fire-and-forget).
      // Runs after the transaction commits so we never embed rolled-back data.
      final embed = reportToEmbed;
      if (embed != null) {
        unawaited(
          _embedAgentReport(
            reportId: embed.reportId,
            reportContent: embed.reportContent,
            taskId: embed.taskId,
            previousReportId: embed.previousReportId,
          ),
        );
      }

      developer.log(
        'Wake completed for agent $agentId: '
        '${observations.length} observations, '
        '${executor.mutatedEntries.length} mutations, '
        '${changeSetBuilder.items.length} deferred changes',
        name: 'TaskAgentWorkflow',
      );

      return WakeResult(
        success: true,
        mutatedEntries: executor.mutatedEntries,
      );
    } catch (e, s) {
      _logError('wake failed', error: e, stackTrace: s);

      // Update failure count in state.
      try {
        await syncService.upsertEntity(
          state.copyWith(
            revision: state.revision + 1,
            updatedAt: now,
            consecutiveFailureCount: state.consecutiveFailureCount + 1,
          ),
        );
      } catch (stateError, s) {
        _logError(
          'failed to update failure count',
          error: stateError,
          stackTrace: s,
        );
      }

      return WakeResult(success: false, error: e.toString());
    } finally {
      // 12. Clean up in-memory conversation to prevent resource leaks.
      conversationRepository.deleteConversation(conversationId);
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Issues a second, forced inference pass to recover a missing report.
  ///
  /// Weaker local models (e.g. Qwen 3.6 via `mlx-vlm`) routinely stop
  /// generating before emitting the mandatory `update_report` tool call,
  /// which leaves the UI with nothing to display. This helper is invoked
  /// when the main wake loop returns without a published report: it sends
  /// one more `sendMessage` with `toolChoice` pinned to `update_report`
  /// and a blunt reminder message. On OpenAI-compatible endpoints this
  /// guarantees a final tool call; on providers that silently ignore
  /// `toolChoice` (Gemini / Ollama / Mistral sub-repos) the directive
  /// message alone still nudges most models into compliance.
  ///
  /// The tool list is restricted to only the report tool — the forced
  /// `toolChoice` is defense in depth, but on providers that drop the
  /// option the model would otherwise see the full tool surface again and
  /// could issue a duplicate metadata or checklist call. Narrowing the
  /// list guarantees that even a misbehaving provider can only emit the
  /// tool we actually want.
  ///
  /// Any failure inside the retry (network error, parser error on a
  /// truncated response, etc.) is caught and logged — the wake must still
  /// persist observations and metadata work collected in the main pass.
  ///
  /// Returns the retry's token usage (if any) so the caller can merge it
  /// into the wake's accumulated total.
  Future<InferenceUsage?> _forceUpdateReportIfMissing({
    required String conversationId,
    required String modelId,
    required AiConfigInferenceProvider provider,
    required CloudInferenceWrapper inferenceRepo,
    required List<ChatCompletionTool> tools,
    required TaskAgentStrategy strategy,
  }) async {
    _log(
      'no report published — retrying with forced update_report',
      subDomain: 'execute',
    );
    const forcedToolChoice = ChatCompletionToolChoiceOption.tool(
      ChatCompletionNamedToolChoice(
        type: ChatCompletionNamedToolChoiceType.function,
        function: ChatCompletionFunctionCallOption(
          name: TaskAgentStrategy.reportToolName,
        ),
      ),
    );
    final reportOnlyTools = tools
        .where((tool) => tool.function.name == TaskAgentStrategy.reportToolName)
        .toList(growable: false);

    try {
      return await conversationRepository.sendMessage(
        conversationId: conversationId,
        message:
            'You did not call `update_report` before stopping. Call it '
            'now. You MUST supply a concise `oneLiner`, a 1-3 sentence '
            '`tldr`, and the full markdown `content`. This is the final '
            'step of the wake and is mandatory — do not respond with '
            'anything else.',
        model: modelId,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: reportOnlyTools,
        toolChoice: forcedToolChoice,
        temperature: 0.3,
        strategy: strategy,
      );
    } catch (e, s) {
      _logError(
        'forced update_report retry failed — persisting partial wake',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  /// Persist token usage from a wake cycle as a synced entity.
  ///
  /// Non-fatal: failures are logged but do not abort the wake.
  Future<void> _persistTokenUsage({
    required InferenceUsage? usage,
    required String agentId,
    required String runKey,
    required String threadId,
    required String modelId,
    required _TemplateContext templateCtx,
    required DateTime now,
  }) async {
    if (usage == null || !usage.hasData) return;

    try {
      await syncService.upsertEntity(
        AgentDomainEntity.wakeTokenUsage(
          id: _uuid.v4(),
          agentId: agentId,
          runKey: runKey,
          threadId: threadId,
          modelId: modelId,
          templateId: templateCtx.template.id,
          templateVersionId: templateCtx.version.id,
          soulDocumentId: templateCtx.soulVersion?.agentId,
          soulDocumentVersionId: templateCtx.soulVersion?.id,
          createdAt: now,
          vectorClock: null,
          inputTokens: usage.inputTokens,
          outputTokens: usage.outputTokens,
          thoughtsTokens: usage.thoughtsTokens,
          cachedInputTokens: usage.cachedInputTokens,
        ),
      );
    } catch (e, s) {
      _logError('failed to persist token usage', error: e, stackTrace: s);
    }
  }

  /// Embeds an agent report for vector search and supersedes the previous
  /// report's embedding if one exists.
  ///
  /// Non-fatal: failures are logged but do not affect the wake cycle.
  /// Called as fire-and-forget via [unawaited] after report persistence.
  Future<void> _embedAgentReport({
    required String reportId,
    required String reportContent,
    required String taskId,
    String? previousReportId,
  }) async {
    final store = embeddingStore;
    final repo = embeddingRepository;
    if (store == null || repo == null) return;

    try {
      final baseUrl = await aiConfigRepository.resolveOllamaBaseUrl();
      if (baseUrl == null) return;

      // Resolve the task's category for category-scoped search.
      final taskEntity = await journalDb.journalEntityById(taskId);
      final categoryId = taskEntity?.meta.categoryId ?? '';

      final didEmbed = await EmbeddingProcessor.processAgentReport(
        reportId: reportId,
        reportContent: reportContent,
        taskId: taskId,
        categoryId: categoryId,
        subtype: AgentReportScopes.current,
        embeddingStore: store,
        embeddingRepository: repo,
        baseUrl: baseUrl,
      );

      // Delete the old report's embedding only after the new one succeeds,
      // so we don't lose search coverage if the embedding call fails or
      // the content is too short.
      if (didEmbed && previousReportId != null) {
        await store.deleteEntityEmbeddings(previousReportId);
      }
    } catch (e, s) {
      _logError('failed to embed agent report', error: e, stackTrace: s);
    }
  }

  /// Resolves the template and its active version for the given [agentId].
  ///
  /// Returns `null` if no template is assigned or if the active version
  /// cannot be resolved.
  Future<_TemplateContext?> _resolveTemplate(String agentId) async {
    final template = await templateService.getTemplateForAgent(agentId);
    if (template == null) {
      _log('no template assigned', subDomain: 'resolve');
      return null;
    }

    final version = await templateService.getActiveVersion(template.id);
    if (version == null) {
      _log('no active version for template', subDomain: 'resolve');
      return null;
    }

    // Resolve the soul document assigned to this template, if any.
    // Returns null when no soul is assigned — that's the legitimate fallback.
    // Exceptions propagate: a broken soul chain is a real error.
    final soulVersion = await soulDocumentService?.resolveActiveSoulForTemplate(
      template.id,
    );
    if (soulVersion != null) {
      _log(
        'resolved soul v${soulVersion.version} for template',
        subDomain: 'resolve',
      );
    }

    return _TemplateContext(
      template: template,
      version: version,
      soulVersion: soulVersion,
    );
  }

  /// Builds the full system prompt from the scaffold and template directives.
  ///
  /// When a soul document is assigned, personality is injected under
  /// `## Your Personality` from the soul version fields, and operational
  /// directives under `## Your Operational Directives` from
  /// `generalDirective`. When no soul is assigned, the existing
  /// `## Your Personality & Directives` heading is preserved for backwards
  /// compatibility.
  String _buildSystemPrompt(_TemplateContext ctx) {
    final version = ctx.version;
    final soulVersion = ctx.soulVersion;
    final trimmedGeneralDirective = version.generalDirective.trim();
    final trimmedReportDirective = version.reportDirective.trim();
    final trimmedLegacyDirective = version.directives.trim();
    final hasNewDirectives =
        trimmedGeneralDirective.isNotEmpty || trimmedReportDirective.isNotEmpty;

    if (hasNewDirectives) {
      final buf = StringBuffer()..write(taskAgentScaffoldCore);

      if (trimmedReportDirective.isNotEmpty) {
        buf
          ..writeln()
          ..writeln()
          ..writeln('## Report Directive')
          ..writeln()
          ..write(trimmedReportDirective);
      } else {
        buf.write(taskAgentScaffoldReport);
      }

      buf
        ..write(taskAgentScaffoldProjectContext)
        ..write(taskAgentScaffoldTrailing);

      if (soulVersion != null) {
        // Soul assigned: separate personality from operational directives.
        _appendSoulPersonality(buf, soulVersion);
        if (trimmedGeneralDirective.isNotEmpty) {
          buf
            ..writeln()
            ..writeln()
            ..writeln('## Your Operational Directives')
            ..writeln()
            ..write(trimmedGeneralDirective);
        }
      } else {
        // No soul: legacy combined heading.
        final effectiveGeneralDirective = trimmedGeneralDirective.isNotEmpty
            ? trimmedGeneralDirective
            : trimmedLegacyDirective;
        if (effectiveGeneralDirective.isNotEmpty) {
          buf
            ..writeln()
            ..writeln()
            ..writeln('## Your Personality & Directives')
            ..writeln()
            ..write(effectiveGeneralDirective);
        }
      }

      return buf.toString();
    }

    // Legacy fallback: single directives field.
    return '$taskAgentScaffold\n\n'
        '## Your Personality & Directives\n\n'
        '${version.directives}';
  }

  /// Appends soul personality fields to the prompt buffer.
  static void _appendSoulPersonality(
    StringBuffer buf,
    SoulDocumentVersionEntity soul,
  ) {
    buf
      ..writeln()
      ..writeln()
      ..writeln('## Your Personality')
      ..writeln()
      ..write(soul.voiceDirective);

    if (soul.toneBounds.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..write(soul.toneBounds);
    }
    if (soul.coachingStyle.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..write(soul.coachingStyle);
    }
    if (soul.antiSycophancyPolicy.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..write(soul.antiSycophancyPolicy);
    }
  }

  /// The rigid scaffold of the Task Agent system prompt, combining all parts.
  ///
  /// Used as a single constant for legacy templates that have no split
  /// directives. New templates use the three sub-constants below.
  static const taskAgentScaffold =
      '$taskAgentScaffoldCore'
      '$taskAgentScaffoldReport'
      '$taskAgentScaffoldProjectContext'
      '$taskAgentScaffoldTrailing';

  /// Core scaffold: role description and job responsibilities.
  static const taskAgentScaffoldCore = '''
You are a Task Agent — a persistent assistant that maintains a summary report
for a single task.

## Non-Negotiable Final Step

EVERY wake MUST end with a single `update_report` tool call. This is mandatory,
not optional. No other tool replaces it. If you have nothing new to say, still
call `update_report` — reuse the prior report's content and refresh the
one-liner and tldr as needed. Do NOT end your turn with a plain text message.
Do NOT stop after calling metadata or checklist tools. The wake is only
complete when `update_report` has been called with `oneLiner`, `tldr`, and
`content`.

Your job each wake is to:

1. Analyze the current task state and any changes since your last wake.
2. Call tools when appropriate to update task metadata (estimates, due dates,
   priorities, checklist items, title, labels).
3. Call `record_observations` for ANYTHING private: your own reasoning,
   things you noticed, patterns across wakes, blockers you hit (including
   tool failures such as a denied category or a rejected proposal), and any
   self-reflection that does NOT belong in the user-facing report. If it
   starts with "I noticed...", "I tried...", "I decided...", or describes a
   tool failure — it is an observation, not report content. Skipping this
   tool means that context is lost forever on the next wake.
4. FINAL STEP — publish an updated report via the `update_report` tool. Always
   do this last; never skip it.''';

  /// Default report section of the scaffold, used when the template version
  /// does not provide its own `reportDirective`.
  static const taskAgentScaffoldReport = '''


## Report

You MUST call `update_report` exactly once at the end of every wake with the
full updated report as markdown. Provide `oneLiner`, `tldr`, and `content`.
The report must follow this standardized structure with emojis for visual
consistency:

### Required Sections

1. **One-Liner argument** — A concise task tagline for compact task-card
   subtitles. Keep it short and meaningful, for example:
   "Implementation done, release and documentation next" or
   "At risk of missing the deadline without API review".
2. **📋 TLDR** — A concise 1-3 sentence overview of the task's current state.
   This is the first and most important section — it is what the user sees in
   the collapsed view.
3. **✅ Achieved** — What has been accomplished (bulleted list). Omit if
   nothing has been achieved yet.
4. **📌 What is left to do** — Remaining work items (bulleted list). Omit if
   the task is complete.
5. **💡 Learnings** — Key insights, patterns, or decisions worth surfacing to
   the user. Omit if there are no noteworthy learnings.

Do NOT include a title line (H1) or a status bar — these are already shown in
the task header UI. Do NOT include a "Goal / Context" section — this is
redundant with the task description.

You MAY add additional sections if they add value (e.g., ⚠️ Blockers,
📊 Metrics), but the core sections above should always be present when
applicable.

### Example report:

```
## 📋 TLDR
OAuth2 integration is 60% complete. Login UI is done, logout flow and
integration tests remain.

## ✅ Achieved
- Set up OAuth provider configuration
- Implemented token refresh logic
- Built login UI with error handling

## 📌 What is left to do
- Add logout flow with token revocation
- Write integration tests for auth endpoints

## 💡 Learnings
- Token refresh needs a 30s buffer before expiry to avoid race conditions
- Error handling for expired sessions requires a dedicated middleware
```

### Writing style
- IMPORTANT: Write the report in the language specified by the task's
  `languageCode` field (e.g. "de" → German, "fr" → French). Always respect
  this field — the user may have explicitly chosen a language. If
  `languageCode` is null, detect the language from the task content.
- Express your personality and voice as defined in your directives.
- Keep the report user-facing. No meta-commentary about being an agent.
- Use present tense for current state, past tense for completed work.

## Report vs Observations — Separation of Concerns

The report (`update_report`) is the PUBLIC, user-facing summary. It should contain:
- Task status, progress, and key metrics
- What was achieved and what remains
- Any deadlines or priorities

The report MUST NOT contain:
- Internal reasoning or decision logs
- "I noticed..." or "I decided to..." commentary
- Debugging notes, failure analysis, or retry logs
- Agent self-reflection or meta-commentary
- Links to linked tasks (parent, child, follow-up) — these are already
  shown in a dedicated "Linked Tasks" UI section below the report. Never
  use internal task IDs or shortened hashes as link targets — they cannot
  be opened and are meaningless to the user. Only include real external
  URLs (GitHub, Stack Overflow, documentation, etc.) in a Links section.

Use `record_observations` for ALL internal notes. Observations are private
and never shown to the user. They persist as your memory across wakes.''';

  /// Parent-project context guidance for task agents.
  static const taskAgentScaffoldProjectContext = '''


## Parent Project Context

When a task belongs to a project, the wake payload may include a
`Parent Project Context` JSON block. This contains the parent project's
identity/metadata plus the latest project-agent report with both:
- `tldr`: the concise project summary
- `content`: the full project report body

Use this as high-level planning context:
- align task recommendations with project priorities, blockers, and sequencing
- look for project-level dependencies or risks that change what matters next
- prefer direct evidence from the current task when it conflicts with older,
  broader project context
''';

  /// Trailing scaffold: tool usage guidelines and important constraints.
  static const taskAgentScaffoldTrailing = '''


## Tool Usage Guidelines

- **No-op rule**: Before calling ANY metadata tool (status, priority, due date,
  estimate, language, labels), check the current value in the task context. If
  the value is already what you would set, do NOT call the tool. Every
  unnecessary tool call wastes a turn and clutters the audit log.
- Only call tools when you have sufficient confidence in the change.
- Do not call tools speculatively or redundantly.
- When a tool call fails, note the failure in observations and move on.
- Each tool call is audited and must stay within the task's category scope.
- **Learn from past decisions**: Review the `## Proposal Ledger` section in
  the task context. Open entries are proposals you made in earlier wakes
  that the user has not yet acted on. Resolved entries show user verdicts
  (confirmed / rejected / deferred) and your own retractions. If the user
  rejected a proposal, do not repeat the same or a similar suggestion
  unless circumstances have clearly changed. Confirmed proposals indicate
  the user's preferences — build on them.
- **Observations**: Record private notes worth remembering for future wakes.
  Good observations include:
  - Why you transitioned a status (e.g., "Set BLOCKED because user mentioned
    waiting for API credentials in note from 2026-02-25")
  - Rationale behind metadata changes (priority shifts, estimate adjustments,
    due date changes)
  - Time-vs-progress analysis (e.g., "12h logged over 3 days but only 2 of 8
    checklist items completed; may need scope review")
  - Decisions between alternatives you considered
  - Blockers or scope changes not obvious from individual tool calls
  Skip routine progress that the report already captures.
  Do NOT embed observations in the report text — always use the tool.
- **Observation priority and category**: When recording observations, assign
  the appropriate priority and category:
  - Use priority "critical" + category "grievance" for ANY expression of user
    frustration, disappointment, or dissatisfaction — even mild complaints.
    Write a full paragraph (3-5 sentences) capturing what happened, what went
    wrong, why it matters, and what should change.
  - Use priority "critical" + category "excellence" when the user explicitly
    praises a specific behavior or outcome.
  - Use priority "critical" + category "template_improvement" when the user
    suggests how you should behave differently.
  - Use priority "notable" for recurring patterns or anomalies.
  - Default to priority "routine" + category "operational" for standard notes.
  When you detect a grievance signal (frustration, "you should have...",
  "why didn't you...", corrections, re-stating requests), record it
  IMMEDIATELY as a critical observation before continuing with other work.
- **Links in reports**: NEVER link to linked tasks (parent, child,
  follow-up) in the report. They are already shown in a dedicated UI
  section. Never use internal task IDs or shortened hashes as link targets
  — they cannot be opened and are meaningless to the user. Only include
  real external URLs (GitHub PRs, issues, documentation, etc.).
  When referencing a linked task by name, use plain text, not a link.
- **Title**: Only set the title when the task has no title yet. Do not
  change an existing title unless the user explicitly asks for it.
- **Estimates**: Only set or update an estimate when the user explicitly
  requests it, or when no estimate exists and you have high confidence.
  Do not retroactively adjust estimates based on time already spent
  unless specifically asked to do so.
- **Status**: Do NOT call `set_task_status` if the task is already at the
  target status. Only transition when there is clear evidence of a change:
  - Set "IN PROGRESS" when time is being logged on the task (especially
    combined with checklist items being checked off).
  - Set "BLOCKED" when the user mentions a blocker (always provide a reason).
  - Set "ON HOLD" when work is intentionally paused (always provide a reason).
  - DONE and REJECTED are user-only — never set these.
  - Do NOT set status speculatively or based on assumptions.
- **Language**: Always write your report and TLDR in the language specified by
  the task's `languageCode` field (e.g. "de" → German, "fr" → French).
  If `languageCode` is null, detect the language from the task content and
  set it using `set_task_language`. Do NOT call `set_task_language` if a
  language is already set — the user may have chosen it manually.
- **Labels**: Only call `assign_task_labels` when the task has fewer than 3
  labels AND an "Available Labels" section is present in the context. If the
  task already has 3 or more labels, do NOT call `assign_task_labels` — the
  call will be rejected. Order by confidence (highest first), omit low
  confidence, cap at 3 per call. Never propose suppressed labels.
- **Checklist sovereignty**: Checklist items track who last toggled them
  (user or agent) and when (checkedAt). Rules:
  - If YOU (the agent) last set the item, you can freely change it.
  - If the USER last set the item, you must NOT change its checked state
    UNLESS you have clear evidence from journal entries, recordings, or
    notes that are timestamped AFTER the user's checkedAt time.
  - Absence of evidence is NOT grounds for unchecking. The user may have
    completed the task outside the app.
  - When overriding a user-set item, you MUST provide a "reason" field in
    the tool call explaining what post-dated evidence justifies the change.
    Without a reason, the system will reject the isChecked change.
  - Title updates (fixing typos, transcription errors) are always allowed
    regardless of who last toggled the item.

- **Task splitting**: When a user describes follow-up tasks in audio or notes —
  especially when referencing specific checklist items to move — use the split
  workflow:
  1. Call `create_follow_up_task` with the identified title, due date (if
     mentioned), and priority. The system creates the follow-up task, links it
     to the current task, and returns a placeholder `targetTaskId`.
  2. Call `migrate_checklist_items` with the checklist item IDs and titles to
     move, plus the `targetTaskId` from step 1.
  3. Record an observation about the split rationale.
  - Only split when the user clearly describes a separate task. Do not
    proactively suggest splits based on task size alone.
  - When unsure which items to move, err on the side of moving fewer items.
    The user can always move more later.
  - Priority defaults to P2 if not mentioned. The new task inherits the
    source task's category automatically.

## Suggestion Hygiene

Every wake you are shown a `## Proposal Ledger` listing every suggestion
you have ever produced for this task, including its current status. Use it
to keep the user-facing suggestion list clean and trustworthy:

1. **Never duplicate an open proposal.** Before proposing a deferred
   action, scan the Open group in the ledger. If an identical proposal
   is already open, do NOT propose it again.
2. **Retract stale open proposals.** If an open proposal is no longer
   relevant — for example the current task state already matches it
   (`priority` is already `P1`), the user made the change manually, or
   it duplicates another open proposal you want to keep — call
   `retract_suggestions` with the item's `fp=…` fingerprint and a short
   one-sentence reason. The user is NOT prompted; the item simply
   disappears from the active suggestion list and is recorded as
   retracted in the ledger. Retraction is not a failure; it is how you
   keep the user's trust in your proposals.
3. **Do not re-propose rejected or retracted items** unless the task
   context has materially changed. When you do re-propose after a
   rejection/retraction, justify the decision in your report.

## Important

- You observe journal-domain data but do not own it.
- Your report and observations are your persistent memory across wakes.
- Be concise. Focus on what changed and what matters.
''';

  /// Builds the user message for a wake cycle.
  Future<String> _buildUserMessage({
    required String agentId,
    required AgentReportEntity? lastReport,
    required List<AgentMessageEntity> journalObservations,
    required String taskDetailsJson,
    required String projectContextJson,
    required String linkedTasksJson,
    required Set<String> triggerTokens,
    required String taskId,
    ProposalLedger ledger = const ProposalLedger.empty(),
  }) async {
    final buffer = StringBuffer();

    if (lastReport != null && lastReport.content.isNotEmpty) {
      buffer
        ..writeln('## Current Report')
        ..writeln(lastReport.content)
        ..writeln();
    } else {
      buffer
        ..writeln(
          '## First Wake — No prior report exists. '
          'Produce an initial report.',
        )
        ..writeln();
    }

    if (journalObservations.isNotEmpty) {
      // Cap to most recent 20 to prevent unbounded context growth.
      // journalObservations is ordered newest-first from the DB query.
      final boundedObservations = journalObservations.length > 20
          ? journalObservations.sublist(0, 20)
          : journalObservations;

      // Batch-resolve all observation payloads in parallel to avoid N+1
      // queries. Used for both the critical section and the journal listing.
      final allPayloads = await _resolveObservationPayloads(
        boundedObservations,
      );

      // Inject prior critical observations first so the agent addresses
      // grievances and excellence notes before routine work.
      _writePriorCriticalObservations(
        buffer,
        boundedObservations,
        allPayloads,
      );

      buffer.writeln('## Agent Journal');
      // Reverse so the LLM sees them in chronological order.
      final recentObs = boundedObservations.reversed.toList();

      for (var i = 0; i < recentObs.length; i++) {
        final payload = recentObs[i].contentEntryId != null
            ? allPayloads[recentObs[i].contentEntryId]
            : null;
        final text = _extractPayloadText(payload);
        buffer.writeln(
          '- [${recentObs[i].createdAt.toIso8601String()}] $text',
        );
      }
      buffer.writeln();
    }

    buffer
      ..writeln('## Current Task Context')
      ..writeln('```json')
      ..writeln(taskDetailsJson)
      ..writeln('```')
      ..writeln();

    if (projectContextJson.isNotEmpty && projectContextJson != '{}') {
      buffer
        ..writeln('## Parent Project Context')
        ..writeln('```json')
        ..writeln(projectContextJson)
        ..writeln('```')
        ..writeln();
    }

    if (linkedTasksJson.isNotEmpty && linkedTasksJson != '{}') {
      buffer
        ..writeln('## Linked Tasks')
        ..writeln('```json')
        ..writeln(linkedTasksJson)
        ..writeln('```')
        ..writeln();
    }

    // Inject label context and correction examples.
    try {
      final taskEntity = await journalDb.journalEntityById(taskId);
      if (taskEntity is Task) {
        // Label context for the assign_task_labels tool.
        final labelContext = await TaskLabelHandler.buildLabelContext(
          task: taskEntity,
          journalDb: journalDb,
        );
        if (labelContext.isNotEmpty) {
          buffer.write(labelContext);
        }

        // Correction examples for checklist item title accuracy.
        final correctionContext = await CorrectionExamplesBuilder.buildContext(
          task: taskEntity,
          journalDb: journalDb,
        );
        if (correctionContext.isNotEmpty) {
          buffer.write(correctionContext);
        }
      }
    } catch (e, s) {
      _logError(
        'failed to build label/correction context',
        error: e,
        stackTrace: s,
      );
      // Non-fatal: continue without context.
    }

    // Proposal ledger — a single status-sorted view of every suggestion the
    // agent has ever produced for this task. Supersedes the older split
    // between "recent user decisions" and "pending proposals": both are now
    // different status slices of the same ledger, so the agent can reason
    // about its own history without duplicated or conflicting sections.
    if (!ledger.isEmpty) {
      buffer.writeln(_formatProposalLedger(ledger));
    }

    if (triggerTokens.isNotEmpty) {
      buffer
        ..writeln('## Changed Since Last Wake')
        ..writeln(
          'The following entity IDs changed: ${triggerTokens.join(", ")}',
        )
        ..writeln();
    }

    buffer.writeln(
      'Analyze the current state, call tools if needed, then call '
      '`update_report` with the full updated report. '
      'Add observations if warranted.',
    );

    return buffer.toString();
  }

  /// Formats the [ProposalLedger] into a single markdown section the agent
  /// consumes during a wake.
  ///
  /// The ledger is the agent's memory of its own suggestions for this task.
  /// Open entries carry fingerprints so the agent can call
  /// `retract_suggestions` with those fingerprints when a proposal is no
  /// longer relevant. Resolved entries show user verdicts (confirmed /
  /// rejected / deferred) and the agent's own retractions so the agent
  /// avoids repeating patterns the user has already rejected.
  String _formatProposalLedger(ProposalLedger ledger) {
    if (ledger.isEmpty) return '';

    final buffer = StringBuffer()
      ..writeln('## Proposal Ledger')
      ..writeln()
      ..writeln(
        'This is a complete record of suggestions you have produced for this '
        'task. Do not re-propose an identical OPEN item. If an OPEN item is '
        'no longer relevant (the current task state already matches it, or '
        'it duplicates another open proposal), call `retract_suggestions` '
        'with its fingerprint. For RESOLVED items, learn from the verdict: '
        'do not re-propose rejected items unless the task context has '
        'materially changed.',
      )
      ..writeln()
      ..writeln('### Open (${ledger.open.length})')
      ..writeln(
        ledger.open.isEmpty
            ? '- (none)'
            : ledger.open
                  .map(
                    (e) =>
                        '- [fp=${e.fingerprint}] `${e.toolName}`: '
                        '${e.humanSummary.trim()}',
                  )
                  .join('\n'),
      )
      ..writeln();

    if (ledger.resolved.isNotEmpty) {
      buffer.writeln('### Resolved (${ledger.resolved.length}, most recent)');
      for (final e in ledger.resolved) {
        final icon = switch (e.verdict) {
          ChangeDecisionVerdict.confirmed => '\u2713',
          ChangeDecisionVerdict.rejected => '\u2717',
          ChangeDecisionVerdict.deferred => '\u23f8',
          ChangeDecisionVerdict.retracted => '\u21ba',
          null => '\u25cb',
        };
        final verdictLabel = e.verdict?.name ?? e.status.name;
        final actorLabel = switch (e.resolvedBy) {
          DecisionActor.user => ' by user',
          DecisionActor.agent => ' by agent',
          null => '',
        };
        final summary = e.humanSummary.trim();
        final trimmedReason = e.reason?.trim();
        final reasonSuffix = (trimmedReason != null && trimmedReason.isNotEmpty)
            ? ' (reason: "$trimmedReason")'
            : '';
        buffer.writeln(
          '- [fp=${e.fingerprint}] $icon `${e.toolName}`: $summary '
          '— $verdictLabel$actorLabel$reasonSuffix',
        );
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Builds linked-task context JSON for the wake prompt.
  ///
  /// Forked from [AiInputRepository.buildLinkedTasksJson] for the task-agent
  /// wake path:
  /// 1. Builds linked task context directly from linked task entities.
  /// 2. Removes legacy `latestSummary` fields.
  /// 3. Injects the latest task-agent report for each linked task when present.
  ///
  /// This keeps prompt context aligned with the Agent Capabilities architecture
  /// where task summaries are being phased out in favor of task-agent reports.
  Future<String> _buildLinkedTasksContextJson(String taskId) async {
    try {
      final linkedFrom = await aiInputRepository.buildLinkedFromContext(taskId);
      final linkedTo = await aiInputRepository.buildLinkedToContext(taskId);

      final linkedFromRows = linkedFrom
          .map((context) => Map<String, dynamic>.from(context.toJson()))
          .toList();
      final linkedToRows = linkedTo
          .map((context) => Map<String, dynamic>.from(context.toJson()))
          .toList();
      final allRows = [...linkedFromRows, ...linkedToRows];

      if (allRows.isEmpty) {
        return '{}';
      }

      for (final row in allRows) {
        row.remove('latestSummary');
      }

      final taskIds = allRows
          .map((row) => row['id'])
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final reportByTaskId = <String, _LinkedTaskAgentReport?>{};
      await Future.wait(
        taskIds.map((id) async {
          reportByTaskId[id] = await _resolveLatestTaskAgentReport(id);
        }),
      );

      for (final row in allRows) {
        final linkedTaskId = row['id'];
        if (linkedTaskId is! String || linkedTaskId.isEmpty) {
          continue;
        }

        final linkedReport = reportByTaskId[linkedTaskId];
        if (linkedReport == null) {
          continue;
        }

        row['taskAgentId'] = linkedReport.agentId;
        row['latestTaskAgentReport'] = linkedReport.content;
        row['latestTaskAgentReportCreatedAt'] = linkedReport.createdAt
            .toIso8601String();
      }

      return const JsonEncoder.withIndent('    ').convert(<String, dynamic>{
        'linked_from': linkedFromRows,
        'linked_to': linkedToRows,
      });
    } catch (e, stackTrace) {
      _logError(
        'failed to build linked tasks context',
        error: e,
        stackTrace: stackTrace,
      );
      return '{}';
    }
  }

  Future<_LinkedTaskAgentReport?> _resolveLatestTaskAgentReport(
    String linkedTaskId,
  ) async {
    try {
      final links = await agentRepository.getLinksTo(
        linkedTaskId,
        type: AgentLinkTypes.agentTask,
      );
      if (links.isEmpty) {
        return null;
      }

      final sortedLinks = links.toList()
        ..sort((a, b) {
          final byCreatedAt = b.createdAt.compareTo(a.createdAt);
          if (byCreatedAt != 0) return byCreatedAt;
          return b.id.compareTo(a.id);
        });

      for (final link in sortedLinks) {
        final report = await agentRepository.getLatestReport(
          link.fromId,
          AgentReportScopes.current,
        );
        if (report == null) {
          continue;
        }
        final content = report.content.trim();
        if (content.isEmpty) {
          continue;
        }
        return _LinkedTaskAgentReport(
          agentId: link.fromId,
          content: content,
          createdAt: report.createdAt,
        );
      }
      return null;
    } catch (e, s) {
      _logError(
        'failed to resolve linked task-agent report',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  /// Batch-resolves all observation payloads into a map keyed by payload ID.
  Future<Map<String, AgentMessagePayloadEntity>> _resolveObservationPayloads(
    List<AgentMessageEntity> observations,
  ) async {
    final payloadIds = observations
        .map((o) => o.contentEntryId)
        .whereType<String>()
        .toSet();

    final entries = await Future.wait(
      payloadIds.map((id) async {
        try {
          final entity = await agentRepository.getEntity(id);
          if (entity is AgentMessagePayloadEntity) {
            return MapEntry(id, entity);
          }
        } catch (e) {
          // Non-fatal — observation will render with placeholder text.
        }
        return null;
      }),
    );

    return {
      for (final entry
          in entries.whereType<MapEntry<String, AgentMessagePayloadEntity>>())
        entry.key: entry.value,
    };
  }

  /// Extracts the text content from an observation payload.
  static String _extractPayloadText(AgentMessagePayloadEntity? payload) {
    if (payload == null) return '(no content)';
    final text = payload.content['text'];
    if (text is String && text.isNotEmpty) return text;
    return '(no content)';
  }

  /// Writes a dedicated section for prior critical observations so the
  /// task agent can self-correct on grievances and reinforce excellence.
  static void _writePriorCriticalObservations(
    StringBuffer buffer,
    List<AgentMessageEntity> observations,
    Map<String, AgentMessagePayloadEntity> payloads,
  ) {
    final grievances = <(DateTime, String)>[];
    final excellence = <(DateTime, String)>[];

    for (final obs in observations) {
      final payload = obs.contentEntryId != null
          ? payloads[obs.contentEntryId]
          : null;
      if (payload == null) continue;

      final rawPriority = payload.content['priority'];
      final priority = rawPriority is String
          ? parseEnumByName(ObservationPriority.values, rawPriority)
          : null;
      if (priority != ObservationPriority.critical) continue;

      final text = payload.content['text'];
      if (text is! String || text.trim().isEmpty) continue;

      final rawCategory = payload.content['category'];
      final category = rawCategory is String
          ? parseEnumByName(ObservationCategory.values, rawCategory)
          : null;
      if (category == ObservationCategory.excellence) {
        excellence.add((obs.createdAt, text));
      } else {
        // grievance, template_improvement, or unrecognized critical
        grievances.add((obs.createdAt, text));
      }
    }

    if (grievances.isEmpty && excellence.isEmpty) return;

    buffer
      ..writeln('## Prior Critical Observations (Self-Review)')
      ..writeln(
        'The following critical observations were recorded in your previous '
        'wakes. Review them and adjust your behavior accordingly.',
      )
      ..writeln();

    if (grievances.isNotEmpty) {
      buffer.writeln('### Grievances');
      for (final (timestamp, text) in grievances) {
        buffer.writeln('- [${timestamp.toIso8601String()}] $text');
      }
      buffer.writeln();
    }

    if (excellence.isNotEmpty) {
      buffer.writeln('### Excellence (keep doing this)');
      for (final (timestamp, text) in excellence) {
        buffer.writeln('- [${timestamp.toIso8601String()}] $text');
      }
      buffer.writeln();
    }
  }

  /// Converts [AgentToolRegistry.taskAgentTools] to OpenAI-compatible
  /// [ChatCompletionTool] objects.
  List<ChatCompletionTool> _buildToolDefinitions() {
    return AgentToolRegistry.taskAgentTools.where((def) => def.enabled).map((
      def,
    ) {
      return ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: def.name,
          description: def.description,
          parameters: def.parameters,
        ),
      );
    }).toList();
  }

  /// Extracts the final assistant text content from the conversation manager.
  String? _extractFinalAssistantContent(ConversationManager? manager) {
    if (manager == null) return null;

    // Walk backwards through messages to find the last assistant message
    // with text content (not a tool-call-only message).
    for (final message in manager.messages.reversed) {
      if (message case ChatCompletionMessage(
        role: ChatCompletionMessageRole.assistant,
      )) {
        final content = message.mapOrNull(
          assistant: (m) => m.content,
        );
        if (content != null && content.isNotEmpty) {
          return content;
        }
      }
    }
    return null;
  }
}

class _LinkedTaskAgentReport {
  const _LinkedTaskAgentReport({
    required this.agentId,
    required this.content,
    required this.createdAt,
  });

  final String agentId;
  final String content;
  final DateTime createdAt;
}

/// Resolved template and version pair for prompt composition.
class _TemplateContext {
  _TemplateContext({
    required this.template,
    required this.version,
    this.soulVersion,
  });

  final AgentTemplateEntity template;
  final AgentTemplateVersionEntity version;

  /// Active soul version for this template, if a soul is assigned.
  final SoulDocumentVersionEntity? soulVersion;
}
