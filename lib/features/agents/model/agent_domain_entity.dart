import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
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
    DateTime? scheduledWakeAt,
    String? recentHeadMessageId,
    String? latestSummaryMessageId,
    @Default(0) int consecutiveFailureCount,
    @Default(0) int wakeCounter,
    @Default({}) Map<String, int> processedCounterByHost,

    /// When true, the agent was auto-created from a category default and is
    /// waiting for the task to contain meaningful content before its first run.
    @Default(false) bool awaitingContent,
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
  ///
  /// The [content] field holds the full markdown report body. The [tldr]
  /// field is a short summary populated by newer agent versions via the
  /// `update_report` tool. The [oneLiner] field is a compact task-card
  /// subtitle/tagline used in project detail task lists. For older reports
  /// where [tldr] is null, the UI extracts a synthetic TLDR from the first
  /// paragraph of [content].
  const factory AgentDomainEntity.agentReport({
    required String id,
    required String agentId,
    required String scope,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    @Default('') String content,

    /// Short summary, populated by `update_report(tldr:, content:)`.
    /// Null for reports created before this field was added.
    String? tldr,

    /// Compact task tagline, populated by
    /// `update_report(oneLiner:, tldr:, content:)`.
    /// Null for reports created before this field was added.
    String? oneLiner,
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
    String? profileId,
    DateTime? deletedAt,
  }) = AgentTemplateEntity;

  /// Immutable version of an agent template's directives.
  ///
  /// The [agentId] field stores the owning template's ID, grouping all
  /// versions under the same template. It does **not** reference an agent
  /// instance.
  ///
  /// The [directives] field is the legacy single-field directive text, kept
  /// for backwards compatibility. New versions should populate
  /// [generalDirective] (persona, tools, objectives) and [reportDirective]
  /// (report structure, formatting) instead. The system prompt is built from
  /// the new fields when they are non-empty, falling back to [directives].
  const factory AgentDomainEntity.agentTemplateVersion({
    required String id,
    required String agentId,
    required int version,
    required AgentTemplateVersionStatus status,
    required String directives,
    required String authoredBy,
    required DateTime createdAt,
    required VectorClock? vectorClock,

    /// The agent's mission: persona, available tools, and overall objective.
    @Default('') String generalDirective,

    /// How the agent should structure its output report.
    @Default('') String reportDirective,

    /// The model ID configured on the template when this version was created.
    String? modelId,

    /// The profile ID configured on the template when this version was created.
    String? profileId,
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
  /// direct SQL lookups via `getEvolutionSessionsByTemplate`. Detailed recap
  /// and transcript content is stored separately in
  /// [EvolutionSessionRecapEntity], keyed by [id].
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
    String? proposedSoulVersionId,
    String? feedbackSummary,
    double? userRating,
    DateTime? completedAt,
    DateTime? deletedAt,
  }) = EvolutionSessionEntity;

  /// Persisted recap for a completed evolution session.
  ///
  /// Stored separately from [EvolutionSessionEntity] so the session index stays
  /// lightweight while history views can still render TLDR, full markdown
  /// recap, approved changes, and a transcript snapshot.
  const factory AgentDomainEntity.evolutionSessionRecap({
    required String id,
    required String agentId,
    required String sessionId,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    required String tldr,
    required String recapMarkdown,
    @Default({}) Map<String, int> categoryRatings,
    @Default(<Map<String, String>>[]) List<Map<String, String>> transcript,
    String? approvedChangeSummary,
    DateTime? deletedAt,
  }) = EvolutionSessionRecapEntity;

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

  /// A batch of proposed mutations from a single agent wake.
  ///
  /// The [agentId] stores the agent instance ID. The [taskId] field is
  /// historically named, but identifies the target journal entity being
  /// modified for both task and project agents. Items are individually
  /// confirmable or rejectable by the user — batch tool calls (e.g.,
  /// `add_multiple_checklist_items`) are exploded into per-item entries.
  const factory AgentDomainEntity.changeSet({
    required String id,
    required String agentId,
    required String taskId,
    required String threadId,
    required String runKey,
    required ChangeSetStatus status,
    required List<ChangeItem> items,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    DateTime? resolvedAt,
    DateTime? deletedAt,
  }) = ChangeSetEntity;

  /// Records a verdict on a single change item.
  ///
  /// Persisted for decision history so the agent can learn which kinds of
  /// suggestions are typically accepted or rejected — and so the agent can
  /// see the outcome of its own past retractions. The [actor] field
  /// distinguishes end-user verdicts (`confirmed` / `rejected` / `deferred`)
  /// from agent-autonomous `retracted` verdicts. The optional [taskId]
  /// field is historical and may contain either a task ID or a project ID
  /// depending on the agent scope.
  const factory AgentDomainEntity.changeDecision({
    required String id,
    required String agentId,
    required String changeSetId,
    required int itemIndex,
    required String toolName,
    required ChangeDecisionVerdict verdict,
    required DateTime createdAt,
    required VectorClock? vectorClock,

    /// Who recorded this decision. Defaults to [DecisionActor.user] so
    /// pre-existing rows (which did not store this field) deserialize as
    /// user decisions — which is what they all were before the agent
    /// gained the ability to retract its own proposals.
    @Default(DecisionActor.user) DecisionActor actor,
    String? taskId,

    /// Free-text reason a *user* supplied when rejecting a proposal.
    /// Only populated when `verdict` is `ChangeDecisionVerdict.rejected`
    /// and `actor` is `DecisionActor.user`. Kept separate from
    /// `retractionReason` so feedback-extraction heuristics that treat
    /// this text as a user signal are not polluted by agent self-talk.
    String? rejectionReason,

    /// Free-text reason the *agent* supplied when retracting its own
    /// proposal. Only populated when `verdict` is
    /// `ChangeDecisionVerdict.retracted` and `actor` is
    /// `DecisionActor.agent`.
    String? retractionReason,

    /// Human-readable summary of the change item (e.g., 'Check off: "Buy
    /// milk"'). Stored at decision time so the agent can see *what* was
    /// confirmed or rejected, not just the tool name.
    String? humanSummary,

    /// The original tool-call arguments, stored so that rejection fingerprints
    /// can be reconstructed even after the parent change set is resolved.
    Map<String, dynamic>? args,
    DateTime? deletedAt,
  }) = ChangeDecisionEntity;

  /// A human-approved project recommendation with lifecycle.
  const factory AgentDomainEntity.projectRecommendation({
    required String id,
    required String agentId,
    required String projectId,
    required String title,
    required int position,
    required ProjectRecommendationStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    String? sourceChangeSetId,
    String? sourceDecisionId,
    String? rationale,
    String? priority,
    DateTime? resolvedAt,
    DateTime? dismissedAt,
    DateTime? supersededAt,
    DateTime? deletedAt,
  }) = ProjectRecommendationEntity;

  /// Token usage record for a single wake cycle.
  ///
  /// Immutable, append-only. Synced via Matrix so usage is visible across
  /// all devices. The [agentId] is the agent instance; [templateId] and
  /// [templateVersionId] enable per-template aggregation. The optional
  /// [soulDocumentId] and [soulDocumentVersionId] record which personality
  /// was active during the wake for provenance tracking.
  const factory AgentDomainEntity.wakeTokenUsage({
    required String id,
    required String agentId,
    required String runKey,
    required String threadId,
    required String modelId,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    String? templateId,
    String? templateVersionId,
    String? soulDocumentId,
    String? soulDocumentVersionId,
    int? inputTokens,
    int? outputTokens,
    int? thoughtsTokens,
    int? cachedInputTokens,
    DateTime? deletedAt,
  }) = WakeTokenUsageEntity;

  /// Soul document — reusable personality blueprint that can be assigned to
  /// one or more agent templates.
  ///
  /// This is the **root entity** of the soul document → version → head
  /// hierarchy. [agentId] equals [id] here (the generic `agent_entities`
  /// table uses `agent_id` as a grouping key; for root entities it is
  /// self-referencing). Versions and the head pointer reference this ID
  /// in their own [agentId] field to form the parent-child relationship.
  const factory AgentDomainEntity.soulDocument({
    required String id,
    required String agentId,
    required String displayName,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = SoulDocumentEntity;

  /// Immutable versioned snapshot of a soul's personality directives.
  ///
  /// Child of [SoulDocumentEntity]. [agentId] stores the parent soul
  /// document's ID (not an agent instance ID), grouping all versions under
  /// the same soul.
  const factory AgentDomainEntity.soulDocumentVersion({
    required String id,
    required String agentId,
    required int version,
    required SoulDocumentVersionStatus status,
    required String authoredBy,
    required DateTime createdAt,
    required VectorClock? vectorClock,

    /// Core personality: tone, warmth, humor, style, communication patterns.
    required String voiceDirective,

    /// Guardrails on voice — what the personality must never do.
    @Default('') String toneBounds,

    /// How the personality coaches, mentors, and motivates the user.
    @Default('') String coachingStyle,

    /// Directness contract — when to push back vs. comply.
    @Default('') String antiSycophancyPolicy,

    /// Evolution session that produced this version, if any.
    String? sourceSessionId,

    /// Parent version for diff tracking.
    String? diffFromVersionId,
    DateTime? deletedAt,
  }) = SoulDocumentVersionEntity;

  /// Mutable head pointer for the active soul version.
  ///
  /// Child of [SoulDocumentEntity]. [agentId] stores the parent soul
  /// document's ID. [versionId] points to the currently active
  /// [SoulDocumentVersionEntity].
  const factory AgentDomainEntity.soulDocumentHead({
    required String id,
    required String agentId,
    required String versionId,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = SoulDocumentHeadEntity;

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
