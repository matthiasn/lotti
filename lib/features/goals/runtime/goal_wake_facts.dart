import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';

/// The deterministic facts one Phase A tick derives for a goal agent
/// (ADR 0054): everything downstream — escalation, and in PR 3 the FACTS
/// block and the tool gate — reads these, never raw signals.
class GoalWakeFacts {
  const GoalWakeFacts({
    required this.trackStatus,
    required this.evaluation,
    this.previousStatus,
    this.shortTermAttainment,
  });

  /// Policy-derived status for the evaluation day.
  final GoalTrackStatus trackStatus;

  /// The most recent previously persisted status, if any register row
  /// exists for a prior day.
  final GoalTrackStatus? previousStatus;

  final GoalEvaluation evaluation;
  final double? shortTermAttainment;

  /// Whether the status changed against the last persisted register row.
  /// A first-ever evaluation counts as a transition (there is a new fact
  /// where there was none).
  bool get statusTransitioned => trackStatus != previousStatus;

  /// Whether this tick warrants waking the LLM tier (Phase B, PR 3).
  ///
  /// v1 policy: only a status transition is LLM-worthy — an unchanged
  /// status is the common no-op tick that must cost €0 and write no
  /// messages. Ad staleness and dialogue triggers join this predicate
  /// with PR 5's nudge state.
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
