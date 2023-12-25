// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_type_definitions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GenericTagImpl _$$GenericTagImplFromJson(Map<String, dynamic> json) =>
    _$GenericTagImpl(
      id: json['id'] as String,
      tag: json['tag'] as String,
      private: json['private'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      inactive: json['inactive'] as bool?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$GenericTagImplToJson(_$GenericTagImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tag': instance.tag,
      'private': instance.private,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'inactive': instance.inactive,
      'runtimeType': instance.$type,
    };

_$PersonTagImpl _$$PersonTagImplFromJson(Map<String, dynamic> json) =>
    _$PersonTagImpl(
      id: json['id'] as String,
      tag: json['tag'] as String,
      private: json['private'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      inactive: json['inactive'] as bool?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$PersonTagImplToJson(_$PersonTagImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tag': instance.tag,
      'private': instance.private,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'inactive': instance.inactive,
      'runtimeType': instance.$type,
    };

_$StoryTagImpl _$$StoryTagImplFromJson(Map<String, dynamic> json) =>
    _$StoryTagImpl(
      id: json['id'] as String,
      tag: json['tag'] as String,
      private: json['private'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      description: json['description'] as String?,
      longTitle: json['longTitle'] as String?,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      inactive: json['inactive'] as bool?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$StoryTagImplToJson(_$StoryTagImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tag': instance.tag,
      'private': instance.private,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'description': instance.description,
      'longTitle': instance.longTitle,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'inactive': instance.inactive,
      'runtimeType': instance.$type,
    };
