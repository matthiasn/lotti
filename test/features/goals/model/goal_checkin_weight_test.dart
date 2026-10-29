import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/model/goal_checkin_weight.dart';

void main() {
  const checkInTime = GoalCriterion.checkInTime(
    criterionId: 'journal',
    window: GoalWindow.rollingDays(count: 7),
    aggregation: GoalAggregation.sum,
    targetMinutes: 70,
  );
  const habit = GoalCriterion.habit(
    criterionId: 'walk',
    habitId: 'habit-walk',
    window: GoalWindow.rollingDays(count: 7),
    targetCount: 3,
  );

  test('check-ins are the substance of a goal measured by them, wherever the '
      'leaf sits in the tree', () {
    expect(GoalCheckInWeight.of(checkInTime), GoalCheckInWeight.substance);
    expect(
      GoalCheckInWeight.of(
        const GoalCriterion.anyOf(
          criterionId: 'root',
          criteria: [habit, checkInTime],
        ),
      ),
      GoalCheckInWeight.substance,
    );
  });

  test('and context for a goal measured by anything else', () {
    expect(GoalCheckInWeight.of(habit), GoalCheckInWeight.context);
  });
}
