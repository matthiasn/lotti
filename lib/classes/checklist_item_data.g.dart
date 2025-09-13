// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_item_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChecklistItemData _$ChecklistItemDataFromJson(Map<String, dynamic> json) =>
    _ChecklistItemData(
      title: json['title'] as String,
      isChecked: json['isChecked'] as bool,
      linkedChecklists: (json['linkedChecklists'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      id: json['id'] as String?,
    );

Map<String, dynamic> _$ChecklistItemDataToJson(_ChecklistItemData instance) =>
    <String, dynamic>{
      'title': instance.title,
      'isChecked': instance.isChecked,
      'linkedChecklists': instance.linkedChecklists,
      'id': instance.id,
    };
