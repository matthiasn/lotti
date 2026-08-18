import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_data.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';

/// A two-leaf criteria tree referencing a habit and a measurable data type —
/// the two definition kinds a goal most commonly binds to. Used to prove the
/// nested tree survives serialization rather than collapsing to its root.
const _criteria = GoalCriterion.allOf(
  criterionId: 'root',
  criteria: [
    GoalCriterion.habit(
      criterionId: 'walk-daily',
      habitId: 'habit-walk',
      targetCount: 5,
      window: GoalWindow.rollingDays(count: 7),
    ),
    GoalCriterion.measurable(
      criterionId: 'systolic',
      dataTypeId: 'measurable-systolic',
      target: 130,
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.dailySumThenAverage,
      direction: GoalDirection.atMost,
    ),
  ],
);

void main() {
  group('GoalData', () {
    test('round-trips through JSON with the criteria tree intact', () {
      final data = GoalData(
        title: 'Blood pressure',
        statement: 'Average under 130 systolic over a rolling week.',
        criteria: _criteria,
        specVersion: 3,
        specVersionId: 'snapshot-v3',
        startDate: DateTime.utc(2026, 8, 3),
        targetDate: DateTime.utc(2026, 12, 31),
        rationale: 'Cardiologist asked for a three-month trend.',
      );

      final restored = GoalData.fromJson(
        jsonDecode(jsonEncode(data)) as Map<String, dynamic>,
      );

      expect(restored, data);
      // The tree specifically: a shallow copyWith-style comparison would pass
      // even if the children were dropped, since equality is structural only
      // when the children actually survive.
      final root = restored.criteria as GoalCriterionAllOf;
      expect(root.criteria, hasLength(2));
      expect(
        root.criteria.whereType<GoalCriterionHabit>().single.habitId,
        'habit-walk',
      );
      expect(
        root.criteria.whereType<GoalCriterionMeasurable>().single.dataTypeId,
        'measurable-systolic',
      );
    });

    test(
      'a goal is not a snapshot; a snapshot names the goal it belongs to',
      () {
        const goal = GoalData(
          title: 'Blood pressure',
          statement: 'Average under 130 systolic over a rolling week.',
          criteria: _criteria,
          specVersion: 3,
          specVersionId: 'snapshot-v3',
        );
        final snapshot = goal.copyWith(snapshotOf: 'goal-1');

        expect(goal.snapshotOf, isNull);
        expect(goal.isSpecSnapshot, isFalse);
        expect(snapshot.isSpecSnapshot, isTrue);
        expect(snapshot.snapshotOf, 'goal-1');
      },
    );

    test('a serialized goal still resolves the definitions it references', () {
      // The reason a goal belongs in the journal database at all: its
      // referents are journal-side definitions. Resolve them from the
      // ROUND-TRIPPED tree, so a serialization that silently dropped a
      // criterion id fails here rather than at evaluation time.
      final restored = GoalData.fromJson(
        jsonDecode(
              jsonEncode(
                const GoalData(
                  title: 'Blood pressure',
                  statement: 'Average under 130 systolic over a rolling week.',
                  criteria: _criteria,
                  specVersion: 1,
                  specVersionId: 'snapshot-v1',
                ),
              ),
            )
            as Map<String, dynamic>,
      );

      expect(goalCriterionHabitIds(restored.criteria), {'habit-walk'});
    });
  });
}
