import 'dart:convert' show utf8;

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/nudge_models.dart';
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
import 'package:lotti/features/nudges/logic/nudge_banner_snooze.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

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

/// Durable outcomes from a goal wake's transactional output batch.
class GoalOutputPersistenceResult {
  const GoalOutputPersistenceResult({
    required this.attributionFinalized,
    required this.reportHeadAdvanced,
  });

  /// Whether report-backed AI attribution has a durable carrier.
  final bool attributionFinalized;

  /// Whether this wake replaced the report selected by the current head.
  final bool reportHeadAdvanced;
}

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
    GoalChatHistoryService? chatHistoryService,
    this._factsRenderer = const GoalFactsRenderer(),
    this._checkInCompactor,
    this._checkInSourceReader,
    this._checkInDigestService,
    this._criterionNameReader,
    this._domainLogger,
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
  final DomainLogger? _domainLogger;

  @override
  DomainLogger? get domainLogger => _domainLogger;

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

  Future<String?> _previousVisibleAssistantText(
    String agentId, {
    required DateTime before,
  }) async {
    final actions =
        (await _repository.getMessagesByKindAndToolName(
              agentId,
              AgentMessageKind.action,
              AgentConversationToolNames.replyToUser,
              limit: 12,
            ))
            .where(
              (message) =>
                  message.deletedAt == null &&
                  !message.createdAt.isAfter(before) &&
                  message.metadata.toolName ==
                      AgentConversationToolNames.replyToUser &&
                  message.contentEntryId != null,
            )
            .toList()
          ..sort((a, b) {
            final byTime = b.createdAt.compareTo(a.createdAt);
            return byTime != 0 ? byTime : b.id.compareTo(a.id);
          });
    for (final action in actions) {
      final payload = await _repository.getEntity(action.contentEntryId!);
      final text =
          payload is AgentMessagePayloadEntity && payload.agentId == agentId
          ? payload.content['text']
          : null;
      if (text is String && text.trim().isNotEmpty) return text.trim();
    }
    return null;
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

    final head = await _repository.getEntity(goalSpecHeadId(agentId));
    if (head is! GoalSpecHeadEntity) {
      return pendingUserMessage == null
          ? const WakeResult(success: true)
          : const WakeResult(
              success: false,
              error: 'goal chat cannot run without a goal spec head',
            );
    }
    var version = await _repository.getEntity(head.versionId);
    if (version is! GoalSpecVersionEntity) {
      return WakeResult(
        success: false,
        error: 'goal spec head ${head.versionId} points at nothing',
      );
    }

    // A late-processed escalation (offline device, poll across midnight)
    // must evaluate the period that armed it, not the day it happens to
    // run on — the wake record is period-scoped for exactly this reason.
    final escalationPeriod = goalEscalationPeriodFromTriggerTokens(
      triggerTokens,
    );
    final overdueEscalation = _isPastPeriod(escalationPeriod, now);
    final reference = _escalationReference(escalationPeriod, now);
    // A delayed escalation may outlive a spec revision: the period's
    // register row records the version that actually armed the wake, and
    // judging the old period against new criteria would publish an
    // unrelated status. Fall back to the head when that version is gone.
    if (escalationPeriod != null) {
      final register = await _repository.getEntity(
        goalProgressId(agentId, escalationPeriod),
      );
      if (register is GoalProgressEntity &&
          register.specVersionId != version.id) {
        final armed = await _repository.getEntity(register.specVersionId);
        if (armed is GoalSpecVersionEntity) version = armed;
      }
    }
    // Disconnected same-ordinal approvals can leave TWO active version
    // rows while the head names only one. A wake resolved onto the
    // non-head active version would pay for inference the transactional
    // fence then discards — no-op here, before any message or model
    // spend. (Superseded versions pass: the stale-escalation path is
    // deliberate and report-only.)
    if (version.status == GoalSpecVersionStatus.active &&
        version.id != head.versionId) {
      return const WakeResult(success: true);
    }
    final derivation = await _phaseA.deriveWakeFacts(
      agentId: agentId,
      version: version,
      now: reference,
      timeEntryEvidenceStart: agentIdentity.createdAt,
      timeEntryEndExclusive: overdueEscalation
          ? _periodEndExclusive(escalationPeriod!)
          : null,
    );
    if (reportRefresh) {
      final persisted = await _phaseA.persistDerivation(
        agentId: agentId,
        derivation: derivation,
        now: now,
      );
      if (!persisted) return const WakeResult(success: true);
    }
    // Phase A persisted the transition's register row BEFORE arming this
    // wake, so re-deriving sees the new status as previousStatus and the
    // transition vanishes. The wake record carries the PRE-transition
    // status as a baseline token (same-day double transitions make the
    // prior-day row an insufficient reconstruction); the prior day is the
    // fallback for wakes armed before the token existed.
    final baselineName = goalEscalationBaselineFromTriggerTokens(
      triggerTokens,
    );
    final baseline = GoalTrackStatus.values
        .where((status) => status.name == baselineName)
        .firstOrNull;
    final facts = GoalWakeFacts(
      trackStatus: derivation.facts.trackStatus,
      previousStatus:
          baseline ??
          (reportRefresh
              ? derivation.facts.previousStatus
              : derivation.priors.firstOrNull?.trackStatus),
      evaluation: derivation.facts.evaluation,
      shortTermAttainment: derivation.facts.shortTermAttainment,
      quantitativeObservationsByType:
          derivation.facts.quantitativeObservationsByType,
      categoryTimeSessionsByCategory:
          derivation.facts.categoryTimeSessionsByCategory,
      labelTimeEntriesByCriterion: derivation.facts.labelTimeEntriesByCriterion,
      categoryTimeEvidenceStart: derivation.facts.categoryTimeEvidenceStart,
      categoryTimeEvidenceEnd: derivation.facts.categoryTimeEvidenceEnd,
      labelTimeEvidenceStart: derivation.facts.labelTimeEvidenceStart,
      labelTimeEvidenceEnd: derivation.facts.labelTimeEvidenceEnd,
      hasActiveCategoryTimer: derivation.facts.hasActiveCategoryTimer,
      hasActiveLabelTimer: derivation.facts.hasActiveLabelTimer,
    );

    // Spec-scoped like the persistence snapshot: an old-spec fresh
    // active must not convince _adRequired that the current goal is
    // covered, and an old-spec retired row must not be offered for
    // rerun. Dismissals pass — the quiet window binds the goal.
    final nudges =
        (await _repository.getEntitiesByAgentId(
              agentId,
              type: AgentEntityTypes.goalNudge,
            ))
            .whereType<GoalNudgeEntity>()
            .where(
              (n) =>
                  n.deletedAt == null &&
                  _specScopedRow(n, (version! as GoalSpecVersionEntity).id),
            )
            .toList();
    final resolved = await _resolveModel(agentIdentity);
    if (resolved == null) {
      // The escalation record is already consumed and Phase A will not
      // re-arm this transition — a temporarily unconfigured provider must
      // not orphan the period. The retry costs €0 until resolution works
      // (this guard aborts before any inference).
      if (escalationPeriod != null) {
        await _rearmEscalation(
          agentId,
          derivation.periodKey,
          triggerTokens,
          now,
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

    final renderedFacts = _factsRenderer.render(
      version: version,
      facts: facts,
      priorRegisters: derivation.priors,
      nudges: nudges,
      evaluationReference: reference,
      observations: observations,
      unansweredUserMessages: [?pendingUserMessage],
      recentDialogue: [
        for (final entry in recentDialogue)
          GoalChatHistoryService.toJson(entry),
      ],
      userVoice: userVoice,
      criterionNames: await _criterionNames(version.criteria),
    );
    var factsBlock = pendingUserMessage == null
        ? renderedFacts
        : '$renderedFacts\n\nPENDING USER MESSAGE:\n$pendingUserMessage';
    if (reportRefresh) {
      factsBlock =
          '$factsBlock\n\nUSER REQUESTED REPORT REFRESH AFTER WATCHED '
          'EVIDENCE CHANGED. Update the standing report from the '
          'authoritative FACTS.';
    }
    if (userRequestedReport) {
      factsBlock =
          '$factsBlock\n\nUSER EXPLICITLY ASKED FOR THE STANDING REPORT TO '
          'CHANGE. Call update_goal_report in this turn with the full '
          'rewritten report honouring their instruction; replying without it '
          'leaves the report they complained about untouched.';
    }
    if (userRequestedAd) {
      factsBlock =
          '$factsBlock\n\nUSER EXPLICITLY REQUESTED A NEW BANNER AD. This '
          'request overrides dismissal cooldown. Create the replacement now; '
          'do not claim that cooldown is system-wide or immutable.';
    }

    final conversationId = _conversationRepository.createConversation(
      systemMessage: composeAgentSystemPrompt(
        scaffold: goalAgentSystemPrompt,
        version: null,
        soulVersion: null,
      ),
      maxTurns: agentIdentity.config.maxTurnsPerWake,
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

    // The ids retire/rerun may legally reference: exactly what the FACTS
    // block offered (active ads + the reusable library).
    final activeAdIds = {
      for (final n in nudges.where((n) => n.status == NudgeStatus.active)) n.id,
    };
    final knownAdIds = {
      ...activeAdIds,
      for (final n in _factsRenderer.reusableTopRated(nudges)) n.id,
    };
    final strategy = GoalAgentStrategy(
      syncService: _syncService,
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      knownAdIds: knownAdIds,
      activeAdIds: activeAdIds,
      allowedCurrentActionCriterionIds: overdueEscalation
          ? const {}
          : _factsRenderer.healthLoggingNeededCriterionIds(
              criteria: version.criteria,
              facts: facts,
              evaluationReference: reference,
            ),
      // The deterministic status is authoritative: a report claiming
      // anything else is rejected in-conversation.
      expectedStatus: facts.trackStatus,
      expectedRollingAggregates: goalRollingAggregateStrings(
        version.criteria,
        facts.evaluation.results,
      ),
    );

    final allTools = [
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

    // A tool that is not on the wire cannot be called. The deterministic tier
    // already decides whether a banner is permitted (`automaticGoalAdEligible`
    // plus the dismissal cooldown), so on a scheduled wake that has ruled one
    // out the ad tools are simply withheld rather than offered and forbidden
    // in prose. Ad over-creation was the single largest failure mode across
    // every evaluated model, and prompt wording could only trade it against
    // skipping ads policy requires — withholding removes the choice.
    //
    // The P5 override is keyed on the DETERMINISTIC request detector, not on
    // "a message exists". Merely being spoken to is not a request for a
    // banner, and treating it as one left the ad tools on the wire for every
    // dialogue turn — the largest remaining failure class across every
    // evaluated model, and one whose calls persistence discards anyway.
    //
    // `userRequestedAd` is the same signal `interactiveAdRequested` already
    // gates persistence on, so withholding here cannot refuse a banner the
    // wake would have kept: it only stops paying to author one that the
    // transaction would drop.
    final adToolsPermitted =
        userRequestedAd ||
        (_adsEligible(facts, derivation.priors) &&
            !_factsRenderer.dismissalCooldownActive(nudges, now));
    final tools = adToolsPermitted
        ? allTools
        : [
            for (final tool in allTools)
              if (tool.function.name != GoalAgentToolNames.createGoalAd &&
                  tool.function.name != GoalAgentToolNames.rerunGoalAd)
                tool,
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
              : 'The track status changed this wake. Call update_goal_report '
                    'now with the status from the FACTS block.',
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
      strategy.recordFinalResponse(
        manager?.messages.reversed
            .map(
              (m) => m.mapOrNull(assistant: (a) => a.content),
            )
            .whereType<String>()
            .firstOrNull,
      );
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
            await _interactiveReplyCommitted(agentId, runKey);
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

      return WakeResult(
        success: true,
        reportUpdated: reportHeadAdvanced && !facts.hasActiveTrackedTimer,
      );
    } catch (error, stackTrace) {
      _domainLogger?.error(
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
        await _rearmEscalation(
          agentId,
          derivation.periodKey,
          triggerTokens,
          now,
        );
      }
      return WakeResult(success: false, error: error.toString());
    }
  }

  Future<bool> _interactiveReplyCommitted(
    String agentId,
    String runKey,
  ) async {
    final entity = await _repository.getEntity(
      goalAgentReplyMessageId(agentId, runKey),
    );
    return entity is AgentMessageEntity &&
        entity.agentId == agentId &&
        entity.metadata.runKey == runKey &&
        entity.metadata.toolName == AgentConversationToolNames.replyToUser;
  }

  /// Re-arms the period's escalation as pending, due at the current
  /// instant — a strictly later deadline than the consumed record's, so
  /// this is the resolver's supported reschedule-beats-consume path.
  /// Contained: a failed re-arm is logged, never masks the original
  /// failure.
  Future<void> _rearmEscalation(
    String agentId,
    String periodKey,
    Set<String> triggerTokens,
    DateTime now,
  ) async {
    try {
      await _syncService.upsertEntity(
        AgentDomainEntity.scheduledWake(
          id: scheduledWakeRecordId(
            agentId,
            workspaceKey: goalEscalationWorkspaceKey(periodKey),
          ),
          agentId: agentId,
          scheduledAt: now.toUtc(),
          status: ScheduledWakeStatus.pending,
          reason: WakeReason.scheduled.name,
          updatedAt: now,
          vectorClock: null,
          workspaceKey: goalEscalationWorkspaceKey(periodKey),
          triggerTokens: [for (final token in triggerTokens) token],
        ),
      );
    } catch (error, stackTrace) {
      logError(
        'failed to re-arm escalation after wake failure',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

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

  Future<InferenceUsage?> _forceAd({
    required GoalWakeFacts facts,
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
    required bool userRequestedAd,
  }) async {
    try {
      return await _conversationRepository.sendMessage(
        conversationId: conversationId,
        message: userRequestedAd
            ? 'The user explicitly requested a NEW banner ad. Dismissal '
                  'cooldown does not block this user-initiated replacement. '
                  'Call create_goal_ad now; do not refuse or merely promise '
                  'that a banner will appear.'
            : 'The goal is ${facts.trackStatus.name} with no active banner '
                  'and no cooldown — an ad is REQUIRED (policy). Call '
                  'create_goal_ad now (or rerun_goal_ad if the FACTS offered '
                  'a reusable one).',
        model: resolved.modelId,
        provider: resolved.provider,
        inferenceRepo: inferenceRepo,
        tools: [
          for (final tool in tools)
            if (tool.function.name == GoalAgentToolNames.createGoalAd ||
                (!userRequestedAd &&
                    tool.function.name == GoalAgentToolNames.rerunGoalAd))
              tool,
        ],
        toolChoice: userRequestedAd
            ? const ChatCompletionToolChoiceOption.tool(
                ChatCompletionNamedToolChoice(
                  type: ChatCompletionNamedToolChoiceType.function,
                  function: ChatCompletionFunctionCallOption(
                    name: GoalAgentToolNames.createGoalAd,
                  ),
                ),
              )
            : null,
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
        message: 'forced goal ad retry failed',
      );
      return null;
    }
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

  /// Compacts every check-in whose transcript has arrived but which has no
  /// summary yet.
  ///
  /// Idempotent by construction: the summary id is derived from
  /// `(agentId, entryId)`, so an entry already summarised is skipped and a
  /// retried compaction overwrites rather than appends. Individually
  /// contained — one unreadable recording must not cost the wake the rest of
  /// what the user said.
  Future<List<GoalCheckInSummary>> _reconcileCheckIns({
    required String agentId,
    required String goalStatement,
    required String model,
    required AiConfigInferenceProvider provider,
    required bool compactMissing,
  }) async {
    final compactor = _checkInCompactor;
    final reader = _checkInSourceReader;
    if (compactor == null || reader == null) return const [];

    final List<GoalCheckInSource> sources;
    _GoalCheckInCompactionState state;
    try {
      // ONE read of each side per wake. Reading the summaries again to render
      // user voice doubled an already-unbounded scan, which is exactly what
      // ADR 0057's bounded-read invariant forbids.
      state = await _checkInCompactionState(agentId);
      sources = await reader(agentId);
    } on Object {
      return const [];
    }

    var stored = state.summaries;
    final byEntryId = {
      for (final summary in stored) summary.sourceEntryId: summary,
    };
    final live = {for (final source in sources) source.entryId: source};

    if (compactMissing) {
      var compacted = false;
      for (final source in sources) {
        final existing = byEntryId[source.entryId];
        // Recompact when the words changed. A transcript is not final when it
        // first lands — it can be re-transcribed with a better model or edited —
        // and without this the first summary stood forever while the agent
        // coached from words that no longer existed. A summary predating the
        // digest has none, so it is refreshed once and then carries one.
        final digest = goalCheckInSourceDigest(source.text);
        if (existing != null && existing.sourceDigest == digest) continue;
        if (state.failuresByEntryId[source.entryId]?.blocks(
              digest,
              clock.now(),
            ) ??
            false) {
          continue;
        }
        await compactor.compact(
          agentId: agentId,
          entryId: source.entryId,
          recordedAt: source.recordedAt,
          transcript: source.text,
          goalStatement: goalStatement,
          model: model,
          provider: provider,
        );
        compacted = true;
      }
      if (compacted) {
        try {
          state = await _checkInCompactionState(agentId);
          stored = state.summaries;
        } on Object {
          return const [];
        }
      }
    }

    if (live.isEmpty && stored.isEmpty) return const [];
    // Only summaries whose source is still linked and live. A deleted or
    // unlinked check-in leaves its summary behind, and without this the agent
    // kept quoting words the user had removed — the timeline already hides
    // them, and the agent's view must not disagree with what the user sees.
    return [
      for (final summary in stored)
        if (live.containsKey(summary.sourceEntryId)) summary,
    ];
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
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'goalCriterionNames',
        message: 'criterion names unavailable; rendering criteria unnamed',
        stackTrace: stackTrace,
      );
      return const {};
    }
  }

  Future<List<Map<String, Object?>>> _userVoiceEntries({
    required String agentId,
    required List<GoalCheckInSummary> summaries,
    required String goalStatement,
    required String model,
    required AiConfigInferenceProvider provider,
    required bool allowInference,
    required DateTime reference,
  }) async {
    final digestService = _checkInDigestService;
    if (digestService == null || summaries.isEmpty) {
      return goalUserVoiceEntries(summaries);
    }
    try {
      final context = await HierarchicalCheckInCompaction(
        digestWriter: digestService.forWake(
          agentId: agentId,
          goalStatement: goalStatement,
          model: model,
          provider: provider,
          allowInference: allowInference,
        ),
      ).build(summaries, reference: reference);
      return context.entries;
    } catch (error, stackTrace) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'goalCheckInDigest',
        message: 'hierarchical user voice failed; falling back to the tail',
        stackTrace: stackTrace,
      );
      return goalUserVoiceEntries(summaries);
    }
  }

  /// The compacted check-ins and retry failures stored for this goal.
  ///
  /// Summaries are read whole and then token-bounded by
  /// `goalUserVoiceEntries`; failure markers stay keyed by source entry so
  /// reconciliation can apply their durable retry backoff.
  Future<_GoalCheckInCompactionState> _checkInCompactionState(
    String agentId,
  ) async {
    final messages = await _repository.getEntitiesByAgentIdAndSubtype(
      agentId,
      type: AgentEntityTypes.agentMessage,
      subtype: AgentMessageKind.action.name,
    );
    final summaries = <GoalCheckInSummary>[];
    final failuresByEntryId = <String, GoalCheckInCompactionFailure>{};
    for (final message in messages.whereType<AgentMessageEntity>()) {
      final payloadId = message.contentEntryId;
      if (payloadId == null) continue;
      final payload = await _repository.getEntity(payloadId);
      if (payload is! AgentMessagePayloadEntity) continue;
      if (message.metadata.toolName == goalCheckInSummaryToolName) {
        final summary = GoalCheckInSummary.fromContent(
          message.id,
          payload.content,
        );
        if (summary != null) summaries.add(summary);
      } else if (message.metadata.toolName ==
          goalCheckInCompactionFailureToolName) {
        final failure = GoalCheckInCompactionFailure.fromContent(
          payload.content,
        );
        if (failure != null) {
          failuresByEntryId[failure.sourceEntryId] = failure;
        }
      }
    }
    return (
      summaries: summaries,
      failuresByEntryId: failuresByEntryId,
    );
  }

  Future<List<GoalObservationFact>> _recentObservationFacts(
    String agentId,
  ) async {
    final messages = await _repository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
      limit: goalObservationLookback,
    );
    final facts = <GoalObservationFact>[];
    for (final message in messages) {
      final payloadId = message.contentEntryId;
      if (payloadId == null) continue;
      final payload = await _repository.getEntity(payloadId);
      if (payload is AgentMessagePayloadEntity) {
        final text = payload.content['text'];
        if (text is String && text.isNotEmpty) {
          facts.add((recordedAt: message.createdAt, text: text));
        }
      }
    }
    return facts;
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
        kind: AgentMessageKind.system,
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
    required String instruction,
  }) async {
    try {
      return await _conversationRepository.sendMessage(
        conversationId: conversationId,
        message: instruction,
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

  Future<InferenceUsage?> _forceReply({
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
    required bool bannerCreated,
  }) async {
    try {
      return await _conversationRepository.sendMessage(
        conversationId: conversationId,
        message: bannerCreated
            ? 'A banner was created in this wake. Call reply_to_user now with '
                  'a brief goal-focused confirmation. Do not mention cooldown.'
            : 'The user is waiting for an answer. Call reply_to_user now with '
                  'a brief response focused only on this goal and its FACTS.',
        model: resolved.modelId,
        provider: resolved.provider,
        inferenceRepo: inferenceRepo,
        tools: [
          for (final tool in tools)
            if (tool.function.name == GoalAgentToolNames.replyToUser) tool,
        ],
        toolChoice: const ChatCompletionToolChoiceOption.tool(
          ChatCompletionNamedToolChoice(
            type: ChatCompletionNamedToolChoiceType.function,
            function: ChatCompletionFunctionCallOption(
              name: GoalAgentToolNames.replyToUser,
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
    } catch (error, stackTrace) {
      logError(
        'forced interactive reply failed',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

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
  }) async {
    final factsReference = evaluationReference ?? now;
    final reportId = strategy.hasReport ? _uuid.v4() : null;
    final attributionEnvelope = await prepareAgentReportAttribution(
      runKey: runKey,
      reportId: reportId,
    );
    var attributionFinalized = false;
    var reportHeadAdvanced = false;
    var fenced = false;

    await _syncService.runInTransaction(() async {
      // A revision approved while the model was thinking moves the head
      // on — and NOTHING from this wake may then publish beside the
      // revised goal: its report and banner describe the superseded
      // target. Checked INSIDE the output transaction so a revision
      // committing between a pre-check and these writes cannot slip
      // through. The fence keys on the derivation snapshot's ACTIVE
      // status: a stale escalation deliberately evaluates the superseded
      // version that armed its period and stays exempt.
      final headNow = await _repository.getEntity(goalSpecHeadId(agentId));
      if (headNow is! GoalSpecHeadEntity) {
        // The goal was DELETED while the model ran: recreating messages,
        // reports or banners here would resurrect rows for a hard-deleted
        // agent and sync them out after the deletion.
        fenced = true;
        return;
      }
      if (derivation.version.status == GoalSpecVersionStatus.active &&
          headNow.versionId != derivation.version.id) {
        fenced = true;
        return;
      }

      // RE-READ inside the transaction, never trust the pre-inference
      // snapshot: the user may have dismissed an ad while the model was
      // thinking, and that dismissal must bind EVERY guard below — the
      // retire skips, the cooldown, and the fresh-active check alike.
      // Scoped to THIS wake's spec: a superseded-spec banner syncing in
      // late must not satisfy the fresh-active guard and suppress the
      // current goal's banner (dismissals stay visible regardless — the
      // quiet window is the goal's, not one spec version's).
      final allRows =
          (await _repository.getEntitiesByAgentId(
                agentId,
                type: AgentEntityTypes.goalNudge,
              ))
              .whereType<GoalNudgeEntity>()
              .where((n) => n.deletedAt == null)
              .toList();
      final nudges = [
        for (final nudge in allRows)
          if (_specScopedRow(nudge, derivation.version.id)) nudge,
      ];
      final byId = {for (final nudge in nudges) nudge.id: nudge};

      // Snooze is a temporary visibility preference, not a terminal ad
      // verdict. Keep the same active row and its activation/rating history;
      // the banner provider reveals it again at the persisted instant without
      // another model call.
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
                    'lotti://goal-agent/${nudge.id}/snooze/$runKey/'
                    '${action.until.toUtc().toIso8601String()}',
                  ),
                )
                as GoalNudgeEntity;
        await _syncService.upsertEntity(updated);
        // A single model turn may request several successive quiet deadlines
        // for one banner. Fold each write into the next so no append-only event
        // is overwritten by the transaction's original snapshot.
        byId[action.adId] = updated;
      }

      // Interactive replies are explicit reply_to_user action rows so the
      // durable chat projection can whitelist them without exposing thoughts.
      // Plain final prose remains a compatibility fallback for models that
      // answer before observing the new tool contract.
      final candidateAssistantText = replyToUser
          ? strategy.replyToUser ?? strategy.finalResponse
          : strategy.finalResponse;
      final assistantText =
          userRequestedAd &&
              (strategy.createdAds.isNotEmpty ||
                  strategy.rerunRequests.isNotEmpty) &&
              _isCooldownRefusal(candidateAssistantText)
          ? null
          : candidateAssistantText;
      if (assistantText != null) {
        final persistedAssistantText = replyToUser
            ? sanitizeAgentReportText(assistantText, stripBareIds: true)
            : assistantText;
        final payloadId = replyToUser
            ? _goalAgentReplyPayloadId(agentId, runKey)
            : _uuid.v4();
        await _syncService.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: payloadId,
            agentId: agentId,
            createdAt: now,
            vectorClock: null,
            content: <String, Object?>{'text': persistedAssistantText},
          ),
        );
        await _syncService.upsertEntity(
          AgentDomainEntity.agentMessage(
            id: replyToUser
                ? goalAgentReplyMessageId(agentId, runKey)
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
              operationId: replyToUser ? replyToMessageId : null,
            ),
          ),
        );
      }

      // Standing report + head (scope `current`). Sanitized: weaker
      // models echo the FACTS' internal ids into prose (the shared
      // report-writer behavior).
      if (reportId != null) {
        await _syncService.upsertEntity(
          AgentDomainEntity.agentReport(
            id: reportId,
            agentId: agentId,
            scope: AgentReportScopes.current,
            createdAt: now,
            vectorClock: null,
            content: sanitizeAgentReportText(
              strategy.reportContent ?? strategy.reportTldr!,
              stripBareIds: true,
            ),
            tldr: sanitizeAgentReportText(
              strategy.reportTldr!,
              stripBareIds: true,
            ),
            oneLiner: sanitizeAgentReportText(
              strategy.reportOneLiner!,
              stripBareIds: true,
            ),
            provenance: <String, Object?>{
              'trackStatus': strategy.reportStatus!.name,
              'periodKey': derivation.periodKey,
              'specVersionId': derivation.version.id,
              // Sanitized like every other visible string on this entity.
              // The card PREFERS these sections over the flat `content`, so
              // leaving them raw put the internal ids the sanitizer exists to
              // remove straight back in front of the reader — and made the
              // sections disagree with the sanitized fallback beneath them.
              GoalReportProvenanceKeys.sections: ?_sanitizeReportSections(
                strategy.reportSections,
              ),
              if (attributionEnvelope != null)
                aiAttributionProvenanceKey: attributionEnvelope.toJson(),
            },
            threadId: threadId,
          ),
        );
        // Out-of-order overdue escalations must not let an OLDER period
        // replace the current standing report: the head only advances
        // when this wake's period is not older than the published one.
        final existingHead = await _repository.getReportHead(
          agentId,
          AgentReportScopes.current,
        );
        final published = await _repository.getLatestReport(
          agentId,
          AgentReportScopes.current,
        );
        final publishedPeriod = published?.provenance['periodKey'];
        // A superseded-spec wake keeps its report ROW as history but
        // never advances the shared head: same-period LWW would let a
        // delayed v1 escalation hide v2's standing report behind a
        // spec-provenance filter until v2 publishes again.
        final headMayAdvance =
            derivation.version.status == GoalSpecVersionStatus.active &&
            (publishedPeriod is! String ||
                derivation.periodKey.compareTo(publishedPeriod) >= 0);
        if (headMayAdvance) {
          await _syncService.upsertEntity(
            AgentDomainEntity.agentReportHead(
              id: existingHead?.id ?? _uuid.v4(),
              agentId: agentId,
              scope: AgentReportScopes.current,
              reportId: reportId,
              // Stamped with the PERIOD's end (not the wall clock) for
              // overdue periods: two devices lease-elected onto different
              // overdue periods write concurrent head versions, and LWW
              // on this timestamp then prefers the NEWER period no matter
              // which device finished last.
              updatedAt: _headTimestamp(derivation.periodKey, now),
              vectorClock: null,
            ),
          );
          reportHeadAdvanced = true;
        }
      }

      // Deterministic recovery retire: when the authoritative status no
      // longer permits ads (back on track, recovering, data gap), every
      // still-active ad is retired HERE — the obsolete chiding banner
      // must not depend on the model remembering retire_goal_ad, nor
      // run out its 72 h staleAt.
      // A superseded-spec wake owns none of the CURRENT banners: its
      // historical facts must neither retire nor rerun rows that may
      // belong to the revised goal (creates stay — they are evidence for
      // the wake's own period, and a fresh current banner already blocks
      // them via the fresh-active guard).
      final staleSpecWake =
          derivation.version.status != GoalSpecVersionStatus.active;
      // The trend gate is for AUTOMATIC at-risk ads. In chat, a create/rerun
      // tool call is the model's structured response to the user's explicit
      // request, so every current track status is eligible. The remaining
      // persistence guards (stale spec and duplicate copy) still apply.
      final interactiveAdRequested =
          replyToUser &&
          userRequestedAd &&
          (strategy.createdAds.isNotEmpty || strategy.rerunRequests.isNotEmpty);
      final adsEligible =
          _adsEligible(derivation.facts, derivation.priors) ||
          interactiveAdRequested;
      if (!staleSpecWake && !adsEligible) {
        final modelRetired = {
          for (final action in strategy.retireRequests) action.adId,
        };
        for (final nudge in nudges) {
          if (nudge.status != NudgeStatus.active ||
              modelRetired.contains(nudge.id)) {
            continue;
          }
          await _syncService.upsertEntity(
            nudge.copyWith(
              status: NudgeStatus.retired,
              retiredAt: now.toUtc(),
              updatedAt: now,
              provenance: {
                ...nudge.provenance,
                'retireReason': 'status no longer permits ads',
              },
            ),
          );
        }
      }

      // Retire before create: a wake that swaps ads must never leave two
      // active ones if it dies between writes.
      for (final action in strategy.retireRequests) {
        if (staleSpecWake) break;
        // The in-transaction snapshot is the consistent view: only a row
        // that is STILL active retires — a dismissal (the user's
        // quiet-window verdict) or a Phase A expiry that landed first
        // survives; rewriting expired→retired would feed the clock-expired
        // ad back into the reuse library.
        final nudge = byId[action.adId];
        if (nudge == null || nudge.status != NudgeStatus.active) {
          continue;
        }
        await _syncService.upsertEntity(
          nudge.copyWith(
            status: NudgeStatus.retired,
            retiredAt: now.toUtc(),
            updatedAt: now,
            provenance: {...nudge.provenance, 'retireReason': action.reason},
          ),
        );
      }

      // A fresh dismissal blocks AUTOMATIC ad activity. A later, explicit
      // chat request supersedes that earlier quiet preference: the structured
      // create/rerun action is the model's typed evidence that the pending
      // user message asked for another banner.
      final cooldownActive = _factsRenderer.dismissalCooldownActive(
        nudges,
        now,
      );
      final cooldownBlocksAds = cooldownActive && !interactiveAdRequested;
      // Validate replacement material before retiring the currently visible
      // banner. A duplicate/replayed create request is not a replacement and
      // must leave the active activation intact.
      final seenDigests = {
        for (final nudge in nudges) nudge.briefDigest,
      };
      final creationId =
          'goal_nudge:$agentId:${derivation.periodKey}:'
          '${adCreationDiscriminator ?? escalationBaseline ?? derivation.facts.previousStatus?.name ?? 'first'}:'
          '${derivation.version.id}';
      final hasViableCreatedReplacement =
          !allRows.any((nudge) => nudge.id == creationId) &&
          strategy.createdAds.any(
            (request) => !seenDigests.contains(
              goalBriefDigest(sanitizeNudgeBrief(request.brief)),
            ),
          );
      final hasViableRerunReplacement = strategy.rerunRequests.any(
        (action) => byId[action.adId]?.status == NudgeStatus.retired,
      );
      final hasViableInteractiveReplacement =
          interactiveAdRequested &&
          (hasViableCreatedReplacement || hasViableRerunReplacement);
      // Automatic ads remain limited to offTrack or worsening atRisk (P4/P5).
      // A structured ad action on an interactive atRisk wake is the explicit
      // user-requested exception computed above.
      // A rating evaluates one activation; it does not make the card vanish
      // immediately. Once the user explicitly asks for another banner,
      // however, that rated activation is complete and is retired here so the
      // replacement can land even if the model omitted retire_goal_ad.
      final explicitlyRetiredNow = {
        for (final action in strategy.retireRequests) action.adId,
      };
      final replacedRetiredNow = <String>{};
      if (hasViableInteractiveReplacement && !staleSpecWake && adsEligible) {
        for (final nudge in nudges) {
          if (nudge.status != NudgeStatus.active ||
              explicitlyRetiredNow.contains(nudge.id)) {
            continue;
          }
          replacedRetiredNow.add(nudge.id);
          await _syncService.upsertEntity(
            nudge.copyWith(
              status: NudgeStatus.retired,
              retiredAt: now.toUtc(),
              updatedAt: now,
              provenance: {
                ...nudge.provenance,
                'retireReason': 'replaced by explicit chat request',
              },
            ),
          );
        }
      }
      // P6: a fresh active ad blocks a second one. Ads retired in THIS
      // wake don't count — explicit retire+create and rated replacement both
      // remain legal.
      final retiredNow = {...explicitlyRetiredNow, ...replacedRetiredNow};
      var freshActiveExists = nudges.any(
        (n) =>
            n.status == NudgeStatus.active &&
            !retiredNow.contains(n.id) &&
            now.difference(n.activatedAt ?? n.createdAt) < goalAdFreshFor,
      );
      for (final action in strategy.rerunRequests) {
        if (staleSpecWake) {
          logError('rerun suppressed: the wake ran under a superseded spec');
          continue;
        }
        if (!adsEligible) {
          logError('rerun suppressed: status does not permit ads');
          continue;
        }
        if (cooldownBlocksAds) {
          logError('rerun suppressed: dismissal cooldown active');
          continue;
        }
        if (freshActiveExists) {
          logError('rerun suppressed: a fresh active ad already exists');
          continue;
        }
        final nudge = byId[action.adId];
        if (nudge == null || nudge.status != NudgeStatus.retired) {
          continue;
        }
        freshActiveExists = true;
        await _syncService.upsertEntity(
          nudge.copyWith(
            status: NudgeStatus.active,
            activationCount: nudge.activationCount + 1,
            activatedAt: now.toUtc(),
            staleAt: now.toUtc().add(goalAdLifetime),
            snoozedUntil: null,
            lastSnoozeDuration: null,
            dismissedForDayAt: null,
            updatedAt: now,
            runKey: runKey,
            threadId: threadId,
            provenance: {
              ..._withoutGoalBannerSnooze(nudge.provenance),
              'rerunReason': action.reason,
              // Re-stamp the evidence fingerprint: the re-run is a fresh
              // acknowledgment of the CURRENT facts, so later Phase A
              // sweeps must compare against this wake's derivation.
              'factsDigest': goalFactsDigest(
                derivation.facts,
                criteria: derivation.version.criteria,
                evaluationReference: factsReference,
              ),
            },
          ),
        );
      }

      // Near-duplicate guard: the digest exists to stop the same copy
      // accumulating rows — across the library and within one response.
      // Automatic creation ids derive from the LOGICAL escalation — its
      // period plus the ARMING baseline carried on the wake's trigger tokens —
      // never from locally observed row counts (which differ across
      // partitions) nor from the re-derived previousStatus (which is
      // post-register and would collide when the same status recurs in
      // one day). An interactive turn instead uses its durable message id:
      // after an earlier banner retired, a user-requested replacement must
      // not collide with that transition's terminal row. Duplicate executions
      // of either wake still converge on the same id.
      // Period + arming baseline + originating spec version: duplicate
      // executions of one escalation converge (identical everything), a
      // same-day recurrence differs by baseline, and a same-day REVISION
      // producing the same baseline differs by spec — so the skip below
      // can never starve the revised goal of its required banner.
      for (final request in strategy.createdAds) {
        if (staleSpecWake) {
          logError(
            'ad creation suppressed: the wake ran under a superseded spec',
          );
          break;
        }
        if (!adsEligible) {
          logError('ad creation suppressed: status does not permit ads');
          continue;
        }
        if (cooldownBlocksAds) {
          logError('ad creation suppressed: dismissal cooldown active');
          continue;
        }
        if (freshActiveExists) {
          logError('ad creation suppressed: a fresh active ad exists');
          continue;
        }
        // Weaker models echo FACTS ids into copy; the banner renders
        // this text verbatim, so it gets the same sanitizer as reports.
        final brief = sanitizeNudgeBrief(request.brief);
        final digest = goalBriefDigest(brief);
        if (!seenDigests.add(digest)) {
          logError('ad creation skipped: duplicate brief digest');
          continue;
        }
        if (allRows.any((n) => n.id == creationId)) {
          // The SAME transition recurring within one day (offTrack →
          // recover → offTrack) maps to one id — skipping preserves the
          // earlier banner's outcome, ratings and counters, and one
          // banner per identical daily transition is the respectful
          // ceiling anyway (the digest/cooldown spirit).
          logError(
            'ad creation skipped: this transition already produced '
            "today's banner",
          );
          continue;
        }
        freshActiveExists = true;
        await _syncService.upsertEntity(
          AgentDomainEntity.goalNudge(
            id: creationId,
            agentId: agentId,
            status: NudgeStatus.active,
            brief: brief,
            briefDigest: digest,
            // UTC throughout: local instants serialize without an offset
            // and would shift the 72 h lifetime and freshness checks by
            // the zone difference on a syncing peer.
            createdAt: now.toUtc(),
            updatedAt: now.toUtc(),
            vectorClock: null,
            runKey: runKey,
            threadId: threadId,
            triggerProgressId: goalProgressId(agentId, derivation.periodKey),
            reasonSummary: request.reasonSummary,
            staleAt: now.toUtc().add(goalAdLifetime),
            activatedAt: now.toUtc(),
            // The originating spec version: a banner syncing in AFTER
            // the revision sweep carries its own fencing evidence. The
            // facts digest lets Phase A's sweep recognize the banner as
            // data-stale once new evidence changes the derivation.
            provenance: {
              'specVersionId': derivation.version.id,
              'factsDigest': goalFactsDigest(
                derivation.facts,
                criteria: derivation.version.criteria,
                evaluationReference: factsReference,
              ),
            },
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
      if (staleSpecWake && strategy.revisionProposals.isNotEmpty) {
        logError(
          'revision proposal suppressed: the wake ran under a superseded '
          'spec — approving it would distort the newer goal',
        );
      }
      if (!staleSpecWake && strategy.revisionProposals.isNotEmpty) {
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
                      // Approval is valid only while this exact immutable
                      // version remains the goal head. An offline proposal
                      // syncing in after an owner edit therefore cannot
                      // overwrite the newer goal.
                      'baseVersionId': derivation.version.id,
                      // Provenance for the minted version: the wake
                      // conversation that proposed this revision.
                      'sourceThreadId': threadId,
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
    if (fenced) {
      logError(
        'outputs fenced: spec head moved while the wake ran against '
        '${derivation.version.id}',
      );
      if (replyToUser) {
        throw StateError(
          'interactive goal turn was fenced by a concurrent spec revision',
        );
      }
      return const GoalOutputPersistenceResult(
        attributionFinalized: false,
        reportHeadAdvanced: false,
      );
    }

    // Finalize AFTER the transaction: the projection must never describe
    // a report the rolled-back transaction did not write. Contained — a
    // bookkeeping failure must not fail a persisted wake; the session is
    // recovered later rather than the wake reported broken.
    if (attributionEnvelope != null) {
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
    return GoalOutputPersistenceResult(
      attributionFinalized: attributionFinalized,
      reportHeadAdvanced: reportHeadAdvanced,
    );
  }
}

/// Conservative deterministic gate for a user-initiated replacement banner.
///
/// Cooldown overrides cannot depend on the model first agreeing to call the ad
/// tool. A missing-banner report, or a short affirmation immediately following
/// the agent's banner offer, also carries replacement intent. Visibility
/// requests such as snooze or dismiss always win.
/// The pre-rounded aggregates a report's rolling standing must quote,
/// rendered exactly as the FACTS block carries them.
///
/// Metric leaves only. A habit result's `actual` is a completion count and a
/// composite's is a count of satisfied children, so requiring those would
/// match any stray digit rather than prove the aggregate was read. Every
/// evaluated model substitutes the LATEST reading for the mean on the
/// multi-series health goal — reporting 94 kg where FACTS say 95 — which is a
/// wrong number in front of the user, not a wording preference.
///
/// A window with no observations has no aggregate to quote, and an
/// insufficientData report should name the gap instead, so empty series are
/// skipped rather than forcing the model to invent a number.
List<String> goalRollingAggregateStrings(
  GoalCriterion criteria,
  Map<String, GoalCriterionResult> results,
) {
  final metricIds = <String>{};
  void walk(GoalCriterion criterion) {
    switch (criterion) {
      case GoalCriterionMetric(:final criterionId):
        metricIds.add(criterionId);
      case GoalCriterionAllOf(:final criteria) ||
          GoalCriterionAnyOf(:final criteria) ||
          GoalCriterionAtLeastCount(:final criteria):
        criteria.forEach(walk);
      case GoalCriterionHabit() ||
          GoalCriterionMeasurable() ||
          GoalCriterionCategoryTime() ||
          GoalCriterionLabelTime():
        break;
    }
  }

  walk(criteria);
  return [
    for (final id in metricIds)
      if (results[id] case final result?)
        if (result.sampleCount > 0)
          '${roundGoalAggregate(result.actual, against: result.target)}',
  ];
}

bool isExplicitGoalAdReplacementRequest(
  String? message, {
  String? previousAssistantMessage,
}) {
  if (message == null) return false;
  final normalized = message.toLowerCase().trim();
  if (_isShortGoalAdAffirmation(normalized) &&
      _offersGoalBanner(previousAssistantMessage)) {
    return true;
  }
  final mentionsAd = RegExp(r'\b(?:banner|ad|advert)\b').hasMatch(normalized);
  if (!mentionsAd) return false;
  final declinesReplacement = RegExp(
    r"\b(?:don't|dont|do not|never)\s+"
    r'(?:want|need|replace|show|give|make|create|serve)\b',
  ).hasMatch(normalized);
  if (declinesReplacement) return false;
  final isVisibilityRequest = RegExp(
    r'\b(?:snooze|hide|dismiss|remove|stop|pause)\b',
  ).hasMatch(normalized);
  if (isVisibilityRequest) return false;
  final directReplacementVerb = RegExp(
    r'\b(?:new|another|replacement|replace|create|make|give|serve)\b',
  ).hasMatch(normalized);
  final qualifiedRequest = RegExp(
    r'\b(?:show|want|need)\b.*\b(?:new|another|replacement)\b',
  ).hasMatch(normalized);
  final requestsBanner = RegExp(
    r'\b(?:want|need)\b[^.!?]{0,80}\b(?:banner|ad|advert)\b|'
    r'\bshow\s+me\b[^.!?]{0,60}\b(?:banner|ad|advert)\b',
  ).hasMatch(normalized);
  final reportsMissingBanner = RegExp(
    r'\b(?:see|have|got)\s+no\s+(?:banner|ad|advert)\b|'
    r'\b(?:banner|ad|advert)\s+(?:is\s+)?(?:missing|not\s+(?:showing|visible))\b|'
    r"\bwhere(?:'s|\s+is)\s+(?:my\s+|the\s+)?(?:banner|ad|advert)\b",
  ).hasMatch(normalized);
  return directReplacementVerb ||
      qualifiedRequest ||
      requestsBanner ||
      reportsMissingBanner;
}

/// True when a chat message asks for the STANDING REPORT itself to change —
/// shorter, restructured, sectioned, less repetitive — rather than asking a
/// question about the goal.
///
/// The report is a stored artifact: a reply alone leaves the user reading the
/// same text they complained about. Like the ad heuristic this is an English
/// fast path that forces a forgotten tool call; the language-independent
/// carrier is the model choosing `update_goal_report` itself, which the
/// system prompt asks for explicitly.
bool isExplicitGoalReportUpdateRequest(
  String? message, {
  String? previousAssistantMessage,
}) {
  if (message == null) return false;
  final normalized = message.toLowerCase().trim();
  // "Yes, please" after the agent offers to rewrite the report is the same
  // request in its most common form; the offer is the only place the subject
  // is named, exactly as the banner path treats an affirmation.
  if (_isShortGoalAdAffirmation(normalized) &&
      _offersGoalReportRewrite(previousAssistantMessage)) {
    return true;
  }
  final mentionsReport = RegExp(
    r'\b(?:report|summary|write[-\s]?up)\b',
  ).hasMatch(normalized);
  if (!mentionsReport) return false;
  // A question ABOUT the report is not a request to rewrite it. Leading
  // interrogatives only: "can/could/would you shorten it" are requests, and
  // they are deliberately not in this set.
  final asksAboutReport = RegExp(
    r'^(?:how|what|why|when|where|which|who)\b',
  ).hasMatch(normalized);
  if (asksAboutReport) return false;
  // Negation binds loosely in real messages — "don't want you to change the
  // report", "please don't make the report shorter" — so any negation ahead
  // of a change word within the same clause declines the rewrite. Forcing a
  // rewrite against an explicit refusal overwrites a report the user asked
  // to keep, which is worse than missing an implicit request.
  final declinesChange = RegExp(
    r"\b(?:don't|dont|do not|never|no\s+need\s+to|rather\s+not|"
    r'stop|leave|keep)\b[^.!?]{0,60}\b(?:change|update|rewrite|rewriting|'
    'restructure|touch|shorten|shorter|concise|condense|trim|tighten|'
    r'split|format|structure|improve|less|make|alone|as\s+is)\b',
  ).hasMatch(normalized);
  if (declinesChange) return false;
  return RegExp(
    r'\b(?:rewrite|rewrote|restructure|reorganise|reorganize|shorten|shorter|'
    'concise|condense|trim|tighten|split|bullets?|sections?|format|structure|'
    r'update|refresh|change|improve|less)\b|'
    r'\bwall\s+of\s+text\b|'
    r'\bbreak\s+(?:it|this|that|the\s+report)?\s*up\b',
  ).hasMatch(normalized);
}

/// Whether the agent's previous visible reply OFFERED to rewrite the standing
/// report, which is what makes a bare "yes" a rewrite request.
bool _offersGoalReportRewrite(String? message) {
  if (message == null) return false;
  final normalized = message.toLowerCase();
  if (!RegExp(r'\b(?:report|summary|write[-\s]?up)\b').hasMatch(normalized)) {
    return false;
  }
  return RegExp(
    r"\b(?:if\s+you(?:'d|\s+would)?\s+(?:like|want)|want\s+me\s+to|"
    r'would\s+you\s+like|shall\s+i|should\s+i|say\s+the\s+word|'
    r'i\s+can\s+(?:rewrite|restructure|shorten|split|reformat)|'
    r'let\s+me\s+(?:rewrite|restructure|shorten|split|reformat))\b',
  ).hasMatch(normalized);
}

bool _isShortGoalAdAffirmation(String message) => RegExp(
  r'^(?:yes|yep|yeah|sure|ok|okay|please|do\s+it|go\s+ahead|make\s+it\s+happen)'
  r'(?:[,.]?\s+(?:please|now))?[.!]*$',
).hasMatch(message);

bool _offersGoalBanner(String? message) {
  if (message == null) return false;
  final normalized = message.toLowerCase();
  if (!RegExp(r'\b(?:banner|ad|advert)\b').hasMatch(normalized)) return false;
  return RegExp(
    r"\b(?:if\s+you(?:'d|\s+would)?\s+(?:like|want)|want\s+me\s+to|"
    r'would\s+you\s+like|shall\s+i|should\s+i|say\s+the\s+word|'
    r'ask\s+me|tell\s+me)\b',
  ).hasMatch(normalized);
}

/// Near-duplicate dedupe key over the banner copy: the same words with
/// different presets are the same ad.
String goalBriefDigest(NudgeBrief brief) => sha1
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

Map<String, String> _withoutGoalBannerSnooze(
  Map<String, String> provenance,
) => {
  for (final entry in provenance.entries)
    if (entry.key != nudgeBannerSnoozedUntilKey &&
        entry.key != 'snoozeReason' &&
        entry.key != 'snoozedAt')
      entry.key: entry.value,
};

/// Applies the goal report sanitizer to every string in the structured
/// sections, including each `nextActions` entry.
///
/// The values arrive as model-authored prose, exactly like `content` and
/// `tldr`, and are rendered directly.
Map<String, Object?>? _sanitizeReportSections(Map<String, Object?>? sections) {
  if (sections == null) return null;
  return {
    for (final entry in sections.entries)
      entry.key: switch (entry.value) {
        final String text => sanitizeAgentReportText(
          text,
          stripBareIds: true,
        ),
        final List<Object?> items => [
          for (final item in items)
            if (item case final String text)
              sanitizeAgentReportText(text, stripBareIds: true)
            else
              item,
        ],
        final Object? other => other,
      },
  };
}

/// Test seam for [_sanitizeReportSections] — the sanitization contract is
/// worth pinning directly rather than only through a full wake.
@visibleForTesting
Map<String, Object?>? sanitizeReportSectionsForTest(
  Map<String, Object?>? sections,
) => _sanitizeReportSections(sections);
