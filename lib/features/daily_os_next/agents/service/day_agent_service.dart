import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart'
    show
        AgentInferenceSetupMode,
        AgentInferenceSetupOrigin,
        AgentLifecycle,
        AgentTemplateKind,
        WakeReason;
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_capture_events.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

export 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart'
    show dailyOsPlannerAgentId;

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

  /// How far back the legacy migration re-parents day-scoped entities
  /// onto the planner (ADR 0022). Older days are archived in place to avoid
  /// flooding sync for long-time experimental users.
  static const _migrationLookback = Duration(days: 14);

  /// Resolve the agent that owns [date]'s workspace, if one exists.
  ///
  /// ADR 0032: a per-day identity (`day_agent:<dayId>`) owns the day when it
  /// exists; otherwise ownership falls back to the coordinator
  /// ([dailyOsPlannerAgentId]), which covers every day predating the per-day
  /// cutover. This is a pure lookup: it returns `null` when neither identity
  /// has been created yet (no Daily OS activity), so read-only callers stay
  /// side-effect free. Write paths call [getOrCreateDayAgentForDate] to create
  /// the day's agent lazily.
  Future<AgentIdentityEntity?> getDayAgentForDate(DateTime date) async {
    final perDay = await agentService.getAgent(perDayAgentIdForDate(date));
    if (perDay != null) return perDay;
    return agentService.getAgent(dailyOsPlannerAgentId);
  }

  /// Get or create the per-day agent that executes [date]'s capture parsing,
  /// drafting, and refinement (ADR 0032).
  ///
  /// Day-forward cutover: when the coordinator already owns artifacts for the
  /// day — a non-deleted plan it wrote, or any capture on the day — the
  /// coordinator is returned and no per-day identity is created, so
  /// pre-cutover days stay under the monolith's history permanently. Clean
  /// days get a lazily created `day_agent:<dayId>` identity sharing the
  /// coordinator's template (and therefore its soul/persona, ADR 0032 §7) and
  /// `allowedCategoryIds`.
  ///
  /// Config inheritance: per-day agents snapshot the day-agent template at
  /// creation time. Template-level default changes
  /// ([updateDefaultInferenceProfile]) therefore affect future day agents,
  /// while coordinator-instance overrides ([updatePlannerProfileOverride],
  /// [updatePlannerThinkingModelOverride]) affect only the coordinator.
  ///
  /// Idempotent and convergent: the deterministic id means concurrent lazy
  /// creation on offline peers merges via LWW. This is also the single agent
  /// resolution seam for durable processing jobs, which resolve their target
  /// agent at execution time rather than persisting an agent id.
  Future<AgentIdentityEntity> getOrCreateDayAgentForDate(DateTime date) async {
    final dayId = dayAgentIdForDate(date);
    final agentId = perDayAgentId(dayId);
    final existing = await agentService.getAgent(agentId);
    if (existing != null) return existing;

    // Ensures the coordinator (and its learning substrate) exists and gives
    // the cutover check + category inheritance a resolved identity.
    final planner = await getOrCreatePlannerAgent();
    if (await _plannerOwnsDay(planner: planner, dayId: dayId)) {
      return planner;
    }

    var created = false;
    final identity = await syncService.runInTransaction(() async {
      final duplicate = await agentService.getAgent(agentId);
      if (duplicate != null) return duplicate;

      // Re-checked inside the transaction: the outer check above can race a
      // concurrent write that makes the coordinator start owning this day
      // between that read and this one, so only this check-and-write pair
      // being atomic actually prevents split ownership.
      if (await _plannerOwnsDay(planner: planner, dayId: dayId)) {
        return planner;
      }

      final templateEntity = await repository.getEntity(dayAgentTemplateId);
      if (templateEntity is! AgentTemplateEntity ||
          templateEntity.deletedAt != null ||
          templateEntity.kind != AgentTemplateKind.dayAgent) {
        throw StateError(
          'Template $dayAgentTemplateId is not an active day-agent template.',
        );
      }

      final profileId = templateEntity.profileId;
      final createdIdentity = await agentService.createAgent(
        agentId: agentId,
        kind: _agentKind,
        // Locale-neutral ISO suffix keeps day agents distinguishable and
        // sortable in the Instances list without touching l10n.
        displayName: '${planner.displayName} · ${_dayLabel(dayId)}',
        config: AgentConfig(
          modelId: templateEntity.modelId,
          profileId: profileId,
          inferenceSetup: profileId == null
              ? null
              : AgentInferenceSetup(
                  mode: AgentInferenceSetupMode.configured,
                  origin: AgentInferenceSetupOrigin.templateSnapshot,
                  baseProfileId: profileId,
                  originEntityId: dayAgentTemplateId,
                ),
        ),
        allowedCategoryIds: planner.allowedCategoryIds,
      );

      await syncService.upsertLink(
        AgentLink.templateAssignment(
          id: '$agentId:template-assignment',
          fromId: dayAgentTemplateId,
          toId: createdIdentity.agentId,
          createdAt: clock.now(),
          updatedAt: clock.now(),
          vectorClock: null,
        ),
      );

      created = true;
      return createdIdentity;
    });

    if (created) {
      // Notify with both ids: agent-keyed listeners (internals, running
      // state) and day-keyed listeners (day page providers watch the dayId
      // token).
      onPersistedStateChanged
        ?..call(identity.agentId)
        ..call(dayId);
      domainLogger.log(
        LogDomain.agentRuntime,
        'created per-day agent ${DomainLogger.sanitizeId(identity.agentId)}',
        subDomain: 'lifecycle',
      );
    }
    return identity;
  }

  /// Whether the coordinator already owns [dayId]'s artifacts (day-forward
  /// cutover rule): a non-deleted plan it wrote, or any capture on the day.
  Future<bool> _plannerOwnsDay({
    required AgentIdentityEntity planner,
    required String dayId,
  }) async {
    final plan = await repository.getEntity(dayAgentPlanEntityId(dayId));
    if (plan is DayPlanEntity &&
        plan.deletedAt == null &&
        plan.agentId == planner.agentId) {
      return true;
    }
    final metas = await repository.getCaptureEventMetaByAgentId(
      planner.agentId,
    );
    return metas.any((meta) => captureEventDayId(meta) == dayId);
  }

  /// `YYYY-MM-DD` portion of a `dayplan-YYYY-MM-DD` day id.
  static String _dayLabel(String dayId) {
    const prefix = 'dayplan-';
    return dayId.startsWith(prefix) ? dayId.substring(prefix.length) : dayId;
  }

  /// Get or create the single long-lived Daily OS planner identity
  /// (ADR 0022).
  ///
  /// Idempotent: returns the existing identity when one exists. Creation
  /// uses the deterministic [dailyOsPlannerAgentId], so concurrent creation
  /// on different devices converges to one identity via LWW instead of
  /// splitting the planner's memory across duplicates.
  ///
  /// The planner gets **no** `activeDayId` slot and **no** `AgentDayLink`: a
  /// day is an explicit workspace carried by wake tokens, not part of the
  /// planner's identity or state (ADR 0022 Decisions 2–3).
  Future<AgentIdentityEntity> getOrCreatePlannerAgent({
    Set<String> allowedCategoryIds = const {},
    String? templateId,
    String? profileId,
    String? displayName,
  }) async {
    final existing = await agentService.getAgent(dailyOsPlannerAgentId);
    if (existing != null) {
      // Migration is idempotent and best-effort, so run it on every resolve —
      // not only on first creation. A legacy `day_agent` can sync in from
      // another device after the planner already exists here, or a
      // first-creation migration can have failed or been interrupted; running
      // it on the existing path lets convergence eventually heal instead of
      // stranding that data under its old id forever.
      await _migrateLegacyDayAgents(planner: existing);
      return existing;
    }

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

      final resolvedProfileId = profileId ?? templateEntity.profileId;
      final createdIdentity = await agentService.createAgent(
        agentId: dailyOsPlannerAgentId,
        kind: _agentKind,
        displayName: displayName ?? 'Shepherd',
        config: AgentConfig(
          modelId: templateEntity.modelId,
          profileId: resolvedProfileId,
          inferenceSetup: resolvedProfileId == null
              ? null
              : AgentInferenceSetup(
                  mode: AgentInferenceSetupMode.configured,
                  origin: AgentInferenceSetupOrigin.templateSnapshot,
                  baseProfileId: resolvedProfileId,
                  originEntityId: resolvedTemplateId,
                ),
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
    await _migrateLegacyDayAgents(planner: identity);
    return identity;
  }

  /// Changes the synced default inference profile for Daily OS.
  ///
  /// Existing planners that still follow the template snapshot are updated as
  /// part of the change. A planner with a user-owned override is deliberately
  /// left untouched, so changing the default never silently replaces an
  /// explicit instance choice.
  Future<void> updateDefaultInferenceProfile(String profileId) async {
    String? updatedPlannerId;
    await syncService.runInTransaction(() async {
      await templateService.updateTemplate(
        templateId: dayAgentTemplateId,
        profileId: profileId,
      );

      final planner = await agentService.getAgent(dailyOsPlannerAgentId);
      if (planner == null) return;

      final currentSetup = planner.config.inferenceSetup;
      if (currentSetup != null &&
          currentSetup.origin != AgentInferenceSetupOrigin.templateSnapshot) {
        return;
      }

      final updated = planner.copyWith(
        config: planner.config.copyWith(
          profileId: profileId,
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.templateSnapshot,
            baseProfileId: profileId,
            originEntityId: dayAgentTemplateId,
          ),
        ),
        updatedAt: clock.now(),
      );
      await syncService.upsertEntity(updated);
      updatedPlannerId = planner.agentId;
    });
    if (updatedPlannerId case final plannerId?) {
      onPersistedStateChanged?.call(plannerId);
    }
  }

  /// Replaces the planner's inherited setup with a user-owned profile.
  ///
  /// Selecting a profile clears any direct thinking-model override so the
  /// newly selected profile is authoritative in every capability slot.
  Future<void> updatePlannerProfileOverride(String profileId) async {
    String? updatedPlannerId;
    await syncService.runInTransaction(() async {
      final planner = await agentService.getAgent(dailyOsPlannerAgentId);
      if (planner == null) {
        throw StateError('Daily OS planner has not been created yet');
      }

      await _persistPlannerInferenceSetup(
        planner: planner,
        profileId: profileId,
        setup: AgentInferenceSetup(
          mode: AgentInferenceSetupMode.configured,
          origin: AgentInferenceSetupOrigin.user,
          baseProfileId: profileId,
        ),
      );
      updatedPlannerId = planner.agentId;
    });
    if (updatedPlannerId case final plannerId?) {
      onPersistedStateChanged?.call(plannerId);
    }
  }

  /// Persists a direct thinking-model override for the Daily OS planner.
  ///
  /// The planner's current base profile remains in place so its other
  /// capability slots stay available.
  Future<void> updatePlannerThinkingModelOverride(String modelConfigId) async {
    String? updatedPlannerId;
    await syncService.runInTransaction(() async {
      final planner = await agentService.getAgent(dailyOsPlannerAgentId);
      if (planner == null) {
        throw StateError('Daily OS planner has not been created yet');
      }
      final template = await templateService.getTemplate(dayAgentTemplateId);
      if (template == null) {
        throw StateError('Daily OS template $dayAgentTemplateId not found');
      }
      final currentSetup = planner.config.inferenceSetup;
      final baseProfileId =
          currentSetup?.mode == AgentInferenceSetupMode.configured
          ? currentSetup?.baseProfileId ??
                planner.config.profileId ??
                template.profileId
          : planner.config.profileId ?? template.profileId;
      if (baseProfileId == null) {
        throw StateError('Choose a Daily OS default profile first');
      }

      await _persistPlannerInferenceSetup(
        planner: planner,
        profileId: baseProfileId,
        setup: AgentInferenceSetup(
          mode: AgentInferenceSetupMode.configured,
          origin: AgentInferenceSetupOrigin.user,
          baseProfileId: baseProfileId,
          thinkingModelOverrideId: modelConfigId,
          originEntityId: currentSetup?.originEntityId,
        ),
      );
      updatedPlannerId = planner.agentId;
    });
    if (updatedPlannerId case final plannerId?) {
      onPersistedStateChanged?.call(plannerId);
    }
  }

  /// Clears every planner override and follows the current Daily OS default.
  Future<void> resetPlannerInferenceToDefault() async {
    String? updatedPlannerId;
    await syncService.runInTransaction(() async {
      final planner = await agentService.getAgent(dailyOsPlannerAgentId);
      if (planner == null) {
        throw StateError('Daily OS planner has not been created yet');
      }
      final template = await templateService.getTemplate(dayAgentTemplateId);
      if (template == null) {
        throw StateError('Daily OS template $dayAgentTemplateId not found');
      }
      final profileId = template.profileId;
      if (profileId == null) {
        throw StateError('Choose a Daily OS default profile first');
      }

      await _persistPlannerInferenceSetup(
        planner: planner,
        profileId: profileId,
        setup: AgentInferenceSetup(
          mode: AgentInferenceSetupMode.configured,
          origin: AgentInferenceSetupOrigin.templateSnapshot,
          baseProfileId: profileId,
          originEntityId: dayAgentTemplateId,
        ),
      );
      updatedPlannerId = planner.agentId;
    });
    if (updatedPlannerId case final plannerId?) {
      onPersistedStateChanged?.call(plannerId);
    }
  }

  Future<void> _persistPlannerInferenceSetup({
    required AgentIdentityEntity planner,
    required String profileId,
    required AgentInferenceSetup setup,
  }) async {
    final updated = planner.copyWith(
      config: planner.config.copyWith(
        profileId: profileId,
        inferenceSetup: setup,
      ),
      updatedAt: clock.now(),
    );
    await syncService.upsertEntity(updated);
  }

  /// Idempotent, best-effort migration from the old per-day identity model to
  /// the single planner (ADR 0022 Decision 2).
  ///
  /// Runs on every `getOrCreatePlannerAgent` resolve — not only first creation —
  /// so a legacy `day_agent` that syncs in from another device after the planner
  /// exists, or one stranded by an interrupted first migration, still converges.
  /// After the first successful pass the active-`day_agent` query is empty and
  /// this returns immediately. For every other active `day_agent` identity it:
  /// 1. clears the agent's `scheduledWakeAt` so the scheduled-wake manager
  ///    stops waking the now-defunct per-day agent, and
  /// 2. archives it (lifecycle → dormant) so it no longer wakes or is
  ///    restored, and
  /// 3. re-parents its recent day-scoped **artifacts** — day plans, captures,
  ///    parsed items, and change sets — onto the planner so the user's existing
  ///    plans (and their pending refine diffs) stay visible.
  ///
  /// Deliberately **not** re-parented: the legacy agent's `agentMessage`
  /// observations/reports, `wakeTokenUsage`, and `changeDecision` audit records.
  /// Per ADR 0022 Decision 6 the planner's cross-day episodic memory is
  /// forward-looking — it learns from days it actually plans — so pre-flip
  /// observations stay with the archived agent rather than seeding the planner's
  /// fold. The audit/usage records are diagnostics that no day-surface read
  /// keys by planner id (`pendingPlanDiffsForDay` reads change *sets*, which are
  /// re-parented), so leaving them in place loses nothing user-visible.
  ///
  /// Re-parenting is **bounded to recent history** ([_migrationLookback]) and
  /// chunked implicitly per agent, so a long-time experimental user does not
  /// flood the sync channel; older days are archived in place (their entities
  /// keep the old agent id and simply stop surfacing). Deterministic entity ids
  /// (`day_agent_plan:<dayId>`) are preserved.
  Future<void> _migrateLegacyDayAgents({
    required AgentIdentityEntity planner,
  }) async {
    try {
      final agents = await agentService.listAgents(
        lifecycle: AgentLifecycle.active,
      );
      final legacy = agents
          .where(
            (a) =>
                a.kind == _agentKind &&
                a.agentId != planner.agentId &&
                // ADR 0032 per-day agents share the kind but are not legacy —
                // only bare pre-ADR-0022 `dayplan-…` identities get archived.
                !isPerDayAgentId(a.agentId),
          )
          .toList();
      if (legacy.isEmpty) return;

      final cutoff = clock.now().subtract(_migrationLookback);
      var reparented = 0;
      var migrated = 0;
      for (final agent in legacy) {
        // Each agent's archive + re-parent is atomic (one transaction). Isolate
        // failures per agent: a single bad agent must not strand every later
        // agent's live scheduledWakeAt, which would revive the exact zombie-wake
        // the migration exists to kill (the migration never retries).
        try {
          await _migrateLegacyDayAgent(
            agent: agent,
            planner: planner,
            cutoff: cutoff,
            onReparent: () => reparented++,
          );
          migrated++;
        } catch (e, s) {
          domainLogger.error(
            LogDomain.agentRuntime,
            e,
            message:
                'failed to migrate legacy day agent '
                '${DomainLogger.sanitizeId(agent.agentId)}',
            stackTrace: s,
          );
        }
      }
      domainLogger.log(
        LogDomain.agentRuntime,
        'migrated $migrated/${legacy.length} legacy day agent(s) to planner; '
        're-parented $reparented recent entit(ies)',
        subDomain: 'migration',
      );
    } catch (e, s) {
      // Migration is best-effort: a failure must not block planner creation or
      // the wake that triggered it. The planner still works for new days;
      // legacy data simply stays under its old id.
      domainLogger.error(
        LogDomain.agentRuntime,
        e,
        message: 'legacy day-agent migration failed',
        stackTrace: s,
      );
    }
  }

  Future<void> _migrateLegacyDayAgent({
    required AgentIdentityEntity agent,
    required AgentIdentityEntity planner,
    required DateTime cutoff,
    required void Function() onReparent,
  }) async {
    final now = clock.now();
    await syncService.runInTransaction(() async {
      // Clear any scheduled wake and archive the identity so the scheduled-wake
      // manager and restore path leave it alone.
      final state = await repository.getAgentState(agent.agentId);
      if (state != null && state.scheduledWakeAt != null) {
        await syncService.upsertEntity(
          state.copyWith(scheduledWakeAt: null, updatedAt: now),
        );
      }
      await syncService.upsertEntity(
        agent.copyWith(lifecycle: AgentLifecycle.dormant, updatedAt: now),
      );

      // Re-parent recent day-scoped entities onto the planner.
      final entities = await repository.getEntitiesByAgentId(agent.agentId);
      for (final entity in entities) {
        final reparented = _reparentRecentEntity(
          entity,
          planner.agentId,
          cutoff,
        );
        if (reparented != null) {
          await syncService.upsertEntity(reparented);
          onReparent();
        }
      }
    });
    onPersistedStateChanged?.call(agent.agentId);
    onPersistedStateChanged?.call(planner.agentId);
  }

  /// Returns a copy of [entity] re-parented to [plannerId] when it is a recent
  /// day-scoped entity worth migrating, or `null` to leave it untouched.
  AgentDomainEntity? _reparentRecentEntity(
    AgentDomainEntity entity,
    String plannerId,
    DateTime cutoff,
  ) {
    return entity.mapOrNull(
      dayPlan: (plan) => plan.planDate.isBefore(cutoff)
          ? null
          : plan.copyWith(agentId: plannerId),
      capture: (capture) => capture.capturedAt.isBefore(cutoff)
          ? null
          : capture.copyWith(agentId: plannerId),
      parsedItem: (item) => item.createdAt.isBefore(cutoff)
          ? null
          : item.copyWith(agentId: plannerId),
      // Re-parent recent change sets so a pre-cutover pending plan diff stays
      // visible: pendingPlanDiffsForDay reads them by agentId.
      changeSet: (cs) => cs.createdAt.isBefore(cutoff)
          ? null
          : cs.copyWith(agentId: plannerId),
    );
  }

  /// Persists a refine transcript as a `CaptureEntity` (id prefixed
  /// `refine_capture:`), or does nothing when [transcript] is blank.
  ///
  /// Returns the persisted capture's id, or `null` for a blank transcript.
  /// Called once at enqueue time for the durable `refinePlan` outbox job
  /// (ADR 0032 phase 1) — the same capture id is then referenced by the
  /// job's payload, so a crash-and-retry re-runs against the original
  /// wording instead of
  /// writing a duplicate.
  Future<String?> persistRefineCapture({
    required String agentId,
    required String dayId,
    required String transcript,
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return null;
    final now = clock.now();
    final captureId = 'refine_capture:${_uuid.v4()}';
    final capture =
        AgentDomainEntity.capture(
              id: captureId,
              agentId: agentId,
              transcript: trimmed,
              capturedAt: now,
              createdAt: now,
              vectorClock: null,
              dayId: dayId,
            )
            as CaptureEntity;
    await syncService.upsertEntity(capture);
    onPersistedStateChanged?.call(captureId);
    return captureId;
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
      // Legitimate active `day_agent` identities are the coordinator and
      // ADR 0032 per-day agents. A stray bare legacy id (e.g. one synced from
      // a peer still on the pre-ADR-0022 build) carries no restorable day
      // context, so restoring its wake would only produce a failing
      // "no resolvable day" wake — skip it.
      if (agent.agentId != dailyOsPlannerAgentId &&
          !isPerDayAgentId(agent.agentId)) {
        continue;
      }
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

  Future<void> _hydrateThrottleDeadline(String agentId) async {
    final state = await repository.getAgentState(agentId);
    final deadline = state?.nextWakeAt;
    if (deadline != null) {
      orchestrator.restorePendingWake(agentId: agentId, dueAt: deadline);
    }
  }
}
