import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/improver_slot_keys.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:uuid/uuid.dart';

/// Improver-agent-specific lifecycle management.
///
/// Creates and manages improver agents — agents that monitor a target
/// template's performance and propose improvements through periodic
/// one-on-one rituals.
class ImproverAgentService {
  ImproverAgentService({
    required this.agentService,
    required this.agentTemplateService,
    required this.repository,
    required this.syncService,
    required this.orchestrator,
  });

  final AgentService agentService;
  final AgentTemplateService agentTemplateService;
  final AgentRepository repository;
  final AgentSyncService syncService;
  final WakeOrchestrator orchestrator;

  static const _uuid = Uuid();

  /// Well-known improver template ID for the seeded default.
  static const improverTemplateId = 'template-improver-001';

  /// Create an improver agent for a target template.
  ///
  /// Steps:
  /// 1. Resolve the improver template (seed a default if needed).
  /// 2. Create the agent identity with kind `template_improver`.
  /// 3. Set up state slots with template ID, feedback window, recursion depth.
  /// 4. Create links: improverTarget (agent -> target template) and
  ///    templateAssignment (improver template -> agent).
  /// 5. Set `scheduledWakeAt` for the first ritual.
  ///
  /// Throws [StateError] if an improver already exists for [targetTemplateId].
  Future<AgentIdentityEntity> createImproverAgent({
    required String targetTemplateId,
    String? improverTemplateId,
    String? displayName,
    int recursionDepth = 0,
  }) async {
    final resolvedImproverTemplateId =
        improverTemplateId ?? ImproverAgentService.improverTemplateId;

    return syncService.runInTransaction(() async {
      // Validate target template exists.
      final targetTemplate =
          await agentTemplateService.getTemplate(targetTemplateId);
      if (targetTemplate == null) {
        throw StateError('Target template $targetTemplateId not found');
      }

      // Check no improver already exists for this template.
      final existing = await getImproverForTemplate(targetTemplateId);
      if (existing != null) {
        throw StateError(
          'An improver agent already exists for template '
          '$targetTemplateId (agent ${existing.agentId})',
        );
      }

      // Resolve the improver template.
      final improverTemplate =
          await agentTemplateService.getTemplate(resolvedImproverTemplateId);
      if (improverTemplate == null) {
        throw StateError(
          'Improver template $resolvedImproverTemplateId not found. '
          'Run seedDefaults() first.',
        );
      }

      // Create the agent identity.
      final identity = await agentService.createAgent(
        kind: AgentKinds.templateImprover,
        displayName: displayName ?? '${targetTemplate.displayName} Improver',
        config: AgentConfig(modelId: improverTemplate.modelId),
      );

      // Update state with improver-specific slots.
      final state = await repository.getAgentState(identity.agentId);
      if (state == null) {
        throw StateError(
          'Agent ${identity.agentId} was just created but has no state',
        );
      }

      final now = clock.now();
      const feedbackWindowDays = ImproverSlotDefaults.defaultFeedbackWindowDays;
      final scheduledWakeAt = now.add(const Duration(days: feedbackWindowDays));

      final updatedState = state.copyWith(
        slots: state.slots.copyWith(
          activeTemplateId: targetTemplateId,
          feedbackWindowDays: feedbackWindowDays,
          recursionDepth: recursionDepth,
          totalSessionsCompleted: 0,
        ),
        scheduledWakeAt: scheduledWakeAt,
        updatedAt: now,
      );
      await syncService.upsertEntity(updatedState);

      // Create improverTarget link: agent -> target template.
      await syncService.upsertLink(
        AgentLink.improverTarget(
          id: _uuid.v4(),
          fromId: identity.agentId,
          toId: targetTemplateId,
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );

      // Create templateAssignment link: improver template -> agent.
      await syncService.upsertLink(
        AgentLink.templateAssignment(
          id: _uuid.v4(),
          fromId: resolvedImproverTemplateId,
          toId: identity.agentId,
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );

      developer.log(
        'Created improver agent ${identity.agentId} '
        'for template $targetTemplateId',
        name: 'ImproverAgentService',
      );

      return identity;
    });
  }

  /// Get the improver agent for a template (if one exists).
  ///
  /// Looks up `improverTarget` links pointing to [templateId] and resolves
  /// the agent identity from the link's `fromId`.
  Future<AgentIdentityEntity?> getImproverForTemplate(
    String templateId,
  ) async {
    final links = await repository.getLinksTo(
      templateId,
      type: AgentLinkTypes.improverTarget,
    );
    if (links.isEmpty) return null;

    return agentService.getAgent(links.first.fromId);
  }

  /// Schedule the next one-on-one wake for an improver agent.
  ///
  /// Reads the `feedbackWindowDays` from the agent's slots and sets
  /// `scheduledWakeAt` accordingly.
  Future<void> scheduleNextRitual(String agentId) async {
    final state = await repository.getAgentState(agentId);
    if (state == null) {
      throw StateError('Agent state not found for $agentId');
    }

    final feedbackWindowDays = state.slots.feedbackWindowDays ??
        ImproverSlotDefaults.defaultFeedbackWindowDays;
    final now = clock.now();
    final nextWake = now.add(Duration(days: feedbackWindowDays));

    final updatedState = state.copyWith(
      scheduledWakeAt: nextWake,
      slots: state.slots.copyWith(
        lastOneOnOneAt: now,
        totalSessionsCompleted: (state.slots.totalSessionsCompleted ?? 0) + 1,
      ),
      updatedAt: now,
    );

    await syncService.upsertEntity(updatedState);

    developer.log(
      'Scheduled next ritual for $agentId at $nextWake',
      name: 'ImproverAgentService',
    );
  }
}
