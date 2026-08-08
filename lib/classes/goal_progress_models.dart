import 'package:freezed_annotation/freezed_annotation.dart';

part 'goal_progress_models.freezed.dart';
part 'goal_progress_models.g.dart';

/// Persisted per-criterion outcome inside a `goalProgress` register row —
/// the serializable form of the evaluator's `GoalCriterionResult`
/// (ADR 0053 Decision 4).
///
/// Stored so a decade of charts can show *which* leg of a composite goal
/// carried or failed a period without re-reading the source journal, and so
/// the agent's wake facts can name the failing dimension.
@freezed
abstract class GoalCriterionProgress with _$GoalCriterionProgress {
  const factory GoalCriterionProgress({
    required String criterionId,
    required num actual,
    required num target,
    required double ratio,
    required bool satisfied,
    required int sampleCount,
    bool? paceFeasible,
  }) = _GoalCriterionProgress;

  factory GoalCriterionProgress.fromJson(Map<String, dynamic> json) =>
      _$GoalCriterionProgressFromJson(json);
}
