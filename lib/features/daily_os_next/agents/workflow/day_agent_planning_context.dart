part of 'day_agent_workflow.dart';

/// The planning half of the day agent's context: digests, attention planning, captures, drafting and refinement.
extension DayAgentPlanningContext on DayAgentWorkflow {
  /// Refreshes and loads the `<recent_weeks>` rollups for a coordinator
  /// digest wake (ADR 0032 digest pooling). Null for every other wake.
  ///
  /// The refresh WRITES the rollup registers (the digest wake is their only
  /// maintenance point — same precedent as the memory pipeline compacting
  /// during context assembly); both the write and the read are fail-soft in
  /// the service, and this guard absorbs unexpected bugs so rollups can
  /// never kill a wake.
  Future<List<Map<String, Object?>>?> _recentWeeksContext({
    required String agentId,
    required DailyOsPlannerWakeContext wakeContext,
    required DateTime now,
  }) async {
    final service = weekContextService;
    if (!wakeContext.isDigestWake ||
        agentId != dailyOsPlannerAgentId ||
        service == null) {
      return null;
    }
    try {
      await service.ensureWeekRollups(now: now);
      return await service.recentWeeksJson(now: now);
    } catch (e, s) {
      _logError('failed to load recent weeks', error: e, stackTrace: s);
      return null;
    }
  }

