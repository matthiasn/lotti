import 'dart:convert' show utf8;

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/features/agents/util/text_utils.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';
import 'package:lotti/features/agents/workflow/agent_system_prompt.dart';
import 'package:lotti/features/agents/workflow/agent_wake_recovery.dart';
import 'package:lotti/features/agents/workflow/carrierless_attribution.dart';
import 'package:lotti/features/agents/workflow/deferred_change_items.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/agents/workflow/wake_token_usage.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/ai_error_utils.dart';
import 'package:lotti/features/ai/util/forced_tool_choice.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/logic/goal_aggregate_rounding.dart';
import 'package:lotti/features/goals/logic/goal_checkin_compaction_strategy.dart';
import 'package:lotti/features/goals/logic/goal_user_voice.dart';
import 'package:lotti/features/goals/model/goal_checkin_source.dart';
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';
import 'package:lotti/features/goals/service/goal_chat_history_service.dart';
import 'package:lotti/features/goals/service/goal_checkin_compactor.dart';
import 'package:lotti/features/goals/service/goal_checkin_digest_service.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/goals/workflow/goal_agent_strategy.dart';
import 'package:lotti/features/goals/workflow/goal_criterion_names.dart';
import 'package:lotti/features/goals/workflow/goal_facts_renderer.dart';
import 'package:lotti/features/notifications/producer/agent_alert_copy.dart';
import 'package:lotti/features/nudges/logic/nudge_banner_snooze.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

part 'goal_agent_workflow_turns.dart';
part 'goal_agent_workflow_wake.dart';
part 'goal_agent_workflow_requests.dart';
part 'goal_agent_workflow_persistence.dart';
part 'goal_agent_workflow_helpers_part.dart';

/// Backward-compatible name used throughout the workflow and its tests.
const Duration goalAdLifetime = nudgeBannerLifetime;

/// Stable output IDs let a wake recognize that its interactive reply's
/// transaction committed even when the deferred sync-outbox flush failed.
@visibleForTesting
String goalAgentReplyMessageId(String agentId, String runKey) =>
    const Uuid().v5(
      Namespace.url.value,
      'lotti://goal-agent/$agentId/$runKey/reply',
    );

String _goalAgentReplyPayloadId(String agentId, String runKey) =>
    const Uuid().v5(
      Namespace.url.value,
      'lotti://goal-agent/$agentId/$runKey/reply-payload',
    );

/// How many recent observations feed the FACTS block.
const goalObservationLookback = 12;

typedef _GoalCheckInCompactionState = ({
  List<GoalCheckInSummary> summaries,
  Map<String, GoalCheckInCompactionFailure> failuresByEntryId,
});

/// Phase B of the goal-agent wake (ADR 0054): the lease-elected LLM tier.
///
/// Runs only when an escalation wake fires (the router keys on the
/// `goal-escalation:<periodKey>` trigger token). One execution: re-derive
/// the deterministic facts via the SAME derivation Phase A used to arm
/// the escalation → render the FACTS block → one bounded conversation
/// against the graduated contract → persist every accumulated output in
/// one transaction. A wake that produces no tool calls writes nothing but
/// its thought — the €0-no-op discipline carried into the paid tier.
class GoalAgentWorkflow with AgentErrorLogging {
  GoalAgentWorkflow({
    required this._repository,
    required this._syncService,
    required this._phaseA,
    required this._conversationRepository,
    required this._cloudInferenceRepository,
    required this._aiConfigRepository,
    required this._domainLogger,
    GoalChatHistoryService? chatHistoryService,
    this._factsRenderer = const GoalFactsRenderer(),
    this._checkInCompactor,
    this._checkInSourceReader,
    this._checkInDigestService,
    this._criterionNameReader,
    this._alertCopy,
  }) : _chatHistoryService =
           chatHistoryService ?? GoalChatHistoryService(_repository);

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final GoalAgentPhaseA _phaseA;
  final ConversationRepository _conversationRepository;
  final CloudInferenceRepository _cloudInferenceRepository;
  final AiConfigRepository _aiConfigRepository;
  final GoalChatHistoryService _chatHistoryService;
  final GoalFactsRenderer _factsRenderer;

