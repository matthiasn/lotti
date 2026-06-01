import 'package:equatable/equatable.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/agent_event_adapter.dart';
import 'package:lotti/features/agents/projection/agent_projection.dart';
import 'package:lotti/features/agents/projection/canonical_order.dart';
import 'package:lotti/features/agents/projection/shadow_projection.dart';

/// The agent's derived state, folded from the append-only log (PR 4 B5).
///
/// This is the **storage-coupled composite** sitting above the pure kernel: it
/// calls `project(canonicalOrder(...))` for the structural part ([projection] —
/// heads + latest report) and aggregates the *order-independent* fields
/// directly off the messages/links — watermarks as `max(createdAt)` per
/// milestone, active slots from the agent's association links. Every field is a
/// pure function of the log's *set* of messages/links, so two devices holding
/// the same set derive an equal [DerivedAgentState] regardless of arrival order
/// (the convergence property the cache cannot guarantee under LWW).
///
/// What is **not** here, and why:
/// - **Counter sums** (`wakeCounter`, `totalSessionsCompleted`,
///   `weeklyReviewCount`) — already convergent per-host G-counters (PR 2b); the
///   derived value is a trivial `.value` read on the synced row, not a fold.
/// - **`awaitingContent`** — its initial value depends on the *creation mode*
///   (auto-created-from-category vs. explicit) and it is cleared by the wake
///   orchestrator detecting task content; neither is a synced log event yet, so
///   it cannot be event-sourced until it gets its own marker (a B2-style step).
/// - Runtime-local / best-effort cache fields (`toolCounterByKey`,
///   `consecutiveFailureCount`, `pendingProjectActivityAt`, scheduling) — stay
///   on the cache by design.
///
/// Drives no production read; B6 flips reads onto this fold.
class DerivedAgentState extends Equatable {
  const DerivedAgentState({
    required this.projection,
    required this.activeTaskId,
    required this.activeProjectId,
    required this.activeDayId,
    required this.activeTemplateId,
    required this.lastWakeAt,
    required this.lastOneOnOneAt,
    required this.lastFeedbackScanAt,
    required this.lastDailyWakeAt,
    required this.lastWeeklyReviewAt,
  });

  /// Structural projection from the kernel: heads, latest report, dangling
  /// parents. The live `recentHeadMessageId` corresponds to the single head
  /// (or one tip of a fork — see [compareShadowProjection]).
  final AgentProjection projection;

  /// `slots.activeTaskId` — `toId` of the agent's primary active `agentTask`
  /// link, or null.
  final String? activeTaskId;

  /// `slots.activeProjectId` — primary active `agentProject` link target.
  final String? activeProjectId;

  /// `slots.activeDayId` — primary active `agentDay` link target.
  final String? activeDayId;

  /// `slots.activeTemplateId` — primary active `improverTarget` link target.
  final String? activeTemplateId;

  /// `lastWakeAt` — `max(createdAt)` of `wakeCompleted` markers.
  final DateTime? lastWakeAt;

  /// `slots.lastOneOnOneAt` — `max(createdAt)` of `oneOnOneCompleted` markers.
  final DateTime? lastOneOnOneAt;

  /// `slots.lastFeedbackScanAt` — `max(createdAt)` of `feedbackScanCompleted`.
  final DateTime? lastFeedbackScanAt;

  /// `slots.lastDailyWakeAt` — `max(createdAt)` of `dailyWakeCompleted`.
  final DateTime? lastDailyWakeAt;

  /// `slots.lastWeeklyReviewAt` — `max(createdAt)` of `weeklyReviewCompleted`.
  final DateTime? lastWeeklyReviewAt;

  @override
  List<Object?> get props => [
    projection,
    activeTaskId,
    activeProjectId,
    activeDayId,
    activeTemplateId,
    lastWakeAt,
    lastOneOnOneAt,
    lastFeedbackScanAt,
    lastDailyWakeAt,
    lastWeeklyReviewAt,
  ];
}

/// Folds the agent's log ([messages] + [links]) into its [DerivedAgentState].
///
/// Pure function of the message/link *set* for [agentId]. May throw the same
/// structural exceptions as `canonicalOrder` (duplicate id / cycle) via the
/// kernel; callers that must not crash use [compareDerivedAgentState], which
/// captures them.
DerivedAgentState deriveAgentState({
  required String agentId,
  required Iterable<AgentMessageEntity> messages,
  required Iterable<AgentLink> links,
  String Function(AgentMessageEntity message)? hostIdOf,
}) {
  final messageList = messages.toList(growable: false);
  final linkList = links.toList(growable: false);

  final projection = project(
    canonicalOrder(
      agentEventsFromLog(messageList, linkList, hostIdOf: hostIdOf),
    ),
  );

  return DerivedAgentState(
    projection: projection,
    activeTaskId: _primaryActiveLinkTarget(
      linkList,
      agentId,
      (link) => link is AgentTaskLink,
    ),
    activeProjectId: _primaryActiveLinkTarget(
      linkList,
      agentId,
      (link) => link is AgentProjectLink,
    ),
    activeDayId: _primaryActiveLinkTarget(
      linkList,
      agentId,
      (link) => link is AgentDayLink,
    ),
    activeTemplateId: _primaryActiveLinkTarget(
      linkList,
      agentId,
      (link) => link is ImproverTargetLink,
    ),
    lastWakeAt: _watermark(messageList, AgentMilestone.wakeCompleted),
    lastOneOnOneAt: _watermark(messageList, AgentMilestone.oneOnOneCompleted),
    lastFeedbackScanAt: _watermark(
      messageList,
      AgentMilestone.feedbackScanCompleted,
    ),
    lastDailyWakeAt: _watermark(messageList, AgentMilestone.dailyWakeCompleted),
    lastWeeklyReviewAt: _watermark(
      messageList,
      AgentMilestone.weeklyReviewCompleted,
    ),
  );
}

