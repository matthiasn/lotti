import 'package:lotti/features/agents/model/agent_domain_entity.dart';

/// Durable provenance key for a temporarily hidden active goal banner.
const goalBannerSnoozedUntilKey = 'snoozedUntil';

/// Returns the persisted snooze deadline, or null for absent/malformed data.
DateTime? goalBannerSnoozedUntil(GoalNudgeEntity nudge) {
  final raw = nudge.provenance[goalBannerSnoozedUntilKey];
  return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
}

/// Whether [nudge] is still inside its user-requested quiet interval.
bool goalBannerIsSnoozed(GoalNudgeEntity nudge, DateTime now) {
  final until = goalBannerSnoozedUntil(nudge);
  return until != null && now.toUtc().isBefore(until);
}
