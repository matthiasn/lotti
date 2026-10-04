part of 'goal_agent_workflow.dart';

/// The preparation phases of [GoalAgentWorkflow.execute], in the order a
/// wake runs them: resolve the spec, derive the facts, gather the ads,
/// compose the FACTS block, then choose the strategy and the tools.
extension _GoalWakePhases on GoalAgentWorkflow {
  /// The spec version this wake evaluates — re-pointed at the version that
  /// armed a delayed escalation — or the result that ends the wake before any
  /// message or model spend.
  Future<({GoalSpecVersionEntity? version, WakeResult? exit})>
  _resolveWakeSpec({
    required String agentId,
    required String? escalationPeriod,
    required bool interactive,
  }) async {
    final head = await _repository.getEntity(goalSpecHeadId(agentId));
    if (head is! GoalSpecHeadEntity) {
      return (
        version: null,
        exit: interactive
            ? const WakeResult(
                success: false,
                error: 'goal chat cannot run without a goal spec head',
              )
            : const WakeResult(success: true),
      );
    }
    var version = await _repository.getEntity(head.versionId);
    if (version is! GoalSpecVersionEntity) {
      return (
        version: null,
        exit: WakeResult(
          success: false,
          error:
              'goal spec head ${DomainLogger.sanitizeId(head.versionId)} '
              'points at nothing',
        ),
      );
    }

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
      return (version: null, exit: const WakeResult(success: true));
    }
    return (version: version, exit: null);
  }

  /// Phase A's derivation for this wake and the facts the agent is held to,
  /// or null when the register kept moving and the wake ends fenced.
  Future<({GoalWakeDerivation derivation, GoalWakeFacts facts})?>
  _deriveForWake({
    required AgentIdentityEntity agentIdentity,
    required GoalSpecVersionEntity version,
    required Set<String> triggerTokens,
    required DateTime now,
    required DateTime reference,
    required String? escalationPeriod,
    required bool overdueEscalation,
    required bool reportRefresh,
  }) async {
    final agentId = agentIdentity.agentId;
    // Derive and persist take their turn with every other Phase A run of
    // this goal on this device (GoalAgentPhaseA.runExclusive).
    // A register that moved under the derivation is derived again. One
    // still moving after that ends the wake like a fenced write: a report
    // must describe the snapshot that was committed, and the next Phase A
    // tick re-escalates a report that no longer matches the day.
    final (derivation, persisted) = await GoalAgentPhaseA.runExclusive(
      agentId,
      () async {
        late GoalWakeDerivation derivation;
        var outcome = GoalPersistOutcome.stale;
        for (
          var attempt = 0;
          attempt < goalPersistAttempts && outcome == GoalPersistOutcome.stale;
          attempt++
        ) {
          derivation = await _phaseA.deriveWakeFacts(
            agentId: agentId,
            version: version,
            now: reference,
            timeEntryEvidenceStart: agentIdentity.createdAt,
            timeEntryEndExclusive: overdueEscalation
                ? _periodEndExclusive(escalationPeriod!)
                : null,
          );
          outcome = reportRefresh
              ? await _phaseA.persistDerivation(
                  agentId: agentId,
                  derivation: derivation,
                  now: now,
                )
              : GoalPersistOutcome.persisted;
        }
        return (derivation, outcome == GoalPersistOutcome.persisted);
      },
    );
    if (!persisted) return null;
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
    return (
      derivation: derivation,
      facts: GoalWakeFacts(
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
        labelTimeEntriesByCriterion:
            derivation.facts.labelTimeEntriesByCriterion,
        categoryTimeEvidenceStart: derivation.facts.categoryTimeEvidenceStart,
        categoryTimeEvidenceEnd: derivation.facts.categoryTimeEvidenceEnd,
        labelTimeEvidenceStart: derivation.facts.labelTimeEvidenceStart,
        labelTimeEvidenceEnd: derivation.facts.labelTimeEvidenceEnd,
        hasActiveCategoryTimer: derivation.facts.hasActiveCategoryTimer,
        hasActiveLabelTimer: derivation.facts.hasActiveLabelTimer,
      ),
    );
  }

  /// The goal's banner ads that belong to [versionId]'s spec.
  Future<List<GoalNudgeEntity>> _specScopedNudges(
    String agentId,
    String versionId,
  ) async {
    // Spec-scoped like the persistence snapshot: an old-spec fresh
    // active must not convince _adRequired that the current goal is
    // covered, and an old-spec retired row must not be offered for
    // rerun. Dismissals pass — the quiet window binds the goal.
    return (await _repository.getEntitiesByAgentId(
          agentId,
          type: AgentEntityTypes.goalNudge,
        ))
        .whereType<GoalNudgeEntity>()
        .where(
          (n) => n.deletedAt == null && _specScopedRow(n, versionId),
        )
        .toList();
  }

  /// The FACTS block this wake sends: the rendered facts, then the pending
  /// message and a note for each explicit request the user made.
  Future<String> _composeFactsBlock({
    required GoalSpecVersionEntity version,
    required GoalWakeFacts facts,
    required GoalWakeDerivation derivation,
    required List<GoalNudgeEntity> nudges,
    required DateTime reference,
    required List<GoalObservationFact> observations,
    required String? pendingUserMessage,
    required List<GoalChatHistoryEntry> recentDialogue,
    required List<Map<String, Object?>> userVoice,
    required bool reportRefresh,
    required bool userRequestedReport,
    required bool userRequestedAd,
  }) async {
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
    return factsBlock;
  }

  /// The conversation strategy that validates this wake's tool calls against
  /// the deterministic facts.
  GoalAgentStrategy _goalStrategy({
    required String agentId,
    required String threadId,
    required String runKey,
    required List<GoalNudgeEntity> nudges,
    required GoalSpecVersionEntity version,
    required GoalWakeFacts facts,
    required DateTime reference,
    required bool overdueEscalation,
  }) {
    // The ids retire/rerun may legally reference: exactly what the FACTS
    // block offered (active ads + the reusable library).
    final activeAdIds = {
      for (final n in nudges.where((n) => n.status == NudgeStatus.active)) n.id,
    };
    final knownAdIds = {
      ...activeAdIds,
      for (final n in _factsRenderer.reusableTopRated(nudges)) n.id,
    };
    return GoalAgentStrategy(
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
  }

  /// The tools this wake puts on the wire: [allTools] less the ones its
  /// deterministic tier has already ruled out.
  List<ChatCompletionTool> _wakeTools({
    required List<ChatCompletionTool> allTools,
    required GoalWakeFacts facts,
    required GoalWakeDerivation derivation,
    required List<GoalNudgeEntity> nudges,
    required DateTime now,
    required bool userRequestedAd,
    required String? pendingUserMessage,
  }) {
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
    // The same reasoning for `reply_to_user`. On a wake with no message
    // waiting, persistence reads only plain final prose and ignores the
    // reply tool entirely, so every such call was paid for and thrown away —
    // and a model that took the offer posted an unsolicited status update the
    // contract calls nagging. Withholding it makes that impossible instead of
    // merely discouraged.
    final replyPermitted = pendingUserMessage != null;
    return [
      for (final tool in allTools)
        if ((adToolsPermitted ||
                (tool.function.name != GoalAgentToolNames.createGoalAd &&
                    tool.function.name != GoalAgentToolNames.rerunGoalAd)) &&
            (replyPermitted ||
                tool.function.name != GoalAgentToolNames.replyToUser))
          tool,
    ];
  }
}
