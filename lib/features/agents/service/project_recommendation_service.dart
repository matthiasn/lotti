import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Persists a project agent's confirmed "next steps" as durable
/// [ProjectRecommendationEntity] rows on the project detail page.
///
/// Invoked from the project change-set confirmation flow once the user accepts
/// a `recommend_next_steps` proposal: it supersedes the project's existing
/// active recommendations and writes the newly confirmed steps in one
/// transaction, then pings [UpdateNotifications] so the UI refreshes.
class ProjectRecommendationService {
  ProjectRecommendationService({
    required this._syncService,
    required this._notifications,
    this._domainLogger,
  });

  final AgentSyncService _syncService;
  final UpdateNotifications _notifications;
  final DomainLogger? _domainLogger;

  static const _uuid = Uuid();
  static const _sub = 'ProjectRecommendationService';

  Future<void> recordConfirmedRecommendations({
    required ChangeSetEntity changeSet,
    required ChangeDecisionEntity decision,
  }) async {
    final steps = _parseSteps(decision.args?['steps']);
    if (steps.isEmpty) {
      throw ArgumentError(
        'recommend_next_steps decision does not contain any valid steps',
      );
    }

    final now = clock.now();
    await _syncService.runInTransaction(() async {
      final existing = await _syncService.repository.getEntitiesByAgentId(
        changeSet.agentId,
        type: AgentEntityTypes.projectRecommendation,
      );

      final activeRecommendations = existing
          .whereType<ProjectRecommendationEntity>()
          .where(
            (recommendation) =>
                recommendation.projectId == changeSet.taskId &&
                recommendation.status == ProjectRecommendationStatus.active,
          );

      for (final recommendation in activeRecommendations) {
        await _syncService.upsertEntity(
          recommendation.copyWith(
            status: ProjectRecommendationStatus.superseded,
            updatedAt: now,
            supersededAt: now,
          ),
        );
      }

      for (final indexedStep in steps.indexed) {
        final index = indexedStep.$1;
        final step = indexedStep.$2;
        await _syncService.upsertEntity(
          AgentDomainEntity.projectRecommendation(
            id: _uuid.v4(),
            agentId: changeSet.agentId,
            projectId: changeSet.taskId,
            title: step.title,
            position: index,
            status: ProjectRecommendationStatus.active,
            createdAt: now,
            updatedAt: now,
            vectorClock: const VectorClock({}),
            sourceChangeSetId: changeSet.id,
            sourceDecisionId: decision.id,
            rationale: step.rationale,
            priority: step.priority,
          ),
        );
      }
    });

    _domainLogger?.log(
      LogDomain.agentWorkflow,
      'Recorded ${steps.length} active project recommendations for '
      '${DomainLogger.sanitizeId(changeSet.taskId)}',
      subDomain: _sub,
    );
    _notifyRecommendationUpdate(changeSet.agentId, changeSet.taskId);
  }

  Future<bool> markResolved(String recommendationId) {
    return _transitionRecommendation(
      recommendationId,
      ProjectRecommendationStatus.resolved,
    );
  }

  Future<bool> dismissRecommendation(String recommendationId) {
    return _transitionRecommendation(
      recommendationId,
      ProjectRecommendationStatus.dismissed,
    );
  }

  Future<bool> _transitionRecommendation(
    String recommendationId,
    ProjectRecommendationStatus status,
  ) async {
    final entity = await _syncService.repository.getEntity(recommendationId);
    final recommendation = entity?.mapOrNull(projectRecommendation: (e) => e);
    if (recommendation == null ||
        recommendation.status != ProjectRecommendationStatus.active) {
      return false;
    }

    final now = clock.now();
    await _syncService.upsertEntity(
      recommendation.copyWith(
        status: status,
        updatedAt: now,
        resolvedAt: status == ProjectRecommendationStatus.resolved
            ? now
            : recommendation.resolvedAt,
        dismissedAt: status == ProjectRecommendationStatus.dismissed
            ? now
            : recommendation.dismissedAt,
      ),
    );

    _domainLogger?.log(
      LogDomain.agentWorkflow,
      'Marked project recommendation '
      '${DomainLogger.sanitizeId(recommendation.id)} as ${status.name}',
      subDomain: _sub,
    );
    _notifyRecommendationUpdate(
      recommendation.agentId,
      recommendation.projectId,
    );
    return true;
  }

  void _notifyRecommendationUpdate(String agentId, String projectId) {
    _notifications.notifyUiOnly({agentId, projectId, agentNotification});
  }

  List<_RecommendationDraft> _parseSteps(Object? rawSteps) {
    if (rawSteps is! List) return const [];

    final steps = <_RecommendationDraft>[];
    for (final rawStep in rawSteps) {
      if (rawStep is! Map) continue;

      final title = rawStep['title'];
      if (title is! String || title.trim().isEmpty) {
        continue;
      }

      final rationale = rawStep['rationale'];
      final priority = rawStep['priority'];
      steps.add(
        _RecommendationDraft(
          title: title.trim(),
          rationale: rationale is String && rationale.trim().isNotEmpty
              ? rationale.trim()
              : null,
          priority: priority is String && priority.trim().isNotEmpty
              ? priority.trim().toUpperCase()
              : null,
        ),
      );
    }
    return steps;
  }
}

class _RecommendationDraft {
  const _RecommendationDraft({
    required this.title,
    this.rationale,
    this.priority,
  });

  final String title;
  final String? rationale;
  final String? priority;
}
