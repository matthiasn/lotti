import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';

/// Coordinates reversible agent retirement with a project's soft deletion.
///
/// The operation outlives its initiating widget and serializes with project
/// agent provisioning. A failed journal write restores the exact lifecycles
/// captured before retirement, unless the project tombstone actually committed.
class ProjectLifecycleService {
  ProjectLifecycleService({
    required this.projectRepository,
    required this.projectAgentService,
    required this.agentService,
    required this.mutationCoordinator,
  });

  final ProjectRepository projectRepository;
  final ProjectAgentService projectAgentService;
  final AgentService agentService;
  final ProjectAgentMutationCoordinator mutationCoordinator;

  /// Retires all linked live agents and deletes the latest project snapshot.
  /// Returns false when deletion cannot be confirmed; compensation is then
  /// attempted independently for every agent retired by this operation.
  Future<bool> deleteProject(String projectId) =>
      mutationCoordinator.run(projectId, () async {
        late final List<AgentIdentityEntity> agents;
        try {
          agents = await projectAgentService.getProjectAgentsForProject(
            projectId,
          );
        } catch (error, stackTrace) {
          _log('Failed to resolve project agents', error, stackTrace);
          return false;
        }

        final retired = <String, AgentLifecycle>{};
        for (final agent in agents) {
          try {
            agentService.abortRunningWake(agent.agentId);
            if (await agentService.destroyAgent(agent.agentId)) {
              retired[agent.agentId] = agent.lifecycle;
            }
            // Retirement disables future execution and removes subscriptions.
            // Cancellation also catches jobs already owned by the drain.
            // An abort alone does not stop the underlying Dart future.
            agentService.cancelPendingWake(agent.agentId);
            await agentService.waitForAgentExecutors(agent.agentId);
          } catch (error, stackTrace) {
            _log('Failed to retire project agent', error, stackTrace);
            // A lifecycle write may commit before its outbox flush throws.
            try {
              final persisted = await agentService.getAgent(agent.agentId);
              if (persisted?.lifecycle == AgentLifecycle.destroyed) {
                retired[agent.agentId] = agent.lifecycle;
              }
            } catch (error, stackTrace) {
              _log('Failed to verify agent retirement', error, stackTrace);
            }
            await _restoreAgents(retired);
            return false;
          }
        }

        var deleted = false;
        try {
          final project = await projectRepository.getProjectById(projectId);
          deleted =
              project == null ||
              await projectRepository.deleteProject(
                project,
                deletedAt: clock.now(),
              );
        } catch (error, stackTrace) {
          _log('Failed to delete project', error, stackTrace);
        }
        if (!deleted) {
          try {
            deleted = await projectRepository.getProjectById(projectId) == null;
          } catch (error, stackTrace) {
            _log('Failed to verify project deletion', error, stackTrace);
          }
        }
        if (!deleted) await _restoreAgents(retired);
        return deleted;
      });

  Future<void> _restoreAgents(Map<String, AgentLifecycle> retired) async {
    var restoredActiveAgent = false;
    for (final MapEntry(key: agentId, value: lifecycle) in retired.entries) {
      try {
        var restored = false;
        try {
          restored = await agentService.restoreAgentLifecycle(
            agentId,
            lifecycle,
          );
        } catch (error, stackTrace) {
          // Subscription restoration must still follow a committed restore
          // whose post-commit sync flush failed.
          restored =
              (await agentService.getAgent(agentId))?.lifecycle == lifecycle;
          _log('Agent lifecycle restore reported a failure', error, stackTrace);
        }
        restoredActiveAgent |= restored && lifecycle == AgentLifecycle.active;
      } catch (error, stackTrace) {
        _log('Failed to restore project agent', error, stackTrace);
      }
    }
    if (restoredActiveAgent) {
      try {
        await projectAgentService.restoreSubscriptions();
      } catch (error, stackTrace) {
        _log('Failed to restore project subscriptions', error, stackTrace);
      }
    }
  }

  void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'ProjectLifecycleService',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

final projectLifecycleServiceProvider = Provider<ProjectLifecycleService>(
  (ref) => ProjectLifecycleService(
    projectRepository: ref.watch(projectRepositoryProvider),
    projectAgentService: ref.watch(projectAgentServiceProvider),
    agentService: ref.watch(agentServiceProvider),
    mutationCoordinator: ref.watch(projectAgentMutationCoordinatorProvider),
  ),
);
