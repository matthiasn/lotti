import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';

void main() {
  const criteria = GoalCriterion.metric(
    criterionId: 'health-weight',
    dataType: GoalHealthDataTypes.weight,
    window: GoalWindow.rollingDays(count: 7),
    aggregation: GoalAggregation.dailySumThenAverage,
    target: 88,
    direction: GoalDirection.atMost,
  );
  final reference = DateTime(2026, 8, 9, 12);

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
      goalFactsDigest(
        backfilled,
        criteria: criteria,
        evaluationReference: reference,
      ),
      isNot(
        goalFactsDigest(
          original,
          criteria: criteria,
          evaluationReference: reference,
        ),
      ),
      reason: 'banner copy can describe timestamps and sparsity',
    );
    expect(
      goalFactsDigest(
        reordered,
        criteria: criteria,
        evaluationReference: reference,
      ),
      goalFactsDigest(
        original,
        criteria: criteria,
        evaluationReference: reference,
      ),
      reason: 'query order cannot create replica-specific freshness',
    );
  });

  test(
    'exact digest ignores prior-period samples absent from rendered facts',
    () {
      final current = facts([
        GoalMetricObservation(
          recordedAt: DateTime(2026, 8, 8, 8),
          value: 88,
        ),
      ]);
      final withPriorPeriodBackfill = facts([
        GoalMetricObservation(
          recordedAt: DateTime(2026, 8, 2, 8),
          value: 91,
        ),
        ...current.quantitativeObservationsByType[GoalHealthDataTypes.weight]!,
      ]);

      expect(
        goalFactsDigest(
          withPriorPeriodBackfill,
          criteria: criteria,
          evaluationReference: reference,
        ),
        goalFactsDigest(
          current,
          criteria: criteria,
          evaluationReference: reference,
        ),
        reason: 'banner freshness must hash only model-facing window evidence',
      );
    },
  );

  test(
    'composite freshness visits nested health and ignores non-health leaves',
    () {
      const composite = GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [
          GoalCriterion.metric(
            criterionId: 'steps',
            dataType: 'cumulative_step_count',
            window: GoalWindow.day(),
            aggregation: GoalAggregation.sum,
            target: 10000,
          ),
          GoalCriterion.habit(
            criterionId: 'habit',
            habitId: 'meds',
            window: GoalWindow.day(),
            targetCount: 1,
          ),
          GoalCriterion.measurable(
            criterionId: 'water',
            dataTypeId: 'water-id',
            window: GoalWindow.day(),
            aggregation: GoalAggregation.sum,
            target: 2000,
          ),
          GoalCriterion.categoryTime(
            criterionId: 'sleep',
            categoryId: 'sleep-id',
            window: GoalWindow.day(),
            aggregation: GoalAggregation.sum,
            targetHours: 8,
          ),
          GoalCriterion.anyOf(
            criterionId: 'health-choice',
            criteria: [
              GoalCriterion.atLeastCount(
                criterionId: 'health-count',
                successes: 1,
                criteria: [criteria],
              ),
            ],
          ),
        ],
      );
      final original = facts([
        GoalMetricObservation(
          recordedAt: DateTime(2026, 8, 8, 8),
          value: 88,
        ),
      ]);
      final changed = facts([
        GoalMetricObservation(
          recordedAt: DateTime(2026, 8, 8, 8),
          value: 87,
        ),
      ]);

      expect(
        goalFactsDigest(
          changed,
          criteria: composite,
          evaluationReference: reference,
        ),
        isNot(
          goalFactsDigest(
            original,
            criteria: composite,
            evaluationReference: reference,
          ),
        ),
        reason: 'only the nested model-facing health series changes the digest',
      );
    },
  );

  test('label-time markdown changes the model-facing facts digest', () {
    const labelCriteria = GoalCriterion.labelTime(
      criterionId: 'daily-content',
      labelId: 'content',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 1,
    );
    GoalWakeFacts labelFacts(String markdown) => GoalWakeFacts(
      trackStatus: GoalTrackStatus.atRisk,
      evaluation: const GoalEvaluation(
        attainment: 0.75,
        satisfied: false,
        dataCoverage: 1,
        results: {
          'daily-content': GoalCriterionResult(
            criterionId: 'daily-content',
            actual: 0.75,
            target: 1,
            ratio: 0.75,
            satisfied: false,
            sampleCount: 1,
          ),
        },
      ),
      labelTimeEntriesByCriterion: {
        'daily-content': [
          GoalLabelTimeEntryEvidence(
            entryId: 'entry-1',
            labelId: 'content',
            dateFrom: DateTime(2026, 8, 9, 9),
            dateTo: DateTime(2026, 8, 9, 9, 45),
            markdown: markdown,
          ),
        ],
      },
    );

    final original = labelFacts('Drafted **three** sections.');
    final revised = labelFacts('Drafted **four** sections.');

    expect(
      goalAggregateFactsDigest(revised),
      goalAggregateFactsDigest(original),
    );
    expect(
      goalFactsDigest(
        revised,
        criteria: labelCriteria,
        evaluationReference: reference,
      ),
      isNot(
        goalFactsDigest(
          original,
          criteria: labelCriteria,
          evaluationReference: reference,
        ),
      ),
    );
  });

  test('label-time digest matches the bounded model-facing evidence', () {
    const labelCriteria = GoalCriterion.labelTime(
      criterionId: 'daily-content',
      labelId: 'content',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetHours: 1,
    );
    final entries = [
      for (var index = 0; index < 201; index++)
        GoalLabelTimeEntryEvidence(
          entryId: 'entry-$index',
          labelId: 'content',
          categoryId: 'work',
          dateFrom: DateTime(2026).add(Duration(minutes: index)),
          dateTo: DateTime(2026).add(Duration(minutes: index + 1)),
          markdown: 'Entry $index',
        ),
    ];
    GoalWakeFacts boundedFacts(List<GoalLabelTimeEntryEvidence> evidence) =>
        GoalWakeFacts(
          trackStatus: GoalTrackStatus.atRisk,
          evaluation: const GoalEvaluation(
            attainment: 0.75,
            satisfied: false,
            dataCoverage: 1,
            results: {
              'daily-content': GoalCriterionResult(
                criterionId: 'daily-content',
                actual: 0.75,
                target: 1,
                ratio: 0.75,
                satisfied: false,
                sampleCount: 1,
              ),
            },
          ),
          labelTimeEntriesByCriterion: {'daily-content': evidence},
        );
    String digest(List<GoalLabelTimeEntryEvidence> evidence) => goalFactsDigest(
      boundedFacts(evidence),
      criteria: labelCriteria,
      evaluationReference: reference,
    );

    final changedOmitted = [
      GoalLabelTimeEntryEvidence(
        entryId: entries.first.entryId,
        labelId: entries.first.labelId,
        categoryId: entries.first.categoryId,
        dateFrom: entries.first.dateFrom,
        dateTo: entries.first.dateTo,
        markdown: 'Changed omitted entry',
      ),
      ...entries.skip(1),
    ];
    final changedRetained = [
      ...entries.take(entries.length - 1),
      GoalLabelTimeEntryEvidence(
        entryId: entries.last.entryId,
        labelId: entries.last.labelId,
        categoryId: 'personal',
        dateFrom: entries.last.dateFrom,
        dateTo: entries.last.dateTo,
        markdown: 'Changed retained entry',
      ),
    ];

    expect(digest(changedOmitted), digest(entries));
    expect(digest(changedRetained), isNot(digest(entries)));
  });
}
