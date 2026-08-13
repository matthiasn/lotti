import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';

void main() {
  GoalWakeFacts facts(List<GoalMetricObservation> observations) =>
      GoalWakeFacts(
        trackStatus: GoalTrackStatus.atRisk,
        evaluation: const GoalEvaluation(
          attainment: 0.98,
          satisfied: false,
          dataCoverage: 2 / 7,
          results: {
            'health-weight': GoalCriterionResult(
              criterionId: 'health-weight',
              actual: 89,
              target: 88,
              ratio: 0.98,
              satisfied: false,
              sampleCount: 2,
            ),
          },
        ),
        quantitativeObservationsByType: {
          GoalHealthDataTypes.weight: observations,
        },
      );

  test('exact health evidence changes the banner digest but not the aggregate '
      'register digest', () {
    final original = facts([
      GoalMetricObservation(
        recordedAt: DateTime(2026, 8, 8, 8),
        value: 90,
        tieBreaker: 'older',
      ),
      GoalMetricObservation(
        recordedAt: DateTime(2026, 8, 9, 8),
        value: 88,
        tieBreaker: 'latest',
      ),
    ]);
    final backfilled = facts([
      GoalMetricObservation(
        recordedAt: DateTime(2026, 8, 7, 8),
        value: 90,
        tieBreaker: 'backfill',
      ),
      ...original.quantitativeObservationsByType[GoalHealthDataTypes.weight]!,
    ]);
    final reordered = facts([
      ...original
          .quantitativeObservationsByType[GoalHealthDataTypes.weight]!
          .reversed,
    ]);

    expect(
      goalAggregateFactsDigest(backfilled),
      goalAggregateFactsDigest(original),
      reason: 'the persisted aggregate did not change',
    );
    expect(
      goalFactsDigest(backfilled),
      isNot(goalFactsDigest(original)),
      reason: 'banner copy can describe timestamps and sparsity',
    );
    expect(
      goalFactsDigest(reordered),
      goalFactsDigest(original),
      reason: 'query order cannot create replica-specific freshness',
    );
  });
}