/// `toId` of the agent's primary (most-recent-wins, same tiebreak production
/// uses) active link matching [isType] with `fromId == agentId`, or null. The
/// slot links are agent→target (`fromId` is the agent), so this resolves the
/// current slot value the same way the live services do.
String? _primaryActiveLinkTarget(
  List<AgentLink> links,
  String agentId,
  bool Function(AgentLink link) isType,
) {
  final matching = [
    for (final link in links)
      if (isType(link) && link.fromId == agentId && link.deletedAt == null)
        link,
  ];
  if (matching.isEmpty) return null;
  return matching.orderedPrimaryFirst().first.toId;
}

/// The watermark for [milestone]: the latest `createdAt` among active messages
/// tagged with it, or null when none exists. `max(createdAt)` is set-union
/// convergent — order- and partition-independent.
DateTime? _watermark(
  List<AgentMessageEntity> messages,
  AgentMilestone milestone,
) {
  DateTime? latest;
  for (final message in messages) {
    if (message.metadata.milestone == milestone && message.deletedAt == null) {
      if (latest == null || message.createdAt.isAfter(latest)) {
        latest = message.createdAt;
      }
    }
  }
  return latest;
}

/// A single derived field that diverges from the live cache row.
class DerivedFieldMismatch extends Equatable {
  const DerivedFieldMismatch({
    required this.field,
    required this.derived,
    required this.live,
  });

  /// The diverging field's name (e.g. `lastWakeAt`).
  final String field;

  /// The value the fold derived from the log.
  final Object? derived;

  /// The value on the live `AgentStateEntity` cache.
  final Object? live;

  @override
  String toString() =>
      'DerivedFieldMismatch($field: derived=$derived, live=$live)';

  @override
  List<Object?> get props => [field, derived, live];
}

/// Result of comparing the log-derived state against the live cache row.
class DerivedStateReport extends Equatable {
  const DerivedStateReport({
    required this.shadow,
    required this.fieldMismatches,
    this.error,
  });

  /// The structural head comparison (reuses [compareShadowProjection]:
  /// match / forked / mismatch / empty / error).
  final ShadowProjectionReport shadow;

  /// Order-independent fields (watermarks, active slots) that diverge from the
  /// live cache. Empty when every derived field reproduces the cache.
  final List<DerivedFieldMismatch> fieldMismatches;

  /// Captured exception string when the fold threw (duplicate id / cycle);
  /// null otherwise.
  final String? error;

  /// True when the head reconciles (an exact match, an expected fork, or a
  /// fresh empty agent) and no order-independent field diverges — i.e. the
  /// projection fully reproduces the live cache, the B6 cutover precondition.
  bool get equivalent =>
      error == null &&
      fieldMismatches.isEmpty &&
      (shadow.status == ShadowProjectionStatus.match ||
          shadow.status == ShadowProjectionStatus.forked ||
          shadow.status == ShadowProjectionStatus.empty);

  @override
  List<Object?> get props => [shadow, fieldMismatches, error];
}

