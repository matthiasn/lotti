part of 'relationship_agent_workflow.dart';

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

/// Whether an automatic escalation ends at €0 before inference, because the
/// fact it was armed for no longer holds (ADR 0059 Decision 3).
///
/// A lapse episode stands down when the cadence is no longer due and the
/// briefing is not stale either — a check-in landing while the escalation
/// rode sync moves the due day; a refresh episode stands down when its
/// evidence has since changed again ([relationshipRefreshSuperseded]): the
/// newer change armed its own refresh, which briefs on everything. And
/// eligibility binds automatic wakes: un-marking important or archiving
/// silences the agent instantly. The one gate the run and the model
/// conformance trace share, so neither can brief where the other stands
/// down.
bool relationshipEscalationStandsDown({
  required RelationshipCadenceDerivation derivation,
  required AgentReportEntity? previousReport,
  required String? escalationKey,
  required bool eligible,
}) {
  final cadenceDue = derivation.status == RelationshipCadenceStatus.due;
  final reportStale = relationshipEvidenceNewerThan(derivation, previousReport);
  return (!cadenceDue && !reportStale) ||
      relationshipRefreshSuperseded(escalationKey, derivation) ||
      !eligible;
}

/// The agent's state row with a wake's outcome recorded at [now], the
/// instant the wake ended (ADR 0115).
///
/// Two watermarks, each merged by latest instant on every receive
/// (`mergeAgentStateCounters`): `lastWakeAt`, when the last wake completed,
/// and `lastWakeFailedAt`, when the last one failed. The last outcome was a
/// failure exactly when the failed stamp is the newer
/// ([AgentStateWakeOutcome.lastWakeFailed]), on every device alike — a
/// field decided by last-writer-wins with the row let a later unrelated
/// write carry an older outcome over a newer one. The stamp is UTC, as the
/// briefing's is, and bumped a microsecond past the stamps the row already
/// holds ([decisionStampAfter]), so an outcome written with knowledge of an
/// earlier one outranks it even when another device's clock ran ahead. The
/// bump reaches the watermark only, forced back to UTC — a 1.1.35 peer's
/// stamp is a local wall clock, and the bump would inherit its zone — and
/// never the row's `updatedAt`, which stays the wall clock: it decides
/// last-writer-wins for every field the join does not cover, and a row
/// stamped hours ahead on a peer's clock would outrank every concurrent
/// write of them for as long. The failure streak is reset or bumped as
/// before: it feeds the configuration backoff and the Stats tab, never a
/// face.
AgentStateEntity relationshipWakeOutcome(
  AgentStateEntity state, {
  required DateTime now,
  required bool succeeded,
}) {
  final endedAt = now.toUtc();
  final at = decisionStampAfter(endedAt, [
    state.lastWakeAt,
    state.lastWakeFailedAt,
  ]).toUtc();
  return state.copyWith(
    updatedAt: endedAt,
    lastWakeAt: succeeded ? at : state.lastWakeAt,
    lastWakeFailedAt: succeeded ? state.lastWakeFailedAt : at,
    consecutiveFailureCount: succeeded ? 0 : state.consecutiveFailureCount + 1,
  );
}

/// The report head's LWW timestamp: the due day's last instant once that
/// day is over, the wall clock otherwise.
///
/// UTC, deliberately — this timestamp exists to give concurrent heads from
/// different devices a DUE-DAY-based LWW order, and a local constructor
/// would map the same due day to different instants across timezones, so
/// an eastern device's older due day could outrank a western device's
/// newer one. [dueDayUtc] is already a midnight-UTC day (see
/// `RelationshipCadenceDerivation`); the wall clock is written in UTC for
/// the same reason the briefing's own stamp is
/// ([relationshipBriefingCreatedAt]).
DateTime relationshipReportHeadUpdatedAt(DateTime dueDayUtc, DateTime now) {
  final dueDayEnd = DateTime.utc(
    dueDayUtc.year,
    dueDayUtc.month,
    dueDayUtc.day,
    23,
    59,
    59,
  );
  return dueDayEnd.isBefore(now) ? dueDayEnd : now.toUtc();
}

