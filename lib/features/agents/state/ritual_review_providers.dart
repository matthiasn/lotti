import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:lotti/features/agents/database/agent_database.dart'
    show WakeRunLogData;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_time_utils.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/model/task_resolution_time_series.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/wake_run_chart_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ritual_review_providers.g.dart';

/// Returns the most recent active [EvolutionSessionEntity] for a template,
/// or `null` if there is no active session pending review.
///
/// Only the newest session is considered: if a newer completed or abandoned
/// session exists, older active sessions are treated as stale and ignored.
/// Actual DB reconciliation (marking stale sessions as abandoned) happens
/// in `TemplateEvolutionWorkflow` during startSession/approveProposal.
///
/// Reuses the cached [evolutionSessionsProvider] to avoid extra DB queries.
@riverpod
Future<AgentDomainEntity?> pendingRitualReview(
  Ref ref,
  String templateId,
) async {
  final sessions = await ref.watch(
    evolutionSessionsProvider(templateId).future,
  );
  final typed = sessions.whereType<EvolutionSessionEntity>().toList();

  // Sessions are newest-first. Only return the newest one if it's active.
  // An active session that's not the newest is stale and should not be shown.
  final newest = typed.firstOrNull;
  if (newest != null && newest.status == EvolutionSessionStatus.active) {
    return newest;
  }
  return null;
}

/// Extracts classified feedback for a template's review window.
///
/// Uses the feedback extraction service to scan the default 7-day window.
@riverpod
Future<ClassifiedFeedback?> ritualFeedback(
  Ref ref,
  String templateId,
) async {
  ref.watch(agentUpdateStreamProvider(templateId));
  final service = ref.watch(feedbackExtractionServiceProvider);
  final now = clock.now();
  final since = now.subtract(const Duration(days: 7));
  return service.extract(templateId: templateId, since: since, until: now);
}

/// Set of template IDs with pending rituals.
@riverpod
Future<Set<String>> templatesPendingReview(Ref ref) async {
  ref.watch(agentUpdateStreamProvider(agentNotification));
  final sessions = await ref.watch(allEvolutionSessionsProvider.future);
  final activeTemplateIds = <String>{};
  for (final session in sessions) {
    if (session is EvolutionSessionEntity &&
        session.status == EvolutionSessionStatus.active) {
      activeTemplateIds.add(session.templateId);
    }
  }
  return activeTemplateIds;
}

/// Aggregate stats for evolution sessions of a template.
@riverpod
Future<EvolutionSessionStats> evolutionSessionStats(
  Ref ref,
  String templateId,
) async {
  ref.watch(agentUpdateStreamProvider(templateId));
  final sessions = await ref.watch(
    evolutionSessionsProvider(templateId).future,
  );
  final typed = sessions.whereType<EvolutionSessionEntity>().toList();

  final total = typed.length;
  final completed = typed
      .where((s) => s.status == EvolutionSessionStatus.completed)
      .length;
  final abandoned = typed
      .where((s) => s.status == EvolutionSessionStatus.abandoned)
      .length;
  final approvalRate = total > 0 ? completed / total : 0.0;

  return EvolutionSessionStats(
    totalSessions: total,
    completedCount: completed,
    abandonedCount: abandoned,
    approvalRate: approvalRate,
  );
}

/// Simple data class for evolution session aggregate stats.
class EvolutionSessionStats {
  const EvolutionSessionStats({
    required this.totalSessions,
    required this.completedCount,
    required this.abandonedCount,
    required this.approvalRate,
  });

  final int totalSessions;
  final int completedCount;
  final int abandonedCount;
  final double approvalRate;
}

/// Returns the completion timestamp of the newest completed ritual session
/// for a template, if any.
@riverpod
Future<DateTime?> latestCompletedRitualTimestamp(
  Ref ref,
  String templateId,
) async {
  final sessions = await ref.watch(
    evolutionSessionsProvider(templateId).future,
  );
  final latestCompleted = sessions
      .whereType<EvolutionSessionEntity>()
      .firstWhereOrNull(
        (session) => session.status == EvolutionSessionStatus.completed,
      );
  return latestCompleted?.completedAt ?? latestCompleted?.createdAt;
}

