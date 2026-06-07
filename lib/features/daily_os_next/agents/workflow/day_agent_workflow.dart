import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/service/agent_log_llm_summarizer.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
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
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tools.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_strategy.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_capture_events.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

part 'day_agent_context_builder.dart';
part 'day_agent_persistence.dart';

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

  static const _uuid = Uuid();
  static const minScheduledWakeLeadTime = Duration(minutes: 15);
  static const maxScheduledWakeWritesPerDay = 4;
  static const _maxRecentObservationCount = 20;

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
    // tokens are authoritative. A capture-submitted wake carries no day token,
    // so its day resolves from the capture's own `dayId` scope; the per-day
    // `activeDayId` slot remains a last-resort fallback until the identity
    // cutover removes per-day identities.
    final dayResolution = resolvePlannerWakeDay(triggerTokens);
    if (dayResolution.isAmbiguous) {
      final candidates = dayResolution.candidates.toList()..sort();
      return WakeResult(
        success: false,
        error: 'Ambiguous day workspace in trigger tokens: $candidates',
      );
    }
    // Token day first, then the legacy per-day slot. Only when neither yields a
    // day (a capture-only wake under one planner, where the slot is gone) do we
    // load the capture to resolve its own `dayId` scope — avoiding a redundant
    // capture read in the common per-day path.
    var dayId = dayResolution.dayId ?? state.slots.activeDayId;
    if (dayId == null || dayId.isEmpty) {
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
    var captureEntities = const <CaptureEntity>[];
    try {
      captureEntities = (await agentRepository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.capture,
      )).whereType<CaptureEntity>().toList();
      capturesLoaded = true;
    } catch (e) {
      _logError('failed to load capture entities', error: e);
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
      inlineEvents: dayCaptureEvents(captureEntities),
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

  Future<DayAgentToolResult> _executeToolHandler({
    required String agentId,
    required String threadId,
    required String runKey,
    required String dayId,
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    if (DayAgentToolNames.isCaptureReconcileTool(toolName)) {
      final service = captureService;
      if (service == null) {
        return const DayAgentToolResult(
          success: false,
          output: 'Error: capture/reconcile tools are not configured.',
        );
      }
      final result = await service.executeTool(
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        toolName: toolName,
        args: args,
      );
      return DayAgentToolResult(
        success: result.success,
        output: result.output,
      );
    }

    if (DayAgentToolNames.isPlanTool(toolName)) {
      final service = planService;
      if (service == null) {
        return const DayAgentToolResult(
          success: false,
          output: 'Error: day-plan tools are not configured.',
        );
      }
      final result = await service.executeTool(
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        toolName: toolName,
        args: args,
      );
      return DayAgentToolResult(
        success: result.success,
        output: result.output,
      );
    }

    if (!DayAgentToolNames.isSetNextWakeTool(toolName)) {
      return DayAgentToolResult(
        success: false,
        output: 'Error: unknown day-agent tool "$toolName".',
      );
    }

    final rawAt = args['at'];
    final reasonValue = args['reason'];
    final reason = reasonValue is String ? reasonValue.trim() : '';
    if (rawAt is! String || rawAt.trim().isEmpty) {
      return const DayAgentToolResult(
        success: false,
        output: 'Error: "at" must be an ISO-8601 date-time string.',
      );
    }
    if (reason.isEmpty) {
      return const DayAgentToolResult(
        success: false,
        output: 'Error: "reason" must not be empty.',
      );
    }

    late final DateTime scheduledAt;
    try {
      scheduledAt = DateTime.parse(rawAt.trim());
    } catch (_) {
      return const DayAgentToolResult(
        success: false,
        output: 'Error: "at" must be parseable as an ISO-8601 date-time.',
      );
    }

    final now = clock.now();
    final earliestAllowed = now.add(minScheduledWakeLeadTime);
    if (scheduledAt.isBefore(earliestAllowed)) {
      return DayAgentToolResult(
        success: false,
        output:
            'Error: next wake must be at least '
            '${minScheduledWakeLeadTime.inMinutes} minutes in the future.',
      );
    }

    // Cap is keyed by (dayId, date) so an active multi-day planner can still
    // pre-warm each day; a single calendar-date key would let three planned
    // days exhaust one shared budget (ADR 0022 Decision 12).
    final wakeCountKey = _scheduledWakeCountKey(now, dayId);
    final workspaceKey = dayAgentWorkspaceKey(dayId);
    try {
      await syncService.runInTransaction(() async {
        final state = await agentRepository.getAgentState(agentId);
        if (state == null) {
          throw const _DayAgentToolException('Error: agent state not found.');
        }

        final currentCount = state.toolCounterByKey[wakeCountKey] ?? 0;
        if (currentCount >= maxScheduledWakeWritesPerDay) {
          throw const _DayAgentToolException(
            'Error: daily scheduled-wake cap reached.',
          );
        }

        // Persist the pre-warm as a day-scoped scheduled-wake record rather
        // than the single, clobberable AgentState.scheduledWakeAt: a
        // long-lived planner has several outstanding day wakes, and each must
        // restore with its own workspace + trigger tokens. The deterministic
        // id overwrites a prior pending pre-warm for the same day.
        await syncService.upsertEntity(
          AgentDomainEntity.scheduledWake(
            id: scheduledWakeRecordId(agentId, workspaceKey: workspaceKey),
            agentId: agentId,
            scheduledAt: scheduledAt,
            status: ScheduledWakeStatus.pending,
            reason: WakeReason.scheduled.name,
            updatedAt: now,
            vectorClock: null,
            triggerTokens: [dayAgentPlanningDayToken(dayId)],
            workspaceKey: workspaceKey,
          ),
        );

        // The cap counter still lives on the per-agent state.
        await syncService.upsertEntity(
          state.copyWith(
            updatedAt: now,
            toolCounterByKey: _nextToolCounterByKey(
              state.toolCounterByKey,
              wakeCountKey,
              currentCount + 1,
            ),
          ),
        );
      });
      onPersistedStateChanged?.call(agentId);

      return DayAgentToolResult(
        success: true,
        output: 'Next wake scheduled for ${scheduledAt.toIso8601String()}.',
      );
    } on _DayAgentToolException catch (e) {
      return DayAgentToolResult(success: false, output: e.message);
    }
  }

  Future<_TemplateContext?> _resolveTemplate(String agentId) async {
    final template = await templateService.getTemplateForAgent(agentId);
    if (template == null) return null;

    final version = await templateService.getActiveVersion(template.id);
    if (version == null) return null;

    final soulVersion = await soulDocumentService?.resolveActiveSoulForTemplate(
      template.id,
    );

    return _TemplateContext(
      template: template,
      version: version,
      soulVersion: soulVersion,
    );
  }

  String _buildSystemPrompt(_TemplateContext? ctx) {
    const captureToolLines =
        '- `submit_capture`: persist a user capture transcript and enqueue parsing.\n'
        '- `parse_capture_to_items`: persist capture phrases parsed from the current capture-submitted wake.\n'
        '- `match_to_corpus`: find existing task candidates for a phrase.\n'
        '- `link_capture_phrase_to_task`: attach a parsed capture item to a task.\n'
        "- `break_capture_link`: remove a parsed capture item's task link.\n"
        '- `surface_pending_decisions`: list overdue, in-progress, missed recurring, and due-today tasks for reconcile.\n'
        '- `apply_triage`: apply a reconcile action to a task.\n'
        '- `create_task_from_phrase`: create a real task from a new capture phrase.';
    const planToolLines =
        '- `draft_day_plan`: persist a drafted day plan with blocks and reasons.\n'
        '- `summarize_recent_patterns`: return learning cards from recent day drafts.';
    final toolLines = <String>[
      '- `record_observations`: private memory for learnings and uncertainty.',
      '- `set_next_wake`: schedule the next useful pre-warm wake.',
      if (captureService != null) captureToolLines,
      if (planService != null) planToolLines,
    ];
    final scaffold =
        '''
You are a Daily OS day agent. You operate on exactly one local calendar day.

Available tools:

${toolLines.join('\n')}

Capture matching rules:
- Use the embedded task corpus when parsing a submitted capture.
- Emit `parse_capture_to_items` with confidenceScore in [0, 1].
- confidenceScore >= 0.75 is a strong match.
- confidenceScore >= 0.5 and < 0.75 is a low-confidence match.
- confidenceScore < 0.5 should be treated as a new item.
- Older overdue or stale-looking corpus tasks can still be valid matches, but
  only emit them as strong matches when the capture phrase clearly refers to
  that existing task. When the evidence is ambiguous, prefer a low-confidence
  match or a new item so the user can choose instead of silently reviving old
  work.

Drafting rules:
- Every `ai` block passed to `draft_day_plan` must include a concrete reason.
- Keep blocks inside the local plan day and within the user's capacity.
- The user message includes `currentLocalTime`. When `planDate` is the same
  local day, do not create new drafted `ai` or `manual` blocks that start
  before `currentLocalTime`. Preserve already-started baseline blocks only
  when they represent existing in-progress, completed, or dropped history.
- Calendar, buffer, and manual blocks may omit reasons when their purpose is
  self-evident.
- When this wake's user message carries a `drafting` block (i.e. the trigger
  tokens include `drafting:<dayId>`), your priority is to call
  `draft_day_plan` once with the full updated block list — replacing or
  extending `drafting.baselinePlan` rather than emitting partial diffs.
- On drafting wakes, `drafting.decidedTasks` contains existing tasks the user
  approved for placement. If an existing task appears stale or unclear from the
  capture evidence, do not force the placement; create a new task from the
  phrase or keep the plan conservative.
- On drafting wakes, `drafting.decidedCaptureItems` contains approved capture
  items without task IDs. For each item you place, call `create_task_from_phrase`
  first and use the returned `taskId` in `draft_day_plan`.
- On `drafting:<dayId>` wakes, `draft_day_plan` MUST be the final tool call.
  Do not end the wake with plain text. Process reconcile decisions first, then
  emit the full plan through `draft_day_plan`.

Refine rules:
- When this wake's user message carries a `refine` block (i.e. the trigger
  tokens include `refine:<dayId>`), your priority is to call
  `propose_plan_diff` once with the structured changes the user described
  in the accompanying capture transcript. Reference existing `blockId`s
  from `refine.baselinePlan.blocks` for `moved` and `dropped` changes;
  `added` changes carry a fresh `to` block payload. Every change must
  include a non-empty `reason`.
- Do not call `accept_diff` or `revert_diff` autonomously — those are the
  user's verdicts, surfaced through the UI.
- Commit, shutdown, and agenda mutation tools are not available yet. Do
  not claim that you committed or shut down a day.

Record private observations and schedule one useful future wake when warranted.

Planning defaults:
${const JsonEncoder.withIndent('  ').convert(config.toJson())}''';

    if (ctx == null) return scaffold;

    final version = ctx.version;
    final generalDirective = version.generalDirective.trim();
    final reportDirective = version.reportDirective.trim();
    final legacyDirective = version.directives.trim();
    final buf = StringBuffer()..write(scaffold);

    if (reportDirective.isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..writeln('## Report Directive')
        ..writeln()
        ..write(reportDirective);
    }

    if (ctx.soulVersion != null) {
      _appendSoulPersonality(buf, ctx.soulVersion!);
    }

    final operationalDirective = generalDirective.isNotEmpty
        ? generalDirective
        : legacyDirective;
    if (operationalDirective.isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..writeln('## Operational Directives')
        ..writeln()
        ..write(operationalDirective);
    }

    return buf.toString();
  }

  static void _appendSoulPersonality(
    StringBuffer buf,
    SoulDocumentVersionEntity soul,
  ) {
    buf
      ..writeln()
      ..writeln()
      ..writeln('## Personality')
      ..writeln()
      ..write(soul.voiceDirective);
    if (soul.toneBounds.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..writeln('## Tone Bounds')
        ..writeln()
        ..write(soul.toneBounds.trim());
    }
    if (soul.coachingStyle.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..writeln('## Coaching Style')
        ..writeln()
        ..write(soul.coachingStyle.trim());
    }
    if (soul.antiSycophancyPolicy.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..writeln('## Anti-Sycophancy Policy')
        ..writeln()
        ..write(soul.antiSycophancyPolicy.trim());
    }
  }

  /// The JSON line carrying the derivable day log in the encoded payload.
  /// Used to split the persisted v2 prompt record around it (ADR 0020).
  static const _dayLogLineAnchor = '\n  "dayLog": ';

  bool _isToolEnabled(String toolName) {
    if (DayAgentToolNames.isCaptureReconcileTool(toolName)) {
      return captureService != null;
    }
    if (DayAgentToolNames.isPlanTool(toolName)) {
      return planService != null;
    }
    return true;
  }

  bool _requiresDraftDayPlan({
    required DailyOsPlannerWakeContext wakeContext,
  }) {
    return planService != null && wakeContext.isDraftingWake;
  }

  bool _requiresCaptureParse({
    required DailyOsPlannerWakeContext wakeContext,
    required _CaptureContext? captureContext,
  }) {
    // A non-null capture context already implies a capture token resolved to
    // a loadable capture owned by this agent. Drafting/refine checks are
    // workspace-filtered: ambiguous multi-day token sets are rejected before
    // this point, so any mode token present belongs to the resolved day.
    return captureService != null &&
        captureContext != null &&
        !wakeContext.isDraftingWake &&
        !wakeContext.isRefineWake;
  }

  Future<InferenceUsage?> _forceCaptureParseIfMissing({
    required String conversationId,
    required String modelId,
    required AiConfigInferenceProvider provider,
    required CloudInferenceWrapper inferenceRepo,
    required List<ChatCompletionTool> tools,
    required DayAgentStrategy strategy,
    required String captureId,
  }) {
    _log(
      'capture wake missed parse_capture_to_items — retrying with forced '
      'tool choice',
      subDomain: 'execute',
    );
    const forcedToolChoice = ChatCompletionToolChoiceOption.tool(
      ChatCompletionNamedToolChoice(
        type: ChatCompletionNamedToolChoiceType.function,
        function: ChatCompletionFunctionCallOption(
          name: DayAgentToolNames.parseCaptureToItems,
        ),
      ),
    );
    final parseOnlyTools = tools
        .where(
          (tool) => tool.function.name == DayAgentToolNames.parseCaptureToItems,
        )
        .toList(growable: false);

    return conversationRepository.sendMessage(
      conversationId: conversationId,
      message:
          'You did not call `parse_capture_to_items` before stopping. Call it '
          'now for capture `$captureId` using the capture transcript and task '
          'corpus already provided in this wake. This is the mandatory output '
          'of a capture-submitted wake. Do not respond with plain text or call '
          'any other tool.',
      model: modelId,
      provider: provider,
      inferenceRepo: inferenceRepo,
      tools: parseOnlyTools,
      toolChoice: forcedToolChoice,
      temperature: 0.3,
      strategy: strategy,
    );
  }

  Future<InferenceUsage?> _forceDraftDayPlanIfMissing({
    required String conversationId,
    required String modelId,
    required AiConfigInferenceProvider provider,
    required CloudInferenceWrapper inferenceRepo,
    required List<ChatCompletionTool> tools,
    required DayAgentStrategy strategy,
  }) {
    _log(
      'drafting wake missed draft_day_plan — retrying with forced tool choice',
      subDomain: 'execute',
    );
    const forcedToolChoice = ChatCompletionToolChoiceOption.tool(
      ChatCompletionNamedToolChoice(
        type: ChatCompletionNamedToolChoiceType.function,
        function: ChatCompletionFunctionCallOption(
          name: DayAgentToolNames.draftDayPlan,
        ),
      ),
    );
    final draftOnlyTools = tools
        .where((tool) => tool.function.name == DayAgentToolNames.draftDayPlan)
        .toList(growable: false);

    return conversationRepository.sendMessage(
      conversationId: conversationId,
      message:
          'You did not call `draft_day_plan` before stopping. Call it now '
          'with the full block list for this day. This is the mandatory '
          'final step of a drafting wake. Do not respond with plain text or '
          'call any other tool.',
      model: modelId,
      provider: provider,
      inferenceRepo: inferenceRepo,
      tools: draftOnlyTools,
      toolChoice: forcedToolChoice,
      temperature: 0.3,
      strategy: strategy,
    );
  }

  List<ChatCompletionTool> _buildToolDefinitions() {
    return dayAgentTools.where((tool) => _isToolEnabled(tool.name)).map((tool) {
      return ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters,
        ),
      );
    }).toList();
  }

  String? _extractFinalAssistantContent(ConversationManager? manager) {
    if (manager == null) return null;
    final messages = manager.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      final content = messages[i].mapOrNull(assistant: (a) => a.content);
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }
    return null;
  }

  static List<AgentMessageEntity> _recentObservations(
    List<AgentMessageEntity> observations,
  ) {
    final sorted = observations.toList()
      ..sort((a, b) {
        final byCreatedAt = a.createdAt.compareTo(b.createdAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return a.id.compareTo(b.id);
      });
    if (sorted.length <= _maxRecentObservationCount) {
      return sorted;
    }
    return sorted.sublist(sorted.length - _maxRecentObservationCount);
  }

  static DateTime? _remainingScheduledWakeAt(
    AgentStateEntity state,
    DateTime now,
  ) {
    final scheduledWakeAt = state.scheduledWakeAt;
    if (scheduledWakeAt == null || scheduledWakeAt.isAfter(now)) {
      return scheduledWakeAt;
    }
    return null;
  }

  static DateTime? _dateFromDayId(String dayId) {
    const prefix = 'dayplan-';
    if (!dayId.startsWith(prefix)) return null;
    return DateTime.tryParse(dayId.substring(prefix.length));
  }

  /// Resolves the day workspace from a capture-submitted wake's captures.
  ///
  /// A capture wake carries no `planning_day:`/`drafting:`/`refine:` token, so
  /// its day comes from the capture's own `dayId` scope (ADR 0022). Loads each
  /// `capture_submitted:` capture owned by [agentId] and collects the distinct
  /// days; more than one distinct day is reported as ambiguous so the wake can
  /// fail fast rather than pick arbitrarily.
  Future<PlannerWakeDayResolution> _dayIdFromCaptureTokens({
    required String agentId,
    required Set<String> triggerTokens,
  }) async {
    final service = captureService;
    if (service == null) return const PlannerWakeDayResolution(candidates: {});
    final captureIds = captureIdsFromTriggerTokens(triggerTokens);
    if (captureIds.isEmpty) {
      return const PlannerWakeDayResolution(candidates: {});
    }
    final days = <String>{};
    for (final captureId in captureIds) {
      final capture = await service.getCapture(captureId);
      if (capture == null || capture.agentId != agentId) continue;
      days.add(captureDayId(capture));
    }
    return PlannerWakeDayResolution(candidates: days);
  }

  static String _extractPayloadText(AgentMessagePayloadEntity? payload) {
    if (payload == null) return '(no content)';
    final text = payload.content['text'];
    if (text is String && text.isNotEmpty) return text;
    return '(no content)';
  }

  static Map<String, int> _nextToolCounterByKey(
    Map<String, int> current,
    String wakeCountKey,
    int nextCount,
  ) {
    const prefix = 'day_agent_set_next_wake:';
    // Keys are `day_agent_set_next_wake:<dayId>:<date>`. Garbage-collect only
    // stale prior-date counters, keeping every day's counter for the current
    // date so interleaved multi-day planning does not reset another day's cap.
    final todaySuffix = wakeCountKey.substring(wakeCountKey.lastIndexOf(':'));
    return {
      for (final entry in current.entries)
        if (!entry.key.startsWith(prefix) || entry.key.endsWith(todaySuffix))
          entry.key: entry.value,
      wakeCountKey: nextCount,
    };
  }

  static String _scheduledWakeCountKey(DateTime now, String dayId) {
    return 'day_agent_set_next_wake:$dayId:'
        '${now.toIso8601String().substring(0, 10)}';
  }
}