  /// Re-words the off-track alert Phase A armed with the banner this wake
  /// authors, when the user allows it (ADR 0074). Optional: without it the
  /// alert keeps its template copy, which is where the app stood before.
  final AgentAlertCopy? _alertCopy;

  /// Names the habits and measurables the criteria refer to, so a criterion
  /// authored without a title still reaches the model with a readable name.
  /// Optional: without it such a criterion is named by nothing but its
  /// `criterionId`, which is where the app stood before the reader existed.
  final GoalCriterionNameReader? _criterionNameReader;

  /// Distills a check-in into the bounded form the agent reads. Optional: the
  /// deterministic tier and the LLM tier both work without it, and a wake with
  /// no compactor simply carries no user voice.
  final GoalCheckInCompactor? _checkInCompactor;

  /// Resolves a goal's check-ins from the journal. Injected rather than
  /// imported so this headless workflow keeps no dependency on the journal
  /// stack.
  final GoalCheckInSourceReader? _checkInSourceReader;

  /// Writes the span digests the hierarchical compaction reads. Null keeps
  /// the truncating selection: the recent tail only.
  final GoalCheckInDigestService? _checkInDigestService;
  final DomainLogger _domainLogger;

  @override
  DomainLogger get domainLogger => _domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentWorkflow;

  static const _uuid = Uuid();

