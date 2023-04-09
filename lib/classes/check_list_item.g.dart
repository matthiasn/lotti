// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_list_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_CheckListItem _$$_CheckListItemFromJson(Map<String, dynamic> json) =>
    _$_CheckListItem(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      utcOffset: json['utcOffset'] as int,
      plainText: json['plainText'] as String,
      timezone: json['timezone'] as String?,
      geolocation: json['geolocation'] == null
          ? null
          : Geolocation.fromJson(json['geolocation'] as Map<String, dynamic>),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$_CheckListItemToJson(_$_CheckListItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'utcOffset': instance.utcOffset,
      'plainText': instance.plainText,
      'timezone': instance.timezone,
      'geolocation': instance.geolocation,
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
