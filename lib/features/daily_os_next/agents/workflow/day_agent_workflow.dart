import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
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
    this.soulDocumentService,
    this.domainLogger,
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

  /// Optional logger.
  final DomainLogger? domainLogger;

  /// Callback fired when persisted state changes.
  final void Function(String agentId)? onPersistedStateChanged;

  /// Planning defaults included in the prompt.
  final DayAgentConfig config;

  static const _uuid = Uuid();
  static const minScheduledWakeLeadTime = Duration(minutes: 15);
  static const maxScheduledWakeWritesPerDay = 4;

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
        '$message${error != null ? ' (errorType=${error.runtimeType})' : ''}',
        name: 'DayAgentWorkflow',
        error: error?.runtimeType,
        stackTrace: stackTrace,
      );
    }
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
    final observationPayloads = await _resolveObservationPayloads(observations);
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
    final systemPrompt = _buildSystemPrompt(templateCtx);
    final userMessage = _buildUserMessage(
      dayId: dayId,
      planDate: dayDate,
      triggerTokens: triggerTokens,
      observations: observations,
      observationPayloads: observationPayloads,
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
        executeToolHandler: (toolName, args, manager) => _executeToolHandler(
          agentId: agentId,
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
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    if (toolName != DayAgentToolNames.setNextWake) {
      return DayAgentToolResult(
        success: false,
        output: 'Error: unknown tool "$toolName".',
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

    final state = await agentRepository.getAgentState(agentId);
    if (state == null) {
      return const DayAgentToolResult(
        success: false,
        output: 'Error: agent state not found.',
      );
    }

    final wakeCountKey = _scheduledWakeCountKey(now);
    final currentCount = state.processedCounterByHost[wakeCountKey] ?? 0;
    if (currentCount >= maxScheduledWakeWritesPerDay) {
      return const DayAgentToolResult(
        success: false,
        output: 'Error: daily scheduled-wake cap reached.',
      );
    }

    await syncService.upsertEntity(
      state.copyWith(
        revision: state.revision + 1,
        scheduledWakeAt: scheduledAt,
        updatedAt: now,
        processedCounterByHost: {
          ...state.processedCounterByHost,
          wakeCountKey: currentCount + 1,
        },
      ),
    );
    onPersistedStateChanged?.call(agentId);

    return DayAgentToolResult(
      success: true,
      output: 'Next wake scheduled for ${scheduledAt.toIso8601String()}.',
    );
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

Available foundation tools:

- `record_observations`: private memory for learnings and uncertainty.
- `set_next_wake`: schedule the next useful pre-warm wake.

You cannot mutate day plans yet. Do not claim that you changed tasks, blocks,
captures, or commitments. Record private observations and schedule one useful
future wake when warranted.

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
  }) {
    final payload = <String, Object?>{
      'dayId': dayId,
      'planDate': planDate.toIso8601String(),
      'triggerTokens': triggerTokens.toList()..sort(),
      'recentObservations': [
        for (final observation in observations.take(20))
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

  static String _scheduledWakeCountKey(DateTime now) {
    return 'day_agent_set_next_wake:${formatIsoDate(now)}';
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
