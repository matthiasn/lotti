import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';

/// Slot helpers for day-agent identities.
extension DayAgentSlots on AgentSlots {
  /// Whether this state is bound to a Daily OS day plan.
  bool get hasActiveDay => activeDayId != null && activeDayId!.isNotEmpty;
}

/// Normalizes [date] to the local calendar day used by DayPlan IDs.
///
/// Converts to local time first so a UTC-typed [date] (e.g. a timestamp
/// deserialized as UTC) is bucketed to the user's actual local calendar day
/// rather than the UTC day, which would shift near midnight. A no-op for the
/// already-local timestamps the app produces via `clock.now()`.
DateTime localDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Stable day-agent subject ID for a local calendar [date].
String dayAgentIdForDate(DateTime date) => dayPlanId(localDay(date));

/// Day workspace a capture belongs to (ADR 0022), derived-on-read.
///
/// Returns the explicit [CaptureEntity.dayId] when present, otherwise derives
/// it from [CaptureEntity.capturedAt] so captures synced from older peers
/// (which carry no `dayId`) still resolve to a concrete day workspace.
String captureDayId(CaptureEntity capture) => capture.dayId.isNotEmpty
    ? capture.dayId
    : dayAgentIdForDate(capture.capturedAt);

/// Deterministic agent-entity ID for the drafted day plan keyed by [dayId].
///
/// Same prefix used by `DayAgentPlanService` so cross-service lookups
/// (e.g. `DayAgentService.enqueueRefineWake` pre-checking that a plan
/// exists) stay in sync without leaking the constant.
String dayAgentPlanEntityId(String dayId) => 'day_agent_plan:$dayId';

/// Deterministic agent-entity ID for the contemporaneous day summary keyed by
/// [dayId].
///
/// One register per day: within-window rewrites upsert the same id. Like
/// `day_agent_plan:<dayId>`, the id deliberately carries no agentId (the same
/// latent identity-recreation hazard, precedented and accepted).
String dayAgentSummaryEntityId(String dayId) => 'day_agent_summary:$dayId';

/// Deterministic agent-entity ID for the coordinator-issued day directive
/// keyed by [dayId] (ADR 0032 phase 3).
///
/// One revisable register per day: the coordinator revises it in place
/// (newest revision wins via LWW), and any day owner reads it by PK — no
/// projection table needed.
String dayDirectiveEntityId(String dayId) => 'day_directive:$dayId';

/// Prefix for append-only day-status events (ADR 0032 phase 3):
/// `day_status:<dayId>:<uuid>`.
const dayStatusEventIdPrefix = 'day_status:';

/// Builds a fresh day-status event ID for [dayId] with the caller-supplied
/// [suffix] (a UUID). Events are append-only and never revised, so the ID is
/// unique per raise, unlike the keyed registers above.
String dayStatusEventId(String dayId, String suffix) =>
    '$dayStatusEventIdPrefix$dayId:$suffix';

/// Monday 00:00 local time of the calendar week containing [date].
///
/// Weeks are ISO weeks (Monday-start), matching the digest's "recent weeks"
/// framing. Normalizes through [localDay] first so UTC-typed inputs bucket to
/// the user's local week. Uses component day arithmetic (not
/// `subtract(Duration)`, which is instant-based) so the result stays at
/// local midnight across DST transitions, where a day may be 23 or 25 hours.
DateTime weekStartFor(DateTime date) {
  final day = localDay(date);
  return DateTime(
    day.year,
    day.month,
    day.day - (day.weekday - DateTime.monday),
  );
}

/// Deterministic agent-entity ID for the weekly rollup register keyed by the
/// week's Monday: `week_rollup:<yyyy-MM-dd>`.
///
/// One revisable register per calendar week, recomputed from source data at
/// digest time (plain LWW — a recompute on any device converges).
String weekRollupEntityId(DateTime weekStart) =>
    'week_rollup:${localDay(weekStart).toIso8601String().substring(0, 10)}';
