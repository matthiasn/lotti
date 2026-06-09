import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/memory/memory_links.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/service/agent_log_llm_summarizer.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/sync/agent_log_compactor.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/agent_wake_memory.dart';
import 'package:lotti/features/agents/workflow/prompt_record.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/daily_os_next/agents/domain/daily_os_planner_wake_context.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_config.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/agents/domain/planner_knowledge.dart';
import 'package:lotti/features/daily_os_next/agents/domain/week_context.dart';
import 'package:lotti/features/daily_os_next/agents/prompt/day_agent_prompt_sections.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_knowledge_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_week_context_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tools.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_strategy.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_capture_events.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

part 'day_agent_context_builder.dart';
part 'day_agent_persistence.dart';
part 'day_agent_tool_handlers.dart';
part 'day_agent_prompt_builder.dart';
part 'day_agent_workflow_models.dart';

/// Assembles context and runs one Daily OS day-agent wake.
class DayAgentWorkflow {
  /// Creates a day-agent workflow.
  DayAgentWorkflow({
    required this.agentRepository,
    required this.conversationRepository,
    required this.aiConfigRepository,
    required this.cloudInferenceRepository,
    required this.syncService,
    required this.templateService,
    required this.domainLogger,
    this.captureService,
    this.planService,
    this.knowledgeService,
    this.weekContextService,
    this.soulDocumentService,
    this.onPersistedStateChanged,
    this.config = const DayAgentConfig(),
    this.logSummarizer,
    this.compactionTailBudgetTokens = 50000,
    this.compactionTailRetainTokens = 20000,
  });

  /// Agent repository.
  final AgentRepository agentRepository;

  /// Conversation repository.
  final ConversationRepository conversationRepository;

  /// AI config repository.
  final AiConfigRepository aiConfigRepository;

  /// Cloud inference repository.
  final CloudInferenceRepository cloudInferenceRepository;

  /// Sync-aware writer.
  final AgentSyncService syncService;

  /// Template resolver.
  final AgentTemplateService templateService;

  /// Optional soul resolver.
  final SoulDocumentService? soulDocumentService;

  /// Capture/reconcile backend tool implementation.
  final DayAgentCaptureService? captureService;

  /// Day-plan backend tool implementation.
  final DayAgentPlanService? planService;

  /// Durable-knowledge backend tool implementation (ADR 0022).
  final DayAgentKnowledgeService? knowledgeService;

  /// Week-context backend: lookback/lookahead prompt sections and the
  /// `write_day_summary` tool.
  final DayAgentWeekContextService? weekContextService;

  /// Structured logger.
  final DomainLogger domainLogger;

  /// Callback fired when persisted state changes.
  final void Function(String agentId)? onPersistedStateChanged;

  /// Planning defaults included in the prompt.
  final DayAgentConfig config;

  /// LLM edge for compaction folds (ADR 0017).
  final AgentLogLlmSummarizer? logSummarizer;

  /// Compaction watermarks — see `TaskAgentWorkflow` for the rationale.
  final int compactionTailBudgetTokens;
  final int compactionTailRetainTokens;

  static const minScheduledWakeLeadTime = Duration(minutes: 15);
  static const maxScheduledWakeWritesPerDay = 4;
  void _log(String message, {String? subDomain}) {
    domainLogger.log(
      LogDomain.agentWorkflow,
      message,
      subDomain: subDomain,
    );
  }

  void _logError(String message, {Object? error, StackTrace? stackTrace}) {
    domainLogger.error(
      LogDomain.agentWorkflow,
      error ?? message,
      message: error != null ? message : null,
      stackTrace: stackTrace,
    );
  }

