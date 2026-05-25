import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';

void main() {
  group('Day plan tests', () {
    group('dayPlanId', () {
      test('generates correct ID format', () {
        final date = DateTime(2026, 1, 14);
        expect(dayPlanId(date), equals('dayplan-2026-01-14'));
      });

      test('handles single digit months and days', () {
        final date = DateTime(2026, 3, 5);
        expect(dayPlanId(date), equals('dayplan-2026-03-05'));
      });

      test('ignores time component', () {
        final date = DateTime(2026, 1, 14, 15, 30, 45);
        expect(dayPlanId(date), equals('dayplan-2026-01-14'));
      });

      glados.Glados<_GeneratedDayDate>(
        glados.any.dayDate,
        glados.ExploreConfig(numRuns: 120),
      ).test('normalizes any time on the same local day', (generated) {
        final id = dayPlanId(generated.withTime);

        expect(id, dayPlanId(generated.dayOnly), reason: '$generated');
        expect(
          id,
          matches(RegExp(r'^dayplan-\d{4}-\d{2}-\d{2}$')),
          reason: '$generated',
        );
        expect(
          DateTime.parse(id.replaceFirst('dayplan-', '')),
          generated.dayOnly,
          reason: '$generated',
        );
      }, tags: 'glados');
    });

    group('DayPlanStatus', () {
      test('draft can be serialized and deserialized', () {
        const status = DayPlanStatus.draft();

        final json = jsonEncode(status.toJson());
        final fromJson = DayPlanStatus.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(status));
        expect(fromJson, isA<DayPlanStatusDraft>());
      });

      test('agreed can be serialized and deserialized', () {
        final status = DayPlanStatus.agreed(
          agreedAt: DateTime(2026, 1, 14, 10, 30),
        );

        final json = jsonEncode(status.toJson());
        final fromJson = DayPlanStatus.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(status));
        expect(fromJson, isA<DayPlanStatusAgreed>());
        expect(
          (fromJson as DayPlanStatusAgreed).agreedAt,
          equals(DateTime(2026, 1, 14, 10, 30)),
        );
      });

      test('needsReview can be serialized and deserialized', () {
        final status = DayPlanStatus.needsReview(
          triggeredAt: DateTime(2026, 1, 14, 14),
          reason: DayPlanReviewReason.newDueTask,
          previouslyAgreedAt: DateTime(2026, 1, 14, 10, 30),
        );

        final json = jsonEncode(status.toJson());
        final fromJson = DayPlanStatus.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(status));
        expect(fromJson, isA<DayPlanStatusNeedsReview>());
        final needsReview = fromJson as DayPlanStatusNeedsReview;
        expect(needsReview.reason, equals(DayPlanReviewReason.newDueTask));
        expect(
          needsReview.previouslyAgreedAt,
          equals(DateTime(2026, 1, 14, 10, 30)),
        );
      });

      test('needsReview without previouslyAgreedAt', () {
        final status = DayPlanStatus.needsReview(
          triggeredAt: DateTime(2026, 1, 14, 14),
          reason: DayPlanReviewReason.blockModified,
        );

        final json = jsonEncode(status.toJson());
        final fromJson = DayPlanStatus.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(status));
        expect(
          (fromJson as DayPlanStatusNeedsReview).previouslyAgreedAt,
          isNull,
        );
      });
    });

    group('PlannedBlock', () {
      test('can be serialized and deserialized', () {
        final block = PlannedBlock(
          id: 'block-1',
          categoryId: 'category-work',
          startTime: DateTime(2026, 1, 14, 9),
          endTime: DateTime(2026, 1, 14, 12),
          note: 'Focus time',
        );

        final json = jsonEncode(block.toJson());
        final fromJson = PlannedBlock.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(block));
        expect(fromJson.note, equals('Focus time'));
      });

      test('duration extension works correctly', () {
        final block = PlannedBlock(
          id: 'block-1',
          categoryId: 'category-work',
          startTime: DateTime(2026, 1, 14, 9),
          endTime: DateTime(2026, 1, 14, 11, 30),
        );

        expect(
          block.duration,
          equals(const Duration(hours: 2, minutes: 30)),
        );
      });

      test('can be serialized without note', () {
        final block = PlannedBlock(
          id: 'block-1',
          categoryId: 'category-work',
          startTime: DateTime(2026, 1, 14, 9),
          endTime: DateTime(2026, 1, 14, 12),
        );

        final json = jsonEncode(block.toJson());
        final fromJson = PlannedBlock.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(block));
        expect(fromJson.note, isNull);
      });

      test('roundtrips agent drafting metadata', () {
        final block = PlannedBlock(
          id: 'block-1',
          categoryId: 'category-work',
          startTime: DateTime(2026, 1, 14, 9),
          endTime: DateTime(2026, 1, 14, 12),
          taskId: 'task-123',
          title: 'Prep demo',
          type: PlannedBlockType.manual,
          state: PlannedBlockState.committed,
          reason: 'High-energy focus window.',
        );

        final decoded = PlannedBlock.fromJson(
          jsonDecode(jsonEncode(block.toJson())) as Map<String, dynamic>,
        );

        expect(decoded, block);
        expect(decoded.taskId, 'task-123');
        expect(decoded.title, 'Prep demo');
        expect(decoded.type, PlannedBlockType.manual);
        expect(decoded.state, PlannedBlockState.committed);
        expect(decoded.requiresReason, isFalse);
      });

      test('defaults legacy blocks to AI draft metadata', () {
        final block = PlannedBlock(
          id: 'block-1',
          categoryId: 'category-work',
          startTime: DateTime(2026, 1, 14, 9),
          endTime: DateTime(2026, 1, 14, 12),
        );

        expect(block.type, PlannedBlockType.ai);
        expect(block.state, PlannedBlockState.drafted);
        expect(block.reason, isNull);
        expect(block.requiresReason, isTrue);
      });

      test('only AI blocks require a reason', () {
        for (final type in PlannedBlockType.values) {
          final block = PlannedBlock(
            id: 'block-${type.name}',
            categoryId: 'category-work',
            startTime: DateTime(2026, 1, 14, 9),
            endTime: DateTime(2026, 1, 14, 12),
            type: type,
          );

          expect(
            block.requiresReason,
            type == PlannedBlockType.ai,
            reason: type.name,
          );
        }
      });
    });

    group('PinnedTaskRef', () {
      test('can be serialized and deserialized', () {
        const ref = PinnedTaskRef(
          taskId: 'task-123',
          categoryId: 'category-1',
          sortOrder: 2,
        );

        final json = jsonEncode(ref.toJson());
        final fromJson = PinnedTaskRef.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(ref));
      });

      test('defaults sortOrder to 0', () {
        const ref = PinnedTaskRef(
          taskId: 'task-123',
          categoryId: 'category-1',
        );

        expect(ref.sortOrder, equals(0));
      });
    });

    group('DayPlanData', () {
      test('can be serialized and deserialized with all fields', () {
        final data = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: DayPlanStatus.agreed(
            agreedAt: DateTime(2026, 1, 14, 8),
          ),
          dayLabel: 'Focused Workday',
          agreedAt: DateTime(2026, 1, 14, 8),
          completedAt: DateTime(2026, 1, 14, 18),
          plannedBlocks: [
            PlannedBlock(
              id: 'block-1',
              categoryId: 'category-work',
              startTime: DateTime(2026, 1, 14, 9),
              endTime: DateTime(2026, 1, 14, 12),
            ),
            PlannedBlock(
              id: 'block-2',
              categoryId: 'category-personal',
              startTime: DateTime(2026, 1, 14, 14),
              endTime: DateTime(2026, 1, 14, 15),
            ),
          ],
          pinnedTasks: const [
            PinnedTaskRef(
              taskId: 'task-1',
              categoryId: 'category-work',
            ),
          ],
        );

        final json = jsonEncode(data.toJson());
        final fromJson = DayPlanData.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson, equals(data));
        expect(fromJson.plannedBlocks.length, equals(2));
        expect(fromJson.pinnedTasks.length, equals(1));
      });

      test('defaults to empty lists', () {
        final data = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
        );

        expect(data.plannedBlocks, isEmpty);
        expect(data.pinnedTasks, isEmpty);
      });

      test('totalPlannedDuration calculates correctly from blocks', () {
        final data = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
          plannedBlocks: [
            PlannedBlock(
              id: 'block-1',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 1, 14, 9),
              endTime: DateTime(2026, 1, 14, 11), // 2 hours
            ),
            PlannedBlock(
              id: 'block-2',
              categoryId: 'cat-2',
              startTime: DateTime(2026, 1, 14, 13),
              endTime: DateTime(2026, 1, 14, 14), // 1 hour
            ),
            PlannedBlock(
              id: 'block-3',
              categoryId: 'cat-3',
              startTime: DateTime(2026, 1, 14, 15),
              endTime: DateTime(2026, 1, 14, 15, 30), // 30 min
            ),
          ],
        );

        expect(
          data.totalPlannedDuration,
          equals(const Duration(hours: 3, minutes: 30)),
        );
      });

      test('blocksForCategory returns sorted blocks', () {
        final data = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
          plannedBlocks: [
            PlannedBlock(
              id: 'block-2',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 1, 14, 14),
              endTime: DateTime(2026, 1, 14, 16),
            ),
            PlannedBlock(
              id: 'block-1',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 1, 14, 9),
              endTime: DateTime(2026, 1, 14, 12),
            ),
            PlannedBlock(
              id: 'block-3',
              categoryId: 'cat-2',
              startTime: DateTime(2026, 1, 14, 10),
              endTime: DateTime(2026, 1, 14, 11),
            ),
          ],
        );

        final blocks = data.blocksForCategory('cat-1');
        expect(blocks.length, equals(2));
        expect(blocks[0].id, equals('block-1'));
        expect(blocks[1].id, equals('block-2'));
      });

      test('derivedBudgets aggregates blocks by category', () {
        final data = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
          plannedBlocks: [
            PlannedBlock(
              id: 'block-1',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 1, 14, 9),
              endTime: DateTime(2026, 1, 14, 11), // 2 hours
            ),
            PlannedBlock(
              id: 'block-2',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 1, 14, 14),
              endTime: DateTime(2026, 1, 14, 15), // 1 hour
            ),
            PlannedBlock(
              id: 'block-3',
              categoryId: 'cat-2',
              startTime: DateTime(2026, 1, 14, 12),
              endTime: DateTime(2026, 1, 14, 13), // 1 hour
            ),
          ],
        );

        final budgets = data.derivedBudgets;
        expect(budgets.length, equals(2));

        // Should be sorted by earliest block start time
        final cat1Budget = budgets.firstWhere((b) => b.categoryId == 'cat-1');
        expect(cat1Budget.plannedDuration, equals(const Duration(hours: 3)));
        expect(cat1Budget.blocks.length, equals(2));

        final cat2Budget = budgets.firstWhere((b) => b.categoryId == 'cat-2');
        expect(cat2Budget.plannedDuration, equals(const Duration(hours: 1)));
        expect(cat2Budget.blocks.length, equals(1));
      });

      test('status helper methods work correctly', () {
        final draft = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
        );
        expect(draft.isDraft, isTrue);
        expect(draft.isAgreed, isFalse);
        expect(draft.needsReview, isFalse);

        final agreed = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 14)),
        );
        expect(agreed.isDraft, isFalse);
        expect(agreed.isAgreed, isTrue);
        expect(agreed.needsReview, isFalse);

        final review = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: DayPlanStatus.needsReview(
            triggeredAt: DateTime(2026, 1, 14),
            reason: DayPlanReviewReason.newDueTask,
          ),
        );
        expect(review.isDraft, isFalse);
        expect(review.isAgreed, isFalse);
        expect(review.needsReview, isTrue);
      });

      test('categoryIds returns all unique categories', () {
        final data = DayPlanData(
          planDate: DateTime(2026, 1, 14),
          status: const DayPlanStatus.draft(),
          plannedBlocks: [
            PlannedBlock(
              id: 'block-1',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 1, 14, 9),
              endTime: DateTime(2026, 1, 14, 11),
            ),
            PlannedBlock(
              id: 'block-2',
              categoryId: 'cat-1',
              startTime: DateTime(2026, 1, 14, 14),
              endTime: DateTime(2026, 1, 14, 15),
            ),
            PlannedBlock(
              id: 'block-3',
              categoryId: 'cat-2',
              startTime: DateTime(2026, 1, 14, 12),
              endTime: DateTime(2026, 1, 14, 13),
            ),
          ],
        );

        expect(data.categoryIds, equals({'cat-1', 'cat-2'}));
      });

      glados.Glados<_GeneratedDayPlanBlocks>(
        glados.any.dayPlanBlocks,
        glados.ExploreConfig(numRuns: 140),
      ).test('derived duration and grouping invariants hold', (generated) {
        final blocks = generated.toBlocks();
        final data = DayPlanData(
          planDate: DateTime(2026, 5, 25),
          status: const DayPlanStatus.draft(),
          plannedBlocks: blocks,
        );

        final expectedCategories = {
          for (final block in blocks) block.categoryId,
        };
        final expectedTotal = blocks.fold(
          Duration.zero,
          (total, block) => total + block.duration,
        );

        expect(data.categoryIds, expectedCategories, reason: '$generated');
        expect(data.totalPlannedDuration, expectedTotal, reason: '$generated');

        for (final categoryId in expectedCategories) {
          final categoryBlocks = data.blocksForCategory(categoryId);
          expect(
            categoryBlocks.every((block) => block.categoryId == categoryId),
            isTrue,
            reason: '$generated',
          );
          expect(
            categoryBlocks.map((block) => block.id),
            unorderedEquals(
              blocks
                  .where((block) => block.categoryId == categoryId)
                  .map((block) => block.id),
            ),
            reason: '$generated',
          );
          for (var i = 1; i < categoryBlocks.length; i++) {
            expect(
              categoryBlocks[i].startTime.isBefore(
                categoryBlocks[i - 1].startTime,
              ),
              isFalse,
              reason: '$generated',
            );
          }
        }

        final budgets = data.derivedBudgets;
        expect(budgets.length, expectedCategories.length, reason: '$generated');
        for (final budget in budgets) {
          final expectedDuration = blocks
              .where((block) => block.categoryId == budget.categoryId)
              .fold(
                Duration.zero,
                (total, block) => total + block.duration,
              );
          expect(
            budget.plannedDuration,
            expectedDuration,
            reason: '$generated',
          );
        }
        for (var i = 1; i < budgets.length; i++) {
          expect(
            budgets[i].blocks.first.startTime.isBefore(
              budgets[i - 1].blocks.first.startTime,
            ),
            isFalse,
            reason: '$generated',
          );
        }
      }, tags: 'glados');

      glados.Glados<_GeneratedDayPlanBlocks>(
        glados.any.dayPlanBlocks,
        glados.ExploreConfig(numRuns: 120),
      ).test('round-trips generated day-plan data through JSON', (generated) {
        final data = DayPlanData(
          planDate: DateTime(2026, 5, 25),
          status: const DayPlanStatus.draft(),
          plannedBlocks: generated.toBlocks(),
          pinnedTasks: generated.toPinnedTasks(),
        );

        final decoded = DayPlanData.fromJson(
          jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
        );

        expect(decoded, data, reason: '$generated');
      }, tags: 'glados');
    });

    group('DayPlanReviewReason', () {
      test('all reasons can be serialized', () {
        for (final reason in DayPlanReviewReason.values) {
          final status = DayPlanStatus.needsReview(
            triggeredAt: DateTime(2026, 1, 14),
            reason: reason,
          );

          final json = jsonEncode(status.toJson());
          final fromJson = DayPlanStatus.fromJson(
            jsonDecode(json) as Map<String, dynamic>,
          );

          expect(
            (fromJson as DayPlanStatusNeedsReview).reason,
            equals(reason),
          );
        }
      });
    });
  });
}

