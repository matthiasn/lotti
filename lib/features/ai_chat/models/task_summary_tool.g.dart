// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_summary_tool.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskSummaryRequest _$TaskSummaryRequestFromJson(Map<String, dynamic> json) =>
    _TaskSummaryRequest(
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      limit: (json['limit'] as num?)?.toInt() ?? 100,
    );

Map<String, dynamic> _$TaskSummaryRequestToJson(_TaskSummaryRequest instance) =>
    <String, dynamic>{
      'start_date': instance.startDate,
      'end_date': instance.endDate,
      'limit': instance.limit,
    };

_TaskSummaryResult _$TaskSummaryResultFromJson(Map<String, dynamic> json) =>
    _TaskSummaryResult(
      taskId: json['taskId'] as String,
      taskTitle: json['taskTitle'] as String,
      summary: json['summary'] as String,
      taskDate: DateTime.parse(json['taskDate'] as String),
      status: json['status'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$TaskSummaryResultToJson(_TaskSummaryResult instance) =>
    <String, dynamic>{
      'taskId': instance.taskId,
      'taskTitle': instance.taskTitle,
      'summary': instance.summary,
      'taskDate': instance.taskDate.toIso8601String(),
      'status': instance.status,
      'metadata': instance.metadata,
    };
