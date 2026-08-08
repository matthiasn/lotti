import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/evaluation/goal_track_policy.dart';

void main() {
  const policy = GoalTrackPolicy();

  GoalEvaluation eval({
    double attainment = 0,
    bool satisfied = false,
    double coverage = 1.0,
    bool? paceFeasible,
  }) => GoalEvaluation(
    attainment: attainment,
    satisfied: satisfied,
    dataCoverage: coverage,
    results: const {},
    paceFeasible: paceFeasible,
  );

  test('low coverage wins over everything — never guilt-trip a data gap', () {
    expect(
      policy.derive(
        evaluation: eval(satisfied: true, attainment: 1, coverage: 0.3),
        targetDatePassed: true,
      ),
      GoalTrackStatus.insufficientData,
    );
  });

  test('a passed target date resolves to achieved or offTrack', () {
    expect(
      policy.derive(
        evaluation: eval(satisfied: true, attainment: 1),
        targetDatePassed: true,
      ),
      GoalTrackStatus.achieved,
    );
    expect(
      policy.derive(
        // 0.95 would normally be atRisk — after the deadline there is no
        // grace left.
        evaluation: eval(attainment: 0.95),
        targetDatePassed: true,
      ),
      GoalTrackStatus.offTrack,
    );
  });

  test('satisfied or full attainment is onTrack', () {
    expect(
      policy.derive(evaluation: eval(satisfied: true, attainment: 0.9)),
      GoalTrackStatus.onTrack,
    );
    expect(
      policy.derive(evaluation: eval(attainment: 1)),
      GoalTrackStatus.onTrack,
    );
  });

  test('an infeasible quota is offTrack regardless of attainment so far', () {
    expect(
      policy.derive(
        evaluation: eval(attainment: 0.9, paceFeasible: false),
        // Even a perfect short-term trend cannot rescue a dead quota.
        shortTermAttainment: 1,
      ),
      GoalTrackStatus.offTrack,
    );
  });

  test('behind but on pace in recent days is recovering', () {
    // 8730/10000 = 0.873 trailing week, last 3 days at target.
    expect(
      policy.derive(
        evaluation: eval(attainment: 0.873),
        shortTermAttainment: 1,
      ),
      GoalTrackStatus.recovering,
    );
  });

  test('close behind without a turnaround signal is atRisk', () {
    // 9120/10000.
    expect(
      policy.derive(evaluation: eval(attainment: 0.912)),
      GoalTrackStatus.atRisk,
    );
    expect(
      policy.derive(
        evaluation: eval(attainment: 0.912),
        shortTermAttainment: 0.95,
      ),
      GoalTrackStatus.atRisk,
    );
  });

  group('below threshold — grace then offTrack', () {
    test('the first bad period gets grace as atRisk', () {
      // 6414/10000 with a good prior period.
      expect(
        policy.derive(
          evaluation: eval(attainment: 0.6414),
          priorAttainments: [0.9],
        ),
        GoalTrackStatus.atRisk,
      );
      expect(
        policy.derive(evaluation: eval(attainment: 0.6414)),
        GoalTrackStatus.atRisk,
      );
    });

    test('a consecutive prior bad period escalates to offTrack', () {
      expect(
        policy.derive(
          evaluation: eval(attainment: 0.6414),
          priorAttainments: [0.65],
        ),
        GoalTrackStatus.offTrack,
      );
    });

    test('only *trailing* consecutive bad priors count', () {
      // Most recent prior was fine; the older slump is history.
      expect(
        policy.derive(
          evaluation: eval(attainment: 0.5),
          priorAttainments: [0.9, 0.4, 0.3],
        ),
        GoalTrackStatus.atRisk,
      );
    });

    test('a longer grace policy needs more consecutive bad periods', () {
      const patient = GoalTrackPolicy(priorBadPeriodsForOffTrack: 2);
      expect(
        patient.derive(
          evaluation: eval(attainment: 0.5),
          priorAttainments: [0.5, 0.9, 0.5],
        ),
        GoalTrackStatus.atRisk,
      );
      expect(
        patient.derive(
          evaluation: eval(attainment: 0.5),
          priorAttainments: [0.5, 0.5],
        ),
        GoalTrackStatus.offTrack,
      );
    });
  });

  test('custom thresholds move the boundaries', () {
    const strict = GoalTrackPolicy(
      offTrackThreshold: 0.95,
      minDataCoverage: 0.8,
    );
    expect(
      strict.derive(evaluation: eval(attainment: 0.9, coverage: 0.7)),
      GoalTrackStatus.insufficientData,
    );
    expect(
      strict.derive(
        evaluation: eval(attainment: 0.9),
        priorAttainments: [0.9],
      ),
      GoalTrackStatus.offTrack,
    );
  });
}
