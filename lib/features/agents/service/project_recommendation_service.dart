import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
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
    this.taskRemover,
    this._domainLogger,
  });

  final AgentSyncService _syncService;
  final UpdateNotifications? _notifications;
  final AgentToolDispatch? taskDispatcher;

  /// Soft-deletes the task a step created, so "Add task" can be undone.
  /// Returns whether the task is gone; `false` keeps the step resolved.
  final Future<bool> Function(String taskId)? taskRemover;
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
  /// an empty result. The final tool payload wins within a run. Start ordering
  /// rejects late older completions; other tools and decided rows are retained.
  Future<void> replaceForRun({
    required String agentId,
    required String projectId,
    required String runKey,
    required DateTime runStartedAt,
    required List<Map<String, dynamic>> deferredItems,
  }) async {
    await _syncService.runInTransaction(() async {
      final accepted = await _replace(
        agentId: agentId,
        projectId: projectId,
        sourceId: runKey,
        createdAt: runStartedAt,
        rawSteps: _latestSteps(deferredItems),
      );
      if (!accepted) return;
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
          createdAt: latest.createdAt,
          rawSteps: batchIsStale
              ? []
              : _latestSteps([
                  for (final item in latest.items)
                    if (item.status == ChangeItemStatus.pending)
                      {'toolName': item.toolName, 'args': item.args},
                ]),
        );
      }
      await _retractPendingBatches(agentId, projectId);
      changed = true;
    });
    if (changed) _notifyRecommendationUpdate(agentId, projectId);
  }

  Future<bool> _replace({
    required String agentId,
    required String projectId,
    required String sourceId,
    required List<dynamic> rawSteps,
    required DateTime createdAt,
  }) async {
    final runs = await _runs(agentId, projectId);
    final runId = _uuid.v5(
      Namespace.url.value,
      '$agentId/$projectId/$sourceId',
    );
    // Completion time cannot let a timed-out executor replace a newer wake.
    // Equal start times use the same stable ordering as synced snapshots.
    if (runs.any((run) => run.id == runId)) return false;
    if (runs.isNotEmpty) {
      final latest = runs.first;
      final order = createdAt.compareTo(latest.createdAt);
      if (order < 0 || (order == 0 && runId.compareTo(latest.id) < 0)) {
        return false;
      }
    }
    final now = createdAt;
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
          sourceRunId: runId,
          status: ProjectRecommendationStatus.active,
          createdAt: now,
          updatedAt: now,
          vectorClock: const VectorClock({}),
        ),
      );
    }
    await _syncService.upsertEntity(
      AgentDomainEntity.projectRecommendationRun(
        id: runId,
        agentId: agentId,
        projectId: projectId,
        recommendationIds: ids.toList(),
        createdAt: now,
        vectorClock: const VectorClock({}),
      ),
    );
    await currentRecommendations(agentId, projectId);
    return true;
  }

  List<dynamic> _latestSteps(List<Map<String, dynamic>> items) {
    final args = items
        .where(
          (item) =>
              item['toolName'] == ProjectAgentToolNames.recommendNextSteps,
        )
        .lastOrNull?['args'];
    final steps = args is Map ? args['steps'] : null;
    return steps is List ? steps : const [];
  }

  Future<List<ProjectRecommendationRunEntity>> _runs(
    String agentId,
    String projectId,
  ) async {
    final entities = await _syncService.repository.getEntitiesByAgentId(
      agentId,
      type: AgentEntityTypes.projectRecommendationRun,
    );
    return entities
        .whereType<ProjectRecommendationRunEntity>()
        .where((run) => run.projectId == projectId && run.deletedAt == null)
        .toList()
      ..sort((a, b) {
        final order = b.createdAt.compareTo(a.createdAt);
        return order == 0 ? b.id.compareTo(a.id) : order;
      });
  }

  /// The still-open steps of the newest run: [currentRunSnapshot] without the
  /// decided rows.
  Future<List<ProjectRecommendationEntity>> currentRecommendations(
    String agentId,
    String projectId,
  ) async => (await currentRunSnapshot(agentId, projectId)).pending.toList();

  /// Selects one immutable run after sync, including an empty winning run, and
  /// returns every step of it the detail surface shows — open, added, done or
  /// dismissed — in the agent's order. Unknown run rows stay hidden until
  /// their snapshot arrives: retracting them early could destroy the eventual
  /// winner when sync delivers rows first. Open rows of a known losing run are
  /// superseded here; decided rows keep their history untouched.
  Future<ProjectNextStepsSnapshot> currentRunSnapshot(
    String agentId,
    String projectId,
  ) => _syncService.runInTransaction(() async {
    final runs = await _runs(agentId, projectId);
    final entities = await _syncService.repository.getEntitiesByAgentId(
      agentId,
      type: AgentEntityTypes.projectRecommendation,
    );
    final rows = entities.whereType<ProjectRecommendationEntity>().where(
      (row) =>
          row.projectId == projectId &&
          row.deletedAt == null &&
          row.status != ProjectRecommendationStatus.superseded,
    );
    if (runs.isEmpty) {
      return ProjectNextStepsSnapshot(
        steps: rows.where((row) => row.sourceRunId == null).toList()
          ..sort(_byPosition),
        runCreatedAt: null,
      );
    }
    final winner = runs.first;
    final knownRuns = runs.map((run) => run.id).toSet();
    final current = <ProjectRecommendationEntity>[];
    for (final row in rows) {
      if (winner.recommendationIds.contains(row.id)) {
        current.add(row);
      } else if (row.status == ProjectRecommendationStatus.active &&
          (row.sourceRunId == null || knownRuns.contains(row.sourceRunId))) {
        await _syncService.upsertEntity(
          row.copyWith(
            status: ProjectRecommendationStatus.superseded,
            supersededAt: clock.now(),
            updatedAt: clock.now(),
          ),
        );
      }
    }
    return ProjectNextStepsSnapshot(
      steps: current..sort(_byPosition),
      runCreatedAt: winner.createdAt,
    );
  });

  static int _byPosition(
    ProjectRecommendationEntity a,
    ProjectRecommendationEntity b,
  ) {
    final order = a.position.compareTo(b.position);
    if (order != 0) return order;
    final created = a.createdAt.compareTo(b.createdAt);
    return created != 0 ? created : a.id.compareTo(b.id);
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
      final status = ChangeItem.deriveSetStatus(items);
      await _syncService.upsertEntity(
        set.copyWith(
          items: items,
          status: status,
          resolvedAt: ChangeItem.deriveResolvedAt(
            newStatus: status,
            existingResolvedAt: set.resolvedAt,
            now: clock.now(),
          ),
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
          row.status != ProjectRecommendationStatus.active ||
          !await _isCurrent(row)) {
        return;
      }
      claimed = row.copyWith(
        status: ProjectRecommendationStatus.resolved,
        resolvedAt: clock.now(),
        updatedAt: clock.now(),
      );
      await _syncService.upsertEntity(claimed!);
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
      if (result.success) {
        await _syncService.runInTransaction(() async {
          if (result.mutatedEntityId case final taskId?) {
            await _syncService.upsertEntity(
              row.copyWith(createdTaskId: taskId, updatedAt: clock.now()),
            );
          }
          await _recordDecision(row, ChangeDecisionVerdict.confirmed);
        });
      }
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
            !await _isCurrent(row) ||
            (report != null && report.createdAt.isAfter(row.createdAt));
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

  /// Reverts a dismissal or a task creation while the step still belongs to
  /// the newest run. A created task is removed first: if that fails the step
  /// stays resolved, so a retry cannot leave the task orphaned. The decision
  /// recorded for the agent's feedback history is withdrawn with the step.
  Future<bool> restoreRecommendation(String recommendationId) async {
    final entity = await _syncService.repository.getEntity(recommendationId);
    final row = entity?.mapOrNull(projectRecommendation: (e) => e);
    if (row == null ||
        row.deletedAt != null ||
        (row.status != ProjectRecommendationStatus.resolved &&
            row.status != ProjectRecommendationStatus.dismissed) ||
        !await _isCurrent(row)) {
      return false;
    }
    if (row.createdTaskId case final taskId?) {
      final remove = taskRemover;
      if (remove == null) throw StateError('No project task remover');
      if (!await remove(taskId)) return false;
    }
    final restored = await _syncService.runInTransaction(() async {
      final latest = await _syncService.repository.getEntity(row.id);
      final current = latest?.mapOrNull(projectRecommendation: (e) => e);
      if (current == null || current.status != row.status) return false;
      final now = clock.now();
      await _syncService.upsertEntity(
        current.copyWith(
          status: ProjectRecommendationStatus.active,
          resolvedAt: null,
          dismissedAt: null,
          createdTaskId: null,
          updatedAt: now,
        ),
      );
      await _withdrawDecision(current, now);
      return true;
    });
    if (restored) {
      _domainLogger?.log(
        LogDomain.agentWorkflow,
        'Restored project recommendation '
        '${DomainLogger.sanitizeId(row.id)} to active',
        subDomain: _sub,
      );
      _notifyRecommendationUpdate(row.agentId, row.projectId);
    }
    return restored;
  }

  /// Soft-deletes the single-item change set [_recordDecision] wrote, which
  /// is what the feedback-extraction path joins decisions against.
  Future<void> _withdrawDecision(
    ProjectRecommendationEntity row,
    DateTime now,
  ) async {
    final setId = _uuid.v5(Namespace.url.value, '${row.id}/decision-source');
    final set = await _syncService.repository.getEntity(setId);
    if (set case ChangeSetEntity(deletedAt: null)) {
      await _syncService.upsertEntity(set.copyWith(deletedAt: now));
    }
  }

  Future<bool> _transitionRecommendation(
    String recommendationId,
    ProjectRecommendationStatus status,
  ) => _syncService.runInTransaction(() async {
    final entity = await _syncService.repository.getEntity(recommendationId);
    final recommendation = entity?.mapOrNull(projectRecommendation: (e) => e);
    if (recommendation == null ||
        recommendation.deletedAt != null ||
        recommendation.status != ProjectRecommendationStatus.active ||
        !await _isCurrent(recommendation)) {
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

    await _recordDecision(
      recommendation,
      status == ProjectRecommendationStatus.resolved
          ? ChangeDecisionVerdict.confirmed
          : ChangeDecisionVerdict.rejected,
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

  Future<bool> _isCurrent(ProjectRecommendationEntity row) async {
    final runs = await _runs(row.agentId, row.projectId);
    return runs.isEmpty
        ? row.sourceRunId == null
        : runs.first.recommendationIds.contains(row.id);
  }

  Future<void> _recordDecision(
    ProjectRecommendationEntity row,
    ChangeDecisionVerdict verdict,
  ) async {
    final setId = _uuid.v5(Namespace.url.value, '${row.id}/decision-source');
    final decisionId = _uuid.v5(Namespace.url.value, '${row.id}/decision');
    final args = <String, dynamic>{
      'steps': [
        {
          'title': row.title,
          if (row.rationale != null) 'rationale': row.rationale,
          if (row.priority != null) 'priority': row.priority,
        },
      ],
    };
    final now = clock.now();
    await _syncService.upsertEntity(
      AgentDomainEntity.changeSet(
        id: setId,
        agentId: row.agentId,
        taskId: row.projectId,
        threadId: row.sourceRunId ?? row.id,
        runKey: row.sourceRunId ?? row.id,
        status: ChangeSetStatus.resolved,
        items: [
          ChangeItem(
            toolName: ProjectAgentToolNames.recommendNextSteps,
            args: args,
            humanSummary: row.title,
            status: verdict == ChangeDecisionVerdict.confirmed
                ? ChangeItemStatus.confirmed
                : ChangeItemStatus.rejected,
          ),
        ],
        createdAt: row.createdAt,
        resolvedAt: now,
        vectorClock: const VectorClock({}),
      ),
    );
    await _syncService.upsertEntity(
      AgentDomainEntity.changeDecision(
        id: decisionId,
        agentId: row.agentId,
        changeSetId: setId,
        itemIndex: 0,
        toolName: ProjectAgentToolNames.recommendNextSteps,
        verdict: verdict,
        taskId: row.projectId,
        humanSummary: row.title,
        args: args,
        createdAt: now,
        vectorClock: const VectorClock({}),
      ),
    );
  }

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

/// The newest run's steps as the project detail shows them, in the agent's
/// order, plus when that run was published so an empty or fully decided band
/// can say when the agent last looked.
class ProjectNextStepsSnapshot {
  const ProjectNextStepsSnapshot({
    required this.steps,
    required this.runCreatedAt,
  });

  const ProjectNextStepsSnapshot.empty()
    : steps = const [],
      runCreatedAt = null;

  /// Every open, added, done or dismissed step of the run, by position.
  final List<ProjectRecommendationEntity> steps;

  /// Start of the run the steps came from; `null` for legacy rows that
  /// predate run snapshots, or when the agent has never published one.
  final DateTime? runCreatedAt;

  Iterable<ProjectRecommendationEntity> get pending => steps.where(
    (step) => step.status == ProjectRecommendationStatus.active,
  );

  bool get hasPending => pending.isNotEmpty;

  bool get isEmpty => steps.isEmpty;
}
