// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_query.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TaskQueryImpl _$$TaskQueryImplFromJson(Map<String, dynamic> json) =>
    _$TaskQueryImpl(
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      categoryIds: (json['categoryIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      tagIds:
          (json['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
      limit: (json['limit'] as num?)?.toInt(),
      queryType: $enumDecodeNullable(_$TaskQueryTypeEnumMap, json['queryType']),
      filters: json['filters'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$TaskQueryImplToJson(_$TaskQueryImpl instance) =>
    <String, dynamic>{
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'categoryIds': instance.categoryIds,
      'tagIds': instance.tagIds,
      'limit': instance.limit,
      'queryType': _$TaskQueryTypeEnumMap[instance.queryType],
      'filters': instance.filters,
    };

const _$TaskQueryTypeEnumMap = {
  TaskQueryType.all: 'all',
  TaskQueryType.withTimeLogged: 'withTimeLogged',
  TaskQueryType.withAiSummary: 'withAiSummary',
  TaskQueryType.completed: 'completed',
  TaskQueryType.incomplete: 'incomplete',
};
