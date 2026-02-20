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
    required Map<String, Object?> content,
    double? confidence,
    @Default({}) Map<String, Object?> provenance,
    DateTime? deletedAt,
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
