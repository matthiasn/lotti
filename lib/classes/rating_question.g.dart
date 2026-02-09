// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating_question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RatingQuestion _$RatingQuestionFromJson(Map<String, dynamic> json) =>
    _RatingQuestion(
      key: json['key'] as String,
      question: json['question'] as String,
      description: json['description'] as String,
      inputType: json['inputType'] as String? ?? 'tapBar',
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => RatingQuestionOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RatingQuestionToJson(_RatingQuestion instance) =>
    <String, dynamic>{
      'key': instance.key,
      'question': instance.question,
      'description': instance.description,
      'inputType': instance.inputType,
      'options': instance.options,
    };

_RatingQuestionOption _$RatingQuestionOptionFromJson(
        Map<String, dynamic> json) =>
    _RatingQuestionOption(
      label: json['label'] as String,
      value: (json['value'] as num).toDouble(),
    );

Map<String, dynamic> _$RatingQuestionOptionToJson(
        _RatingQuestionOption instance) =>
    <String, dynamic>{
      'label': instance.label,
      'value': instance.value,
    };
