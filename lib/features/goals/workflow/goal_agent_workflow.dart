import 'dart:convert' show utf8;

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/util/inference_provider_resolver.dart';
import 'package:lotti/features/agents/workflow/agent_system_prompt.dart';
import 'package:lotti/features/agents/workflow/carrierless_attribution.dart';
import 'package:lotti/features/agents/workflow/deferred_change_items.dart';
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
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/goals/workflow/goal_agent_strategy.dart';
import 'package:lotti/features/goals/workflow/goal_facts_renderer.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// How long a freshly created or re-run banner may claim to be current
/// before the register data must re-justify it (ADR 0055: staleness is a
/// contract, not a hope).
const goalAdLifetime = Duration(hours: 72);

/// How many recent observations feed the FACTS block.
const goalObservationLookback = 12;

/// Phase B of the goal-agent wake (ADR 0054): the lease-elected LLM tier.
///
/// Runs only when an escalation wake fires (the router keys on the
/// `goal-escalation:<periodKey>` trigger token). One execution: re-derive
/// the deterministic facts via the SAME derivation Phase A used to arm
/// the escalation → render the FACTS block → one bounded conversation
/// against the graduated contract → persist every accumulated output in
/// one transaction. A wake that produces no tool calls writes nothing but
/// its thought — the €0-no-op discipline carried into the paid tier.
class GoalAgentWorkflow {
  GoalAgentWorkflow({
    required this._repository,
    required this._syncService,
    required this._phaseA,
    required this._conversationRepository,
    required this._cloudInferenceRepository,
    required this._aiConfigRepository,
    this._factsRenderer = const GoalFactsRenderer(),
    this._domainLogger,
  });

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final GoalAgentPhaseA _phaseA;
  final ConversationRepository _conversationRepository;
  final CloudInferenceRepository _cloudInferenceRepository;
  final AiConfigRepository _aiConfigRepository;
  final GoalFactsRenderer _factsRenderer;
  final DomainLogger? _domainLogger;

