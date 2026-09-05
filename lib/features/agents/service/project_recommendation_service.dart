import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Owns the current project next steps and their individual user decisions.
/// Successful analyst runs replace active suggestions; failed runs leave them
/// intact. Legacy pending batches are materialized once, newest run first.
class ProjectRecommendationService {
  ProjectRecommendationService({
    required this._syncService,
    this._notifications,
    this.taskDispatcher,
    this._domainLogger,
  });

  final AgentSyncService _syncService;
  final UpdateNotifications? _notifications;
  final AgentToolDispatch? taskDispatcher;
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

  /// Replaces suggestions in the caller's successful-run transaction, including
  /// an empty result. Other pending tools and already decided rows are retained.
  Future<void> replaceForRun({
    required String agentId,
    required String projectId,
    required String runKey,
    required List<Map<String, dynamic>> deferredItems,
  }) async {
    await _syncService.runInTransaction(() async {
      await _replace(
        agentId: agentId,
        projectId: projectId,
        sourceId: runKey,
        rawSteps: [
          for (final item in deferredItems)
            if (item['toolName'] == ProjectAgentToolNames.recommendNextSteps &&
                item['args'] is Map &&
                (item['args'] as Map)['steps'] is List)
              ...(item['args'] as Map)['steps'] as List,
        ],
      );
      await _retractPendingBatches(agentId, projectId);
    });
  }

