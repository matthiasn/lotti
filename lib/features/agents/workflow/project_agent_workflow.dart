import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/agent_time_utils.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/project_agent_report_contract.dart';
import 'package:lotti/features/agents/service/agent_log_llm_summarizer.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/sync/agent_input_capture_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/agent_wake_memory.dart';
import 'package:lotti/features/agents/workflow/project_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/prompt_record.dart';
import 'package:lotti/features/agents/workflow/task_source_renderer.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

part 'project_agent_context_builder.dart';

/// Assembles context, runs a conversation, and persists results for a single
/// Project Agent wake cycle.
///
/// Standalone class (no base class, following the `ImproverAgentWorkflow`
/// pattern). Fetches the project entity + linked tasks, builds a system prompt
/// with project context, runs the conversation, and persists report,
/// observations, and state updates.
class ProjectAgentWorkflow {
  ProjectAgentWorkflow({
    required this.agentRepository,
    required this.conversationRepository,
    required this.aiConfigRepository,
    required this.cloudInferenceRepository,
    required this.journalRepository,
    required this.syncService,
    required this.templateService,
    this.soulDocumentService,
    this.domainLogger,
    this.onPersistedStateChanged,
    this.inputCaptureService,
    this.logSummarizer,
    this.compactionTailBudgetTokens = 50000,
    this.compactionTailRetainTokens = 20000,
  });

  final AgentRepository agentRepository;
  final AgentSyncService syncService;
  final ConversationRepository conversationRepository;
  final AiConfigRepository aiConfigRepository;
  final CloudInferenceRepository cloudInferenceRepository;
  final JournalRepository journalRepository;
  final AgentTemplateService templateService;
  final SoulDocumentService? soulDocumentService;
  final DomainLogger? domainLogger;
  final void Function(String agentId)? onPersistedStateChanged;

  /// Captures the wake's project-linked journal entries into the agent's
  /// append-only log (ADR 0020).
  final AgentInputCaptureService? inputCaptureService;

  /// LLM edge for compaction folds (ADR 0017).
  final AgentLogLlmSummarizer? logSummarizer;

