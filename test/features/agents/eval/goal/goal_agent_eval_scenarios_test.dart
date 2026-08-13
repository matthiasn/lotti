import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_progress_evaluator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_track_policy.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';

import 'support/goal_agent_eval_fixtures.dart';
import 'support/goal_agent_eval_scenarios.dart';
import 'support/goal_agent_spec.dart';

/// The offline self-tests: fixture arithmetic is not trusted by comment —
/// every derived constant is recomputed through the REAL
/// [GoalProgressEvaluator] and [GoalTrackPolicy], so the eval fixtures are
/// an executable spec of the deterministic tier. If evaluator semantics
/// drift, these tests break before a live eval run burns money on wrong
/// expectations.
void main() {
  const evaluator = GoalProgressEvaluator();
  const policy = GoalTrackPolicy();

  const stepsCriterion = GoalCriterion.metric(
    criterionId: 'g1',
    dataType: 'cumulative_step_count',
    window: GoalWindow.rollingDays(count: 7),
    aggregation: GoalAggregation.dailySumThenAverage,
    target: gStepsTarget,
  );

  const gymCriterion = GoalCriterion.habit(
    criterionId: 'g2',
    habitId: 'gym-habit',
    window: GoalWindow.calendarWeek(),
    targetCount: gGymTargetCount,
  );

  GoalSignalWindow stepsWindow(List<num?> daily) => GoalSignalWindow(
    quantitativeDailySums: {
      'cumulative_step_count': {
        for (var i = 0; i < daily.length; i++)
          if (daily[i] != null) goalEvalWindowDays[i]: daily[i]!,
      },
    },
  );

  ({double attainment, GoalTrackStatus status}) derive(
    List<num?> daily, {
    List<double> priors = const [],
  }) {
    final signals = stepsWindow(daily);
    final evaluation = evaluator.evaluate(
      stepsCriterion,
      signals,
      goalEvalReference,
    );
    final shortTerm = evaluator.shortTermAttainment(
      stepsCriterion,
      signals,
      goalEvalReference,
    );
    return (
      attainment: evaluation.attainment,
      status: policy.derive(
        evaluation: evaluation,
        shortTermAttainment: shortTerm,
        priorAttainments: priors,
      ),
    );
  }

  Map<String, dynamic> decodedFacts(GoalAgentEvalScenario scenario) {
    const prefix = '```json\n';
    final start = scenario.facts.indexOf(prefix);
    final end = scenario.facts.lastIndexOf('\n```');
    return jsonDecode(
          scenario.facts.substring(start + prefix.length, end),
        )
        as Map<String, dynamic>;
  }

  group('fixture arithmetic matches the real evaluator', () {
    test('on-track week', () {
      final signals = stepsWindow(gOnTrackSteps);
      final evaluation = evaluator.evaluate(
        stepsCriterion,
        signals,
        goalEvalReference,
      );
      expect(
        evaluation.results['g1']!.actual,
        closeTo(gOnTrackMean, 1e-9),
      );
      final result = derive(gOnTrackSteps);
      expect(result.attainment, 1.0);
      expect(result.status, GoalTrackStatus.onTrack);
    });

    test('slightly-off week', () {
      final signals = stepsWindow(gSlightlyOffSteps);
      final evaluation = evaluator.evaluate(
        stepsCriterion,
        signals,
        goalEvalReference,
      );
      expect(
        evaluation.results['g1']!.actual,
        closeTo(gSlightlyOffMean, 1e-9),
      );
      final result = derive(gSlightlyOffSteps);
      expect(result.attainment, closeTo(gSlightlyOffAttainment, 1e-9));
      expect(result.status, GoalTrackStatus.atRisk);
    });

    test('worsening week is atRisk with a sub-weekly short-term ratio', () {
      final signals = stepsWindow(gWorseningSteps);
      final evaluation = evaluator.evaluate(
        stepsCriterion,
        signals,
        goalEvalReference,
      );
      expect(
        evaluation.results['g1']!.actual,
        closeTo(gWorseningMean, 1e-9),
      );
      final shortTerm = evaluator.shortTermAttainment(
        stepsCriterion,
        signals,
        goalEvalReference,
      );
      expect(shortTerm, closeTo(gWorseningShortTerm, 1e-9));
      expect(
        shortTerm,
        lessThan(evaluation.attainment),
        reason: 'the worsening signal: recent days worse than the week',
      );
      expect(derive(gWorseningSteps).status, GoalTrackStatus.atRisk);
    });

    test('badly-off week escalates only past the grace period', () {
      final result = derive(
        gBadlyOffSteps,
        priors: gBadlyOffPriorAttainments,
      );
      expect(result.attainment, closeTo(gBadlyOffAttainment, 1e-9));
      expect(result.status, GoalTrackStatus.offTrack);
      // Same numbers, clean prior history → grace as atRisk. This is what
      // makes the offTrack scenario's prior period load-bearing.
      expect(derive(gBadlyOffSteps).status, GoalTrackStatus.atRisk);
    });

    test('recovering week: bad trailing mean, on-pace last three days', () {
      final signals = stepsWindow(gRecoveringSteps);
      final evaluation = evaluator.evaluate(
        stepsCriterion,
        signals,
        goalEvalReference,
      );
      expect(
        evaluation.results['g1']!.actual,
        closeTo(gRecoveringMean, 1e-9),
      );
      expect(
        evaluator.shortTermAttainment(
          stepsCriterion,
          signals,
          goalEvalReference,
        ),
        1.0,
      );
      expect(derive(gRecoveringSteps).status, GoalTrackStatus.recovering);
    });

    test('data gap yields insufficientData from coverage alone', () {
      final signals = stepsWindow(gDataGapSteps);
      final evaluation = evaluator.evaluate(
        stepsCriterion,
        signals,
        goalEvalReference,
      );
      expect(evaluation.dataCoverage, closeTo(gDataGapCoverage, 1e-9));
      expect(derive(gDataGapSteps).status, GoalTrackStatus.insufficientData);
    });

    test('gym 1/3 by Saturday is feasible and atRisk', () {
      final signals = GoalSignalWindow(
        habitSuccessesByDay: {
          'gym-habit': {DateTime.utc(2026, 8, 3): 1},
        },
      );
      final evaluation = evaluator.evaluate(
        gymCriterion,
        signals,
        goalEvalReference,
      );
      expect(
        evaluation.attainment,
        closeTo(gGymOneOfThreeAttainment, 1e-9),
      );
      expect(evaluation.paceFeasible, isTrue);
      expect(
        policy.derive(evaluation: evaluation),
        GoalTrackStatus.atRisk,
      );
    });

    test('composite: gym satisfied cannot rescue collapsed steps', () {
      const composite = GoalCriterion.allOf(
        criterionId: 'fit',
        criteria: [
          GoalCriterion.metric(
            criterionId: 'steps',
            dataType: 'cumulative_step_count',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: gStepsTarget,
          ),
          GoalCriterion.habit(
            criterionId: 'gym',
            habitId: 'gym-habit',
            window: GoalWindow.calendarWeek(),
            targetCount: gGymTargetCount,
          ),
        ],
      );
      final signals = GoalSignalWindow(
        quantitativeDailySums: {
          'cumulative_step_count': {
            for (var i = 0; i < 7; i++)
              goalEvalWindowDays[i]: gCompositeSteps[i],
          },
        },
        habitSuccessesByDay: {
          'gym-habit': {
            DateTime.utc(2026, 8, 3): 1,
            DateTime.utc(2026, 8, 5): 1,
            DateTime.utc(2026, 8, 8): 1,
          },
        },
      );
      final evaluation = evaluator.evaluate(
        composite,
        signals,
        goalEvalReference,
      );
      expect(
        evaluation.results['steps']!.ratio,
        closeTo(gCompositeStepsAttainment, 1e-9),
      );
      expect(evaluation.results['steps']!.satisfied, isFalse);
      expect(evaluation.results['gym']!.satisfied, isTrue);
      expect(evaluation.attainment, closeTo(gCompositeAttainment, 1e-9));
      expect(evaluation.satisfied, isFalse);
      // Gym leaf satisfied → no pace opinion drags the composite.
      expect(evaluation.paceFeasible, isNull);

      final shortTerm = evaluator.shortTermAttainment(
        composite,
        signals,
        goalEvalReference,
      );
      expect(shortTerm, closeTo(gCompositeShortTerm, 1e-9));

      expect(
        policy.derive(
          evaluation: evaluation,
          shortTermAttainment: shortTerm,
          priorAttainments: gCompositePriorAttainments,
        ),
        GoalTrackStatus.offTrack,
      );
      // Without the prior bad period, the same week gets grace.
      expect(
        policy.derive(
          evaluation: evaluation,
          shortTermAttainment: shortTerm,
        ),
        GoalTrackStatus.atRisk,
      );
    });

    test('gym 3/3 is satisfied and onTrack', () {
      final signals = GoalSignalWindow(
        habitSuccessesByDay: {
          'gym-habit': {
            DateTime.utc(2026, 8, 3): 1,
            DateTime.utc(2026, 8, 5): 1,
            DateTime.utc(2026, 8, 8): 1,
          },
        },
      );
      final evaluation = evaluator.evaluate(
        gymCriterion,
        signals,
        goalEvalReference,
      );
      expect(evaluation.satisfied, isTrue);
      expect(
        policy.derive(evaluation: evaluation),
        GoalTrackStatus.onTrack,
      );
    });

    test('complex health fixture matches six real evaluator leaves', () {
      const criteria = GoalCriterion.allOf(
        criterionId: 'blood-pressure-management',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'habit-measure-bp',
            habitId: 'habit-measure-bp',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 5,
          ),
          GoalCriterion.habit(
            criterionId: 'habit-bp-meds',
            habitId: 'habit-bp-meds',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 7,
          ),
          GoalCriterion.habit(
            criterionId: 'habit-weigh',
            habitId: 'habit-weigh',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 3,
          ),
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

      GoalSignalWindow signals({required bool medsDue}) => GoalSignalWindow(
        quantitativeDailySums: {
          GoalHealthDataTypes.bloodPressureSystolic: {
            DateTime.utc(2026, 8, 12): 129,
            DateTime.utc(2026, 8, 13): 125,
          },
          GoalHealthDataTypes.bloodPressureDiastolic: {
            DateTime.utc(2026, 8, 12): 94,
            DateTime.utc(2026, 8, 13): 84,
          },
          GoalHealthDataTypes.weight: {
            DateTime.utc(2026, 8, 7): 96,
            DateTime.utc(2026, 8, 10): 95,
            DateTime.utc(2026, 8, 13): 94,
          },
        },
        habitSuccessesByDay: {
          'habit-measure-bp': {
            DateTime.utc(2026, 8, 7): 1,
            DateTime.utc(2026, 8, 8): 1,
            DateTime.utc(2026, 8, 10): 1,
            DateTime.utc(2026, 8, 12): 1,
            DateTime.utc(2026, 8, 13): 1,
          },
          'habit-bp-meds': {
            for (var day = 7; day <= (medsDue ? 12 : 13); day++)
              DateTime.utc(2026, 8, day): 1,
          },
          'habit-weigh': {
            DateTime.utc(2026, 8, 7): 1,
            DateTime.utc(2026, 8, 10): 1,
            DateTime.utc(2026, 8, 13): 1,
          },
        },
      );

      final complete = evaluator.evaluate(
        criteria,
        signals(medsDue: false),
        complexHealthEvalReference,
      );
      expect(
        complete.results['health-blood-pressure-systolic']!.actual,
        complexHealthSystolicAverage,
      );
      expect(
        complete.results['health-blood-pressure-diastolic']!.actual,
        complexHealthDiastolicAverage,
      );
      expect(
        complete.results['health-weight']!.actual,
        complexHealthWeightAverage,
      );
      expect(complete.results['habit-measure-bp']!.actual, 5);
      expect(complete.results['habit-bp-meds']!.actual, 7);
      expect(complete.results['habit-weigh']!.actual, 3);
      expect(complete.attainment, closeTo(complexHealthAttainment, 1e-12));
      expect(
        policy.derive(evaluation: complete),
        GoalTrackStatus.insufficientData,
      );

      final habitDue = evaluator.evaluate(
        criteria,
        signals(medsDue: true),
        complexHealthEvalReference,
      );
      expect(habitDue.results['habit-bp-meds']!.actual, 6);
      expect(habitDue.results['habit-bp-meds']!.deficit, 7);
      expect(
        habitDue.attainment,
        closeTo(complexHealthHabitDueAttainment, 1e-12),
      );
      expect(
        policy.derive(evaluation: habitDue),
        GoalTrackStatus.insufficientData,
      );
    });
  });

  group('scenario catalog invariants', () {
    test(
      'complex health scenarios carry exact time series and habit state',
      () {
        final complete = goalAgentEvalScenarios.singleWhere(
          (scenario) => scenario.id == 'gh_complex_latest_on_target',
        );
        final completeEvaluation =
            decodedFacts(complete)['evaluation'] as Map<String, dynamic>;
        final completeResults = (completeEvaluation['criterionResults'] as List)
            .cast<Map<String, dynamic>>();
        Map<String, dynamic> result(String id) => completeResults.singleWhere(
          (entry) => entry['criterionId'] == id,
        );

        expect(completeResults, hasLength(6));
        expect(result('habit-measure-bp')['actual'], 5);
        expect(result('habit-bp-meds')['actual'], 7);
        expect(result('habit-weigh')['actual'], 3);
        expect(
          ((result('health-blood-pressure-systolic')['healthSeries']
                      as Map<String, dynamic>)['observations']
                  as List)
              .map((entry) => (entry as Map<String, dynamic>)['value']),
          [129, 125],
        );
        expect(
          ((result('health-blood-pressure-diastolic')['healthSeries']
                      as Map<String, dynamic>)['observations']
                  as List)
              .map((entry) => (entry as Map<String, dynamic>)['value']),
          [94, 84],
        );
        expect(
          ((result('health-weight')['healthSeries']
                      as Map<String, dynamic>)['observations']
                  as List)
              .map((entry) => (entry as Map<String, dynamic>)['value']),
          [96, 95, 94],
        );
        expect(
          (result('health-blood-pressure-systolic')['healthSeries']
              as Map<String, dynamic>)['latest'],
          allOf(
            containsPair('onTarget', true),
            containsPair('todayStatus', 'completeOnTarget'),
          ),
        );
        expect(
          (result('health-blood-pressure-systolic')['healthSeries']
              as Map<String, dynamic>)['latestChange'],
          {
            'fromValue': 129,
            'toValue': 125,
            'direction': 'towardTarget',
          },
        );
        expect(completeEvaluation['todayGuidance'], {
          'healthLoggingCompleteCriterionIds': [
            'health-blood-pressure-systolic',
            'health-blood-pressure-diastolic',
          ],
          'healthLoggingNeededCriterionIds': <String>[],
          'rollingHabitCriterionIdsBehind': <String>[],
        });

        final habitDue = goalAgentEvalScenarios.singleWhere(
          (scenario) => scenario.id == 'gh_complex_habit_behind',
        );
        final dueResults =
            ((decodedFacts(habitDue)['evaluation']
                        as Map<String, dynamic>)['criterionResults']
                    as List)
                .cast<Map<String, dynamic>>();
        final meds = dueResults.singleWhere(
          (entry) => entry['criterionId'] == 'habit-bp-meds',
        );
        expect(meds['actual'], 6);
        expect(meds['target'], 7);
        expect(meds['satisfied'], isFalse);
        expect(meds['daysToRecover'], 7);
        expect(
          (decodedFacts(habitDue)['evaluation']
              as Map<String, dynamic>)['todayGuidance'],
          {
            'healthLoggingCompleteCriterionIds': [
              'health-blood-pressure-systolic',
              'health-blood-pressure-diastolic',
            ],
            'healthLoggingNeededCriterionIds': <String>[],
            'rollingHabitCriterionIdsBehind': ['habit-bp-meds'],
          },
        );
      },
    );

    test('scenario ids are unique', () {
      final ids = goalAgentEvalScenarios.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every scenario references an existing policy rule', () {
      final ruleIds = goalAgentPolicyMatrix.map((r) => r.id).toSet();
      for (final scenario in goalAgentEvalScenarios) {
        expect(
          ruleIds,
          contains(scenario.policyRuleId),
          reason: '${scenario.id} references ${scenario.policyRuleId}',
        );
      }
    });

    test('every policy rule is exercised by at least one scenario', () {
      final covered = goalAgentEvalScenarios.map((s) => s.policyRuleId).toSet();
      for (final rule in goalAgentPolicyMatrix) {
        expect(
          covered,
          contains(rule.id),
          reason: 'policy row ${rule.id} has no scenario',
        );
      }
    });

    test('every ad-creating scenario carries the leakage inventory', () {
      for (final scenario in goalAgentEvalScenarios) {
        final expectsAdCreation = scenario.expectedToolCalls.any(
          (call) => call.name == GoalAgentToolNames.createGoalAd,
        );
        if (!expectsAdCreation) continue;
        expect(
          scenario.forbiddenToolArgumentTerms[GoalAgentToolNames.createGoalAd],
          containsAll(signePrivateStrings),
          reason: '${scenario.id} commissions an ad without leakage guards',
        );
      }
    });

    test('scenario facts embed the track status they assert on', () {
      for (final scenario in goalAgentEvalScenarios) {
        for (final call in scenario.expectedToolCalls) {
          final status = call.expectedArgumentsSubset['status'];
          if (status is String) {
            expect(
              scenario.facts,
              contains('"trackStatus": "$status"'),
              reason: '${scenario.id} expects a status its FACTS do not state',
            );
          }
        }
      }
    });

    test('expected tools are never simultaneously forbidden', () {
      for (final scenario in goalAgentEvalScenarios) {
        for (final call in scenario.expectedToolCalls) {
          expect(
            scenario.forbiddenToolNames,
            isNot(contains(call.name)),
            reason: '${scenario.id} expects and forbids ${call.name}',
          );
          final cap = scenario.maxToolCallCounts[call.name];
          expect(
            cap == null || cap >= 1,
            isTrue,
            reason: '${scenario.id} caps ${call.name} at 0 but expects it',
          );
        }
      }
    });

    test('no-op scenario forbids the entire tool surface', () {
      final noop = goalAgentEvalScenarios.singleWhere(
        (s) => s.expectsNoToolCalls,
      );
      final allNames = goalAgentTools.map((t) => t.name).toSet();
      expect(noop.forbiddenToolNames.toSet(), allNames);
    });
  });

  group('spec invariants', () {
    test('report tool status enum is the GoalTrackStatus vocabulary', () {
      final reportTool = goalAgentTools.singleWhere(
        (t) => t.name == GoalAgentToolNames.updateGoalReport,
      );
      final properties =
          reportTool.parameters['properties'] as Map<String, dynamic>?;
      final status = properties?['status'] as Map<String, dynamic>?;
      expect(status, isNotNull);
      expect(
        status!['enum'],
        GoalTrackStatus.values.map((v) => v.name).toList(),
      );
    });

    test('tool names use the shared reply carrier or verb_goal_noun', () {
      for (final tool in goalAgentTools) {
        expect(
          tool.name == GoalAgentToolNames.replyToUser ||
              RegExp(r'^[a-z]+_goal_[a-z0-9_]+$').hasMatch(tool.name),
          isTrue,
          reason: tool.name,
        );
      }
    });

    test('system prompt stays lean', () {
      // The payload lesson: a bloated prompt gets skimmed. Budget grew with
      // the judgment tier (composite targeting, cooldown, roast bounds) —
      // still a hard ceiling, revisit any growth past it.
      expect(goalAgentSystemPrompt.length, lessThan(3200));
      expect(goalAgentSystemPrompt, contains('insufficientData'));
      expect(goalAgentSystemPrompt, contains('rerun_goal_ad'));
      expect(goalAgentSystemPrompt, contains('snooze_goal_ad'));
      expect(goalAgentSystemPrompt, contains('roast'));
      expect(goalAgentSystemPrompt, contains('Dismissal cooldown'));
      expect(goalAgentSystemPrompt, contains('not a general assistant'));
    });

    test('numberTerms accepts the groupings models actually emit', () {
      expect(
        numberTerms(10000),
        containsAll(['10000', '10,000', '10 000', '10k']),
      );
      expect(numberTerms(8000), contains('8k'));
      expect(numberTerms(500), ['500']);
    });
  });
}
