// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskOpen _$TaskOpenFromJson(Map<String, dynamic> json) => _TaskOpen(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$TaskOpenToJson(_TaskOpen instance) => <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_TaskInProgress _$TaskInProgressFromJson(Map<String, dynamic> json) =>
    _TaskInProgress(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$TaskInProgressToJson(_TaskInProgress instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_TaskGroomed _$TaskGroomedFromJson(Map<String, dynamic> json) => _TaskGroomed(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$TaskGroomedToJson(_TaskGroomed instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_TaskBlocked _$TaskBlockedFromJson(Map<String, dynamic> json) => _TaskBlocked(
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

Map<String, dynamic> _$TaskBlockedToJson(_TaskBlocked instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'reason': instance.reason,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_TaskOnHold _$TaskOnHoldFromJson(Map<String, dynamic> json) => _TaskOnHold(
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

Map<String, dynamic> _$TaskOnHoldToJson(_TaskOnHold instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'reason': instance.reason,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_TaskDone _$TaskDoneFromJson(Map<String, dynamic> json) => _TaskDone(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$TaskDoneToJson(_TaskDone instance) => <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_TaskRejected _$TaskRejectedFromJson(Map<String, dynamic> json) =>
    _TaskRejected(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$TaskRejectedToJson(_TaskRejected instance) =>
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
    };
