import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/model/goal_checkin_weight.dart';

import '../../agents/test_data/entity_factories.dart';

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

  GoalCheckInWeight weightOf(
    GoalCriterion criteria, {
    bool? checkInsAreSubstance,
  }) => GoalCheckInWeight.of(
    makeTestGoalSpecVersion(
      criteria: criteria,
      checkInsAreSubstance: checkInsAreSubstance,
    ),
  );

  test('check-ins are the substance of a goal measured by them, wherever the '
      'leaf sits in the tree', () {
    expect(weightOf(checkInTime), GoalCheckInWeight.substance);
    expect(
      weightOf(
        const GoalCriterion.anyOf(
          criterionId: 'root',
          criteria: [habit, checkInTime],
        ),
      ),
      GoalCheckInWeight.substance,
    );
  });

  test('and context for a goal measured by anything else', () {
    expect(weightOf(habit), GoalCheckInWeight.context);
  });

  test("the user's say outranks the criteria, in both directions", () {
    // A journal tracked by a habit tick is still a journal.
    expect(
      weightOf(habit, checkInsAreSubstance: true),
      GoalCheckInWeight.substance,
    );
    // Minutes of reflection can be counted without the words being the goal.
    expect(
      weightOf(checkInTime, checkInsAreSubstance: false),
      GoalCheckInWeight.context,
    );
  });
}