class _GeneratedDayDate {
  const _GeneratedDayDate({
    required this.yearSlot,
    required this.monthSlot,
    required this.daySlot,
    required this.hourSlot,
    required this.minuteSlot,
    required this.secondSlot,
  });

  final int yearSlot;
  final int monthSlot;
  final int daySlot;
  final int hourSlot;
  final int minuteSlot;
  final int secondSlot;

  int get year => 2000 + yearSlot % 50;
  int get month => 1 + monthSlot % 12;
  int get day => 1 + daySlot % 28;
  int get hour => hourSlot % 24;
  int get minute => minuteSlot % 60;
  int get second => secondSlot % 60;

  DateTime get dayOnly => DateTime(year, month, day);
  DateTime get withTime => DateTime(year, month, day, hour, minute, second);

  @override
  String toString() {
    return '_GeneratedDayDate('
        'year: $year, month: $month, day: $day, '
        'hour: $hour, minute: $minute, second: $second)';
  }
}

class _GeneratedDayPlanBlocks {
  const _GeneratedDayPlanBlocks(this.slots);

  final List<int> slots;

  List<PlannedBlock> toBlocks() {
    final count = slots.first % slots.length;
    final base = DateTime(2026, 5, 25);
    return [
      for (var i = 0; i < count; i++)
        PlannedBlock(
          id: 'block-$i-${slots[i]}',
          categoryId: 'cat-${slots[i] % 4}',
          startTime: base.add(Duration(minutes: slots[i] % (24 * 60))),
          endTime: base
              .add(Duration(minutes: slots[i] % (24 * 60)))
              .add(Duration(minutes: 1 + (slots[i] ~/ 4) % 240)),
          note: slots[i].isEven ? 'note-${slots[i]}' : null,
        ),
    ];
  }

