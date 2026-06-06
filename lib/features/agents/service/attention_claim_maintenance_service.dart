import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:uuid/uuid.dart';

/// Producer-side maintenance for task attention claims.
///
/// This runs inside a task-agent wake and resolves obvious terminal states
/// without waking agents from the day-planning critical path.
class AttentionClaimMaintenanceService {
  AttentionClaimMaintenanceService({
    required this.agentRepository,
    required this.syncService,
  });

  final AgentRepository agentRepository;
  final AgentSyncService syncService;

  static const _uuid = Uuid();
  static const _taskTargetKind = 'task';

  Future<AttentionClaimMaintenanceResult> settleTerminalTaskClaims({
    required String agentId,
    required Task task,
  }) async {
    final projectedStatus = _terminalDispositionStatus(task.data.status);
    if (projectedStatus == null) {
      return const AttentionClaimMaintenanceResult();
    }

    final activeClaims = await agentRepository.getAttentionClaimsForTarget(
      targetKind: _taskTargetKind,
      targetId: task.id,
    );
    final ownClaims = activeClaims
        .where((claim) => claim.agentId == agentId)
        .toList(growable: false);
    if (ownClaims.isEmpty) {
      return AttentionClaimMaintenanceResult(
        inspectedClaims: activeClaims.length,
      );
    }

    final now = clock.now();
    await syncService.runInTransaction(() async {
      for (final claim in ownClaims) {
        await syncService.upsertEntity(
          AgentDomainEntity.attentionClaimDisposition(
            id: _uuid.v4(),
            agentId: agentId,
            requestId: claim.id,
            status: projectedStatus,
            reason: _terminalDispositionReason(task.data.status),
            createdAt: now,
            vectorClock: null,
          ),
        );
      }
    });

    return AttentionClaimMaintenanceResult(
      inspectedClaims: activeClaims.length,
      settledClaims: ownClaims.length,
      status: projectedStatus,
    );
  }

  static AttentionClaimStatus? _terminalDispositionStatus(TaskStatus status) {
    return switch (status) {
      TaskDone() => AttentionClaimStatus.satisfied,
      TaskRejected() => AttentionClaimStatus.withdrawn,
      _ => null,
    };
  }

  static String _terminalDispositionReason(TaskStatus status) {
    return switch (status) {
      TaskDone() => 'Task is done; the attention request is no longer open.',
      TaskRejected() =>
        'Task was rejected; the attention request is no longer relevant.',
      _ => 'Task state no longer needs this attention request.',
    };
  }
}

class AttentionClaimMaintenanceResult {
  const AttentionClaimMaintenanceResult({
    this.inspectedClaims = 0,
    this.settledClaims = 0,
    this.status,
  });

  final int inspectedClaims;
  final int settledClaims;
  final AttentionClaimStatus? status;
}
