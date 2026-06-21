import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/deferred_change_items.dart';
import 'package:lotti/features/agents/workflow/event_agent_context_builder.dart';
import 'package:lotti/features/agents/workflow/event_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Assembles context, runs a conversation, and persists results for a single
/// Event Agent wake cycle.
///
/// Mirrors `ProjectAgentWorkflow` but is leaner: v1 events are narrate-led, so
/// there is no compaction / input-capture log, no daily-digest scheduling, and
/// no health band. It does persist deferred proposals (follow-up tasks) as a
/// pending change set. After a successful run the content gate is cleared
/// (`awaitingContent = false`).
class EventAgentWorkflow {
  EventAgentWorkflow({
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

  static const _uuid = Uuid();

  late final EventAgentContextBuilder _contextBuilder =
      EventAgentContextBuilder(
        agentRepository: agentRepository,
        journalRepository: journalRepository,
        logError: _logError,
      );

  void _log(String message, {String? subDomain}) {
    domainLogger?.log(LogDomain.agentWorkflow, message, subDomain: subDomain);
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
        name: 'EventAgentWorkflow',
        error: error?.runtimeType,
        stackTrace: stackTrace,
      );
    }
  }

  /// Execute a full wake cycle for the given event agent.
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

    // 1. Load current state, reconciled against the log.
    final state = await syncService.reconciledAgentState(agentId);
    if (state == null) {
      _log('no agent state found — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'No agent state found');
    }

    final eventId = state.slots.activeEventId;
    if (eventId == null) {
      _log('no active event ID — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'No active event ID');
    }

    final now = clock.now();

    // 2. Load the latest recap and the event entity.
    final lastReport = await agentRepository.getLatestReport(
      agentId,
      AgentReportScopes.current,
    );

    final eventEntity = await journalRepository.getJournalEntityById(eventId);
    if (eventEntity == null) {
      _log('event not found in journal — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'Event not found');
    }

    // 3. Load observations and resolve template + provider.
    final observations = await agentRepository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
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
      _log('no provider configured — aborting wake', subDomain: 'execute');
      return const WakeResult(
        success: false,
        error: 'No inference provider configured',
      );
    }
    final modelId = resolvedProfile.thinkingModelId;
    final provider = resolvedProfile.thinkingProvider;

    // 4. Assemble system prompt and user message.
    final observationPayloads = await _contextBuilder
        .resolveObservationPayloads(
          observations,
        );
    final linkedEntriesContext = await _contextBuilder
        .buildLinkedEntriesContext(
          eventId,
        );
    final systemPrompt = _contextBuilder.buildSystemPrompt(
      version: templateCtx?.version,
      soulVersion: templateCtx?.soulVersion,
    );
    final userMessage = _contextBuilder.buildUserMessage(
      eventEntity: eventEntity,
      lastReport: lastReport,
      observations: observations,
      observationPayloads: observationPayloads,
      linkedEntriesContext: linkedEntriesContext,
      triggerTokens: triggerTokens,
    );

    // 5. Create conversation and persist the user message for inspectability.
    final conversationId = conversationRepository.createConversation(
      systemMessage: systemPrompt,
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

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
    }

    try {
      final strategy = EventAgentStrategy(
        syncService: syncService,
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
      );

      final tools = _contextBuilder.buildToolDefinitions();
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

      // 6. Run the conversation.
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

      // 6b. Forced-report retry: if the model stopped without publishing a
      // recap, give it one more pass with `update_report` pinned. Without this,
      // a flubbed wake would clear the content gate having produced nothing.
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
      final finalContent = _contextBuilder.extractFinalAssistantContent(
        manager,
      );
      strategy.recordFinalResponse(finalContent);

      // 7. Persist all wake outputs.
      final reportContent = strategy.extractReportContent();
      final reportTldr = strategy.extractReportTldr();
      final reportOneLiner = strategy.extractReportOneLiner();
      final extractedObservations = strategy.extractObservations();
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

        // Persist recap report.
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
        for (final observation in extractedObservations) {
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

        // Persist deferred proposals (follow-up tasks) as a pending change set
        // keyed by the event id, so the detail page can surface them for
        // accept/reject.
        if (deferredItems.isNotEmpty) {
          final changeItems = buildDeferredChangeItems(
            deferredItems,
            _buildHumanSummary,
          );

          await syncService.upsertEntity(
            AgentDomainEntity.changeSet(
              id: _uuid.v4(),
              agentId: agentId,
              taskId: eventId,
              threadId: threadId,
              runKey: runKey,
              status: ChangeSetStatus.pending,
              items: changeItems,
              createdAt: now,
              vectorClock: null,
            ),
          );
        }

        // Update state: the run reached inference, so content has arrived —
        // clear the content gate.
        final hostId = await syncService.localHost();
        await syncService.upsertEntity(
          latestState.copyWith(
            lastWakeAt: now,
            updatedAt: now,
            awaitingContent: false,
            consecutiveFailureCount: 0,
            wakeCounter: latestState.wakeCounter.increment(hostId),
          ),
        );

        await syncService.appendMilestone(
          agentId: agentId,
          milestone: AgentMilestone.wakeCompleted,
          createdAt: now,
          threadId: threadId,
          runKey: runKey,
        );
      });
      onPersistedStateChanged?.call(agentId);

      _log(
        'wake completed: ${extractedObservations.length} observations',
        subDomain: 'execute',
      );

      return const WakeResult(success: true);
    } catch (e, s) {
      _logError('wake failed', error: e, stackTrace: s);

      try {
        // Re-read state in a transaction before bumping the failure count, so a
        // concurrent gate-clear or a peer device's state write that landed
        // since the wake-start snapshot is not clobbered (e.g. resurrecting
        // `awaitingContent` or reverting a newer `wakeCounter`).
        await syncService.runInTransaction(() async {
          final current = await agentRepository.getAgentState(agentId) ?? state;
          await syncService.upsertEntity(
            current.copyWith(
              updatedAt: now,
              consecutiveFailureCount: current.consecutiveFailureCount + 1,
            ),
          );
        });
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

  /// Issues a second, forced inference pass to recover a missing recap.
  ///
  /// When the model stops without calling `update_report`, this sends one more
  /// `sendMessage` with `toolChoice` pinned to `update_report` and the tool list
  /// restricted to it, mirroring the task agent. Any failure inside the retry is
  /// swallowed (a partial wake is persisted); returns the retry's token usage.
  Future<InferenceUsage?> _forceUpdateReportIfMissing({
    required String conversationId,
    required String modelId,
    required AiConfigInferenceProvider provider,
    required CloudInferenceWrapper inferenceRepo,
    required List<ChatCompletionTool> tools,
    required EventAgentStrategy strategy,
  }) async {
    _log(
      'no recap published — retrying with forced update_report',
      subDomain: 'execute',
    );
    const forcedToolChoice = ChatCompletionToolChoiceOption.tool(
      ChatCompletionNamedToolChoice(
        type: ChatCompletionNamedToolChoiceType.function,
        function: ChatCompletionFunctionCallOption(
          name: EventAgentToolNames.updateReport,
        ),
      ),
    );
    final reportOnlyTools = tools
        .where((tool) => tool.function.name == EventAgentToolNames.updateReport)
        .toList(growable: false);

    try {
      return await conversationRepository.sendMessage(
        conversationId: conversationId,
        message:
            'You did not call `update_report` before stopping. Call it now '
            'with a concise `oneLiner`, a 1-2 sentence `tldr`, and the full '
            'markdown `content`. This is the final, mandatory step of the '
            'recap — respond with nothing else.',
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

  /// Builds a user-facing one-line summary for a deferred tool call.
  static String _buildHumanSummary(String toolName, Map<String, dynamic> args) {
    switch (toolName) {
      case EventAgentToolNames.suggestFollowUpTask:
        final title = args['title'];
        return title is String && title.trim().isNotEmpty
            ? 'Follow-up task: ${title.trim()}'
            : 'Suggest a follow-up task';
      default:
        return 'Deferred: $toolName';
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
}

class _TemplateContext {
  const _TemplateContext({
    required this.template,
    required this.version,
    this.soulVersion,
  });

  final AgentTemplateEntity template;
  final AgentTemplateVersionEntity version;
  final SoulDocumentVersionEntity? soulVersion;
}
