// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskOpen _$TaskOpenFromJson(Map<String, dynamic> json) => TaskOpen(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$TaskOpenToJson(TaskOpen instance) => <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

TaskInProgress _$TaskInProgressFromJson(Map<String, dynamic> json) =>
    TaskInProgress(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$TaskInProgressToJson(TaskInProgress instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

TaskGroomed _$TaskGroomedFromJson(Map<String, dynamic> json) => TaskGroomed(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$TaskGroomedToJson(TaskGroomed instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

TaskBlocked _$TaskBlockedFromJson(Map<String, dynamic> json) => TaskBlocked(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      reason: json['reason'] as String,
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$TaskBlockedToJson(TaskBlocked instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'reason': instance.reason,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

TaskOnHold _$TaskOnHoldFromJson(Map<String, dynamic> json) => TaskOnHold(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      reason: json['reason'] as String,
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$TaskOnHoldToJson(TaskOnHold instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'reason': instance.reason,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

TaskDone _$TaskDoneFromJson(Map<String, dynamic> json) => TaskDone(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$TaskDoneToJson(TaskDone instance) => <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

TaskRejected _$TaskRejectedFromJson(Map<String, dynamic> json) => TaskRejected(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$TaskRejectedToJson(TaskRejected instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_TaskData _$TaskDataFromJson(Map<String, dynamic> json) => _TaskData(
      status: TaskStatus.fromJson(json['status'] as Map<String, dynamic>),
      dateFrom: DateTime.parse(json['dateFrom'] as String),
      dateTo: DateTime.parse(json['dateTo'] as String),
      statusHistory: (json['statusHistory'] as List<dynamic>)
          .map((e) => TaskStatus.fromJson(e as Map<String, dynamic>))
          .toList(),
      title: json['title'] as String,
      due: json['due'] == null ? null : DateTime.parse(json['due'] as String),
      estimate: json['estimate'] == null
          ? null
          : Duration(microseconds: (json['estimate'] as num).toInt()),
      checklistIds: (json['checklistIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      languageCode: json['languageCode'] as String?,
      aiSuppressedLabelIds: (json['aiSuppressedLabelIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet(),
      priority: $enumDecodeNullable(_$TaskPriorityEnumMap, json['priority']) ??
          TaskPriority.p2Medium,
    );

Map<String, dynamic> _$TaskDataToJson(_TaskData instance) => <String, dynamic>{
      'status': instance.status,
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'statusHistory': instance.statusHistory,
      'title': instance.title,
      'due': instance.due?.toIso8601String(),
      'estimate': instance.estimate?.inMicroseconds,
      'checklistIds': instance.checklistIds,
      'languageCode': instance.languageCode,
      'aiSuppressedLabelIds': instance.aiSuppressedLabelIds?.toList(),
      'priority': _$TaskPriorityEnumMap[instance.priority]!,
    };

const _$TaskPriorityEnumMap = {
  TaskPriority.p0Urgent: 'p0Urgent',
  TaskPriority.p1High: 'p1High',
  TaskPriority.p2Medium: 'p2Medium',
  TaskPriority.p3Low: 'p3Low',
};
