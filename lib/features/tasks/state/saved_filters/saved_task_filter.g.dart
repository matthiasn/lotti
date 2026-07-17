// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_task_filter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SavedTaskFilter _$SavedTaskFilterFromJson(Map<String, dynamic> json) =>
    _SavedTaskFilter(
      id: json['id'] as String,
      name: json['name'] as String,
      filter: TasksFilter.fromJson(json['filter'] as Map<String, dynamic>),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$SavedTaskFilterToJson(_SavedTaskFilter instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'filter': instance.filter.toJson(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
