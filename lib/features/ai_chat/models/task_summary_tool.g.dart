// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_summary_tool.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TaskSummaryRequestImpl _$$TaskSummaryRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$TaskSummaryRequestImpl(
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      limit: (json['limit'] as num?)?.toInt() ?? 100,
    );

Map<String, dynamic> _$$TaskSummaryRequestImplToJson(
        _$TaskSummaryRequestImpl instance) =>
    <String, dynamic>{
      'start_date': instance.startDate,
      'end_date': instance.endDate,
      'limit': instance.limit,
    };

_$TaskSummaryResultImpl _$$TaskSummaryResultImplFromJson(
        Map<String, dynamic> json) =>
    _$TaskSummaryResultImpl(
      taskId: json['taskId'] as String,
      taskTitle: json['taskTitle'] as String,
      summary: json['summary'] as String,
      taskDate: DateTime.parse(json['taskDate'] as String),
      status: json['status'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$TaskSummaryResultImplToJson(
        _$TaskSummaryResultImpl instance) =>
    <String, dynamic>{
      'taskId': instance.taskId,
      'taskTitle': instance.taskTitle,
      'summary': instance.summary,
      'taskDate': instance.taskDate.toIso8601String(),
      'status': instance.status,
      'metadata': instance.metadata,
    };
