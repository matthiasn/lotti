// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_list_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CheckListItemImpl _$$CheckListItemImplFromJson(Map<String, dynamic> json) =>
    _$CheckListItemImpl(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: (json['utcOffset'] as num).toInt(),
      plainText: json['plainText'] as String,
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$CheckListItemImplToJson(_$CheckListItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'plainText': instance.plainText,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