class _DayAgentToolException implements Exception {
  const _DayAgentToolException(this.message);

  final String message;
}

class _MissingDraftDayPlanException implements Exception {
  const _MissingDraftDayPlanException();

  @override
  String toString() {
    return 'Drafting wake did not persist draft_day_plan after forced retry.';
  }
}

class _MissingCaptureParseException implements Exception {
  const _MissingCaptureParseException();

  @override
  String toString() {
    return 'Capture wake did not persist parse_capture_to_items after forced '
        'retry.';
  }
}

class _TemplateContext {
  const _TemplateContext({
    required this.template,
    required this.version,
    required this.soulVersion,
  });

  final AgentTemplateEntity template;
  final AgentTemplateVersionEntity version;
  final SoulDocumentVersionEntity? soulVersion;
}

class _CaptureContext {
  const _CaptureContext({
    required this.capture,
    required this.taskCorpus,
  });

  final CaptureEntity capture;
  final List<Map<String, Object?>> taskCorpus;

  Map<String, Object?> toJson() => {
    'captureId': capture.id,
    'transcript': capture.transcript,
    'capturedAt': capture.capturedAt.toIso8601String(),
    'audioRef': capture.audioRef,
    'taskCorpus': taskCorpus,
  };
}

class _DraftingContext {
  const _DraftingContext({
    this.baselinePlan,
    this.decidedTasks = const [],
    this.decidedCaptureItems = const [],
  });

