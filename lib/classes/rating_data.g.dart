// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RatingData _$RatingDataFromJson(Map<String, dynamic> json) => _RatingData(
      timeEntryId: json['timeEntryId'] as String,
      dimensions: (json['dimensions'] as List<dynamic>)
          .map((e) => RatingDimension.fromJson(e as Map<String, dynamic>))
          .toList(),
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      note: json['note'] as String?,
    );

Map<String, dynamic> _$RatingDataToJson(_RatingData instance) =>
    <String, dynamic>{
      'timeEntryId': instance.timeEntryId,
      'dimensions': instance.dimensions,
      'schemaVersion': instance.schemaVersion,
      'note': instance.note,
    };

_RatingDimension _$RatingDimensionFromJson(Map<String, dynamic> json) =>
    _RatingDimension(
      key: json['key'] as String,
      value: (json['value'] as num).toDouble(),
    );

Map<String, dynamic> _$RatingDimensionToJson(_RatingDimension instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
    };
