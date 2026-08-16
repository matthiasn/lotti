import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/features/agents/util/inference_provider_resolver.dart';
import 'package:lotti/features/agents/util/text_utils.dart';
import 'package:lotti/features/agents/workflow/agent_system_prompt.dart';
import 'package:lotti/features/agents/workflow/carrierless_attribution.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/nudges/logic/nudge_banner_snooze.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/workflow/relationship_agent_contract.dart';
import 'package:lotti/features/relationships/workflow/relationship_agent_strategy.dart';
import 'package:lotti/features/relationships/workflow/relationship_facts_renderer.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Stable output IDs let a wake recognize that its interactive reply's
/// transaction committed even when the deferred sync-outbox flush failed
/// (the goal-workflow durable-turn pattern).
@visibleForTesting
String relationshipAgentReplyMessageId(String agentId, String runKey) =>
    const Uuid().v5(
      Namespace.url.value,
      'lotti://relationship-agent/$agentId/$runKey/reply',
    );

String _replyPayloadId(String agentId, String runKey) => const Uuid().v5(
  Namespace.url.value,
  'lotti://relationship-agent/$agentId/$runKey/reply-payload',
);

/// Deterministic id of the ONE banner a wake may mint: lease election
/// already guarantees a single arming device, and the run-scoped id makes
/// a retried transaction idempotent instead of duplicating the banner.
@visibleForTesting
String relationshipAdId(String agentId, String runKey) => const Uuid().v5(
  Namespace.url.value,
  'lotti://relationship-agent/$agentId/$runKey/ad',
);

/// The resolved inference route for a relationship agent. `profileId` is
/// the profile that won the resolution chain, or null when the validated
/// default model routes.
typedef RelationshipModelResolution = ({
  String modelId,
  AiConfigInferenceProvider provider,
  GeminiThinkingMode? geminiThinkingMode,
  String? profileId,
});

/// The single model-resolution chain for relationship-agent inference: the
/// relationship's own AI profile (`RelationshipData.profileId`, ADR 0059
/// Decision 7 / plan D6), then the agent config's profile, then the
/// validated default model. Phase B and the briefing disclosure both
/// resolve through here so the provider a consent surface names is the one
/// that actually runs.
Future<RelationshipModelResolution?> resolveRelationshipAgentModel({
  required RelationshipEntry? relationship,
  required AgentIdentityEntity? agentIdentity,
  required AiConfigRepository aiConfigRepository,
}) async {
  final profileId =
      relationship?.data.profileId ?? agentIdentity?.config.profileId;
  if (profileId != null) {
    final profile = await ProfileResolver(
      aiConfigRepository: aiConfigRepository,
    ).resolveByProfileId(profileId);
    if (profile != null) {
      return (
        modelId: profile.thinkingModelId,
        provider: profile.thinkingProvider,
        geminiThinkingMode: profile.thinkingModel?.geminiThinkingMode,
        profileId: profileId,
      );
    }
  }
  final direct = await resolveInferenceProviderWithModel(
    modelId: meliousGlm52ModelId,
    aiConfigRepository: aiConfigRepository,
    logTag: 'RelationshipAgentWorkflow',
  );
  if (direct == null) return null;
  return (
    modelId: direct.model.providerModelId,
    provider: direct.provider,
    geminiThinkingMode: direct.model.geminiThinkingMode,
    profileId: null,
  );
}

/// Phase B of the relationship-agent wake (ADR 0059 Decision 2, the
/// ADR 0054 lease-elected LLM tier).
///
/// One execution: re-derive the deterministic facts via the SAME Phase A
/// derivation that armed the escalation (never trust the arming device) →
/// return BEFORE any inference when the armed fact no longer holds →
/// render the bounded FACTS block (relationship + last N check-ins +
/// linked task titles/statuses + previous briefing; contact channels and
/// refs are structurally absent, ADR 0041 §5) → one bounded conversation
/// at temperature 0 → persist every accumulated output in one transaction.
class RelationshipAgentWorkflow with AgentErrorLogging {
  RelationshipAgentWorkflow({
    required this._repository,
    required this._syncService,
    required this._phaseA,
    required this._relationshipRepository,
    required this._conversationRepository,
    required this._cloudInferenceRepository,
    required this._aiConfigRepository,
    this._factsRenderer = const RelationshipFactsRenderer(),
    this._domainLogger,
  });

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final RelationshipAgentPhaseA _phaseA;
  final RelationshipRepository _relationshipRepository;
  final ConversationRepository _conversationRepository;
  final CloudInferenceRepository _cloudInferenceRepository;
  final AiConfigRepository _aiConfigRepository;
  final RelationshipFactsRenderer _factsRenderer;
  final DomainLogger? _domainLogger;

