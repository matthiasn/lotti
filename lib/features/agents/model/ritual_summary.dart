import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';

/// Wake runs that occurred on a single calendar [date], for the per-day bars
/// of the ritual summary's wake-activity chart.
@immutable
class DailyWakeCountBucket {
  const DailyWakeCountBucket({
    required this.date,
    required this.wakeCount,
  });

  final DateTime date;
  final int wakeCount;
}

/// Headline metrics for an agent's evolution-ritual review screen.
///
/// Frames "how much has this agent done" against the last evolution session:
/// [lifetimeWakeCount] is the all-time total, while [wakesSinceLastSession] and
/// [totalTokenUsageSinceLastSession] measure activity accumulated since the
/// previous ritual so the user can gauge whether another review is warranted.
/// [dailyWakeCounts] feeds the trend chart.
@immutable
class RitualSummaryMetrics {
  const RitualSummaryMetrics({
    required this.lifetimeWakeCount,
    required this.wakesSinceLastSession,
    required this.totalTokenUsageSinceLastSession,
    required this.dailyWakeCounts,
  });

  final int lifetimeWakeCount;
  final int wakesSinceLastSession;
  final int totalTokenUsageSinceLastSession;
  final List<DailyWakeCountBucket> dailyWakeCounts;
}

/// One row of the ritual-session history list: a past evolution [session]
/// paired with its [recap] entity when one was generated (`null` while a
/// recap is still pending or was never produced).
@immutable
class RitualSessionHistoryEntry {
  const RitualSessionHistoryEntry({
    required this.session,
    this.recap,
  });

  final EvolutionSessionEntity session;
  final EvolutionSessionRecapEntity? recap;
}