/// Compares the full log-derived state against the live [liveState] cache row.
///
/// The structural head is compared via [compareShadowProjection] (fork-tolerant);
/// the order-independent fields (watermarks, active slots) are compared exactly.
/// Counter sums and `awaitingContent` are intentionally **not** compared — see
/// [DerivedAgentState]. Pure and non-throwing: a structural fold failure is
/// surfaced via [DerivedStateReport.error].
DerivedStateReport compareDerivedAgentState({
  required Iterable<AgentMessageEntity> messages,
  required Iterable<AgentLink> links,
  required AgentStateEntity liveState,
  String Function(AgentMessageEntity message)? hostIdOf,
}) {
  final shadow = compareShadowProjection(
    messages: messages,
    links: links,
    liveHeadId: liveState.recentHeadMessageId,
    hostIdOf: hostIdOf,
  );
  try {
    final derived = deriveAgentState(
      agentId: liveState.agentId,
      messages: messages,
      links: links,
      hostIdOf: hostIdOf,
    );
    final slots = liveState.slots;
    final mismatches = <DerivedFieldMismatch>[
      if (derived.activeTaskId != slots.activeTaskId)
        DerivedFieldMismatch(
          field: 'activeTaskId',
          derived: derived.activeTaskId,
          live: slots.activeTaskId,
        ),
      if (derived.activeProjectId != slots.activeProjectId)
        DerivedFieldMismatch(
          field: 'activeProjectId',
          derived: derived.activeProjectId,
          live: slots.activeProjectId,
        ),
      if (derived.activeDayId != slots.activeDayId)
        DerivedFieldMismatch(
          field: 'activeDayId',
          derived: derived.activeDayId,
          live: slots.activeDayId,
        ),
      if (derived.activeTemplateId != slots.activeTemplateId)
        DerivedFieldMismatch(
          field: 'activeTemplateId',
          derived: derived.activeTemplateId,
          live: slots.activeTemplateId,
        ),
      if (derived.lastWakeAt != liveState.lastWakeAt)
        DerivedFieldMismatch(
          field: 'lastWakeAt',
          derived: derived.lastWakeAt,
          live: liveState.lastWakeAt,
        ),
      if (derived.lastOneOnOneAt != slots.lastOneOnOneAt)
        DerivedFieldMismatch(
          field: 'lastOneOnOneAt',
          derived: derived.lastOneOnOneAt,
          live: slots.lastOneOnOneAt,
        ),
      if (derived.lastFeedbackScanAt != slots.lastFeedbackScanAt)
        DerivedFieldMismatch(
          field: 'lastFeedbackScanAt',
          derived: derived.lastFeedbackScanAt,
          live: slots.lastFeedbackScanAt,
        ),
      if (derived.lastDailyWakeAt != slots.lastDailyWakeAt)
        DerivedFieldMismatch(
          field: 'lastDailyWakeAt',
          derived: derived.lastDailyWakeAt,
          live: slots.lastDailyWakeAt,
        ),
      if (derived.lastWeeklyReviewAt != slots.lastWeeklyReviewAt)
        DerivedFieldMismatch(
          field: 'lastWeeklyReviewAt',
          derived: derived.lastWeeklyReviewAt,
          live: slots.lastWeeklyReviewAt,
        ),
    ];
    return DerivedStateReport(shadow: shadow, fieldMismatches: mismatches);
  } catch (e) {
    return DerivedStateReport(
      shadow: shadow,
      fieldMismatches: const [],
      error: e.toString(),
    );
  }
}

/// Reconciles the cached [cache] row against the log: the **read cutover**
/// (PR 4 B6). Returns a row whose log-backed fields reflect the projection,
/// leaving every other field on the cache untouched. Returns [cache] *itself*
/// (value-equal) when nothing diverged, so callers can skip a redundant persist.
///
/// The merge is deliberately **not** a blind "log wins":
/// - **Watermarks** reconcile to `max(derived, cache)`. They are monotonic, so
///   the max never regresses a value the cache holds but the log lacks yet
///   (an agent whose log predates the B2 milestone markers, or a marker that
///   hasn't synced) and self-heals a value the cache lost to LWW under a
///   partition (the "missed/double weekly review" case). Two devices converge
///   on the same max once they hold the same marker set.
/// - **Active slots** reconcile to `derived ?? cache`: the primary association
///   link wins (convergent), falling back to the cached value for agents
///   created before their slot link existed (e.g. `agentDay`, added in B3).
///
/// Fields the log does not own are left on the cache by construction:
/// `recentHeadMessageId` (append-path-maintained), the G-counters (already
/// convergent), device-local scheduling, and `awaitingContent` (no backing log
/// event yet — see `deriveAgentState`).
AgentStateEntity reconcileAgentState({
  required AgentStateEntity cache,
  required Iterable<AgentMessageEntity> messages,
  required Iterable<AgentLink> links,
  String Function(AgentMessageEntity message)? hostIdOf,
}) {
  final derived = deriveAgentState(
    agentId: cache.agentId,
    messages: messages,
    links: links,
    hostIdOf: hostIdOf,
  );
  final slots = cache.slots;
  return cache.copyWith(
    lastWakeAt: _laterOf(derived.lastWakeAt, cache.lastWakeAt),
    slots: slots.copyWith(
      activeTaskId: derived.activeTaskId ?? slots.activeTaskId,
      activeProjectId: derived.activeProjectId ?? slots.activeProjectId,
      activeDayId: derived.activeDayId ?? slots.activeDayId,
      activeTemplateId: derived.activeTemplateId ?? slots.activeTemplateId,
      lastOneOnOneAt: _laterOf(derived.lastOneOnOneAt, slots.lastOneOnOneAt),
      lastFeedbackScanAt: _laterOf(
        derived.lastFeedbackScanAt,
        slots.lastFeedbackScanAt,
      ),
      lastDailyWakeAt: _laterOf(derived.lastDailyWakeAt, slots.lastDailyWakeAt),
      lastWeeklyReviewAt: _laterOf(
        derived.lastWeeklyReviewAt,
        slots.lastWeeklyReviewAt,
      ),
    ),
  );
}

/// The later of two nullable timestamps (null is "no value"). Used to reconcile
/// monotonic watermarks without regressing either side.
DateTime? _laterOf(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}