  /// Compaction watermarks — see `TaskAgentWorkflow` for the rationale.
  final int compactionTailBudgetTokens;
  final int compactionTailRetainTokens;

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
        name: 'ProjectAgentWorkflow',
        error: error?.runtimeType,
        stackTrace: stackTrace,
      );
    }
  }

  /// Execute a full wake cycle for the given project agent.
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

    // 1. Load current state, reconciled against the log (PR 4 B6).
    final loadedState = await syncService.reconciledAgentState(agentId);
    if (loadedState == null) {
      _log('no agent state found — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'No agent state found');
    }
    var state = loadedState;

    final projectId = state.slots.activeProjectId;
    if (projectId == null) {
      _log('no active project ID — aborting wake', subDomain: 'execute');
      return const WakeResult(
        success: false,
        error: 'No active project ID',
      );
    }

    final now = clock.now();

    // 2. Load the latest report and decide whether a due scheduled wake can be
    // skipped cheaply because no new project activity was recorded.
    final lastReport = await agentRepository.getLatestReport(
      agentId,
      AgentReportScopes.current,
    );
    final initialScheduledWakeWasDue =
        state.scheduledWakeAt != null && !state.scheduledWakeAt!.isAfter(now);
    if (initialScheduledWakeWasDue && lastReport != null) {
      final latestState = await agentRepository.getAgentState(agentId) ?? state;
      final latestScheduledWakeWasDue =
          latestState.scheduledWakeAt != null &&
          !latestState.scheduledWakeAt!.isAfter(now);

      if (!latestScheduledWakeWasDue) {
        _log(
          'scheduled wake already handled elsewhere — skipping duplicate run',
          subDomain: 'execute',
        );
        return const WakeResult(success: true);
      }

      if (latestState.slots.pendingProjectActivityAt == null) {
        await _skipDormantScheduledWake(
          state: latestState,
          now: now,
        );
        return const WakeResult(success: true);
      }

      state = latestState;
    }

    final scheduledWakeWasDue =
        state.scheduledWakeAt != null && !state.scheduledWakeAt!.isAfter(now);
    final shouldInitializeSchedule = state.scheduledWakeAt == null;

    // 2a. Capture this wake's project-linked journal entries into the log
    // (ADR 0020) — same substrate and renderer as the task agent (only
    // text/audio/image log entries are kept; member TASKS are state, not
    // log, and stay in the linked-tasks context). Runs AFTER the dormant
    // skip so no-activity scheduled wakes stay cheap (a dormant wake has
    // nothing new to capture). Non-fatal.
    final memory = AgentWakeMemory(
      syncService: syncService,
      inputCaptureService: inputCaptureService,
      logSummarizer: logSummarizer,
      domainLogger: domainLogger,
    );
    var captureSucceeded = false;
    if (inputCaptureService != null) {
      try {
        final linked = await journalRepository.getLinkedEntities(
          linkedTo: projectId,
        );
        captureSucceeded = await memory.capture(
          agentId: agentId,
          sources: renderTaskSources(linked),
          at: now,
          threadId: threadId,
          runKey: runKey,
        );
      } catch (e) {
        _logError('failed to capture wake inputs', error: e);
      }
    }

    // 3. Load project entity and linked task context.
    final projectEntity = await journalRepository.getJournalEntityById(
      projectId,
    );
    if (projectEntity == null) {
      _log(
        'project not found in journal — aborting wake',
        subDomain: 'execute',
      );
      return const WakeResult(
        success: false,
        error: 'Project not found',
      );
    }

    // 4. Load observations.
    final journalObservations = await agentRepository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
    );

    // 5. Resolve template and active version.
    final templateCtx = await _resolveTemplate(agentId);

    // 6. Resolve inference profile → provider.
    final profileResolver = ProfileResolver(
      aiConfigRepository: aiConfigRepository,
    );
    final resolvedProfile = templateCtx != null
        ? await profileResolver.resolve(
            agentConfig: agentIdentity.config,
            template: templateCtx.template,
            version: templateCtx.version,
          )
        : null;
    if (resolvedProfile == null) {
      _log(
        'no provider configured — aborting wake',
        subDomain: 'execute',
      );
      return const WakeResult(
        success: false,
        error: 'No inference provider configured',
      );
    }
    final modelId = resolvedProfile.thinkingModelId;
    final provider = resolvedProfile.thinkingProvider;

    // 6a2. Compaction (ADR 0017) — the shared per-wake memory pipeline: flag
    // read, fold past the trigger watermark with the wake's resolved model,
    // assemble the compacted log, evaluate the read-flip gates.
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
    );

    // 6b. Load observation payloads so we can render actual text.
    final observationPayloads = await _resolveObservationPayloads(
      journalObservations,
    );

    // 6c. Load linked tasks and their task-agent reports.
    final linkedTasksContext = await _buildLinkedTasksContext(projectId);

    // 7. Assemble system prompt and user message.
    final systemPrompt = _buildSystemPrompt(templateCtx);
    final builtMessage = _buildUserMessage(
      projectEntity: projectEntity,
      lastReport: lastReport,
      observations: journalObservations,
      observationPayloads: observationPayloads,
      linkedTasksContext: linkedTasksContext,
      triggerTokens: triggerTokens,
      // Only attach the compacted log when the read actually flips; the
      // legacy sections render otherwise.
      compactedLog: memoryView.useCompactedLog ? memoryView.compactedLog : null,
    );
    final userMessage = builtMessage.text;

    // 8. Create conversation and run with strategy.
    final conversationId = conversationRepository.createConversation(
      systemMessage: systemPrompt,
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

    // 8a. Persist user message for inspectability — as a v2 prompt record
    // when the read flipped (the log block is derivable from the synced
    // event log; ADR 0020), or the legacy full blob otherwise.
    try {
      final userPayloadId = _uuid.v4();
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
    }

    try {
      final strategy = ProjectAgentStrategy(
        syncService: syncService,
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
      );

      final tools = _buildToolDefinitions();
      final inferenceRepo = CloudInferenceWrapper(
        cloudRepository: cloudInferenceRepository,
        geminiThinkingMode: resolvedProfile.thinkingModel?.geminiThinkingMode,
      );

      // Record template + soul provenance on the wake run log.
      if (templateCtx != null) {
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
        }
      }

      // 9. Run the conversation.
      final usage = await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: userMessage,
        model: modelId,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: 0.3,
        strategy: strategy,
      );

      // Persist token usage.
      await _persistTokenUsage(
        usage: usage,
        agentId: agentId,
        runKey: runKey,
        threadId: threadId,
        modelId: modelId,
        templateCtx: templateCtx,
        now: now,
      );

      // Capture final assistant response.
      final manager = conversationRepository.getConversation(conversationId);
      final finalContent = _extractFinalAssistantContent(manager);
      strategy.recordFinalResponse(finalContent);

      // 9. Persist all wake outputs.
      final reportContent = strategy.extractReportContent();
      final reportTldr = strategy.extractReportTldr();
      final reportOneLiner = strategy.extractReportOneLiner();
      final reportHealthBand = strategy.extractReportHealthBand();
      final reportHealthRationale = strategy.extractReportHealthRationale();
      final reportHealthConfidence = strategy.extractReportHealthConfidence();
      final observations = strategy.extractObservations();
      final deferredItems = strategy.extractDeferredItems();
      await syncService.runInTransaction(() async {
        final latestState =
            await agentRepository.getAgentState(agentId) ?? state;

        // Persist thought.
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

        // Persist report.
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
              provenance: <String, Object?>{
                ProjectAgentReportProvenanceKeys.healthBand: reportHealthBand,
                ProjectAgentReportProvenanceKeys.healthRationale:
                    reportHealthRationale,
                ...?reportHealthConfidence == null
                    ? null
                    : <String, Object?>{
                        ProjectAgentReportProvenanceKeys.healthConfidence:
                            reportHealthConfidence,
                      },
              },
              threadId: threadId,
            ),
          );

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
        }

        // Persist observations.
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

        // Persist deferred change set (if any items were accumulated).
        if (deferredItems.isNotEmpty) {
          final changeItems = deferredItems.map((item) {
            final toolName = item['toolName'] as String? ?? '';
            final args = item['args'] as Map<String, dynamic>? ?? {};
            return ChangeItem(
              toolName: toolName,
              args: args,
              humanSummary: _buildHumanSummary(toolName, args),
            );
          }).toList();

          await syncService.upsertEntity(
            AgentDomainEntity.changeSet(
              id: _uuid.v4(),
              agentId: agentId,
              taskId: projectId,
              threadId: threadId,
              runKey: runKey,
              status: ChangeSetStatus.pending,
              items: changeItems,
              createdAt: now,
              vectorClock: null,
            ),
          );
        }

        // Update state.
        final nextScheduledWakeAt =
            scheduledWakeWasDue || shouldInitializeSchedule
            ? nextLocalDayAtTime(
                now,
                hour: AgentSchedules.projectDailyDigestHour,
              )
            : latestState.scheduledWakeAt;
        final latestPendingActivityAt =
            latestState.slots.pendingProjectActivityAt;
        final nextPendingActivityAt =
            latestPendingActivityAt != null &&
                latestPendingActivityAt.isAfter(now)
            ? latestPendingActivityAt
            : null;
        final nextSlots = scheduledWakeWasDue
            ? latestState.slots.copyWith(lastDailyWakeAt: now)
            : latestState.slots;
        final hostId = await syncService.localHost();
        await syncService.upsertEntity(
          latestState.copyWith(
            slots: nextSlots.copyWith(
              pendingProjectActivityAt: nextPendingActivityAt,
            ),
            lastWakeAt: now,
            scheduledWakeAt: nextScheduledWakeAt,
            updatedAt: now,
            consecutiveFailureCount: 0,
            wakeCounter: latestState.wakeCounter.increment(hostId),
          ),
        );

        // Event-source the watermarks updated above (PR 4, B2): the markers'
        // createdAt is what the projection folds. `lastWakeAt` updates on every
        // wake; `lastDailyWakeAt` only when the scheduled daily wake was due.
        // The cached row stays the read source until the cutover (B6).
        await syncService.appendMilestone(
          agentId: agentId,
          milestone: AgentMilestone.wakeCompleted,
          createdAt: now,
          threadId: threadId,
          runKey: runKey,
        );
        if (scheduledWakeWasDue) {
          await syncService.appendMilestone(
            agentId: agentId,
            milestone: AgentMilestone.dailyWakeCompleted,
            createdAt: now,
            threadId: threadId,
            runKey: runKey,
          );
        }
      });
      onPersistedStateChanged?.call(agentId);

      _log(
        'wake completed: ${observations.length} observations, '
        '${deferredItems.length} deferred items',
        subDomain: 'execute',
      );

      return const WakeResult(success: true);
    } catch (e, s) {
      _logError('wake failed', error: e, stackTrace: s);

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
      conversationRepository.deleteConversation(conversationId);
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _skipDormantScheduledWake({
    required AgentStateEntity state,
    required DateTime now,
  }) async {
    final hostId = await syncService.localHost();
    await syncService.runInTransaction(() async {
      await syncService.upsertEntity(
        state.copyWith(
          lastWakeAt: now,
          scheduledWakeAt: nextLocalDayAtTime(
            now,
            hour: AgentSchedules.projectDailyDigestHour,
          ),
          updatedAt: now,
          consecutiveFailureCount: 0,
          wakeCounter: state.wakeCounter.increment(hostId),
        ),
      );

      // The dormant skip still advances `lastWakeAt`, so it event-sources the
      // same marker as a full wake (PR 4, B2). No wake thread here — the marker
      // gets its own thread.
      await syncService.appendMilestone(
        agentId: state.agentId,
        milestone: AgentMilestone.wakeCompleted,
        createdAt: now,
      );
    });
    onPersistedStateChanged?.call(state.agentId);

    _log(
      'scheduled wake skipped: no pending project activity',
      subDomain: 'execute',
    );
  }

  Future<void> _persistTokenUsage({
    required InferenceUsage? usage,
    required String agentId,
    required String runKey,
    required String threadId,
    required String modelId,
    required _TemplateContext? templateCtx,
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
          templateId: templateCtx?.template.id,
          templateVersionId: templateCtx?.version.id,
          soulDocumentId: templateCtx?.soulVersion?.agentId,
          soulDocumentVersionId: templateCtx?.soulVersion?.id,
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

  Future<_TemplateContext?> _resolveTemplate(String agentId) async {
    final template = await templateService.getTemplateForAgent(agentId);
    if (template == null) return null;

    final version = await templateService.getActiveVersion(template.id);
    if (version == null) return null;

    // Resolve the soul document assigned to this template, if any.
    // Returns null when no soul is assigned — that's the legitimate fallback.
    // Exceptions propagate: a broken soul chain is a real error.
    final soulVersion = await soulDocumentService?.resolveActiveSoulForTemplate(
      template.id,
    );

    return _TemplateContext(
      template: template,
      version: version,
      soulVersion: soulVersion,
    );
  }

  /// Builds a user-readable summary for a deferred tool call.
  static String _buildHumanSummary(
    String toolName,
    Map<String, dynamic> args,
  ) {
    switch (toolName) {
      case ProjectAgentToolNames.recommendNextSteps:
        final steps = args['steps'];
        if (steps is List && steps.isNotEmpty) {
          return 'Recommend ${steps.length} next step(s)';
        }
        return 'Recommend next steps';
      case ProjectAgentToolNames.updateProjectStatus:
        final status = args['status'] ?? 'unknown';
        return 'Update project status to $status';
      case ProjectAgentToolNames.createTask:
        final title = args['title'] ?? 'untitled';
        return 'Create task: $title';
      default:
        return 'Deferred: $toolName';
    }
  }
}

class _TemplateContext {
  const _TemplateContext({
    required this.template,
    required this.version,
    this.soulVersion,
  });

  final AgentTemplateEntity template;
  final AgentTemplateVersionEntity version;

  /// Active soul version for this template, if a soul is assigned.
  final SoulDocumentVersionEntity? soulVersion;
}
