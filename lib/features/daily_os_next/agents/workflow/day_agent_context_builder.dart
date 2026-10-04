part of 'day_agent_workflow.dart';

/// Pure context-assembly helpers of [DayAgentWorkflow]: user-message
/// construction and the capture/drafting/refine context builders.
extension DayAgentContextBuilder on DayAgentWorkflow {
  /// Cap on `<day_entries>` items rendered into the prompt — the ADR 0032
  /// §4 sizing of this slot as a bounded provenance/status index. The list
  /// is ascending by capture time, so the cap keeps the NEWEST entries.
  static const _dayEntriesLimit = 32;

  Future<_TimeSensitiveDayAgentContext> _loadTimeSensitiveContext({
    required String agentId,
    required DailyOsPlannerWakeContext wakeContext,
    required DateTime planDate,
    required bool isDayTokenWake,
    required DayDirectiveEntity? directive,
    required RefineContext? refineContext,
    DateTime? initialSnapshotAt,
  }) async {
    // Time-sensitive context reads can themselves cross a planning boundary.
    // Build from one snapshot, then compare the pure day/window projection
    // after every await. If it changed, rebuild from the fresh instant before
    // rendering. The projection becomes permanently stable once the target
    // window is closed, so this converges without an arbitrary retry cap.
    var contextSnapshotAt = initialSnapshotAt ?? clock.now();
    while (true) {
      final digestContext = await _digestContext(
        agentId: agentId,
        wakeContext: wakeContext,
        dayDate: planDate,
        now: contextSnapshotAt,
        preloadedTodayDirective: directive,
      );
      final recentWeeksContext = await _recentWeeksContext(
        agentId: agentId,
        wakeContext: wakeContext,
        now: contextSnapshotAt,
      );
      final weekContext = isDayTokenWake
          ? await _weekContext(planDate: planDate, now: contextSnapshotAt)
          : null;

      final planningSnapshotAt = clock.now();
      final contextStayedCurrent =
          _timeSensitiveContextKey(
            planDate: planDate,
            now: contextSnapshotAt,
            refineContext: refineContext,
          ) ==
          _timeSensitiveContextKey(
            planDate: planDate,
            now: planningSnapshotAt,
            refineContext: refineContext,
          );
      if (contextStayedCurrent) {
        return (
          digestContext: digestContext,
          planningSnapshotAt: planningSnapshotAt,
          recentWeeksContext: recentWeeksContext,
          weekContext: weekContext,
        );
      }
      contextSnapshotAt = planningSnapshotAt;
    }
  }

  String _buildUserMessage({
    required String dayId,
    required DateTime planDate,
    required DateTime now,
    required Set<String> triggerTokens,
    required List<RecalledObservation> observations,
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
                    'createdAt': observation.at.toIso8601String(),
                    'text': observation.text,
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

  /// Loads the coordinator's durable knowledge without applying wall-clock
  /// staleness yet.
  ///
  /// Knowledge is always read under [dailyOsPlannerAgentId], not the waking
  /// agent: durable learning lives with the coordinator (ADR 0032 §4,
  /// "coordinator-published"), so per-day agents see the same knowledge the
  /// monolith would. For coordinator wakes the two ids coincide.
  Future<List<PlannerKnowledgeEntity>> _activeKnowledge() async {
    final service = knowledgeService;
    if (service == null) return const [];
    try {
      return await service.activeFor(dailyOsPlannerAgentId);
    } catch (e, s) {
      _logError(
        'failed to load durable planner knowledge',
        error: e,
        stackTrace: s,
      );
      return const [];
    }
  }

  /// Renders the two-tier knowledge prompt blocks against the final planning
  /// snapshot, after every asynchronous context read has completed.
  KnowledgeContext _knowledgeContext({
    required List<PlannerKnowledgeEntity> active,
    required Set<String> touchedScopes,
    required DateTime now,
  }) {
    if (active.isEmpty) return const KnowledgeContext.empty();
    return KnowledgeContext(
      hookIndex: renderKnowledgeHookIndex(active),
      statements: renderKnowledgeStatements(active, touchedScopes, now: now),
    );
  }

  /// The time-sensitive prompt context only needs rebuilding when an await
  /// crosses a boundary that changes day classification or the advertised
  /// planning window. Encoding the pure prompt projection keeps this check in
  /// lockstep with what the model actually sees.
  String _timeSensitiveContextKey({
    required DateTime planDate,
    required DateTime now,
    required RefineContext? refineContext,
  }) => jsonEncode({
    'localDay': localDay(now).toIso8601String(),
    'planningWindow': _planningWindowJson(
      planDate: planDate,
      now: now,
      refineBaseline: refineContext?.baselinePlan,
    ),
  });

  /// Whether the exact baseline echo that a closed window permits would omit
  /// trusted work selected after that baseline was written.
  ///
  /// Task-backed decisions use their stable task id. Standalone capture items
  /// and directive commitments have no dedicated block foreign key, so their
  /// current contract is the same one used by the eval: the baseline's active
  /// block prose must name the item/commitment. Directive evidence refs also
  /// count when they point at a task already represented by a block.
  bool _closedDraftOmitsTrustedWork({
    required DraftingContext? draftingContext,
    required DayDirectiveEntity? directive,
  }) {
    final activeBlocks =
        draftingContext?.baselinePlan?.data.plannedBlocks
            .where((block) => block.state != PlannedBlockState.dropped)
            .toList() ??
        const [];
    final representedTaskIds = {
      for (final block in activeBlocks)
        if (block.taskId != null) block.taskId!,
    };
    final planTokens = _semanticTokens(
      [
        for (final block in activeBlocks)
          [
            block.id,
            block.title,
            block.reason,
            block.note,
          ].whereType<String>().join(' '),
      ].join(' '),
    );

    bool named(String id, String title) {
      return _containsSemanticPhrase(planTokens, id) ||
          _containsSemanticPhrase(planTokens, title);
    }

    final omitsTask =
        draftingContext?.decidedTasks.any(
          (task) => !representedTaskIds.contains(task.id),
        ) ??
        false;
    final omitsCaptureItem =
        draftingContext?.decidedCaptureItems.any((item) {
          final matchedTaskId = item.matchedTaskId;
          return !((matchedTaskId != null &&
                  representedTaskIds.contains(matchedTaskId)) ||
              named(item.id, item.title));
        }) ??
        false;
    final omitsCommitment =
        directive?.commitments.any((commitment) {
          final representedByTask =
              representedTaskIds.contains(commitment.id) ||
              commitment.evidenceRefs.any(representedTaskIds.contains);
          return !(representedByTask || named(commitment.id, commitment.title));
        }) ??
        false;
    return omitsTask || omitsCaptureItem || omitsCommitment;
  }

  List<String> _semanticTokens(String value) => collapseToSingleLine(value)
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((token) => token.isNotEmpty)
      .toList();

  bool _containsSemanticPhrase(List<String> proseTokens, String phrase) {
    final phraseTokens = _semanticTokens(phrase);
    if (phraseTokens.isEmpty || phraseTokens.length > proseTokens.length) {
      return false;
    }
    for (
      var start = 0;
      start <= proseTokens.length - phraseTokens.length;
      start++
    ) {
      var matches = true;
      for (var offset = 0; offset < phraseTokens.length; offset++) {
        if (proseTokens[start + offset] != phraseTokens[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
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
}
