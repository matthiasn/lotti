import 'dart:convert';

import 'package:crypto/crypto.dart' show sha1;
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';

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

/// `int` and `double` must fingerprint identically after a JSON round-trip,
/// so every numeric value is normalized through a fixed-precision double.
String _digestNum(num value) => value.toDouble().toStringAsFixed(4);

String _evidenceDigest(
  GoalTrackStatus trackStatus,
  Iterable<({String id, num actual, bool satisfied})> criteria,
) {
  final sorted = criteria.toList()..sort((a, b) => a.id.compareTo(b.id));
  return [
    trackStatus.name,
    for (final criterion in sorted)
      '${criterion.id}=${_digestNum(criterion.actual)}:${criterion.satisfied}',
  ].join('|');
}

/// Deterministic fingerprint of the aggregate evidence persisted in a goal
/// progress register.
String goalAggregateFactsDigest(GoalWakeFacts facts) => _evidenceDigest(
  facts.trackStatus,
  facts.evaluation.results.values.map(
    (result) => (
      id: result.criterionId,
      actual: result.actual,
      satisfied: result.satisfied,
    ),
  ),
);

String _healthEvidenceDigest(
  Map<String, List<GoalMetricObservation>> observationsByType,
) {
  if (observationsByType.isEmpty) return '';
  final types = observationsByType.keys.toList()..sort();
  final evidence = <String>[];
  for (final type in types) {
    final observations = [...observationsByType[type]!]
      ..sort((a, b) {
        final byTime = a.recordedAt.compareTo(b.recordedAt);
        return byTime != 0 ? byTime : a.tieBreaker.compareTo(b.tieBreaker);
      });
    evidence
      ..add(type)
      ..addAll(
        observations.map(
          (observation) =>
              '${observation.recordedAt.toIso8601String()}='
              '${_digestNum(observation.value)}',
        ),
      );
  }
  return sha1.convert(utf8.encode(evidence.join('|'))).toString();
}

/// Exact observations that one health criterion can expose to inference.
///
/// Keeping this projection shared by rendering and freshness guarantees that
/// a prior-period backfill cannot stale copy when it is absent from FACTS.
List<GoalMetricObservation> goalHealthObservationsForCriterion({
  required GoalCriterionMetric metric,
  required GoalWakeFacts facts,
  required DateTime evaluationReference,
}) {
  if (!GoalHealthDataTypes.supported.contains(metric.dataType)) {
    return const [];
  }
  final range = metric.window.periodRange(evaluationReference);
  final candidates =
      facts.quantitativeObservationsByType[metric.dataType] ??
      const <GoalMetricObservation>[];
  return <GoalMetricObservation>[
    for (final observation in candidates)
      if (!GoalWindow.dayUtc(observation.recordedAt).isBefore(range.start) &&
          !GoalWindow.dayUtc(observation.recordedAt).isAfter(range.end) &&
          !observation.recordedAt.isAfter(evaluationReference))
        observation,
  ]..sort((a, b) {
    final byTime = a.recordedAt.compareTo(b.recordedAt);
    return byTime != 0 ? byTime : a.tieBreaker.compareTo(b.tieBreaker);
  });
}

Map<String, List<GoalMetricObservation>> _renderedHealthEvidence({
  required GoalCriterion criteria,
  required GoalWakeFacts facts,
  required DateTime evaluationReference,
}) {
  final evidence = <String, List<GoalMetricObservation>>{};

  void visit(GoalCriterion criterion) {
    switch (criterion) {
      case final GoalCriterionMetric metric
          when GoalHealthDataTypes.supported.contains(metric.dataType):
        evidence['${metric.criterionId}:${metric.dataType}'] =
            goalHealthObservationsForCriterion(
              metric: metric,
              facts: facts,
              evaluationReference: evaluationReference,
            );
      case GoalCriterionAllOf(:final criteria) ||
          GoalCriterionAnyOf(:final criteria) ||
          GoalCriterionAtLeastCount(:final criteria):
        criteria.forEach(visit);
      case GoalCriterionMetric() ||
          GoalCriterionHabit() ||
          GoalCriterionMeasurable() ||
          GoalCriterionCategoryTime():
        break;
    }
  }

  visit(criteria);
  return evidence;
}

/// Deterministic fingerprint of every fact that can shape banner copy: the
/// aggregate register evidence plus exact model-facing health observations.
///
/// Phase B stamps this into a banner's provenance at minting; Phase A's
/// staleness sweep compares it against the current derivation, so a banner
/// quoting evidence that has since changed is recognized as data-stale even
/// when a backfill leaves the daily aggregate unchanged.
String goalFactsDigest(
  GoalWakeFacts facts, {
  required GoalCriterion criteria,
  required DateTime evaluationReference,
}) {
  final aggregate = goalAggregateFactsDigest(facts);
  final health = _healthEvidenceDigest(
    _renderedHealthEvidence(
      criteria: criteria,
      facts: facts,
      evaluationReference: evaluationReference,
    ),
  );
  return health.isEmpty ? aggregate : '$aggregate|health=$health';
}

/// The same fingerprint computed from a persisted register row, so a fresh
/// derivation can be compared against what the last tick recorded.
String goalRegisterDigest(GoalProgressEntity row) => _evidenceDigest(
  row.trackStatus,
  row.criterionResults.map(
    (result) => (
      id: result.criterionId,
      actual: result.actual,
      satisfied: result.satisfied,
    ),
  ),
);

/// The deterministic facts one Phase A tick derives for a goal agent
/// (ADR 0054): everything downstream — escalation, and in PR 3 the FACTS
/// block and the tool gate — reads these, never raw signals.
class GoalWakeFacts {
  const GoalWakeFacts({
    required this.trackStatus,
    required this.evaluation,
    this.previousStatus,
    this.shortTermAttainment,
    this.quantitativeObservationsByType = const {},
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

  /// Exact quantitative samples retained for Phase B evidence. Deterministic
  /// policy still reads [evaluation], never this model-facing series.
  final Map<String, List<GoalMetricObservation>> quantitativeObservationsByType;

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
