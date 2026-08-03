import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/improver_slot_keys.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// Improver-agent-specific lifecycle management.
///
/// Manages improver agents that monitor a target template's performance and
/// propose improvements through periodic one-on-one rituals.
class ImproverAgentService {
  ImproverAgentService({
    required this.agentService,
    required this.repository,
    required this.syncService,
    this.onPersistedStateChanged,
  });

  final AgentService agentService;
  final AgentRepository repository;
  final AgentSyncService syncService;
  final void Function(String agentId)? onPersistedStateChanged;

  /// Get the improver agent for a template (if one exists).
  ///
  /// Looks up `improverTarget` links pointing to [templateId] and resolves
  /// the agent identity from the link's `fromId`.
  Future<AgentIdentityEntity?> getImproverForTemplate(String templateId) async {
    final links = await repository.getLinksTo(
      templateId,
      type: AgentLinkTypes.improverTarget,
    );
    if (links.isEmpty) return null;

    // Iterate defensively — stale links may point to missing agents.
    for (final link in links) {
      final agent = await agentService.getAgent(link.fromId);
      if (agent != null) return agent;
    }
    return null;
  }

  /// Schedule the next one-on-one wake for an improver agent.
  ///
  /// Reads `feedbackWindowDays` from the agent's [AgentConfig] (PR 4 B4),
  /// falling back to the legacy `AgentSlots.feedbackWindowDays` for agents
  /// created before the re-home, and sets `scheduledWakeAt` accordingly.
  Future<void> scheduleNextRitual(String agentId) async {
    final state = await repository.getAgentState(agentId);
    if (state == null) {
      throw StateError('Agent state not found for $agentId');
    }

    final identity = await agentService.getAgent(agentId);
    final configuredWindowDays =
        identity?.config.feedbackWindowDays ?? state.slots.feedbackWindowDays;
    final feedbackWindowDays =
        configuredWindowDays != null && configuredWindowDays > 0
        ? configuredWindowDays
        : ImproverSlotDefaults.defaultFeedbackWindowDays;
    final now = clock.now();
    final nextWake = now.add(Duration(days: feedbackWindowDays));

    final hostId = await syncService.localHost();
    final updatedState = state.copyWith(
      scheduledWakeAt: nextWake,
      slots: state.slots.copyWith(
        lastOneOnOneAt: now,
        totalSessionsCompleted: state.slots.totalSessionsCompleted.increment(
          hostId,
        ),
      ),
      updatedAt: now,
    );

    // The cached watermark and its event-sourced marker (PR 4, B2) must share
    // one durability boundary: if only the cache row committed, a later
    // reconciled read could regress `lastOneOnOneAt` or re-run the ritual on
    // another device. The marker's createdAt is what the projection folds; the
    // cached row stays the read source until the cutover (B6). No wake thread
    // here — the marker gets its own.
    await syncService.runInTransaction(() async {
      await syncService.upsertEntity(updatedState);
      await syncService.appendMilestone(
        agentId: agentId,
        milestone: AgentMilestone.oneOnOneCompleted,
        createdAt: now,
      );
    });
    onPersistedStateChanged?.call(agentId);

    developer.log(
      'Scheduled next ritual for ${DomainLogger.sanitizeId(agentId)} '
      'at $nextWake',
      name: 'ImproverAgentService',
    );
  }
}