  @override
  DomainLogger? get domainLogger => _domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentWorkflow;

  static const _uuid = Uuid();

  /// Resolves the durable source turn selected by the wake token, then
  /// runs the same fact-grounded workflow with that message pending.
  Future<WakeResult> executeUserMessage({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
    required String messageId,
  }) async {
    final message = await _repository.getEntity(messageId);
    if (message is! AgentMessageEntity ||
        message.agentId != agentIdentity.agentId ||
        message.kind != AgentMessageKind.user ||
        message.contentEntryId == null) {
      return const WakeResult(
        success: false,
        error: 'relationship chat source message is unavailable',
      );
    }
    final payload = await _repository.getEntity(message.contentEntryId!);
    final text =
        payload is AgentMessagePayloadEntity &&
            payload.agentId == agentIdentity.agentId
        ? payload.content['text']
        : null;
    if (text is! String || text.trim().isEmpty) {
      return const WakeResult(
        success: false,
        error: 'relationship chat source payload is unavailable',
      );
    }
    return execute(
      agentIdentity: agentIdentity,
      runKey: runKey,
      triggerTokens: triggerTokens,
      threadId: threadId,
      pendingUserMessage: text.trim(),
    );
  }

  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
    String? pendingUserMessage,
  }) async {
    final agentId = agentIdentity.agentId;
    final now = clock.now();
    final interactive = pendingUserMessage != null;
    final reportRefresh = relationshipReportRefreshRequested(triggerTokens);
    final escalationDueDay = relationshipEscalationDueDayFromTriggerTokens(
      triggerTokens,
    );
    // The baseline token carries the cadence status persisted BEFORE the
    // transition that armed this wake — Phase A's own register write hides
    // it from any later re-derivation, so "newly lapsed" vs "still overdue"
    // is only tellable from here (ADR 0059 Decision 3).
    final baselineName = relationshipEscalationBaselineFromTriggerTokens(
      triggerTokens,
    );
    final preTransitionStatus = baselineName == null
        ? null
        : RelationshipCadenceStatus.values.asNameMap()[baselineName];

    final relationshipId = await _phaseA.watchedRelationshipId(agentId);
    if (relationshipId == null) {
      return interactive
          ? const WakeResult(
              success: false,
              error: 'relationship agent has no linked relationship',
            )
          : const WakeResult(success: true);
    }
    final relationship = await _relationshipRepository.getRelationshipById(
      relationshipId,
    );
    if (relationship == null || relationship.meta.deletedAt != null) {
      // The person is gone: nothing may publish beside a deleted
      // relationship, and a chat turn against one is an error the UI
      // should surface rather than silently swallow.
      return interactive
          ? const WakeResult(
              success: false,
              error: 'the relationship no longer exists',
            )
          : const WakeResult(success: true);
    }

    final derivation = await _phaseA.deriveCadenceFacts(
      agentId: agentId,
      relationship: relationship,
      now: now,
    );
    final previousReport = await _repository.getLatestReport(
      agentId,
      AgentReportScopes.current,
    );
    // The briefing is stale when evidence arrived after it was written —
    // including the very first check-ins before any briefing exists.
    final reportStale =
        derivation.lastCheckInAt != null &&
        (previousReport == null ||
            derivation.lastCheckInAt!.isAfter(previousReport.createdAt));

    // Re-derive facts FIRST and return before any inference when the armed
    // fact no longer holds (ADR 0059 Decision 3): a check-in landing while
    // the escalation rode sync moves the due day, and this stale episode
    // consumes itself at €0.
    final cadenceDue = derivation.status == RelationshipCadenceStatus.due;
    if (!interactive && !reportRefresh && !cadenceDue && !reportStale) {
      return const WakeResult(success: true);
    }
    // Eligibility binds automatic wakes: un-marking important or archiving
    // silences the agent instantly. Chat and the explicit Brief me remain
    // answerable — the user is asking directly.
    final eligible =
        relationship.data.important &&
        relationship.data.status is RelationshipActive;
    if (!interactive && !reportRefresh && !eligible) {
      return const WakeResult(success: true);
    }

    final nudges =
        (await _repository.getEntitiesByAgentId(
              agentId,
              type: AgentEntityTypes.relationshipNudge,
            ))
            .whereType<RelationshipNudgeEntity>()
            .where((n) => n.deletedAt == null)
            .toList();
    final linkedTasks = await _relationshipRepository.getLinkedTasks(
      relationshipId,
    );
    final checkIns = await _relationshipRepository
        .getAllCheckInsForRelationship(relationshipId);

    var factsBlock = _factsRenderer.render(
      relationship: relationship,
      derivation: derivation,
      checkIns: checkIns,
      linkedTasks: linkedTasks,
      previousReport: previousReport,
      nudges: nudges,
      now: now,
      preTransitionStatus: preTransitionStatus,
    );
    if (interactive) {
      factsBlock = '$factsBlock\n\nPENDING USER MESSAGE:\n$pendingUserMessage';
    }
    if (reportRefresh) {
      factsBlock =
          '$factsBlock\n\nUSER EXPLICITLY REQUESTED A FRESH BRIEFING. Call '
          'update_relationship_report now with the full briefing from the '
          'authoritative FACTS.';
    }

    final resolved = await resolveRelationshipAgentModel(
      relationship: relationship,
      agentIdentity: agentIdentity,
      aiConfigRepository: _aiConfigRepository,
    );
    if (resolved == null) {
      // The escalation record is already consumed and Phase A will not
      // re-arm this episode — a temporarily unconfigured provider must not
      // orphan it. The retry costs €0 until resolution works.
      if (escalationDueDay != null) {
        await _rearmEscalation(
          agentId,
          relationshipEscalationWorkspaceKey(escalationDueDay),
          triggerTokens,
          now,
        );
      }
      return const WakeResult(
        success: false,
        error: 'no inference provider resolves for the relationship agent',
      );
    }

    final conversationId = _conversationRepository.createConversation(
      systemMessage: composeAgentSystemPrompt(
        scaffold: relationshipAgentSystemPrompt,
        version: null,
        soulVersion: null,
      ),
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );
    if (!interactive) {
      await _persistFactsMessage(
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        text: factsBlock,
        now: now,
      );
    }

    final activeAdIds = {
      for (final n in nudges.where((n) => n.status == NudgeStatus.active)) n.id,
    };
    final strategy = RelationshipAgentStrategy(
      syncService: _syncService,
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      activeAdIds: activeAdIds,
    );
    final tools = [
      for (final tool in relationshipAgentTools)
        ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters,
          ),
        ),
    ];
    final inferenceRepo = CloudInferenceWrapper(
      cloudRepository: _cloudInferenceRepository,
      geminiThinkingMode: resolved.geminiThinkingMode,
    );
    final recordConsumption = canRecordAgentConsumption;
    var outputsCommitted = false;

    try {
      var usage = await _conversationRepository.sendMessage(
        conversationId: conversationId,
        message: factsBlock,
        model: resolved.modelId,
        provider: resolved.provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: 0,
        strategy: strategy,
        consumptionAgentId: recordConsumption ? agentId : null,
        consumptionWakeRunKey: recordConsumption ? runKey : null,
        consumptionThreadId: recordConsumption ? threadId : null,
        rethrowInferenceErrors: true,
      );

      // A briefing is REQUIRED on every fact that justified this spend —
      // one pinned retry, then accept the partial wake (the goal-workflow
      // discipline; ordinary no-ops stay free of forced output).
      if ((cadenceDue || reportRefresh || reportStale) &&
          !strategy.hasBriefing) {
        usage = _merge(
          usage,
          await _forceInstruction(
            conversationId: conversationId,
            resolved: resolved,
            inferenceRepo: inferenceRepo,
            tools: tools,
            strategy: strategy,
            recordConsumption: recordConsumption,
            agentId: agentId,
            runKey: runKey,
            threadId: threadId,
            instruction:
                'The briefing is required this wake. Call '
                'update_relationship_report now with the full briefing '
                'grounded in the FACTS block.',
          ),
        );
      }

      // A due cadence with no showing banner and no rest-of-day quiet
      // window REQUIRES the nudge — the escalation exists to speak.
      final quietToday = _dismissedToday(nudges, now);
      if (eligible &&
          cadenceDue &&
          activeAdIds.isEmpty &&
          !quietToday &&
          strategy.createdAds.isEmpty) {
        usage = _merge(
          usage,
          await _forceInstruction(
            conversationId: conversationId,
            resolved: resolved,
            inferenceRepo: inferenceRepo,
            tools: tools,
            strategy: strategy,
            recordConsumption: recordConsumption,
            agentId: agentId,
            runKey: runKey,
            threadId: threadId,
            instruction:
                'The cadence is due and no banner is showing. Call '
                'create_relationship_ad now with a warm check-in nudge '
                'referencing the FACTS.',
          ),
        );
      }

      final manager = _conversationRepository.getConversation(conversationId);
      strategy.recordFinalResponse(
        manager?.messages.reversed
            .map((m) => m.mapOrNull(assistant: (a) => a.content))
            .whereType<String>()
            .firstOrNull,
      );
      if (interactive) {
        final candidate = strategy.replyToUser ?? strategy.finalResponse;
        if (candidate == null || candidate.trim().isEmpty) {
          usage = _merge(
            usage,
            await _forceInstruction(
              conversationId: conversationId,
              resolved: resolved,
              inferenceRepo: inferenceRepo,
              tools: tools,
              strategy: strategy,
              recordConsumption: recordConsumption,
              agentId: agentId,
              runKey: runKey,
              threadId: threadId,
              instruction:
                  'The pending user message is still unanswered. Call '
                  'reply_to_user now with your complete answer.',
            ),
          );
        }
        final visibleReply = strategy.replyToUser ?? strategy.finalResponse;
        if (visibleReply == null || visibleReply.trim().isEmpty) {
          throw StateError(
            'interactive relationship turn produced no visible reply',
          );
        }
      }

      var attributionFinalized = false;
      var reportHeadAdvanced = false;
      try {
        final persistence = await persistOutputs(
          agentId: agentId,
          relationshipId: relationshipId,
          runKey: runKey,
          threadId: threadId,
          strategy: strategy,
          derivation: derivation,
          now: now,
          replyToUser: interactive,
        );
        attributionFinalized = persistence.attributionFinalized;
        reportHeadAdvanced = persistence.reportHeadAdvanced;
        outputsCommitted = true;
      } catch (error, stackTrace) {
        final replyCommitted =
            interactive && await _interactiveReplyCommitted(agentId, runKey);
        if (!replyCommitted) rethrow;
        // runInTransaction commits the whole batch before its deferred
        // outbox flush: the durable reply is the transaction marker — do
        // not fail/retry inference and duplicate the visible turn.
        outputsCommitted = true;
        attributionFinalized = strategy.hasBriefing;
        logError(
          'relationship outputs committed before deferred outbox flush '
          'failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (!attributionFinalized && recordConsumption) {
        await finalizeCarrierlessAgentAttribution(
          runKey: runKey,
          logger: this,
          status: AiWorkStatus.partial,
          errorCode: 'output_carrier_unavailable',
        );
      }

      if (usage != null && usage.hasData) {
        try {
          await _syncService.upsertEntity(
            AgentDomainEntity.wakeTokenUsage(
              id: _uuid.v4(),
              agentId: agentId,
              runKey: runKey,
              threadId: threadId,
              modelId: resolved.modelId,
              createdAt: now,
              vectorClock: null,
              inputTokens: usage.inputTokens,
              outputTokens: usage.outputTokens,
              thoughtsTokens: usage.thoughtsTokens,
              cachedInputTokens: usage.cachedInputTokens,
            ),
          );
        } catch (error, stackTrace) {
          logError(
            'failed to persist wake token usage',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      return WakeResult(success: true, reportUpdated: reportHeadAdvanced);
    } catch (error, stackTrace) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'relationshipPhaseB',
        message: 'relationship Phase B wake failed',
        stackTrace: stackTrace,
      );
      if (recordConsumption) {
        await finalizeCarrierlessAgentAttribution(
          runKey: runKey,
          logger: this,
          status: AiWorkStatus.failed,
          errorCode: error.runtimeType.toString(),
          errorSummary: error.toString(),
        );
      }
      // The consumed escalation is not re-armed by Phase A (the register
      // already transitioned) — a transient failure must not orphan the
      // episode. Only when the outputs never committed.
      if (!outputsCommitted && escalationDueDay != null) {
        await _rearmEscalation(
          agentId,
          relationshipEscalationWorkspaceKey(escalationDueDay),
          triggerTokens,
          now,
        );
      }
      return WakeResult(success: false, error: error.toString());
    } finally {
      // Clean up the in-memory conversation to prevent resource leaks
      // (the task/project workflow discipline).
      _conversationRepository.deleteConversation(conversationId);
    }
  }

  /// Persists every accumulated output in ONE transaction (the goal
  /// persistOutputs shape): the interactive reply carrier, the briefing
  /// report + head, snoozes onto their rows, and at most one new banner.
  Future<({bool attributionFinalized, bool reportHeadAdvanced})>
  persistOutputs({
    required String agentId,
    required String relationshipId,
    required String runKey,
    required String threadId,
    required RelationshipAgentStrategy strategy,
    required RelationshipCadenceDerivation derivation,
    required DateTime now,
    bool replyToUser = false,
  }) async {
    final reportId = strategy.hasBriefing ? _uuid.v4() : null;
    final attributionEnvelope = await prepareAgentReportAttribution(
      runKey: runKey,
      reportId: reportId,
    );
    var attributionFinalized = false;
    var reportHeadAdvanced = false;

    await _syncService.runInTransaction(() async {
      // The person may have been deleted while the model was thinking:
      // nothing from this wake may publish beside a deleted relationship
      // (checked INSIDE the transaction, the goal fence pattern).
      final subject = await _relationshipRepository.getRelationshipById(
        relationshipId,
      );
      if (subject == null || subject.meta.deletedAt != null) return;

      // RE-READ inside the transaction: the user may have dismissed a
      // banner while the model ran, and that dismissal binds the
      // fresh-active and quiet-window guards below.
      final rows =
          (await _repository.getEntitiesByAgentId(
                agentId,
                type: AgentEntityTypes.relationshipNudge,
              ))
              .whereType<RelationshipNudgeEntity>()
              .where((n) => n.deletedAt == null)
              .toList();
      final byId = {for (final nudge in rows) nudge.id: nudge};

      for (final action in strategy.snoozeRequests) {
        final nudge = byId[action.adId];
        if (nudge == null || nudge.status != NudgeStatus.active) continue;
        final updated =
            snoozeNudgeBannerEntity(
                  nudge: NudgeEntityView.of(nudge)!,
                  now: now,
                  until: action.until,
                  returnUtcOffsetMinutes: action.returnUtcOffsetMinutes,
                  eventId: const Uuid().v5(
                    Namespace.url.value,
                    'lotti://relationship-agent/${nudge.id}/snooze/$runKey/'
                    '${action.until.toUtc().toIso8601String()}',
                  ),
                )
                as RelationshipNudgeEntity;
        await _syncService.upsertEntity(updated);
        byId[action.adId] = updated;
      }

      final assistantText = replyToUser
          ? strategy.replyToUser ?? strategy.finalResponse
          : strategy.finalResponse;
      if (assistantText != null) {
        final persistedText = replyToUser
            ? sanitizeAgentReportText(assistantText, stripBareIds: true)
            : assistantText;
        final payloadId = replyToUser
            ? _replyPayloadId(agentId, runKey)
            : _uuid.v4();
        await _syncService.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: payloadId,
            agentId: agentId,
            createdAt: now,
            vectorClock: null,
            content: <String, Object?>{'text': persistedText},
          ),
        );
        await _syncService.upsertEntity(
          AgentDomainEntity.agentMessage(
            id: replyToUser
                ? relationshipAgentReplyMessageId(agentId, runKey)
                : _uuid.v4(),
            agentId: agentId,
            threadId: threadId,
            kind: replyToUser
                ? AgentMessageKind.action
                : AgentMessageKind.thought,
            createdAt: now,
            vectorClock: null,
            contentEntryId: payloadId,
            metadata: AgentMessageMetadata(
              runKey: runKey,
              toolName: replyToUser
                  ? AgentConversationToolNames.replyToUser
                  : null,
            ),
          ),
        );
      }

      if (reportId != null) {
        final briefing = strategy.briefing!;
        await _syncService.upsertEntity(
          AgentDomainEntity.agentReport(
            id: reportId,
            agentId: agentId,
            scope: AgentReportScopes.current,
            createdAt: now,
            vectorClock: null,
            content: sanitizeAgentReportText(
              briefing.content,
              stripBareIds: true,
            ),
            tldr: sanitizeAgentReportText(briefing.tldr, stripBareIds: true),
            oneLiner: sanitizeAgentReportText(
              briefing.oneLiner,
              stripBareIds: true,
            ),
            provenance: <String, Object?>{
              RelationshipReportProvenanceKeys.healthBand: briefing.band.name,
              RelationshipReportProvenanceKeys.healthRationale:
                  sanitizeAgentReportText(
                    briefing.rationale,
                    stripBareIds: true,
                  ),
              if (briefing.confidence != null)
                RelationshipReportProvenanceKeys.healthConfidence:
                    briefing.confidence,
              'relationshipId': relationshipId,
              'dueDayKey': derivation.dueDayKey,
              if (attributionEnvelope != null)
                aiAttributionProvenanceKey: attributionEnvelope.toJson(),
            },
            threadId: threadId,
          ),
        );
        final existingHead = await _repository.getReportHead(
          agentId,
          AgentReportScopes.current,
        );
        await _syncService.upsertEntity(
          AgentDomainEntity.agentReportHead(
            id: existingHead?.id ?? _uuid.v4(),
            agentId: agentId,
            scope: AgentReportScopes.current,
            reportId: reportId,
            updatedAt: now,
            vectorClock: null,
          ),
        );
        reportHeadAdvanced = true;
      }

      // At most ONE new banner per wake, and only when nothing fresh is
      // already speaking and today's quiet window is clear — re-checked
      // HERE so a dismissal that landed mid-inference binds (ADR 0055).
      final firstAd = strategy.createdAds.firstOrNull;
      final freshActive = byId.values.any(
        (n) => n.status == NudgeStatus.active,
      );
      if (firstAd != null && !freshActive && !_dismissedToday(rows, now)) {
        // The dock renders the brief verbatim, and the FACTS block hands the
        // model literal adId=<uuid> lines — sanitize before persisting (the
        // goal-workflow rule, shared helper). UTC stamps: updatedAt feeds the
        // nudge LWW tiebreak, and a local instant serializes without an
        // offset, shifting on a syncing peer.
        final brief = sanitizeNudgeBrief(firstAd.brief);
        await _syncService.upsertEntity(
          AgentDomainEntity.relationshipNudge(
            id: relationshipAdId(agentId, runKey),
            agentId: agentId,
            status: NudgeStatus.active,
            brief: brief,
            briefDigest: _briefDigest(brief),
            createdAt: now.toUtc(),
            updatedAt: now.toUtc(),
            vectorClock: null,
            runKey: runKey,
            threadId: threadId,
            triggerRegisterId: relationshipHealthId(agentId),
            reasonSummary: firstAd.reasonSummary,
            activatedAt: now.toUtc(),
            staleAt: now.toUtc().add(nudgeBannerLifetime),
          ),
        );
      }
    });

    // Finalize AFTER the transaction: the projection must never describe a
    // report the rolled-back (or fenced) transaction did not write.
    // Contained — a bookkeeping failure must not fail a persisted wake; the
    // session is recovered later rather than the wake reported broken (the
    // goal persistOutputs shape).
    if (reportHeadAdvanced && attributionEnvelope != null) {
      try {
        await getIt<AiAttributionService>().finalize(attributionEnvelope);
        attributionFinalized = true;
      } catch (error, stackTrace) {
        logError(
          'report attribution projection remains pending for recovery',
          error: error,
          stackTrace: stackTrace,
        );
        attributionFinalized = true;
      }
    }
    return (
      attributionFinalized: attributionFinalized,
      reportHeadAdvanced: reportHeadAdvanced,
    );
  }

  /// Near-duplicate dedupe key over the copy (the goal `briefDigest`).
  String _briefDigest(NudgeBrief brief) => const Uuid().v5(
    Namespace.url.value,
    'lotti://relationship-ad/${brief.headline.toLowerCase().trim()}/'
    '${brief.tagline?.toLowerCase().trim() ?? ''}',
  );

  bool _dismissedToday(List<RelationshipNudgeEntity> nudges, DateTime now) {
    for (final nudge in nudges) {
      final dismissedAt = nudge.dismissedForDayAt ?? nudge.dismissedAt;
      if (dismissedAt == null) continue;
      final local = dismissedAt.toLocal();
      if (local.year == now.year &&
          local.month == now.month &&
          local.day == now.day) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _interactiveReplyCommitted(String agentId, String runKey) async {
    final persisted = await _repository.getEntity(
      relationshipAgentReplyMessageId(agentId, runKey),
    );
    return persisted is AgentMessageEntity && persisted.agentId == agentId;
  }

  /// Re-arms a consumed escalation after a failure that committed nothing.
  ///
  /// The deadline is `now.toUtc()` — a strictly LATER instant than the
  /// consumed record's, so this rides the resolver's supported
  /// reschedule-beats-consume path (the goal precedent). Rebuilding the
  /// record from the derivation instead would write a pending twin at the
  /// consumed record's own deadline, and consumption is terminal at an
  /// equal instant: any peer's consumed echo would kill the retry.
  /// The ORIGINAL trigger tokens are forwarded verbatim — the baseline
  /// token carries the pre-transition cadence status, which a re-derivation
  /// after Phase A's register write can no longer reconstruct.
  /// Contained: a failed re-arm is logged, never masks the original error.
  Future<void> _rearmEscalation(
    String agentId,
    String escalationWorkspaceKey,
    Set<String> triggerTokens,
    DateTime now,
  ) async {
    try {
      await _syncService.upsertEntity(
        AgentDomainEntity.scheduledWake(
          id: scheduledWakeRecordId(
            agentId,
            workspaceKey: escalationWorkspaceKey,
          ),
          agentId: agentId,
          scheduledAt: now.toUtc(),
          status: ScheduledWakeStatus.pending,
          reason: WakeReason.scheduled.name,
          updatedAt: now,
          vectorClock: null,
          workspaceKey: escalationWorkspaceKey,
          triggerTokens: [...triggerTokens],
        ),
      );
    } catch (error, stackTrace) {
      logError(
        'failed to re-arm relationship escalation',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  InferenceUsage? _merge(InferenceUsage? a, InferenceUsage? b) =>
      a == null ? b : (b == null ? a : a.merge(b));

  Future<InferenceUsage?> _forceInstruction({
    required String conversationId,
    required RelationshipModelResolution resolved,
    required CloudInferenceWrapper inferenceRepo,
    required List<ChatCompletionTool> tools,
    required RelationshipAgentStrategy strategy,
    required bool recordConsumption,
    required String agentId,
    required String runKey,
    required String threadId,
    required String instruction,
  }) async {
    try {
      return await _conversationRepository.sendMessage(
        conversationId: conversationId,
        message: instruction,
        model: resolved.modelId,
        provider: resolved.provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: 0,
        strategy: strategy,
        consumptionAgentId: recordConsumption ? agentId : null,
        consumptionWakeRunKey: recordConsumption ? runKey : null,
        consumptionThreadId: recordConsumption ? threadId : null,
        rethrowInferenceErrors: true,
      );
    } catch (error, stackTrace) {
      // The retry is best-effort: the primary pass already succeeded and
      // its outputs must persist regardless.
      logError(
        'pinned relationship retry failed',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _persistFactsMessage({
    required String agentId,
    required String threadId,
    required String runKey,
    required String text,
    required DateTime now,
  }) async {
    final payloadId = _uuid.v4();
    await _syncService.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: agentId,
        createdAt: now,
        vectorClock: null,
        content: <String, Object?>{'text': text},
      ),
    );
    await _syncService.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: _uuid.v4(),
        agentId: agentId,
        threadId: threadId,
        kind: AgentMessageKind.system,
        createdAt: now,
        vectorClock: null,
        contentEntryId: payloadId,
        metadata: AgentMessageMetadata(runKey: runKey),
      ),
    );
  }
}
