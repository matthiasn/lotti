import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/database/database.dart';
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
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_config.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tools.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_strategy.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_capture_events.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

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
    this.journalDb,
    this.logSummarizer,
    this.compactionEnabled,
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

  /// Journal DB for the per-wake `enable_agent_compaction` flag read (see
  /// `AgentWakeMemory`); null keeps compaction off.
  final JournalDb? journalDb;

  /// LLM edge for compaction folds (ADR 0017).
  final AgentLogLlmSummarizer? logSummarizer;

  /// Test override for the compaction flag; null = consult it per wake.
  final bool? compactionEnabled;

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

    final dayId = state.slots.activeDayId;
    if (dayId == null || dayId.isEmpty) {
      return const WakeResult(success: false, error: 'No active day ID');
    }

    final dayDate = _dateFromDayId(dayId);
    if (dayDate == null) {
      return WakeResult(success: false, error: 'Invalid active day ID $dayId');
    }

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
      journalDb: journalDb,
      syncService: syncService,
      logSummarizer: logSummarizer,
      compactionEnabled: compactionEnabled,
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
      triggerTokens: triggerTokens,
    );
    final draftingContext = await _draftingContext(
      agentIdentity: agentIdentity,
      dayId: dayId,
      triggerTokens: triggerTokens,
      captureContext: captureContext,
    );
    final refineContext = await _refineContext(
      agentIdentity: agentIdentity,
      dayId: dayId,
      triggerTokens: triggerTokens,
    );
    final systemPrompt = _buildSystemPrompt(templateCtx);
    final userMessage = _buildUserMessage(
      dayId: dayId,
      planDate: dayDate,
      now: now,
      triggerTokens: triggerTokens,
      observations: recentObservations,
      observationPayloads: observationPayloads,
      captureContext: captureContext,
      draftingContext: draftingContext,
      refineContext: refineContext,
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

      if (_requiresDraftDayPlan(
        dayId: dayId,
        triggerTokens: triggerTokens,
      )) {
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
        ..call(dayId);

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

    final wakeCountKey = _scheduledWakeCountKey(now);
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

        await syncService.upsertEntity(
          state.copyWith(
            scheduledWakeAt: scheduledAt,
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

  String _buildUserMessage({
    required String dayId,
    required DateTime planDate,
    required DateTime now,
    required Set<String> triggerTokens,
    required List<AgentMessageEntity> observations,
    required Map<String, AgentMessagePayloadEntity> observationPayloads,
    required _CaptureContext? captureContext,
    required _DraftingContext? draftingContext,
    required _RefineContext? refineContext,
    String? compactedLog,
  }) {
    final payload = <String, Object?>{
      'dayId': dayId,
      'planDate': planDate.toIso8601String(),
      // The compacted day log (ADR 0017): capture transcripts and the
      // agent's observations as an append-only event tail behind a summary.
      // Placed before the per-wake volatile fields so the JSON-encoded
      // prefix stays byte-stable across wakes; when present it supersedes
      // the separate recentObservations listing below.
      'dayLog': ?compactedLog,
      'triggerTokens': triggerTokens.toList()..sort(),
      if (captureContext != null) 'capture': captureContext.toJson(),
      if (draftingContext != null) 'drafting': draftingContext.toJson(),
      if (refineContext != null) 'refine': refineContext.toJson(),
      if (compactedLog == null)
        'recentObservations': [
          for (final observation in observations)
            {
              'createdAt': observation.createdAt.toIso8601String(),
              'text': _extractPayloadText(
                observationPayloads[observation.contentEntryId],
              ),
            },
        ],
      // Keep the volatile wall-clock last so the rest of the payload stays a
      // stable prefix across wakes, maximizing prompt prefix / KV-cache reuse.
      'currentLocalTime': now.toIso8601String(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<_CaptureContext?> _captureContext({
    required AgentIdentityEntity agentIdentity,
    required DateTime planDate,
    required Set<String> triggerTokens,
  }) async {
    final service = captureService;
    if (service == null) return null;

    final captureId = captureIdFromTriggerTokens(triggerTokens);
    if (captureId == null) return null;

    final capture = await service.getCapture(captureId);
    if (capture == null || capture.agentId != agentIdentity.agentId) {
      return null;
    }

    final corpus = await service.buildTaskCorpusSnapshot(
      allowedCategoryIds: agentIdentity.allowedCategoryIds,
      day: planDate,
    );
    return _CaptureContext(capture: capture, taskCorpus: corpus);
  }

  Future<_DraftingContext?> _draftingContext({
    required AgentIdentityEntity agentIdentity,
    required String dayId,
    required Set<String> triggerTokens,
    required _CaptureContext? captureContext,
  }) async {
    final service = planService;
    if (service == null) return null;
    if (draftingDayIdFromTriggerTokens(triggerTokens) != dayId) return null;

    final baselinePlan = await service.draftPlanForDay(
      agentId: agentIdentity.agentId,
      dayId: dayId,
    );
    final explicitTaskIds = decidedTaskIdsFromTriggerTokens(triggerTokens);
    final explicitCaptureItemIds = decidedCaptureItemIdsFromTriggerTokens(
      triggerTokens,
    ).toSet();
    final parsedItems = await _parsedItemsForCapture(captureContext);
    final decidedTasks = await service.hydrateDecidedTasks(
      allowedCategoryIds: agentIdentity.allowedCategoryIds,
      explicitTaskIds: explicitTaskIds,
      parsedItems: parsedItems,
    );
    final decidedCaptureItems = [
      for (final item in parsedItems)
        if (explicitCaptureItemIds.contains(item.id)) item,
    ];
    return _DraftingContext(
      baselinePlan: baselinePlan,
      decidedTasks: decidedTasks,
      decidedCaptureItems: decidedCaptureItems,
    );
  }

  Future<List<ParsedItemEntity>> _parsedItemsForCapture(
    _CaptureContext? captureContext,
  ) async {
    final capture = captureContext?.capture;
    final service = captureService;
    if (capture == null || service == null) return const [];
    final entities = await service.parsedItemsForCapture(capture.id);
    return entities.whereType<ParsedItemEntity>().toList();
  }

  Future<_RefineContext?> _refineContext({
    required AgentIdentityEntity agentIdentity,
    required String dayId,
    required Set<String> triggerTokens,
  }) async {
    final service = planService;
    if (service == null) return null;
    if (refineDayIdFromTriggerTokens(triggerTokens) != dayId) return null;

    final baselinePlan = await service.draftPlanForDay(
      agentId: agentIdentity.agentId,
      dayId: dayId,
    );
    return _RefineContext(baselinePlan: baselinePlan);
  }

  /// The JSON line carrying the derivable day log in the encoded payload.
  /// Used to split the persisted v2 prompt record around it (ADR 0020).
  static const _dayLogLineAnchor = '\n  "dayLog": ';

  Future<void> _persistUserMessage({
    required String agentId,
    required String threadId,
    required String runKey,
    required String userMessage,
    required DateTime now,
    WakeMemoryView? memoryView,
  }) async {
    try {
      final payloadId = _uuid.v4();
      // ADR 0020 v2 prompt records: when the read flipped, the `dayLog`
      // JSON field is a pure function of the synced event log — store the
      // payload WITHOUT that line plus the reconstruction marker. The line
      // is re-encoded on reconstruction (`json-day-log-line` wrap).
      var content = <String, Object?>{'text': userMessage};
      if (memoryView != null && memoryView.useCompactedLog) {
        final anchor = userMessage.indexOf(_dayLogLineAnchor);
        if (anchor >= 0) {
          final lineStart = anchor + 1;
          final lineEnd = userMessage.indexOf('\n', lineStart);
          if (lineEnd > lineStart) {
            content = encodePromptRecord(
              head: userMessage.substring(0, lineStart),
              tail: userMessage.substring(lineEnd + 1),
              summaryId: memoryView.activeSummaryId,
              until: memoryView.lastEventPosition,
              wrap: promptRecordWrapDayLogJsonLine,
            );
          }
        }
      }
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: agentId,
          createdAt: now,
          vectorClock: null,
          content: content,
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
          contentEntryId: payloadId,
          metadata: AgentMessageMetadata(runKey: runKey),
        ),
      );
    } catch (e, s) {
      _logError(
        'failed to persist day-agent user message',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> _persistThought({
    required String agentId,
    required String threadId,
    required String runKey,
    required String? thoughtText,
    required DateTime now,
  }) async {
    if (thoughtText == null || thoughtText.trim().isEmpty) return;
    final payloadId = _uuid.v4();
    await syncService.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: agentId,
        createdAt: now,
        vectorClock: null,
        content: <String, Object?>{'text': thoughtText.trim()},
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
        contentEntryId: payloadId,
        metadata: AgentMessageMetadata(runKey: runKey),
      ),
    );
  }

  Future<void> _persistObservations({
    required String agentId,
    required String threadId,
    required String runKey,
    required List<ObservationRecord> observations,
    required DateTime now,
  }) async {
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
  }

  Future<Map<String, AgentMessagePayloadEntity>> _resolveObservationPayloads(
    List<AgentMessageEntity> observations,
  ) async {
    final payloadIds = observations
        .map((observation) => observation.contentEntryId)
        .whereType<String>()
        .toSet();
    if (payloadIds.isEmpty) return const <String, AgentMessagePayloadEntity>{};

    final entitiesById = await agentRepository.getEntitiesByIds(payloadIds);
    return {
      for (final entry in entitiesById.entries)
        if (entry.value is AgentMessagePayloadEntity)
          entry.key: entry.value as AgentMessagePayloadEntity,
    };
  }

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
    required String dayId,
    required Set<String> triggerTokens,
  }) {
    return planService != null &&
        draftingDayIdFromTriggerTokens(triggerTokens) == dayId;
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
    return {
      for (final entry in current.entries)
        if (!entry.key.startsWith(prefix) || entry.key == wakeCountKey)
          entry.key: entry.value,
      wakeCountKey: nextCount,
    };
  }

  static String _scheduledWakeCountKey(DateTime now) {
    return 'day_agent_set_next_wake:${now.toIso8601String().substring(0, 10)}';
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
