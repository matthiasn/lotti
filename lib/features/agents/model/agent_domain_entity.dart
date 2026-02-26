import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'agent_domain_entity.freezed.dart';
part 'agent_domain_entity.g.dart';

@Freezed(fallbackUnion: 'unknown')
abstract class AgentDomainEntity with _$AgentDomainEntity {
  /// Agent identity and lifecycle.
  const factory AgentDomainEntity.agent({
    required String id,
    required String agentId,
    required String kind,
    required String displayName,
    required AgentLifecycle lifecycle,
    required AgentInteractionMode mode,
    required Set<String> allowedCategoryIds,
    required String currentStateId,
    required AgentConfig config,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
    DateTime? destroyedAt,
  }) = AgentIdentityEntity;

  /// Durable state snapshot.
  const factory AgentDomainEntity.agentState({
    required String id,
    required String agentId,
    required int revision,
    required AgentSlots slots,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? lastWakeAt,
    DateTime? nextWakeAt,
    DateTime? sleepUntil,
    String? recentHeadMessageId,
    String? latestSummaryMessageId,
    @Default(0) int consecutiveFailureCount,
    @Default(0) int wakeCounter,
    @Default({}) Map<String, int> processedCounterByHost,
    DateTime? deletedAt,
  }) = AgentStateEntity;

  /// Immutable message log entry.
  const factory AgentDomainEntity.agentMessage({
    required String id,
    required String agentId,
    required String threadId,
    required AgentMessageKind kind,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    required AgentMessageMetadata metadata,
    String? prevMessageId,
    String? contentEntryId,
    String? triggerSourceId,
    String? summaryStartMessageId,
    String? summaryEndMessageId,
    @Default(0) int summaryDepth,
    @Default(0) int tokensApprox,
    DateTime? deletedAt,
  }) = AgentMessageEntity;

  /// Normalized large content payload.
  const factory AgentDomainEntity.agentMessagePayload({
    required String id,
    required String agentId,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    required Map<String, Object?> content,
    @Default('application/json') String contentType,
    DateTime? deletedAt,
  }) = AgentMessagePayloadEntity;

  /// Immutable report snapshot.
  const factory AgentDomainEntity.agentReport({
    required String id,
    required String agentId,
    required String scope,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    @Default('') String content,
    double? confidence,
    @Default({}) Map<String, Object?> provenance,
    DateTime? deletedAt,
    String? threadId,
  }) = AgentReportEntity;

  /// Latest report pointer per scope.
  const factory AgentDomainEntity.agentReportHead({
    required String id,
    required String agentId,
    required String scope,
    required String reportId,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentReportHeadEntity;

  /// Agent template — reusable blueprint for agent instances.
  ///
  /// The [agentId] field stores the template's own ID (same as [id]), serving
  /// as a grouping key that links this template to its versions and head
  /// pointer. It does **not** reference an agent instance. This naming is
  /// inherited from the base entity schema to keep the DB schema uniform.
  const factory AgentDomainEntity.agentTemplate({
    required String id,
    required String agentId,
    required String displayName,
    required AgentTemplateKind kind,
    required String modelId,
    required Set<String> categoryIds,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentTemplateEntity;

  /// Immutable version of an agent template's directives.
  ///
  /// The [agentId] field stores the owning template's ID, grouping all
  /// versions under the same template. It does **not** reference an agent
  /// instance.
  const factory AgentDomainEntity.agentTemplateVersion({
    required String id,
    required String agentId,
    required int version,
    required AgentTemplateVersionStatus status,
    required String directives,
    required String authoredBy,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentTemplateVersionEntity;

  /// Mutable head pointer for the active template version.
  ///
  /// The [agentId] field stores the owning template's ID. It does **not**
  /// reference an agent instance.
  const factory AgentDomainEntity.agentTemplateHead({
    required String id,
    required String agentId,
    required String versionId,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentTemplateHeadEntity;

  /// Lightweight metadata record for a 1-on-1 evolution session.
  ///
  /// The [agentId] field stores the owning **template's ID**, enabling
  /// direct SQL lookups via `getEvolutionSessionsByTemplate`. The actual
  /// conversation messages are stored as [AgentMessageEntity] records with
  /// [AgentMessageEntity.threadId] set to this session's [id].
  ///
  /// Delta tracking (`lastAcknowledgedAt`) lives on the evolution agent's
  /// [AgentStateEntity], not here — see Phase 2.
  const factory AgentDomainEntity.evolutionSession({
    required String id,
    required String agentId,
    required String templateId,
    required int sessionNumber,
    required EvolutionSessionStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    String? proposedVersionId,
    String? feedbackSummary,
    double? userRating,
    DateTime? completedAt,
    DateTime? deletedAt,
  }) = EvolutionSessionEntity;

  /// The evolution agent's private reasoning note.
  ///
  /// The [agentId] field stores the owning template's ID. It does **not**
  /// reference an agent instance.
  const factory AgentDomainEntity.evolutionNote({
    required String id,
    required String agentId,
    required String sessionId,
    required EvolutionNoteKind kind,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    required String content,
    DateTime? deletedAt,
  }) = EvolutionNoteEntity;

  /// Fallback for forward compatibility.
  const factory AgentDomainEntity.unknown({
    required String id,
    required String agentId,
    required DateTime createdAt,
    VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentUnknownEntity;

  factory AgentDomainEntity.fromJson(Map<String, dynamic> json) =>
      _$AgentDomainEntityFromJson(json);
}
