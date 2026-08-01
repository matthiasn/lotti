// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating_question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RatingQuestionOption _$RatingQuestionOptionFromJson(
  Map<String, dynamic> json,
) => _RatingQuestionOption(
  label: json['label'] as String,
  value: (json['value'] as num).toDouble(),
);

Map<String, dynamic> _$RatingQuestionOptionToJson(
  _RatingQuestionOption instance,
) => <String, dynamic>{'label': instance.label, 'value': instance.value};
