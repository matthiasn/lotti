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
