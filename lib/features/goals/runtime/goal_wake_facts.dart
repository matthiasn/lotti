import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';

/// Whether three consecutive attainment points are strictly worsening.
/// [priorAttainments] is ordered most-recent-first.
bool goalTrendWorsening(double current, List<double> priorAttainments) {
  if (priorAttainments.length < 2) return false;
  return current < priorAttainments[0] &&
      priorAttainments[0] < priorAttainments[1];
}

/// Whether deterministic health facts permit an automatic banner.
///
/// Off-track goals always qualify. At-risk goals qualify on their first
/// evaluation or after three strictly worsening attainment points. Keeping
/// this policy beside the wake facts lets Phase A schedule a replacement when
/// an activation expires without drifting from Phase B's persistence gate.
bool automaticGoalAdEligible(
  GoalWakeFacts facts,
  List<GoalProgressEntity> priors,
) =>
    facts.trackStatus == GoalTrackStatus.offTrack ||
    (facts.trackStatus == GoalTrackStatus.atRisk &&
        (priors.isEmpty ||
            goalTrendWorsening(facts.evaluation.attainment, [
              for (final row in priors) row.attainment,
            ])));

/// The deterministic facts one Phase A tick derives for a goal agent
/// (ADR 0054): everything downstream — escalation, and in PR 3 the FACTS
/// block and the tool gate — reads these, never raw signals.
class GoalWakeFacts {
  const GoalWakeFacts({
    required this.trackStatus,
    required this.evaluation,
    this.previousStatus,
    this.shortTermAttainment,
    this.categoryTimeSessionsByCategory = const {},
    this.categoryTimeEvidenceStart,
    this.categoryTimeEvidenceEnd,
    this.hasActiveCategoryTimer = false,
  });

  /// Policy-derived status for the evaluation day.
  final GoalTrackStatus trackStatus;

  /// The most recent previously persisted status, if any register row
  /// exists for a prior day.
  final GoalTrackStatus? previousStatus;

  final GoalEvaluation evaluation;
  final double? shortTermAttainment;

  /// Session-level evidence for model pattern analysis. These observations do
  /// not override [evaluation]; a future governed daily assessment can turn a
  /// model suggestion into a user-approved outcome.
  final Map<String, List<GoalCategoryTimeSession>>
  categoryTimeSessionsByCategory;
  final DateTime? categoryTimeEvidenceStart;
  final DateTime? categoryTimeEvidenceEnd;

  /// Whether the category-time snapshot contains a still-running timer.
  /// Reports built from this prefix remain stale until a later settled wake.
  final bool hasActiveCategoryTimer;

  /// Whether the status changed against the last persisted register row.
  /// A first-ever evaluation counts as a transition (there is a new fact
  /// where there was none).
  bool get statusTransitioned => trackStatus != previousStatus;

  /// Whether this tick warrants waking the LLM tier (Phase B, PR 3).
  ///
  /// A status transition is intrinsically LLM-worthy. Phase A separately
  /// combines this with deterministic banner expiry so an eligible goal can
  /// replace stale copy without making ordinary unchanged ticks spend money.
  bool get needsEscalation => statusTransitioned;
}

/// Everything one deterministic derivation pass computed for a goal wake:
/// the shared product of `GoalAgentPhaseA.deriveWakeFacts`, consumed by
/// Phase A's register/escalation writes AND by Phase B's FACTS renderer —
/// one derivation, two tiers, zero drift.
class GoalWakeDerivation {
  const GoalWakeDerivation({
    required this.version,
    required this.facts,
    required this.periodKey,
    required this.priors,
    this.existingToday,
  });

  final GoalSpecVersionEntity version;
  final GoalWakeFacts facts;

  /// The evaluation day's register period key.
  final String periodKey;

  /// Most-recent-first prior register rows (consecutive, same spec
  /// version — the grace streak).
  final List<GoalProgressEntity> priors;

  /// Today's already-persisted register row, if any.
  final GoalProgressEntity? existingToday;
}
