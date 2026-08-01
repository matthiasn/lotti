import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';

// Re-exported so the many Daily OS call sites that reach for these through
// the slot helpers keep working; they now live beside dayPlanId so the agent
// persistence layer can derive a capture's day without depending on a feature.
export 'package:lotti/classes/day_plan.dart' show dayAgentIdForDate, localDay;

/// Day workspace a capture belongs to (ADR 0022), derived-on-read.
///
/// Returns the explicit [CaptureEntity.dayId] when present, otherwise derives
/// it from [CaptureEntity.capturedAt] so a raw capture from an older peer still
/// resolves before the repository materializes and preserves that day.
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

/// Stable day-status event ID for one durable processing job.
///
/// A draft attempt may raise status before its required plan artifact, then
/// fail and retry under a fresh wake run key. Keying that status to the
/// durable job makes each attempt upsert the same event instead of appending
/// duplicate escalations.
String dayStatusEventIdForProcessingJob(String dayId, String processingJobId) =>
    dayStatusEventId(dayId, 'job:$processingJobId');

/// `WeekRollupEntity.bucketingRule` value for the canonical rule: recorded
/// minutes bucket by the wall clock of the device that recorded them.
///
/// A register without this stamp is legacy — bucketed in whichever zone the
/// reading device happened to be in.
const recordedLocalBucketingRule = 'recordedLocal';

/// The wall clock an instant was recorded at, from the UTC offset the
/// recording device stamped on the entry (`Metadata.utcOffset`, in minutes).
///
/// Returned UTC-typed, but it is **not a UTC instant** — it is a zone-free
/// calendar reading, the numbers that were on the recorder's clock. That is
/// what makes it canonical: every device derives the same reading from the
/// same synced entry, whereas `start.toLocal()` answers differently on a
/// device in another zone.
///
/// A legacy entry with no stamped offset falls back to the reading device's
/// zone — the pre-canonical behaviour, and the only answer still available.
DateTime recordedWallClock(DateTime start, int? utcOffsetMinutes) {
  if (utcOffsetMinutes == null) {
    final local = start.toLocal();
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
  }
  return start.toUtc().add(Duration(minutes: utcOffsetMinutes));
}

/// Monday 00:00 of the ISO week containing [date], read from [date]'s own
/// calendar components and returned UTC-typed — the zone-free week key that
/// [weekRollupEntityId] hashes.
///
/// Component day arithmetic (not `subtract(Duration)`, which is instant-based)
/// keeps the result at midnight across DST, where a local day may be 23 or 25
/// hours. Because it reads components rather than converting, it accepts both
/// a local-midnight day-plan date and a [recordedWallClock] reading and gives
/// the same answer for the same calendar date.
DateTime canonicalWeekStart(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  return DateTime.utc(
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
///
/// Keyed on [weekStart]'s calendar components, NOT on the instant it names:
/// a converting read would give two devices in different zones two different
/// ids for the same week, which is the register-flapping this file's
/// bucketing rules exist to prevent.
String weekRollupEntityId(DateTime weekStart) =>
    'week_rollup:${_isoDate(weekStart)}';

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
