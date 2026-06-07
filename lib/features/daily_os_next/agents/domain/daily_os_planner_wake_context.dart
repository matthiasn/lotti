import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';

/// Explicit day-workspace context for one Daily OS planner wake (ADR 0022).
///
/// A long-lived planner cannot read its target day from mutable agent state;
/// the wake itself must carry the workspace. This object is the workflow's
/// single source of truth for "what day am I operating on" plus the payload
/// IDs extracted deterministically from the trigger tokens.
class DailyOsPlannerWakeContext {
  /// Creates a wake context for an already-resolved [dayId] workspace.
  DailyOsPlannerWakeContext({
    required this.plannerAgentId,
    required this.dayId,
    required this.runKey,
    required this.threadId,
    required this.triggerTokens,
    this.captureIds = const [],
    this.decidedTaskIds = const [],
    this.decidedCaptureItemIds = const [],
  });

  /// Builds a context from [triggerTokens] for a [dayId] the caller has
  /// already resolved (via [resolvePlannerWakeDay] plus any fallback).
  ///
  /// Payload IDs are extracted with the deterministic helpers from
  /// `day_agent_trigger_tokens.dart`.
  factory DailyOsPlannerWakeContext.fromTokens({
    required String plannerAgentId,
    required String dayId,
    required String runKey,
    required String threadId,
    required Set<String> triggerTokens,
  }) {
    return DailyOsPlannerWakeContext(
      plannerAgentId: plannerAgentId,
      dayId: dayId,
      runKey: runKey,
      threadId: threadId,
      triggerTokens: Set.unmodifiable(triggerTokens),
      captureIds: captureIdsFromTriggerTokens(triggerTokens),
      decidedTaskIds: decidedTaskIdsFromTriggerTokens(triggerTokens),
      decidedCaptureItemIds: decidedCaptureItemIdsFromTriggerTokens(
        triggerTokens,
      ),
    );
  }

  /// Identity of the planner executing this wake.
  final String plannerAgentId;

  /// Day workspace this wake operates on (`dayplan-YYYY-MM-DD`).
  final String dayId;

  /// Deterministic run key of this wake.
  final String runKey;

  /// Thread the wake's messages are recorded under.
  final String threadId;

  /// Raw trigger tokens the wake was enqueued with.
  final Set<String> triggerTokens;

  /// Submitted capture IDs advertised on the wake, sorted.
  final List<String> captureIds;

  /// Decided task IDs advertised on the wake.
  final List<String> decidedTaskIds;

  /// Decided parsed-capture-item IDs advertised on the wake.
  final List<String> decidedCaptureItemIds;

  /// Whether the wake requests drafting for this context's day workspace.
  bool get isDraftingWake => hasDraftingTokenForDay(triggerTokens, dayId);

  /// Whether the wake requests a refine for this context's day workspace.
  bool get isRefineWake => hasRefineTokenForDay(triggerTokens, dayId);

  /// Validates that a tool call targeting [toolDayId] stays inside this
  /// wake's workspace.
  ///
  /// Day-scoped tool calls must be rejected when the requested day differs
  /// from the wake workspace (ADR 0022 Decision 4). A `null`/empty
  /// [toolDayId] is treated as "inherit the wake's day" and passes.
  bool allowsToolDayId(String? toolDayId) {
    if (toolDayId == null || toolDayId.trim().isEmpty) return true;
    return toolDayId.trim() == dayId;
  }
}
