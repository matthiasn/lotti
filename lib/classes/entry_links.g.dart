// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_links.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BasicLinkImpl _$$BasicLinkImplFromJson(Map<String, dynamic> json) =>
    _$BasicLinkImpl(
      id: json['id'] as String,
      fromId: json['fromId'] as String,
      toId: json['toId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      hidden: json['hidden'] as bool?,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
    );

Map<String, dynamic> _$$BasicLinkImplToJson(_$BasicLinkImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromId': instance.fromId,
      'toId': instance.toId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'hidden': instance.hidden,
      'deletedAt': instance.deletedAt?.toIso8601String(),
    };
