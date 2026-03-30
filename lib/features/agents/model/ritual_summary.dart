import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';

@immutable
class DailyWakeCountBucket {
  const DailyWakeCountBucket({
    required this.date,
    required this.wakeCount,
  });

  final DateTime date;
  final int wakeCount;
}

@immutable
class RitualSummaryMetrics {
  const RitualSummaryMetrics({
    required this.lifetimeWakeCount,
    required this.wakesSinceLastSession,
    required this.totalTokenUsageSinceLastSession,
    required this.meanTimeToResolution,
    required this.dailyWakeCounts,
  });

  final int lifetimeWakeCount;
  final int wakesSinceLastSession;
  final int totalTokenUsageSinceLastSession;
  final Duration? meanTimeToResolution;
  final List<DailyWakeCountBucket> dailyWakeCounts;
}

@immutable
class RitualSessionHistoryEntry {
  const RitualSessionHistoryEntry({
    required this.session,
    this.recap,
  });

  final EvolutionSessionEntity session;
  final EvolutionSessionRecapEntity? recap;
}
