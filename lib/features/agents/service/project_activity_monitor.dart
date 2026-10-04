import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/logic/repositories/project_agent_mutation_coordinator.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

/// Tracks local project-linked activity and marks project reports stale.
///
/// Project activity never wakes a project agent. This monitor listens to the
/// local update stream — direct project edits, task links, and edits to linked
/// tasks and their entries — resolves whether an affected project has a
/// provisioned agent, and marks its report stale: the pending activity marker
/// and the synced, max-joined `reportStaleAt` watermark. Then it asks
/// [armProjectUpdate] to arm the next update slot, which fires on one device at
/// the slot's start (`ProjectUpdateCadence`, `ProjectWakeGovernor.tla`).
class ProjectActivityMonitor with AgentErrorLogging {
  ProjectActivityMonitor({
    required this._notifications,
    required this._agentRepository,
    required this._projectRepository,
    required this._syncService,
    this.domainLogger,
    this._clock = const Clock(),
    this.retireProjectAgent,
    this.updateProjectAgentScopes,
    this.armProjectUpdate,
    ProjectAgentMutationCoordinator? mutationCoordinator,
  }) : _mutationCoordinator =
           mutationCoordinator ?? ProjectAgentMutationCoordinator();

  final UpdateNotifications _notifications;
  final AgentRepository _agentRepository;
  final ProjectRepository _projectRepository;
  final AgentSyncService _syncService;
  final ProjectAgentMutationCoordinator _mutationCoordinator;
  final Future<void> Function(String agentId)? retireProjectAgent;
  final Future<void> Function(
    String projectId,
    Set<String> allowedCategoryIds,
  )?
  updateProjectAgentScopes;

  /// Arms the agent's next update slot once its report is marked stale. Inert
  /// and idempotent: it schedules at most one slot, and starts no work.
  final Future<void> Function(String agentId)? armProjectUpdate;
  @override
  final DomainLogger? domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentRuntime;
  final Clock _clock;

  StreamSubscription<Set<String>>? _subscription;
  StreamSubscription<Set<String>>? _syncSubscription;

  void _log(String message, {String? subDomain}) {
    domainLogger?.log(
      LogDomain.agentRuntime,
      message,
      subDomain: subDomain,
    );
  }

  /// Start tracking local project activity.
  void start() {
    _subscription?.cancel();
    _syncSubscription?.cancel();
    _subscription = _notifications.localUpdateStream.listen((affectedIds) {
      unawaited(_handleBatch(affectedIds, _clock.now()));
    });
    if (retireProjectAgent != null || updateProjectAgentScopes != null) {
      _syncSubscription = _notifications.syncUpdateStream.listen((affectedIds) {
        unawaited(_reconcileSyncedProjects(affectedIds));
      });
    }
  }

  /// Stop tracking project activity.
  Future<void> stop() async {
    await Future.wait([
      if (_subscription != null) _subscription!.cancel(),
      if (_syncSubscription != null) _syncSubscription!.cancel(),
    ]);
    _subscription = null;
    _syncSubscription = null;
  }

