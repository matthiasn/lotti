import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';

/// Shared plan-entity reads used by every day-plan collaborator.
///
/// Extracting these tiny lookups into one collaborator breaks the
/// planning/resolve cross-call cycle: both the editor and the writer
/// depend on [DayAgentPlanReads] instead of on each other.
class DayAgentPlanReads {
  /// Creates the shared reads collaborator.
  DayAgentPlanReads({required this.agentRepository});

  /// Agent entity/link repository.
  final AgentRepository agentRepository;

  /// Fetch the persisted plan for one day. Soft-deleted entities are
  /// hidden so callers that come in after `deletePlanForDay` (commit,
  /// uncommit, refine, the UI's `currentPlanForDate` projection) all
  /// see the same "no plan" state instead of operating on the deleted
  /// row.
  Future<DayPlanEntity?> draftPlanForDay({
    required String agentId,
    required String dayId,
  }) async {
    final entity = await agentRepository.getEntity(dayAgentPlanEntityId(dayId));
    if (entity is DayPlanEntity &&
        entity.agentId == agentId &&
        entity.deletedAt == null) {
      return entity;
    }
    return null;
  }

  /// Resolve the agent identity, throwing when it is missing/deleted.
  Future<AgentIdentityEntity> requireIdentity(String agentId) async {
    final entity = await agentRepository.getEntity(agentId);
    if (entity is AgentIdentityEntity && entity.deletedAt == null) {
      return entity;
    }
    throw DayAgentCaptureException('agent $agentId not found');
  }

  /// Resolve a capture by id, or `null` when it is not a capture entity.
  Future<CaptureEntity?> captureOrNull(String captureId) async {
    final entity = await agentRepository.getEntity(captureId);
    return entity is CaptureEntity ? entity : null;
  }
}
