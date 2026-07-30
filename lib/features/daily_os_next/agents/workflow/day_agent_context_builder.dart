part of 'day_agent_workflow.dart';

/// Pure context-assembly helpers of [DayAgentWorkflow]: user-message
/// construction and the capture/drafting/refine context builders.
extension DayAgentContextBuilder on DayAgentWorkflow {
  String _buildUserMessage({
    required String dayId,
    required DateTime planDate,
    required DateTime now,
    required Set<String> triggerTokens,
    required List<AgentMessageEntity> observations,
    required Map<String, AgentMessagePayloadEntity> observationPayloads,
    required CaptureContext? captureContext,
    required DraftingContext? draftingContext,
    required RefineContext? refineContext,
    required AttentionPlanningInputs attentionPlanning,
    required KnowledgeContext knowledge,
    DayDirectiveEntity? directive,
    List<Map<String, Object?>>? recentWeeksContext,
    Map<String, Object?>? digestContext,
    WeekContext? weekContext,
    List<DayAudioEntryContext> dayAudioEntries = const [],
    String? compactedLog,
  }) {
    // Section order is deliberately STABLE → VOLATILE for prompt-prefix /
    // KV-cache reuse: providers cache the longest identical leading prefix, so
    // anything that varies wake-to-wake must come last. Crucially the two tiers
    // of durable knowledge are split by stability: the always-on
    // `knowledge_index` is global and slow-changing, so it leads the prefix;
    // the scope-filtered `knowledge_statements` vary by which scopes THIS wake
    // touches (capture vs drafting vs refine touch different categories), so
    // they sit AFTER the large day-stable `day_log`/`attention_planning` — a
    // changing statement set must never evict the (much larger) day-log prefix
    // behind it. Prose sections are plain text; data-shaped, tool-facing
    // sections stay JSON inside their tags (see [DayAgentPromptSections]).
    final sections = DayAgentPromptSections()
      ..addText(DayAgentPromptTags.dayId, dayId)
      ..addText(DayAgentPromptTags.planDate, planDate.toIso8601String())
      // Tier 1 — the always-on compact hook index of durable knowledge
      // (ADR 0022 Decisions 9–10). One line per active key, independent of the
      // wake's touched scopes, so it is byte-stable across a planning session
      // and belongs ahead of the day log in the stable prefix.
      ..addText(DayAgentPromptTags.knowledgeIndex, knowledge.hookIndex)
      // The coordinator's directive for this day (ADR 0032 phase 3): the
      // distilled commitments/capacity ledger the drafting contract binds
      // against. Stable within a revision, so it stays in the byte-stable
      // prefix ahead of the day log (ADR §4 slot).
      ..addJson(
        DayAgentPromptTags.dayDirective,
        directive == null ? null : _directiveToJson(directive),
      )
      // The compacted day log (ADR 0017): capture transcripts and the agent's
      // observations as an append-only event tail behind a summary —
      // byte-stable at its head between folds. The derivable section the v2
      // prompt record splices around.
      ..addText(DayAgentPromptTags.dayLog, compactedLog)
      // Durable recording receipts are independent of CaptureEntity creation,
      // so a later wake can recover a completed offline check-in immediately.
      // Capped to the newest entries (ADR 0032 §4 sizes this slot as a
      // provenance/status INDEX, ~32 items): a heavy capture day must not
      // inflate a section that sits ahead of everything behind it in the
      // prompt. The marker keeps truncation explicit instead of reading as
      // "this was everything".
      ..addJson(
        DayAgentPromptTags.dayEntries,
        dayAudioEntries.isEmpty
            ? null
            : [
                for (final entry
                    in dayAudioEntries.length > _dayEntriesLimit
                        ? dayAudioEntries.sublist(
                            dayAudioEntries.length - _dayEntriesLimit,
                          )
                        : dayAudioEntries)
                  entry.toJson(),
                if (dayAudioEntries.length > _dayEntriesLimit)
                  {
                    'truncated': true,
                    'omittedOlderEntries':
                        dayAudioEntries.length - _dayEntriesLimit,
                  },
              ],
      )
      // Day-stable attention claims/agreements precede the per-wake mode blocks.
      ..addJson(
        DayAgentPromptTags.attentionPlanning,
        attentionPlanning.isEmpty
            ? null
            : _attentionPlanningToJson(attentionPlanning),
      )
      // Tier 2 — the scope-filtered full statements for the scopes THIS wake
      // touches. Per-wake-variable, so placed below the large stable blocks
      // (and above the equally per-wake mode blocks) to keep the day-log prefix
      // reusable across differing wake types within a day.
      ..addText(
        DayAgentPromptTags.knowledgeStatements,
        knowledge.statements.isEmpty ? null : knowledge.statements,
      )
      // Week context: the today-so-far line changes with tracked time, making
      // these sections more volatile than the knowledge statements above, so
      // they sit after them. Placing them BEFORE the mode sections is a
      // deliberate trade (plan red-team correction): it lets modeless wakes
      // (scheduled → drafting, the morning pattern) reuse the prefix through
      // `week_ahead`, at the cost of a same-mode re-wake with an unchanged
      // baseline (refine → refine) re-prefilling its mode section when the
      // today line churns. Bodies arrive fully rendered and sanitized from
      // the week-context renderer.
      ..addPreRendered(DayAgentPromptTags.recentDays, weekContext?.recentDays)
      ..addPreRendered(DayAgentPromptTags.weekAhead, weekContext?.weekAhead)
      // Mode blocks: present only for the wake that owns them, stable for it.
      ..addJson(
        DayAgentPromptTags.capture,
        captureContext?.toJson(),
      )
      ..addJson(
        DayAgentPromptTags.drafting,
        draftingContext?.toJson(),
      )
      ..addJson(
        DayAgentPromptTags.refine,
        refineContext?.toJson(),
      )
      // Weekly rollup registers (ADR 0032 digest pooling): month-scale
      // planned-vs-recorded trends, present only on digest wakes and stable
      // within one (rollups refresh at most once per digest).
      ..addJson(DayAgentPromptTags.recentWeeks, recentWeeksContext)
      // Coordinator digest inputs (ADR 0032 phase 3): present only on
      // digest wakes, per-wake stable like the other mode blocks.
      ..addJson(DayAgentPromptTags.digest, digestContext)
      // Pre-compaction fallback listing: superseded by the day log once the
      // read flips, so only rendered while there is no compacted log.
      ..addJson(
        DayAgentPromptTags.recentObservations,
        compactedLog != null
            ? null
            : [
                for (final observation in observations)
                  {
                    'createdAt': observation.createdAt.toIso8601String(),
                    'text': extractPayloadText(
                      observationPayloads[observation.contentEntryId],
                    ),
                  },
              ],
      )
      // Volatile per-wake metadata, kept LAST (before the wall-clock) so a
      // changing trigger set never evicts the large stable blocks above it.
      ..addJson(
        DayAgentPromptTags.triggerTokens,
        triggerTokens
            .where(
              (token) => !token.startsWith(dayAgentProcessingJobPrefix),
            )
            .toList()
          ..sort(),
      )
      // The day's planning floor, next to the wall-clock it is derived from.
      // Rendered for every wake that could place a block, not just drafting:
      // the guard does not care which mode asked.
      ..addJson(
        DayAgentPromptTags.planningWindow,
        _planningWindowJson(
          planDate: planDate,
          now: now,
          // Refine edits an existing plan incrementally, so its budget is what
          // that plan has left, not a fresh day's. A drafting baseline is
          // replaced wholesale, so full capacity is right there.
          refineBaseline: refineContext?.baselinePlan,
        ),
      )
      // The volatile wall-clock is the trailing section.
      ..addText(DayAgentPromptTags.currentLocalTime, now.toIso8601String());
    return sections.build();
  }

