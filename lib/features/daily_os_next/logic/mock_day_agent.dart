import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

/// Scripted [DayAgentInterface] for the Capture + Reconcile preview.
///
/// Replaces the real `DayAgentWorkflow` until the agentic backend
/// described in `docs/implementation_plans/2026-05-25_day_agent_layer.md`
/// ships. Returns a stable, demoable shape so the UI work can land
/// independently. Every call carries an artificial latency so the
/// loading states render in real conditions.
///
/// The mock keeps its own in-memory "broken link" tracker so the
/// `breakCaptureLink` action visibly mutates the returned parsed
/// items across calls.
class MockDayAgent implements DayAgentInterface {
  MockDayAgent({
    this.parseLatency = const Duration(milliseconds: 220),
    this.pendingLatency = const Duration(milliseconds: 180),
    this.triageLatency = const Duration(milliseconds: 120),
    this.draftLatency = const Duration(milliseconds: 400),
    this.summarizeLatency = const Duration(milliseconds: 120),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration parseLatency;
  final Duration pendingLatency;
  final Duration triageLatency;
  final Duration draftLatency;
  final Duration summarizeLatency;
  final DateTime Function() _clock;

  static const _work = DayAgentCategory(
    id: 'cat_work',
    name: 'Work',
    colorHex: '5ED4B7',
  );
  static const _health = DayAgentCategory(
    id: 'cat_health',
    name: 'Health',
    colorHex: '7AB889',
  );
  static const _meals = DayAgentCategory(
    id: 'cat_meals',
    name: 'Meals',
    colorHex: '4AB6E8',
  );
  static const _study = DayAgentCategory(
    id: 'cat_study',
    name: 'Study',
    colorHex: 'FBA336',
  );

  int _captureSeq = 0;

  /// Items that have had their link broken in this session — keyed
  /// by parsed-item id. Subsequent `parseCaptureToItems` calls
  /// rebuild the same list with those entries downgraded to NEW.
  final Set<String> _brokenLinks = <String>{};

  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
  }) async {
    await Future<void>.delayed(parseLatency);
    _captureSeq++;
    return CaptureId('mock_capture_$_captureSeq');
  }

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async {
    await Future<void>.delayed(parseLatency);
    const items = <ParsedItem>[
      ParsedItem(
        id: 'p_deck_review',
        kind: ParsedItemKind.matched,
        title: 'Send the leadership deck to Sarah',
        category: _work,
        confidence: ParsedItemConfidence.high,
        spokenPhrase: 'send the deck to Sarah',
        matchedTaskId: 't_deck_review',
        matchedTaskTitle: 'Deck review — Q2 leadership update',
        matchedTaskState: 'In progress · 2 sessions',
        estimateMinutes: 60,
      ),
      ParsedItem(
        id: 'p_invoices',
        kind: ParsedItemKind.newTask,
        title: 'Review outstanding invoices',
        category: _work,
        confidence: ParsedItemConfidence.high,
        estimateMinutes: 45,
        timeAnchor: 'before 11am',
      ),
      ParsedItem(
        id: 'p_call_mom',
        kind: ParsedItemKind.newTask,
        title: 'Call mom re: Sunday',
        category: _meals,
        // Medium = parser is uncertain enough to surface the
        // warning tag on the foot row. Low would mean "confidently
        // a new task" and would suppress the warning.
        confidence: ParsedItemConfidence.medium,
        estimateMinutes: 15,
      ),
      ParsedItem(
        id: 'p_run_done',
        kind: ParsedItemKind.update,
        title: 'Morning run',
        category: _health,
        confidence: ParsedItemConfidence.high,
        spokenPhrase: 'did my run already',
        matchedTaskId: 't_morning_run',
        matchedTaskTitle: 'Morning run · 5km',
        matchedTaskState: 'Recurring · daily',
        proposedUpdate: 'Mark done for today',
      ),
    ];

    if (_brokenLinks.isEmpty) return items;
    return [
      for (final item in items)
        if (_brokenLinks.contains(item.id))
          ParsedItem(
            id: item.id,
            kind: ParsedItemKind.newTask,
            title: item.matchedTaskTitle ?? item.title,
            category: item.category,
            confidence: item.confidence,
            estimateMinutes: item.estimateMinutes,
            timeAnchor: item.timeAnchor,
          )
        else
          item,
    ];
  }

  @override
  Future<List<PendingItem>> surfacePendingDecisions({
    DateTime? forDate,
  }) async {
    await Future<void>.delayed(pendingLatency);
    return const [
      PendingItem(
        taskId: 't_onboarding_doc',
        title: 'Finish the Onboarding doc',
        category: _work,
        reason: PendingItemReason.inProgress,
        note: 'Started Wednesday, 40m in',
        sessionCount: 1,
      ),
      PendingItem(
        taskId: 't_dentist',
        title: 'Reschedule dentist',
        category: _health,
        reason: PendingItemReason.overdue,
        note: 'Was due Monday',
        overdueByDays: 3,
      ),
      PendingItem(
        taskId: 't_dnd_book',
        title: 'Read 30 pages',
        category: _study,
        reason: PendingItemReason.missedRecurring,
        note: 'Last skipped Thursday',
      ),
    ];
  }