/// The instant a briefing written at [now] is stamped with: UTC.
///
/// The row syncs, and a local instant serializes without an offset, so a
/// peer in another zone read the briefing as hours earlier or later than
/// the evidence it was written for — behind it, east of the writer — and
/// its next tick armed a refresh for evidence already briefed
/// (`specs/tla/RelationshipCadence.tla`, `ReportStampUtc`; ADR 0114). The
/// nudge beside it has always been stamped in UTC. A reader that formats
/// the stamp calls `toLocal()`; one that measures its age need not.
DateTime relationshipBriefingCreatedAt(DateTime now) => now.toUtc();

/// The resolved inference route for a relationship agent. `profileId` is
/// the profile that won the resolution chain, or null when the validated
/// default model or a direct thinking-model override routes.
typedef RelationshipModelResolution = ({
  String modelId,
  ResolvedAgentSetup setup,
  AiConfigInferenceProvider provider,
  GeminiThinkingMode? geminiThinkingMode,
  String? profileId,
});

/// Shared by Phase B, setup status and disclosure so each names the same route.
/// An explicit typed setup is authoritative (including disabled/broken).
/// Legacy agents try person profile, agent profile, category default, Settings
/// default, then the validated built-in model. Explicit/category lookups are
/// lazy; a transient fallback read cannot break an already resolved route.
/// A selected Settings default that no longer resolves fails closed instead
/// of silently sending inference to the built-in cloud model.
Future<RelationshipModelResolution?> resolveRelationshipAgentModel({
  required RelationshipEntry? relationship,
  required AgentIdentityEntity? agentIdentity,
  required AiConfigRepository aiConfigRepository,
  CategoryProfileLookup? categoryProfileLookup,
}) async {
  final profileResolver = ProfileResolver(
    aiConfigRepository: aiConfigRepository,
  );
  final setup = agentIdentity?.config.inferenceSetup;
  if (setup != null) {
    final details = await profileResolver.resolveSetup(setup);
    final profile = details.profile;
    if (profile == null) return null;
    return (
      setup: details,
      modelId: profile.thinkingModelId,
      provider: profile.thinkingProvider,
      geminiThinkingMode: profile.thinkingModel?.geminiThinkingMode,
      // A direct override must disclose its own provider, never the locality
      // of an optional base profile whose thinking slot it replaced.
      profileId: details.source == AgentSetupResolutionSource.baseProfile
          ? setup.baseProfileId
          : null,
    );
  }
  Future<RelationshipModelResolution?> viaProfile(String profileId) async {
    final profile = await profileResolver.resolveByProfileId(profileId);
    if (profile == null) return null;
    return (
      setup: ResolvedAgentSetup(
        status: AgentSetupResolutionStatus.resolved,
        profile: profile,
        source: AgentSetupResolutionSource.baseProfile,
      ),
      modelId: profile.thinkingModelId,
      provider: profile.thinkingProvider,
      geminiThinkingMode: profile.thinkingModel?.geminiThinkingMode,
      profileId: profileId,
    );
  }

  final explicitProfileIds = <String>{
    ?relationship?.data.profileId,
    ?agentIdentity?.config.profileId,
  };
  for (final profileId in explicitProfileIds) {
    final resolved = await viaProfile(profileId);
    if (resolved != null) return resolved;
  }
  final categoryId = relationship?.meta.categoryId;
  if (categoryId != null && categoryProfileLookup != null) {
    final categoryProfileId = await categoryProfileLookup(categoryId);
    if (categoryProfileId != null &&
        !explicitProfileIds.contains(categoryProfileId)) {
      final resolved = await viaProfile(categoryProfileId);
      if (resolved != null) return resolved;
    }
  }
  final defaultProfileId = await aiConfigRepository.getDefaultProfileId();
  if (defaultProfileId != null) {
    // A selected but unavailable default is actionable configuration, not
    // permission to send relationship data through an unrelated cloud model.
    return viaProfile(defaultProfileId);
  }
  final direct = await resolveInferenceProviderWithModel(
    modelId: meliousGlm52ModelId,
    aiConfigRepository: aiConfigRepository,
    logTag: 'RelationshipAgentWorkflow',
  );
  if (direct == null) return null;
  return (
    setup: ResolvedAgentSetup(
      status: AgentSetupResolutionStatus.resolved,
      source: AgentSetupResolutionSource.legacyModel,
      profile: ResolvedProfile(
        thinkingModelId: direct.model.providerModelId,
        thinkingModel: direct.model,
        thinkingProvider: direct.provider,
      ),
    ),
    modelId: direct.model.providerModelId,
    provider: direct.provider,
    geminiThinkingMode: direct.model.geminiThinkingMode,
    profileId: null,
  );
}
