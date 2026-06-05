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
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/decision_events.dart';
import 'package:lotti/features/agents/service/agent_log_llm_summarizer.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
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

        await changeSetBuilder.build(
          syncService,
          existingPendingSets: pendingSets,
          rejectedFingerprints: rejectedFingerprints,
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

## Finishing a Wake

A wake ends in exactly one of two ways:
- the task changed materially since the last published report → end with a
  single `update_report` tool call carrying the full updated report
  (`oneLiner`, `tldr`, and `content`); or
- nothing report-worthy changed → end with a brief plain-text note of what
  you checked or did. Do NOT call `update_report` just to re-publish
  unchanged content — the report is derived from the task log, not per-wake
  ceremony, and re-publishing identical content wastes the user's attention.

If no report has ever been published for this task, publish the first one.

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
4. FINAL STEP — publish the full updated report via `update_report` when it
   would materially change (always last), or finish with a brief plain-text
   note when it would not.''';

  /// Default report section of the scaffold, used when the template version
  /// does not provide its own `reportDirective`.
  static const taskAgentScaffoldReport = '''


## Report

When the report would materially change (and always when none exists yet),
call `update_report` exactly once, last, with the full updated report as
markdown. Provide `oneLiner`, `tldr`, and `content`. The report must follow
this standardized structure with emojis for visual consistency:

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
- Bare internal task IDs or shortened hashes as visible link text. When a
  provided task context includes a task ID and linking helps the user inspect
  proof of work, link the readable task title to `/tasks/<taskId>`. Keep the
  Links section for real external URLs (GitHub, Stack Overflow,
  documentation, etc.).

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
- **Duplicate checklist items**: when the checklist contains two items that
  mean the same thing, propose archiving the redundant one via
  `update_checklist_items` with `isArchived: true` (keep the better-phrased
  or user-created one). Never "fix" a duplicate by re-titling it, and never
  add an item that already exists.
- Only call tools when you have sufficient confidence in the change.
- Do not call tools speculatively or redundantly.
- **Batch independent calls**: when a wake warrants several updates that do not
  depend on each other (e.g., labels, priority, due date, estimate, checklist
  items), emit them as parallel tool calls in a single turn rather than one
  tool per turn — fewer turns is faster. `update_report` stays the separate,
  final step.
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
- **Links in reports**: When a linked task's ID is present in the provided
  context and a link would help the user inspect proof of work, format the
  readable task title as `[Task title](/tasks/<taskId>)`. Never use bare
  internal IDs or shortened hashes as visible link text, and never invent task
  IDs. Keep the dedicated Links section for real external URLs (GitHub PRs,
  issues, documentation, etc.).
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
   - For `update_running_timer`, keep exactly one open proposal. If you
     have a better timer description than an existing open
     `update_running_timer` proposal, retract the old proposal first and
     then propose the newer text.
2. **Retract an open proposal only when THAT proposal is itself stale.**
   Valid reasons: the current task state already satisfies it (`priority`
   is already `P1`), the user already made that exact change manually, or
   it duplicates another open proposal you are keeping. Call
   `retract_suggestions` with the item's `fp=…` fingerprint and a short
   one-sentence reason. The user is NOT prompted; the item disappears from
   the active suggestion list and is recorded as retracted in the ledger.
   Retraction is how you keep the user's trust — but only when the
   proposal is genuinely dead.
   - **Never retract a proposal just because the user acted on a
     DIFFERENT one.** Each open proposal stands on its own. When the user
     confirms or rejects one checklist item (or any single suggestion),
     the OTHER open proposals are still valid and the user may still want
     them — leave them alone. A partially-acted-on batch is normal, not a
     signal to withdraw the rest.
   - **Prefer leaving a good proposal in place over retract-and-re-add.**
     Do not retract an open proposal only to re-propose a near-identical
     one; the churn is worse than a slightly imperfect summary. (The one
     exception is the single-open-proposal rule for `update_running_timer`
     above.)
3. **Do not re-propose rejected or retracted items** unless the task
   context has materially changed. When you do re-propose after a
   rejection/retraction, justify the decision in your report.

## Important

- You observe journal-domain data but do not own it.
- Your report and observations are your persistent memory across wakes.
- Be concise. Focus on what changed and what matters.
''';

  /// Builds the user message for a wake cycle. [taskDetails] is the compact
  /// markdown task state when the read-flip succeeds, or the full JSON header
  /// (inline log included) for fallback prompts. [hasReport] gates the
  /// first-wake report bootstrap section; the prior report's prose is never
  /// injected.
  ///
  /// Returns the full text plus the offsets of the embedded (derivable) log
  /// block, so the persisted prompt record can store only the non-derivable
  /// halves (ADR 0020 v2 prompt records).
  Future<({String text, int? logStart, int? logEnd})> _buildUserMessage({
    required String agentId,
    required bool hasReport,
    required List<AgentMessageEntity> journalObservations,
    required String taskDetails,
    required String projectContextJson,
    required String linkedTasksJson,
    required Set<String> triggerTokens,
    required String taskId,
    ProposalLedger ledger = const ProposalLedger.empty(),
    TimeService? timeService,
    String? compactedTaskLog,
  }) async {
    final buffer = StringBuffer();

    // Ordering is by volatility, least-volatile first, so provider prefix
    // caches survive consecutive wakes: label / correction context,
    // parent-project + linked-task summaries (all rare-change), then the
    // compacted task log (append-only between folds), then the volatile tail
    // (task-state JSON with its ticking timeSpent, timer, report, journal,
    // ledger, trigger tokens). One flipped byte voids the cache for every
    // byte after it, so nothing per-wake-mutable may precede the log.

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

    final useCompactedLog =
        compactedTaskLog != null && compactedTaskLog.trim().isNotEmpty;

    int? logStart;
    int? logEnd;
    if (useCompactedLog) {
      // With compaction on (ADR 0017/0020), the task log is supplied as the
      // active summary + uncovered verbatim event tail from the captured log.
      // It is the largest stable block — the summary changes only at folds and
      // the tail is append-only between them — so it ends the stable prefix.
      // The task STATE moves BELOW it into the volatile tail: its time fields
      // tick on every working wake, and a single byte flipped upstream voids
      // the provider prefix cache for everything after it.
      buffer.writeln('## Task Log');
      logStart = buffer.length;
      buffer.write(compactedTaskLog);
      logEnd = buffer.length;
      buffer
        ..writeln()
        ..writeln();
    } else {
      buffer
        ..writeln('## Current Task Context')
        ..writeln('```json')
        ..writeln(taskDetails)
        ..writeln('```')
        ..writeln();
    }

    // --- Volatile tail: changes most across wakes, so it follows the stable
    // header above to keep that header byte-identical and prefix-cacheable. ---

    if (useCompactedLog) {
      buffer
        ..writeln('## Current Task Context')
        ..writeln(taskDetails)
        ..writeln();
    }

    final activeTimerSection = _buildActiveTimerSection(timeService, taskId);
    if (activeTimerSection.isNotEmpty) {
      buffer.write(activeTimerSection);
    }

    final editableTimeEntriesSection = await _buildEditableTimeEntriesSection(
      timeService,
      taskId,
    );
    if (editableTimeEntriesSection.isNotEmpty) {
      buffer.write(editableTimeEntriesSection);
    }

    // Proposal ledger. In compacted mode only the OPEN proposals render here
    // — they are current state (fingerprints for `retract_suggestions`,
    // same-wake dedup) — while resolved verdicts live in the `## Task Log`
    // as decision-tagged events that fold into summaries. Legacy mode keeps
    // the full status-sorted view including resolved history.
    if (!ledger.isEmpty) {
      buffer.writeln(
        _formatProposalLedger(ledger, includeResolved: !useCompactedLog),
      );
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

      // With compaction on, observations live in the `## Task Log` event tail
      // (interleaved as observation-tagged lines, folded into summaries by
      // the same watermarks) — a separate journal section would duplicate
      // them.
      if (!useCompactedLog) {
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
    }

    // The prior report's PROSE is deliberately NOT injected: the report is a
    // projection of the task log, not agent memory. Re-reading its own stale
    // conclusions as ground truth creates a feedback loop (a wrong "learning"
    // re-published verbatim every wake), and everything report-worthy is
    // already in the log, the observations, and the task state.
    if (!hasReport) {
      buffer
        ..writeln(
          '## First Wake — No prior report exists. '
          'Produce an initial report.',
        )
        ..writeln();
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
      'Analyze the current state and call tools if needed. If the report '
      'would materially change, call `update_report` with the full updated '
      'report; otherwise finish with a brief plain-text note. '
      'Add observations if warranted.',
    );

    return (text: buffer.toString(), logStart: logStart, logEnd: logEnd);
  }

  /// Formats the [ProposalLedger] into a single markdown section the agent
  /// consumes during a wake.
  ///
  /// The ledger is the agent's memory of its own suggestions for this task.
  /// Open entries carry fingerprints so the agent can call
  /// `retract_suggestions` with those fingerprints when a proposal is no
  /// longer relevant.
  ///
  /// [includeResolved] selects the legacy full view (resolved verdicts
  /// rendered here); with compaction on, resolved verdicts are
  /// decision-tagged events in the task log instead, so this section carries
  /// only the open (actionable) state.
  String _formatProposalLedger(
    ProposalLedger ledger, {
    required bool includeResolved,
  }) {
    if (ledger.isEmpty) return '';
    if (!includeResolved && ledger.open.isEmpty) return '';

    final buffer = StringBuffer()
      ..writeln('## Proposal Ledger')
      ..writeln()
      ..writeln(
        includeResolved
            ? 'This is a complete record of suggestions you have produced '
                  'for this task. Do not re-propose an identical OPEN item. '
                  'If an OPEN item is no longer relevant (the current task '
                  'state already matches it, or it duplicates another open '
                  'proposal), call `retract_suggestions` with its '
                  'fingerprint. For RESOLVED items, learn from the verdict: '
                  'do not re-propose rejected items unless the task context '
                  'has materially changed.'
            : 'These are your OPEN suggestions for this task. Do not '
                  're-propose an identical item. If one is no longer '
                  'relevant (the current task state already matches it, or '
                  'it duplicates another open proposal), call '
                  '`retract_suggestions` with its fingerprint. Past '
                  'verdicts appear as decision-tagged events in the Task Log: '
                  'learn from them and do not re-propose rejected items '
                  'unless the task context has materially changed.',
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

    if (includeResolved && ledger.resolved.isNotEmpty) {
      buffer.writeln('### Resolved (${ledger.resolved.length}, most recent)');
      for (final e in ledger.resolved) {
        buffer.writeln('- ${formatResolvedLedgerLine(e)}');
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
  /// 3. Injects a compact summary (oneLiner/tldr) of the latest task-agent
  ///    report for each linked task when present — not the full body, to keep
  ///    wake prefill small.
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

      // Two bulk queries replace the prior `Future.wait(map →
      // _resolveLatestTaskAgentReport(id))` fan-out. The fan-out hit
      // 2 203 `agent_links WHERE to_id = ? AND type = ?` queries plus
      // a compounding 2 484 `agent_entities WHERE id = ?` queries on
      // the 2026-05-10 desktop slow_queries log; each per-row request
      // queued independently behind the writer lock. The bulk path is
      // `getLinksToMultiple` + `getLatestReportsByAgentIds`, mirroring
      // the already-batched implementation in
      // `ProjectAgentWorkflow._buildLinkedTasksContext`.
      final reportByTaskId = <String, _LinkedTaskAgentReport>{};
      if (taskIds.isNotEmpty) {
        var linksByTaskId = const <String, List<AgentLink>>{};
        try {
          linksByTaskId = await agentRepository.getLinksToMultiple(
            taskIds.toList(),
            type: AgentLinkTypes.agentTask,
          );
        } catch (e, s) {
          _logError(
            'batch agent_task link lookup failed',
            error: e,
            stackTrace: s,
          );
        }

        final linkedAgentIds = linksByTaskId.values
            .expand((links) => links.map((link) => link.fromId))
            .toSet()
            .toList();

        var reportsByAgentId = const <String, AgentReportEntity>{};
        if (linkedAgentIds.isNotEmpty) {
          try {
            reportsByAgentId = await agentRepository.getLatestReportsByAgentIds(
              linkedAgentIds,
              AgentReportScopes.current,
            );
          } catch (e, s) {
            _logError(
              'batch agent report lookup failed',
              error: e,
              stackTrace: s,
            );
          }
        }

        // Sort matches the prior per-task `orderedPrimaryFirst` shape
        // (createdAt DESC, then id DESC): newest link wins, but only if
        // its agent has a non-empty current report — otherwise fall
        // back to the next link, exactly as the pre-batch code did.
        for (final taskId in taskIds) {
          final links = linksByTaskId[taskId];
          if (links == null || links.isEmpty) continue;
          for (final link in links.orderedPrimaryFirst()) {
            final report = reportsByAgentId[link.fromId];
            if (report == null) continue;
            // Gate on a non-empty body so only "real" reports surface, but
            // embed just the compact summary to keep wake prefill small.
            if (report.content.trim().isEmpty) continue;
            reportByTaskId[taskId] = _LinkedTaskAgentReport(
              agentId: link.fromId,
              oneLiner: report.oneLiner,
              tldr: report.tldr,
              createdAt: report.createdAt,
            );
            break;
          }
        }
      }

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
        row['latestTaskAgentReportOneLiner'] = linkedReport.oneLiner;
        row['latestTaskAgentReportTldr'] = linkedReport.tldr;
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

  /// Batch-resolves all observation payloads into a map keyed by payload ID.
  Future<Map<String, AgentMessagePayloadEntity>> _resolveObservationPayloads(
    List<AgentMessageEntity> observations,
  ) async {
    final payloadIds = observations
        .map((o) => o.contentEntryId)
        .whereType<String>()
        .toSet();

    if (payloadIds.isEmpty) {
      return const <String, AgentMessagePayloadEntity>{};
    }

    // Single batched IN-list lookup instead of `Future.wait(map →
    // getEntity)`. See `AgentRepository.getEntitiesByIds` for the slow-
    // log evidence behind the rewrite. Non-payload entities (or ids
    // with no row / soft-deleted) are silently dropped — the caller
    // renders a placeholder, same as the pre-batch failure mode.
    final Map<String, AgentDomainEntity> entitiesById;
    try {
      entitiesById = await agentRepository.getEntitiesByIds(payloadIds);
    } catch (e) {
      // Non-fatal — observation will render with placeholder text.
      return const <String, AgentMessagePayloadEntity>{};
    }

    final result = <String, AgentMessagePayloadEntity>{};
    for (final entry in entitiesById.entries) {
      final entity = entry.value;
      if (entity is AgentMessagePayloadEntity) {
        result[entry.key] = entity;
      }
    }
    return result;
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

  /// Renders an "Active Running Timer" section describing whatever timer
  /// is currently running.
  ///
  /// Two shapes:
  ///
  /// - **Same task** — the timer belongs to the task being woken. The agent
  ///   gets the timerId, started time, tracked range, elapsed minutes, and
  ///   current entry text, and is told to propose `update_running_timer`
  ///   instead of a parallel `create_time_entry` for that ongoing work.
  /// - **Other task** — the timer belongs to a different task. The agent is
  ///   only told the tracked range (no id, no source task, no entry text)
  ///   so it can avoid proposing `create_time_entry` entries for this task
  ///   that overlap with that range. Details about the other task are
  ///   intentionally withheld.
  ///
  /// Returns an empty string when no timer is active.
  String _buildActiveTimerSection(TimeService? timeService, String taskId) {
    if (timeService == null) return '';
    final current = timeService.getCurrent();
    if (current is! JournalEntry) return '';

    final dateFrom = current.meta.dateFrom;
    final now = clock.now();
    // [TimeService.start] only emits live `dateTo` updates on its broadcast
    // stream; the in-memory `_current` entity returned by `getCurrent()`
    // still carries the original `dateTo` recorded when the timer was
    // started. Use `now` as the running endpoint so the prompt — and the
    // overlap guard for the cross-task branch — reflects the actual
    // tracked range. If `current.meta.dateTo` is somehow ahead of `now`
    // (e.g. an injected fixture), respect it as a defensive upper bound.
    final dateTo = current.meta.dateTo.isAfter(now) ? current.meta.dateTo : now;
    final elapsedMinutes = dateTo.difference(dateFrom).inMinutes;
    final isSameTask = timeService.linkedFrom?.id == taskId;

    final buffer = StringBuffer()..writeln('## Active Running Timer');

    if (isSameTask) {
      final entryText = current.entryText?.plainText.trim() ?? '';
      buffer
        ..writeln(
          'A timer is currently running for THIS task. Do NOT propose a '
          'new `create_time_entry` for the work covered by this timer — '
          'propose `update_running_timer` instead with a richer description. '
          '`create_time_entry` is still appropriate for clearly distinct '
          'completed sessions that do not overlap this timer.',
        )
        ..writeln('- timerId: ${current.meta.id}')
        ..writeln('- started: ${dateFrom.toIso8601String()}')
        ..writeln(
          '- tracked: ${dateFrom.toIso8601String()} → '
          '${dateTo.toIso8601String()} '
          '(~$elapsedMinutes min elapsed)',
        )
        ..writeln(
          '- current text: '
          '${entryText.isEmpty ? '(empty)' : '"$entryText"'}',
        );
    } else {
      buffer
        ..writeln(
          'A timer is currently running for a DIFFERENT task. Details '
          'about that task are intentionally withheld. Do NOT propose '
          '`create_time_entry` entries on this task whose [startTime, '
          'endTime] interval overlaps the tracked range below — that '
          'time is already being recorded elsewhere. You may still '
          'propose entries for non-overlapping completed intervals. '
          '`update_running_timer` is NOT available in '
          'this wake because the timer is not for this task.',
        )
        ..writeln(
          '- tracked elsewhere: ${dateFrom.toIso8601String()} → '
          '${dateTo.toIso8601String()} '
          '(~$elapsedMinutes min elapsed)',
        );
    }

    buffer.writeln();
    return buffer.toString();
  }

  Future<String> _buildEditableTimeEntriesSection(
    TimeService? timeService,
    String taskId,
  ) async {
    try {
      final runningId = timeService?.getCurrent()?.meta.id;
      final linkedEntries = await journalDb.getLinkedEntities(taskId);
      final entries =
          linkedEntries
              .whereType<JournalEntry>()
              .where((entry) => entry.meta.id != runningId)
              .toList()
            ..sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));

      if (entries.isEmpty) return '';

      final buffer = StringBuffer()
        ..writeln('## Editable Time Entries')
        ..writeln(
          'These completed time-entry IDs are linked from THIS task. Only '
          'pass an `entryId` listed here to `update_time_entry`. Do not use '
          '`update_time_entry` for the currently running timer.',
        );

      for (final entry in entries) {
        final text = entry.entryText?.plainText.trim() ?? '';
        buffer
          ..writeln('- id: ${entry.meta.id}')
          ..writeln('  dateFrom: ${entry.meta.dateFrom.toIso8601String()}')
          ..writeln('  dateTo: ${entry.meta.dateTo.toIso8601String()}')
          ..writeln('  text: ${jsonEncode(text)}');
      }

      buffer.writeln();
      return buffer.toString();
    } catch (error, stackTrace) {
      _logError(
        'failed to build editable time entries section',
        error: error,
        stackTrace: stackTrace,
      );
      return '';
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
