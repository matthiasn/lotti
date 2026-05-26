import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';

void main() {
  group('MockDayAgent', () {
    late MockDayAgent agent;

    setUp(() {
      agent = MockDayAgent(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );
    });

    test('submitCapture returns a fresh, monotonic capture id', () async {
      final first = await agent.submitCapture(
        transcript: 'hello world',
        capturedAt: DateTime(2026, 5, 25, 9),
      );
      final second = await agent.submitCapture(
        transcript: 'another one',
        capturedAt: DateTime(2026, 5, 25, 9, 1),
      );
      expect(first, isNot(equals(second)));
      expect(first.value, contains('mock_capture_'));
    });

    test('parseCaptureToItems exposes all four scripted variants', () async {
      final items = await agent.parseCaptureToItems(const CaptureId('x'));
      expect(items, hasLength(4));
      final kinds = items.map((i) => i.kind).toList();
      expect(kinds, contains(ParsedItemKind.matched));
      expect(kinds, contains(ParsedItemKind.newTask));
      expect(kinds, contains(ParsedItemKind.update));
      // The medium-confidence variant should be present so the UI
      // can exercise the warning tag (medium = parser is uncertain,
      // low = confidently new and no warning).
      expect(
        items.any((i) => i.confidence == ParsedItemConfidence.medium),
        isTrue,
      );
      // A time-anchor variant should be present so the UI can render
      // the warning-tinted constraint chip.
      expect(items.any((i) => i.timeAnchor != null), isTrue);
    });

    test('breakCaptureLink downgrades a matched item to a NEW card', () async {
      final initial = await agent.parseCaptureToItems(const CaptureId('x'));
      final matched = initial.firstWhere(
        (i) => i.kind == ParsedItemKind.matched,
      );
      expect(matched.matchedTaskId, isNotNull);

      final updated = await agent.breakCaptureLink(matched.id);
      expect(updated.kind, ParsedItemKind.newTask);
      expect(updated.matchedTaskId, isNull);
      expect(updated.title, isNotEmpty);

      final after = await agent.parseCaptureToItems(const CaptureId('x'));
      final sameId = after.firstWhere((i) => i.id == matched.id);
      expect(sameId.kind, ParsedItemKind.newTask);
    });

    test('surfacePendingDecisions exposes the three core reasons', () async {
      final items = await agent.surfacePendingDecisions();
      expect(items, hasLength(3));
      final reasons = items.map((i) => i.reason).toSet();
      expect(reasons, contains(PendingItemReason.overdue));
      expect(reasons, contains(PendingItemReason.inProgress));
      expect(reasons, contains(PendingItemReason.missedRecurring));

      final overdue = items.firstWhere(
        (i) => i.reason == PendingItemReason.overdue,
      );
      expect(overdue.overdueByDays, isNotNull);

      final inProgress = items.firstWhere(
        (i) => i.reason == PendingItemReason.inProgress,
      );
      expect(inProgress.sessionCount, isNotNull);
    });

    test(
      'applyTriage carries the action through and populates deferredTo only '
      'for defer',
      () async {
        final today = await agent.applyTriage(
          taskId: 't_1',
          action: TriageAction.today,
        );
        expect(today.action, TriageAction.today);
        expect(today.deferredTo, isNull);

        final deferred = await agent.applyTriage(
          taskId: 't_2',
          action: TriageAction.defer,
        );
        expect(deferred.action, TriageAction.defer);
        expect(deferred.deferredTo, isNotNull);
        // Defaults to the next day at the injected clock.
        expect(deferred.deferredTo, DateTime(2026, 5, 26, 9));

        final explicit = await agent.applyTriage(
          taskId: 't_3',
          action: TriageAction.defer,
          deferTo: DateTime(2026, 6),
        );
        expect(explicit.deferredTo, DateTime(2026, 6));
      },
    );

    test(
      'draftDayPlan returns blocks with mandatory reasons on ai placements',
      () async {
        final plan = await agent.draftDayPlan(
          captureId: const CaptureId('cap'),
          decidedTaskIds: const ['t_deck_review', 't_onboarding_doc'],
          dayDate: DateTime(2026, 5, 25),
        );

        expect(plan.blocks, isNotEmpty);
        expect(plan.capacityMinutes, 480);
        expect(plan.scheduledMinutes, greaterThan(0));
        expect(plan.bands, hasLength(3));

        // Every AI-placed block carries a reason — that's the contract
        // the WhyChip popover relies on.
        final aiBlocks = plan.blocks
            .where((b) => b.type == TimeBlockType.ai)
            .toList();
        expect(aiBlocks, isNotEmpty);
        for (final block in aiBlocks) {
          expect(
            block.reason,
            isNotNull,
            reason: 'ai block ${block.id} is missing a reason',
          );
          expect(block.reason, isNotEmpty);
        }

        // Calendar blocks survive the day's sort.
        expect(
          plan.blocks.any((b) => b.type == TimeBlockType.cal),
          isTrue,
        );
        // At least one buffer placement is present.
        expect(
          plan.blocks.any((b) => b.type == TimeBlockType.buffer),
          isTrue,
        );

        // Blocks come back sorted by start.
        for (var i = 1; i < plan.blocks.length; i++) {
          expect(
            plan.blocks[i].start.isAfter(plan.blocks[i - 1].start) ||
                plan.blocks[i].start.isAtSameMomentAs(plan.blocks[i - 1].start),
            isTrue,
          );
        }
      },
    );

    test('summarizeRecentPatterns returns 3 cards including a nudge', () async {
      final cards = await agent.summarizeRecentPatterns(
        asOf: DateTime(2026, 5, 25),
      );
      expect(cards, hasLength(3));
      expect(
        cards.any((c) => c.kind == LearningCardKind.nudge),
        isTrue,
      );
      // Standard cards carry bullets; the nudge card does not.
      final standard = cards.where((c) => c.kind == LearningCardKind.standard);
      for (final card in standard) {
        expect(card.bullets, isNotEmpty);
        expect(card.summary, isNotEmpty);
      }
    });

    test(
      'DayAgentInterface is implementable; equality on value objects works',
      () {
        // Compile-time check — Mock is an implementation.
        const DayAgentInterface i = _NullAgent();
        expect(i, isA<DayAgentInterface>());
        expect(const CaptureId('x'), const CaptureId('x'));
        expect(
          const DayAgentCategory(id: 'a', name: 'A', colorHex: 'fff'),
          const DayAgentCategory(id: 'a', name: 'A', colorHex: 'fff'),
        );
      },
    );
  });
}