  /// Loads the week context for a day-token wake. The service is fail-soft
  /// already (load errors log and return null); this guard additionally
  /// absorbs unexpected service bugs so lookback context can never kill a
  /// wake. The wake's own [now] is passed through so the section's day
  /// classification agrees with `current_local_time` across a midnight
  /// straddle.
  Future<WeekContext?> _weekContext({
    required DateTime planDate,
    required DateTime now,
  }) async {
    try {
      return await weekContextService?.buildForDay(
        planDate: planDate,
        now: now,
      );
    } catch (e, s) {
      _logError('failed to load week context', error: e, stackTrace: s);
      return null;
    }
  }

  Future<List<DayAudioEntryContext>> _dayAudioEntries(String dayId) async {
    try {
      return await dayAudioEntryContextService?.loadForDay(dayId) ?? const [];
    } catch (e, s) {
      _logError(
        'failed to load durable day audio entries',
        error: e,
        stackTrace: s,
      );
      return const [];
    }
  }

  /// Loads the coordinator's durable knowledge and renders the two-tier
  /// prompt blocks (ADR 0022 Decisions 9–10): the always-on hook index plus
  /// the scope-filtered full statements for the scopes this wake actually
  /// touches (`global` always; [touchedScopes] for `category:`/`project:`).
  /// Returns empty blocks (and the caller omits the field) when no knowledge
  /// or no service is configured.
  ///
  /// Knowledge is always read under [dailyOsPlannerAgentId], not the waking
  /// agent: durable learning lives with the coordinator (ADR 0032 §4,
  /// "coordinator-published"), so per-day agents see the same knowledge the
  /// monolith would. For coordinator wakes the two ids coincide.
  Future<KnowledgeContext> _knowledgeContext({
    required AgentIdentityEntity agentIdentity,
    required Set<String> touchedScopes,
    required DateTime now,
  }) async {
    final service = knowledgeService;
    if (service == null) return const KnowledgeContext.empty();
    try {
      final active = await service.activeFor(dailyOsPlannerAgentId);
      if (active.isEmpty) return const KnowledgeContext.empty();
      return KnowledgeContext(
        hookIndex: renderKnowledgeHookIndex(active),
        statements: renderKnowledgeStatements(active, touchedScopes, now: now),
      );
    } catch (e, s) {
      _logError(
        'failed to load durable planner knowledge',
        error: e,
        stackTrace: s,
      );
      return const KnowledgeContext.empty();
    }
  }

