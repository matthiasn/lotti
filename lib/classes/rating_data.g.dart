// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RatingData _$RatingDataFromJson(Map<String, dynamic> json) => _RatingData(
      targetId: json['timeEntryId'] as String,
      dimensions: (json['dimensions'] as List<dynamic>)
          .map((e) => RatingDimension.fromJson(e as Map<String, dynamic>))
          .toList(),
      catalogId: json['catalogId'] as String? ?? 'session',
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      note: json['note'] as String?,
    );

Map<String, dynamic> _$RatingDataToJson(_RatingData instance) =>
    <String, dynamic>{
      'timeEntryId': instance.targetId,
      'dimensions': instance.dimensions,
      'catalogId': instance.catalogId,
      'schemaVersion': instance.schemaVersion,
      'note': instance.note,
    };

_RatingDimension _$RatingDimensionFromJson(Map<String, dynamic> json) =>
    _RatingDimension(
      key: json['key'] as String,
      value: (json['value'] as num).toDouble(),
      question: json['question'] as String?,
      description: json['description'] as String?,
      inputType: json['inputType'] as String?,
      optionLabels: (json['optionLabels'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      optionValues: (json['optionValues'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );

Map<String, dynamic> _$RatingDimensionToJson(_RatingDimension instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
      'question': instance.question,
      'description': instance.description,
      'inputType': instance.inputType,
      'optionLabels': instance.optionLabels,
      'optionValues': instance.optionValues,
    };
