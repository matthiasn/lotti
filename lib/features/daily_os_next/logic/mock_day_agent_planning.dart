import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent_fixtures.dart';

/// Scripted planning/refine/shutdown half of `MockDayAgent`.
///
/// Owns the plan-diff sequence counter and the pure corpus-filter
/// predicate so the facade can stay a thin delegator.
class MockDayAgentPlanning {
  /// Creates the planning collaborator.
  MockDayAgentPlanning({
    required this.draftLatency,
    required this.triageLatency,
    required this.summarizeLatency,
    required this.pendingLatency,
  });

  /// Latency applied to plan-drafting/refine calls.
  final Duration draftLatency;

  /// Latency applied to triage-shaped (accept/revert/commit/rename) calls.
  final Duration triageLatency;

  /// Latency applied to summarize/shutdown calls.
  final Duration summarizeLatency;

  /// Latency applied to corpus-browse calls.
  final Duration pendingLatency;

  int _diffSeq = 0;

  /// Tool: `propose_plan_diff`.
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
    // ignored: mock returns immediately, has no poll loop to cancel.
    bool Function()? isCancelled,
  }) async {
    await Future<void>.delayed(draftLatency);
    _diffSeq++;

    // No blocks → no meaningful scripted reshape; return an empty diff
    // instead of crashing on `currentPlan.blocks.first`. The Refine
    // controller treats an empty diff as immediately resolved, so the
    // UI cleanly bounces back to idle.
    if (currentPlan.blocks.isEmpty) {
      return PlanDiff(
        id: 'diff_$_diffSeq',
        transcript: voiceTranscript,
        changes: const [],
        updatedPlan: currentPlan,
      );
    }

    // Find the deep-work block and slide it 30 minutes earlier; drop
    // the second-wind onboarding block; add a buffer at 4 pm. This is
    // a scripted reshape — the real agent will derive these from the
    // transcript.
    final deck = currentPlan.blocks.firstWhere(
      (b) => b.id == 'b_deep_work',
      orElse: () => currentPlan.blocks.first,
    );
    final onboarding = currentPlan.blocks.firstWhere(
      (b) => b.id == 'b_run_review',
      orElse: () => currentPlan.blocks.last,
    );

    final movedDeck = TimeBlock(
      id: deck.id,
      title: deck.title,
      start: deck.start.subtract(const Duration(minutes: 30)),
      end: deck.end.subtract(const Duration(minutes: 30)),
      type: deck.type,
      state: deck.state,
      category: deck.category,
      taskId: deck.taskId,
      reason: 'Moved earlier to clear afternoon for the new buffer.',
      sessionIndex: deck.sessionIndex,
      sessionTotal: deck.sessionTotal,
      location: deck.location,
    );

    final addedBuffer = TimeBlock(
      id: 'b_buffer_pm',
      title: 'Buffer',
      start: onboarding.start.add(const Duration(hours: 1)),
      end: onboarding.start.add(const Duration(hours: 2)),
      type: TimeBlockType.buffer,
      state: TimeBlockState.drafted,
      category: mockBufferCategory,
    );

    final updatedBlocks =
        [
          for (final block in currentPlan.blocks)
            if (block.id == deck.id)
              movedDeck
            else if (block.id == onboarding.id)
              null
            else
              block,
          addedBuffer,
        ].whereType<TimeBlock>().toList()..sort(
          (a, b) => a.start.compareTo(b.start),
        );

    final scheduled = updatedBlocks
        .where((b) => b.state != TimeBlockState.dropped)
        .fold<int>(0, (acc, b) => acc + b.duration.inMinutes);

    final updatedPlan = currentPlan.copyWith(
      blocks: updatedBlocks,
      scheduledMinutes: scheduled,
      agendaItems: agendaFor(updatedBlocks),
    );

    return PlanDiff(
      id: 'diff_$_diffSeq',
      transcript: voiceTranscript,
      changes: [
        PlanDiffChange(
          id: 'c_moved_deck',
          kind: PlanDiffChangeKind.moved,
          title: deck.title,
          category: deck.category,
          reason: 'Earlier start matches your high-energy window.',
          affectedBlockId: deck.id,
          fromStart: deck.start,
          fromEnd: deck.end,
          toStart: movedDeck.start,
          toEnd: movedDeck.end,
        ),
        PlanDiffChange(
          id: 'c_dropped_onboarding',
          kind: PlanDiffChangeKind.dropped,
          title: onboarding.title,
          category: onboarding.category,
          reason: 'Dropped per your "skip onboarding" request.',
          affectedBlockId: onboarding.id,
          fromStart: onboarding.start,
          fromEnd: onboarding.end,
        ),
        PlanDiffChange(
          id: 'c_added_buffer',
          kind: PlanDiffChangeKind.added,
          title: 'Afternoon buffer',
          category: mockBufferCategory,
          reason: 'Protects recovery time after lunch.',
          affectedBlockId: addedBuffer.id,
          toStart: addedBuffer.start,
          toEnd: addedBuffer.end,
        ),
      ],
      updatedPlan: updatedPlan,
    );
  }

  // [itemIndices] is intentionally ignored here. The scripted mock has no
  // "diff baseline" to splice individual changes against (the real
  // adapter rebuilds plans from the persisted change set), so it returns
  // the post-accept plan in full regardless of selection. Tests that
  // need to assert partial-accept semantics override these methods on a
  // local subclass (see `_RecordingRefineAgent` in
  // refine_controller_test.dart).
  /// User verdict: apply the proposed [diff].
  Future<DraftPlan> acceptDiff(
    PlanDiff diff, {
    List<int>? itemIndices,
  }) async {
    await Future<void>.delayed(triageLatency);
    return diff.updatedPlan;
  }

  /// User verdict: discard the proposed [diff].
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
    List<int>? itemIndices,
  }) async {
    await Future<void>.delayed(triageLatency);
    return originalPlan;
  }

  /// Tool: `summarize_recent_patterns`.
  Future<List<LearningCard>> summarizeRecentPatterns({
    required DateTime asOf,
    int lookbackDays = 7,
  }) async {
    await Future<void>.delayed(summarizeLatency);
    return const [
      LearningCard(
        id: 'l_yesterday',
        overline: 'YESTERDAY',
        summary: 'Strong morning, distracted afternoon.',
        bullets: [
          LearningBullet(
            text: '2h 40m of focus before 11am — your best of the week.',
            tone: LearningBulletTone.positive,
          ),
          LearningBullet(
            text: 'Three context switches between 2 and 4pm.',
            tone: LearningBulletTone.warning,
          ),
          LearningBullet(
            text: 'Workout moved to evening (again).',
            tone: LearningBulletTone.info,
          ),
        ],
      ),
      LearningCard(
        id: 'l_week',
        overline: 'THIS WEEK SO FAR',
        summary: 'Mornings holding, afternoons slipping.',
        bullets: [
          LearningBullet(
            text: 'Deep work earlier · 3 days running.',
            tone: LearningBulletTone.positive,
          ),
          LearningBullet(
            text: 'Onboarding doc carried over twice.',
            tone: LearningBulletTone.warning,
          ),
          LearningBullet(
            text: 'You shipped 4 of the 5 items you committed to.',
            tone: LearningBulletTone.positive,
          ),
        ],
      ),
      LearningCard(
        id: 'l_nudge',
        overline: 'GENTLE NUDGE',
        summary:
            'You pushed deep work later three days running. '
            'Protect mornings today?',
        bullets: [],
        kind: LearningCardKind.nudge,
      ),
    ];
  }

  /// User verdict: commit [plan].
  Future<DraftPlan> commitDay(DraftPlan plan) async {
    await Future<void>.delayed(triageLatency);
    return plan.copyWith(
      state: DayState.committed,
      blocks: [
        for (final block in plan.blocks)
          // Drafted blocks read as solid after commit; cal events and
          // already-committed blocks stay where they are.
          if (block.state == TimeBlockState.drafted)
            TimeBlock(
              id: block.id,
              title: block.title,
              start: block.start,
              end: block.end,
              type: block.type,
              state: TimeBlockState.committed,
              category: block.category,
              taskId: block.taskId,
              reason: block.reason,
              sessionIndex: block.sessionIndex,
              sessionTotal: block.sessionTotal,
              location: block.location,
            )
          else
            block,
      ],
    );
  }

  /// Renames a standalone block in place.
  Future<DraftPlan> renameBlock({
    required DraftPlan plan,
    required String blockId,
    required String title,
  }) async {
    await Future<void>.delayed(triageLatency);
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw StateError('Block title must not be blank.');
    }
    final block = plan.blocks.where((b) => b.id == blockId).firstOrNull;
    if (block == null) {
      throw StateError('No block $blockId on the plan for ${plan.dayDate}.');
    }
    if (block.taskId != null && block.taskId!.isNotEmpty) {
      throw StateError(
        'Block $blockId is task-linked — rename the task instead.',
      );
    }
    return plan.copyWith(
      blocks: [
        for (final b in plan.blocks)
          if (b.id == blockId) b.copyWith(title: trimmedTitle) else b,
      ],
      agendaItems: [
        for (final item in plan.agendaItems)
          if (item.taskId == null && item.linkedBlockIds.contains(blockId))
            item.copyWith(title: trimmedTitle)
          else
            item,
      ],
    );
  }

  /// Tool: `surface_shutdown_data`.
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) async {
    await Future<void>.delayed(summarizeLatency);
    return (
      completed: const [
        CompletedItem(
          taskId: 't_deck_review',
          title: 'Deck review — Q2 leadership update',
          category: mockWorkCategory,
          durationMinutes: 95,
          note: 'Two focus sessions, draft sent to Sarah.',
        ),
        CompletedItem(
          taskId: 't_morning_run',
          title: 'Morning run · 5km',
          category: mockHealthCategory,
          durationMinutes: 28,
        ),
      ],
      carryover: const [
        CarryoverItem(
          taskId: 't_onboarding_doc',
          title: 'Finish the Onboarding doc',
          category: mockWorkCategory,
          reason: 'Ran out of time — started, 40m in.',
          suggestedTarget: '→ tomorrow morning',
        ),
        CarryoverItem(
          taskId: 't_invoices',
          title: 'Review outstanding invoices',
          category: mockWorkCategory,
          reason: 'Skipped — afternoon ran long.',
          suggestedTarget: '→ tomorrow afternoon',
        ),
      ],
      metrics: const ShutdownMetrics(
        focusMinutes: 215,
        flowSessions: 3,
        contextSwitches: 5,
        contextSwitchesWeekAvg: 8,
        energyScore: 7.4,
        energyDeltaVsWeek: 0.6,
      ),
    );
  }

  /// Tool: `record_reflection`.
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
    required ReflectionSource source,
  }) async {
    await Future<void>.delayed(triageLatency);
  }

  /// Tool: `record_carryover_decision`.
  Future<void> recordCarryoverDecision({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) async {
    await Future<void>.delayed(triageLatency);
  }

  /// Tool: `generate_tomorrow_note`.
  Future<TomorrowNote> generateTomorrowNote({
    required DateTime forDate,
  }) async {
    await Future<void>.delayed(summarizeLatency);
    return const TomorrowNote(
      body:
          "You started the Onboarding doc and stopped 40m in. I'll start "
          'the draft with it placed in your morning, alongside the '
          'carryover, and ask if you want to keep that.',
      maturity: 1,
    );
  }

  /// Tool: `surface_task_corpus`.
  Future<List<TaskCorpusItem>> surfaceTaskCorpus({
    TaskCorpusState stateFilter = TaskCorpusState.all,
    String? categoryId,
    String? query,
  }) async {
    await Future<void>.delayed(pendingLatency);
    const all = scriptedTaskCorpus;
    return [
      for (final item in all)
        if (matchesFilter(item, stateFilter, categoryId, query)) item,
    ];
  }

  /// Pure corpus-filter predicate. Exposed for the facade's
  /// `debugMatchesFilter` test seam.
  bool matchesFilter(
    TaskCorpusItem item,
    TaskCorpusState state,
    String? categoryId,
    String? query,
  ) {
    if (state != TaskCorpusState.all && item.state != state) return false;
    if (categoryId != null && item.category.id != categoryId) return false;
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      if (!item.title.toLowerCase().contains(q)) return false;
    }
    return true;
  }
}
