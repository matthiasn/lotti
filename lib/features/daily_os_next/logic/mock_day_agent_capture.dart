part of 'mock_day_agent.dart';

mixin _MockDayAgentCapture on _MockDayAgentBase {
  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
    String? audioId,
  }) async {
    await Future<void>.delayed(parseLatency);
    _captureSeq++;
    return CaptureId('mock_capture_$_captureSeq');
  }

  @override
  Future<DraftPlan?> currentPlanForDate(DateTime date) async => null;

  @override
  Future<bool> deletePlanForDate(DateTime date) async => true;

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
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    // ignored: mock returns immediately, has no poll loop to cancel.
    bool Function()? isCancelled,
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
        .where((b) => b.state != TimeBlockState.dropped)
        .fold<int>(0, (acc, b) => acc + b.duration.inMinutes);

    final actualBlocks = <TimeBlock>[
      TimeBlock(
        id: 'a_deck_review',
        title: 'Deck review — Q2 leadership update',
        start: at(8, 35),
        end: at(10, 10),
        type: TimeBlockType.manual,
        state: TimeBlockState.completed,
        category: _work,
        taskId: 't_deck_review',
      ),
      TimeBlock(
        id: 'a_morning_run',
        title: 'Morning run · 5km',
        start: at(12, 5),
        end: at(12, 33),
        type: TimeBlockType.manual,
        state: TimeBlockState.completed,
        category: _health,
        taskId: 't_morning_run',
      ),
      TimeBlock(
        id: 'a_onboarding',
        title: 'Finish the Onboarding doc',
        start: at(15, 35),
        end: at(16, 15),
        type: TimeBlockType.manual,
        state: TimeBlockState.inProgress,
        category: _work,
        taskId: 't_onboarding_doc',
      ),
    ];

    return DraftPlan(
      dayDate: start,
      blocks: allBlocks,
      actualBlocks: actualBlocks,
      bands: bands,
      capacityMinutes: 480,
      scheduledMinutes: scheduled,
      agendaItems: _agendaFor(allBlocks),
    );
  }
}
