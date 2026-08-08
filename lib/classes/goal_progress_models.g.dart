// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_progress_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GoalCriterionProgress _$GoalCriterionProgressFromJson(
  Map<String, dynamic> json,
) => _GoalCriterionProgress(
  criterionId: json['criterionId'] as String,
  actual: json['actual'] as num,
  target: json['target'] as num,
  ratio: (json['ratio'] as num).toDouble(),
  satisfied: json['satisfied'] as bool,
  sampleCount: (json['sampleCount'] as num).toInt(),
  paceFeasible: json['paceFeasible'] as bool?,
);

Map<String, dynamic> _$GoalCriterionProgressToJson(
  _GoalCriterionProgress instance,
) => <String, dynamic>{
  'criterionId': instance.criterionId,
  'actual': instance.actual,
  'target': instance.target,
  'ratio': instance.ratio,
  'satisfied': instance.satisfied,
  'sampleCount': instance.sampleCount,
  'paceFeasible': instance.paceFeasible,
};