  /// Assembles the `<digest>` inputs for a coordinator digest wake
  /// (ADR 0032 phase 3): status events raised since the last digest, the
  /// current directives for today and tomorrow, and the two-day attention
  /// window. Null for every other wake. Fail-soft: a load error degrades to
  /// no digest section rather than killing the wake.
  Future<Map<String, Object?>?> _digestContext({
    required String agentId,
    required DailyOsPlannerWakeContext wakeContext,
    required DateTime dayDate,
    required DateTime now,
    DayDirectiveEntity? preloadedTodayDirective,
  }) async {
    if (!wakeContext.isDigestWake ||
        agentId != dailyOsPlannerAgentId ||
        directiveService == null) {
      return null;
    }
    try {
      // Overlap the watermark by a sync-lag slack: `created_at` is stamped
      // by the ORIGINATING device, so another device's offline escalation
      // can sync in bearing a timestamp older than this device's
      // digest-completion milestone. A strict `> watermark` read would skip
      // it forever; the bounded overlap re-ranks such late arrivals instead
      // (re-showing an already-digested event is advisory noise, skipping
      // an escalation is loss). Events syncing in later than the slack are
      // still missed — accepted residual until consumed-event tracking
      // exists.
      final since = (await _lastDigestAt(
        agentId,
        now,
      )).subtract(_digestStatusEventSyncLagSlack);
      final tomorrowId = dayAgentIdForDate(
        DateTime(dayDate.year, dayDate.month, dayDate.day + 1),
      );
      // The watermark advances to the digest's OWN completion milestone —
      // never to the last returned row — so the digest is an advisory
      // distillation, not an exactly-once queue; equal-timestamp rows at a
      // page boundary cannot be skipped by the watermark. When more events
      // exist than the digest renders, selection is severity-ranked
      // (attention-weighted aggregation) rather than arrival-order, and the
      // rendered section says it was truncated instead of silently reading
      // as "this was everything".
      //
      // Ranking must see EVERY event since the watermark: the query returns
      // oldest-first, so a fixed-size fetch would truncate the NEWEST events
      // before ranking — and once this digest's completion milestone
      // advances the watermark, those unseen events (possibly escalations)
      // would be skipped forever. A full page therefore refetches with a
      // doubled limit until the tail fits, bounded by a hard ceiling; only
      // at the ceiling may events go unranked, and then the truncation
      // marker is forced on.
      var fetchLimit = _digestStatusEventFetchLimit;
      var candidates = await agentRepository.getDayStatusEventsSince(
        since,
        limit: fetchLimit,
      );
      while (candidates.length >= fetchLimit &&
          fetchLimit < _digestStatusEventFetchCeiling) {
        fetchLimit = fetchLimit * 2 < _digestStatusEventFetchCeiling
            ? fetchLimit * 2
            : _digestStatusEventFetchCeiling;
        candidates = await agentRepository.getDayStatusEventsSince(
          since,
          limit: fetchLimit,
        );
      }
      final poolTruncated = candidates.length >= _digestStatusEventFetchCeiling;
      if (poolTruncated) {
        // The pool is oldest-first, so at the ceiling the NEWEST events —
        // the live escalations — are exactly the ones that would go
        // unranked and be skipped forever once the watermark advances.
        // Merge one newest-first page so ranking covers both ends of the
        // backlog; only the middle can drop, and the marker says so.
        final newest = await agentRepository.getDayStatusEventsSinceNewestFirst(
          since,
          limit: _digestStatusEventFetchLimit,
        );
        final seenIds = {for (final event in candidates) event.id};
        candidates = [
          ...candidates,
          for (final event in newest)
            if (seenIds.add(event.id)) event,
        ];
      }
      final (:selected, :truncated) = selectDigestStatusEvents(
        candidates,
        limit: _digestStatusEventLimit,
      );
      final statusEvents = selected;
      // Reuse the standalone <day_directive> load when it is this day's —
      // the digest previously re-read the identical register.
      final todayDirective =
          preloadedTodayDirective != null &&
              preloadedTodayDirective.dayId == wakeContext.dayId
          ? preloadedTodayDirective
          : await directiveService!.directiveForDay(wakeContext.dayId);
      final tomorrowDirective = await directiveService!.directiveForDay(
        tomorrowId,
      );
      final dayStart = DateTime(dayDate.year, dayDate.month, dayDate.day);
      final attentionWindow = await agentRepository
          .getAttentionPlanningInputsForWindow(
            start: dayStart,
            // Two local days (see _attentionPlanningContext on DST-safe
            // day arithmetic): the digest issues today's AND tomorrow's
            // directives.
            end: DateTime(dayStart.year, dayStart.month, dayStart.day + 2),
          );
      return {
        'since': since.toIso8601String(),
        'todayDayId': wakeContext.dayId,
        'tomorrowDayId': tomorrowId,
        if (truncated || poolTruncated) 'statusEventsTruncated': true,
        'statusEvents': [
          for (final event in statusEvents)
            {
              'dayId': event.dayId,
              'agentId': event.agentId,
              'status': event.status.name,
              if (event.reasons.isNotEmpty)
                'reasons': [for (final reason in event.reasons) reason.name],
              if (event.note.isNotEmpty) 'note': event.note,
              'raisedAt': event.raisedAt.toIso8601String(),
            },
        ],
        'directives': {
          'today': todayDirective == null
              ? null
              : _directiveToJson(todayDirective),
          'tomorrow': tomorrowDirective == null
              ? null
              : _directiveToJson(tomorrowDirective),
        },
        if (!attentionWindow.isEmpty)
          'attentionWindow': _attentionPlanningToJson(attentionWindow),
      };
    } catch (e, s) {
      _logError('failed to load digest context', error: e, stackTrace: s);
      return null;
    }
  }

  /// Cap on status events rendered into one digest. Escalations are rare by
  /// contract (one per wake, typed reasons only), so hitting this means
  /// something is systemically wrong — which the `statusEventsTruncated`
  /// marker surfaces to the model rather than hiding.
  static const _digestStatusEventLimit = 50;

  /// Sync-lag overlap subtracted from the digest watermark before reading
  /// status events (see `_digestContext`).
  static const _digestStatusEventSyncLagSlack = Duration(hours: 12);

  /// Initial candidate-pool fetch for ranked selection — larger than the
  /// render cap so severity decides what survives truncation instead of
  /// arrival order. A full page doubles and refetches (see the loop above)
  /// so ranking covers everything since the watermark.
  static const _digestStatusEventFetchLimit = 200;

  /// Hard ceiling on the doubling refetch — a memory backstop far above any
  /// real backlog (per-wake caps make even hundreds pathological). Only at
  /// this ceiling can events since the watermark go unranked, and then the
  /// `statusEventsTruncated` marker is forced on.
  static const _digestStatusEventFetchCeiling = 2000;