  List<PinnedTaskRef> toPinnedTasks() {
    final count = slots.length - slots.first % slots.length;
    return [
      for (var i = 0; i < count; i++)
        PinnedTaskRef(
          taskId: 'task-$i-${slots[i]}',
          categoryId: 'cat-${slots[i] % 4}',
          sortOrder: slots[i] % 7,
        ),
    ];
  }

  @override
  String toString() {
    return '_GeneratedDayPlanBlocks(slots: $slots)';
  }
}

extension _AnyDayPlan on glados.Any {
  glados.Generator<int> get _slot => glados.IntAnys(this).intInRange(0, 100000);

  glados.Generator<_GeneratedDayDate> get dayDate =>
      glados.CombinableAny(this).combine6(
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        (
          int yearSlot,
          int monthSlot,
          int daySlot,
          int hourSlot,
          int minuteSlot,
          int secondSlot,
        ) => _GeneratedDayDate(
          yearSlot: yearSlot,
          monthSlot: monthSlot,
          daySlot: daySlot,
          hourSlot: hourSlot,
          minuteSlot: minuteSlot,
          secondSlot: secondSlot,
        ),
      );

  glados.Generator<_GeneratedDayPlanBlocks> get dayPlanBlocks =>
      glados.CombinableAny(this).combine9(
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        _slot,
        (
          int slot0,
          int slot1,
          int slot2,
          int slot3,
          int slot4,
          int slot5,
          int slot6,
          int slot7,
          int slot8,
        ) => _GeneratedDayPlanBlocks([
          slot0,
          slot1,
          slot2,
          slot3,
          slot4,
          slot5,
          slot6,
          slot7,
          slot8,
        ]),
      );
}
