import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/change_set.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart'
    show decisionStampAfter;
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
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/ai_error_utils.dart';
import 'package:lotti/features/ai/util/inference_provider_resolver.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/notifications/producer/agent_alert_copy.dart';
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

part 'relationship_agent_workflow_resolve_relationship_agent_model_part.dart';
part 'relationship_agent_workflow_internals.dart';

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
    required this._domainLogger,
    this._factsRenderer = const RelationshipFactsRenderer(),
    this._categoryProfileLookup,
    this._alertCopy,
  });

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final RelationshipAgentPhaseA _phaseA;
  final RelationshipRepository _relationshipRepository;
  final ConversationRepository _conversationRepository;
  final CloudInferenceRepository _cloudInferenceRepository;
  final AiConfigRepository _aiConfigRepository;
  final RelationshipFactsRenderer _factsRenderer;
  final DomainLogger _domainLogger;

  /// The person's category default profile, the third step of
  /// [resolveRelationshipAgentModel]. Null skips the category fallback.
  final CategoryProfileLookup? _categoryProfileLookup;

  /// Re-words the check-in reminder Phase A armed with the banner this wake
  /// authors, when the user allows it (ADR 0074). Optional: without it the
  /// reminder keeps its template copy, which is where the app stood before.
  final AgentAlertCopy? _alertCopy;

  @override
  DomainLogger get domainLogger => _domainLogger;

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
    // Unfiltered, like Phase A: the episode this wake consumes was armed
    // from the unfiltered read, so gating here would silently swallow a
    // private person's briefing on a device that hides private entries —
    // and burn the episode doing it.
    final relationship = await _relationshipRepository
        .getRelationshipByIdUnfiltered(relationshipId);
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
    final reportStale = relationshipEvidenceNewerThan(
      derivation,
      previousReport,
    );

    final cadenceDue = derivation.status == RelationshipCadenceStatus.due;
    final eligible =
        relationship.data.important &&
        relationship.data.status is RelationshipActive;
    // Re-derive facts FIRST and return before any inference when the armed
    // fact no longer holds (ADR 0059 Decision 3). Chat and the explicit
    // Brief me are never stood down — the user is asking directly.
    if (!interactive &&
        !reportRefresh &&
        relationshipEscalationStandsDown(
          derivation: derivation,
          previousReport: previousReport,
          escalationKey: escalationDueDay,
          eligible: eligible,
        )) {
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

    final proposals = await _repository.getProposalLedger(
      agentId,
      taskId: relationshipId,
    );
    final checkInEntries = await _relationshipRepository
        .getAllEntriesForCheckIns({
          for (final checkIn in relationshipCheckInWindow(checkIns)) checkIn.id,
        });
    final imageDescriptions = await _relationshipRepository
        .getImageDescriptions({
          for (final entries in checkInEntries.values)
            for (final entry in entries)
              if (entry is JournalImage) entry.id,
        });
    final observations = await recallAgentObservations(
      _repository,
      agentId,
      limit: relationshipObservationLookback,
    );
    var factsBlock = _factsRenderer.render(
      relationship: relationship,
      derivation: derivation,
      checkIns: checkIns,
      linkedTasks: linkedTasks,
      previousReport: previousReport,
      nudges: nudges,
      now: now,
      preTransitionStatus: preTransitionStatus,
      proposals: proposals,
      observations: observations,
      checkInEntries: checkInEntries,
      imageDescriptions: imageDescriptions,
    );
    if (interactive) {
      factsBlock =
          '$factsBlock\n\n'
          '${composeRelationshipPendingUserMessage(pendingUserMessage)}';
    }
    if (reportRefresh) {
      factsBlock = '$factsBlock\n\n$relationshipReportRefreshInstruction';
    }

    RelationshipModelResolution? resolved;
    try {
      resolved = await resolveRelationshipAgentModel(
        relationship: relationship,
        agentIdentity: agentIdentity,
        aiConfigRepository: _aiConfigRepository,
        domainLogger: _domainLogger,
        categoryProfileLookup: _categoryProfileLookup,
      );
    } catch (error, stackTrace) {
      logError(
        'failed to resolve relationship inference configuration',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
          configurationFailure: true,
        );
      }
      // A wake that never reached the model still failed: stamp it, so the
      // person page's card reads *Failed* with *Choose a model* instead of
      // waiting on a briefing that cannot come.
      await _stampWakeOutcome(agentId: agentId, succeeded: false);
      return const WakeResult(
        success: false,
        error: 'no inference provider resolves for the relationship agent',
      );
    }

    final activeAdIds = {
      for (final n in nudges.where((n) => n.status == NudgeStatus.active)) n.id,
    };
    final strategy = RelationshipAgentStrategy(
      domainLogger: domainLogger,
      syncService: _syncService,
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      activeAdIds: activeAdIds,
      sourceCheckInIds: {
        for (final entry in relationshipCheckInWindow(checkIns)) entry.id,
      },
      allowedHealthBands: relationshipHealthBandConstraint(
        checkIns: checkIns,
        cadenceStatus: derivation.status,
      )?.bands,
    );
    final tools = [
      for (final tool in relationshipAgentTools) tool.toChatCompletionTool(),
    ];
    final inferenceRepo = CloudInferenceWrapper(
      cloudRepository: _cloudInferenceRepository,
      geminiThinkingMode: resolved.geminiThinkingMode,
    );
    final recordConsumption = canRecordAgentConsumption;
    var outputsCommitted = false;
    // Created immediately before the guarded region so `finally` can always
    // delete it — an in-memory map write with nothing to clean up if it were
    // to throw.
    final conversationId = _conversationRepository.createConversation(
      systemMessage: composeAgentSystemPrompt(
        scaffold: relationshipAgentSystemPrompt,
        version: null,
        soulVersion: null,
      ),
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

    try {
      // Inside the guard: this write goes through the sync outbox, and a
      // failure here must land on the same path as any other — a WakeResult
      // rather than a raw throw, the conversation deleted, the attribution
      // finalized and the consumed escalation re-armed.
      if (!interactive) {
        await _persistFactsMessage(
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          text: factsBlock,
          now: now,
        );
      }
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
      strategy.recordFinalResponse(manager?.finalAssistantContent);
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
              instruction: relationshipReplyRequiredInstruction,
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
          inferenceSnapshot: InferenceRunSnapshot(
            runKey: runKey,
            threadId: threadId,
            executor: InferenceRouteSnapshot.fromResolvedProfile(
              resolved.setup.profile!,
            ),
            setupSource: resolved.setup.source,
            setupOrigin: resolved.setup.setupOrigin,
            profileId: resolved.profileId,
          ),
          derivation: derivation,
          now: now,
          replyToUser: interactive,
          // Eligibility binds automatic wakes only — the same rule as the
          // pre-inference gate above: chat and the explicit Brief me stay
          // answerable after un-marking.
          enforceEligibility: !interactive && !reportRefresh,
        );
        attributionFinalized = persistence.attributionFinalized;
        reportHeadAdvanced = persistence.reportHeadAdvanced;
        outputsCommitted = true;
      } catch (error, stackTrace) {
        final replyCommitted =
            interactive &&
            await isInteractiveReplyCommitted(
              repository: _repository,
              replyMessageId: relationshipAgentReplyMessageId(agentId, runKey),
              agentId: agentId,
              runKey: runKey,
            );
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

      await _stampWakeOutcome(agentId: agentId, succeeded: true);
      return WakeResult(success: true, reportUpdated: reportHeadAdvanced);
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'relationshipPhaseB',
        message: 'relationship Phase B wake failed',
        stackTrace: stackTrace,
      );
      await _stampWakeOutcome(agentId: agentId, succeeded: false);
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
          // A refused API key is a setup problem: back off like one rather
          // than retrying on every scheduler pass until the key changes.
          configurationFailure: AiErrorUtils.isAuthenticationFailure(error),
        );
      }
      return WakeResult.failed(kind: 'Relationship Phase B', error: error);
    } finally {
      // Clean up the in-memory conversation to prevent resource leaks
      // (the task/project workflow discipline).
      _conversationRepository.deleteConversation(conversationId);
    }
  }

  /// Persists every accumulated output in ONE transaction (the goal
  /// persistOutputs shape): the interactive reply carrier, the briefing
  /// report + head, snoozes onto their rows, and at most one new banner.
  ///
  /// [inferenceSnapshot] preserves the authoring route on each new report;
  /// changing the selected setup later must not rewrite historical attribution.
  ///
  /// [enforceEligibility] extends the in-transaction fence to revoked
  /// consent: an automatic wake whose relationship was un-marked
  /// `important` or archived while the model ran publishes NOTHING.
  Future<({bool attributionFinalized, bool reportHeadAdvanced})>
  persistOutputs({
    required String agentId,
    required String relationshipId,
    required String runKey,
    required String threadId,
    required RelationshipAgentStrategy strategy,
    required RelationshipCadenceDerivation derivation,
    required DateTime now,
    InferenceRunSnapshot? inferenceSnapshot,
    bool replyToUser = false,
    bool enforceEligibility = false,
  }) async {
    final reportId = strategy.hasBriefing ? _uuid.v4() : null;
    final attributionEnvelope = await prepareAgentReportAttribution(
      runKey: runKey,
      reportId: reportId,
    );
    var attributionFinalized = false;
    var reportHeadAdvanced = false;
    // The banner this wake created, if any — the words the armed reminder
    // may take once the transaction holding the banner has committed.
    NudgeBrief? alertBrief;

    await _syncService.runInTransaction(() async {
      // The person may have been deleted while the model was thinking:
      // nothing from this wake may publish beside a deleted relationship
      // (checked INSIDE the transaction, the goal fence pattern). Unfiltered
      // for the same reason as the entry read — this fence asks "was the
      // person deleted", not "is the person visible here".
      final subject = await _relationshipRepository
          .getRelationshipByIdUnfiltered(relationshipId);
      if (subject == null || subject.meta.deletedAt != null) return;
      // Consent may have been REVOKED while the model was thinking:
      // `important` is the single consent switch for proactive behavior
      // (ADR 0039), so an automatic wake re-checks eligibility inside the
      // transaction — un-marking or archiving mid-inference silences this
      // wake's report and banner, not just the next one.
      if (enforceEligibility &&
          (!subject.data.important ||
              subject.data.status is! RelationshipActive)) {
        return;
      }

      if (strategy.deferredItems.isNotEmpty &&
          subject.data.important &&
          subject.data.status is RelationshipActive) {
        final setId = const Uuid().v5(
          Namespace.url.value,
          'lotti://relationship-agent/$agentId/$runKey/proposals',
        );
        // Retry must not replace a set the user has already acted on.
        if (await _repository.getEntity(setId) == null) {
          final ledger = await _repository.getProposalLedger(
            agentId,
            taskId: relationshipId,
          );
          final fingerprints = {
            for (final entry in [...ledger.open, ...ledger.resolved])
              entry.fingerprint,
          };
          final displayKeys = {
            for (final entry in [...ledger.open, ...ledger.resolved])
              ChangeItem.displayDuplicateKeyFromParts(
                entry.toolName,
                entry.humanSummary,
                args: entry.args,
              ),
          };
          final items =
              buildDeferredChangeItems(
                    strategy.deferredItems,
                    (tool, args) => 'Create task: ${args['title']}',
                  )
                  .where(
                    (item) =>
                        fingerprints.add(ChangeItem.fingerprint(item)) &&
                        displayKeys.add(ChangeItem.displayDuplicateKey(item)),
                  )
                  .toList();
          if (items.isNotEmpty) {
            await _syncService.upsertEntity(
              AgentDomainEntity.changeSet(
                id: setId,
                agentId: agentId,
                taskId: relationshipId,
                threadId: threadId,
                runKey: runKey,
                status: ChangeSetStatus.pending,
                items: items,
                createdAt: now,
                vectorClock: null,
              ),
            );
          }
        }
      }

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

      await persistAgentObservations(
        _syncService,
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        now: now,
        observations: strategy.observations,
      );

      if (reportId != null) {
        final briefing = strategy.briefing!;
        await _syncService.upsertEntity(
          AgentDomainEntity.agentReport(
            id: reportId,
            agentId: agentId,
            scope: AgentReportScopes.current,
            createdAt: relationshipBriefingCreatedAt(now),
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
              if (inferenceSnapshot != null)
                taskAgentInferenceProvenanceKey:
                    ReportInferenceProvenance.executorOnly(
                      inferenceSnapshot,
                    ).toJson(),
              'relationshipId': relationshipId,
              'dueDayKey': derivation.dueDayKey,
              if (attributionEnvelope != null)
                aiAttributionProvenanceKey: attributionEnvelope.toJson(),
            },
            threadId: threadId,
          ),
        );
        // An out-of-order overdue escalation must not put an OLDER due day's
        // briefing back at the standing head (the goal-workflow hazard, same
        // shape): the head only advances when this wake's due day is not
        // older than the one already published, and it is stamped with the
        // due day rather than the wall clock so concurrent heads from two
        // lease-elected devices resolve by DUE DAY under generic LWW.
        final existingHead = await _repository.getReportHead(
          agentId,
          AgentReportScopes.current,
        );
        // Resolved through the head, not `getLatestReport`: the row written
        // moments ago is the newest one, so the latest report is always this
        // wake's own and would compare equal to itself.
        final publishedId = existingHead?.reportId;
        final published = publishedId == null
            ? null
            : await _repository.getEntity(publishedId);
        final publishedDueDay = published is AgentReportEntity
            ? published.provenance['dueDayKey']
            : null;
        final headMayAdvance =
            publishedDueDay is! String ||
            derivation.dueDayKey.compareTo(publishedDueDay) >= 0;
        if (headMayAdvance) {
          await _syncService.upsertEntity(
            AgentDomainEntity.agentReportHead(
              id: existingHead?.id ?? _uuid.v4(),
              agentId: agentId,
              scope: AgentReportScopes.current,
              reportId: reportId,
              updatedAt: relationshipReportHeadUpdatedAt(
                derivation.dueDayUtc,
                now,
              ),
              // Carry the head this write replaces (ADR 0068 addendum): a
              // second briefing for the same overdue due day stamps the same
              // instant, and built on no clock it would be resolved as
              // concurrent with the head and lose the tie.
              vectorClock: existingHead?.vectorClock,
            ),
          );
          reportHeadAdvanced = true;
        }
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
        alertBrief = brief;
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

    // The reminder in the agent's words — AFTER the transaction, like Phase
    // A's sink calls, so a rolled-back banner never re-words a reminder.
    if (alertBrief case final brief?) {
      await _alertCopy?.restate(subjectId: relationshipId, brief: brief);
    }

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

  InferenceUsage? _merge(InferenceUsage? a, InferenceUsage? b) =>
      a == null ? b : (b == null ? a : a.merge(b));
}