class _NullAgent implements DayAgentInterface {
  const _NullAgent();

  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
    String? audioId,
  }) async => const CaptureId('null');

  @override
  Future<DraftPlan?> currentPlanForDate(DateTime date) async => null;

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async => const [];

  @override
  Future<List<PendingItem>> surfacePendingDecisions({
    DateTime? forDate,
  }) async => const [];

  @override
  Future<ParsedItem> breakCaptureLink(String parsedItemId) async =>
      throw UnimplementedError();

  @override
  Future<TriageResult> applyTriage({
    required String taskId,
    required TriageAction action,
    DateTime? deferTo,
  }) async => TriageResult(taskId: taskId, action: action);

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<TimeBlock> calendarBlocks = const [],
  }) async => DraftPlan(
    dayDate: dayDate,
    blocks: const [],
    bands: const [],
    capacityMinutes: 0,
    scheduledMinutes: 0,
  );

  @override
  Future<List<LearningCard>> summarizeRecentPatterns({
    required DateTime asOf,
    int lookbackDays = 7,
  }) async => const [];

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
  }) async => PlanDiff(
    id: 'null',
    transcript: voiceTranscript,
    changes: const [],
    updatedPlan: currentPlan,
  );

  @override
  Future<DraftPlan> acceptDiff(PlanDiff diff) async => diff.updatedPlan;

  @override
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
  }) async => originalPlan;

  @override
  Future<DraftPlan> commitDay(DraftPlan plan) async =>
      plan.copyWith(state: DayState.committed);

  @override
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) async => (
    completed: const <CompletedItem>[],
    carryover: const <CarryoverItem>[],
    metrics: const ShutdownMetrics(
      focusMinutes: 0,
      flowSessions: 0,
      contextSwitches: 0,
      contextSwitchesWeekAvg: 0,
      energyScore: 0,
      energyDeltaVsWeek: 0,
    ),
  );

  @override
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
    required ReflectionSource source,
  }) async {}

  @override
  Future<void> recordCarryoverDecision({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) async {}

  @override
  Future<TomorrowNote> generateTomorrowNote({
    required DateTime forDate,
  }) async => const TomorrowNote(body: '', maturity: 1);

  @override
  Future<List<TaskCorpusItem>> surfaceTaskCorpus({
    TaskCorpusState stateFilter = TaskCorpusState.all,
    String? categoryId,
    String? query,
  }) async => const [];
}
