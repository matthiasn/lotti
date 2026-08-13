import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';

/// How long a banner remains current while it is actually eligible to show.
const goalBannerLifetime = Duration(hours: 72);

/// Durable provenance key for a temporarily hidden active goal banner.
const goalBannerSnoozedUntilKey = 'snoozedUntil';

/// Returns the persisted snooze deadline, or null for absent/malformed data.
DateTime? goalBannerSnoozedUntil(GoalNudgeEntity nudge) {
  if (nudge.snoozedUntil != null) return nudge.snoozedUntil!.toUtc();
  // A typed day dismissal dual-writes the same provenance deadline solely for
  // older clients. Current clients use the calendar-day gate instead of
  // reporting that compatibility value as a snooze.
  if (nudge.dismissedForDayAt != null) return null;
  final raw = nudge.provenance[goalBannerSnoozedUntilKey];
  return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
}

/// Whether [nudge] is still inside its user-requested quiet interval.
bool goalBannerIsSnoozed(GoalNudgeEntity nudge, DateTime now) {
  final until = goalBannerSnoozedUntil(nudge);
  return until != null && now.toUtc().isBefore(until);
}

/// Whether the banner is inside its persisted "not today" interval on this
/// device. Calendar-day comparison is local and component-based, so DST days
/// remain 23 or 25 hours instead of becoming a rolling 24-hour dismissal.
bool goalBannerIsDismissedForDay(GoalNudgeEntity nudge, DateTime now) {
  final dismissedAt = nudge.dismissedForDayAt;
  if (dismissedAt == null) return false;
  return GoalWindow.dayUtc(dismissedAt.toLocal()) ==
      GoalWindow.dayUtc(now.toLocal());
}

/// The next local calendar boundary after [now].
DateTime goalBannerNextLocalMidnight(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day + 1);
}

Map<String, String> _legacyQuietDeadline(
  Map<String, String> provenance,
  DateTime until,
) => {
  for (final entry in provenance.entries)
    if (entry.key != goalBannerSnoozedUntilKey &&
        entry.key != 'snoozeReason' &&
        entry.key != 'snoozedAt')
      entry.key: entry.value,
  // Older clients only understand this provenance field. Keep writing it
  // while typed visibility state can sync to mixed-version devices.
  goalBannerSnoozedUntilKey: until.toUtc().toIso8601String(),
};

DateTime _staleAtAfterQuietPeriod(DateTime until) =>
    until.toUtc().add(goalBannerLifetime);

/// Applies a durable snooze while preserving an append-only timing event.
GoalNudgeEntity snoozeGoalBannerEntity({
  required GoalNudgeEntity nudge,
  required DateTime now,
  required DateTime until,
  required String eventId,
}) {
  final exactDuration = until.toUtc().difference(now.toUtc());
  if (exactDuration <= Duration.zero) {
    throw ArgumentError.value(until, 'until', 'must be in the future');
  }
  final durationMinutes = (exactDuration.inSeconds + 59) ~/ 60;
  final event = GoalNudgeSnooze(
    id: eventId,
    activation: nudge.activationCount,
    snoozedAt: now.toUtc(),
    snoozedUntil: until.toUtc(),
    duration: goalBannerSnoozeDurationFor(exactDuration),
    durationMinutes: durationMinutes,
    utcOffsetMinutes: now.timeZoneOffset.inMinutes,
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
GoalNudgeEntity dismissGoalBannerForDayEntity({
  required GoalNudgeEntity nudge,
  required DateTime now,
  required String eventId,
}) {
  final hiddenUntil = goalBannerNextLocalMidnight(now);
  final staleAfterDismissal = _staleAtAfterQuietPeriod(hiddenUntil);
  final event = GoalNudgeDayDismissal(
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
