import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/sync/g_counter.dart';

part 'agent_config.freezed.dart';
part 'agent_config.g.dart';

/// Configuration for an agent instance.
@freezed
abstract class AgentConfig with _$AgentConfig {
  const factory AgentConfig({
    /// Maximum number of tool-call turns per wake.
    @Default(10) int maxTurnsPerWake,

    /// Model identifier to use for inference.
    @Default('models/gemini-3-flash-preview') String modelId,

    /// Inference profile ID — takes precedence over [modelId] when set.
    String? profileId,

    /// Typed persistent inference setup for agent instances.
    ///
    /// Null preserves the legacy profile/template/model resolution chain.
    /// Once present, this setup is authoritative: configured setups resolve
    /// only their direct model override or base profile, while disabled setups
    /// prohibit inference instead of falling through to legacy defaults.
    AgentInferenceSetup? inferenceSetup,

    /// Whether task changes may schedule coalesced automatic wakes.
    ///
    /// Null means legacy/on. New task agents and the first switch edit persist
    /// an explicit value independently from profile/model selection.
    bool? automaticUpdatesEnabled,

    /// Improver ritual cadence in days. Re-homed from `AgentSlots` (PR 4 B4):
    /// it is configuration set once at creation, not mutable derived state.
    /// Null falls back to the default window. Reads accept the legacy
    /// `AgentSlots.feedbackWindowDays` for agents created before the re-home.
    int? feedbackWindowDays,

    /// Improver recursion depth: 0 = task improver, 1 = meta-improver. Re-homed
    /// from `AgentSlots` (config, not mutable state); legacy slot value is the
    /// read fallback for pre-existing agents.
    int? recursionDepth,
  }) = _AgentConfig;

  factory AgentConfig.fromJson(Map<String, dynamic> json) =>
      _$AgentConfigFromJson(json);
}

extension AgentConfigAutomation on AgentConfig {
  /// Legacy configs omitted the field and retain the historical enabled state.
  bool get automaticUpdatesEnabledEffective => automaticUpdatesEnabled ?? true;
}

/// Persistent inference routing owned by one agent instance.
@freezed
abstract class AgentInferenceSetup with _$AgentInferenceSetup {
  const factory AgentInferenceSetup({
    @JsonKey(unknownEnumValue: AgentInferenceSetupMode.disabled)
    required AgentInferenceSetupMode mode,
    @JsonKey(unknownEnumValue: AgentInferenceSetupOrigin.unknown)
    required AgentInferenceSetupOrigin origin,

    /// Base inference profile. Its non-thinking slots remain available when a
    /// direct thinking-model override is selected.
    String? baseProfileId,

    /// Config-row ID (`AiConfigModel.id`) for the agent's thinking model.
    /// This is deliberately not a provider-native `providerModelId`.
    String? thinkingModelOverrideId,

    /// Category/template ID whose default was copied, when applicable.
    String? originEntityId,
  }) = _AgentInferenceSetup;

  factory AgentInferenceSetup.fromJson(Map<String, dynamic> json) =>
      _$AgentInferenceSetupFromJson(json);
}

/// Named slots that an agent uses to track its active work items.
@freezed
abstract class AgentSlots with _$AgentSlots {
  const factory AgentSlots({
    /// The journal-domain task ID this agent is working on.
    String? activeTaskId,

    /// The day-plan ID this agent is working on.
    String? activeDayId,

    /// The project ID this agent is working on.
    String? activeProjectId,

    /// The event ID this agent is working on.
    String? activeEventId,

    /// The template ID this improver agent manages.
    String? activeTemplateId,

    /// When the last one-on-one ritual completed.
    DateTime? lastOneOnOneAt,

    /// Incremental feedback scan watermark.
    DateTime? lastFeedbackScanAt,

    /// Configurable ritual frequency in days (default 7).
    int? feedbackWindowDays,

    /// Total one-on-one sessions completed by this improver (per-host G-counter
    /// so concurrent multi-device increments converge to the exact total).
    @Default(GCounter.empty())
    @JsonKey(name: 'totalSessionsCompletedByHost')
    GCounter totalSessionsCompleted,

    /// Recursion depth: 0 = task improver, 1 = meta-improver.
    int? recursionDepth,

    /// When the last daily wake completed for project agents.
    DateTime? lastDailyWakeAt,

    /// When the last weekly review completed for project agents.
    DateTime? lastWeeklyReviewAt,

    /// Total weekly review sessions completed by this project agent (per-host
    /// G-counter; not yet incremented anywhere — wired up when the feature lands).
    @Default(GCounter.empty())
    @JsonKey(name: 'weeklyReviewCountByHost')
    GCounter weeklyReviewCount,

    /// Most recent project-linked activity that is not reflected in the
    /// current project report yet. `null` means the summary is up to date.
    DateTime? pendingProjectActivityAt,
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

    /// Tags this message as recording the completion of a wake milestone.
    ///
    /// When set, the message's `createdAt` is the source of truth for the
    /// corresponding derived watermark (e.g. `lastWakeAt`,
    /// `slots.lastOneOnOneAt`). The State-as-Projection fold (PR 4) reads these
    /// markers so watermarks converge across devices instead of being clobbered
    /// by LWW. Null on every message today — emission is wired in B2.
    ///
    /// Forward-compatible: a milestone value an older client doesn't recognise
    /// deserialises to `null` rather than throwing.
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    AgentMilestone? milestone,

    /// When set, this is a **retraction** event (ADR 0020): the captured input
    /// source identified by this `contentEntryId` is soft-retracted from the
    /// agent's active consideration as of this message's position in the log
    /// (the user deleted or unlinked it). The original content snapshot stays
    /// in the log — auditable — and a later capture of the same source un-does
    /// the retraction. `projectInputFrontier` folds these to exclude retracted
    /// sources from the wake context. Null on every non-retraction message.
    String? retractsContentEntryId,
  }) = _AgentMessageMetadata;

  factory AgentMessageMetadata.fromJson(Map<String, dynamic> json) =>
      _$AgentMessageMetadataFromJson(json);
}