  /// Resolves the durable source turn selected by the wake token, then runs
  /// the same fact-grounded workflow as an escalation with that message at
  /// the top of its priority order.
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
        error: 'goal chat source message is unavailable',
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
        error: 'goal chat source payload is unavailable',
      );
    }
    final pendingUserMessage = text.trim();
    List<GoalChatHistoryEntry> recentDialogue;
    try {
      recentDialogue = await _chatHistoryService.recentDialogue(
        agentId: agentIdentity.agentId,
        before: message,
      );
    } catch (error, stackTrace) {
      recentDialogue = const [];
      logError(
        'goal chat recent dialogue unavailable for this wake',
        error: error,
        stackTrace: stackTrace,
      );
    }
    final previousAssistantMessage =
        _isShortGoalAdAffirmation(pendingUserMessage.toLowerCase())
        ? await _previousVisibleAssistantText(
            agentIdentity.agentId,
            before: message.createdAt,
          )
        : null;
    return execute(
      agentIdentity: agentIdentity,
      runKey: runKey,
      triggerTokens: triggerTokens,
      threadId: threadId,
      pendingUserMessage: pendingUserMessage,
      previousAssistantMessage: previousAssistantMessage,
      chatMessageId: messageId,
      recentDialogue: recentDialogue,
    );
  }

  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
    String? pendingUserMessage,
    String? previousAssistantMessage,
    String? chatMessageId,
    List<GoalChatHistoryEntry> recentDialogue = const [],
  }) async {
    final agentId = agentIdentity.agentId;
    final now = clock.now();
    final reportRefresh = goalReportRefreshRequested(triggerTokens);
    var userRequestedAd = isExplicitGoalAdReplacementRequest(
      pendingUserMessage,
      previousAssistantMessage: previousAssistantMessage,
    );
    // A chat request to change the report is as binding as the detail page's
    // refresh token, but must not take the token's other effects (persisting
    // the derivation, re-basing previousStatus) — it is a rewrite of the
    // standing text, not a re-derivation of the evidence.
    final userRequestedReport = isExplicitGoalReportUpdateRequest(
      pendingUserMessage,
      previousAssistantMessage: previousAssistantMessage,
    );

    // A late-processed escalation (offline device, poll across midnight)
    // must evaluate the period that armed it, not the day it happens to
    // run on — the wake record is period-scoped for exactly this reason.
    final escalationPeriod = goalEscalationPeriodFromTriggerTokens(
      triggerTokens,
    );
    final overdueEscalation = _isPastPeriod(escalationPeriod, now);
    final reference = _escalationReference(escalationPeriod, now);
    final (:version, :exit) = await _resolveWakeSpec(
      agentId: agentId,
      escalationPeriod: escalationPeriod,
      interactive: pendingUserMessage != null,
    );
    if (version == null) return exit!;
    final derived = await _deriveForWake(
      agentIdentity: agentIdentity,
      version: version,
      triggerTokens: triggerTokens,
      now: now,
      reference: reference,
      escalationPeriod: escalationPeriod,
      overdueEscalation: overdueEscalation,
      reportRefresh: reportRefresh,
    );
    if (derived == null) return const WakeResult(success: true);
    final (:derivation, :facts) = derived;

    final nudges = await _specScopedNudges(agentId, version.id);
    final resolved = await _resolveModel(agentIdentity);
    if (resolved == null) {
      // The escalation record is already consumed and Phase A will not
      // re-arm this transition — a temporarily unconfigured provider must
      // not orphan the period. The retry costs €0 until resolution works
      // (this guard aborts before any inference).
      if (escalationPeriod != null) {
        await rearmConsumedEscalation(
          syncService: _syncService,
          agentId: agentId,
          workspaceKey: goalEscalationWorkspaceKey(derivation.periodKey),
          triggerTokens: triggerTokens,
          scheduledAt: now,
          updatedAt: now,
          logError: logError,
        );
      }
      return const WakeResult(
        success: false,
        error: 'no inference provider resolves for the goal agent',
      );
    }

    // Compact any check-in whose words are new or have changed, using the
    // wake's OWN model — the agent reads its user in the same voice it thinks
    // in — and return the summaries whose sources are still live. Non-fatal: a
    // check-in that fails to compact simply is not in this wake's context, and
    // the next wake retries.
    final checkInSummaries = await _reconcileCheckIns(
      agentId: agentId,
      goalStatement: version.statement,
      model: resolved.modelId,
      provider: resolved.provider,
      compactMissing: pendingUserMessage == null,
    );

    final observations = await _recentObservationFacts(agentId);
    // What the user said, compacted. Bounded by tokens rather than by count,
    // so a talkative fortnight cannot push the deterministic FACTS out of the
    // wake's budget.
    //
    // Contained: user voice is ADDITIVE context. A read that fails must cost
    // this wake its check-ins, never the wake itself — the deterministic FACTS
    // are what the agent is actually accountable to, and they are already
    // assembled.
    //
    // Hierarchical when a digest service is wired: the recent tail verbatim,
    // older spans as stored digests, so a two-year goal's redefinition or
    // injury stays in view (the compaction evaluation is the gate for this:
    // docs/evaluations/goal_agent_models/compaction.md). Digests are written
    // on the same wakes that compact check-ins — never on an interactive
    // turn — and a failure anywhere falls back to the truncating selection.
    final userVoice = await _userVoiceEntries(
      agentId: agentId,
      summaries: checkInSummaries,
      goalStatement: version.statement,
      model: resolved.modelId,
      provider: resolved.provider,
      allowInference: pendingUserMessage == null,
      reference: reference,
    );

    final factsBlock = await _composeFactsBlock(
      version: version,
      facts: facts,
      derivation: derivation,
      nudges: nudges,
      reference: reference,
      observations: observations,
      pendingUserMessage: pendingUserMessage,
      recentDialogue: recentDialogue,
      userVoice: userVoice,
      reportRefresh: reportRefresh,
      userRequestedReport: userRequestedReport,
      userRequestedAd: userRequestedAd,
    );

    if (pendingUserMessage == null) {
      await _persistUserMessage(
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        text: factsBlock,
        now: now,
      );
    }

    final strategy = _goalStrategy(
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      nudges: nudges,
      version: version,
      facts: facts,
      reference: reference,
      overdueEscalation: overdueEscalation,
    );

    final allTools = [
      for (final tool in goalAgentTools) tool.toChatCompletionTool(),
    ];
    final tools = _wakeTools(
      allTools: allTools,
      facts: facts,
      derivation: derivation,
      nudges: nudges,
      now: now,
      userRequestedAd: userRequestedAd,
      pendingUserMessage: pendingUserMessage,
    );
    final inferenceRepo = CloudInferenceWrapper(
      cloudRepository: _cloudInferenceRepository,
      geminiThinkingMode: resolved.geminiThinkingMode,
    );
    final recordConsumption = canRecordAgentConsumption;
    var outputsCommitted = false;
    // Created immediately before the guarded region so `finally` can always
    // delete it — the repository's conversation map lives as long as the app.
    final conversationId = _conversationRepository.createConversation(
      systemMessage: composeAgentSystemPrompt(
        scaffold: goalAgentSystemPrompt,
        version: null,
        soulVersion: null,
      ),
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

    try {
      var usage = await _conversationRepository.sendMessage(
        conversationId: conversationId,
        message: factsBlock,
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

      // Two language-independent intent carriers, because the English
      // heuristic above must never be the only way a localized request
      // bypasses the automatic health/cooldown gates.
      //
      // The typed ad action is one — but it cannot fire on a wake whose ad
      // tools were withheld, which is exactly the ineligible interactive case
      // the gate now covers. So the reply carries the intent as data instead:
      // the model reads the message in the user's own language and says
      // whether a banner was asked for, and the deterministic tier decides.
      userRequestedAd =
          userRequestedAd ||
          (pendingUserMessage != null &&
              (strategy.createdAds.isNotEmpty ||
                  strategy.rerunRequests.isNotEmpty)) ||
          (pendingUserMessage != null && strategy.bannerRequested);

      // A transition or explicit detail-page refresh requires a report — one
      // pinned retry, then accept the partial wake. Ordinary automatic no-ops
      // remain legal and free of forced output.
      if ((facts.statusTransitioned || reportRefresh || userRequestedReport) &&
          !strategy.hasReport) {
        final retryUsage = await _forceReport(
          conversationId: conversationId,
          resolved: resolved,
          inferenceRepo: inferenceRepo,
          tools: tools,
          strategy: strategy,
          agentId: recordConsumption ? agentId : null,
          runKey: recordConsumption ? runKey : null,
          threadId: recordConsumption ? threadId : null,
          // Say which of the three reasons forced this, so the retry cannot
          // describe a habit-day edit the user never made.
          instruction: userRequestedReport
              ? 'The user asked in chat for the standing report itself to '
                    'change. Call update_goal_report now with the full '
                    'rewritten report honouring their instruction, keeping '
                    'every value faithful to the FACTS block.'
              : reportRefresh
              ? 'The user explicitly requested a standing-report refresh '
                    'after editing a habit day. Call update_goal_report now '
                    'with the status and current evidence from the FACTS '
                    'block.'
              : goalStatusTransitionReportInstruction,
        );
        if (retryUsage != null) {
          usage = usage == null ? retryUsage : usage.merge(retryUsage);
        }
      }

      // Policy row P5 is deterministic: offTrack + no fresh active ad +
      // no cooldown REQUIRES an ad, and no later wake will re-arm this
      // escalation (the status already persisted). One pinned retry.
      if (_adRequired(
            facts,
            derivation.priors,
            nudges,
            strategy,
            now,
            userRequestedAd: userRequestedAd,
          ) &&
          !_hasViableAdAction(strategy, nudges)) {
        final retryUsage = await _forceAd(
          facts: facts,
          conversationId: conversationId,
          resolved: resolved,
          inferenceRepo: inferenceRepo,
          // The full surface on purpose: this path runs only when the
          // deterministic tier says an ad is REQUIRED, which is exactly the
          // case the main turn's narrowing must not be able to veto.
          tools: allTools,
          strategy: strategy,
          agentId: recordConsumption ? agentId : null,
          runKey: recordConsumption ? runKey : null,
          threadId: recordConsumption ? threadId : null,
          userRequestedAd: userRequestedAd,
        );
        if (retryUsage != null) {
          usage = usage == null ? retryUsage : usage.merge(retryUsage);
        }
      }

      // A batch can contain a plausible reply alongside a rejected mutation.
      // Persisting that reply would hide the tool error and tell the user the
      // request succeeded. Fail the interactive wake so the existing retry UI
      // remains truthful and no accepted mutation from the mixed batch lands.
      if (pendingUserMessage != null &&
          strategy.unresolvedRejectedTools.isNotEmpty) {
        strategy.discardVisibleReply();
        throw StateError(
          'interactive goal turn left rejected tools unresolved: '
          '${strategy.unresolvedRejectedTools.join(', ')}',
        );
      }

      final manager = _conversationRepository.getConversation(conversationId);
      strategy.recordFinalResponse(manager?.finalAssistantContent);
      if (pendingUserMessage != null) {
        final candidate = strategy.replyToUser ?? strategy.finalResponse;
        final staleAdRefusal =
            userRequestedAd &&
            (strategy.createdAds.isNotEmpty ||
                strategy.rerunRequests.isNotEmpty) &&
            _isCooldownRefusal(candidate);
        if (candidate == null || candidate.trim().isEmpty || staleAdRefusal) {
          strategy.discardVisibleReply();
          final replyUsage = await _forceReply(
            conversationId: conversationId,
            resolved: resolved,
            inferenceRepo: inferenceRepo,
            tools: tools,
            strategy: strategy,
            agentId: recordConsumption ? agentId : null,
            runKey: recordConsumption ? runKey : null,
            threadId: recordConsumption ? threadId : null,
            bannerCreated:
                strategy.createdAds.isNotEmpty ||
                strategy.rerunRequests.isNotEmpty,
          );
          if (replyUsage != null) {
            usage = usage == null ? replyUsage : usage.merge(replyUsage);
          }
        }
        final visibleReply = strategy.replyToUser ?? strategy.finalResponse;
        if (visibleReply == null || visibleReply.trim().isEmpty) {
          throw StateError('interactive goal turn produced no visible reply');
        }
      }

      var attributionFinalized = false;
      var reportHeadAdvanced = false;
      try {
        final persistence = await persistOutputs(
          agentId: agentId,
          runKey: runKey,
          threadId: threadId,
          strategy: strategy,
          derivation: derivation,
          now: now,
          evaluationReference: reference,
          escalationBaseline: goalEscalationBaselineFromTriggerTokens(
            triggerTokens,
          ),
          replyToUser: pendingUserMessage != null,
          userRequestedAd: userRequestedAd,
          adCreationDiscriminator: chatMessageId == null
              ? null
              : 'chat:$chatMessageId',
          replyToMessageId: chatMessageId,
        );
        attributionFinalized = persistence.attributionFinalized;
        reportHeadAdvanced = persistence.reportHeadAdvanced;
        outputsCommitted = true;
      } catch (error, stackTrace) {
        final replyCommitted =
            pendingUserMessage != null &&
            await isInteractiveReplyCommitted(
              repository: _repository,
              replyMessageId: goalAgentReplyMessageId(agentId, runKey),
              agentId: agentId,
              runKey: runKey,
            );
        if (!replyCommitted) rethrow;
        // runInTransaction commits the whole output batch before its deferred
        // outbox flush. The durable reply is therefore a transaction marker:
        // do not fail/retry inference and duplicate the user-visible turn.
        outputsCommitted = true;
        attributionFinalized = strategy.hasReport;
        logError(
          'goal outputs committed before deferred outbox flush failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (!attributionFinalized && recordConsumption) {
        // No report → no output carrier: close the wake's attribution
        // session explicitly or it looks perpetually in-flight in the
        // consumption surfaces.
        await finalizeCarrierlessAgentAttribution(
          runKey: runKey,
          logger: this,
          status: AiWorkStatus.partial,
          errorCode: 'output_carrier_unavailable',
        );
      }

      // Bookkeeping, contained: a failed usage row must not fail (or
      // re-run!) a wake whose outputs already committed.
      await persistWakeTokenUsage(
        syncService: _syncService,
        usage: usage,
        agentId: agentId,
        runKey: runKey,
        threadId: threadId,
        modelId: resolved.modelId,
        now: now,
        logError: logError,
      );

      return WakeResult(
        success: true,
        reportUpdated: reportHeadAdvanced && !facts.hasActiveTrackedTimer,
      );
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'goalPhaseB',
        message: 'goal Phase B wake failed',
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
      // The escalation record was consumed before this workflow ran, and
      // Phase A will not re-arm it (the transitioned status is already
      // persisted) — a transient failure must not orphan the period. But
      // ONLY when the outputs never committed: a post-commit bookkeeping
      // failure re-armed would re-bill the wake and duplicate its
      // UUID-keyed outputs.
      if (!outputsCommitted && escalationPeriod != null) {
        await rearmConsumedEscalation(
          syncService: _syncService,
          agentId: agentId,
          workspaceKey: goalEscalationWorkspaceKey(derivation.periodKey),
          triggerTokens: triggerTokens,
          // A refused API key cannot succeed until the user changes it:
          // retry a few times a day rather than on every scheduler pass.
          scheduledAt: AiErrorUtils.isAuthenticationFailure(error)
              ? now.add(authenticationFailureRetryDelay)
              : now,
          updatedAt: now,
          logError: logError,
        );
      }
      return WakeResult.failed(kind: 'Goal Phase B', error: error);
    } finally {
      // A wake's transcript and FACTS block must not outlive it.
      _conversationRepository.deleteConversation(conversationId);
    }
  }

  /// How long a Phase B wake that failed on a refused API key waits before
  /// its escalation is retried.
  static const authenticationFailureRetryDelay = Duration(hours: 6);

  /// Whether a nudge row belongs in THIS wake's view: rows from another
  /// spec version are invisible (they neither count as fresh actives nor
  /// enter the reuse pool), except dismissals — the user's quiet window
  /// binds the whole goal. Legacy rows without provenance pass.
  bool _specScopedRow(GoalNudgeEntity nudge, String versionId) {
    if (nudge.status == NudgeStatus.dismissed) return true;
    final origin = nudge.provenance['specVersionId'];
    return origin == null || origin == versionId;
  }

  /// Whether the deterministic facts permit ad activity at all: offTrack
  /// always; atRisk on the first evaluation or a worsening trend (policy
  /// rows P4/P5 plus the initial-goal acknowledgement). Every other status
  /// forbids ads — succeeding, recovering or data-gapped users are never
  /// chided.
  bool _adsEligible(GoalWakeFacts facts, List<GoalProgressEntity> priors) =>
      automaticGoalAdEligible(facts, priors);

  bool _isCooldownRefusal(String? message) {
    if (message == null) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('cooldown') &&
        RegExp(
          r"\b(?:can't|cannot|unable|refuse|blocked|no banner)\b",
        ).hasMatch(normalized);
  }

  /// The deterministic ad requirement (policy rows P4/P5): an eligible
  /// status, no fresh active ad surviving this wake's retires, and no
  /// dismissal cooldown.
  bool _adRequired(
    GoalWakeFacts facts,
    List<GoalProgressEntity> priors,
    List<GoalNudgeEntity> nudges,
    GoalAgentStrategy strategy,
    DateTime now, {
    required bool userRequestedAd,
  }) {
    if (userRequestedAd) return true;
    if (!_adsEligible(facts, priors)) return false;
    if (_factsRenderer.dismissalCooldownActive(nudges, now)) return false;
    final retired = {for (final action in strategy.retireRequests) action.adId};
    final freshActive = nudges.any(
      (n) =>
          n.status == NudgeStatus.active &&
          !retired.contains(n.id) &&
          now.difference(n.activatedAt ?? n.createdAt) < goalAdFreshFor,
    );
    return !freshActive;
  }

  /// Whether the strategy holds an ad action that will actually SURVIVE
  /// the persistence guards: any create, or a rerun whose target really
  /// is a retired row — a rerun of a stale-but-active ad would be
  /// rejected at persistence and must not satisfy the requirement.
  bool _hasViableAdAction(
    GoalAgentStrategy strategy,
    List<GoalNudgeEntity> nudges,
  ) {
    if (strategy.createdAds.isNotEmpty) return true;
    final byId = {for (final nudge in nudges) nudge.id: nudge};
    return strategy.rerunRequests.any(
      (action) => byId[action.adId]?.status == NudgeStatus.retired,
    );
  }

  /// The head's LWW timestamp: the period's last instant when the period
  /// is already over, the wall clock otherwise — so concurrent heads from
  /// different overdue periods resolve by PERIOD under generic LWW.
  DateTime _headTimestamp(String periodKey, DateTime now) {
    // UTC, deliberately: this timestamp exists to give concurrent heads
    // from different devices a PERIOD-based LWW order, and a local
    // constructor would map the same period key to different instants
    // across timezones — an eastern device's older period could outrank
    // a western device's newer one.
    final parts = _periodParts(periodKey);
    if (parts == null) return now;
    final periodEnd = DateTime.utc(parts.$1, parts.$2, parts.$3, 23, 59, 59);
    return periodEnd.isBefore(now) ? periodEnd : now;
  }

  /// The evaluation instant for an overdue period — LOCAL wall clock,
  /// unlike [_headTimestamp]: signal queries and day keys are local.
  DateTime? _periodEnd(String periodKey) {
    return _periodEndExclusive(periodKey)?.subtract(
      const Duration(microseconds: 1),
    );
  }

  /// Exclusive local end of an encoded day, preserving the final second.
  DateTime? _periodEndExclusive(String periodKey) {
    final parts = _periodParts(periodKey);
    if (parts == null) return null;
    return DateTime(parts.$1, parts.$2, parts.$3 + 1);
  }

  (int, int, int)? _periodParts(String periodKey) {
    final parts = periodKey.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return (year, month, day);
  }

  /// The instant the derivation evaluates at: the escalation's encoded
  /// day when that day is already over (evaluated at its last hour, so
  /// the whole day's data is in range), otherwise now. Day keys are
  /// lexically ordered, so a plain string compare detects a past period.
  DateTime _escalationReference(String? periodKey, DateTime now) {
    if (periodKey == null) return now;
    if (!_isPastPeriod(periodKey, now)) return now;
    return _periodEnd(periodKey) ?? now;
  }

  bool _isPastPeriod(String? periodKey, DateTime now) =>
      periodKey != null &&
      periodKey.compareTo(const GoalWindow.day().periodKey(now)) < 0;

  /// Uses the shared standalone setup/profile/default resolution chain.
  Future<
    ({
      String modelId,
      AiConfigInferenceProvider provider,
      GeminiThinkingMode? geminiThinkingMode,
    })?
  >
  _resolveModel(AgentIdentityEntity agentIdentity) async {
    final details =
        await ProfileResolver(
          aiConfigRepository: _aiConfigRepository,
          domainLogger: _domainLogger,
        ).resolveStandalone(
          agentConfig: agentIdentity.config,
          legacyModelId: meliousGlm52ModelId,
        );
    final profile = details.profile;
    if (profile == null) return null;
    return (
      modelId: profile.thinkingModelId,
      provider: profile.thinkingProvider,
      geminiThinkingMode: profile.thinkingModel?.geminiThinkingMode,
    );
  }

  /// Display names for the entities [criteria] refer to, for the renderer.
  ///
  /// Contained like the user voice: names are ADDITIVE context, and a read
  /// that fails must leave the wake with untitled criteria unnamed, never
  /// fail the wake itself.
  Future<Map<String, String>> _criterionNames(GoalCriterion criteria) async {
    final reader = _criterionNameReader;
    if (reader == null) return const {};
    final ids = goalCriterionEntityIds(criteria);
    if (ids.habitIds.isEmpty && ids.dataTypeIds.isEmpty) return const {};
    try {
      return await reader(ids);
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'goalCriterionNames',
        message: 'criterion names unavailable; rendering criteria unnamed',
        stackTrace: stackTrace,
      );
      return const {};
    }
  }

  Future<List<GoalObservationFact>> _recentObservationFacts(
    String agentId,
  ) async => [
    for (final observation in await recallAgentObservations(
      _repository,
      agentId,
      limit: goalObservationLookback,
    ))
      (recordedAt: observation.at, text: observation.text),
  ];

  /// Visible for tests: the transactional output write is exercised
  /// directly to pin the ad-state guards (dismissal-terminal defense,
  /// rerun-requires-retired) that the in-conversation validation makes
  /// hard to reach through the loop.
  /// Returns the durable report-carrier and standing-head outcomes. The caller
  /// terminalizes attribution without a carrier and only clears report
  /// staleness when the current head actually advanced.
  @visibleForTesting
  Future<GoalOutputPersistenceResult> persistOutputs({
    required String agentId,
    required String runKey,
    required String threadId,
    required GoalAgentStrategy strategy,
    required GoalWakeDerivation derivation,
    required DateTime now,
    DateTime? evaluationReference,
    String? escalationBaseline,
    bool replyToUser = false,
    bool userRequestedAd = false,
    String? adCreationDiscriminator,
    String? replyToMessageId,
  }) => _persistOutputs(
    agentId: agentId,
    runKey: runKey,
    threadId: threadId,
    strategy: strategy,
    derivation: derivation,
    now: now,
    evaluationReference: evaluationReference,
    escalationBaseline: escalationBaseline,
    replyToUser: replyToUser,
    userRequestedAd: userRequestedAd,
    adCreationDiscriminator: adCreationDiscriminator,
    replyToMessageId: replyToMessageId,
  );
}
