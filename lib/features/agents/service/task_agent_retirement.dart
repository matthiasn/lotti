import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

/// Keeps a task at one live task agent across devices (ADR 0104).
///
/// `TaskAgentService.createTaskAgent` refuses a task that already has an
/// agent, but only against what this device holds: two devices that assign
/// the same task before either has the other's agent both create one — the
/// follow-up tool's auto-assignment on each device that confirms it, or two
/// manual assignments. Each agent then wakes and writes reports and
/// proposals.
///
/// Every device resolves the task's agent the same way: the first of the
/// task's `agent_task` links by [AgentLinkSelection.orderedPrimaryFirst]
/// (`createdAt`, then id, newest first) among the links whose agent identity
/// this device holds, live or destroyed — the agent the task's card shows.
/// Every other live agent of the task is retired: destroyed, which syncs.
/// The rank reads only replicated data, so devices that hold the same links
/// and identities retire the same agents, and a retirement reaches every
/// device as an ordinary lifecycle write. A link whose identity has not
/// arrived yet does not rank; the pass that its identity's arrival triggers
/// ranks it.
///
/// The pass runs where the duplicate can first be seen or would first act:
/// after sync applies an `agent_task` link or a task agent's identity, at
/// startup over every task holding more than one link (which also clears
/// what older builds left behind), and before a task agent's wake.
/// `specs/tla/TaskAgentAssignment.tla` model-checks the rule.
class TaskAgentRetirement {
  TaskAgentRetirement({
    required this.repository,
    required this.syncService,
    required this.orchestrator,
    this.updateNotifications,
    this.domainLogger,
  });

  final AgentRepository repository;
  final AgentSyncService syncService;
  final WakeOrchestrator orchestrator;
  final UpdateNotifications? updateNotifications;
  final DomainLogger? domainLogger;

  /// Retires every live agent of [taskId] other than the task's agent.
  ///
  /// The ranking read and the lifecycle writes share one transaction, so a
  /// local write between them cannot make the pass retire against a view it
  /// no longer holds. Returns the ids of the agents it retired.
  Future<Set<String>> retireSuperseded(String taskId) async {
    // Almost every task has one agent, and the sync receive runs this for
    // every task link and task agent it applies: settle that case with one
    // read, without taking the writer's transaction.
    final candidates = await repository.getLinksTo(
      taskId,
      type: AgentLinkTypes.agentTask,
    );
    if (candidates.length < 2) return const <String>{};

    final retired = await syncService.runInTransaction(() async {
      final links = await repository.getLinksTo(
        taskId,
        type: AgentLinkTypes.agentTask,
      );
      if (links.length < 2) return const <String>{};

      final identities = <String, AgentIdentityEntity>{};
      for (final link in links) {
        final entity = await repository.getEntity(link.fromId);
        if (entity is AgentIdentityEntity &&
            entity.kind == AgentKinds.taskAgent) {
          identities[entity.agentId] = entity;
        }
      }
      final ranked = links
          .where((link) => identities.containsKey(link.fromId))
          .toList()
          .orderedPrimaryFirst();
      if (ranked.isEmpty) return const <String>{};

      final taskAgentId = ranked.first.fromId;
      final now = clock.now();
      final retired = <String>{};
      for (final identity in identities.values) {
        if (identity.agentId == taskAgentId ||
            identity.lifecycle == AgentLifecycle.destroyed) {
          continue;
        }
        await syncService.upsertEntity(
          identity.copyWith(
            lifecycle: AgentLifecycle.destroyed,
            destroyedAt: now,
            updatedAt: now,
            lifecycleUpdatedAt: now,
          ),
        );
        retired.add(identity.agentId);
      }
      return retired;
    });
    if (retired.isEmpty) return retired;

    // After the commit, as `AgentService.destroyAgent` does: a retired agent
    // stops observing the task, and the drain engine skips its queued jobs
    // because it is destroyed.
    retired.forEach(orchestrator.removeSubscriptions);
    updateNotifications?.notifyUiOnly({
      ...retired,
      taskId,
      agentNotification,
    });
    domainLogger?.log(
      LogDomain.agentRuntime,
      'retired ${retired.length} superseded task agent(s) '
      '(${retired.map(DomainLogger.sanitizeId).join(', ')}) '
      'of task ${DomainLogger.sanitizeId(taskId)}',
      subDomain: 'lifecycle',
    );
    return retired;
  }

  /// The wake gate: runs the pass for every task [agentId] is linked to and
  /// returns whether [agentId] must not run — it is destroyed once the pass
  /// is done. That covers a loser this pass retired and one a pass before it
  /// retired after the drain engine last read the agent's policy.
  Future<bool> retireIfSuperseded(String agentId) async {
    final links = await repository.getLinksFrom(
      agentId,
      type: AgentLinkTypes.agentTask,
    );
    for (final taskId in {for (final link in links) link.toId}) {
      await retireSuperseded(taskId);
    }
    final identity = await repository.getEntity(agentId);
    return identity is! AgentIdentityEntity ||
        identity.lifecycle == AgentLifecycle.destroyed;
  }

  /// The startup pass: every task holding links from more than one agent.
  ///
  /// Covers what a receive's pass did not get to — the process died between
  /// the receive and its pass — and the duplicates older builds left. A task
  /// whose pass throws is logged and skipped, so one bad row does not stop
  /// the others or the startup restoration after it.
  Future<void> retireSupersededEverywhere() async {
    final taskIds = await repository.getTaskIdsWithSeveralAgentLinks();
    for (final taskId in taskIds) {
      try {
        await retireSuperseded(taskId);
      } catch (error, stackTrace) {
        domainLogger?.error(
          LogDomain.agentRuntime,
          error,
          message:
              'failed to retire superseded task agents of task '
              '${DomainLogger.sanitizeId(taskId)}',
          stackTrace: stackTrace,
          subDomain: 'lifecycle',
        );
      }
    }
  }
}
