import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart'
    show DayAgentCaptureException;
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_diff.dart';

import '../../../agents/test_data/entity_factories.dart';

void main() {
  final planDate = DateTime(2024, 3, 15);
  final plan = makeTestDayPlan(planDate: planDate);

  PlannedBlock block({
    String id = 'block-1',
    int startHour = 9,
    int endHour = 10,
  }) {
    return PlannedBlock(
      id: id,
      categoryId: 'cat-1',
      startTime: DateTime(2024, 3, 15, startHour),
      endTime: DateTime(2024, 3, 15, endHour),
      title: 'Focus',
      reason: 'placed here originally',
    );
  }

  Map<String, dynamic> rawChange({
    String action = 'moved',
    String? blockId = 'block-1',
    Map<String, dynamic>? from,
    Map<String, dynamic>? to,
  }) {
    return <String, dynamic>{
      'action': action,
      'reason': 'user asked',
      'blockId': ?blockId,
      'from': ?from,
      'to': ?to,
    };
  }

  Map<String, dynamic> snapshot({int startHour = 9, int endHour = 10}) {
    return <String, dynamic>{
      'start': DateTime(2024, 3, 15, startHour).toIso8601String(),
      'end': DateTime(2024, 3, 15, endHour).toIso8601String(),
      'title': 'Focus',
      'categoryId': 'cat-1',
    };
  }

  group('parsePlanDiffChange', () {
    test('a proposed remainder survives into the change args', () {
      // The snapshot parser never read the field, so the schema advertised
      // it, the apply path handled it, and nothing in between carried it.
      final change = parsePlanDiffChange(
        raw: rawChange(
          action: 'added',
          blockId: null,
          to: snapshot()
            ..['taskId'] = 'task-ops'
            ..['remainingMinutes'] = 45,
        ),
        plan: plan,
        blockById: {'block-1': block()},
      );

      expect(change.to?.remainingMinutes, 45);
      expect(change.toArgs()['remainingMinutes'], 45);
    });

    test('a negative proposed remainder is refused', () {
      expect(
        () => parsePlanDiffChange(
          raw: rawChange(
            action: 'added',
            blockId: null,
            to: snapshot()..['remainingMinutes'] = -5,
          ),
          plan: plan,
          blockById: {'block-1': block()},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('parses a moved change with from/to snapshots', () {
      final change = parsePlanDiffChange(
        raw: rawChange(
          from: snapshot(),
          to: snapshot(startHour: 11, endHour: 12),
        ),
        plan: plan,
        blockById: {'block-1': block()},
      );

      expect(change.action, PlanDiffAction.moved);
      expect(change.blockId, 'block-1');
      expect(change.toolName, 'move_block');
      expect(change.to?.start, DateTime(2024, 3, 15, 11));
      expect(change.reason, 'user asked');
    });

    test('rejects unknown actions and missing requirements', () {
      expect(
        () => parsePlanDiffChange(
          raw: rawChange(action: 'teleported'),
          plan: plan,
          blockById: const {},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
      // moved without `to`
      expect(
        () => parsePlanDiffChange(
          raw: rawChange(from: snapshot()),
          plan: plan,
          blockById: {'block-1': block()},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
      // moved referencing an unknown block
      expect(
        () => parsePlanDiffChange(
          raw: rawChange(from: snapshot(), to: snapshot(startHour: 11)),
          plan: plan,
          blockById: const {},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
      // added without title/categoryId
      expect(
        () => parsePlanDiffChange(
          raw: rawChange(
            action: 'added',
            blockId: null,
            to: <String, dynamic>{
              'start': DateTime(2024, 3, 15, 9).toIso8601String(),
              'end': DateTime(2024, 3, 15, 10).toIso8601String(),
            },
          ),
          plan: plan,
          blockById: const {},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('rejects snapshots outside the plan day', () {
      expect(
        () => parsePlanDiffChange(
          raw: rawChange(
            action: 'added',
            blockId: null,
            to: <String, dynamic>{
              'start': DateTime(2024, 3, 16, 9).toIso8601String(),
              'end': DateTime(2024, 3, 16, 10).toIso8601String(),
              'title': 'Focus',
              'categoryId': 'cat-1',
            },
          ),
          plan: plan,
          blockById: const {},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });
  });

  group('applyPlanDiffItem', () {
    ChangeItem item(String toolName, Map<String, dynamic> args) =>
        ChangeItem(toolName: toolName, args: args, humanSummary: 's');

    test('add_block files the block under its task category', () {
      // The accepted-diff door of the same rule the draft path enforces.
      // Fixing only one of them is how the original mismatch arose.
      final result = applyPlanDiffItem(
        item('add_block', {
          'categoryId': 'cat-1',
          'toStart': DateTime(2024, 3, 15, 14).toIso8601String(),
          'toEnd': DateTime(2024, 3, 15, 15).toIso8601String(),
          'title': 'Ops work',
          'taskId': 'task-ops',
          'blockReason': 'why',
        }),
        const [],
        addedBlockState: PlannedBlockState.drafted,
        taskCategoryIds: const {'task-ops': 'cat-ops'},
      );

      expect(result.single.categoryId, 'cat-ops');
    });

    test('add_block carries a declared remainder onto the new block', () {
      final result = applyPlanDiffItem(
        item('add_block', {
          'categoryId': 'cat-1',
          'toStart': DateTime(2024, 3, 15, 14).toIso8601String(),
          'toEnd': DateTime(2024, 3, 15, 15).toIso8601String(),
          'title': 'Ops work',
          'taskId': 'task-ops',
          'blockReason': 'why',
          'remainingMinutes': 45,
        }),
        const [],
        addedBlockState: PlannedBlockState.drafted,
        taskCategoryIds: const {'task-ops': 'cat-ops'},
      );

      expect(result.single.remainingMinutes, 45);
    });

    test(
      'move_block updates the remainder it is given, keeps it otherwise',
      () {
        // Resizing a partial block changes the arithmetic, so a refine that
        // shortens one must be able to restate what is left — and a move that
        // says nothing about it must not silently drop it.
        final partial = block().copyWith(
          taskId: 'task-ops',
          remainingMinutes: 60,
        );
        final resized = applyPlanDiffItem(
          item('move_block', {
            'blockId': 'block-1',
            'toEnd': DateTime(2024, 3, 15, 15).toIso8601String(),
            'remainingMinutes': 30,
          }),
          [partial],
          addedBlockState: PlannedBlockState.drafted,
        );
        final untouched = applyPlanDiffItem(
          item('move_block', {
            'blockId': 'block-1',
            'toStart': DateTime(2024, 3, 15, 14).toIso8601String(),
          }),
          [partial],
          addedBlockState: PlannedBlockState.drafted,
        );

        expect(resized.single.remainingMinutes, 30);
        expect(untouched.single.remainingMinutes, 60);
      },
    );

    test('move_block re-derives the category even when only times move', () {
      // Applied at acceptance, not only at proposal: a change set written
      // before this rule — or by a peer on an older build — is filed
      // correctly when the user accepts it, rather than persisting the old
      // mismatch.
      final result = applyPlanDiffItem(
        item('move_block', {
          'blockId': 'block-1',
          'toStart': DateTime(2024, 3, 15, 14).toIso8601String(),
          'toEnd': DateTime(2024, 3, 15, 15).toIso8601String(),
        }),
        [block().copyWith(taskId: 'task-ops')],
        addedBlockState: PlannedBlockState.drafted,
        taskCategoryIds: const {'task-ops': 'cat-ops'},
      );

      expect(result.single.categoryId, 'cat-ops');
    });

    test('move_block ignores a category that disagrees with the task', () {
      final result = applyPlanDiffItem(
        item('move_block', {
          'blockId': 'block-1',
          'categoryId': 'cat-1',
          'taskId': 'task-ops',
        }),
        [block()],
        addedBlockState: PlannedBlockState.drafted,
        taskCategoryIds: const {'task-ops': 'cat-ops'},
      );

      expect(result.single.categoryId, 'cat-ops');
    });

    test('a block with no task keeps the category the change supplied', () {
      final result = applyPlanDiffItem(
        item('add_block', {
          'categoryId': 'cat-1',
          'toStart': DateTime(2024, 3, 15, 14).toIso8601String(),
          'toEnd': DateTime(2024, 3, 15, 15).toIso8601String(),
          'title': 'Buffer',
          'blockReason': 'why',
        }),
        const [],
        addedBlockState: PlannedBlockState.drafted,
      );

      expect(result.single.categoryId, 'cat-1');
    });

    test('move_block updates times and keeps the block reason', () {
      final result = applyPlanDiffItem(
        item('move_block', {
          'blockId': 'block-1',
          'toStart': DateTime(2024, 3, 15, 14).toIso8601String(),
          'toEnd': DateTime(2024, 3, 15, 15).toIso8601String(),
        }),
        [block()],
        addedBlockState: PlannedBlockState.drafted,
      );

      expect(result.single.startTime, DateTime(2024, 3, 15, 14));
      expect(result.single.endTime, DateTime(2024, 3, 15, 15));
      // The change-level reason must not clobber the block's own reason.
      expect(result.single.reason, 'placed here originally');
    });

    test('add_block appends a new block in the requested state', () {
      final result = applyPlanDiffItem(
        item('add_block', {
          'categoryId': 'cat-2',
          'toStart': DateTime(2024, 3, 15, 16).toIso8601String(),
          'toEnd': DateTime(2024, 3, 15, 17).toIso8601String(),
          'title': 'New block',
          'blockReason': 'fills the gap',
        }),
        [block()],
        addedBlockState: PlannedBlockState.committed,
      );

      expect(result, hasLength(2));
      final added = result.last;
      expect(added.categoryId, 'cat-2');
      expect(added.title, 'New block');
      expect(added.state, PlannedBlockState.committed);
      expect(added.reason, 'fills the gap');
      expect(added.id, startsWith('block_'));
    });

    test('drop_block removes the block and rejects unknown ids', () {
      final result = applyPlanDiffItem(
        item('drop_block', {'blockId': 'block-1'}),
        [block()],
        addedBlockState: PlannedBlockState.drafted,
      );
      expect(result, isEmpty);

      expect(
        () => applyPlanDiffItem(
          item('drop_block', {'blockId': 'nope'}),
          [block()],
          addedBlockState: PlannedBlockState.drafted,
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });
  });

  group('validateApplicablePlanDiffBatch', () {
    ChangeItem item(String toolName, Map<String, dynamic> args) =>
        ChangeItem(toolName: toolName, args: args, humanSummary: 's');
    final planWithBlock = makeTestDayPlan(
      planDate: planDate,
      data: DayPlanData(
        planDate: planDate,
        status: const DayPlanStatus.draft(),
        plannedBlocks: [block()],
      ),
    );
    String at(int hour) => DateTime(2024, 3, 15, hour).toIso8601String();
    Map<String, dynamic> addArgs({
      int startHour = 14,
      Object? type,
      Object? taskId,
    }) => {
      'categoryId': 'cat-1',
      'toStart': at(startHour),
      'toEnd': at(startHour + 1),
      'type': ?type,
      'taskId': ?taskId,
    };
    void validate(
      ChangeItem change, {
      DateTime? earliestStart,
      Set<String> allowedTaskIds = const {},
    }) => validateApplicablePlanDiffBatch(
      [MapEntry(0, change)],
      planWithBlock,
      const {'cat-1'},
      earliestStart: earliestStart,
      allowedTaskIds: allowedTaskIds,
    );
    Matcher refusedWith(String fragment) => throwsA(
      isA<DayAgentCaptureException>().having(
        (e) => e.message,
        'message',
        contains(fragment),
      ),
    );

    test('an add or a relocation into the past is refused once the day is '
        'under way, but a move that restates its own start is not', () {
      final now = DateTime(2024, 3, 15, 12);

      expect(
        () => validate(
          item('add_block', addArgs(startHour: 11)),
          earliestStart: now,
        ),
        refusedWith('toStart would place the block before the current time'),
      );
      expect(
        () => validate(
          item('move_block', {
            'blockId': 'block-1',
            'toStart': at(8),
          }),
          earliestStart: now,
        ),
        refusedWith('before the current time'),
      );
      // The block already began at 09:00; re-stating that start while
      // stretching its end is not planning the past.
      expect(
        () => validate(
          item('move_block', {
            'blockId': 'block-1',
            'toStart': at(9),
            'toEnd': at(13),
          }),
          earliestStart: now,
        ),
        returnsNormally,
      );
      // On a day that is not today there is no floor at all.
      expect(
        () => validate(item('add_block', addArgs(startHour: 11))),
        returnsNormally,
      );
    });

    test('a calendar-mirror block type is refused on add and move', () {
      expect(
        () => validate(item('add_block', addArgs(type: 'cal'))),
        refusedWith('cal mirrors an imported calendar event'),
      );
      expect(
        () => validate(
          item('move_block', {'blockId': 'block-1', 'type': 'cal'}),
        ),
        refusedWith('cal mirrors an imported calendar event'),
      );
      expect(
        () => validate(item('add_block', addArgs(type: 'buffer'))),
        returnsNormally,
      );
    });

    test('a task link must be one the plan is allowed to reference', () {
      expect(
        () => validate(
          item('add_block', addArgs(taskId: 'task-foreign')),
          allowedTaskIds: const {'task-ops'},
        ),
        refusedWith('taskId task-foreign is not an allowed task'),
      );
      expect(
        () => validate(
          item('move_block', {'blockId': 'block-1', 'taskId': 'task-x'}),
        ),
        refusedWith('taskId task-x is not an allowed task'),
      );
      expect(
        () => validate(
          item('add_block', addArgs(taskId: 'task-ops')),
          allowedTaskIds: const {'task-ops'},
        ),
        returnsNormally,
      );
    });
  });

  group('applyPlanDiffItem guards', () {
    test('move_block on a block that is not in the list fails cleanly', () {
      expect(
        () => applyPlanDiffItem(
          const ChangeItem(
            toolName: 'move_block',
            args: {'blockId': 'ghost'},
            humanSummary: 's',
          ),
          [block()],
          addedBlockState: PlannedBlockState.drafted,
        ),
        throwsA(
          isA<DayAgentCaptureException>().having(
            (e) => e.message,
            'message',
            contains('blockId ghost not found in plan'),
          ),
        ),
      );
    });
  });

  group('stateForAcceptedAddedBlock', () {
    test('commits blocks only for agreed or committed plans', () {
      expect(
        stateForAcceptedAddedBlock(
          DayPlanStatus.agreed(agreedAt: DateTime(2024, 3, 15)),
        ),
        PlannedBlockState.committed,
      );
      expect(
        stateForAcceptedAddedBlock(
          DayPlanStatus.committed(committedAt: DateTime(2024, 3, 15)),
        ),
        PlannedBlockState.committed,
      );
      expect(
        stateForAcceptedAddedBlock(const DayPlanStatus.draft()),
        PlannedBlockState.drafted,
      );
    });
  });
}
