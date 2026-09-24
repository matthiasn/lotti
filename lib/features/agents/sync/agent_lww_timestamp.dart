import 'package:lotti/features/agents/model/agent_domain_entity.dart';

/// Last-writer-wins timestamp source for [AgentDomainEntity].
extension AgentDomainEntityLwwTimestamp on AgentDomainEntity {
  /// The timestamp used for last-writer-wins comparison: the variant's
  /// `updatedAt` when it has one, otherwise its `createdAt` (append-only
  /// variants — messages, payloads, reports, observations — carry only
  /// `createdAt`).
  ///
  /// Implemented with freezed's generated, **exhaustive** `map` rather than a
  /// serialized form: **zero allocations, no serialization, no string parsing**,
  /// and **compile-time exhaustiveness** — adding a new `AgentDomainEntity`
  /// variant won't compile until it is classified here, so a missing timestamp
  /// can't slip through to a runtime failure on the sync hot path. The fields
  /// are typed, non-nullable `DateTime`s deserialized by the model, so there is
  /// nothing to cast or fail-to-parse.
  DateTime get effectiveUpdatedAt => map(
    queryChatEvent: (e) => e.deletedAt ?? e.createdAt,
    agent: (e) => e.updatedAt,
    agentState: (e) => e.updatedAt,
    agentMessage: (e) => e.createdAt,
    agentMessagePayload: (e) => e.createdAt,
    agentReport: (e) => e.createdAt,
    agentReportHead: (e) => e.updatedAt,
    scheduledWake: (e) => e.updatedAt,
    plannerKnowledge: (e) => e.updatedAt,
    capture: (e) => e.createdAt,
    parsedItem: (e) => e.createdAt,
    dayPlan: (e) => e.updatedAt,
    daySummary: (e) => e.updatedAt,
    dayDirective: (e) => e.updatedAt,
    dayStatusEvent: (e) => e.createdAt,
    weekRollup: (e) => e.updatedAt,
    attentionRequest: (e) => e.createdAt,
    attentionClaimDisposition: (e) => e.createdAt,
    attentionAward: (e) => e.createdAt,
    standingAgreement: (e) => e.updatedAt,
    agentTemplate: (e) => e.updatedAt,
    agentTemplateVersion: (e) => e.createdAt,
    agentTemplateHead: (e) => e.updatedAt,
    evolutionSession: (e) => e.updatedAt,
    evolutionSessionRecap: (e) => e.createdAt,
    evolutionNote: (e) => e.createdAt,
    changeSet: (e) => e.createdAt,
    changeDecision: (e) => e.createdAt,
    projectRecommendationRun: (e) => e.createdAt,
    projectRecommendation: (e) => e.updatedAt,
    wakeTokenUsage: (e) => e.createdAt,
    soulDocument: (e) => e.updatedAt,
    soulDocumentVersion: (e) => e.createdAt,
    soulDocumentHead: (e) => e.updatedAt,
    goalSpecVersion: (e) => e.createdAt,
    goalSpecHead: (e) => e.updatedAt,
    goalProgress: (e) => e.updatedAt,
    goalNudge: (e) => e.updatedAt,
    relationshipNudge: (e) => e.updatedAt,
    relationshipHealth: (e) => e.updatedAt,
    unknown: (e) => e.createdAt,
  );

  /// Whether last-writer-wins orders this variant by a mutable `updatedAt`
  /// (rather than the fixed `createdAt` of an append-only variant).
  bool get lwwOnUpdatedAt => _updatedAtSetter != null;

  /// This entity with `updatedAt` raised to [floor] when it is older, so a
  /// local write never sorts before the row it replaces (ADR 0068). Variants
  /// ordered by `createdAt` come back unchanged.
  AgentDomainEntity withUpdatedAtNotBefore(DateTime floor) {
    final setUpdatedAt = _updatedAtSetter;
    if (setUpdatedAt == null || !effectiveUpdatedAt.isBefore(floor)) {
      return this;
    }
    return setUpdatedAt(floor);
  }

  /// A copy-with for the variant's `updatedAt`, or null for the variants
  /// that [effectiveUpdatedAt] orders by `createdAt`. Exhaustive for the same
  /// reason: a new variant must be classified here before it compiles.
  AgentDomainEntity Function(DateTime)? get _updatedAtSetter => map(
    queryChatEvent: (_) => null,
    agent: (e) =>
        (t) => e.copyWith(updatedAt: t),
    agentState: (e) =>
        (t) => e.copyWith(updatedAt: t),
    agentMessage: (_) => null,
    agentMessagePayload: (_) => null,
    agentReport: (_) => null,
    agentReportHead: (e) =>
        (t) => e.copyWith(updatedAt: t),
    scheduledWake: (e) =>
        (t) => e.copyWith(updatedAt: t),
    plannerKnowledge: (e) =>
        (t) => e.copyWith(updatedAt: t),
    capture: (_) => null,
    parsedItem: (_) => null,
    dayPlan: (e) =>
        (t) => e.copyWith(updatedAt: t),
    daySummary: (e) =>
        (t) => e.copyWith(updatedAt: t),
    dayDirective: (e) =>
        (t) => e.copyWith(updatedAt: t),
    dayStatusEvent: (_) => null,
    weekRollup: (e) =>
        (t) => e.copyWith(updatedAt: t),
    attentionRequest: (_) => null,
    attentionClaimDisposition: (_) => null,
    attentionAward: (_) => null,
    standingAgreement: (e) =>
        (t) => e.copyWith(updatedAt: t),
    agentTemplate: (e) =>
        (t) => e.copyWith(updatedAt: t),
    agentTemplateVersion: (_) => null,
    agentTemplateHead: (e) =>
        (t) => e.copyWith(updatedAt: t),
    evolutionSession: (e) =>
        (t) => e.copyWith(updatedAt: t),
    evolutionSessionRecap: (_) => null,
    evolutionNote: (_) => null,
    changeSet: (_) => null,
    changeDecision: (_) => null,
    projectRecommendationRun: (_) => null,
    projectRecommendation: (e) =>
        (t) => e.copyWith(updatedAt: t),
    wakeTokenUsage: (_) => null,
    soulDocument: (e) =>
        (t) => e.copyWith(updatedAt: t),
    soulDocumentVersion: (_) => null,
    soulDocumentHead: (e) =>
        (t) => e.copyWith(updatedAt: t),
    goalSpecVersion: (_) => null,
    goalSpecHead: (e) =>
        (t) => e.copyWith(updatedAt: t),
    goalProgress: (e) =>
        (t) => e.copyWith(updatedAt: t),
    goalNudge: (e) =>
        (t) => e.copyWith(updatedAt: t),
    relationshipNudge: (e) =>
        (t) => e.copyWith(updatedAt: t),
    relationshipHealth: (e) =>
        (t) => e.copyWith(updatedAt: t),
    unknown: (_) => null,
  );
}
