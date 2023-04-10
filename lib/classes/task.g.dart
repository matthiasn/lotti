// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_TaskOpen _$$_TaskOpenFromJson(Map<String, dynamic> json) => _$_TaskOpen(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: json['utcOffset'] as int,
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$_TaskOpenToJson(_$_TaskOpen instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$_TaskStarted _$$_TaskStartedFromJson(Map<String, dynamic> json) =>
    _$_TaskStarted(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: json['utcOffset'] as int,
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$_TaskStartedToJson(_$_TaskStarted instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$_TaskInProgress _$$_TaskInProgressFromJson(Map<String, dynamic> json) =>
    _$_TaskInProgress(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: json['utcOffset'] as int,
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$_TaskInProgressToJson(_$_TaskInProgress instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$_TaskGroomed _$$_TaskGroomedFromJson(Map<String, dynamic> json) =>
    _$_TaskGroomed(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: json['utcOffset'] as int,
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$_TaskGroomedToJson(_$_TaskGroomed instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$_TaskBlocked _$$_TaskBlockedFromJson(Map<String, dynamic> json) =>
    _$_TaskBlocked(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: json['utcOffset'] as int,
      reason: json['reason'] as String,
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$_TaskBlockedToJson(_$_TaskBlocked instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'reason': instance.reason,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$_TaskOnHold _$$_TaskOnHoldFromJson(Map<String, dynamic> json) =>
    _$_TaskOnHold(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: json['utcOffset'] as int,
      reason: json['reason'] as String,
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$_TaskOnHoldToJson(_$_TaskOnHold instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'reason': instance.reason,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$_TaskDone _$$_TaskDoneFromJson(Map<String, dynamic> json) => _$_TaskDone(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: json['utcOffset'] as int,
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$_TaskDoneToJson(_$_TaskDone instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$_TaskRejected _$$_TaskRejectedFromJson(Map<String, dynamic> json) =>
    _$_TaskRejected(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: json['utcOffset'] as int,
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$_TaskRejectedToJson(_$_TaskRejected instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_$_TaskData _$$_TaskDataFromJson(Map<String, dynamic> json) => _$_TaskData(
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
          : Duration(microseconds: json['estimate'] as int),
      checklist: (json['checklist'] as List<dynamic>?)
          ?.map((e) => CheckListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$_TaskDataToJson(_$_TaskData instance) =>
    <String, dynamic>{
      'status': instance.status,
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'statusHistory': instance.statusHistory,
      'title': instance.title,
      'due': instance.due?.toIso8601String(),
      'estimate': instance.estimate?.inMicroseconds,
      'checklist': instance.checklist,
    };
