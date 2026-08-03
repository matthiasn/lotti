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
    required this.dayId,
    required this.triggerTokens,
    this.captureIds = const [],
    this.decidedTaskIds = const [],
    this.decidedCaptureItemIds = const [],
    this.processingJobId,
  });

  /// Builds a context from [triggerTokens] for a [dayId] the caller has
  /// already resolved (via [resolvePlannerWakeDay] plus any fallback).
  ///
  /// Payload IDs are extracted with the deterministic helpers from
  /// `day_agent_trigger_tokens.dart`.
  factory DailyOsPlannerWakeContext.fromTokens({
    required String dayId,
    required Set<String> triggerTokens,
  }) {
    return DailyOsPlannerWakeContext(
      dayId: dayId,
      triggerTokens: Set.unmodifiable(triggerTokens),
      captureIds: captureIdsFromTriggerTokens(triggerTokens),
      decidedTaskIds: decidedTaskIdsFromTriggerTokens(triggerTokens),
      decidedCaptureItemIds: decidedCaptureItemIdsFromTriggerTokens(
        triggerTokens,
      ),
      processingJobId: processingJobIdFromTriggerTokens(triggerTokens),
    );
  }

  /// Day workspace this wake operates on (`dayplan-YYYY-MM-DD`).
  final String dayId;

  /// Raw trigger tokens the wake was enqueued with.
  final Set<String> triggerTokens;

  /// Submitted capture IDs advertised on the wake, sorted.
  final List<String> captureIds;

  /// Decided task IDs advertised on the wake.
  final List<String> decidedTaskIds;

  /// Decided parsed-capture-item IDs advertised on the wake.
  final List<String> decidedCaptureItemIds;

  /// Durable outbox job whose attempt opened this wake, when present.
  ///
  /// Retries of the same job carry the same id. Side effects that can occur
  /// before the terminal artifact use this as their idempotency scope.
  final String? processingJobId;

  /// Whether the wake requests drafting for this context's day workspace.
  bool get isDraftingWake => hasDraftingTokenForDay(triggerTokens, dayId);

  /// Whether the wake requests a refine for this context's day workspace.
  bool get isRefineWake => hasRefineTokenForDay(triggerTokens, dayId);

  /// Whether this is a coordinator digest wake anchored to this context's
  /// day (ADR 0032 phase 3).
  bool get isDigestWake => triggerTokens.contains(dayAgentDigestToken(dayId));
}