  /// The newest digest watermark: the coordinator's most recent
  /// `dailyWakeCompleted` milestone, falling back to 48h ago for the first
  /// digest so a fresh install does not scan unbounded history.
  Future<DateTime> _lastDigestAt(String agentId, DateTime now) async {
    final markers = await agentRepository.getMessagesByKind(
      agentId,
      AgentMessageKind.system,
      limit: 200,
    );
    for (final marker in markers) {
      if (marker.metadata.milestone == AgentMilestone.dailyWakeCompleted) {
        return marker.createdAt;
      }
    }
    return now.subtract(const Duration(hours: 48));
  }

  Future<AttentionPlanningInputs> _attentionPlanningContext(
    DateTime planDate,
  ) async {
    try {
      final start = DateTime(planDate.year, planDate.month, planDate.day);
      return await agentRepository.getAttentionPlanningInputsForWindow(
        start: start,
        // Use day + 1 (not Duration(days: 1)) so the window stays at local
        // midnight across DST transitions, where a day may be 23 or 25 hours.
        end: DateTime(start.year, start.month, start.day + 1),
      );
    } catch (e, s) {
      _logError(
        'failed to load attention planning context',
        error: e,
        stackTrace: s,
      );
      return const AttentionPlanningInputs.empty();
    }
  }

  Map<String, Object?> _attentionPlanningToJson(
    AttentionPlanningInputs inputs,
  ) {
    return {
      'claims': [
        for (final claim in inputs.claims)
          {
            'id': claim.id,
            'agentId': claim.agentId,
            'kind': claim.kind.name,
            'title': claim.title,
            'categoryId': claim.categoryId,
            'requestedMinutes': claim.requestedMinutes,
            'impact': claim.impact,
            'urgency': claim.urgency,
            'energyFit': claim.energyFit.name,
            'scopeKind': claim.scopeKind.name,
            'earliestStart': claim.earliestStart?.toIso8601String(),
            'latestEnd': claim.latestEnd?.toIso8601String(),
            'deadline': claim.deadline?.toIso8601String(),
            'nextReviewAt': claim.nextReviewAt?.toIso8601String(),
            'targetId': claim.targetId,
            'targetKind': claim.targetKind,
            'rationale': claim.rationale,
            'evidenceRefs': [
              for (final ref in claim.evidenceRefs)
                {
                  'kind': ref.kind.name,
                  'id': ref.id,
                  'label': ref.label,
                },
            ],
          },
      ],
      'standingAgreements': [
        for (final agreement in inputs.standingAgreements)
          {
            'id': agreement.id,
            'agentId': agreement.agentId,
            'title': agreement.title,
            'scope': agreement.scope.name,
            'cadence': agreement.cadence.name,
            'status': agreement.status.name,
            'enforcement': agreement.enforcement.name,
            'approvalMode': agreement.approvalMode.name,
            'categoryId': agreement.categoryId,
            'targetId': agreement.targetId,
            'targetKind': agreement.targetKind,
            'minCount': agreement.minCount,
            'maxCount': agreement.maxCount,
            'minMinutes': agreement.minMinutes,
            'maxMinutes': agreement.maxMinutes,
            'preferredSessionMinutes': agreement.preferredSessionMinutes,
            'priority': agreement.priority,
            'canPreempt': agreement.canPreempt,
            'activeFrom': agreement.activeFrom?.toIso8601String(),
            'activeUntil': agreement.activeUntil?.toIso8601String(),
            'rationale': agreement.rationale,
          },
      ],
    };
  }

