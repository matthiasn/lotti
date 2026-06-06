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

    test(
      'deletePlanForDate resolves to true (mock has no persistence)',
      () async {
        final deleted = await agent.deletePlanForDate(DateTime(2026, 5, 25));
        expect(deleted, isTrue);
      },
    );

    test(
      'breakCaptureLink throws StateError for an id not in the scripted list',
      () async {
        // The id is recorded in the broken-links set, then the scripted
        // list is rebuilt — but since the id is not one of the four
        // scripted parsed items, firstWhere falls through to the orElse
        // and surfaces a StateError rather than returning a stale match.
        await expectLater(
          agent.breakCaptureLink('p_not_a_real_item'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('p_not_a_real_item'),
            ),
          ),
        );
      },
    );

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

  // Lifecycle tools added when the Commit, Shutdown and Tasks corpus
  // screens shipped. Kept as a sibling group (rather than mixed into
  // the main `MockDayAgent` group above) because they need extra
  // latencies zeroed out — `draftDayPlan` would otherwise wait 400 ms
  // per call and slow the suite for no benefit.
  group('MockDayAgent lifecycle', () {
    late MockDayAgent agent;

    setUp(() {
      agent = MockDayAgent(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );
    });

    group('renameBlock', () {
      test(
        'renames a standalone block and its derived agenda item in place',
        () async {
          final plan = await agent.draftDayPlan(
            captureId: const CaptureId('cap'),
            decidedTaskIds: const ['t_deck_review'],
            dayDate: DateTime(2026, 5, 25),
          );
          final standalone = plan.blocks.firstWhere(
            (b) =>
                (b.taskId == null || b.taskId!.isEmpty) &&
                b.type != TimeBlockType.buffer,
          );

          final renamed = await agent.renameBlock(
            plan: plan,
            blockId: standalone.id,
            title: 'Renamed standalone',
          );

          final block = renamed.blocks.singleWhere(
            (b) => b.id == standalone.id,
          );
          expect(block.title, 'Renamed standalone');
          // Untouched blocks keep their titles.
          expect(
            renamed.blocks.where((b) => b.title == 'Renamed standalone'),
            hasLength(1),
          );
          // Standalone agenda items derived from the block follow along.
          final agendaTitles = renamed.agendaItems
              .where(
                (item) =>
                    item.taskId == null &&
                    item.linkedBlockIds.contains(standalone.id),
              )
              .map((item) => item.title);
          expect(agendaTitles, everyElement('Renamed standalone'));
        },
      );

      test('rejects blank titles and trims persisted ones', () async {
        final plan = await agent.draftDayPlan(
          captureId: const CaptureId('cap'),
          decidedTaskIds: const ['t_deck_review'],
          dayDate: DateTime(2026, 5, 25),
        );
        final standalone = plan.blocks.firstWhere(
          (b) =>
              (b.taskId == null || b.taskId!.isEmpty) &&
              b.type != TimeBlockType.buffer,
        );

        expect(
          () => agent.renameBlock(
            plan: plan,
            blockId: standalone.id,
            title: '   ',
          ),
          throwsStateError,
        );

        final renamed = await agent.renameBlock(
          plan: plan,
          blockId: standalone.id,
          title: '  Trimmed title  ',
        );
        expect(
          renamed.blocks.singleWhere((b) => b.id == standalone.id).title,
          'Trimmed title',
        );
      });

      test('rejects unknown block ids', () async {
        final plan = await agent.draftDayPlan(
          captureId: const CaptureId('cap'),
          decidedTaskIds: const ['t_deck_review'],
          dayDate: DateTime(2026, 5, 25),
        );
        expect(
          () => agent.renameBlock(
            plan: plan,
            blockId: 'nope',
            title: 'Renamed',
          ),
          throwsStateError,
        );
      });

      test('rejects task-linked blocks — rename the task instead', () async {
        final plan = await agent.draftDayPlan(
          captureId: const CaptureId('cap'),
          decidedTaskIds: const ['t_deck_review'],
          dayDate: DateTime(2026, 5, 25),
        );
        final linked = plan.blocks.firstWhere(
          (b) => b.taskId != null && b.taskId!.isNotEmpty,
        );
        expect(
          () => agent.renameBlock(
            plan: plan,
            blockId: linked.id,
            title: 'Renamed',
          ),
          throwsStateError,
        );
      });
    });

    test(
      'commitDay flips drafted blocks to committed and the plan state',
      () async {
        final plan = await agent.draftDayPlan(
          captureId: const CaptureId('cap'),
          decidedTaskIds: const ['t_deck_review'],
          dayDate: DateTime(2026, 5, 25),
        );
        // The freshly-drafted plan is, by construction, drafted.
        expect(plan.state, DayState.drafted);
        expect(
          plan.blocks.any((b) => b.state == TimeBlockState.drafted),
          isTrue,
        );

        final committed = await agent.commitDay(plan);
        expect(committed.state, DayState.committed);
        // No drafted blocks remain — they all transitioned.
        expect(
          committed.blocks.any((b) => b.state == TimeBlockState.drafted),
          isFalse,
        );
        // Real calendar events keep their original state — the
        // prototype's calendar block is already committed.
        expect(
          committed.blocks
              .where((b) => b.type == TimeBlockType.cal)
              .every((b) => b.state == TimeBlockState.committed),
          isTrue,
        );
      },
    );

    test(
      'surfaceShutdownData returns completed + carryover + metrics',
      () async {
        final result = await agent.surfaceShutdownData(
          forDate: DateTime(2026, 5, 25),
        );
        expect(result.completed, isNotEmpty);
        expect(result.carryover, isNotEmpty);
        expect(result.metrics.focusMinutes, greaterThan(0));
        expect(result.metrics.flowSessions, greaterThan(0));
        // Every carryover row carries a suggestedTarget label so the
        // primary teal chip always has something to render.
        for (final item in result.carryover) {
          expect(item.suggestedTarget, isNotEmpty);
        }
      },
    );

    test('generateTomorrowNote returns a non-empty body', () async {
      final note = await agent.generateTomorrowNote(
        forDate: DateTime(2026, 5, 25),
      );
      expect(note.body, isNotEmpty);
      expect(note.maturity, greaterThanOrEqualTo(1));
    });

    test(
      'recordReflection + recordCarryoverDecision are side-effect-only',
      () async {
        // These are no-ops in the mock; the test just verifies they
        // complete without throwing — the real agent layer will
        // persist + emit feedback events.
        await agent.recordReflection(
          forDate: DateTime(2026, 5, 25),
          text: 'morning was sharp',
          source: ReflectionSource.typed,
        );
        await agent.recordCarryoverDecision(
          taskId: 't_onboarding_doc',
          action: CarryoverAction.tomorrow,
        );
      },
    );

    group('surfaceTaskCorpus', () {
      test('default filter returns the full corpus', () async {
        final all = await agent.surfaceTaskCorpus();
        expect(all, isNotEmpty);
        // The corpus must include every TaskCorpusState the filter
        // chip row knows about, except `all` (which is a meta state).
        final present = all.map((i) => i.state).toSet();
        expect(present, contains(TaskCorpusState.inProgress));
        expect(present, contains(TaskCorpusState.overdue));
      });

      test('state filter narrows to matching items', () async {
        final overdue = await agent.surfaceTaskCorpus(
          stateFilter: TaskCorpusState.overdue,
        );
        expect(overdue, isNotEmpty);
        expect(
          overdue.every((i) => i.state == TaskCorpusState.overdue),
          isTrue,
        );
      });

      test('query filters by title substring (case-insensitive)', () async {
        final hits = await agent.surfaceTaskCorpus(query: 'deck');
        expect(hits, isNotEmpty);
        expect(
          hits.every((i) => i.title.toLowerCase().contains('deck')),
          isTrue,
        );

        final noMatch = await agent.surfaceTaskCorpus(query: 'zzzz');
        expect(noMatch, isEmpty);
      });

      test('categoryId filter narrows to matching items only', () async {
        final health = await agent.surfaceTaskCorpus(categoryId: 'cat_health');
        expect(health, isNotEmpty);
        expect(
          health.every((i) => i.category.id == 'cat_health'),
          isTrue,
        );
        // Items in other categories are filtered out — the corpus has
        // work/study/meals rows that must not leak through.
        expect(
          health.any((i) => i.category.id != 'cat_health'),
          isFalse,
        );

        final none = await agent.surfaceTaskCorpus(categoryId: 'cat_nope');
        expect(none, isEmpty);
      });
    });

    group('proposePlanDiff', () {
      test(
        'returns an empty diff when the current plan has no blocks',
        () async {
          final empty = DraftPlan(
            dayDate: DateTime(2026, 5, 25),
            blocks: const [],
            bands: const [],
            capacityMinutes: 480,
            scheduledMinutes: 0,
          );

          final diff = await agent.proposePlanDiff(
            currentPlan: empty,
            voiceTranscript: 'skip onboarding',
          );

          expect(diff.changes, isEmpty);
          expect(diff.transcript, 'skip onboarding');
          // The unchanged plan flows straight back so the Refine
          // controller treats it as immediately resolved.
          expect(diff.updatedPlan, same(empty));
          expect(diff.id, startsWith('diff_'));
        },
      );

      test(
        'diff id increments across successive calls',
        () async {
          final empty = DraftPlan(
            dayDate: DateTime(2026, 5, 25),
            blocks: const [],
            bands: const [],
            capacityMinutes: 480,
            scheduledMinutes: 0,
          );

          final first = await agent.proposePlanDiff(
            currentPlan: empty,
            voiceTranscript: 'a',
          );
          final second = await agent.proposePlanDiff(
            currentPlan: empty,
            voiceTranscript: 'b',
          );
          expect(first.id, isNot(second.id));
        },
      );

      test(
        'falls back to first/last block when the named blocks are absent and '
        'scripts the morning-run outcome',
        () async {
          // No b_deep_work / b_run_review blocks: the deck firstWhere
          // hits orElse -> blocks.first, the onboarding firstWhere hits
          // orElse -> blocks.last. We also tag the first block with the
          // t_morning_run taskId so the agenda projection exercises the
          // scripted 't_morning_run' outcome branch.
          final start = DateTime(2026, 5, 25, 8);
          final plan = DraftPlan(
            dayDate: DateTime(2026, 5, 25),
            blocks: [
              TimeBlock(
                id: 'b_alpha',
                title: 'Morning run · 5km',
                start: start,
                end: start.add(const Duration(minutes: 30)),
                type: TimeBlockType.ai,
                state: TimeBlockState.drafted,
                category: const DayAgentCategory(
                  id: 'cat_health',
                  name: 'Health',
                  colorHex: '7AB889',
                ),
                taskId: 't_morning_run',
                reason: 'placeholder',
              ),
              TimeBlock(
                id: 'b_omega',
                title: 'Wrap up',
                start: start.add(const Duration(hours: 2)),
                end: start.add(const Duration(hours: 3)),
                type: TimeBlockType.ai,
                state: TimeBlockState.drafted,
                category: const DayAgentCategory(
                  id: 'cat_work',
                  name: 'Work',
                  colorHex: '5ED4B7',
                ),
                taskId: 't_deck_review',
                reason: 'placeholder',
              ),
            ],
            bands: const [],
            capacityMinutes: 480,
            scheduledMinutes: 0,
          );

          final diff = await agent.proposePlanDiff(
            currentPlan: plan,
            voiceTranscript: 'reshape my afternoon',
          );

          // First block was treated as the "deck" and moved 30m earlier.
          final moved = diff.changes.firstWhere(
            (c) => c.kind == PlanDiffChangeKind.moved,
          );
          expect(moved.affectedBlockId, 'b_alpha');
          expect(
            moved.toStart,
            start.subtract(const Duration(minutes: 30)),
          );

          // Last block was treated as the "onboarding" block and dropped.
          final dropped = diff.changes.firstWhere(
            (c) => c.kind == PlanDiffChangeKind.dropped,
          );
          expect(dropped.affectedBlockId, 'b_omega');

          // A buffer was added.
          expect(
            diff.changes.any((c) => c.kind == PlanDiffChangeKind.added),
            isTrue,
          );

          // The morning-run scripted outcome surfaced on the agenda
          // projection of the moved deck block.
          final runAgenda = diff.updatedPlan.agendaItems.firstWhere(
            (a) => a.taskId == 't_morning_run',
          );
          expect(
            runAgenda.outcome,
            '5 km logged before the day starts.',
          );
        },
      );

      test(
        'uses the named blocks when both b_deep_work and b_run_review exist',
        () async {
          final plan = await agent.draftDayPlan(
            captureId: const CaptureId('cap'),
            decidedTaskIds: const ['t_deck_review', 't_onboarding_doc'],
            dayDate: DateTime(2026, 5, 25),
          );

          final diff = await agent.proposePlanDiff(
            currentPlan: plan,
            voiceTranscript: 'skip onboarding, move the deck earlier',
          );

          // The moved change targets the named deep-work block, not a
          // fallback first/last block.
          final moved = diff.changes.firstWhere(
            (c) => c.kind == PlanDiffChangeKind.moved,
          );
          expect(moved.affectedBlockId, 'b_deep_work');

          final dropped = diff.changes.firstWhere(
            (c) => c.kind == PlanDiffChangeKind.dropped,
          );
          expect(dropped.affectedBlockId, 'b_run_review');

          // The dropped onboarding block is gone from the updated plan.
          expect(
            diff.updatedPlan.blocks.any((b) => b.id == 'b_run_review'),
            isFalse,
          );
          // The moved deck block starts 30 minutes earlier than before.
          final originalDeck = plan.blocks.firstWhere(
            (b) => b.id == 'b_deep_work',
          );
          final updatedDeck = diff.updatedPlan.blocks.firstWhere(
            (b) => b.id == 'b_deep_work',
          );
          expect(
            updatedDeck.start,
            originalDeck.start.subtract(const Duration(minutes: 30)),
          );
        },
      );

      test(
        'agenda items for unscripted taskIds carry no outcome or progress',
        () async {
          // A block whose taskId matches none of the scripted cases drives
          // both `_scriptedOutcome` and `_scriptedProgress` into their
          // `return null` fallbacks.
          final start = DateTime(2026, 5, 25, 8);
          final plan = DraftPlan(
            dayDate: DateTime(2026, 5, 25),
            blocks: [
              TimeBlock(
                id: 'b_unscripted',
                title: 'Completely new work',
                start: start,
                end: start.add(const Duration(hours: 1)),
                type: TimeBlockType.ai,
                state: TimeBlockState.drafted,
                category: const DayAgentCategory(
                  id: 'cat_work',
                  name: 'Work',
                  colorHex: '5ED4B7',
                ),
                taskId: 't_unscripted_task',
                reason: 'placeholder',
              ),
            ],
            bands: const [],
            capacityMinutes: 480,
            scheduledMinutes: 60,
          );

          final diff = await agent.proposePlanDiff(
            currentPlan: plan,
            voiceTranscript: 'shuffle things around',
          );

          final agendaItem = diff.updatedPlan.agendaItems.firstWhere(
            (a) => a.taskId == 't_unscripted_task',
          );
          expect(agendaItem.outcome, isNull);
          expect(agendaItem.progress, isNull);
          expect(agendaItem.totalEstimateMinutes, greaterThan(0));
        },
      );
    });

    test('currentPlanForDate always reports no stored plan', () async {
      expect(await agent.currentPlanForDate(DateTime(2026, 5, 25)), isNull);
      // Even right after drafting a plan, the mock stores nothing.
      await agent.draftDayPlan(
        captureId: const CaptureId('cap'),
        decidedTaskIds: const ['t_deck_review'],
        dayDate: DateTime(2026, 5, 25),
      );
      expect(await agent.currentPlanForDate(DateTime(2026, 5, 25)), isNull);
    });
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
  Future<bool> deletePlanForDate(DateTime date) async => true;

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
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
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
    bool Function()? isCancelled,
  }) async => PlanDiff(
    id: 'null',
    transcript: voiceTranscript,
    changes: const [],
    updatedPlan: currentPlan,
  );

  @override
  Future<DraftPlan> acceptDiff(
    PlanDiff diff, {
    List<int>? itemIndices,
  }) async => diff.updatedPlan;

  @override
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
    List<int>? itemIndices,
  }) async => originalPlan;

  @override
  Future<DraftPlan> commitDay(DraftPlan plan) async =>
      plan.copyWith(state: DayState.committed);

  @override
  Future<DraftPlan> renameBlock({
    required DraftPlan plan,
    required String blockId,
    required String title,
  }) async {
    return plan.copyWith(
      blocks: [
        for (final block in plan.blocks)
          if (block.id == blockId) block.copyWith(title: title) else block,
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