/// History entries for past ritual sessions, backed by persisted recap data.
@riverpod
Future<List<RitualSessionHistoryEntry>> ritualSessionHistory(
  Ref ref,
  String templateId,
) async {
  ref.watch(agentUpdateStreamProvider(templateId));
  final templateService = ref.watch(agentTemplateServiceProvider);
  final (sessions, recaps) = await (
    ref.watch(evolutionSessionsProvider(templateId).future),
    templateService.getEvolutionSessionRecaps(templateId),
  ).wait;

  final recapBySessionId = {
    for (final recap in recaps) recap.sessionId: recap,
  };

  return sessions
      .whereType<EvolutionSessionEntity>()
      .where((session) => session.status != EvolutionSessionStatus.active)
      .map(
        (session) => RitualSessionHistoryEntry(
          session: session,
          recap: recapBySessionId[session.id],
        ),
      )
      .toList();
}

/// Compact summary metrics for ritual home and chat header surfaces.
@riverpod
Future<RitualSummaryMetrics> ritualSummaryMetrics(
  Ref ref,
  String templateId,
) async {
  ref.watch(agentUpdateStreamProvider(templateId));
  final templateService = ref.watch(agentTemplateServiceProvider);
  final repository = ref.watch(agentRepositoryProvider);
  final lastSessionAt = await ref.watch(
    latestCompletedRitualTimestampProvider(templateId).future,
  );
  final resolutionTimeSeries = await ref.watch(
    templateTaskResolutionTimeSeriesProvider(templateId).future,
  );

  final now = clock.now();
  final today = truncateToDay(now);
  final chartStart = today.subtract(const Duration(days: 29));

  final lifetimeWakeCount = await templateService.getLifetimeWakeCount(
    templateId,
  );
  final recentWakeRuns = await templateService.getWakeRunsInWindow(
    templateId,
    since: chartStart,
    until: now,
  );

  final wakesSinceLastSession = lastSessionAt == null
      ? lifetimeWakeCount
      : (await templateService.getWakeRunsInWindow(
          templateId,
          since: lastSessionAt,
          until: now,
        )).length;

  final int totalTokenUsageSinceLastSession;
  if (lastSessionAt == null) {
    final sums = await repository.sumTokenUsageForTemplate(templateId);
    totalTokenUsageSinceLastSession =
        sums.totalInput + sums.totalOutput + sums.totalThoughts;
  } else {
    final sums = await repository.sumTokenUsageForTemplateSince(
      templateId,
      since: lastSessionAt,
    );
    totalTokenUsageSinceLastSession =
        sums.totalInput + sums.totalOutput + sums.totalThoughts;
  }

  return RitualSummaryMetrics(
    lifetimeWakeCount: lifetimeWakeCount,
    wakesSinceLastSession: wakesSinceLastSession,
    totalTokenUsageSinceLastSession: totalTokenUsageSinceLastSession,
    meanTimeToResolution: _weightedMeanMttr(
      resolutionTimeSeries.dailyBuckets,
    ),
    dailyWakeCounts: _buildDailyWakeCounts(
      recentWakeRuns: recentWakeRuns,
      chartStart: chartStart,
      today: today,
    ),
  );
}

Duration? _weightedMeanMttr(List<DailyResolutionBucket> buckets) {
  var totalResolved = 0;
  var totalMs = 0;

  for (final bucket in buckets) {
    if (bucket.resolvedCount <= 0) {
      continue;
    }
    totalResolved += bucket.resolvedCount;
    totalMs += bucket.averageMttr.inMilliseconds * bucket.resolvedCount;
  }

  if (totalResolved == 0) {
    return null;
  }
  return Duration(milliseconds: totalMs ~/ totalResolved);
}

List<DailyWakeCountBucket> _buildDailyWakeCounts({
  required List<WakeRunLogData> recentWakeRuns,
  required DateTime chartStart,
  required DateTime today,
}) {
  final countsByDay = <DateTime, int>{};
  for (final run in recentWakeRuns) {
    final day = truncateToDay(run.createdAt);
    countsByDay.update(day, (count) => count + 1, ifAbsent: () => 1);
  }

  final buckets = <DailyWakeCountBucket>[];
  var current = chartStart;
  while (!current.isAfter(today)) {
    buckets.add(
      DailyWakeCountBucket(
        date: current,
        wakeCount: countsByDay[current] ?? 0,
      ),
    );
    current = current.add(const Duration(days: 1));
  }
  return buckets;
}
