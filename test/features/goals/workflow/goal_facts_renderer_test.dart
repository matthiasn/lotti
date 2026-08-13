import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';
import 'package:lotti/features/goals/workflow/goal_facts_renderer.dart';

void main() {
  const renderer = GoalFactsRenderer();
  final now = DateTime(2026, 8, 9, 12);
  final fixedClock = Clock.fixed(now);

  GoalSpecVersionEntity version({GoalCriterion? criteria}) =>
      AgentDomainEntity.goalSpecVersion(
            id: 'goal-1:spec-v1',
            agentId: 'goal-1',
            version: 1,
            status: GoalSpecVersionStatus.active,
            authoredBy: 'user',
            title: 'Steps',
            statement: 'Average 10,000 steps per day over a rolling week.',
            criteria:
                criteria ??
                const GoalCriterion.metric(
                  criterionId: 'steps',
                  dataType: 'cumulative_step_count',
                  window: GoalWindow.rollingDays(count: 7),
                  aggregation: GoalAggregation.dailySumThenAverage,
                  target: 10000,
                ),
            createdAt: DateTime(2026),
            vectorClock: null,
          )
          as GoalSpecVersionEntity;

  GoalWakeFacts facts({
    GoalTrackStatus status = GoalTrackStatus.offTrack,
    GoalTrackStatus? previous = GoalTrackStatus.atRisk,
    int? deficit,
    int? buffer,
    int? projectedDaysToTarget,
    bool onTrackByTrend = false,
    Map<String, List<GoalCategoryTimeSession>> categoryTimeSessions = const {},
    DateTime? categoryTimeEvidenceStart,
    DateTime? categoryTimeEvidenceEnd,
  }) => GoalWakeFacts(
    trackStatus: status,
    previousStatus: previous,
    evaluation: GoalEvaluation(
      attainment: 0.64,
      satisfied: false,
      dataCoverage: 1,
      deficit: deficit,
      buffer: buffer,
      onTrackByTrend: onTrackByTrend,
      results: {
        'steps': GoalCriterionResult(
          criterionId: 'steps',
          actual: 6400,
          target: 10000,
          ratio: 0.64,
          satisfied: false,
          sampleCount: 7,
          deficit: deficit,
          buffer: buffer,
          projectedDaysToTarget: projectedDaysToTarget,
        ),
      },
    ),
    shortTermAttainment: 0.5,
    categoryTimeSessionsByCategory: categoryTimeSessions,
    categoryTimeEvidenceStart: categoryTimeEvidenceStart,
    categoryTimeEvidenceEnd: categoryTimeEvidenceEnd,
  );

  GoalNudgeEntity nudge({
    required String id,
    required GoalNudgeStatus status,
    List<GoalNudgeRating> ratings = const [],
    DateTime? activatedAt,
    DateTime? dismissedAt,
    DateTime? staleAt,
    int activationCount = 1,
    List<GoalNudgeSnooze> snoozeHistory = const [],
  }) =>
      AgentDomainEntity.goalNudge(
            id: id,
            agentId: 'goal-1',
            status: status,
            brief: const GoalNudgeBrief(
              headline: 'Your inner couch potato is winning.',
              tagline: 'Six days of quiet shoes.',
              tone: GoalNudgeTone.nudge,
              animation: GoalBannerAnimation.pulse,
            ),
            briefDigest: 'digest-$id',
            createdAt: DateTime(2026, 8, 8),
            updatedAt: DateTime(2026, 8, 8),
            vectorClock: null,
            ratings: ratings,
            activatedAt: activatedAt,
            dismissedAt: dismissedAt,
            staleAt: staleAt,
            activationCount: activationCount,
            snoozeHistory: snoozeHistory,
          )
          as GoalNudgeEntity;

  Map<String, dynamic> renderedJson({
    List<GoalNudgeEntity> nudges = const [],
    GoalWakeFacts? wakeFacts,
    List<GoalProgressEntity> priors = const [],
    GoalCriterion? criteria,
    DateTime? evaluationReference,
  }) {
    final text = withClock(
      fixedClock,
      () => renderer.render(
        version: version(criteria: criteria),
        facts: wakeFacts ?? facts(),
        priorRegisters: priors,
        nudges: nudges,
        evaluationReference: evaluationReference ?? now,
      ),
    );
    expect(
      text,
      startsWith('FACTS (deterministic, authoritative'),
      reason: 'the labelled fence is part of the validated contract',
    );
    final fence = text.substring(
      text.indexOf('```json\n') + 8,
      text.lastIndexOf('\n```'),
    );
    return jsonDecode(fence) as Map<String, dynamic>;
  }

  test('renders the exact section vocabulary the evals validated', () {
    final json = renderedJson();
    expect(json.keys, {
      'generatedAt',
      'localTime',
      'goal',
      'evaluation',
      'reporting',
      'ads',
      'personaTone',
      'unansweredUserMessages',
      'observations',
    });
    final localTime = json['localTime'] as Map<String, dynamic>;
    expect(localTime['iso8601'], isA<String>());
    expect(localTime['utcOffsetMinutes'], isA<int>());
    expect(localTime['timeZoneName'], isA<String>());
    final evaluation = json['evaluation'] as Map<String, dynamic>;
    expect(evaluation['referenceIsCurrentDay'], isTrue);
    expect(evaluation['todayGuidance'], {
      'healthLoggingCompleteCriterionIds': <String>[],
      'healthLoggingNeededCriterionIds': <String>[],
      'rollingHabitCriterionIdsBehind': <String>[],
    });
    expect(evaluation['trackStatus'], 'offTrack');
    expect(evaluation['attainment'], 0.64);
    expect(evaluation['trailing3DayAttainment'], 0.5);
    final reporting = json['reporting'] as Map<String, dynamic>;
    expect(reporting['materialChangeSinceLastReport'], isTrue);
    expect(reporting['lastReportStatus'], 'atRisk');
    final goal = json['goal'] as Map<String, dynamic>;
    expect(
      (goal['criteria'] as Map<String, dynamic>)['window'],
      'rolling 7 days',
    );
  });

  test('marks a delayed evaluation reference as historical', () {
    final json = renderedJson(
      evaluationReference: DateTime(2026, 8, 8, 23, 59, 59),
    );
    final evaluation = json['evaluation'] as Map<String, dynamic>;
    expect(evaluation['referenceIsCurrentDay'], isFalse);
  });

  test('rolling-window recovery facts reach the authoritative block so the '
      'agent can restate them without recomputing', () {
    final json = renderedJson(wakeFacts: facts(deficit: 2, buffer: 1));
    final evaluation = json['evaluation'] as Map<String, dynamic>;
    // Root-level, and per-criterion.
    expect(evaluation['daysToRecover'], 2);
    expect(evaluation['bufferDays'], 1);
    final steps = (evaluation['criterionResults'] as List).single;
    expect((steps as Map<String, dynamic>)['daysToRecover'], 2);
    expect(steps['bufferDays'], 1);
  });

  test('health trend projections reach the authoritative facts block', () {
    final json = renderedJson(
      wakeFacts: facts(projectedDaysToTarget: 12, onTrackByTrend: true),
    );
    final evaluation = json['evaluation'] as Map<String, dynamic>;
    expect(evaluation['onTrackByTrend'], isTrue);
    final result = (evaluation['criterionResults'] as List).single;
    expect(
      (result as Map<String, dynamic>)['projectedDaysToTarget'],
      12,
    );
  });

  test('health criteria expose every ordered observation and latest-day '
      'status alongside the rolling aggregate', () {
    const criteria = GoalCriterion.allOf(
      criterionId: 'blood-pressure-and-weight',
      criteria: [
        GoalCriterion.metric(
          criterionId: 'health-blood-pressure-systolic',
          dataType: GoalHealthDataTypes.bloodPressureSystolic,
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 125,
          direction: GoalDirection.atMost,
        ),
        GoalCriterion.metric(
          criterionId: 'health-blood-pressure-diastolic',
          dataType: GoalHealthDataTypes.bloodPressureDiastolic,
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 85,
          direction: GoalDirection.atMost,
        ),
        GoalCriterion.metric(
          criterionId: 'health-weight',
          dataType: GoalHealthDataTypes.weight,
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 88,
          direction: GoalDirection.atMost,
        ),
      ],
    );
    GoalCriterionResult result({
      required String id,
      required num actual,
      required num target,
      required int sampleCount,
    }) => GoalCriterionResult(
      criterionId: id,
      actual: actual,
      target: target,
      ratio: target / actual,
      satisfied: false,
      sampleCount: sampleCount,
    );
    final json = renderedJson(
      criteria: criteria,
      wakeFacts: GoalWakeFacts(
        trackStatus: GoalTrackStatus.insufficientData,
        evaluation: GoalEvaluation(
          attainment: 0.94,
          satisfied: false,
          dataCoverage: 2 / 7,
          results: {
            'health-blood-pressure-systolic': result(
              id: 'health-blood-pressure-systolic',
              actual: 127,
              target: 125,
              sampleCount: 2,
            ),
            'health-blood-pressure-diastolic': result(
              id: 'health-blood-pressure-diastolic',
              actual: 89,
              target: 85,
              sampleCount: 2,
            ),
            'health-weight': result(
              id: 'health-weight',
              actual: 95,
              target: 88,
              sampleCount: 3,
            ),
          },
        ),
        quantitativeObservationsByType: {
          GoalHealthDataTypes.bloodPressureSystolic: [
            GoalMetricObservation(
              recordedAt: DateTime(2026, 8, 9, 11),
              value: 125,
            ),
            GoalMetricObservation(
              recordedAt: DateTime(2026, 8, 2, 21, 48),
              value: 140,
            ),
            GoalMetricObservation(
              recordedAt: DateTime(2026, 8, 8, 21, 48),
              value: 129,
            ),
          ],
          GoalHealthDataTypes.bloodPressureDiastolic: [
            GoalMetricObservation(
              recordedAt: DateTime(2026, 8, 8, 21, 48),
              value: 94,
            ),
            GoalMetricObservation(
              recordedAt: DateTime(2026, 8, 9, 11),
              value: 84,
            ),
          ],
          GoalHealthDataTypes.weight: [
            GoalMetricObservation(
              recordedAt: DateTime(2026, 8, 7, 8),
              value: 96,
            ),
            GoalMetricObservation(
              recordedAt: DateTime(2026, 8, 8, 8),
              value: 95,
            ),
            GoalMetricObservation(
              recordedAt: DateTime(2026, 8, 9, 8),
              value: 94,
            ),
          ],
        },
      ),
    );
    final evaluation = json['evaluation'] as Map<String, dynamic>;
    expect(evaluation['todayGuidance'], {
      'healthLoggingCompleteCriterionIds': [
        'health-blood-pressure-diastolic',
        'health-blood-pressure-systolic',
      ],
      'healthLoggingNeededCriterionIds': <String>[],
      'rollingHabitCriterionIdsBehind': <String>[],
    });
    final results = (evaluation['criterionResults'] as List)
        .cast<Map<String, dynamic>>();
    Map<String, dynamic> healthSeries(String criterionId) =>
        results.singleWhere(
              (entry) => entry['criterionId'] == criterionId,
            )['healthSeries']
            as Map<String, dynamic>;

    final systolic = healthSeries('health-blood-pressure-systolic');
    expect(systolic['observationCount'], 2);
    expect(systolic['observationsOmitted'], 0);
    expect(systolic['observations'], [
      {'recordedAt': '2026-08-08T21:48:00.000', 'value': 129},
      {'recordedAt': '2026-08-09T11:00:00.000', 'value': 125},
    ]);
    expect(systolic['latest'], {
      'recordedAt': '2026-08-09T11:00:00.000',
      'value': 125,
      'onTarget': true,
      'isToday': true,
      'todayStatus': 'completeOnTarget',
    });
    expect(systolic['latestChange'], {
      'fromValue': 129,
      'toValue': 125,
      'direction': 'towardTarget',
    });
    expect(
      (healthSeries('health-blood-pressure-diastolic')['latest']
          as Map<String, dynamic>)['onTarget'],
      isTrue,
    );
    expect(
      (healthSeries('health-weight')['observations'] as List)
          .map((entry) => (entry as Map<String, dynamic>)['value'])
          .toList(),
      [96, 95, 94],
    );
    expect(
      (healthSeries('health-weight')['latest']
          as Map<String, dynamic>)['todayStatus'],
      'measuredOffTarget',
    );
    expect(healthSeries('health-weight')['latestChange'], {
      'fromValue': 95,
      'toValue': 94,
      'direction': 'towardTarget',
    });
  });

  test(
    'today guidance keeps unmeasured health and rolling habits actionable',
    () {
      const criteria = GoalCriterion.allOf(
        criterionId: 'health-routine',
        criteria: [
          GoalCriterion.metric(
            criterionId: 'health-weight',
            dataType: GoalHealthDataTypes.weight,
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 88,
            direction: GoalDirection.atMost,
          ),
          GoalCriterion.habit(
            criterionId: 'habit-bp-meds',
            habitId: 'habit-bp-meds',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 7,
          ),
        ],
      );
      final json = renderedJson(
        criteria: criteria,
        evaluationReference: DateTime(2026, 8, 9, 12),
        wakeFacts: GoalWakeFacts(
          trackStatus: GoalTrackStatus.insufficientData,
          evaluation: const GoalEvaluation(
            attainment: 0.9,
            satisfied: false,
            dataCoverage: 1 / 7,
            results: {
              'health-weight': GoalCriterionResult(
                criterionId: 'health-weight',
                actual: 95,
                target: 88,
                ratio: 88 / 95,
                satisfied: false,
                sampleCount: 1,
              ),
              'habit-bp-meds': GoalCriterionResult(
                criterionId: 'habit-bp-meds',
                actual: 6,
                target: 7,
                ratio: 6 / 7,
                satisfied: false,
                sampleCount: 6,
                deficit: 7,
              ),
            },
          ),
          quantitativeObservationsByType: {
            GoalHealthDataTypes.weight: [
              GoalMetricObservation(
                recordedAt: DateTime(2026, 8, 8, 8),
                value: 95,
              ),
            ],
          },
        ),
      );
      final evaluation = json['evaluation'] as Map<String, dynamic>;
      expect(evaluation['todayGuidance'], {
        'healthLoggingCompleteCriterionIds': <String>[],
        'healthLoggingNeededCriterionIds': ['health-weight'],
        'rollingHabitCriterionIdsBehind': ['habit-bp-meds'],
      });
      final result = (evaluation['criterionResults'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .singleWhere((entry) => entry['criterionId'] == 'health-weight');
      final latest =
          (result['healthSeries'] as Map<String, dynamic>)['latest']
              as Map<String, dynamic>;
      expect(latest['todayStatus'], 'notMeasuredToday');
    },
  );

  test(
    'latest health change respects authored direction and flat readings',
    () {
      const criteria = GoalCriterion.allOf(
        criterionId: 'direction-checks',
        criteria: [
          GoalCriterion.metric(
            criterionId: 'weight-at-most',
            dataType: GoalHealthDataTypes.weight,
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.max,
            target: 88,
            direction: GoalDirection.atMost,
          ),
          GoalCriterion.metric(
            criterionId: 'weight-at-least',
            dataType: GoalHealthDataTypes.weight,
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.max,
            target: 95,
          ),
          GoalCriterion.metric(
            criterionId: 'flat-systolic',
            dataType: GoalHealthDataTypes.bloodPressureSystolic,
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.max,
            target: 125,
            direction: GoalDirection.atMost,
          ),
        ],
      );
      GoalCriterionResult result(String id, num actual, num target) =>
          GoalCriterionResult(
            criterionId: id,
            actual: actual,
            target: target,
            ratio: 0.9,
            satisfied: false,
            sampleCount: 2,
          );
      final json = renderedJson(
        criteria: criteria,
        wakeFacts: GoalWakeFacts(
          trackStatus: GoalTrackStatus.atRisk,
          evaluation: GoalEvaluation(
            attainment: 0.9,
            satisfied: false,
            dataCoverage: 1,
            results: {
              'weight-at-most': result('weight-at-most', 91, 88),
              'weight-at-least': result('weight-at-least', 91, 95),
              'flat-systolic': result('flat-systolic', 130, 125),
            },
          ),
          quantitativeObservationsByType: {
            GoalHealthDataTypes.weight: [
              GoalMetricObservation(
                recordedAt: DateTime(2026, 8, 8),
                value: 90,
              ),
              GoalMetricObservation(
                recordedAt: DateTime(2026, 8, 9),
                value: 91,
              ),
            ],
            GoalHealthDataTypes.bloodPressureSystolic: [
              GoalMetricObservation(
                recordedAt: DateTime(2026, 8, 8),
                value: 130,
              ),
              GoalMetricObservation(
                recordedAt: DateTime(2026, 8, 9),
                value: 130,
              ),
            ],
          },
        ),
      );
      final results =
          ((json['evaluation'] as Map<String, dynamic>)['criterionResults']
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();
      String direction(String id) =>
          (((results.singleWhere(
                        (entry) => entry['criterionId'] == id,
                      )['healthSeries']
                      as Map<String, dynamic>)['latestChange']
                  as Map<String, dynamic>)['direction'])
              as String;
      expect(direction('weight-at-most'), 'awayFromTarget');
      expect(direction('weight-at-least'), 'towardTarget');
      expect(direction('flat-systolic'), 'flat');
    },
  );

  test('current report actions expose only unmeasured health criteria', () {
    const criteria = GoalCriterion.allOf(
      criterionId: 'health-routine',
      criteria: [
        GoalCriterion.metric(
          criterionId: 'health-weight',
          dataType: GoalHealthDataTypes.weight,
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 88,
          direction: GoalDirection.atMost,
        ),
        GoalCriterion.habit(
          criterionId: 'habit-bp-meds',
          habitId: 'habit-bp-meds',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 7,
        ),
      ],
    );
    final wakeFacts = GoalWakeFacts(
      trackStatus: GoalTrackStatus.insufficientData,
      evaluation: const GoalEvaluation(
        attainment: 0.9,
        satisfied: false,
        dataCoverage: 1 / 7,
        results: {
          'health-weight': GoalCriterionResult(
            criterionId: 'health-weight',
            actual: 95,
            target: 88,
            ratio: 88 / 95,
            satisfied: false,
            sampleCount: 1,
          ),
          'habit-bp-meds': GoalCriterionResult(
            criterionId: 'habit-bp-meds',
            actual: 6,
            target: 7,
            ratio: 6 / 7,
            satisfied: false,
            sampleCount: 6,
          ),
        },
      ),
      quantitativeObservationsByType: {
        GoalHealthDataTypes.weight: [
          GoalMetricObservation(
            recordedAt: DateTime(2026, 8, 8, 8),
            value: 95,
          ),
        ],
      },
    );

    expect(
      renderer.healthLoggingNeededCriterionIds(
        criteria: criteria,
        facts: wakeFacts,
        evaluationReference: DateTime(2026, 8, 9, 12),
      ),
      {'health-weight'},
    );
  });

  test('health evidence keeps the newest bounded sample and omitted count', () {
    const criteria = GoalCriterion.metric(
      criterionId: 'health-weight',
      dataType: GoalHealthDataTypes.weight,
      window: GoalWindow.rollingDays(count: 3650),
      aggregation: GoalAggregation.dailySumThenAverage,
      target: 88,
      direction: GoalDirection.atMost,
    );
    final observations = [
      for (
        var index = 0;
        index < goalHealthObservationEvidenceLimit + 2;
        index++
      )
        GoalMetricObservation(
          recordedAt: DateTime(2026).add(Duration(hours: index)),
          value: 100 - index / 10,
        ),
    ];
    final json = renderedJson(
      criteria: criteria,
      evaluationReference: DateTime(2026, 8, 9, 12),
      wakeFacts: GoalWakeFacts(
        trackStatus: GoalTrackStatus.atRisk,
        evaluation: const GoalEvaluation(
          attainment: 0.9,
          satisfied: false,
          dataCoverage: 1,
          results: {
            'health-weight': GoalCriterionResult(
              criterionId: 'health-weight',
              actual: 90,
              target: 88,
              ratio: 0.9,
              satisfied: false,
              sampleCount: 102,
            ),
          },
        ),
        quantitativeObservationsByType: {
          GoalHealthDataTypes.weight: observations,
        },
      ),
    );
    final evaluation = json['evaluation'] as Map<String, dynamic>;
    final result =
        (evaluation['criterionResults'] as List<dynamic>).single
            as Map<String, dynamic>;
    final series = result['healthSeries'] as Map<String, dynamic>;
    final emitted = series['observations'] as List<dynamic>;

    expect(series['observationCount'], goalHealthObservationEvidenceLimit + 2);
    expect(series['observationsOmitted'], 2);
    expect(emitted, hasLength(goalHealthObservationEvidenceLimit));
    expect(
      (emitted.first as Map<String, dynamic>)['recordedAt'],
      observations[2].recordedAt.toIso8601String(),
    );
    expect(
      (series['latest'] as Map<String, dynamic>)['recordedAt'],
      observations.last.recordedAt.toIso8601String(),
    );
  });

  test('nested non-health criteria remain aggregate-only', () {
    const criteria = GoalCriterion.anyOf(
      criterionId: 'any-routine',
      criteria: [
        GoalCriterion.atLeastCount(
          criterionId: 'two-of-three',
          successes: 2,
          criteria: [
            GoalCriterion.habit(
              criterionId: 'gym',
              habitId: 'gym-habit',
              window: GoalWindow.rollingDays(count: 7),
              targetCount: 3,
            ),
            GoalCriterion.measurable(
              criterionId: 'water',
              dataTypeId: 'water-id',
              window: GoalWindow.day(),
              aggregation: GoalAggregation.sum,
              target: 2000,
            ),
            GoalCriterion.categoryTime(
              criterionId: 'coding',
              categoryId: 'coding-category',
              window: GoalWindow.rollingDays(count: 7),
              aggregation: GoalAggregation.sum,
              targetHours: 4,
            ),
          ],
        ),
      ],
    );
    final json = renderedJson(
      criteria: criteria,
      wakeFacts: const GoalWakeFacts(
        trackStatus: GoalTrackStatus.atRisk,
        evaluation: GoalEvaluation(
          attainment: 1 / 3,
          satisfied: false,
          dataCoverage: 1,
          results: {
            'gym': GoalCriterionResult(
              criterionId: 'gym',
              actual: 1,
              target: 3,
              ratio: 1 / 3,
              satisfied: false,
              sampleCount: 7,
            ),
          },
        ),
      ),
    );

    final evaluation = json['evaluation'] as Map<String, dynamic>;
    final result =
        (evaluation['criterionResults'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(result, isNot(contains('healthSeries')));
  });

  test('active ads carry freshness; a stale-marked ad is exposed as such', () {
    final recordedOutcome = GoalNudgeRating(
      activation: 1,
      ratedAt: now.subtract(const Duration(hours: 1)),
      rating: 4,
    );
    final json = renderedJson(
      nudges: [
        nudge(
          id: 'ad-fresh',
          status: GoalNudgeStatus.active,
          activatedAt: now.subtract(const Duration(hours: 6)),
          staleAt: now.add(const Duration(hours: 66)),
          ratings: [recordedOutcome],
        ),
        nudge(
          id: 'ad-stale',
          status: GoalNudgeStatus.active,
          activatedAt: now.subtract(const Duration(hours: 80)),
          staleAt: now.subtract(const Duration(hours: 8)),
        ),
      ],
    );
    final ads = json['ads'] as Map<String, dynamic>;
    final active = (ads['active'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(active, hasLength(2));
    final fresh = active.singleWhere((a) => a['adId'] == 'ad-fresh');
    expect(fresh['fresh'], isTrue);
    expect(fresh['markedStale'], isFalse);
    expect(fresh['outcomeRecorded'], isTrue);
    final stale = active.singleWhere((a) => a['adId'] == 'ad-stale');
    expect(stale['fresh'], isFalse);
    expect(stale['markedStale'], isTrue);
    expect(stale['outcomeRecorded'], isFalse);
  });

  test('only retired ads with mean rating >= 4 are offered for re-run, '
      'best first; skips never count', () {
    GoalNudgeRating rating(
      int activation,
      int? value, {
      bool skipped = false,
    }) => GoalNudgeRating(
      activation: activation,
      ratedAt: DateTime(2026, 8, activation),
      rating: value,
      skipped: skipped,
    );
    final json = renderedJson(
      nudges: [
        nudge(
          id: 'ad-great',
          status: GoalNudgeStatus.retired,
          ratings: [rating(1, 5), rating(2, null, skipped: true), rating(3, 4)],
          activationCount: 3,
        ),
        nudge(
          id: 'ad-good',
          status: GoalNudgeStatus.retired,
          ratings: [rating(1, 4)],
        ),
        nudge(
          id: 'ad-meh',
          status: GoalNudgeStatus.retired,
          ratings: [rating(1, 2)],
        ),
        nudge(id: 'ad-unrated', status: GoalNudgeStatus.retired),
        nudge(
          id: 'ad-active-top',
          status: GoalNudgeStatus.active,
          ratings: [rating(1, 5)],
        ),
      ],
    );
    final reusable =
        ((json['ads'] as Map<String, dynamic>)['reusableTopRated']
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    expect(
      [for (final ad in reusable) ad['adId']],
      ['ad-great', 'ad-good'],
    );
    expect(reusable.first['meanRating'], 4.5);
    expect(reusable.first['timesRun'], 3);
  });

  test('snooze behavior gives the model durable local timing patterns', () {
    GoalNudgeSnooze event(
      String id, {
      required int startHourUtc,
      required int durationHours,
    }) => GoalNudgeSnooze(
      id: id,
      activation: 1,
      snoozedAt: DateTime.utc(2026, 8, 10, startHourUtc),
      snoozedUntil: DateTime.utc(
        2026,
        8,
        10,
        startHourUtc + durationHours,
      ),
      duration: goalBannerSnoozeDurationFor(
        Duration(hours: durationHours),
      ),
      durationMinutes: durationHours * 60,
      utcOffsetMinutes: 120,
    );
    final json = renderedJson(
      nudges: [
        nudge(
          id: 'ad-history',
          status: GoalNudgeStatus.retired,
          snoozeHistory: [
            event('s1', startHourUtc: 8, durationHours: 3),
            event('s2', startHourUtc: 9, durationHours: 1),
            event('s3', startHourUtc: 12, durationHours: 3),
          ],
        ),
      ],
    );

    final behavior =
        (json['ads'] as Map<String, dynamic>)['snoozeBehavior']
            as Map<String, dynamic>;
    expect(behavior['totalCount'], 3);
    expect(behavior['countByDurationMinutes'], {'60': 1, '180': 2});
    final startHours = behavior['countByStartLocalHour'] as List<dynamic>;
    expect(startHours[10], 1);
    expect(startHours[11], 1);
    expect(startHours[14], 1);
    final returnHours =
        behavior['countByRequestedReturnLocalHour'] as List<dynamic>;
    expect(returnHours[12], 1);
    expect(returnHours[13], 1);
    expect(returnHours[17], 1);
    final recent = (behavior['recent'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(recent.last['requestedReturnLocal'], '2026-08-10T17:00:00');
  });

  test('a dismissal quiets the rest of ITS calendar day; yesterday does '
      'not carry over', () {
    bool cooldown(DateTime dismissedAt) =>
        ((renderedJson(
                      nudges: [
                        nudge(
                          id: 'ad-x',
                          status: GoalNudgeStatus.dismissed,
                          dismissedAt: dismissedAt,
                        ),
                      ],
                    )['ads'] ??
                    <String, dynamic>{})
                as Map<String, dynamic>)['dismissalCooldownActive']
            as bool;
    // Same local day (test clock is 2026-08-09 12:00): quiet.
    expect(cooldown(DateTime(2026, 8, 9, 8)), isTrue);
    expect(cooldown(DateTime(2026, 8, 9, 23, 30)), isTrue);
    // Late last night — a rolling 24h would still be quiet; a new day
    // must not be.
    expect(cooldown(DateTime(2026, 8, 8, 23)), isFalse);
  });

  test('trend worsening needs three strictly declining points', () {
    expect(renderer.trendWorsening(0.5, [0.6, 0.7]), isTrue);
    expect(renderer.trendWorsening(0.5, [0.6]), isFalse);
    expect(renderer.trendWorsening(0.7, [0.6, 0.7]), isFalse);
    expect(renderer.trendWorsening(0.5, [0.5, 0.7]), isFalse);
  });

  test('criterionJson renders every composite variant', () {
    const composite = GoalCriterion.atLeastCount(
      criterionId: 'two-of-three',
      successes: 2,
      criteria: [
        GoalCriterion.habit(
          criterionId: 'gym',
          habitId: 'gym-habit',
          window: GoalWindow.calendarWeek(),
          targetCount: 3,
        ),
        GoalCriterion.measurable(
          criterionId: 'water',
          dataTypeId: 'water-id',
          window: GoalWindow.day(),
          aggregation: GoalAggregation.sum,
          target: 2000,
        ),
        GoalCriterion.anyOf(
          criterionId: 'either',
          criteria: [
            GoalCriterion.allOf(criterionId: 'both', criteria: []),
          ],
        ),
      ],
    );
    final json = criterionJson(composite);
    expect(json['atLeast'], 2);
    expect(
      criterionJson(
        const GoalCriterion.metric(
          criterionId: 'monthly',
          dataType: 'x',
          window: GoalWindow.calendarMonth(),
          aggregation: GoalAggregation.sum,
          target: 1,
        ),
      )['window'],
      'calendar month',
    );
    final children = (json['of']! as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(children[0]['habit'], 'gym-habit');
    expect(children[0]['window'], 'calendar week (Mon-Sun)');
    expect(children[1]['measurable'], 'water-id');
    expect(children[1]['window'], 'day');
    expect(
      ((children[2]['anyOf'] as List<dynamic>).single
          as Map<String, dynamic>)['allOf'],
      isEmpty,
    );
  });

  test(
    'criterionJson labels tracked category time and its local daily band',
    () {
      final json = criterionJson(
        const GoalCriterion.categoryTime(
          criterionId: 'late-coding',
          categoryId: 'vibe-coding',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.sum,
          targetHours: 0,
          title: 'Late-night coding',
          dailyTimeRange: GoalDailyTimeRange(
            startMinute: 21 * 60 + 30,
            endMinute: 7 * 60,
          ),
        ),
      );

      expect(json['categoryTime'], 'vibe-coding');
      expect(json['title'], 'Late-night coding');
      expect(json['targetHours'], 0);
      expect(json['direction'], 'atMost');
      expect(json['evidence'], 'tracked Lotti time entries only');
      expect(json['dailyTimeRange'], {
        'startMinute': 21 * 60 + 30,
        'endMinute': 7 * 60,
      });
    },
  );

  test(
    'category session evidence exposes local timing without deciding success',
    () {
      final json = renderedJson(
        wakeFacts: facts(
          categoryTimeSessions: {
            'vibe-coding': [
              GoalCategoryTimeSession(
                categoryId: 'vibe-coding',
                dateFrom: DateTime(2026, 8, 8, 23, 15),
                dateTo: DateTime(2026, 8, 9, 1, 45),
              ),
            ],
          },
          categoryTimeEvidenceStart: DateTime(2026, 8, 2),
          categoryTimeEvidenceEnd: DateTime(2026, 8, 10),
        ),
      );

      final signals = json['signals'] as Map<String, dynamic>;
      expect(signals['categoryTimeEvidenceStart'], '2026-08-02T00:00:00.000');
      expect(signals['categoryTimeEvidenceEnd'], '2026-08-10T00:00:00.000');
      final session =
          (signals['categoryTimeSessions'] as List).single
              as Map<String, dynamic>;
      expect(session['categoryId'], 'vibe-coding');
      expect(session['startedAtLocal'], '2026-08-08T23:15:00.000');
      expect(session['endedAtLocal'], '2026-08-09T01:45:00.000');
      expect(session['durationMinutes'], 150);
      expect(session.containsKey('satisfied'), isFalse);
      final summary =
          (signals['categoryTimeLifetimeSummary'] as List).single
              as Map<String, dynamic>;
      expect(summary['sessionCount'], 1);
      expect(summary['totalMinutes'], 150);
      final minutesByHour = summary['minutesByLocalHour'] as List;
      expect(minutesByHour[23], 45);
      expect(minutesByHour[0], 60);
      expect(minutesByHour[1], 45);
    },
  );

  test('lifetime category summaries union overlapping raw sessions', () {
    final json = renderedJson(
      wakeFacts: facts(
        categoryTimeSessions: {
          'vibe-coding': [
            GoalCategoryTimeSession(
              categoryId: 'vibe-coding',
              dateFrom: DateTime(2026, 8, 8, 9),
              dateTo: DateTime(2026, 8, 8, 10, 30),
            ),
            GoalCategoryTimeSession(
              categoryId: 'vibe-coding',
              dateFrom: DateTime(2026, 8, 8, 9, 30),
              dateTo: DateTime(2026, 8, 8, 11),
            ),
          ],
        },
      ),
    );

    final signals = json['signals'] as Map<String, dynamic>;
    expect(signals['categoryTimeSessionCount'], 2);
    expect(signals['categoryTimeSessions'], hasLength(2));
    final summary =
        (signals['categoryTimeLifetimeSummary'] as List).single
            as Map<String, dynamic>;
    expect(summary['sessionCount'], 2, reason: 'raw evidence stays auditable');
    expect(
      summary['totalMinutes'],
      120,
      reason: 'the 09:30–10:30 overlap must count only once',
    );
    final minutesByHour = summary['minutesByLocalHour'] as List;
    expect(minutesByHour[9], 60);
    expect(minutesByHour[10], 60);
  });

  test('category summaries preserve seconds across local-hour splits', () {
    final json = renderedJson(
      wakeFacts: facts(
        categoryTimeSessions: {
          'vibe-coding': [
            GoalCategoryTimeSession(
              categoryId: 'vibe-coding',
              dateFrom: DateTime(2026, 8, 8, 9, 59, 30),
              dateTo: DateTime(2026, 8, 8, 10, 0, 30),
            ),
          ],
        },
      ),
    );

    final signals = json['signals'] as Map<String, dynamic>;
    final raw =
        (signals['categoryTimeSessions'] as List).single
            as Map<String, dynamic>;
    expect(raw['durationMinutes'], 1);
    final summary =
        (signals['categoryTimeLifetimeSummary'] as List).single
            as Map<String, dynamic>;
    expect(summary['totalMinutes'], 1);
    final minutesByHour = summary['minutesByLocalHour'] as List;
    expect(minutesByHour[9], 0.5);
    expect(minutesByHour[10], 0.5);
  });

  test('lifetime category evidence keeps a bounded recent raw sample', () {
    final sessions = [
      for (var index = 0; index < 205; index++)
        GoalCategoryTimeSession(
          categoryId: 'vibe-coding',
          dateFrom: DateTime(2026).add(Duration(hours: index)),
          dateTo: DateTime(2026).add(
            Duration(hours: index, minutes: 30),
          ),
        ),
    ];

    final json = renderedJson(
      wakeFacts: facts(
        categoryTimeSessions: {'vibe-coding': sessions},
        categoryTimeEvidenceStart: DateTime(2026),
        categoryTimeEvidenceEnd: DateTime(2026, 8, 10),
      ),
    );
    final signals = json['signals'] as Map<String, dynamic>;

    expect(signals['categoryTimeSessionCount'], 205);
    expect(signals['categoryTimeSessionsOmitted'], 5);
    expect(signals['categoryTimeSessions'], hasLength(200));
    final recent = signals['categoryTimeSessions'] as List;
    expect(
      (recent.first as Map<String, dynamic>)['startedAtLocal'],
      sessions[5].dateFrom.toIso8601String(),
      reason: 'the bounded sample must retain the most recent raw sessions',
    );
    final summary =
        (signals['categoryTimeLifetimeSummary'] as List).single
            as Map<String, dynamic>;
    expect(summary['sessionCount'], 205);
    expect(summary['totalMinutes'], 205 * 30);
  });
}
