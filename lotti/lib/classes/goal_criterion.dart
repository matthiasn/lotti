import 'package:freezed_annotation/freezed_annotation.dart';

part 'goal_criterion.freezed.dart';
part 'goal_criterion.g.dart';

@freezed
class GoalCriterion with _$GoalCriterion {
  factory GoalCriterion({
    required String measurableTypeId,
    String? comment,
    num? min,
    num? max,
    DateTime? validFrom,
    DateTime? validTo,
  }) = _GoalCriterion;

  factory GoalCriterion.fromJson(Map<String, dynamic> json) =>
      _$GoalCriterionFromJson(json);
}
