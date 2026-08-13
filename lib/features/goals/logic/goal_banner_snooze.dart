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
  final staleAfterSnooze = until.toUtc().add(goalBannerLifetime);
  return nudge.copyWith(
    snoozedUntil: until.toUtc(),
    lastSnoozeDuration: event.duration,
    snoozeHistory: [...nudge.snoozeHistory, event],
    dismissedForDayAt: null,
    staleAt: nudge.staleAt == null || nudge.staleAt!.isBefore(staleAfterSnooze)
        ? staleAfterSnooze
        : nudge.staleAt,
    updatedAt: now,
    provenance: {
      for (final entry in nudge.provenance.entries)
        if (entry.key != goalBannerSnoozedUntilKey &&
            entry.key != 'snoozeReason' &&
            entry.key != 'snoozedAt')
          entry.key: entry.value,
    },
  );
}