  /// Upgrades old batches without replaying confirmed or dismissed suggestions.
  /// All writes share a transaction, so provider refreshes cannot migrate twice.
  Future<void> migratePendingBatches(String agentId, String projectId) async {
    var changed = false;
    await _syncService.runInTransaction(() async {
      final sets =
          (await _syncService.repository.getPendingChangeSets(
                agentId,
                taskId: projectId,
              ))
              .whereType<ChangeSetEntity>()
              .where(
                (set) => set.items.any(
                  (item) =>
                      item.toolName ==
                          ProjectAgentToolNames.recommendNextSteps &&
                      item.status == ChangeItemStatus.pending,
                ),
              )
              .toList()
            ..sort((a, b) {
              final order = b.createdAt.compareTo(a.createdAt);
              return order == 0 ? b.id.compareTo(a.id) : order;
            });
      if (sets.isEmpty) return;
      final latest = sets.first;
      final existing = await _syncService.repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.projectRecommendation,
      );
      // A newer confirmed list wins over an older pending batch.
      final hasNewer = existing.whereType<ProjectRecommendationEntity>().any(
        (row) =>
            row.projectId == projectId &&
            !row.createdAt.isBefore(latest.createdAt),
      );
      final report = await _syncService.repository.getLatestReport(
        agentId,
        AgentReportScopes.current,
      );
      final batchIsStale =
          report != null && report.createdAt.isAfter(latest.createdAt);
      if (!hasNewer) {
        await _replace(
          agentId: agentId,
          projectId: projectId,
          sourceId: latest.runKey,
          rawSteps: batchIsStale
              ? []
              : [
                  for (final set in sets.reversed)
                    if (set.runKey == latest.runKey)
                      for (final item in set.items)
                        if (item.toolName ==
                                ProjectAgentToolNames.recommendNextSteps &&
                            item.status == ChangeItemStatus.pending &&
                            item.args['steps'] is List)
                          ...item.args['steps'] as List,
                ],
        );
      }
      await _retractPendingBatches(agentId, projectId);
      changed = true;
    });
    if (changed) _notifyRecommendationUpdate(agentId, projectId);
  }

  Future<void> _replace({
    required String agentId,
    required String projectId,
    required String sourceId,
    required List<dynamic> rawSteps,
  }) async {
    final now = clock.now();
    final existing = await _syncService.repository.getEntitiesByAgentId(
      agentId,
      type: AgentEntityTypes.projectRecommendation,
    );
    final steps = _parseSteps(rawSteps);
    final ids = <String>{};
    for (final entry in steps.indexed) {
      final id = _uuid.v5(
        Namespace.url.value,
        '$agentId/$projectId/$sourceId/${entry.$1}',
      );
      ids.add(id);
      // Retry-safe: never revive an already decided row from this run.
      if (existing.any((row) => row.id == id)) continue;
      final step = entry.$2;
      await _syncService.upsertEntity(
        AgentDomainEntity.projectRecommendation(
          id: id,
          agentId: agentId,
          projectId: projectId,
          title: step.title,
          rationale: step.rationale,
          priority: step.priority,
          position: entry.$1,
          status: ProjectRecommendationStatus.active,
          createdAt: now,
          updatedAt: now,
          vectorClock: const VectorClock({}),
        ),
      );
    }
    for (final row in existing.whereType<ProjectRecommendationEntity>()) {
      if (row.projectId == projectId &&
          row.status == ProjectRecommendationStatus.active &&
          !ids.contains(row.id)) {
        await _syncService.upsertEntity(
          row.copyWith(
            status: ProjectRecommendationStatus.superseded,
            supersededAt: now,
            updatedAt: now,
          ),
        );
      }
    }
  }

  Future<void> _retractPendingBatches(String agentId, String projectId) async {
    final sets = await _syncService.repository.getPendingChangeSets(
      agentId,
      taskId: projectId,
    );
    for (final set in sets.whereType<ChangeSetEntity>()) {
      var changed = false;
      final items = set.items.map((item) {
        if (item.toolName != ProjectAgentToolNames.recommendNextSteps ||
            item.status != ChangeItemStatus.pending) {
          return item;
        }
        changed = true;
        return item.copyWith(status: ChangeItemStatus.retracted);
      }).toList();
      if (!changed) continue;
      await _syncService.upsertEntity(
        set.copyWith(
          items: items,
          status: items.any((item) => item.status == ChangeItemStatus.pending)
              ? ChangeSetStatus.partiallyResolved
              : ChangeSetStatus.resolved,
        ),
      );
    }
  }

  /// Claims the suggestion before creating its project-linked task. A known
  /// failure restores it for retry; successful creation consumes it even when
  /// optional agent assignment reports a warning.
  Future<ToolExecutionResult> createTask(String recommendationId) async {
    final dispatch = taskDispatcher;
    if (dispatch == null) throw StateError('No project task dispatcher');
    ProjectRecommendationEntity? claimed;
    await _syncService.runInTransaction(() async {
      final row = await _syncService.repository.getEntity(recommendationId);
      if (row is! ProjectRecommendationEntity ||
          row.deletedAt != null ||
          row.status != ProjectRecommendationStatus.active) {
        return;
      }
      claimed = row;
      await _syncService.upsertEntity(
        row.copyWith(
          status: ProjectRecommendationStatus.resolved,
          resolvedAt: clock.now(),
          updatedAt: clock.now(),
        ),
      );
    });
    final row = claimed;
    if (row == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Recommendation is no longer active',
      );
    }
    try {
      final result = await dispatch(ProjectAgentToolNames.createTask, {
        'title': row.title,
        if (row.rationale != null) 'description': row.rationale,
        if (row.priority != null) 'priority': row.priority,
      }, row.projectId);
      if (!result.success && !result.nonRetryable) {
        await _restoreAfterFailedCreation(row);
      }
      return result;
    } catch (_) {
      // An unexpected exception may follow a committed task write. Keep the
      // claim consumed to avoid creating a duplicate on an uncertain retry.
      rethrow;
    } finally {
      _notifyRecommendationUpdate(row.agentId, row.projectId);
    }
  }

  Future<void> _restoreAfterFailedCreation(
    ProjectRecommendationEntity row,
  ) async {
    await _syncService.runInTransaction(() async {
      final current = await _syncService.repository.getEntity(row.id);
      if (current is ProjectRecommendationEntity &&
          current.status == ProjectRecommendationStatus.resolved) {
        final report = await _syncService.repository.getLatestReport(
          row.agentId,
          AgentReportScopes.current,
        );
        final superseded =
            report != null && report.createdAt.isAfter(row.createdAt);
        await _syncService.upsertEntity(
          current.copyWith(
            status: superseded
                ? ProjectRecommendationStatus.superseded
                : ProjectRecommendationStatus.active,
            supersededAt: superseded ? clock.now() : null,
            resolvedAt: null,
            updatedAt: clock.now(),
          ),
        );
      }
    });
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
  ) => _syncService.runInTransaction(() async {
    final entity = await _syncService.repository.getEntity(recommendationId);
    final recommendation = entity?.mapOrNull(projectRecommendation: (e) => e);
    if (recommendation == null ||
        recommendation.deletedAt != null ||
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
  });

  void _notifyRecommendationUpdate(String agentId, String projectId) {
    _notifications?.notifyUiOnly({agentId, projectId, agentNotification});
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