  /// Reconciles project-agent lifecycle and scope after project sync updates.
  ///
  /// Provisioning necessarily spans the journal and agent databases. Even
  /// after its final existence check, a peer can commit a project tombstone
  /// before the new identity is announced and woken. The sync notification is
  /// the durable reconciliation point for that last race: a missing project
  /// must not retain active agents or queued work, while a surviving project
  /// must keep every linked agent scoped to its current category.
  Future<void> _reconcileSyncedProjects(
    Set<String> affectedIds,
  ) async {
    final retireAgent = retireProjectAgent;
    final updateScopes = updateProjectAgentScopes;
    if ((retireAgent == null && updateScopes == null) ||
        !affectedIds.contains(projectNotification)) {
      return;
    }

    final candidateProjectIds = affectedIds.difference({
      projectNotification,
      labelUsageNotification,
    });
    for (final projectId in candidateProjectIds) {
      try {
        await _mutationCoordinator.run(projectId, () async {
          final project = await _projectRepository.getProjectById(projectId);
          if (project != null) {
            await updateScopes?.call(projectId, {
              if (project.meta.categoryId case final String categoryId)
                categoryId,
            });
            return;
          }
          if (retireAgent == null) return;
          final links = await _agentRepository.getLinksTo(
            projectId,
            type: AgentLinkTypes.agentProject,
          );
          final retiredAgentIds = <String>{};
          for (final link in links) {
            if (retiredAgentIds.add(link.fromId)) {
              try {
                final currentProject = await _projectRepository.getProjectById(
                  projectId,
                );
                if (currentProject != null) {
                  await updateScopes?.call(projectId, {
                    if (currentProject.meta.categoryId
                        case final String categoryId)
                      categoryId,
                  });
                  return;
                }
                await retireAgent(link.fromId);
              } catch (error, stackTrace) {
                logError(
                  'failed to retire project agent '
                  '${DomainLogger.sanitizeId(link.fromId)} for project '
                  '${DomainLogger.sanitizeId(projectId)}',
                  error: error,
                  stackTrace: stackTrace,
                );
              }
            }
          }
        });
      } catch (error, stackTrace) {
        logError(
          'failed to reconcile synced project '
          '${DomainLogger.sanitizeId(projectId)}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _handleBatch(
    Set<String> affectedIds,
    DateTime observedAt,
  ) async {
    if (affectedIds.isEmpty) return;

    final projectIds = await _projectRepository.resolveAffectedProjectIds(
      affectedIds,
    );
    if (projectIds.isEmpty) return;

    // Only project IDs with an `agent_project` link matter here. Generic
    // notification tokens are filtered out by the project repository.
    await Future.wait(
      projectIds.map(
        (projectId) => _markProjectActivityIfNeeded(projectId, observedAt),
      ),
    );
  }

  Future<void> _markProjectActivityIfNeeded(
    String projectId,
    DateTime observedAt,
  ) async {
    try {
      final links = await _agentRepository.getLinksTo(
        projectId,
        type: AgentLinkTypes.agentProject,
      );
      if (links.isEmpty) return;

      final agentId = links.selectPrimary().fromId;
      final snapshot = await _agentRepository.getAgentState(agentId);
      if (snapshot == null || snapshot.deletedAt != null) return;
      final now = observedAt;
      final pendingActivityAt = snapshot.slots.pendingProjectActivityAt;
      if (pendingActivityAt != null && !pendingActivityAt.isBefore(now)) {
        return;
      }

      var activityPersisted = false;
      await _syncService.runInTransaction(() async {
        // Re-read inside the same transaction as the write. The wake router
        // may have persisted `reportStaleAt` after the snapshot above; using
        // that current row keeps the independent freshness and activity
        // mutations from erasing one another.
        final current = await _agentRepository.getAgentState(agentId);
        if (current == null || current.deletedAt != null) return;
        final lastWakeAt = current.lastWakeAt;
        if (lastWakeAt != null && !now.isAfter(lastWakeAt)) return;
        final currentPendingActivityAt = current.slots.pendingProjectActivityAt;
        if (currentPendingActivityAt != null &&
            !currentPendingActivityAt.isBefore(now)) {
          return;
        }

        final staleAt = current.reportStaleAt;
        await _syncService.upsertEntity(
          current.copyWith(
            slots: current.slots.copyWith(
              pendingProjectActivityAt: now,
            ),
            // The synced staleness the cadence and the report card read.
            // Joined by maximum, so a peer's concurrent write cannot erase
            // this change.
            reportStaleAt: staleAt == null || staleAt.isBefore(now)
                ? now
                : staleAt,
            updatedAt: now,
          ),
        );
        activityPersisted = true;
      });
      if (!activityPersisted) return;

      _notifications.notifyUiOnly({agentId, agentNotification});
      await armProjectUpdate?.call(agentId);

      _log(
        'marked pending project activity for '
        '${DomainLogger.sanitizeId(agentId)}',
        subDomain: 'activity',
      );
    } catch (error, stackTrace) {
      logError(
        'failed to mark project activity for '
        '${DomainLogger.sanitizeId(projectId)}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
