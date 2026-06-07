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
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/decision_events.dart';
import 'package:lotti/features/agents/service/agent_log_llm_summarizer.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/attention_claim_maintenance_service.dart';
import 'package:lotti/features/agents/service/change_set_notification_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/service/suggestion_retraction_service.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/sync/agent_input_capture_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/correction_examples_builder.dart';
import 'package:lotti/features/agents/tools/task_label_handler.dart';
import 'package:lotti/features/agents/workflow/agent_wake_memory.dart';
import 'package:lotti/features/agents/workflow/change_proposal_filter.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:lotti/features/agents/workflow/prompt_record.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/task_source_renderer.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/model/ai_chat_message.dart';
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
import 'package:uuid/uuid.dart';

export 'package:lotti/features/agents/workflow/wake_result.dart';

part 'task_agent_context_builder.dart';
part 'task_agent_persistence_helpers.dart';
part 'task_agent_prompt_builder.dart';

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
    this.changeSetNotificationService,
    this.inputCaptureService,
    this.logSummarizer,
    this.compactionTailBudgetTokens = 50000,
    this.compactionTailRetainTokens = 20000,
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

  /// Optional bridge that keeps task-suggestion notifications aligned with
  /// agent change-set resolution.
  final ChangeSetNotificationService? changeSetNotificationService;

  /// Optional input-capture service (ADR 0020). When present, each wake
  /// snapshots the user-content sources it read (per-source, content-addressed)
  /// into the append-only log, so the agent's inputs become a projection of the
  /// log rather than a live journal read. Null disables capture (unit tests
  /// that don't exercise it); production wires it in `agent_workflow_providers`.
  final AgentInputCaptureService? inputCaptureService;

  /// Optional LLM summarizer used by compaction to distill folded input
  /// sources (ADR 0017), invoked with the wake's resolved model/provider.
  /// Required to actually emit summaries; null leaves emission inert while
  /// reads still assemble the captured event tail.
  final AgentLogLlmSummarizer? logSummarizer;

  /// Token budget for the verbatim uncovered tail before compaction folds its
  /// oldest entries (ADR 0017). This is the *trigger* (high watermark): no
  /// summarization happens while the tail fits it.
  ///
  /// Sized generously (50k) because the tail is append-only and therefore
  /// prefix-cached: warm wakes pay cache-read rates (or, on local inference
  /// with a persistent KV cache, nothing) for the history. The remaining real
  /// costs are the cold prefill on the first wake of a session and attention
  /// quality on very long raw logs — which is why the fold still exists at
  /// all rather than the tail growing without bound. Deployments on
  /// small-context/local models can pass tighter values here.
  final int compactionTailBudgetTokens;

  /// Low watermark for the fold (hysteresis): once
  /// [compactionTailBudgetTokens] is exceeded, the tail is folded down so only
  /// this many tokens of the most recent verbatim entries remain — leaving
  /// `budget - retain` tokens of headroom before the next summarization. Keeps
  /// the summarizer infrequent (one fold per ~30k tokens of NEW activity at
  /// the defaults) and the prompt's summary block stable between folds
  /// (prefix-cache friendly).
  final int compactionTailRetainTokens;

  /// How many resolved proposal verdicts the wake projects into the event
  /// substrate (and the legacy ledger view). Sized far above any realistic
  /// per-task verdict count — each one is a human confirmation click — and
  /// saturation is logged loudly rather than silently truncating.
  static const resolvedDecisionWindow = 500;

  static const _uuid = Uuid();

  void _log(String message, {String? subDomain}) {
    domainLogger?.log(
      LogDomain.agentWorkflow,
      message,
      subDomain: subDomain,
    );
  }

  void _logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (domainLogger != null) {
      domainLogger!.error(
        LogDomain.agentWorkflow,
        error ?? message,
        message: error != null ? message : null,
        stackTrace: stackTrace,
      );
    } else {
      developer.log(
        '$message${error != null ? ' (errorType=${error.runtimeType})' : ''}',
        name: 'TaskAgentWorkflow',
        error: error?.runtimeType,
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

    // 1. Load current state + both memory types. The wake acts on the
    // log-reconciled state (PR 4 B6), so a watermark/slot the cache lost to LWW
    // self-heals before the agent decides anything.
    final state = await syncService.reconciledAgentState(agentId);
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

    // Capture timestamp once for the whole wake so all writes share causality.
    final now = clock.now();

    // 1a. Capture this wake's user-content sources into the log (ADR 0020),
    // per-source and content-addressed, BEFORE assembly so the input frontier
    // reflects the latest content. Non-fatal: a capture failure must not abort.
    final memory = AgentWakeMemory(
      syncService: syncService,
      inputCaptureService: inputCaptureService,
      logSummarizer: logSummarizer,
      domainLogger: domainLogger,
    );
    var captureSucceeded = false;
    if (inputCaptureService != null) {
      try {
        final linked = await journalDb.getLinkedEntities(taskId);
        captureSucceeded = await memory.capture(
          agentId: agentId,
          sources: renderTaskSources(
            linked,
            // A running timer's duration is still ticking; capturing it would
            // mint a new content version every wake (see renderTaskSources).
            runningEntryId: getIt<TimeService>().getCurrent()?.meta.id,
          ),
          at: now,
          threadId: threadId,
          runKey: runKey,
        );
      } catch (e) {
        // Source rendering failed (the capture call itself absorbs its own
        // errors inside [AgentWakeMemory.capture]).
        _logError('failed to capture wake inputs', error: e);
      }
    }

    // 2. Resolve the agent's template and active version. (Resolved before
    // compaction so the summarizer can use the wake's own model.)
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

    // 3. Resolve inference profile (or legacy modelId) → provider.
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

    // One ledger fetch feeds the compactor's decision events (below), the
    // LLM prompt (open proposals + legacy resolved view) and the
    // ChangeSetBuilder (open pending sets for cross-wake dedup).
    final ledger = await agentRepository.getProposalLedger(
      agentId,
      taskId: taskId,
      resolvedLimit: resolvedDecisionWindow,
    );
    if (ledger.resolved.length >= resolvedDecisionWindow) {
      // No silent caps: beyond the window, the oldest UNFOLDED verdicts
      // would leave the event substrate before being summarized (folded
      // verdicts stay provably covered via the checkpoint's coveredSources).
      _log(
        'resolved-decision window saturated '
        '(${ledger.resolved.length} >= $resolvedDecisionWindow): oldest '
        'unfolded verdicts may drop from the event tail',
        subDomain: 'compaction',
      );
    }

    // 1b. Compaction (ADR 0017) — the shared per-wake memory pipeline: flag
    // read fresh each wake, fold past the trigger watermark with the wake's
    // resolved model, assemble the compacted log, evaluate the read-flip
    // gates. Resolved proposal verdicts join the event substrate as inline
    // events — they interleave chronologically with the content that
    // motivated them and fold into summaries, instead of being re-rendered
    // (and eventually capped away) in a separate prompt section every wake.
    final memoryView = await memory.compactAndAssemble(
      agentId: agentId,
      captureSucceeded: captureSucceeded,
      model: modelId,
      provider: provider,
      at: now,
      threadId: threadId,
      runKey: runKey,
      budget: compactionTailBudgetTokens,
      retainTokens: compactionTailRetainTokens,
      inlineEvents: decisionEventsFromLedger(ledger.resolved),
    );
    final compactedTaskLog = memoryView.compactedLog;
    final useCompactedLog = memoryView.useCompactedLog;

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
    // With compaction on, the inline log entries are dropped from the task
    // header and supplied instead as `active summary + uncovered tail` from
    // the captured log (the read-flip).
    final (
      taskDetails,
      projectContextJson,
      linkedTasksJson,
    ) = await (
      // Compacted wakes get the task STATE as compact markdown (the log is
      // event material supplied separately); legacy wakes keep the full JSON
      // header with the inline log entries.
      useCompactedLog
          ? aiInputRepository.buildTaskStateMarkdown(taskId)
          : aiInputRepository.buildTaskDetailsJson(id: taskId),
      aiInputRepository.buildProjectContextJsonForTask(taskId),
      _buildLinkedTasksContextJson(taskId),
    ).wait;

    if (taskDetails == null) {
      _log('task not found in journal — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'Task not found');
    }
    final taskAttentionContext = await _maintainAndLoadAttentionClaims(
      agentId: agentId,
      taskId: taskId,
    );

    // 5. Assemble conversation context (the ledger was fetched before
    // compaction, which consumes its resolved entries as decision events).
    final pendingSets = ledger.pendingSets;

    final systemPrompt = _buildSystemPrompt(templateCtx);
    final builtMessage = await _buildUserMessage(
      agentId: agentId,
      hasReport: lastReport != null,
      journalObservations: journalObservations,
      taskDetails: taskDetails,
      projectContextJson: projectContextJson,
      linkedTasksJson: linkedTasksJson,
      triggerTokens: triggerTokens,
      taskId: taskId,
      ledger: ledger,
      attentionClaims: taskAttentionContext.claims,
      task: taskAttentionContext.task,
      timeService: getIt<TimeService>(),
      // Only attach the compacted log when we're actually using it (the inline
      // log was dropped); otherwise the full inline log already carries it.
      compactedTaskLog: useCompactedLog ? compactedTaskLog : null,
    );
    final userMessage = builtMessage.text;

    // 6. Create conversation and run with strategy.
    final conversationId = conversationRepository.createConversation(
      systemMessage: systemPrompt,
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

    // 6a. Persist the prompts for inspectability before sending to the LLM.
    // The system prompt is content-addressed: one payload per DISTINCT prompt
    // text (it only changes when the template/soul/scaffold change, so storage
    // does not grow per wake), referenced from each wake by a `system` message
    // with a `contentEntryId` so the conversation view can expand it. In the
    // actual LLM request the system prompt is always messages[0] — this row is
    // audit/inspection only.
    try {
      final systemPromptContent = <String, Object?>{
        'role': 'system',
        'text': systemPrompt,
      };
      final systemPromptPayloadId = ContentDigest.of(systemPromptContent);
      if (await agentRepository.getEntity(systemPromptPayloadId) == null) {
        await syncService.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: systemPromptPayloadId,
            agentId: AgentInputCaptureService.sharedContentAgentId,
            createdAt: now,
            vectorClock: null,
            content: systemPromptContent,
          ),
        );
      }
      // NB: a `system` message WITH a contentEntryId is how the conversation
      // UI identifies the prompt row (`_displayRank` ordering and the
      // "System Prompt" badge both key on it) — keep `system`-kind
      // bookkeeping rows (milestones, retractions) payload-free.
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: _uuid.v4(),
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.system,
          createdAt: now,
          vectorClock: null,
          contentEntryId: systemPromptPayloadId,
          metadata: AgentMessageMetadata(runKey: runKey),
        ),
      );
    } catch (e) {
      _logError('failed to persist system prompt', error: e);
      // Non-fatal: continue with execution even if audit fails.
    }
    try {
      final userPayloadId = _uuid.v4();
      // ADR 0020 v2 prompt records: when the read flipped, the embedded log
      // block is a pure function of the synced event log — store only the
      // non-derivable halves plus the reconstruction marker, instead of the
      // whole prompt. Legacy wakes (live journal render) keep the full blob.
      final logStart = builtMessage.logStart;
      final logEnd = builtMessage.logEnd;
      final userPayloadContent = (logStart != null && logEnd != null)
          ? encodePromptRecord(
              head: userMessage.substring(0, logStart),
              tail: userMessage.substring(logEnd),
              summaryId: memoryView.activeSummaryId,
              until: memoryView.lastEventPosition,
            )
          : <String, Object?>{'text': userMessage};
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: userPayloadId,
          agentId: agentId,
          createdAt: now,
          vectorClock: null,
          content: userPayloadContent,
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
        agentRepository: agentRepository,
        syncService: syncService,
        requestingAgentId: agentId,
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
              isArchived: entity.data.isArchived,
            );
          }
          return null;
        },
        existingChecklistTitlesResolver: () async {
          final entity = await journalDb.journalEntityById(taskId);
          if (entity is! Task) return {};
          final items = await checklistRepository.getChecklistItemsForTask(
            task: entity,
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

      final retractionService = SuggestionRetractionService(
        syncService: syncService,
        domainLogger: domainLogger,
        onChangeSetRetracted:
            changeSetNotificationService?.syncAfterAgentRetraction,
      );

      final strategy = TaskAgentStrategy(
        executor: executor,
        syncService: syncService,
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        taskId: taskId,
        changeSetBuilder: changeSetBuilder,
        retractionService: retractionService,
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
        geminiThinkingMode: resolvedProfile.thinkingModel?.geminiThinkingMode,
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

      // 7b. Forced-report retry — only to bootstrap the FIRST report. Once a
      // report exists, skipping `update_report` is a legitimate "nothing
      // materially changed" outcome, not a contract violation.
      if (lastReport == null && strategy.extractReportContent().isEmpty) {
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
      if (reportContent.isEmpty && lastReport == null) {
        // Only the FIRST report is mandatory; afterwards an empty report
        // means "nothing materially changed" and the prior one stands.
        _log(
          'no initial report published despite forced retry',
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

        // 10a. Apply any retractions the agent staged during the conversation.
        // Deferred to here — and run before the build below — so the retraction
        // and the new proposals commit in one transaction. Persisting
        // retractions mid-conversation (their old behavior) emptied the
        // suggestion list for the seconds until this end-of-wake build landed
        // the replacements; staging closes that gap. Running before build also
        // lets the builder's dedup see the freshly-retracted statuses.
        //
        // Churn guard: weaker models routinely retract an open proposal AND
        // re-propose an identical one in the same wake. That retract-then-re-add
        // makes a stable suggestion vanish and reappear under the user's finger
        // (and, when the user has just confirmed a sibling, looks like accepting
        // one wipes the rest). Suppress retractions of anything being
        // re-proposed this wake; the matching new proposal is then dropped by
        // the builder's dedup against the still-open original, leaving it
        // untouched.
        await retractionService.applyStaged(
          strategy.extractStagedRetractions(),
          skipFingerprints: changeSetBuilder.proposedFingerprints,
        );

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
        final rejectedDisplayKeys = {
          for (final entry in ledger.resolved)
            if (entry.verdict == ChangeDecisionVerdict.rejected)
              if (ChangeItem.displayDuplicateKeyFromParts(
                    entry.toolName,
                    entry.humanSummary,
                    args: entry.args,
                  )
                  case final String key)
                key,
        };

        await changeSetBuilder.build(
          syncService,
          existingPendingSets: pendingSets,
          rejectedFingerprints: rejectedFingerprints,
          rejectedDisplayKeys: rejectedDisplayKeys,
        );

        // 11. Persist state.
        final hostId = await syncService.localHost();
        await syncService.upsertEntity(
          state.copyWith(
            lastWakeAt: now,
            updatedAt: now,
            consecutiveFailureCount: 0,
            wakeCounter: state.wakeCounter.increment(hostId),
          ),
        );

        // 12. Event-source the `lastWakeAt` watermark: emit a milestone marker
        // whose createdAt the projection folds as the watermark (PR 4, B2). The
        // cached row above stays the read source until the cutover (B6).
        await syncService.appendMilestone(
          agentId: agentId,
          milestone: AgentMilestone.wakeCompleted,
          createdAt: now,
          threadId: threadId,
          runKey: runKey,
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
    required List<AiTool> tools,
    required TaskAgentStrategy strategy,
  }) async {
    _log(
      'no report published — retrying with forced update_report',
      subDomain: 'execute',
    );
    const forcedToolChoice = AiToolChoiceFunction(
      TaskAgentStrategy.reportToolName,
    );
    final reportOnlyTools = tools
        .where((tool) => tool.name == TaskAgentStrategy.reportToolName)
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
}

class _LinkedTaskAgentReport {
  const _LinkedTaskAgentReport({
    required this.agentId,
    required this.oneLiner,
    required this.tldr,
    required this.createdAt,
  });

  final String agentId;
  final String? oneLiner;
  final String? tldr;
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
