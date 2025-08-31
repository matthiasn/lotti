// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TaskSummaryImpl _$$TaskSummaryImplFromJson(Map<String, dynamic> json) =>
    _$TaskSummaryImpl(
      taskId: json['taskId'] as String,
      taskName: json['taskName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      aiSummary: json['aiSummary'] as String?,
      timeLogged: json['timeLogged'] == null
          ? null
          : Duration(microseconds: (json['timeLogged'] as num).toInt()),
      status: $enumDecodeNullable(_$TaskStatusEnumMap, json['status']),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$TaskSummaryImplToJson(_$TaskSummaryImpl instance) =>
    <String, dynamic>{
      'taskId': instance.taskId,
      'taskName': instance.taskName,
      'createdAt': instance.createdAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'categoryId': instance.categoryId,
      'categoryName': instance.categoryName,
      'tags': instance.tags,
      'aiSummary': instance.aiSummary,
      'timeLogged': instance.timeLogged?.inMicroseconds,
      'status': _$TaskStatusEnumMap[instance.status],
      'metadata': instance.metadata,
    };

const _$TaskStatusEnumMap = {
  TaskStatus.planned: 'planned',
  TaskStatus.inProgress: 'inProgress',
  TaskStatus.completed: 'completed',
  TaskStatus.cancelled: 'cancelled',
};

_$TaskSummaryResultImpl _$$TaskSummaryResultImplFromJson(
        Map<String, dynamic> json) =>
    _$TaskSummaryResultImpl(
      tasks: (json['tasks'] as List<dynamic>)
          .map((e) => TaskSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      queryStartDate: DateTime.parse(json['queryStartDate'] as String),
      queryEndDate: DateTime.parse(json['queryEndDate'] as String),
      totalCount: (json['totalCount'] as num).toInt(),
      limitApplied: (json['limitApplied'] as num?)?.toInt(),
      categoriesQueried: (json['categoriesQueried'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      tagsQueried: (json['tagsQueried'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$$TaskSummaryResultImplToJson(
        _$TaskSummaryResultImpl instance) =>
    <String, dynamic>{
      'tasks': instance.tasks,
      'queryStartDate': instance.queryStartDate.toIso8601String(),
      'queryEndDate': instance.queryEndDate.toIso8601String(),
      'totalCount': instance.totalCount,
      'limitApplied': instance.limitApplied,
      'categoriesQueried': instance.categoriesQueried,
      'tagsQueried': instance.tagsQueried,
    };