  /// Execute a full wake cycle for [agentIdentity].
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
  }) async {
    final agentId = agentIdentity.agentId;
    final now = clock.now();
    // The wake acts on the log-reconciled state (PR 4 B6).
    final state = await syncService.reconciledAgentState(agentId);
    if (state == null) {
      return const WakeResult(success: false, error: 'No agent state found');
    }

    // Day workspace resolution (ADR 0022 Decisions 3–4): the wake's trigger
    // tokens are authoritative. The long-lived planner has no `activeDayId`
    // slot, so the day comes from the day tokens or — for a capture-submitted
    // wake, which carries no day token — from the capture's own `dayId` scope.
    // The workflow fails fast when no day can be resolved.
    final dayResolution = resolvePlannerWakeDay(triggerTokens);
    if (dayResolution.isAmbiguous) {
      final candidates = dayResolution.candidates.toList()..sort();
      return WakeResult(
        success: false,
        error: 'Ambiguous day workspace in trigger tokens: $candidates',
      );
    }
    var dayId = dayResolution.dayId;
    // Whether the workspace came from day-carrying tokens (planning_day /
    // drafting / refine — including scheduled wakes, which carry a
    // planning_day token) rather than the capture fallback below. Week
    // context is gated to these wakes: a capture-submitted wake is
    // high-frequency text triage, and an 8-day journal+links+claims load per
    // capture is unjustified for it.
    final isDayTokenWake = dayId != null;
    if (dayId == null) {
      final captureResolution = await _dayIdFromCaptureTokens(
        agentId: agentId,
        triggerTokens: triggerTokens,
      );
      if (captureResolution.isAmbiguous) {
        final candidates = captureResolution.candidates.toList()..sort();
        return WakeResult(
          success: false,
          error: 'Ambiguous day workspace across captures: $candidates',
        );
      }
      dayId = captureResolution.dayId;
    }
    final resolvedDayId = dayId;
    if (resolvedDayId == null || resolvedDayId.isEmpty) {
      return const WakeResult(success: false, error: 'No active day ID');
    }

    final dayDate = _dateFromDayId(resolvedDayId);
    if (dayDate == null) {
      return WakeResult(
        success: false,
        error: 'Invalid active day ID $resolvedDayId',
      );
    }

    final wakeContext = DailyOsPlannerWakeContext.fromTokens(
      plannerAgentId: agentId,
      dayId: resolvedDayId,
      runKey: runKey,
      threadId: threadId,
      triggerTokens: triggerTokens,
    );

    final observations = await agentRepository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
    );
    final recentObservations = _recentObservations(observations);
    final observationPayloads = await _resolveObservationPayloads(
      recentObservations,
    );
    final templateCtx = await _resolveTemplate(agentId);

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
      return const WakeResult(
        success: false,
        error: 'No inference provider configured',
      );
    }

    final modelId = resolvedProfile.thinkingModelId;
    final provider = resolvedProfile.thinkingProvider;

    // Memory substrate (ADR 0016/0017): the day agent's durable inputs —
    // submitted capture transcripts and its own observations — are ALREADY
    // synced log entities, so they join the event log as inline/projected
    // events (no payload capture step). The pipeline folds them past the
    // trigger watermark and assembles the compacted day log.
    final memory = AgentWakeMemory(
      syncService: syncService,
      logSummarizer: logSummarizer,
      domainLogger: domainLogger,
    );
    var capturesLoaded = false;
    var captureMetas = const <CaptureEventMeta>[];
    try {
      // Only the lightweight ordering metadata (id + timestamps) — never the
      // full transcripts — so per-wake cost stays flat as the single
      // long-lived planner's capture history grows. Transcripts are resolved
      // lazily for just the post-cutoff tail via [_resolveCaptureContent].
      captureMetas = await agentRepository.getCaptureEventMetaByAgentId(
        agentId,
      );
      capturesLoaded = true;
    } catch (e) {
      _logError('failed to load capture metadata', error: e);
    }
    final memoryView = await memory.compactAndAssemble(
      agentId: agentId,
      // Inline events derive from already-synced entities read in the same
      // breath as the rest of this wake — there is no stale-frontier risk,
      // so the gate is simply whether the load itself succeeded.
      captureSucceeded: capturesLoaded,
      model: modelId,
      provider: provider,
      at: now,
      threadId: threadId,
      runKey: runKey,
      budget: compactionTailBudgetTokens,
      retainTokens: compactionTailRetainTokens,
      inlineEvents: dayCaptureEvents(captureMetas),
      resolveInlineContent: _resolveCaptureContent,
    );

    final captureContext = await _captureContext(
      agentIdentity: agentIdentity,
      planDate: dayDate,
      wakeContext: wakeContext,
    );
    final draftingContext = await _draftingContext(
      agentIdentity: agentIdentity,
      wakeContext: wakeContext,
      captureContext: captureContext,
    );
    final refineContext = await _refineContext(
      agentIdentity: agentIdentity,
      wakeContext: wakeContext,
    );
    final attentionPlanning = await _attentionPlanningContext(dayDate);
    final knowledge = await _knowledgeContext(
      agentIdentity: agentIdentity,
      touchedScopes: _touchedScopes(
        attentionPlanning: attentionPlanning,
        draftingContext: draftingContext,
        refineContext: refineContext,
      ),
      now: now,
    );
    final weekContext = isDayTokenWake
        ? await _weekContext(agentId: agentId, planDate: dayDate, now: now)
        : null;
    final systemPrompt = _buildSystemPrompt(templateCtx);
    final userMessage = _buildUserMessage(
      dayId: resolvedDayId,
      planDate: dayDate,
      now: now,
      triggerTokens: triggerTokens,
      observations: recentObservations,
      observationPayloads: observationPayloads,
      captureContext: captureContext,
      draftingContext: draftingContext,
      refineContext: refineContext,
      attentionPlanning: attentionPlanning,
      knowledge: knowledge,
      weekContext: weekContext,
      compactedLog: memoryView.useCompactedLog ? memoryView.compactedLog : null,
    );

    final conversationId = conversationRepository.createConversation(
      systemMessage: systemPrompt,
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

    await _persistUserMessage(
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      userMessage: userMessage,
      now: now,
      memoryView: memoryView,
    );

    try {
      final strategy = DayAgentStrategy(
        syncService: syncService,
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        domainLogger: domainLogger,
        executeToolHandler: (toolName, args, manager) => _executeToolHandler(
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          dayId: resolvedDayId,
          toolName: toolName,
          args: args,
        ),
      );

      final inferenceRepo = CloudInferenceWrapper(
        cloudRepository: cloudInferenceRepository,
        geminiThinkingMode: resolvedProfile.thinkingModel?.geminiThinkingMode,
      );

      if (templateCtx != null) {
        await agentRepository.updateWakeRunTemplate(
          runKey,
          templateCtx.template.id,
          templateCtx.version.id,
          resolvedModelId: modelId,
          soulId: templateCtx.soulVersion?.agentId,
          soulVersionId: templateCtx.soulVersion?.id,
        );
      }

      final tools = _buildToolDefinitions();
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

      if (_requiresCaptureParse(
        wakeContext: wakeContext,
        captureContext: captureContext,
      )) {
        if (!strategy.didPersistCaptureParse) {
          // The resolved capture context is the single source of truth for
          // which capture this wake parses; re-extracting from the token set
          // would be non-deterministic under merged multi-capture sets.
          final captureId = captureContext!.capture.id;
          final retryUsage = await _forceCaptureParseIfMissing(
            conversationId: conversationId,
            modelId: modelId,
            provider: provider,
            inferenceRepo: inferenceRepo,
            tools: tools,
            strategy: strategy,
            captureId: captureId,
          );
          if (retryUsage != null) {
            usage = usage == null ? retryUsage : usage.merge(retryUsage);
          }
        }
        if (!strategy.didPersistCaptureParse) {
          throw const _MissingCaptureParseException();
        }
      }

      if (_requiresDraftDayPlan(wakeContext: wakeContext)) {
        if (!strategy.didPersistDraftDayPlan) {
          final retryUsage = await _forceDraftDayPlanIfMissing(
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
        if (!strategy.didPersistDraftDayPlan) {
          throw const _MissingDraftDayPlanException();
        }
      }

      await _persistTokenUsage(
        usage: usage,
        agentId: agentId,
        runKey: runKey,
        threadId: threadId,
        modelId: modelId,
        templateCtx: templateCtx,
        now: now,
      );

      final manager = conversationRepository.getConversation(conversationId);
      strategy.recordFinalResponse(_extractFinalAssistantContent(manager));

      await syncService.runInTransaction(() async {
        final latestState =
            await agentRepository.getAgentState(agentId) ?? state;
        await _persistThought(
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          thoughtText: strategy.finalResponse,
          now: now,
        );
        await _persistObservations(
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          observations: strategy.extractObservations(),
          now: now,
        );
        final hostId = await syncService.localHost();
        await syncService.upsertEntity(
          latestState.copyWith(
            lastWakeAt: now,
            updatedAt: now,
            consecutiveFailureCount: 0,
            wakeCounter: latestState.wakeCounter.increment(hostId),
            scheduledWakeAt: _remainingScheduledWakeAt(latestState, now),
          ),
        );

        // Event-source the `lastWakeAt` watermark (PR 4, B2): the marker's
        // createdAt is what the projection folds; the cached row above stays the
        // read source until the cutover (B6).
        await syncService.appendMilestone(
          agentId: agentId,
          milestone: AgentMilestone.wakeCompleted,
          createdAt: now,
          threadId: threadId,
          runKey: runKey,
        );
      });
      onPersistedStateChanged
        ?..call(agentId)
        ..call(resolvedDayId);

      _log('day-agent wake completed', subDomain: 'execute');
      return const WakeResult(success: true);
    } catch (e, s) {
      _logError('day-agent wake failed', error: e, stackTrace: s);
      try {
        final latestState =
            await agentRepository.getAgentState(agentId) ?? state;
        await syncService.upsertEntity(
          latestState.copyWith(
            updatedAt: now,
            consecutiveFailureCount: latestState.consecutiveFailureCount + 1,
            scheduledWakeAt: _remainingScheduledWakeAt(latestState, now),
          ),
        );
      } catch (stateError, stackTrace) {
        _logError(
          'failed to update day-agent failure count',
          error: stateError,
          stackTrace: stackTrace,
        );
      }
      return WakeResult(success: false, error: e.toString());
    } finally {
      conversationRepository.deleteConversation(conversationId);
    }
  }
}
