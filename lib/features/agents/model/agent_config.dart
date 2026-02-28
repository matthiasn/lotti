import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_config.freezed.dart';
part 'agent_config.g.dart';

/// Configuration for an agent instance.
@freezed
abstract class AgentConfig with _$AgentConfig {
  const factory AgentConfig({
    /// Maximum number of tool-call turns per wake.
    @Default(5) int maxTurnsPerWake,

    /// Model identifier to use for inference.
    @Default('models/gemini-3-flash-preview') String modelId,

    /// Inference profile ID — takes precedence over [modelId] when set.
    String? profileId,
  }) = _AgentConfig;

  factory AgentConfig.fromJson(Map<String, dynamic> json) =>
      _$AgentConfigFromJson(json);
}

/// Named slots that an agent uses to track its active work items.
@freezed
abstract class AgentSlots with _$AgentSlots {
  const factory AgentSlots({
    /// The journal-domain task ID this agent is working on.
    String? activeTaskId,
  }) = _AgentSlots;

  factory AgentSlots.fromJson(Map<String, dynamic> json) =>
      _$AgentSlotsFromJson(json);
}

/// Metadata attached to each agent message.
@freezed
abstract class AgentMessageMetadata with _$AgentMessageMetadata {
  const factory AgentMessageMetadata({
    /// The run key of the wake that produced this message.
    String? runKey,

    /// Tool name if this is an action or toolResult message.
    String? toolName,

    /// Operation ID for idempotency tracking.
    String? operationId,

    /// Error message if the tool call failed.
    String? errorMessage,

    /// Whether the tool call was denied by policy.
    @Default(false) bool policyDenied,

    /// Denial reason if policyDenied is true.
    String? denialReason,
  }) = _AgentMessageMetadata;

  factory AgentMessageMetadata.fromJson(Map<String, dynamic> json) =>
      _$AgentMessageMetadataFromJson(json);
}
