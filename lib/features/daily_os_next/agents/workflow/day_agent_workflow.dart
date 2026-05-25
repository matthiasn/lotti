import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_config.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tools.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_strategy.dart';
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
    this.soulDocumentService,
    this.onPersistedStateChanged,
    this.config = const DayAgentConfig(),
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

  /// Structured logger.
  final DomainLogger domainLogger;

  /// Callback fired when persisted state changes.
  final void Function(String agentId)? onPersistedStateChanged;

  /// Planning defaults included in the prompt.
  final DayAgentConfig config;

  static const _uuid = Uuid();
  static const minScheduledWakeLeadTime = Duration(minutes: 15);
  static const maxScheduledWakeWritesPerDay = 4;
  static const _maxRecentObservationCount = 20;

  void _log(String message, {String? subDomain}) {
    domainLogger.log(
      LogDomains.agentWorkflow,
      message,
      subDomain: subDomain,
    );
  }

  void _logError(String message, {Object? error, StackTrace? stackTrace}) {
    domainLogger.error(
      LogDomains.agentWorkflow,
      message,
      error: error,
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
    final state = await agentRepository.getAgentState(agentId);
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
    final captureContext = await _captureContext(
      agentIdentity: agentIdentity,
      planDate: dayDate,
      triggerTokens: triggerTokens,
    );
    final systemPrompt = _buildSystemPrompt(templateCtx);
    final userMessage = _buildUserMessage(
      dayId: dayId,
      planDate: dayDate,
      triggerTokens: triggerTokens,
      observations: recentObservations,
      observationPayloads: observationPayloads,
      captureContext: captureContext,
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

      final usage = await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: userMessage,
        model: modelId,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: _buildToolDefinitions(),
        temperature: 0.3,
        strategy: strategy,
      );

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
        await syncService.upsertEntity(
          latestState.copyWith(
            revision: latestState.revision + 1,
            lastWakeAt: now,
            updatedAt: now,
            consecutiveFailureCount: 0,
            wakeCounter: latestState.wakeCounter + 1,
            scheduledWakeAt: _remainingScheduledWakeAt(latestState, now),
          ),
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
            revision: latestState.revision + 1,
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
    if (!DayAgentToolNames.isSetNextWakeTool(toolName)) {
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
            revision: state.revision + 1,
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
    final scaffold = '''
You are a Daily OS day agent. You operate on exactly one local calendar day.

Available tools:

- `record_observations`: private memory for learnings and uncertainty.
- `set_next_wake`: schedule the next useful pre-warm wake.
- `submit_capture`: persist a user capture transcript and enqueue parsing.
- `parse_capture_to_items`: persist capture phrases parsed from the current
  capture-submitted wake.
- `match_to_corpus`: find existing task candidates for a phrase.
- `link_capture_phrase_to_task`: attach a parsed capture item to a task.
- `break_capture_link`: remove a parsed capture item's task link.
- `surface_pending_decisions`: list overdue, in-progress, missed recurring,
  and due-today tasks for reconcile.
- `apply_triage`: apply a reconcile action to a task.
- `create_task_from_phrase`: propose a new task via a pending change set.

Capture matching rules:
- Use the embedded task corpus when parsing a submitted capture.
- Emit `parse_capture_to_items` with confidenceScore in [0, 1].
- confidenceScore >= 0.75 is a strong match.
- confidenceScore >= 0.5 and < 0.75 is a low-confidence match.
- confidenceScore < 0.5 should be treated as a new item.

You cannot mutate day plans yet. Do not claim that you changed blocks or
commitments. Record private observations and schedule one useful future wake
when warranted.

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
    required Set<String> triggerTokens,
    required List<AgentMessageEntity> observations,
    required Map<String, AgentMessagePayloadEntity> observationPayloads,
    required _CaptureContext? captureContext,
  }) {
    final payload = <String, Object?>{
      'dayId': dayId,
      'planDate': planDate.toIso8601String(),
      'triggerTokens': triggerTokens.toList()..sort(),
      if (captureContext != null) 'capture': captureContext.toJson(),
      'recentObservations': [
        for (final observation in observations)
          {
            'createdAt': observation.createdAt.toIso8601String(),
            'text': _extractPayloadText(
              observationPayloads[observation.contentEntryId],
            ),
          },
      ],
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

  Future<void> _persistUserMessage({
    required String agentId,
    required String threadId,
    required String runKey,
    required String userMessage,
    required DateTime now,
  }) async {
    try {
      final payloadId = _uuid.v4();
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: payloadId,
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

  List<ChatCompletionTool> _buildToolDefinitions() {
    return dayAgentTools.map((tool) {
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
