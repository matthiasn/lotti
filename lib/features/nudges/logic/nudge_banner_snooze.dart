import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';

/// How long a banner remains current while it is actually eligible to show.
const nudgeBannerLifetime = Duration(hours: 72);

/// Durable provenance key for a temporarily hidden active banner.
const nudgeBannerSnoozedUntilKey = 'snoozedUntil';

/// Returns the persisted snooze deadline, or null for absent/malformed data.
DateTime? nudgeBannerSnoozedUntil(NudgeEntityView nudge) {
  if (nudge.snoozedUntil != null) return nudge.snoozedUntil!.toUtc();
  // A typed day dismissal dual-writes the same provenance deadline solely for
  // older clients. Current clients use the calendar-day gate instead of
  // reporting that compatibility value as a snooze.
  if (nudge.dismissedForDayAt != null) return null;
  final raw = nudge.provenance[nudgeBannerSnoozedUntilKey];
  return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
}

/// Whether [nudge] is still inside its user-requested quiet interval.
bool nudgeBannerIsSnoozed(NudgeEntityView nudge, DateTime now) {
  final until = nudgeBannerSnoozedUntil(nudge);
  return until != null && now.toUtc().isBefore(until);
}

/// Whether the banner is inside its persisted "not today" interval on this
/// device. Calendar-day comparison is local and component-based, so DST days
/// remain 23 or 25 hours instead of becoming a rolling 24-hour dismissal.
bool nudgeBannerIsDismissedForDay(NudgeEntityView nudge, DateTime now) {
  final dismissedAt = nudge.dismissedForDayAt;
  if (dismissedAt == null) return false;
  return GoalWindow.dayUtc(dismissedAt.toLocal()) ==
      GoalWindow.dayUtc(now.toLocal());
}

/// The next local calendar boundary after [now].
DateTime nudgeBannerNextLocalMidnight(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day + 1);
}

Map<String, String> _legacyQuietDeadline(
  Map<String, String> provenance,
  DateTime until,
) => {
  for (final entry in provenance.entries)
    if (entry.key != nudgeBannerSnoozedUntilKey &&
        entry.key != 'snoozeReason' &&
        entry.key != 'snoozedAt')
      entry.key: entry.value,
  // Older clients only understand this provenance field. Keep writing it
  // while typed visibility state can sync to mixed-version devices.
  nudgeBannerSnoozedUntilKey: until.toUtc().toIso8601String(),
};

DateTime _staleAtAfterQuietPeriod(DateTime until) =>
    until.toUtc().add(nudgeBannerLifetime);

/// Applies a durable snooze while preserving unique append-only timing
/// events. Returns the updated entity in its original variant.
AgentDomainEntity snoozeNudgeBannerEntity({
  required NudgeEntityView nudge,
  required DateTime now,
  required DateTime until,
  required String eventId,
  int? returnUtcOffsetMinutes,
}) {
  if (nudge.snoozeHistory.any((event) => event.id == eventId)) {
    return nudge.entity;
  }
  final exactDuration = until.toUtc().difference(now.toUtc());
  if (exactDuration <= Duration.zero) {
    throw ArgumentError.value(until, 'until', 'must be in the future');
  }
  final durationMinutes = (exactDuration.inSeconds + 59) ~/ 60;
  final event = NudgeSnooze(
    id: eventId,
    activation: nudge.activationCount,
    snoozedAt: now.toUtc(),
    snoozedUntil: until.toUtc(),
    duration: nudgeBannerSnoozeDurationFor(exactDuration),
    durationMinutes: durationMinutes,
    utcOffsetMinutes: now.timeZoneOffset.inMinutes,
    returnUtcOffsetMinutes:
        returnUtcOffsetMinutes ?? until.timeZoneOffset.inMinutes,
  );
  final staleAfterSnooze = _staleAtAfterQuietPeriod(until);
  return nudge.copyWith(
    snoozedUntil: until.toUtc(),
    lastSnoozeDuration: event.duration,
    snoozeHistory: [...nudge.snoozeHistory, event],
    dismissedForDayAt: null,
    staleAt: nudge.staleAt == null || nudge.staleAt!.isBefore(staleAfterSnooze)
        ? staleAfterSnooze
        : nudge.staleAt,
    updatedAt: now,
    provenance: _legacyQuietDeadline(nudge.provenance, until),
  );
}

/// Applies a rest-of-local-day dismissal without consuming the banner's
/// visible lifetime, and dual-writes the deadline for older clients.
/// Returns the updated entity in its original variant.
AgentDomainEntity dismissNudgeBannerForDayEntity({
  required NudgeEntityView nudge,
  required DateTime now,
  required String eventId,
}) {
  final hiddenUntil = nudgeBannerNextLocalMidnight(now);
  final staleAfterDismissal = _staleAtAfterQuietPeriod(hiddenUntil);
  final event = NudgeDayDismissal(
    id: eventId,
    activation: nudge.activationCount,
    dismissedAt: now.toUtc(),
    dismissedUntil: hiddenUntil.toUtc(),
    utcOffsetMinutes: now.timeZoneOffset.inMinutes,
  );
  return nudge.copyWith(
    snoozedUntil: null,
    dismissedForDayAt: event.dismissedAt,
    dismissalHistory: [...nudge.dismissalHistory, event],
    staleAt:
        nudge.staleAt == null || nudge.staleAt!.isBefore(staleAfterDismissal)
        ? staleAfterDismissal
        : nudge.staleAt,
    updatedAt: now,
    provenance: _legacyQuietDeadline(nudge.provenance, hiddenUntil),
  );
}
