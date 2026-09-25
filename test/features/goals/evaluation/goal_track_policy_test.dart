import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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
    bool onTrackByTrend = false,
  }) => GoalEvaluation(
    attainment: attainment,
    satisfied: satisfied,
    dataCoverage: coverage,
    results: const {},
    paceFeasible: paceFeasible,
    onTrackByTrend: onTrackByTrend,
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

  test('a favorable projection is onTrack without claiming achievement', () {
    expect(
      policy.derive(
        evaluation: eval(attainment: 0.7, onTrackByTrend: true),
      ),
      GoalTrackStatus.onTrack,
    );
    expect(
      policy.derive(
        evaluation: eval(attainment: 0.7, onTrackByTrend: true),
        targetDatePassed: true,
      ),
      GoalTrackStatus.offTrack,
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

  group('exhaustive decision table', () {
    // A proof by exhaustion. `derive` reads its real-valued inputs only
    // through comparisons with fixed thresholds (`minDataCoverage`, 1.0,
    // `offTrackThreshold`), so every input is equivalent to one of the
    // representatives below: a value on each side of every threshold and the
    // threshold itself. Enumerating all of them visits every region of the
    // input space. Each status is then checked against a declarative
    // characterisation — an "if and only if", not a replay of the rule chain —
    // and the characterisations must partition the space: exactly one holds.
    for (final policy in const [
      GoalTrackPolicy(),
      GoalTrackPolicy(
        offTrackThreshold: 0.6,
        minDataCoverage: 0.25,
        priorBadPeriodsForOffTrack: 2,
      ),
    ]) {
      test(
        'every status holds exactly when its characterisation does '
        '(threshold ${policy.offTrackThreshold}, coverage '
        '${policy.minDataCoverage}, streak '
        '${policy.priorBadPeriodsForOffTrack})',
        () {
          final thr = policy.offTrackThreshold;
          final cov = policy.minDataCoverage;
          final coverages = [0.0, cov - 0.01, cov, 1.0];
          final attainments = [0.0, thr - 0.01, thr, 0.99, 1.0];
          final shortTerms = <double?>[null, 0, 0.99, 1];
          final priorValues = [thr - 0.01, thr];
          final priorLists = <List<double>>[
            const [],
            for (final a in priorValues) [a],
            for (final a in priorValues)
              for (final b in priorValues) [a, b],
            for (final a in priorValues)
              for (final b in priorValues)
                for (final c in priorValues) [a, b, c],
          ];

          var cases = 0;
          for (final coverage in coverages) {
            for (final passed in [false, true]) {
              for (final satisfied in [false, true]) {
                for (final attainment in attainments) {
                  // An evaluator never reports a met criterion below full
                  // attainment, nor an unmet one at it; the policy must still
                  // be total over the impossible combinations.
                  for (final trend in [false, true]) {
                    for (final pace in const <bool?>[null, true, false]) {
                      for (final shortTerm in shortTerms) {
                        for (final priors in priorLists) {
                          cases++;
                          final status = policy.derive(
                            evaluation: GoalEvaluation(
                              attainment: attainment,
                              satisfied: satisfied,
                              dataCoverage: coverage,
                              results: const {},
                              paceFeasible: pace,
                              onTrackByTrend: trend,
                            ),
                            shortTermAttainment: shortTerm,
                            priorAttainments: priors,
                            targetDatePassed: passed,
                          );

                          final covered = coverage >= cov;
                          final live = covered && !passed;
                          final meetsNow =
                              satisfied || attainment >= 1 || trend;
                          final recovers =
                              pace != false &&
                              shortTerm != null &&
                              shortTerm >= 1;
                          final badStreak = priors
                              .takeWhile((prior) => prior < thr)
                              .length;
                          final graceSpent =
                              attainment < thr &&
                              badStreak >= policy.priorBadPeriodsForOffTrack;

                          final expected = {
                            GoalTrackStatus.insufficientData: !covered,
                            GoalTrackStatus.achieved:
                                covered && passed && satisfied,
                            GoalTrackStatus.onTrack: live && meetsNow,
                            GoalTrackStatus.recovering:
                                live && !meetsNow && recovers,
                            GoalTrackStatus.offTrack:
                                (covered && passed && !satisfied) ||
                                (live &&
                                    !meetsNow &&
                                    (pace == false ||
                                        (!recovers && graceSpent))),
                            GoalTrackStatus.atRisk:
                                live &&
                                !meetsNow &&
                                pace != false &&
                                !recovers &&
                                !graceSpent,
                          };
                          final input =
                              'coverage $coverage passed $passed satisfied '
                              '$satisfied attainment $attainment trend '
                              '$trend pace $pace short $shortTerm priors '
                              '$priors';
                          expect(
                            expected.values.where((holds) => holds),
                            hasLength(1),
                            reason: 'characterisations overlap: $input',
                          );
                          expect(
                            expected[status],
                            isTrue,
                            reason: '$status for $input',
                          );
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          expect(cases, 4 * 2 * 2 * 5 * 2 * 3 * 4 * 15);
        },
      );
    }
  });

  group('policy properties', () {
    // Higher is better; recovering and onTrack both mean "no nudge".
    int rank(GoalTrackStatus status) => switch (status) {
      GoalTrackStatus.offTrack => 0,
      GoalTrackStatus.atRisk => 1,
      GoalTrackStatus.recovering || GoalTrackStatus.onTrack => 2,
      GoalTrackStatus.achieved => 3,
      GoalTrackStatus.insufficientData => -1,
    };

    glados.Glados2(
      glados.any.policyInput,
      glados.BoolAny(glados.any).bool,
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'the verdict follows coverage, deadline and satisfaction in that order',
      (input, targetDatePassed) {
        final status = policy.derive(
          evaluation: input.evaluation,
          shortTermAttainment: input.shortTerm,
          priorAttainments: input.priors,
          targetDatePassed: targetDatePassed,
        );

        if (input.evaluation.dataCoverage < policy.minDataCoverage) {
          expect(status, GoalTrackStatus.insufficientData);
        } else if (targetDatePassed) {
          expect(
            status,
            input.evaluation.satisfied
                ? GoalTrackStatus.achieved
                : GoalTrackStatus.offTrack,
          );
        } else {
          expect(status, isNot(GoalTrackStatus.achieved));
          expect(status, isNot(GoalTrackStatus.insufficientData));
          if (input.evaluation.satisfied) {
            expect(status, GoalTrackStatus.onTrack);
          }
        }
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.policyInput,
      glados.IntAnys(glados.any).intInRange(0, 80),
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'a further bad prior period never improves the verdict',
      (input, badPercent) {
        GoalTrackStatus derive(List<double> priors) => policy.derive(
          evaluation: input.evaluation,
          shortTermAttainment: input.shortTerm,
          priorAttainments: priors,
        );
        final before = derive(input.priors);
        final after = derive([badPercent / 100, ...input.priors]);

        expect(rank(after), lessThanOrEqualTo(rank(before)));
      },
      tags: 'glados',
    );
  });
}

class _PolicyInput {
  const _PolicyInput(this.evaluation, this.shortTerm, this.priors);

  final GoalEvaluation evaluation;
  final double? shortTerm;
  final List<double> priors;

  @override
  String toString() =>
      '_PolicyInput(attainment: ${evaluation.attainment}, '
      'satisfied: ${evaluation.satisfied}, '
      'coverage: ${evaluation.dataCoverage}, '
      'pace: ${evaluation.paceFeasible}, '
      'trend: ${evaluation.onTrackByTrend}, '
      'shortTerm: $shortTerm, priors: $priors)';
}

extension _AnyPolicyInput on glados.Any {
  /// Percentages 0–100 as fractions; -1 stands for "absent".
  glados.Generator<_PolicyInput> get policyInput =>
      glados.CombinableAny(this).combine7(
        glados.IntAnys(this).intInRange(0, 101),
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 101),
        glados.AnyUtils(this).choose<bool?>([null, true, false]),
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(-1, 121),
        glados.ListAnys(this).listWithLengthInRange(
          0,
          5,
          glados.IntAnys(this).intInRange(0, 101),
        ),
        (
          int attainment,
          bool satisfied,
          int coverage,
          bool? pace,
          bool trend,
          int shortTerm,
          List<int> priors,
        ) => _PolicyInput(
          GoalEvaluation(
            attainment: attainment / 100,
            satisfied: satisfied,
            dataCoverage: coverage / 100,
            results: const {},
            paceFeasible: pace,
            onTrackByTrend: trend,
          ),
          shortTerm < 0 ? null : shortTerm / 100,
          [for (final prior in priors) prior / 100],
        ),
      );
}