  /// The category/project scopes the current wake actually touches (ADR 0022
  /// Decision 10): the categories of the day's attention claims/agreements and
  /// the categories of the baseline plan blocks being drafted/refined. This is
  /// the wake's real workspace, not the planner identity's static allow-list
  /// (which is empty = "allow all" and would surface nothing).
  ///
  /// `category:` scopes come from the `categoryId` every touched entity carries
  /// (`AttentionRequestEntity`, `StandingAgreementEntity`, `DecidedTaskRef`,
  /// `PlannedBlock`). `project:` scopes are derived from claims/agreements that
  /// explicitly target a project (`targetKind == 'project'`, `targetId` = the
  /// project id), so `project:`-scoped durable knowledge (which `_validScope`
  /// and the tool schema accept, ADR Decision 10) is actually reachable when a
  /// project-targeted claim or agreement is in play; tasks/blocks expose only a
  /// category, so they contribute no project scope.
  Set<String> _touchedScopes({
    required AttentionPlanningInputs attentionPlanning,
    required DraftingContext? draftingContext,
    required RefineContext? refineContext,
  }) {
    const projectTargetKind = 'project';
    final scopes = <String>{};
    void addCategory(String? categoryId) {
      if (categoryId != null && categoryId.isNotEmpty) {
        scopes.add(knowledgeCategoryScope(categoryId));
      }
    }

    void addProject(String? targetKind, String? targetId) {
      if (targetKind == projectTargetKind &&
          targetId != null &&
          targetId.isNotEmpty) {
        scopes.add(knowledgeProjectScope(targetId));
      }
    }

    for (final claim in attentionPlanning.claims) {
      addCategory(claim.categoryId);
      addProject(claim.targetKind, claim.targetId);
    }
    for (final agreement in attentionPlanning.standingAgreements) {
      addCategory(agreement.categoryId);
      addProject(agreement.targetKind, agreement.targetId);
    }
    final decidedTasks = draftingContext?.decidedTasks;
    if (decidedTasks != null) {
      for (final task in decidedTasks) {
        addCategory(task.categoryId);
      }
    }
    final draftBlocks = draftingContext?.baselinePlan?.data.plannedBlocks;
    if (draftBlocks != null) {
      for (final block in draftBlocks) {
        addCategory(block.categoryId);
      }
    }
    final refineBlocks = refineContext?.baselinePlan?.data.plannedBlocks;
    if (refineBlocks != null) {
      for (final block in refineBlocks) {
        addCategory(block.categoryId);
      }
    }
    return scopes;
  }

  /// Loads the coordinator's directive for [dayId], fail-soft: a read error
  /// degrades to "no directive" (the wake plans from its own day context)
  /// rather than killing the wake.
  Future<DayDirectiveEntity?> _directiveContext(String dayId) async {
    final service = directiveService;
    if (service == null) return null;
    try {
      return await service.directiveForDay(dayId);
    } catch (e, s) {
      _logError('failed to load day directive', error: e, stackTrace: s);
      return null;
    }
  }

  /// Renders the directive as the `<day_directive>` JSON body. Field order is
  /// fixed so the section is byte-stable within a revision.
  Map<String, Object?> _directiveToJson(DayDirectiveEntity directive) => {
    'directiveRevisionId': directive.directiveRevisionId,
    'issuedAt': directive.issuedAt.toIso8601String(),
    if (directive.commitments.isNotEmpty)
      'commitments': [
        for (final commitment in directive.commitments) commitment.toJson(),
      ],
    if (directive.capacityBudget != null)
      'capacityBudget': directive.capacityBudget!.toJson(),
    if (directive.carryOver.isNotEmpty)
      'carryOver': [for (final item in directive.carryOver) item.toJson()],
    if (directive.constraints.isNotEmpty) 'constraints': directive.constraints,
    if (directive.attentionNotes.isNotEmpty)
      'attentionNotes': directive.attentionNotes,
  };

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

  /// Cap on `<day_entries>` items rendered into the prompt — the ADR 0032
  /// §4 sizing of this slot as a bounded provenance/status index. The list
  /// is ascending by capture time, so the cap keeps the NEWEST entries.
  static const _dayEntriesLimit = 32;

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
    final budget = <String, Object?>{
      'availableMinutes': ?available,
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