  final DayPlanEntity? baselinePlan;
  final List<DecidedTaskRef> decidedTasks;
  final List<ParsedItemEntity> decidedCaptureItems;

  Map<String, Object?> toJson() {
    final plan = baselinePlan;
    return <String, Object?>{
      'requested': true,
      'baselinePlan': plan == null
          ? null
          : <String, Object?>{
              'planId': plan.id,
              'dayId': plan.dayId,
              'planDate': plan.planDate.toIso8601String(),
              'capacityMinutes': plan.capacityMinutes,
              'scheduledMinutes': plan.scheduledMinutes,
              'blocks': [
                for (final block in plan.data.plannedBlocks)
                  <String, Object?>{
                    'id': block.id,
                    'title': block.title,
                    'taskId': block.taskId,
                    'categoryId': block.categoryId,
                    'start': block.startTime.toIso8601String(),
                    'end': block.endTime.toIso8601String(),
                    'type': block.type.name,
                    'state': block.state.name,
                    'reason': block.reason,
                    'note': block.note,
                  },
              ],
              'energyBands': [
                for (final band in plan.energyBands) band.toJson(),
              ],
            },
      'decidedTasks': [for (final task in decidedTasks) task.toJson()],
      'decidedCaptureItems': [
        for (final item in decidedCaptureItems)
          <String, Object?>{
            'id': item.id,
            'kind': item.kind.name,
            'title': item.title,
            'categoryId': item.categoryId,
            'confidence': item.confidence.name,
            'confidenceScore': item.confidenceScore,
            'lowConfidence': item.lowConfidence,
            'spokenPhrase': item.spokenPhrase,
            'matchedTaskId': item.matchedTaskId,
            'estimateMinutes': item.estimateMinutes,
            'timeAnchor': item.timeAnchor,
            'proposedUpdate': item.proposedUpdate,
          },
      ],
    };
  }
}

class _RefineContext {
  const _RefineContext({this.baselinePlan});

  final DayPlanEntity? baselinePlan;

  Map<String, Object?> toJson() {
    final plan = baselinePlan;
    return <String, Object?>{
      'requested': true,
      'baselinePlan': plan == null
          ? null
          : <String, Object?>{
              'planId': plan.id,
              'dayId': plan.dayId,
              'planDate': plan.planDate.toIso8601String(),
              'capacityMinutes': plan.capacityMinutes,
              'scheduledMinutes': plan.scheduledMinutes,
              'blocks': [
                for (final block in plan.data.plannedBlocks)
                  <String, Object?>{
                    'id': block.id,
                    'title': block.title,
                    'taskId': block.taskId,
                    'categoryId': block.categoryId,
                    'start': block.startTime.toIso8601String(),
                    'end': block.endTime.toIso8601String(),
                    'type': block.type.name,
                    'state': block.state.name,
                    'reason': block.reason,
                    'note': block.note,
                  },
              ],
              'energyBands': [
                for (final band in plan.energyBands) band.toJson(),
              ],
            },
    };
  }
}
