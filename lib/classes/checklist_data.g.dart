// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChecklistData _$ChecklistDataFromJson(Map<String, dynamic> json) =>
    _ChecklistData(
      title: json['title'] as String,
      linkedChecklistItems: (json['linkedChecklistItems'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      linkedTasks: (json['linkedTasks'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ChecklistDataToJson(_ChecklistData instance) =>
    <String, dynamic>{
      'title': instance.title,
      'linkedChecklistItems': instance.linkedChecklistItems,
      'linkedTasks': instance.linkedTasks,
    };
