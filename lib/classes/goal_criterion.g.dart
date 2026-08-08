// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_criterion.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoalCriterionMetric _$GoalCriterionMetricFromJson(Map<String, dynamic> json) =>
    GoalCriterionMetric(
      criterionId: json['criterionId'] as String,
      dataType: json['dataType'] as String,
      window: GoalWindow.fromJson(json['window'] as Map<String, dynamic>),
      aggregation: $enumDecode(_$GoalAggregationEnumMap, json['aggregation']),
      target: json['target'] as num,
      direction:
          $enumDecodeNullable(_$GoalDirectionEnumMap, json['direction']) ??
          GoalDirection.atLeast,
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$GoalCriterionMetricToJson(
  GoalCriterionMetric instance,
) => <String, dynamic>{
  'criterionId': instance.criterionId,
  'dataType': instance.dataType,
  'window': instance.window,
  'aggregation': _$GoalAggregationEnumMap[instance.aggregation]!,
  'target': instance.target,
  'direction': _$GoalDirectionEnumMap[instance.direction]!,
  'title': instance.title,
  'runtimeType': instance.$type,
};

const _$GoalAggregationEnumMap = {
  GoalAggregation.dailySumThenAverage: 'dailySumThenAverage',
  GoalAggregation.sum: 'sum',
  GoalAggregation.count: 'count',
  GoalAggregation.max: 'max',
};

const _$GoalDirectionEnumMap = {
  GoalDirection.atLeast: 'atLeast',
  GoalDirection.atMost: 'atMost',
};

GoalCriterionHabit _$GoalCriterionHabitFromJson(Map<String, dynamic> json) =>
    GoalCriterionHabit(
      criterionId: json['criterionId'] as String,
      habitId: json['habitId'] as String,
      window: GoalWindow.fromJson(json['window'] as Map<String, dynamic>),
      targetCount: (json['targetCount'] as num).toInt(),
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$GoalCriterionHabitToJson(GoalCriterionHabit instance) =>
    <String, dynamic>{
      'criterionId': instance.criterionId,
      'habitId': instance.habitId,
      'window': instance.window,
      'targetCount': instance.targetCount,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

GoalCriterionMeasurable _$GoalCriterionMeasurableFromJson(
  Map<String, dynamic> json,
) => GoalCriterionMeasurable(
  criterionId: json['criterionId'] as String,
  dataTypeId: json['dataTypeId'] as String,
  window: GoalWindow.fromJson(json['window'] as Map<String, dynamic>),
  aggregation: $enumDecode(_$GoalAggregationEnumMap, json['aggregation']),
  target: json['target'] as num,
  direction:
      $enumDecodeNullable(_$GoalDirectionEnumMap, json['direction']) ??
      GoalDirection.atLeast,
  title: json['title'] as String?,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$GoalCriterionMeasurableToJson(
  GoalCriterionMeasurable instance,
) => <String, dynamic>{
  'criterionId': instance.criterionId,
  'dataTypeId': instance.dataTypeId,
  'window': instance.window,
  'aggregation': _$GoalAggregationEnumMap[instance.aggregation]!,
  'target': instance.target,
  'direction': _$GoalDirectionEnumMap[instance.direction]!,
  'title': instance.title,
  'runtimeType': instance.$type,
};

GoalCriterionAllOf _$GoalCriterionAllOfFromJson(Map<String, dynamic> json) =>
    GoalCriterionAllOf(
      criterionId: json['criterionId'] as String,
      criteria: (json['criteria'] as List<dynamic>)
          .map((e) => GoalCriterion.fromJson(e as Map<String, dynamic>))
          .toList(),
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$GoalCriterionAllOfToJson(GoalCriterionAllOf instance) =>
    <String, dynamic>{
      'criterionId': instance.criterionId,
      'criteria': instance.criteria,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

GoalCriterionAnyOf _$GoalCriterionAnyOfFromJson(Map<String, dynamic> json) =>
    GoalCriterionAnyOf(
      criterionId: json['criterionId'] as String,
      criteria: (json['criteria'] as List<dynamic>)
          .map((e) => GoalCriterion.fromJson(e as Map<String, dynamic>))
          .toList(),
      title: json['title'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$GoalCriterionAnyOfToJson(GoalCriterionAnyOf instance) =>
    <String, dynamic>{
      'criterionId': instance.criterionId,
      'criteria': instance.criteria,
      'title': instance.title,
      'runtimeType': instance.$type,
    };

GoalCriterionAtLeastCount _$GoalCriterionAtLeastCountFromJson(
  Map<String, dynamic> json,
) => GoalCriterionAtLeastCount(
  criterionId: json['criterionId'] as String,
  criteria: (json['criteria'] as List<dynamic>)
      .map((e) => GoalCriterion.fromJson(e as Map<String, dynamic>))
      .toList(),
  successes: (json['successes'] as num).toInt(),
  title: json['title'] as String?,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$GoalCriterionAtLeastCountToJson(
  GoalCriterionAtLeastCount instance,
) => <String, dynamic>{
  'criterionId': instance.criterionId,
  'criteria': instance.criteria,
  'successes': instance.successes,
  'title': instance.title,
  'runtimeType': instance.$type,
};
