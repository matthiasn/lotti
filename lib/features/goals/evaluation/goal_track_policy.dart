import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/model/goal_enums.dart';

/// Deterministic derivation of [GoalTrackStatus] from evaluator output.
///
/// The classification is policy, not model judgment (ADR 0054): every device
/// derives the same status from the same registers, and the goal agent's
/// report merely restates it. Ordering of the rules is load-bearing and
/// documented on [derive].
class GoalTrackPolicy {
  const GoalTrackPolicy({
    this.offTrackThreshold = 0.8,
    this.minDataCoverage = 0.5,
    this.priorBadPeriodsForOffTrack = 1,
    this.shortTermDays = 3,
  });

  /// Attainment below this is a "bad" period.
  final double offTrackThreshold;

  /// Below this coverage the verdict is [GoalTrackStatus.insufficientData] —
  /// never guilt-trip over a data gap.
  final double minDataCoverage;

  /// Number of *consecutive* prior bad periods required before a bad current
  /// period escalates from [GoalTrackStatus.atRisk] (grace) to
  /// [GoalTrackStatus.offTrack].
  final int priorBadPeriodsForOffTrack;

  /// Trailing-days window callers should use when computing
  /// `GoalProgressEvaluator.shortTermAttainment` for [derive].
  final int shortTermDays;

  /// Derives the track status for one period.
  ///
  /// Rule order (first match wins):
  /// 1. Coverage below [minDataCoverage] → [GoalTrackStatus.insufficientData].
  /// 2. Target date passed → [GoalTrackStatus.achieved] if satisfied, else
  ///    [GoalTrackStatus.offTrack] — the period is over, grace is meaningless.
  /// 3. Satisfied (or attainment at 100%) → [GoalTrackStatus.onTrack].
  /// 4. A calendar quota that can no longer be completed →
  ///    [GoalTrackStatus.offTrack] regardless of attainment so far.
  /// 5. Behind overall but the trailing [shortTermDays] days are at or above
  ///    pace → [GoalTrackStatus.recovering] (retires "you're behind" nudges).
  /// 6. Attainment at or above [offTrackThreshold] → [GoalTrackStatus.atRisk].
  /// 7. Below threshold: [GoalTrackStatus.offTrack] once
  ///    [priorBadPeriodsForOffTrack] consecutive prior periods were also bad
  ///    ([priorAttainments] ordered most recent first), else one period of
  ///    grace as [GoalTrackStatus.atRisk].
  GoalTrackStatus derive({
    required GoalEvaluation evaluation,
    double? shortTermAttainment,
    List<double> priorAttainments = const [],
    bool targetDatePassed = false,
  }) {
    if (evaluation.dataCoverage < minDataCoverage) {
      return GoalTrackStatus.insufficientData;
    }
    if (targetDatePassed) {
      return evaluation.satisfied
          ? GoalTrackStatus.achieved
          : GoalTrackStatus.offTrack;
    }
    if (evaluation.satisfied || evaluation.attainment >= 1) {
      return GoalTrackStatus.onTrack;
    }
    if (evaluation.paceFeasible == false) {
      return GoalTrackStatus.offTrack;
    }
    if (shortTermAttainment != null && shortTermAttainment >= 1) {
      return GoalTrackStatus.recovering;
    }
    if (evaluation.attainment >= offTrackThreshold) {
      return GoalTrackStatus.atRisk;
    }
    var priorBad = 0;
    for (final attainment in priorAttainments) {
      if (attainment >= offTrackThreshold) break;
      priorBad++;
    }
    return priorBad >= priorBadPeriodsForOffTrack
        ? GoalTrackStatus.offTrack
        : GoalTrackStatus.atRisk;
  }
}
