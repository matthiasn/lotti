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
    agent: (e) => e.updatedAt,
    agentState: (e) => e.updatedAt,
    agentMessage: (e) => e.createdAt,
    agentMessagePayload: (e) => e.createdAt,
    agentReport: (e) => e.createdAt,
    agentReportHead: (e) => e.updatedAt,
    capture: (e) => e.createdAt,
    parsedItem: (e) => e.createdAt,
    dayPlan: (e) => e.updatedAt,
    agentTemplate: (e) => e.updatedAt,
    agentTemplateVersion: (e) => e.createdAt,
    agentTemplateHead: (e) => e.updatedAt,
    evolutionSession: (e) => e.updatedAt,
    evolutionSessionRecap: (e) => e.createdAt,
    evolutionNote: (e) => e.createdAt,
    changeSet: (e) => e.createdAt,
    changeDecision: (e) => e.createdAt,
    projectRecommendation: (e) => e.updatedAt,
    wakeTokenUsage: (e) => e.createdAt,
    soulDocument: (e) => e.updatedAt,
    soulDocumentVersion: (e) => e.createdAt,
    soulDocumentHead: (e) => e.updatedAt,
    unknown: (e) => e.createdAt,
  );
}
