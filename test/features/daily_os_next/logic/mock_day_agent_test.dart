import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('MockDayAgent', () {
    late MockDayAgent agent;

    setUp(() {
      agent = MockDayAgent(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        // `draftDayPlan` (below) otherwise waits the default 400 ms of real
        // wall-clock per call — zero it out to keep the group deterministic
        // and fast (see test/README.md's no-real-delay policy).
        draftLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );
    });

    test('submitCapture returns a fresh, monotonic capture id', () async {
      final first = await agent.submitCapture(
        transcript: 'hello world',
        capturedAt: DateTime(2026, 5, 25, 9),
        dayDate: DateTime(2026, 5, 25),
      );
      final second = await agent.submitCapture(
        transcript: 'another one',
        capturedAt: DateTime(2026, 5, 25, 9, 1),
        dayDate: DateTime(2026, 5, 25),
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
        // the agenda why tooltip relies on.
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

    test('value-object equality holds for CaptureId and DayAgentCategory', () {
      expect(const CaptureId('x'), const CaptureId('x'));
      expect(const CaptureId('x'), isNot(const CaptureId('y')));
      expect(
        const DayAgentCategory(id: 'a', name: 'A', colorHex: 'fff'),
        const DayAgentCategory(id: 'a', name: 'A', colorHex: 'fff'),
      );
      expect(
        const DayAgentCategory(id: 'a', name: 'A', colorHex: 'fff'),
        isNot(const DayAgentCategory(id: 'b', name: 'A', colorHex: 'fff')),
      );
    });
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
          const category = DayAgentCategory(
            id: 'c1',
            name: 'Work',
            colorHex: '5ED4B7',
          );
          final start = DateTime(2026, 5, 25, 12);
          final plan = DraftPlan(
            dayDate: DateTime(2026, 5, 25),
            blocks: [
              TimeBlock(
                id: 'b_standalone',
                title: 'Lunch',
                start: start,
                end: start.add(const Duration(hours: 1)),
                type: TimeBlockType.manual,
                state: TimeBlockState.drafted,
                category: category,
              ),
              TimeBlock(
                id: 'b_linked',
                title: 'Deck work',
                start: start.add(const Duration(hours: 2)),
                end: start.add(const Duration(hours: 3)),
                type: TimeBlockType.ai,
                state: TimeBlockState.drafted,
                category: category,
                taskId: 'task-1',
                reason: 'focus window',
              ),
            ],
            bands: const [],
            capacityMinutes: 480,
            scheduledMinutes: 120,
            agendaItems: const [
              AgendaItem(
                id: 'agenda_b_standalone',
                title: 'Lunch',
                category: category,
                linkedBlockIds: ['b_standalone'],
              ),
              AgendaItem(
                id: 'agenda_task-1',
                title: 'Deck work',
                category: category,
                linkedBlockIds: ['b_linked'],
                taskId: 'task-1',
              ),
            ],
          );

          final renamed = await agent.renameBlock(
            plan: plan,
            blockId: 'b_standalone',
            title: 'Renamed standalone',
          );

          expect(
            renamed.blocks.singleWhere((b) => b.id == 'b_standalone').title,
            'Renamed standalone',
          );
          // Untouched blocks keep their titles.
          expect(
            renamed.blocks.singleWhere((b) => b.id == 'b_linked').title,
            'Deck work',
          );
          // The standalone agenda item derived from the block follows
          // along; the task-linked agenda item stays untouched.
          expect(
            renamed.agendaItems
                .singleWhere((item) => item.id == 'agenda_b_standalone')
                .title,
            'Renamed standalone',
          );
          expect(
            renamed.agendaItems
                .singleWhere((item) => item.id == 'agenda_task-1')
                .title,
            'Deck work',
          );
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

    group('editBlock', () {
      const category = DayAgentCategory(
        id: 'c1',
        name: 'Work',
        colorHex: '5ED4B7',
      );

      DraftPlan planWith(
        TimeBlock block, {
        DateTime? dayDate,
        List<TimeBlock> extraBlocks = const [],
        List<AgendaItem> agendaItems = const [],
      }) {
        final blocks = [block, ...extraBlocks];
        return DraftPlan(
          dayDate: dayDate ?? DateTime(2026, 5, 25),
          blocks: blocks,
          bands: const [],
          capacityMinutes: 480,
          scheduledMinutes: blocks.fold(
            0,
            (sum, candidate) => sum + candidate.duration.inMinutes,
          ),
          agendaItems: agendaItems,
        );
      }

      TimeBlock block({
        String id = 'block-1',
        TimeBlockType type = TimeBlockType.ai,
        TimeBlockState state = TimeBlockState.drafted,
        String? taskId,
        DateTime? start,
        DateTime? end,
      }) => TimeBlock(
        id: id,
        title: 'Focus work',
        start: start ?? DateTime(2026, 5, 25, 9),
        end: end ?? DateTime(2026, 5, 25, 10),
        type: type,
        state: state,
        category: category,
        taskId: taskId,
        reason: type == TimeBlockType.ai ? 'Morning focus.' : null,
      );

      test('moves and resizes an editable block', () async {
        final updated = await agent.editBlock(
          plan: planWith(block()),
          blockId: 'block-1',
          start: DateTime(2026, 5, 25, 10, 15),
          end: DateTime(2026, 5, 25, 11, 45),
        );

        expect(updated.blocks.single.start, DateTime(2026, 5, 25, 10, 15));
        expect(updated.blocks.single.end, DateTime(2026, 5, 25, 11, 45));
        expect(updated.scheduledMinutes, 90);
      });

      test('accepts the next local midnight across a DST transition', () async {
        final berlin = tz.getLocation('Europe/Berlin');
        final editable = block(
          start: tz.TZDateTime(berlin, 2024, 10, 27, 22),
          end: tz.TZDateTime(berlin, 2024, 10, 27, 23),
        );
        final updated = await agent.editBlock(
          plan: planWith(
            editable,
            dayDate: tz.TZDateTime(berlin, 2024, 10, 27),
          ),
          blockId: editable.id,
          start: tz.TZDateTime(berlin, 2024, 10, 27, 23),
          end: tz.TZDateTime(berlin, 2024, 10, 28),
        );

        expect(updated.blocks.single.end, tz.TZDateTime(berlin, 2024, 10, 28));
        expect(updated.scheduledMinutes, 60);
      });

      test(
        'updates standalone identity and its agenda projection atomically',
        () async {
          const playful = DayAgentCategory(
            id: 'c2',
            name: 'Penguin Diplomacy',
            colorHex: 'FF8A65',
          );
          final editable = block(id: 'z-edit');
          final dropped = block(
            id: 'dropped',
            state: TimeBlockState.dropped,
            start: DateTime(2026, 5, 25, 8),
            end: DateTime(2026, 5, 25, 9),
          );
          final updated = await agent.editBlock(
            plan: planWith(
              editable,
              extraBlocks: [dropped],
              agendaItems: const [
                AgendaItem(
                  id: 'standalone',
                  title: 'Focus work',
                  category: category,
                  linkedBlockIds: ['z-edit'],
                ),
                AgendaItem(
                  id: 'task-owned',
                  title: 'Task source of truth',
                  category: category,
                  linkedBlockIds: ['z-edit'],
                  taskId: 'task-1',
                ),
              ],
            ),
            blockId: 'z-edit',
            start: DateTime(2026, 5, 25, 8),
            end: DateTime(2026, 5, 25, 10, 30),
            title: '  Audit the emergency fish ledger  ',
            category: playful,
          );

          expect(updated.blocks.map((candidate) => candidate.id), [
            'dropped',
            'z-edit',
          ]);
          expect(updated.blocks.last.title, 'Audit the emergency fish ledger');
          expect(updated.blocks.last.category, playful);
          expect(updated.scheduledMinutes, 150);
          expect(
            updated.agendaItems.first.title,
            'Audit the emergency fish ledger',
          );
          expect(updated.agendaItems.first.category, playful);
          expect(updated.agendaItems.last.title, 'Task source of truth');
          expect(updated.agendaItems.last.category, category);
        },
      );

      test('sorts blocks with equal starts by stable id', () async {
        final updated = await agent.editBlock(
          plan: planWith(
            block(id: 'z-last'),
            extraBlocks: [
              block(
                id: 'a-first',
                start: DateTime(2026, 5, 25, 11),
                end: DateTime(2026, 5, 25, 12),
              ),
            ],
          ),
          blockId: 'z-last',
          start: DateTime(2026, 5, 25, 11),
          end: DateTime(2026, 5, 25, 12, 30),
        );

        expect(updated.blocks.map((candidate) => candidate.id), [
          'a-first',
          'z-last',
        ]);
      });

      test('accepts the UTC plan-day boundary', () async {
        final day = DateTime.utc(2026, 5, 25);
        final updated = await agent.editBlock(
          plan: planWith(
            block(
              start: DateTime.utc(2026, 5, 25, 22),
              end: DateTime.utc(2026, 5, 25, 23),
            ),
            dayDate: day,
          ),
          blockId: 'block-1',
          start: DateTime.utc(2026, 5, 25, 23),
          end: DateTime.utc(2026, 5, 26),
        );

        expect(updated.blocks.single.start, DateTime.utc(2026, 5, 25, 23));
        expect(updated.blocks.single.end, DateTime.utc(2026, 5, 26));
      });

      test('rejects invalid ownership and identity edits', () async {
        final cases =
            <({DraftPlan plan, String? title, DayAgentCategory? category})>[
              (plan: planWith(block()), title: '  ', category: null),
              (
                plan: planWith(block(taskId: 'task-1')),
                title: 'Rename the linked task',
                category: null,
              ),
              (
                plan: planWith(block(taskId: 'task-1')),
                title: null,
                category: const DayAgentCategory(
                  id: 'c2',
                  name: 'Life',
                  colorHex: 'FF8A65',
                ),
              ),
              (
                plan: planWith(block(type: TimeBlockType.buffer)),
                title: 'Rename buffer',
                category: null,
              ),
            ];

        for (final values in cases) {
          await expectLater(
            agent.editBlock(
              plan: values.plan,
              blockId: 'block-1',
              start: DateTime(2026, 5, 25, 9),
              end: DateTime(2026, 5, 25, 10),
              title: values.title,
              category: values.category,
            ),
            throwsStateError,
          );
        }
      });

      test('rejects ranges before and after the plan day', () async {
        final editablePlan = planWith(block());
        final ranges = <({DateTime start, DateTime end})>[
          (
            start: DateTime(2026, 5, 24, 23, 45),
            end: DateTime(2026, 5, 25, 1),
          ),
          (
            start: DateTime(2026, 5, 25, 23, 45),
            end: DateTime(2026, 5, 26, 0, 15),
          ),
        ];

        for (final range in ranges) {
          await expectLater(
            agent.editBlock(
              plan: editablePlan,
              blockId: 'block-1',
              start: range.start,
              end: range.end,
            ),
            throwsStateError,
          );
        }
      });

      test('rejects invalid, calendar-owned, and unknown edits', () async {
        final editablePlan = planWith(block());
        final calendarPlan = planWith(block(type: TimeBlockType.cal));

        expect(
          () => agent.editBlock(
            plan: editablePlan,
            blockId: 'block-1',
            start: DateTime(2026, 5, 25, 10),
            end: DateTime(2026, 5, 25, 10),
          ),
          throwsStateError,
        );
        expect(
          () => agent.editBlock(
            plan: calendarPlan,
            blockId: 'block-1',
            start: DateTime(2026, 5, 25, 10),
            end: DateTime(2026, 5, 25, 11),
          ),
          throwsStateError,
        );
        expect(
          () => agent.editBlock(
            plan: editablePlan,
            blockId: 'missing',
            start: DateTime(2026, 5, 25, 10),
            end: DateTime(2026, 5, 25, 11),
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
  group('debugMatchesFilter — properties', () {
    const categories = ['cat-a', 'cat-b'];
    const queries = [null, '', '  ', 'deck', 'DECK', 'zzz'];

    TaskCorpusItem item(int seed) => TaskCorpusItem(
      id: 'task-$seed',
      title: seed.isEven ? 'Paint the deck $seed' : 'Inbox triage $seed',
      category: DayAgentCategory(
        id: categories[seed % categories.length],
        name: 'Cat',
        colorHex: '8E8E8E',
      ),
      state: TaskCorpusState
          .values[1 + seed % (TaskCorpusState.values.length - 1)],
      updatedLabel: 'today',
    );

    glados.Glados3(
      glados.any.intInRange(0, 50),
      glados.any.intInRange(0, TaskCorpusState.values.length),
      glados.any.intInRange(0, 12),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'every item matching a narrowed filter also matches state=all with '
      'the same category/query (all is a superset)',
      (seed, stateIndex, filterSeed) {
        final agent = MockDayAgent();
        final candidate = item(seed);
        final state =
            TaskCorpusState.values[stateIndex % TaskCorpusState.values.length];
        final categoryId = filterSeed.isEven
            ? null
            : categories[filterSeed % categories.length];
        final query = queries[filterSeed % queries.length];

        final narrowed = agent.debugMatchesFilter(
          candidate,
          state,
          categoryId,
          query,
        );
        final broad = agent.debugMatchesFilter(
          candidate,
          TaskCorpusState.all,
          categoryId,
          query,
        );

        if (narrowed) {
          expect(
            broad,
            isTrue,
            reason: 'state=$state cat=$categoryId q="$query" item=$seed',
          );
        }

        // Oracle for the broad filter itself: category and query are the
        // only remaining predicates under state=all.
        final q = query?.trim().toLowerCase();
        final expectedBroad =
            (categoryId == null || candidate.category.id == categoryId) &&
            (q == null ||
                q.isEmpty ||
                candidate.title.toLowerCase().contains(q));
        expect(broad, expectedBroad);
      },
      tags: 'glados',
    );
  });
}
