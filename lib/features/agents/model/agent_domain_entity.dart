import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/day_agent_plan_models.dart';
import 'package:lotti/classes/day_directive_models.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_progress_models.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'agent_domain_entity.freezed.dart';
part 'agent_domain_entity.g.dart';

/// The single sealed domain entity persisted and synced by the agents
/// subsystem. Every variant below is one row shape in the unified agent
/// store: they share one Drift table, one `fromJson` discriminator, and one
/// sync/outbox path, and consumers fold over them with exhaustive
/// `.when`/`.map`. The type is intentionally one unit — a freezed union's
/// `const factory` constructors are members of one class body and cannot span
/// part files. See the agents README "Persistence Model" for the per-variant
/// reference.
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
    required AgentSlots slots,
    required DateTime updatedAt,
    required VectorClock? vectorClock,

    /// **Retired** (PR 4 B4). Was a display-only per-row counter; never read for
    /// logic — concurrent resolution uses `updatedAt` + the vector clock, not
    /// this. No longer incremented or shown. Kept as a defaulted (rather than
    /// removed) field purely so a peer still on an older build can deserialize
    /// state this build emits; drop it in a later breaking-change window.
    @Default(0) int revision,
    DateTime? lastWakeAt,
    DateTime? nextWakeAt,
    DateTime? sleepUntil,
    DateTime? scheduledWakeAt,
    String? recentHeadMessageId,
    String? latestSummaryMessageId,
    @Default(0) int consecutiveFailureCount,
    @Default(GCounter.empty())
    @JsonKey(name: 'wakeCounterByHost')
    GCounter wakeCounter,
    @Default({}) Map<String, int> processedCounterByHost,
    @Default({}) Map<String, int> toolCounterByKey,

    /// Most recent relevant task change observed while automatic updates were
    /// disabled. This is a monotonic watermark rather than a boolean so a wake
    /// cannot accidentally clear a newer change that arrived during inference.
    DateTime? reportStaleAt,

    /// Start time of the most recent successful wake that refreshed the task
    /// report. A report is stale when `reportStaleAt` is not older than this
    /// watermark.
    DateTime? reportFreshAt,

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

  /// Persisted scheduled-wake record (ADR 0022 Decision 12).
  ///
  /// A single `AgentStateEntity.scheduledWakeAt` cannot represent several
  /// outstanding day-scoped wakes under one long-lived planner — a second
  /// day's `set_next_wake` would clobber the first. Each day-scoped scheduled
  /// wake (e.g. the morning pre-warm) is its own record carrying the
  /// [workspaceKey] and [triggerTokens], so the scheduled-wake manager
  /// restores it with full day context after a restart and never overwrites
  /// another day's wake.
  ///
  /// The id is deterministic per `(agentId, workspaceKey)` so re-scheduling
  /// the same workspace's pre-warm overwrites the prior record (LWW) rather
  /// than accumulating; firing flips [status] to
  /// [ScheduledWakeStatus.consumed] in place.
  const factory AgentDomainEntity.scheduledWake({
    required String id,
    required String agentId,
    required DateTime scheduledAt,
    required ScheduledWakeStatus status,
    required String reason,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    @Default(<String>[]) List<String> triggerTokens,
    String? workspaceKey,
    DateTime? consumedAt,

    /// Host that most recently claimed this record, for records whose work
    /// must run on exactly one device (the coordinator digest).
    ///
    /// The record is one synced last-write-wins register, so concurrent claims
    /// converge to a single surviving host — that convergence *is* the
    /// election. A claimant confirms by re-reading after a settle period and
    /// only proceeds if the survivor is still itself.
    String? leaseHostId,

    /// When the `leaseHostId` claim lapses.
    ///
    /// Without an expiry a device that claims and then goes offline would
    /// silently drop that window forever; past this instant any device may
    /// claim again.
    DateTime? leaseUntil,
    DateTime? deletedAt,
  }) = ScheduledWakeEntity;

  /// Submitted Daily OS capture transcript.
  ///
  /// [dayId] is the planning day workspace this capture belongs to
  /// (`dayplan-YYYY-MM-DD`, ADR 0022). It is **defaulted, never required**: a
  /// capture synced from an older peer carries no `dayId`, and a required,
  /// non-defaulted field would throw on `fromJson`. The repository materializes
  /// a stable day when storing such a row and preserves it across later legacy
  /// rewrites; `captureDayId` retains the captured-date fallback for raw,
  /// not-yet-persisted legacy entities.
  ///
  /// [parseCompletedAt] records a successful `parse_capture_to_items` call,
  /// including the explicit-empty result. Once non-null it is preserved
  /// monotonically at the repository write boundary because older peers omit
  /// it from whole-row rewrites. Successful parses also write an independent
  /// basic-link artifact that peers predating this field preserve, so
  /// completion converges even when a fresh device receives a causally newer
  /// marker-less rewrite first. Existing parsed-item links remain the
  /// compatibility signal for captures that completed before either artifact
  /// existed.
  const factory AgentDomainEntity.capture({
    required String id,
    required String agentId,
    required String transcript,
    required DateTime capturedAt,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    @Default('') String dayId,
    String? audioRef,
    DateTime? parseCompletedAt,
    DateTime? deletedAt,
  }) = CaptureEntity;

  /// Durable, compaction-exempt planner knowledge — "memorize what I tell you"
  /// (ADR 0022 Decisions 9–10).
  ///
  /// Each entry is keyed by a stable [key] (e.g. `deep-work-earliest-start`).
  /// The active entry per key is the most recent non-retracted one (recency
  /// wins; [supersedesId] points at the entry it replaces). Entries are NEVER
  /// folded into the compaction substrate, so user instructions cannot dissolve
  /// over the planner's life. They are surfaced two-tier: a compact [hook]
  /// index is always in the prompt; the full [statementText] is pulled on
  /// demand, scoped by [scope].
  const factory AgentDomainEntity.plannerKnowledge({
    required String id,
    required String agentId,
    required String key,
    required String hook,
    required String statementText,
    required KnowledgeSource source,
    required KnowledgeStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,

    /// Structured or short value, e.g. "10:00 local". Optional free-form.
    @Default('') String value,

    /// `global` (always surfaced), `category:<id>`, or `project:<id>`.
    @Default('global') String scope,

    /// Author-time topic tags (A-MEM construction attributes), set once at
    /// origin and carried forward immutably across confirm/edit. Surfaced as
    /// chips in the "What I've learned" panel and reusable for later recall.
    @Default(<String>[]) List<String> tags,

    /// The prior entry this supersedes (recency-wins), if any.
    String? supersedesId,
    DateTime? confirmedAt,
    DateTime? retractedAt,

    /// When the entry should be re-surfaced for staleness re-confirmation.
    DateTime? reviewAfter,
    DateTime? deletedAt,
  }) = PlannerKnowledgeEntity;

  /// LLM-parsed item extracted from a submitted Daily OS capture.
  const factory AgentDomainEntity.parsedItem({
    required String id,
    required String agentId,
    required String captureId,
    required ParsedItemKind kind,
    required String title,
    required String categoryId,
    required ParsedItemConfidence confidence,
    required double confidenceScore,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    @Default(false) bool lowConfidence,
    String? spokenPhrase,
    String? matchedTaskId,
    int? estimateMinutes,
    String? timeAnchor,
    String? proposedUpdate,
    DateTime? deletedAt,
  }) = ParsedItemEntity;

  /// Drafted Daily OS day plan emitted by the day-agent.
  const factory AgentDomainEntity.dayPlan({
    required String id,
    required String agentId,
    required String dayId,
    required DateTime planDate,
    required DayPlanData data,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    String? captureId,

    /// Run key of the wake that wrote this plan.
    ///
    /// Lets a durable draft job prove an artifact is *its* — matching by
    /// timestamp alone cannot distinguish this job's plan from one a
    /// concurrent wake happened to write inside the same window. Null for
    /// plans written before the field existed, and for writes with no wake
    /// behind them (a user edit).
    String? runKey,
    @Default([]) List<DayAgentEnergyBand> energyBands,
    @Default(480) int capacityMinutes,
    @Default(0) int scheduledMinutes,
    DateTime? deletedAt,
  }) = DayPlanEntity;

  /// Contemporaneous day summary — the planner's own testimony about one day
  /// (`day_agent_summary:<dayId>`), written at/near day close in its own words
  /// for its own consumption.
  ///
  /// A keyed mutable register, NOT an append-only log entry: the id is
  /// deterministic per day, within-window self-rewrites upsert in place, and
  /// concurrent versions resolve **earliest `createdAt` wins** (the most
  /// contemporaneous testimony is canonical — see
  /// `resolveConcurrentAgentEntityOverride`). Deliberate amendment to
  /// ADR 0016 D3 / ADR 0018 D1. Facts are never derived from this text; it is
  /// rendered next to the deterministic facts line in `<recent_days>` so the
  /// model can self-audit. Compaction-exempt for now (retention revisited with
  /// compaction integration).
  const factory AgentDomainEntity.daySummary({
    required String id,
    required String agentId,
    required String dayId,
    required String text,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = DaySummaryEntity;

  /// Coordinator-issued directive for one day (ADR 0032 §2, phase 3).
  ///
  /// Keyed `day_directive:<dayId>` — a deterministic per-day register the
  /// coordinator revises in place (newest revision wins via LWW; a fresh
  /// [directiveRevisionId] marks each revision). Contains only distilled,
  /// bounded facts — never capture transcripts or another day's log content.
  /// The per-day agent reads the newest revision at wake start; its prompt
  /// contract requires every commitment to be represented in the plan,
  /// explicitly traded away in a proposed diff, or escalated via a status
  /// event.
  const factory AgentDomainEntity.dayDirective({
    required String id,
    required String agentId,
    required String dayId,
    required DateTime planDate,
    required String directiveRevisionId,
    required DateTime issuedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    @Default(<DayDirectiveCommitment>[])
    List<DayDirectiveCommitment> commitments,
    DayCapacityBudget? capacityBudget,
    @Default(<DayCarryOverItem>[]) List<DayCarryOverItem> carryOver,
    @Default(<String>[]) List<String> constraints,
    @Default(<String>[]) List<String> attentionNotes,
    DateTime? deletedAt,
  }) = DayDirectiveEntity;

  /// Typed status event raised by a day-owner agent (ADR 0032 §2, phase 3).
  ///
  /// Append-only (`day_status:<dayId>:<uuid>`), never revised — the upward
  /// channel the coordinator scans at its digest wake. A new entity variant
  /// (not an [AgentMessageKind]) so status stays out of the compaction fold
  /// and gets an indexed typed scan via the type/subtype columns (subtype =
  /// [status] name).
  const factory AgentDomainEntity.dayStatusEvent({
    required String id,
    required String agentId,
    required String dayId,
    required DayStatusKind status,
    required DateTime raisedAt,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    @Default(<DayStatusReason>[]) List<DayStatusReason> reasons,
    @Default('') String note,
    DateTime? deletedAt,
  }) = DayStatusEventEntity;

  /// Deterministic weekly rollup register (ADR 0032 digest pooling).
  ///
  /// Keyed `week_rollup_v2:<ISO Monday date>` and coordinator-owned: a pure
  /// aggregation over one calendar week's day plans (planned minutes per
  /// category, days that had a plan) and recorded time entries (recorded
  /// minutes per category). Recomputed from source data — never accumulated
  /// in place — whenever the digest wake refreshes rollups, so concurrent
  /// revisions converge via plain LWW. Minutes maps are keyed by category id;
  /// the empty-string key buckets uncategorized recorded time.
  const factory AgentDomainEntity.weekRollup({
    required String id,
    required String agentId,
    required DateTime weekStart,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    @Default(<String, int>{}) Map<String, int> plannedMinutesByCategory,
    @Default(<String, int>{}) Map<String, int> recordedMinutesByCategory,
    @Default(0) int daysWithPlans,

    /// Which rule bucketed `recordedMinutesByCategory` into this week.
    ///
    /// `recordedLocal` means each span was bucketed by the wall clock of the
    /// device that recorded it, which every device derives identically. Null
    /// marks a **legacy** register bucketed in the reading device's own zone,
    /// where two devices in different zones computed different totals for the
    /// same week and flapped this register between them. Legacy registers are
    /// rewritten the next time their week falls inside the recompute window;
    /// older ones keep their legacy values and stay flagged by this null.
    String? bucketingRule,
    DateTime? deletedAt,
  }) = WeekRollupEntity;

  /// Event-sourced bid for the user's scarce attention.
  ///
  /// [agentId] is the requesting agent. A planner reads pending requests and
  /// emits proposal/disposition records; the request itself is immutable and
  /// evidence-backed so decisions can be audited from the log.
  const factory AgentDomainEntity.attentionRequest({
    required String id,
    required String agentId,
    required AttentionRequestKind kind,
    required String title,
    required String categoryId,
    required int requestedMinutes,
    required int impact,
    required int urgency,
    required AttentionEnergyFit energyFit,
    required List<AttentionEvidenceRef> evidenceRefs,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    @Default(AttentionClaimScopeKind.day) AttentionClaimScopeKind scopeKind,
    @Default(AttentionRequestStatus.pending) AttentionRequestStatus status,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    DateTime? earliestStart,
    DateTime? latestEnd,
    DateTime? deadline,
    DateTime? nextReviewAt,
    String? targetId,
    String? targetKind,
    String? cadence,
    String? rationale,
    DateTime? deletedAt,
  }) = AttentionRequestEntity;

  /// Planner/user/system disposition for an attention claim.
  ///
  /// The original [AttentionRequestEntity] remains auditable. Disposition
  /// records project the current lifecycle state without mutating away the
  /// request's original rationale and evidence.
  const factory AgentDomainEntity.attentionClaimDisposition({
    required String id,
    required String agentId,
    required String requestId,
    required AttentionClaimStatus status,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    String? awardId,
    String? planId,
    String? changeSetId,
    String? reason,
    DateTime? nextReviewAt,
    DateTime? deletedAt,
  }) = AttentionClaimDispositionEntity;

  /// Planner award proposal for a concrete plan block.
  ///
  /// Awards are proposal records: they describe the block the planner would
  /// add, but schedule mutation still flows through the existing ChangeSet
  /// gate.
  const factory AgentDomainEntity.attentionAward({
    required String id,
    required String agentId,
    required String requestId,
    required String dayId,
    required String planId,
    required String blockId,
    required String categoryId,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required int rank,
    required int utilityScore,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    @Default(AttentionAwardStatus.proposed) AttentionAwardStatus status,
    String? taskId,
    String? rationale,
    DateTime? deletedAt,
  }) = AttentionAwardEntity;

  /// Durable policy/goal the planner must consider across planning windows.
  ///
  /// Standing agreements are not per-day claims. They represent user-approved
  /// norms such as "exercise 3x/week", "protect sleep wind-down", or "cap
  /// paperwork time". Specialist agents may use them to emit concrete
  /// [AttentionRequestEntity] claims; the day-planner reads them directly when
  /// weighing claims and deciding whether a proposal can be auto-accepted,
  /// should ask the user, or must be rejected.
  const factory AgentDomainEntity.standingAgreement({
    required String id,
    required String agentId,
    required String title,
    required StandingAgreementScope scope,
    required StandingAgreementCadence cadence,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    @Default(StandingAgreementStatus.active) StandingAgreementStatus status,
    @Default(StandingAgreementEnforcement.target)
    StandingAgreementEnforcement enforcement,
    @Default(StandingAgreementApprovalMode.ask)
    StandingAgreementApprovalMode approvalMode,
    String? categoryId,
    String? targetId,
    String? targetKind,
    String? customScope,
    String? customCadence,
    int? minCount,
    int? maxCount,
    int? minMinutes,
    int? maxMinutes,
    int? preferredSessionMinutes,
    @Default(false) bool canPreempt,
    @Default(0) int priority,
    @Default([]) List<String> preemptibleCategoryIds,
    @Default([]) List<String> protectedCategoryIds,
    @Default([]) List<AttentionEvidenceRef> evidenceRefs,
    DateTime? activeFrom,
    DateTime? activeUntil,
    String? rationale,
    DateTime? deletedAt,
  }) = StandingAgreementEntity;

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

  /// Immutable version of a goal's spec (ADR 0053 Decision 2).
  ///
  /// The goal is versioned structured state, not prose: [statement] is the
  /// sentence the agent can always *speak*, [criteria] is the machine-
  /// evaluable tree the deterministic tier folds. Versions are never edited;
  /// a revision writes a new version (via ChangeSet approval when
  /// agent-proposed — there is no auto-accept tier) and moves the head.
  /// [agentId] is the goal agent; one agent IS one goal.
  const factory AgentDomainEntity.goalSpecVersion({
    required String id,
    required String agentId,
    required int version,
    required GoalSpecVersionStatus status,
    required String authoredBy,
    required String title,

    /// The speakable form: "Average 10,000 steps a day over a rolling week."
    required String statement,
    required GoalCriterion criteria,
    required DateTime createdAt,
    required VectorClock? vectorClock,

    /// Conversation that produced an agent-proposed revision.
    String? sourceSessionId,

    /// Parent version for diff rendering in the revision ChangeSet.
    String? diffFromVersionId,
    DateTime? startDate,

    /// Optional deadline; when passed, the track policy resolves to
    /// achieved/offTrack instead of granting grace.
    DateTime? targetDate,
    String? rationale,
    DateTime? deletedAt,
  }) = GoalSpecVersionEntity;

  /// Mutable head pointer for the active goal spec version.
  ///
  /// Deterministic id `goal_spec_head:<agentId>` (`goalSpecHeadId`), LWW.
  /// "State your current goal" is a head→version read — zero inference.
  const factory AgentDomainEntity.goalSpecHead({
    required String id,
    required String agentId,
    required String versionId,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = GoalSpecHeadEntity;

  /// Deterministic attainment register for one goal period (ADR 0053
  /// Decision 4).
  ///
  /// Keyed `goal_progress:<agentId>:<periodKey>` (`goalProgressId`) and
  /// recomputed from source, never accumulated — the `weekRollup`
  /// convergence pattern: N devices computing the same period write the
  /// same row. [trackStatus] is derived by `GoalTrackPolicy`, never by a
  /// model, and is mirrored into the row's `subtype` for indexed scans.
  /// [specVersionId] pins which goal definition the numbers were computed
  /// against, so charts stay honest across revisions. Retention-exempt:
  /// this register IS the quantitative history.
  const factory AgentDomainEntity.goalProgress({
    required String id,
    required String agentId,
    required String periodKey,
    required GoalTrackStatus trackStatus,
    required double attainment,
    required double dataCoverage,
    required bool satisfied,
    required String specVersionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    @Default(<GoalCriterionProgress>[])
    List<GoalCriterionProgress> criterionResults,
    bool? paceFeasible,
    double? shortTermAttainment,
    DateTime? deletedAt,
  }) = GoalProgressEntity;

  /// A goal ad — one banner nudge, its brief, and its whole life
  /// (ADR 0055).
  ///
  /// The row is append-only in spirit: [status] moves through the lifecycle
  /// (including the reuse re-entry `retired → active`), while [ratings] and
  /// the visibility counters accumulate across runs — the labeled library
  /// that personalizes future ads and detects wear-out. [brief] is all the
  /// banner there is: copy plus procedural presentation presets, rendered
  /// by the app with zero generation cost (ADR 0058). [briefDigest] is the
  /// near-duplicate dedupe key over the copy.
  const factory AgentDomainEntity.goalNudge({
    required String id,
    required String agentId,
    required GoalNudgeStatus status,
    required GoalNudgeBrief brief,
    required String briefDigest,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,

    /// Wake provenance (the DayPlanEntity precedent).
    String? runKey,
    String? threadId,

    /// The `goalProgress` row that justified this ad.
    String? triggerProgressId,
    String? reasonSummary,

    /// How long this ad may claim to be current; goal-relevant events pull
    /// it forward (staleness is a contract, not a hope).
    DateTime? staleAt,
    DateTime? activatedAt,
    DateTime? dismissedAt,
    DateTime? retiredAt,
    DateTime? expiredAt,

    /// How many times this ad has been activated (1-based; a reuse
    /// re-entry increments it). Rating prompts key off this: one outcome
    /// per activation in the ratings history.
    @Default(1) int activationCount,

    /// Rating-prompt outcomes, one per rated-or-skipped activation
    /// (append-only; never overwritten).
    @Default(<GoalNudgeRating>[]) List<GoalNudgeRating> ratings,

    /// Accumulated visible milliseconds, per host — grow-only counters so
    /// concurrent exposure on two devices can merge by element-wise max
    /// instead of losing one side to whole-row LWW (`.value` is the total).
    /// The concurrent-merge rule itself lands with the first producer
    /// (PR 5), before anything writes these rows.
    @Default(GCounter.empty())
    @JsonKey(name: 'totalVisibleMsByHost')
    GCounter totalVisibleMs,
    @Default(GCounter.empty())
    @JsonKey(name: 'impressionCountByHost')
    GCounter impressionCount,
    DateTime? firstShownAt,
    DateTime? lastShownAt,

    /// Pipeline outcomes (verification verdict, generator model, …).
    @Default(<String, String>{}) Map<String, String> provenance,
    DateTime? deletedAt,
  }) = GoalNudgeEntity;

  /// Fallback for forward compatibility.
  const factory AgentDomainEntity.unknown({
    required String id,
    required String agentId,
    required DateTime createdAt,
    VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentUnknownEntity;

  /// Decodes an agent entity and applies bounded read-side compatibility
  /// repairs before the generated decoder enforces the current schema.
  ///
  /// Early `weekRollup` rows omitted `weekStart` even though their canonical
  /// id already contained the same Monday. Derive that one field without
  /// mutating the caller's map. A malformed id is not guessed or echoed in the
  /// diagnostic: sync can classify the fixed [FormatException] as permanent
  /// and avoid retrying a poison payload.
  factory AgentDomainEntity.fromJson(Map<String, dynamic> json) =>
      _$AgentDomainEntityFromJson(_repairLegacyWeekRollup(json));
}

// Both register generations. The `_v2` ids this build writes always carry
// `weekStart`, so they never reach the repair — but a generation the pattern
// does not know would be rejected as a poison payload rather than repaired,
// which is a worse failure than being redundant here.
final _canonicalWeekRollupId = RegExp(
  r'^week_rollup(?:_v2)?:(\d{4})-(\d{2})-(\d{2})$',
);

const _invalidLegacyWeekRollupMessage =
    'Legacy weekRollup is missing weekStart and its id is not a canonical '
    'Monday';

Map<String, dynamic> _repairLegacyWeekRollup(Map<String, dynamic> json) {
  if (json['runtimeType'] != 'weekRollup' || json['weekStart'] != null) {
    return json;
  }

  final id = json['id'];
  final match = id is String ? _canonicalWeekRollupId.firstMatch(id) : null;
  if (match == null) {
    throw const FormatException(_invalidLegacyWeekRollupMessage);
  }

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  // UTC-typed: the id is a zone-free calendar key, so resolving it in the
  // reader's zone would make the derived weekStart reader-relative — the
  // divergence week rollups were made canonical to end.
  final weekStart = DateTime.utc(year, month, day);
  final isExactDate =
      weekStart.year == year &&
      weekStart.month == month &&
      weekStart.day == day;
  if (!isExactDate || weekStart.weekday != DateTime.monday) {
    throw const FormatException(_invalidLegacyWeekRollupMessage);
  }

  return <String, dynamic>{
    ...json,
    'weekStart': weekStart.toIso8601String(),
  };
}

extension AgentStateReportFreshness on AgentStateEntity {
  /// Whether a relevant task change is not reflected in the latest successful
  /// report wake.
  bool get isReportStale {
    final staleAt = reportStaleAt;
    if (staleAt == null) return false;
    final freshAt = reportFreshAt;
    return freshAt == null || !staleAt.isBefore(freshAt);
  }
}