  Future<CaptureContext?> _captureContext({
    required AgentIdentityEntity agentIdentity,
    required DateTime planDate,
    required DailyOsPlannerWakeContext wakeContext,
  }) async {
    final service = captureService;
    if (service == null) return null;
    if (wakeContext.captureIds.isEmpty) return null;

    // The IDs are pre-sorted, so under a merged multi-capture token set the
    // same capture wins deterministically. The first capture that loads and
    // belongs to a legitimate day owner (spanning the ADR 0032 ownership
    // cutover) becomes the wake's capture context.
    for (final captureId in wakeContext.captureIds) {
      final capture = await service.getCapture(captureId);
      if (capture == null ||
          !canReadDailyOsDayArtifact(
            readerAgentId: agentIdentity.agentId,
            ownerAgentId: capture.agentId,
            dayId: captureDayId(capture),
          )) {
        continue;
      }

      final corpus = await service.buildTaskCorpusSnapshot(
        allowedCategoryIds: agentIdentity.allowedCategoryIds,
        day: planDate,
        dependencyResolver: dependencyResolver,
      );
      return CaptureContext(capture: capture, taskCorpus: corpus);
    }
    return null;
  }

  /// The day's planning floor as the model sees it.
  ///
  /// Empty on a day that has not begun — there is no past to guard. Otherwise
  /// either the padded start to build on, or `closed` when no usable slot
  /// remains, which are different instructions and must not collapse.
  Map<String, Object?> _planningWindowJson({
    required DateTime planDate,
    required DateTime now,
    DayPlanEntity? refineBaseline,
  }) {
    // A refine wake proposes changes *on top of* a plan that already spends
    // part of the day, and `propose_plan_diff` applies them incrementally. Its
    // own capacity governs, not the workflow config's.
    //
    // But a single "available" number cannot describe an incremental edit:
    // dropping a 180-minute block and adding another is net zero, and reading
    // it against the unused remainder alone would report a conflict that does
    // not exist. So refine gets the two facts it needs — the plan's capacity
    // and what it currently spends — and judges its own net change against
    // them.
    //
    // Occupancy is recomputed from the blocks rather than read from the
    // denormalized `scheduledMinutes`, which can drift; the projection and the
    // agenda view both recompute for the same reason.
    final refineBudget = refineBaseline == null
        ? const <String, Object?>{}
        : {
            'capacityMinutes': refineBaseline.capacityMinutes,
            'scheduledMinutes': scheduledMinutesFor(
              refineBaseline.data.plannedBlocks,
            ),
          };
    final windowClosed = draftPlanningWindowClosed(
      planDate: planDate,
      now: now,
      capacityMinutes: config.capacityMinutes,
      workingHoursStart: config.workingHoursStart,
      workingHoursEnd: config.workingHoursEnd,
    );
    // Working-hours exhaustion and the end-of-day five-minute boundary are
    // one model-facing state. The same predicate gates whether the plan writer
    // accepts an empty fresh draft, so the prompt and persistence contract
    // cannot contradict each other.
    if (windowClosed) return {'closed': true, ...refineBudget};
    final available = remainingWorkingMinutes(
      planDate: planDate,
      now: now,
      capacityMinutes: config.capacityMinutes,
      workingHoursStart: config.workingHoursStart,
      workingHoursEnd: config.workingHoursEnd,
    );
    // The clock bounds hold for refine too — `proposePlanDiff` enforces the
    // same past-start guard — so the temporal fields are *added to* the refine
    // budget rather than replacing it. Returning capacity and occupancy alone
    // dropped the floor a diff still has to respect, and let a 480-minute
    // baseline advertise room for a 240-minute addition at 15:00 with 115
    // working minutes left.
    // The writer rejects a block that ends after the working day, so the end
    // is advertised beside the start rather than left to be inferred from the
    // working hours: a window that says where work may begin and not where it
    // must stop bought one rejected draft per late-day wake.
    final latest = workingHourOn(planDate, config.workingHoursEnd);
    final budget = <String, Object?>{
      'availableMinutes': ?available,
      'latestEnd': ?latest?.toIso8601String(),
      ...refineBudget,
    };
    final earliest = advertisedPlanningStart(planDate: planDate, now: now);
    if (earliest != null) {
      return {'earliestStart': earliest.toIso8601String(), ...budget};
    }
    return budget;
  }