  static const _uuid = Uuid();

  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
  }) async {
    final agentId = agentIdentity.agentId;
    final now = clock.now();

    final head = await _repository.getEntity(goalSpecHeadId(agentId));
    if (head is! GoalSpecHeadEntity) {
      return const WakeResult(success: true);
    }
    final version = await _repository.getEntity(head.versionId);
    if (version is! GoalSpecVersionEntity) {
      return WakeResult(
        success: false,
        error: 'goal spec head ${head.versionId} points at nothing',
      );
    }

    final derivation = await _phaseA.deriveWakeFacts(
      agentId: agentId,
      version: version,
      now: now,
    );

    final nudges = (await _repository.getEntitiesByAgentId(
      agentId,
      type: AgentEntityTypes.goalNudge,
    )).whereType<GoalNudgeEntity>().where((n) => n.deletedAt == null).toList();
    final observations = await _recentObservationTexts(agentId);

    final facts = _factsRenderer.render(
      version: version,
      facts: derivation.facts,
      priorRegisters: derivation.priors,
      nudges: nudges,
      observations: observations,
    );

    final resolved = await _resolveModel(agentIdentity);
    if (resolved == null) {
      return const WakeResult(
        success: false,
        error: 'no inference provider resolves for the goal agent',
      );
    }

    final conversationId = _conversationRepository.createConversation(
      systemMessage: composeAgentSystemPrompt(
        scaffold: goalAgentSystemPrompt,
        version: null,
        soulVersion: null,
      ),
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

    await _persistUserMessage(
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      text: facts,
      now: now,
    );

    // The ids retire/rerun may legally reference: exactly what the FACTS
    // block offered (active ads + the reusable library).
    final knownAdIds = {
      for (final n in nudges.where((n) => n.status == GoalNudgeStatus.active))
        n.id,
      for (final n in _factsRenderer.reusableTopRated(nudges)) n.id,
    };
    final strategy = GoalAgentStrategy(
      syncService: _syncService,
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      knownAdIds: knownAdIds,
    );

    final tools = [
      for (final tool in goalAgentTools)
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

    try {
      var usage = await _conversationRepository.sendMessage(
        conversationId: conversationId,
        message: facts,
        model: resolved.modelId,
        provider: resolved.provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        // The temperature the eval matrix validated the contract at.
        temperature: 0,
        strategy: strategy,
        consumptionAgentId: recordConsumption ? agentId : null,
        consumptionWakeRunKey: recordConsumption ? runKey : null,
        consumptionThreadId: recordConsumption ? threadId : null,
        rethrowInferenceErrors: true,
      );

      // An escalation exists BECAUSE the status transitioned, so a report
      // is expected — one pinned retry, then accept the partial wake.
      // (Nothing else is ever forced: a no-op stays legal.)
      if (derivation.facts.statusTransitioned && !strategy.hasReport) {
        final retryUsage = await _forceReport(
          conversationId: conversationId,
          resolved: resolved,
          inferenceRepo: inferenceRepo,
          tools: tools,
          strategy: strategy,
          agentId: recordConsumption ? agentId : null,
          runKey: recordConsumption ? runKey : null,
          threadId: recordConsumption ? threadId : null,
        );
        if (retryUsage != null) {
          usage = usage == null ? retryUsage : usage.merge(retryUsage);
        }
      }

      final manager = _conversationRepository.getConversation(conversationId);
      strategy.recordFinalResponse(
        manager?.messages.reversed
            .map(
              (m) => m.mapOrNull(assistant: (a) => a.content),
            )
            .whereType<String>()
            .firstOrNull,
      );

      await persistOutputs(
        agentId: agentId,
        runKey: runKey,
        threadId: threadId,
        strategy: strategy,
        derivation: derivation,
        nudges: nudges,
        now: now,
      );

      if (usage != null && usage.hasData) {
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
      }

      return const WakeResult(success: true);
    } catch (error, stackTrace) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'goalPhaseB',
        message: 'goal Phase B wake failed for $agentId',
        stackTrace: stackTrace,
      );
      return WakeResult(success: false, error: error.toString());
    }
  }

  /// glm-5.2 on Melious is the validated default (the model the eval
  /// matrix proved the contract against); an AI profile on the agent's
  /// config overrides it.
  Future<
    ({
      String modelId,
      AiConfigInferenceProvider provider,
      GeminiThinkingMode? geminiThinkingMode,
    })?
  >
  _resolveModel(AgentIdentityEntity agentIdentity) async {
    final profileId = agentIdentity.config.profileId;
    if (profileId != null) {
      final profile = await ProfileResolver(
        aiConfigRepository: _aiConfigRepository,
      ).resolveByProfileId(profileId);
      if (profile != null) {
        return (
          modelId: profile.thinkingModelId,
          provider: profile.thinkingProvider,
          geminiThinkingMode: profile.thinkingModel?.geminiThinkingMode,
        );
      }
    }
    final direct = await resolveInferenceProviderWithModel(
      modelId: meliousGlm52ModelId,
      aiConfigRepository: _aiConfigRepository,
      logTag: 'GoalAgentWorkflow',
    );
    if (direct == null) return null;
    return (
      modelId: direct.model.providerModelId,
      provider: direct.provider,
      geminiThinkingMode: direct.model.geminiThinkingMode,
    );
  }

  Future<List<String>> _recentObservationTexts(String agentId) async {
    final messages = await _repository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
      limit: goalObservationLookback,
    );
    final texts = <String>[];
    for (final message in messages) {
      final payloadId = message.contentEntryId;
      if (payloadId == null) continue;
      final payload = await _repository.getEntity(payloadId);
      if (payload is AgentMessagePayloadEntity) {
        final text = payload.content['text'];
        if (text is String && text.isNotEmpty) texts.add(text);
      }
    }
    return texts;
  }

  Future<void> _persistUserMessage({
    required String agentId,
    required String threadId,
    required String runKey,
    required String text,
    required DateTime now,
  }) async {
    // Full-blob persistence (the event-agent argument): a FACTS block is
    // entirely non-derivable context, so a v2 prompt record would point
    // at an empty derivation.
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
        kind: AgentMessageKind.user,
        createdAt: now,
        vectorClock: null,
        contentEntryId: payloadId,
        metadata: AgentMessageMetadata(runKey: runKey),
      ),
    );
  }

  Future<InferenceUsage?> _forceReport({
    required String conversationId,
    required ({
      String modelId,
      AiConfigInferenceProvider provider,
      GeminiThinkingMode? geminiThinkingMode,
    })
    resolved,
    required CloudInferenceWrapper inferenceRepo,
    required List<ChatCompletionTool> tools,
    required GoalAgentStrategy strategy,
    required String? agentId,
    required String? runKey,
    required String? threadId,
  }) async {
    try {
      return await _conversationRepository.sendMessage(
        conversationId: conversationId,
        message:
            'The track status changed this wake. Call update_goal_report '
            'now with the status from the FACTS block.',
        model: resolved.modelId,
        provider: resolved.provider,
        inferenceRepo: inferenceRepo,
        tools: [
          for (final tool in tools)
            if (tool.function.name == GoalAgentToolNames.updateGoalReport) tool,
        ],
        toolChoice: const ChatCompletionToolChoiceOption.tool(
          ChatCompletionNamedToolChoice(
            type: ChatCompletionNamedToolChoiceType.function,
            function: ChatCompletionFunctionCallOption(
              name: GoalAgentToolNames.updateGoalReport,
            ),
          ),
        ),
        temperature: 0,
        strategy: strategy,
        consumptionAgentId: agentId,
        consumptionWakeRunKey: runKey,
        consumptionThreadId: threadId,
        rethrowInferenceErrors: true,
      );
    } catch (error) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'goalPhaseB',
        message: 'forced goal report retry failed',
      );
      return null;
    }
  }

  /// Visible for tests: the transactional output write is exercised
  /// directly to pin the ad-state guards (dismissal-terminal defense,
  /// rerun-requires-retired) that the in-conversation validation makes
  /// hard to reach through the loop.
  @visibleForTesting
  Future<void> persistOutputs({
    required String agentId,
    required String runKey,
    required String threadId,
    required GoalAgentStrategy strategy,
    required GoalWakeDerivation derivation,
    required List<GoalNudgeEntity> nudges,
    required DateTime now,
  }) async {
    final byId = {for (final nudge in nudges) nudge.id: nudge};
    final reportId = strategy.hasReport ? _uuid.v4() : null;
    final attributionEnvelope = await prepareAgentReportAttribution(
      runKey: runKey,
      reportId: reportId,
    );

    await _syncService.runInTransaction(() async {
      // Thought (final assistant prose — dialogue turns land here too).
      final thought = strategy.finalResponse;
      if (thought != null) {
        final payloadId = _uuid.v4();
        await _syncService.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: payloadId,
            agentId: agentId,
            createdAt: now,
            vectorClock: null,
            content: <String, Object?>{'text': thought},
          ),
        );
        await _syncService.upsertEntity(
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

      // Standing report + head (scope `current`).
      if (reportId != null) {
        await _syncService.upsertEntity(
          AgentDomainEntity.agentReport(
            id: reportId,
            agentId: agentId,
            scope: AgentReportScopes.current,
            createdAt: now,
            vectorClock: null,
            content: strategy.reportContent ?? strategy.reportTldr!,
            tldr: strategy.reportTldr,
            oneLiner: strategy.reportOneLiner,
            provenance: <String, Object?>{
              'trackStatus': strategy.reportStatus!.name,
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
      }

      // Retire before create: a wake that swaps ads must never leave two
      // active ones if it dies between writes.
      for (final action in strategy.retireRequests) {
        final nudge = byId[action.adId];
        if (nudge == null || nudge.status == GoalNudgeStatus.dismissed) {
          continue;
        }
        await _syncService.upsertEntity(
          nudge.copyWith(
            status: GoalNudgeStatus.retired,
            retiredAt: now,
            updatedAt: now,
            provenance: {...nudge.provenance, 'retireReason': action.reason},
          ),
        );
      }

      for (final action in strategy.rerunRequests) {
        final nudge = byId[action.adId];
        if (nudge == null || nudge.status != GoalNudgeStatus.retired) {
          continue;
        }
        await _syncService.upsertEntity(
          nudge.copyWith(
            status: GoalNudgeStatus.active,
            activationCount: nudge.activationCount + 1,
            activatedAt: now,
            staleAt: now.add(goalAdLifetime),
            updatedAt: now,
            runKey: runKey,
            threadId: threadId,
            provenance: {...nudge.provenance, 'rerunReason': action.reason},
          ),
        );
      }

      for (final request in strategy.createdAds) {
        await _syncService.upsertEntity(
          AgentDomainEntity.goalNudge(
            id: _uuid.v4(),
            agentId: agentId,
            status: GoalNudgeStatus.active,
            brief: request.brief,
            briefDigest: goalBriefDigest(request.brief),
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
            runKey: runKey,
            threadId: threadId,
            triggerProgressId: goalProgressId(agentId, derivation.periodKey),
            reasonSummary: request.reasonSummary,
            staleAt: now.add(goalAdLifetime),
            activatedAt: now,
          ),
        );
      }

      // Observations.
      for (final observation in strategy.observations) {
        final payloadId = _uuid.v4();
        await _syncService.upsertEntity(
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
        await _syncService.upsertEntity(
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

      // Revision proposals: ChangeSet-gated — the goal spec NEVER mutates
      // here; PR 4's approval flow mints the new version on accept.
      if (strategy.revisionProposals.isNotEmpty) {
        await _syncService.upsertEntity(
          AgentDomainEntity.changeSet(
            id: _uuid.v4(),
            agentId: agentId,
            taskId: agentId,
            threadId: threadId,
            runKey: runKey,
            status: ChangeSetStatus.pending,
            items: buildDeferredChangeItems(
              [
                for (final proposal in strategy.revisionProposals)
                  {
                    'toolName': GoalAgentToolNames.proposeGoalRevision,
                    'args': {
                      'changes': proposal.changes,
                      'rationale': proposal.rationale,
                    },
                  },
              ],
              (toolName, args) =>
                  'Goal revision proposal: '
                  '${(args['rationale'] as String?) ?? ''}',
            ),
            createdAt: now,
            vectorClock: null,
          ),
        );
      }
    });
  }
}

/// Near-duplicate dedupe key over the banner copy: the same words with
/// different presets are the same ad.
String goalBriefDigest(GoalNudgeBrief brief) => sha1
    .convert(
      utf8.encode(
        [
          brief.headline,
          brief.tagline ?? '',
          brief.cta ?? '',
        ].join('\n').toLowerCase().trim(),
      ),
    )
    .toString();
