// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GoalData _$GoalDataFromJson(Map<String, dynamic> json) => _GoalData(
  title: json['title'] as String,
  statement: json['statement'] as String,
  criteria: GoalCriterion.fromJson(json['criteria'] as Map<String, dynamic>),
  specVersion: (json['specVersion'] as num).toInt(),
  specVersionId: json['specVersionId'] as String,
  startDate: json['startDate'] == null
      ? null
      : DateTime.parse(json['startDate'] as String),
  targetDate: json['targetDate'] == null
      ? null
      : DateTime.parse(json['targetDate'] as String),
  rationale: json['rationale'] as String?,
  snapshotOf: json['snapshotOf'] as String?,
);

Map<String, dynamic> _$GoalDataToJson(_GoalData instance) => <String, dynamic>{
  'title': instance.title,
  'statement': instance.statement,
  'criteria': instance.criteria,
  'specVersion': instance.specVersion,
  'specVersionId': instance.specVersionId,
  'startDate': instance.startDate?.toIso8601String(),
  'targetDate': instance.targetDate?.toIso8601String(),
  'rationale': instance.rationale,
  'snapshotOf': instance.snapshotOf,
};
