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
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Deterministic identity id of the single Daily OS planner (ADR 0022).
///
/// Constant across devices on purpose: concurrent `getOrCreatePlannerAgent`
/// calls on offline peers create entities with identical ids, so sync merges
/// them via LWW instead of diverging into one planner per device.
const dailyOsPlannerAgentId = 'daily_os_planner';

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

      // Agent → day link, mirroring the agentTask/agentProject slot links, so
      // `slots.activeDayId` can be derived from the synced log
      // (State-as-Projection, PR 4 B3). The cached slot above stays the read
      // source until the cutover.
      await syncService.upsertLink(
        AgentLink.agentDay(
          id: _uuid.v4(),
          fromId: identity.agentId,
          toId: dayId,
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
      triggerTokens: {dayAgentPlanningDayToken(dayId)},
    );

    domainLogger.log(
      LogDomain.agentRuntime,
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

  /// Get or create the single long-lived Daily OS planner identity
  /// (ADR 0022).
  ///
  /// Idempotent: returns the existing identity when one exists. Creation
  /// uses the deterministic [dailyOsPlannerAgentId], so concurrent creation
  /// on different devices converges to one identity via LWW instead of
  /// splitting the planner's memory across duplicates.
  ///
  /// Unlike [createDayAgent], the planner gets **no** `activeDayId` slot and
  /// **no** `AgentDayLink`: a day is an explicit workspace carried by wake
  /// tokens, not part of the planner's identity or state (ADR 0022
  /// Decisions 2–3).
  Future<AgentIdentityEntity> getOrCreatePlannerAgent({
    Set<String> allowedCategoryIds = const {},
    String? templateId,
    String? profileId,
    String? displayName,
  }) async {
    final existing = await agentService.getAgent(dailyOsPlannerAgentId);
    if (existing != null) return existing;

    final resolvedTemplateId = templateId ?? dayAgentTemplateId;

    var created = false;
    final identity = await syncService.runInTransaction(() async {
      final duplicate = await agentService.getAgent(dailyOsPlannerAgentId);
      if (duplicate != null) return duplicate;

      final templateEntity = await repository.getEntity(resolvedTemplateId);
      if (templateEntity is! AgentTemplateEntity ||
          templateEntity.deletedAt != null ||
          templateEntity.kind != AgentTemplateKind.dayAgent) {
        throw StateError(
          'Template $resolvedTemplateId is not an active day-agent template.',
        );
      }

      final createdIdentity = await agentService.createAgent(
        agentId: dailyOsPlannerAgentId,
        kind: _agentKind,
        displayName: displayName ?? 'Shepherd',
        config: AgentConfig(
          modelId: templateEntity.modelId,
          profileId: profileId ?? templateEntity.profileId,
        ),
        allowedCategoryIds: allowedCategoryIds,
      );

      await syncService.upsertLink(
        AgentLink.templateAssignment(
          // Deterministic link id for the same convergence reason as the
          // identity id: both devices write the same row, LWW merges.
          id: '$dailyOsPlannerAgentId:template-assignment',
          fromId: resolvedTemplateId,
          toId: createdIdentity.agentId,
          createdAt: clock.now(),
          updatedAt: clock.now(),
          vectorClock: null,
        ),
      );

      created = true;
      return createdIdentity;
    });

    // Only notify when this call actually created the planner; a concurrent
    // peer's write found by the in-transaction recheck is not our mutation.
    if (created) {
      onPersistedStateChanged?.call(identity.agentId);
      domainLogger.log(
        LogDomain.agentRuntime,
        'created planner agent ${DomainLogger.sanitizeId(identity.agentId)}',
        subDomain: 'lifecycle',
      );
    }
    return identity;
  }

  /// Enqueue a drafting wake for the day agent that owns [dayDate].
  ///
  /// When [captureId] is provided, the source capture is included as a
  /// `capture_submitted:<captureId>` trigger token so the workflow loads its
  /// transcript and parsed items into the drafting prompt.
  ///
  /// When [decidedTaskIds] is non-empty, each task id is advertised as a
  /// `decided_task:<taskId>` trigger token. The workflow hydrates these
  /// alongside any capture-derived matches and surfaces the merged set in
  /// the drafting prompt so the model can attach `taskId` on the blocks it
  /// places. Blank/whitespace task ids are silently skipped to mirror the
  /// [captureId] guard. Duplicates dedupe via the trigger-token set.
  ///
  /// When [decidedCaptureItemIds] is non-empty, each parsed item id is
  /// advertised as a `decided_capture_item:<parsedItemId>` trigger token.
  /// These represent approved capture items that do not have a persisted task
  /// yet; drafting carries their parsed details so the model can create a task
  /// before placing it.
  ///
  /// Returns `false` when no active day agent exists for [dayDate]. Callers
  /// are expected to either call [createDayAgent] first or surface the
  /// missing-agent state in the UI.
  Future<bool> enqueueDraftingWake({
    required DateTime dayDate,
    String? captureId,
    List<String> decidedTaskIds = const [],
    List<String> decidedCaptureItemIds = const [],
  }) async {
    final agent = await getDayAgentForDate(dayDate);
    if (agent == null) {
      domainLogger.log(
        LogDomain.agentRuntime,
        'no day agent for '
        '${DomainLogger.sanitizeId(dayAgentIdForDate(dayDate))}; '
        'drafting wake not enqueued',
        subDomain: 'drafting',
      );
      return false;
    }
    final dayId = dayAgentIdForDate(dayDate);
    final triggerTokens = <String>{
      dayAgentPlanningDayToken(dayId),
      dayAgentDraftingToken(dayId),
      if (captureId != null && captureId.trim().isNotEmpty)
        dayAgentCaptureSubmittedToken(captureId.trim()),
      for (final taskId in decidedTaskIds)
        if (taskId.trim().isNotEmpty) dayAgentDecidedTaskToken(taskId.trim()),
      for (final parsedItemId in decidedCaptureItemIds)
        if (parsedItemId.trim().isNotEmpty)
          dayAgentDecidedCaptureItemToken(parsedItemId.trim()),
    };
    domainLogger.log(
      LogDomain.agentRuntime,
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

  /// Enqueue a refine wake for the day agent that owns [dayDate].
  ///
  /// When [transcript] is non-blank, the text is persisted as a new
  /// `CaptureEntity` (id prefixed `refine_capture:`) and advertised to the
  /// workflow via a `capture_submitted:<captureId>` trigger token alongside
  /// `refine:<dayId>`. Blank/whitespace transcripts skip the capture write
  /// — the wake still fires with only the refine token, and the model
  /// operates on the baseline plan + recent observations alone.
  ///
  /// Pre-checks that a non-deleted plan exists for the day; returns `false`
  /// (and no wake) when none is found, mirroring the missing-agent guard.
  /// The agent identity, captures, and any prior change sets are left
  /// untouched. Explicit user refine is allowed after commit/agreement; the
  /// amendment is tracked as a pending plan diff rather than applied directly.
  Future<bool> enqueueRefineWake({
    required DateTime dayDate,
    required String transcript,
  }) async {
    final agent = await getDayAgentForDate(dayDate);
    if (agent == null) {
      domainLogger.log(
        LogDomain.agentRuntime,
        'no day agent for '
        '${DomainLogger.sanitizeId(dayAgentIdForDate(dayDate))}; '
        'refine wake not enqueued',
        subDomain: 'refine',
      );
      return false;
    }
    final dayId = dayAgentIdForDate(dayDate);
    final plan = await repository.getEntity(dayAgentPlanEntityId(dayId));
    if (plan is! DayPlanEntity ||
        plan.deletedAt != null ||
        plan.agentId != agent.agentId) {
      domainLogger.log(
        LogDomain.agentRuntime,
        'no editable plan for '
        '${DomainLogger.sanitizeId(dayId)}; refine wake not enqueued',
        subDomain: 'refine',
      );
      return false;
    }

    final trimmedTranscript = transcript.trim();
    final triggerTokens = <String>{
      dayAgentPlanningDayToken(dayId),
      dayAgentRefineToken(dayId),
    };
    final now = clock.now();
    String? captureId;
    if (trimmedTranscript.isNotEmpty) {
      captureId = 'refine_capture:${_uuid.v4()}';
      final capture =
          AgentDomainEntity.capture(
                id: captureId,
                agentId: agent.agentId,
                transcript: trimmedTranscript,
                capturedAt: now,
                createdAt: now,
                vectorClock: null,
              )
              as CaptureEntity;
      await syncService.upsertEntity(capture);
      triggerTokens.add(dayAgentCaptureSubmittedToken(captureId));
      onPersistedStateChanged?.call(captureId);
    }

    domainLogger.log(
      LogDomain.agentRuntime,
      'refine wake enqueued for '
      '${DomainLogger.sanitizeId(agent.agentId)} / '
      '${DomainLogger.sanitizeId(dayId)}'
      '${captureId == null ? ' (no transcript)' : ''}',
      subDomain: 'refine',
    );
    orchestrator.enqueueManualWake(
      agentId: agent.agentId,
      reason: dayAgentRefineReason,
      triggerTokens: triggerTokens,
    );
    return true;
  }

  /// Trigger a manual wake for [agentId].
  void triggerReanalysis(String agentId) {
    domainLogger.log(
      LogDomain.agentRuntime,
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
      LogDomain.agentRuntime,
      'day-agent scheduled wake cancelled for '
      '${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'lifecycle',
    );
    agentService.cancelPendingWake(agentId);
  }

  /// Restore in-memory runtime state for active day agents at app startup.
  Future<void> restoreSubscriptions() async {
    domainLogger.log(
      LogDomain.agentRuntime,
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
          LogDomain.agentRuntime,
          e,
          message: msg,
          stackTrace: s,
        );
      }
    }

    domainLogger.log(
      LogDomain.agentRuntime,
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
