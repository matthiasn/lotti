import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ritual_review_providers.g.dart';

/// Returns the most recent active [EvolutionSessionEntity] for a template,
/// or `null` if there is no active session pending review.
///
/// Reuses the cached [evolutionSessionsProvider] to avoid extra DB queries.
@riverpod
Future<AgentDomainEntity?> pendingRitualReview(
  Ref ref,
  String templateId,
) async {
  final sessions =
      await ref.watch(evolutionSessionsProvider(templateId).future);
  final typed = sessions.whereType<EvolutionSessionEntity>();
  for (final session in typed) {
    if (session.status == EvolutionSessionStatus.active) {
      return session;
    }
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
  final sessions =
      await ref.watch(evolutionSessionsProvider(templateId).future);
  final typed = sessions.whereType<EvolutionSessionEntity>().toList();

  final total = typed.length;
  final completed =
      typed.where((s) => s.status == EvolutionSessionStatus.completed).length;
  final abandoned =
      typed.where((s) => s.status == EvolutionSessionStatus.abandoned).length;
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
