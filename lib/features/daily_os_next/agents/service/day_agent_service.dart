import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart'
    show AgentLifecycle, AgentTemplateKind, WakeReason;
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Daily OS day-agent lifecycle management.
class DayAgentService {
  /// Creates a Daily OS day-agent service.
  DayAgentService({
    required this.agentService,
    required this.repository,
    required this.orchestrator,
    required this.syncService,
    required this.templateService,
    required this.domainLogger,
    this.onPersistedStateChanged,
  });

  /// Shared agent lifecycle service.
  final AgentService agentService;

  /// Agent repository for state/link lookups.
  final AgentRepository repository;

  /// Wake orchestrator for manual day-agent wakes.
  final WakeOrchestrator orchestrator;

  /// Sync-aware writer for agent entities and links.
  final AgentSyncService syncService;

  /// Template service used to resolve the shared Shepherd template.
  final AgentTemplateService templateService;

  /// Structured logger.
  final DomainLogger domainLogger;

  /// Callback fired when persisted state changes.
  final void Function(String agentId)? onPersistedStateChanged;

  static const _uuid = Uuid();
  static const String _agentKind = AgentKinds.dayAgent;

  /// Create a new day agent for [date].
  ///
  /// One active day-agent identity is allowed per local calendar day.
  Future<AgentIdentityEntity> createDayAgent({
    required DateTime date,
    Set<String> allowedCategoryIds = const {},
    String? templateId,
    String? profileId,
    String? displayName,
  }) async {
    final dayId = dayAgentIdForDate(date);
    final existing = await getDayAgentForDate(date);
    if (existing != null) {
      throw StateError(
        'A day agent already exists for $dayId '
        '(agent ${existing.agentId})',
      );
    }

    final resolvedTemplateId = templateId ?? dayAgentTemplateId;

    final identity = await syncService.runInTransaction(() async {
      final duplicate = await _findDayAgentForDayId(dayId);
      if (duplicate != null) {
        throw StateError(
          'A day agent already exists for $dayId '
          '(agent ${duplicate.agentId})',
        );
      }

      final templateEntity = await repository.getEntity(resolvedTemplateId);
      if (templateEntity is! AgentTemplateEntity ||
          templateEntity.deletedAt != null ||
          templateEntity.kind != AgentTemplateKind.dayAgent) {
        throw StateError(
          'Template $resolvedTemplateId is not an active day-agent template.',
        );
      }

      final identity = await agentService.createAgent(
        kind: _agentKind,
        displayName: displayName ?? _defaultDisplayName(dayId),
        config: AgentConfig(
          modelId: templateEntity.modelId,
          profileId: profileId ?? templateEntity.profileId,
        ),
        allowedCategoryIds: allowedCategoryIds,
      );

      final state = await repository.getAgentState(identity.agentId);
      if (state == null) {
        throw StateError(
          'Agent ${identity.agentId} was just created but has no state entity',
        );
      }

      final now = clock.now();
      await syncService.upsertEntity(
        state.copyWith(
          slots: state.slots.copyWith(activeDayId: dayId),
          updatedAt: now,
        ),
      );

      await syncService.upsertLink(
        AgentLink.templateAssignment(
          id: _uuid.v4(),
          fromId: resolvedTemplateId,
          toId: identity.agentId,
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );

      return identity;
    });

    onPersistedStateChanged
      ?..call(identity.agentId)
      ..call(dayId);
    orchestrator.enqueueManualWake(
      agentId: identity.agentId,
      reason: WakeReason.creation.name,
      triggerTokens: {dayId},
    );

    domainLogger.log(
      LogDomains.agentRuntime,
      'created day agent ${DomainLogger.sanitizeId(identity.agentId)} '
      'for ${DomainLogger.sanitizeId(dayId)}',
      subDomain: 'lifecycle',
    );

    return identity;
  }

  /// Find the active day agent for [date], if one exists.
  Future<AgentIdentityEntity?> getDayAgentForDate(DateTime date) {
    return _findDayAgentForDayId(dayAgentIdForDate(date));
  }

  /// Enqueue a drafting wake for the day agent that owns [dayDate].
  ///
  /// When [captureId] is provided, the source capture is included as a
  /// `capture_submitted:<captureId>` trigger token so the workflow loads its
  /// transcript and parsed items into the drafting prompt.
  ///
  /// Returns `false` when no active day agent exists for [dayDate]. Callers
  /// are expected to either call [createDayAgent] first or surface the
  /// missing-agent state in the UI.
  Future<bool> enqueueDraftingWake({
    required DateTime dayDate,
    String? captureId,
  }) async {
    final agent = await getDayAgentForDate(dayDate);
    if (agent == null) {
      domainLogger.log(
        LogDomains.agentRuntime,
        'no day agent for '
        '${DomainLogger.sanitizeId(dayAgentIdForDate(dayDate))}; '
        'drafting wake not enqueued',
        subDomain: 'drafting',
      );
      return false;
    }
    final dayId = dayAgentIdForDate(dayDate);
    final triggerTokens = <String>{
      dayAgentDraftingToken(dayId),
      if (captureId != null && captureId.trim().isNotEmpty)
        dayAgentCaptureSubmittedToken(captureId.trim()),
    };
    domainLogger.log(
      LogDomains.agentRuntime,
      'drafting wake enqueued for '
      '${DomainLogger.sanitizeId(agent.agentId)} / '
      '${DomainLogger.sanitizeId(dayId)}',
      subDomain: 'drafting',
    );
    orchestrator.enqueueManualWake(
      agentId: agent.agentId,
      reason: dayAgentDraftingReason,
      triggerTokens: triggerTokens,
    );
    return true;
  }

  /// Trigger a manual wake for [agentId].
  void triggerReanalysis(String agentId) {
    domainLogger.log(
      LogDomains.agentRuntime,
      'manual day-agent reanalysis triggered for '
      '${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'lifecycle',
    );
    orchestrator.enqueueManualWake(
      agentId: agentId,
      reason: WakeReason.reanalysis.name,
    );
  }

  /// Cancel a pending or scheduled wake for [agentId].
  void cancelScheduledWake(String agentId) {
    domainLogger.log(
      LogDomains.agentRuntime,
      'day-agent scheduled wake cancelled for '
      '${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'lifecycle',
    );
    agentService.cancelPendingWake(agentId);
  }

  /// Restore in-memory runtime state for active day agents at app startup.
  Future<void> restoreSubscriptions() async {
    domainLogger.log(
      LogDomains.agentRuntime,
      'restoring day-agent runtime state...',
      subDomain: 'restore',
    );

    final activeAgents = await agentService.listAgents(
      lifecycle: AgentLifecycle.active,
    );

    var count = 0;
    for (final agent in activeAgents) {
      if (agent.kind != _agentKind) continue;
      try {
        await _hydrateThrottleDeadline(agent.agentId);
        count++;
      } catch (e, s) {
        final msg =
            'failed to restore day-agent runtime state for '
            '${DomainLogger.sanitizeId(agent.agentId)}';
        domainLogger.error(
          LogDomains.agentRuntime,
          msg,
          error: e,
          stackTrace: s,
        );
      }
    }

    domainLogger.log(
      LogDomains.agentRuntime,
      'restored $count day agent(s)',
      subDomain: 'restore',
    );
  }

  Future<AgentIdentityEntity?> _findDayAgentForDayId(String dayId) async {
    return repository.getActiveAgentByKindAndActiveDayId(
      kind: _agentKind,
      activeDayId: dayId,
    );
  }

  Future<void> _hydrateThrottleDeadline(String agentId) async {
    final state = await repository.getAgentState(agentId);
    final deadline = state?.nextWakeAt;
    if (deadline != null) {
      orchestrator.restorePendingWake(agentId: agentId, dueAt: deadline);
    }
  }

  static String _defaultDisplayName(String dayId) {
    final datePart = dayId.replaceFirst('dayplan-', '');
    return 'Shepherd $datePart';
  }
}
