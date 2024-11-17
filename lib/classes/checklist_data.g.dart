// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChecklistDataImpl _$$ChecklistDataImplFromJson(Map<String, dynamic> json) =>
    _$ChecklistDataImpl(
      title: json['title'] as String,
      linkedChecklistItems: (json['linkedChecklistItems'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$$ChecklistDataImplToJson(_$ChecklistDataImpl instance) =>
    <String, dynamic>{
      'title': instance.title,
      'linkedChecklistItems': instance.linkedChecklistItems,
    };
