// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProjectOpen _$ProjectOpenFromJson(Map<String, dynamic> json) => ProjectOpen(
  id: json['id'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  utcOffset: (json['utcOffset'] as num).toInt(),
  timezone: json['timezone'] as String?,
  geolocation: json['geolocation'] == null
      ? null
      : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$ProjectOpenToJson(ProjectOpen instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

ProjectActive _$ProjectActiveFromJson(Map<String, dynamic> json) =>
    ProjectActive(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$ProjectActiveToJson(ProjectActive instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

ProjectOnHold _$ProjectOnHoldFromJson(Map<String, dynamic> json) =>
    ProjectOnHold(
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

Map<String, dynamic> _$ProjectOnHoldToJson(ProjectOnHold instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'reason': instance.reason,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

ProjectCompleted _$ProjectCompletedFromJson(Map<String, dynamic> json) =>
    ProjectCompleted(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$ProjectCompletedToJson(ProjectCompleted instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

ProjectArchived _$ProjectArchivedFromJson(Map<String, dynamic> json) =>
    ProjectArchived(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$ProjectArchivedToJson(ProjectArchived instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'runtimeType': instance.$type,
    };

_ProjectData _$ProjectDataFromJson(Map<String, dynamic> json) => _ProjectData(
  title: json['title'] as String,
  status: ProjectStatus.fromJson(json['status'] as Map<String, dynamic>),
  dateFrom: DateTime.parse(json['dateFrom'] as String),
  dateTo: DateTime.parse(json['dateTo'] as String),
  statusHistory:
      (json['statusHistory'] as List<dynamic>?)
          ?.map((e) => ProjectStatus.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  targetDate: json['targetDate'] == null
      ? null
      : DateTime.parse(json['targetDate'] as String),
  profileId: json['profileId'] as String?,
  coverArtId: json['coverArtId'] as String?,
  coverArtCropX: (json['coverArtCropX'] as num?)?.toDouble() ?? 0.5,
);

Map<String, dynamic> _$ProjectDataToJson(_ProjectData instance) =>
    <String, dynamic>{
      'title': instance.title,
      'status': instance.status,
      'dateFrom': instance.dateFrom.toIso8601String(),
      'dateTo': instance.dateTo.toIso8601String(),
      'statusHistory': instance.statusHistory,
      'targetDate': instance.targetDate?.toIso8601String(),
      'profileId': instance.profileId,
      'coverArtId': instance.coverArtId,
      'coverArtCropX': instance.coverArtCropX,
    };