  @override
  Future<ParsedItem> breakCaptureLink(String parsedItemId) async {
    await Future<void>.delayed(triageLatency);
    _brokenLinks.add(parsedItemId);
    final list = await parseCaptureToItems(const CaptureId('mock_capture'));
    return list.firstWhere(
      (item) => item.id == parsedItemId,
      orElse: () => throw StateError(
        'Mock day agent: parsed item $parsedItemId is no longer in the '
        'scripted list. This should not happen in tests.',
      ),
    );
  }

  @override
  Future<TriageResult> applyTriage({
    required String taskId,
    required TriageAction action,
    DateTime? deferTo,
  }) async {
    await Future<void>.delayed(triageLatency);
    return TriageResult(
      taskId: taskId,
      action: action,
      deferredTo: action == TriageAction.defer
          ? (deferTo ?? _clock().add(const Duration(days: 1)))
          : null,
    );
  }

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<TimeBlock> calendarBlocks = const [],
  }) async {
    await Future<void>.delayed(draftLatency);
    final start = DateTime(dayDate.year, dayDate.month, dayDate.day);
    DateTime at(int hour, int minute) =>
        start.add(Duration(hours: hour, minutes: minute));

    final blocks = <TimeBlock>[
      TimeBlock(
        id: 'b_deep_work',
        title: 'Send the leadership deck to Sarah',
        start: at(8, 30),
        end: at(10, 30),
        type: TimeBlockType.ai,
        state: TimeBlockState.drafted,
        category: _work,
        taskId: 't_deck_review',
        reason:
            'Your deepest focus runs 8:30–10:30. Pulling this in before '
            'the 11am ping from Sarah.',
        sessionIndex: 3,
        sessionTotal: 4,
      ),
      TimeBlock(
        id: 'b_invoices',
        title: 'Review outstanding invoices',
        start: at(10, 45),
        end: at(11, 30),
        type: TimeBlockType.ai,
        state: TimeBlockState.drafted,
        category: _work,
        reason:
            'You said "before eleven" — sliding right after the deck '
            'with a 15-min buffer.',
      ),
      TimeBlock(
        id: 'b_buffer_lunch',
        title: 'Buffer',
        start: at(11, 30),
        end: at(12, 30),
        type: TimeBlockType.buffer,
        state: TimeBlockState.drafted,
        category: _buffer,
      ),
      TimeBlock(
        id: 'b_team_sync',
        title: 'Team sync — pricing',
        start: at(13, 0),
        end: at(13, 30),
        type: TimeBlockType.cal,
        state: TimeBlockState.committed,
        category: _work,
      ),
      TimeBlock(
        id: 'b_run_review',
        title: 'Onboarding doc — second wind',
        start: at(15, 30),
        end: at(16, 30),
        type: TimeBlockType.ai,
        state: TimeBlockState.drafted,
        category: _work,
        taskId: 't_onboarding_doc',
        reason:
            'You started this on Wednesday and stopped 40m in. Placing it '
            'in your 3pm second-wind window.',
      ),
    ];

    final allBlocks = [...calendarBlocks, ...blocks]
      ..sort((a, b) => a.start.compareTo(b.start));

    final bands = [
      EnergyBand(
        start: at(7, 0),
        end: at(10, 30),
        level: EnergyLevel.high,
        label: 'HIGH ENERGY',
      ),
      EnergyBand(
        start: at(13, 0),
        end: at(15, 0),
        level: EnergyLevel.low,
        label: 'LOW ENERGY',
      ),
      EnergyBand(
        start: at(15, 0),
        end: at(17, 0),
        level: EnergyLevel.secondWind,
        label: 'SECOND WIND',
      ),
    ];

    final scheduled = allBlocks
        .where((b) => b.type != TimeBlockType.buffer)
        .fold<int>(0, (acc, b) => acc + b.duration.inMinutes);

    return DraftPlan(
      dayDate: start,
      blocks: allBlocks,
      bands: bands,
      capacityMinutes: 480,
      scheduledMinutes: scheduled,
      agendaItems: _agendaFor(allBlocks),
    );
  }

  /// Roll the placed blocks up into one [AgendaItem] per task. Blocks
  /// without a taskId (buffers, calendar events) are not surfaced on
  /// the Agenda — that screen is intent-first.
  List<AgendaItem> _agendaFor(List<TimeBlock> blocks) {
    final byTask = <String, List<TimeBlock>>{};
    for (final block in blocks) {
      final id = block.taskId;
      if (id == null) continue;
      byTask.putIfAbsent(id, () => <TimeBlock>[]).add(block);
    }

    AgendaItem buildItem(String taskId, List<TimeBlock> linked) {
      final outcome = _scriptedOutcome(taskId);
      final estimate = linked.fold<int>(
        0,
        (acc, b) => acc + b.duration.inMinutes,
      );
      final state = linked.any((b) => b.state == TimeBlockState.inProgress)
          ? AgendaItemState.inProgress
          : AgendaItemState.open;
      return AgendaItem(
        id: 'agenda_$taskId',
        taskId: taskId,
        title: linked.first.title,
        category: linked.first.category,
        linkedBlockIds: linked.map((b) => b.id).toList(),
        outcome: outcome,
        totalEstimateMinutes: estimate,
        progress: _scriptedProgress(taskId),
        state: state,
      );
    }

    return byTask.entries
        .map((entry) => buildItem(entry.key, entry.value))
        .toList();
  }

  String? _scriptedOutcome(String taskId) {
    switch (taskId) {
      case 't_deck_review':
        return 'Deck reviewed by Sarah, sent to leadership.';
      case 't_onboarding_doc':
        return 'Onboarding doc back on track — picked up where you left off.';
      case 't_morning_run':
        return '5 km logged before the day starts.';
    }
    return null;
  }

  double? _scriptedProgress(String taskId) {
    switch (taskId) {
      case 't_onboarding_doc':
        return 0.4;
      case 't_deck_review':
        return 0.6;
    }
    return null;
  }

  int _diffSeq = 0;

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
  }) async {
    await Future<void>.delayed(draftLatency);
    _diffSeq++;

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
      category: _buffer,
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
        .where((b) => b.type != TimeBlockType.buffer)
        .fold<int>(0, (acc, b) => acc + b.duration.inMinutes);

    final updatedPlan = currentPlan.copyWith(
      blocks: updatedBlocks,
      scheduledMinutes: scheduled,
      agendaItems: _agendaFor(updatedBlocks),
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
          category: _buffer,
          reason: 'Protects recovery time after lunch.',
          affectedBlockId: addedBuffer.id,
          toStart: addedBuffer.start,
          toEnd: addedBuffer.end,
        ),
      ],
      updatedPlan: updatedPlan,
    );
  }

  @override
  Future<DraftPlan> acceptDiff(PlanDiff diff) async {
    await Future<void>.delayed(triageLatency);
    return diff.updatedPlan;
  }

  @override
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
  }) async {
    await Future<void>.delayed(triageLatency);
    return originalPlan;
  }

  @override
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

  @override
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

  @override
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
          category: _work,
          durationMinutes: 95,
          note: 'Two focus sessions, draft sent to Sarah.',
        ),
        CompletedItem(
          taskId: 't_morning_run',
          title: 'Morning run · 5km',
          category: _health,
          durationMinutes: 28,
        ),
      ],
      carryover: const [
        CarryoverItem(
          taskId: 't_onboarding_doc',
          title: 'Finish the Onboarding doc',
          category: _work,
          reason: 'Ran out of time — started, 40m in.',
          suggestedTarget: '→ tomorrow morning',
        ),
        CarryoverItem(
          taskId: 't_invoices',
          title: 'Review outstanding invoices',
          category: _work,
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

  @override
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
    required ReflectionSource source,
  }) async {
    await Future<void>.delayed(triageLatency);
  }

  @override
  Future<void> recordCarryoverDecision({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) async {
    await Future<void>.delayed(triageLatency);
  }

  @override
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

  @override
  Future<List<TaskCorpusItem>> surfaceTaskCorpus({
    TaskCorpusState stateFilter = TaskCorpusState.all,
    String? categoryId,
    String? query,
  }) async {
    await Future<void>.delayed(pendingLatency);
    const all = <TaskCorpusItem>[
      TaskCorpusItem(
        id: 't_deck_review',
        title: 'Deck review — Q2 leadership update',
        category: _work,
        state: TaskCorpusState.inProgress,
        updatedLabel: 'today',
      ),
      TaskCorpusItem(
        id: 't_onboarding_doc',
        title: 'Finish the Onboarding doc',
        category: _work,
        state: TaskCorpusState.inProgress,
        updatedLabel: 'yesterday',
      ),
      TaskCorpusItem(
        id: 't_dentist',
        title: 'Reschedule dentist',
        category: _health,
        state: TaskCorpusState.overdue,
        updatedLabel: '3 days ago',
      ),
      TaskCorpusItem(
        id: 't_invoices',
        title: 'Review outstanding invoices',
        category: _work,
        state: TaskCorpusState.scheduled,
        updatedLabel: 'today',
      ),
      TaskCorpusItem(
        id: 't_dnd_book',
        title: 'Read 30 pages',
        category: _study,
        state: TaskCorpusState.recurring,
        updatedLabel: 'May 18',
      ),
      TaskCorpusItem(
        id: 't_sunday_call',
        title: 'Call mom re: Sunday',
        category: _meals,
        state: TaskCorpusState.backlog,
        updatedLabel: '2 weeks ago',
      ),
      TaskCorpusItem(
        id: 't_morning_run_done',
        title: 'Morning run · 5km',
        category: _health,
        state: TaskCorpusState.done,
        updatedLabel: 'today',
      ),
    ];
    return [
      for (final item in all)
        if (_matchesFilter(item, stateFilter, categoryId, query)) item,
    ];
  }

  bool _matchesFilter(
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

const DayAgentCategory _buffer = DayAgentCategory(
  id: 'cat_buffer',
  name: 'Buffer',
  colorHex: '8E8E8E',
);
