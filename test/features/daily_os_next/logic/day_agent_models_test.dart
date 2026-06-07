import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

void main() {
  group('CaptureId equality', () {
    test('identical instances and matching values are equal', () {
      const a = CaptureId('cap_1');
      const b = CaptureId('cap_1');
      const c = CaptureId('cap_2');

      // Identity (same instance) and structural equality both pass.
      expect(a, equals(a));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      // ignore: unrelated_type_equality_checks
      expect(a == 'cap_1', isFalse);
    });

    test('toString carries the inner value', () {
      const id = CaptureId('cap_show');
      expect(id.toString(), 'CaptureId(cap_show)');
    });
  });

  group('DayAgentCategory equality', () {
    test('matching id/name/colorHex compare equal', () {
      const a = DayAgentCategory(
        id: 'c1',
        name: 'Work',
        colorHex: 'AABBCC',
      );
      const b = DayAgentCategory(
        id: 'c1',
        name: 'Work',
        colorHex: 'AABBCC',
      );
      const differentColour = DayAgentCategory(
        id: 'c1',
        name: 'Work',
        colorHex: 'DDEEFF',
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == differentColour, isFalse);
      // operator == fast-rejects non-matching runtime types.
      // ignore: unrelated_type_equality_checks
      expect(a == 'c1', isFalse);
    });
  });

  group('DraftPlan.copyWith', () {
    DraftPlan basePlan() => DraftPlan(
      dayDate: DateTime(2026, 5, 25),
      blocks: const [],
      bands: const [],
      capacityMinutes: 480,
      scheduledMinutes: 0,
    );

    test('returns an identical plan when called with no overrides', () {
      final original = basePlan();
      final copy = original.copyWith();

      expect(copy.dayDate, original.dayDate);
      expect(copy.blocks, original.blocks);
      expect(copy.bands, original.bands);
      expect(copy.capacityMinutes, original.capacityMinutes);
      expect(copy.scheduledMinutes, original.scheduledMinutes);
      expect(copy.actualBlocks, original.actualBlocks);
      expect(copy.agendaItems, original.agendaItems);
      expect(copy.state, original.state);
    });

    test('replaces only the supplied fields and keeps the rest', () {
      final original = basePlan();
      final newDate = DateTime(2026, 6, 2);
      final newBlock = TimeBlock(
        id: 'b1',
        title: 'Focus',
        start: newDate,
        end: newDate.add(const Duration(hours: 1)),
        type: TimeBlockType.ai,
        state: TimeBlockState.drafted,
        category: const DayAgentCategory(
          id: 'c1',
          name: 'Work',
          colorHex: 'AABBCC',
        ),
      );
      final newBand = EnergyBand(
        start: newDate,
        end: newDate.add(const Duration(hours: 1)),
        level: EnergyLevel.high,
        label: 'HIGH',
      );
      const newAgenda = AgendaItem(
        id: 'agenda_1',
        title: 'Focus',
        category: DayAgentCategory(
          id: 'c1',
          name: 'Work',
          colorHex: 'AABBCC',
        ),
        linkedBlockIds: ['b1'],
      );

      final updated = original.copyWith(
        dayDate: newDate,
        blocks: [newBlock],
        bands: [newBand],
        capacityMinutes: 360,
        scheduledMinutes: 60,
        actualBlocks: [newBlock],
        agendaItems: const [newAgenda],
        state: DayState.committed,
      );

      expect(updated.dayDate, newDate);
      expect(updated.blocks, hasLength(1));
      expect(updated.bands, hasLength(1));
      expect(updated.capacityMinutes, 360);
      expect(updated.scheduledMinutes, 60);
      expect(updated.actualBlocks, hasLength(1));
      expect(updated.agendaItems, hasLength(1));
      expect(updated.state, DayState.committed);

      // The original is untouched (DraftPlan is immutable).
      expect(original.dayDate, DateTime(2026, 5, 25));
      expect(original.blocks, isEmpty);
      expect(original.state, DayState.drafted);
    });
  });

  test('TimeBlock.duration reflects end - start', () {
    final start = DateTime(2026, 5, 25, 9);
    final end = start.add(const Duration(minutes: 45));
    final block = TimeBlock(
      id: 'b1',
      title: 'Focus',
      start: start,
      end: end,
      type: TimeBlockType.ai,
      state: TimeBlockState.drafted,
      category: const DayAgentCategory(
        id: 'c1',
        name: 'Work',
        colorHex: 'AABBCC',
      ),
    );

    expect(block.duration, const Duration(minutes: 45));
  });

  group('TimeBlock.copyWith', () {
    final base = TimeBlock(
      id: 'b1',
      title: 'Original',
      start: DateTime(2026, 5, 25, 9),
      end: DateTime(2026, 5, 25, 10),
      type: TimeBlockType.ai,
      state: TimeBlockState.drafted,
      category: const DayAgentCategory(
        id: 'c1',
        name: 'Work',
        colorHex: '5ED4B7',
      ),
      taskId: 'task-1',
      reason: 'why',
      sessionIndex: 1,
      sessionTotal: 2,
      location: 'desk',
    );

    test('no arguments returns an equal-field copy', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.title, base.title);
      expect(copy.start, base.start);
      expect(copy.end, base.end);
      expect(copy.type, base.type);
      expect(copy.state, base.state);
      expect(copy.category, base.category);
      expect(copy.taskId, base.taskId);
      expect(copy.reason, base.reason);
      expect(copy.sessionIndex, base.sessionIndex);
      expect(copy.sessionTotal, base.sessionTotal);
      expect(copy.location, base.location);
    });

    test('every field can be overridden independently', () {
      const otherCategory = DayAgentCategory(
        id: 'c2',
        name: 'Life',
        colorHex: 'A855F7',
      );
      final copy = base.copyWith(
        id: 'b2',
        title: 'Renamed',
        start: DateTime(2026, 5, 25, 11),
        end: DateTime(2026, 5, 25, 12),
        type: TimeBlockType.manual,
        state: TimeBlockState.committed,
        category: otherCategory,
        taskId: 'task-2',
        reason: 'new why',
        sessionIndex: 2,
        sessionTotal: 3,
        location: 'cafe',
      );
      expect(copy.id, 'b2');
      expect(copy.title, 'Renamed');
      expect(copy.start, DateTime(2026, 5, 25, 11));
      expect(copy.end, DateTime(2026, 5, 25, 12));
      expect(copy.type, TimeBlockType.manual);
      expect(copy.state, TimeBlockState.committed);
      expect(copy.category, otherCategory);
      expect(copy.taskId, 'task-2');
      expect(copy.reason, 'new why');
      expect(copy.sessionIndex, 2);
      expect(copy.sessionTotal, 3);
      expect(copy.location, 'cafe');
      // The original is untouched.
      expect(base.title, 'Original');
    });
  });

  group('AgendaItem.copyWith', () {
    const base = AgendaItem(
      id: 'a1',
      title: 'Original',
      category: DayAgentCategory(id: 'c1', name: 'Work', colorHex: '5ED4B7'),
      linkedBlockIds: ['b1'],
      taskId: 'task-1',
      outcome: 'done looks like X',
      totalEstimateMinutes: 60,
      progress: 0.4,
      state: AgendaItemState.inProgress,
    );

    test('no arguments returns an equal-field copy', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.title, base.title);
      expect(copy.category, base.category);
      expect(copy.linkedBlockIds, base.linkedBlockIds);
      expect(copy.taskId, base.taskId);
      expect(copy.outcome, base.outcome);
      expect(copy.totalEstimateMinutes, base.totalEstimateMinutes);
      expect(copy.progress, base.progress);
      expect(copy.state, base.state);
    });

    test('every field can be overridden independently', () {
      const otherCategory = DayAgentCategory(
        id: 'c2',
        name: 'Life',
        colorHex: 'A855F7',
      );
      final copy = base.copyWith(
        id: 'a2',
        title: 'Renamed',
        category: otherCategory,
        linkedBlockIds: ['b2', 'b3'],
        taskId: 'task-2',
        outcome: 'new outcome',
        totalEstimateMinutes: 90,
        progress: 0.8,
        state: AgendaItemState.done,
      );
      expect(copy.id, 'a2');
      expect(copy.title, 'Renamed');
      expect(copy.category, otherCategory);
      expect(copy.linkedBlockIds, ['b2', 'b3']);
      expect(copy.taskId, 'task-2');
      expect(copy.outcome, 'new outcome');
      expect(copy.totalEstimateMinutes, 90);
      expect(copy.progress, 0.8);
      expect(copy.state, AgendaItemState.done);
    });
  });

  group('TimeBlockListTotals', () {
    TimeBlock block({
      required String id,
      required int minutes,
      TimeBlockState state = TimeBlockState.inProgress,
      String? taskId,
    }) {
      final start = DateTime(2026, 5, 25, 9);
      return TimeBlock(
        id: id,
        title: id,
        start: start,
        end: start.add(Duration(minutes: minutes)),
        type: TimeBlockType.manual,
        state: state,
        category: const DayAgentCategory(
          id: 'c1',
          name: 'Work',
          colorHex: '5ED4B7',
        ),
        taskId: taskId,
      );
    }

    test('totalMinutes sums durations; empty list is zero', () {
      expect(<TimeBlock>[].totalMinutes, 0);
      expect(
        [block(id: 'a', minutes: 90), block(id: 'b', minutes: 30)].totalMinutes,
        120,
      );
    });

    test(
      'completedCount counts only completed blocks, de-duplicated by task',
      () {
        final blocks = [
          // Two completed sessions on the same task -> one unit of done.
          block(
            id: 's1',
            minutes: 30,
            state: TimeBlockState.completed,
            taskId: 'task-1',
          ),
          block(
            id: 's2',
            minutes: 30,
            state: TimeBlockState.completed,
            taskId: 'task-1',
          ),
          // Completed standalone session counts by block id.
          block(id: 's3', minutes: 30, state: TimeBlockState.completed),
          // Not completed -> not counted.
          block(id: 's4', minutes: 30, taskId: 'task-2'),
        ];
        expect(blocks.completedCount, 2);
      },
    );
  });

  group('enum contracts — names and order are consumer-visible', () {
    // The UI and the mock agent switch over these enums by name/index;
    // a silent rename or reorder would only surface in consumer tests.
    test('every day-agent enum keeps its declared names in order', () {
      expect(
        AgendaItemState.values.map((e) => e.name),
        ['open', 'inProgress', 'overdue', 'done'],
      );
      expect(
        PlanDiffChangeKind.values.map((e) => e.name),
        ['moved', 'added', 'dropped'],
      );
      expect(
        PlanDiffChangeDecision.values.map((e) => e.name),
        ['pending', 'accepted', 'rejected'],
      );
      expect(
        LearningCardKind.values.map((e) => e.name),
        ['standard', 'nudge'],
      );
      expect(
        TaskCorpusState.values.map((e) => e.name),
        [
          'all',
          'inProgress',
          'overdue',
          'scheduled',
          'recurring',
          'backlog',
          'done',
        ],
      );
      expect(
        PendingItemReason.values.map((e) => e.name),
        ['overdue', 'inProgress', 'missedRecurring', 'dueToday'],
      );
      expect(
        TriageAction.values.map((e) => e.name),
        ['today', 'doNow', 'defer', 'done', 'drop'],
      );
      expect(
        CarryoverAction.values.map((e) => e.name),
        ['tomorrow', 'pickDate', 'drop'],
      );
      expect(ReflectionSource.values.map((e) => e.name), ['typed', 'voice']);
    });
  });

  group('value-object field contracts', () {
    const cat = DayAgentCategory(id: 'c1', name: 'Deep', colorHex: '3B82F6');

    test(
      'PendingItem: optionals default to null, reason-specific fields land',
      () {
        const minimal = PendingItem(
          taskId: 't1',
          title: 'Fix flaky test',
          category: cat,
          reason: PendingItemReason.dueToday,
        );
        expect(minimal.note, isNull);
        expect(minimal.overdueByDays, isNull);
        expect(minimal.sessionCount, isNull);
        expect(minimal.referenceDate, isNull);

        final overdue = PendingItem(
          taskId: 't2',
          title: 'Pay invoice',
          category: cat,
          reason: PendingItemReason.overdue,
          overdueByDays: 3,
          note: 'Last skipped Thursday',
          referenceDate: DateTime(2024, 3, 15),
        );
        expect(overdue.overdueByDays, 3);
        expect(overdue.note, 'Last skipped Thursday');
        expect(overdue.referenceDate, DateTime(2024, 3, 15));
      },
    );

    test('TriageResult: deferredTo only accompanies the defer action', () {
      const done = TriageResult(taskId: 't1', action: TriageAction.done);
      expect(done.deferredTo, isNull);

      final deferred = TriageResult(
        taskId: 't1',
        action: TriageAction.defer,
        deferredTo: DateTime(2024, 3, 18),
      );
      expect(deferred.action, TriageAction.defer);
      expect(deferred.deferredTo, DateTime(2024, 3, 18));
    });

    test('ParsedItem: matched-task and anchor optionals land verbatim', () {
      const minimal = ParsedItem(
        id: 'p1',
        kind: ParsedItemKind.newTask,
        title: 'Buy paint',
        category: cat,
        confidence: ParsedItemConfidence.high,
      );
      expect(minimal.matchedTaskId, isNull);
      expect(minimal.timeAnchor, isNull);
      expect(minimal.proposedUpdate, isNull);

      const matched = ParsedItem(
        id: 'p2',
        kind: ParsedItemKind.matched,
        title: 'Deck progress',
        category: cat,
        confidence: ParsedItemConfidence.medium,
        spokenPhrase: 'paint the deck before lunch',
        matchedTaskId: 'task-9',
        matchedTaskTitle: 'Paint the deck',
        timeAnchor: 'before 11am',
        proposedUpdate: 'Set estimate to 90m',
      );
      expect(matched.matchedTaskId, 'task-9');
      expect(matched.spokenPhrase, 'paint the deck before lunch');
      expect(matched.timeAnchor, 'before 11am');
      expect(matched.proposedUpdate, 'Set estimate to 90m');
    });

    test('PlanDiff carries its changes and the post-apply plan', () {
      final updated = DraftPlan(
        dayDate: DateTime(2024, 3, 15),
        blocks: const [],
        bands: const [],
        capacityMinutes: 480,
        scheduledMinutes: 60,
      );
      final diff = PlanDiff(
        id: 'd1',
        transcript: 'move the gym',
        changes: const [],
        updatedPlan: updated,
      );
      expect(diff.updatedPlan.scheduledMinutes, 60);
      expect(diff.changes, isEmpty);
      expect(diff.transcript, 'move the gym');
    });

    test('Shutdown models: metrics, completed/carryover items, note', () {
      const metrics = ShutdownMetrics(
        focusMinutes: 240,
        flowSessions: 3,
        contextSwitches: 12,
        contextSwitchesWeekAvg: 15.5,
        energyScore: 7.5,
        energyDeltaVsWeek: 0.5,
      );
      expect(metrics.focusMinutes, 240);
      expect(metrics.energyDeltaVsWeek, 0.5);

      const completedItem = CompletedItem(
        taskId: 't1',
        title: 'Ship release',
        category: cat,
        durationMinutes: 90,
      );
      expect(completedItem.note, isNull);
      expect(completedItem.durationMinutes, 90);

      const carryover = CarryoverItem(
        taskId: 't2',
        title: 'Write docs',
        category: cat,
        reason: 'Ran out of time — started, 40m in',
        suggestedTarget: '→ tomorrow morning',
      );
      expect(carryover.suggestedTarget, '→ tomorrow morning');

      const note = TomorrowNote(body: 'Start with the deck.', maturity: 2);
      expect(note.maturity, inInclusiveRange(1, 3));
      expect(note.body, isNotEmpty);
    });
  });
}
