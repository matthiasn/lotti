part of 'day_agent_service.dart';

/// Private helpers of [DayAgentService] that hold no state of their own; kept beside the class as an extension so the library stays readable.
extension _DayAgentServiceInternals on DayAgentService {
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
    // Indexed day lookup rather than a scan of every capture the coordinator
    // ever owned: this runs on every day-agent identity resolution, i.e.
    // ahead of every day-view read. Captures store the day as their subtype
    // (derived for legacy rows that carry no explicit dayId), so one row is
    // enough to answer the question.
    final captures = await repository.getEntitiesByAgentIdAndSubtype(
      planner.agentId,
      type: AgentEntityTypes.capture,
      subtype: dayId,
      limit: 1,
    );
    return captures.isNotEmpty;
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
        agent.copyWith(
          lifecycle: AgentLifecycle.dormant,
          updatedAt: now,
          lifecycleUpdatedAt: now,
        ),
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

  Future<void> _retireDayAgent(AgentIdentityEntity agent) async {
    final now = clock.now();
    // One transaction: either the agent is dormant *and* its deadline is gone,
    // or neither happened and the next pass retries. Half a retirement is a
    // live agent robbed of its pre-warm, or a dormant one still holding a wake
    // that later passes cannot see — they list active identities only.
    await syncService.runInTransaction(() async {
      final state = await repository.getAgentState(agent.agentId);
      if (state?.scheduledWakeAt != null) {
        await syncService.upsertEntity(
          state!.copyWith(scheduledWakeAt: null, updatedAt: now),
        );
      }
      await syncService.upsertEntity(
        agent.copyWith(
          lifecycle: AgentLifecycle.dormant,
          updatedAt: now,
          lifecycleUpdatedAt: now,
        ),
      );
    });
    // Surfaces watching lifecycle refresh on this, as they do for every other
    // identity mutation in this service.
    onPersistedStateChanged?.call(agent.agentId);
  }

  /// Cold-start bootstrap for the coordinator's digest cadence (ADR 0032
  /// phase 3): ensure one pending digest `ScheduledWakeEntity` exists. A
  /// completed digest re-arms the next one deterministically; this covers
  /// the first digest ever and any install that missed the re-arm (e.g. the
  /// app was killed mid-digest).
  Future<void> _ensurePendingDigestWake() async {
    final existing = await repository.getEntity(
      DayAgentService._digestRecordId,
    );
    final now = clock.now();
    if (existing is ScheduledWakeEntity &&
        existing.deletedAt == null &&
        existing.status == ScheduledWakeStatus.pending) {
      return;
    }
    switch (await _digestRecovery(existing, now)) {
      case _RetryDigest(:final record):
        await _retryInterruptedDigest(record);
        return;
      case _PreserveDigest():
        return;
      case _AdvanceDigest():
        break;
    }
    await _scheduleNextDigest(now);
  }

  Future<void> _scheduleNextDigest(DateTime now) async {
    final next = nextDigestTime(now);
    await syncService.upsertEntity(
      AgentDomainEntity.scheduledWake(
        id: DayAgentService._digestRecordId,
        agentId: dailyOsPlannerAgentId,
        scheduledAt: next,
        status: ScheduledWakeStatus.pending,
        reason: dayAgentDigestReason,
        updatedAt: now,
        vectorClock: null,
        triggerTokens: [dayAgentDigestToken(dayAgentIdForDate(next))],
        workspaceKey: coordinatorDigestWorkspaceKey,
      ),
    );
    domainLogger.log(
      LogDomain.agentRuntime,
      'scheduled coordinator digest wake for ${next.toIso8601String()}',
      subDomain: 'restore',
    );
  }

  Future<void> _retryInterruptedDigest(ScheduledWakeEntity interrupted) async {
    final now = clock.now();
    // Re-armed by `copyWith`, not rebuilt: the retry keeps the consumed
    // record's `scheduledAt`, and `agent_concurrent_resolver` makes
    // consumption *terminal* for a wake window. A row stamped from a null
    // clock would be concurrent with the consumed version on peers and lose
    // to it — the retry would be rejected everywhere but here. Carrying the
    // existing clock forward makes the pending row causally dominate, so it
    // never reaches the concurrent path at all.
    await syncService.upsertEntity(
      interrupted.copyWith(
        status: ScheduledWakeStatus.pending,
        updatedAt: now,
        consumedAt: null,
        // The claim belonged to the run that died. Clearing it lets the retry
        // re-elect rather than inherit a lease no device now holds.
        leaseHostId: null,
        leaseUntil: null,
      ),
    );
    domainLogger.log(
      LogDomain.agentRuntime,
      'retrying interrupted coordinator digest for '
      '${interrupted.scheduledAt.toIso8601String()}',
      subDomain: 'restore',
    );
  }

  void _hydrateThrottleDeadlineFromState(
    String agentId,
    AgentStateEntity? state,
  ) {
    final deadline = state?.nextWakeAt;
    if (deadline != null) {
      orchestrator.restorePendingWake(agentId: agentId, dueAt: deadline);
    }
  }
}