  Future<DraftingContext?> _draftingContext({
    required AgentIdentityEntity agentIdentity,
    required DailyOsPlannerWakeContext wakeContext,
    required CaptureContext? captureContext,
  }) async {
    final service = planService;
    if (service == null) return null;
    if (!wakeContext.isDraftingWake) return null;

    final baselinePlan = await service.draftPlanForDay(
      agentId: agentIdentity.agentId,
      dayId: wakeContext.dayId,
    );
    final explicitTaskIds = wakeContext.decidedTaskIds;
    final explicitCaptureItemIds = wakeContext.decidedCaptureItemIds.toSet();
    final parsedItems = await _parsedItemsForCapture(captureContext);
    final decidedTasks = await service.hydrateDecidedTasks(
      allowedCategoryIds: agentIdentity.allowedCategoryIds,
      explicitTaskIds: explicitTaskIds,
      parsedItems: parsedItems,
      // The same resolver that gates whether the blocked-work rule is emitted
      // at all, so the rule and the data behind it cannot drift apart: if the
      // model is told to respect blockers, this is what tells it which tasks
      // have any.
      dependencyResolver: dependencyResolver,
    );
    final decidedCaptureItems = [
      for (final item in parsedItems)
        if (explicitCaptureItemIds.contains(item.id)) item,
    ];
    return DraftingContext(
      baselinePlan: baselinePlan,
      decidedTasks: decidedTasks,
      decidedCaptureItems: decidedCaptureItems,
      baselineTaskStates: await _baselineTaskStates(
        service: service,
        baselinePlan: baselinePlan,
        decidedTasks: decidedTasks,
        allowedCategoryIds: agentIdentity.allowedCategoryIds,
      ),
    );
  }

  /// Blocked-work state for tasks the baseline plan already schedules.
  ///
  /// A re-draft replaces the whole block list, so the model re-affirms every
  /// baseline block — including one whose task became blocked *since* that
  /// draft was written. Those tasks are not necessarily decided ones: with no
  /// capture there is no corpus row for them either, so without this the
  /// blocked-work rule would again arrive with nothing behind it, just for a
  /// different set of tasks.
  ///
  /// Folding them into `decidedTasks` instead would be wrong — the prompt
  /// defines that list as tasks *the user approved for placement*, and a block
  /// the agent drafted earlier is not that.
  ///
  /// Skips ids already resolved as decided tasks, so the common re-draft costs
  /// nothing extra, and returns empty when there is nothing left to ask about.
  Future<Map<String, PlannedTaskState>> _baselineTaskStates({
    required DayAgentPlanService service,
    required DayPlanEntity? baselinePlan,
    required List<DecidedTaskRef> decidedTasks,
    required Set<String> allowedCategoryIds,
  }) async {
    if (dependencyResolver == null || baselinePlan == null) return const {};
    final alreadyResolved = {for (final task in decidedTasks) task.id};
    final pending = <String>{
      for (final block in baselinePlan.data.plannedBlocks)
        if (block.taskId case final taskId?)
          if (!alreadyResolved.contains(taskId)) taskId,
    };
    if (pending.isEmpty) return const {};
    return service.resolvePlannedTaskStates(
      taskIds: pending,
      allowedCategoryIds: allowedCategoryIds,
      dependencyResolver: dependencyResolver,
    );
  }

  Future<List<ParsedItemEntity>> _parsedItemsForCapture(
    CaptureContext? captureContext,
  ) async {
    final capture = captureContext?.capture;
    final service = captureService;
    if (capture == null || service == null) return const [];
    final entities = await service.parsedItemsForCapture(capture.id);
    return entities.whereType<ParsedItemEntity>().toList();
  }

  Future<RefineContext?> _refineContext({
    required AgentIdentityEntity agentIdentity,
    required DailyOsPlannerWakeContext wakeContext,
  }) async {
    final service = planService;
    if (service == null) return null;
    if (!wakeContext.isRefineWake) return null;

    final baselinePlan = await service.draftPlanForDay(
      agentId: agentIdentity.agentId,
      dayId: wakeContext.dayId,
    );
    return RefineContext(baselinePlan: baselinePlan);
  }
}
