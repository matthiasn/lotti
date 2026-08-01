import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
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

/// The wall clock a recorded entry carries, as a zone-free calendar reading.
///
/// `Metadata.dateFrom` is a local-typed timestamp serialized with
/// `toIso8601String()`, which emits **no zone suffix**, and the receiving
/// device parses it back as local. Its *components* are therefore the
/// recording device's wall clock on every device that holds the entry, while
/// the instant it denotes is not — that is reader-relative, because each
/// device resolves those components in its own zone.
///
/// So the canonical reading is the components, read as-is. Converting first
/// (`start.toUtc()`, `start.toLocal()`) is precisely the mistake: it turns a
/// device-independent calendar reading back into a reader-relative instant,
/// which is what made two devices disagree about the same entry's week.
///
/// The stamped `Metadata.utcOffset` is deliberately NOT consulted. It records
/// the offset at *creation* time rather than at `dateFrom`, so a backfilled or
/// cross-DST entry carries an offset that does not apply to its own timestamp;
/// and it is absent on older entries, which would leave them on a different
/// rule from everything else. The components need neither.
DateTime recordedWallClock(DateTime start) => DateTime.utc(
  start.year,
  start.month,
  start.day,
  start.hour,
  start.minute,
  start.second,
  start.millisecond,
  start.microsecond,
);

/// The wall-clock length of a recorded interval, read from its own
/// components.
///
/// `dateTo - dateFrom` on the parsed values is reader-relative for the same
/// reason the bucket was: both strings arrive without a zone suffix and are
/// resolved in the reader's zone, so an interval that crosses a DST boundary
/// subtracts to a different number of minutes on different devices. A New York
/// 01:30–03:30 on the spring-forward day is 60 minutes there and 120 on a UTC
/// reader — and both would be stamped canonical, leaving the register free to
/// flap between them.
///
/// Reading both ends as zone-free calendar values gives the length the
/// recorder's own clock showed, identically everywhere.
Duration canonicalRecordedDuration(Metadata meta) =>
    canonicalWallClockDuration(meta.dateFrom, meta.dateTo);

/// The wall-clock length between two zone-less timestamps.
Duration canonicalWallClockDuration(DateTime from, DateTime to) =>
    recordedWallClock(to).difference(recordedWallClock(from));

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
/// week's Monday: `week_rollup_v2:<yyyy-MM-dd>`.
///
/// One revisable register per calendar week, recomputed from source data at
/// digest time (plain LWW — a recompute on any device converges).
///
/// Keyed on [weekStart]'s calendar components, NOT on the instant it names:
/// a converting read would give two devices in different zones two different
/// ids for the same week, which is the register-flapping this file's
/// bucketing rules exist to prevent.
///
/// **The `_v2` generation is what keeps a staggered upgrade honest.** A device
/// still on the previous build recomputes the old `week_rollup:` id with the
/// old reader-local rule and writes it back without the canonical stamp; had
/// both generations shared an id, the two builds would have overwritten each
/// other for as long as the rollout lasted — the exact loop this change
/// exists to end. Old-generation rows are inert: nothing reads them again.
String weekRollupEntityId(DateTime weekStart) =>
    'week_rollup_v2:${isoCalendarDate(weekStart)}';

/// The previous generation's id for the same week.
///
/// Read only to carry a deliberate deletion forward: a week the user
/// tombstoned under v1 must not come back to life because the generation
/// changed underneath it.
String legacyWeekRollupEntityId(DateTime weekStart) =>
    'week_rollup:${isoCalendarDate(weekStart)}';

/// `yyyy-MM-dd` read from [date]'s own calendar components.
///
/// Never `toIso8601String()` after a `localDay`/`toUtc` conversion: on a
/// zone-free key that moves the date, which is how a canonical Monday ends up
/// labelled as the preceding Sunday.
String isoCalendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
