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
      isArchived: json['isArchived'] as bool? ?? false,
      id: json['id'] as String?,
      checkedBy: $enumDecodeNullable(
              _$CheckedBySourceEnumMap, json['checkedBy'],
              unknownValue: CheckedBySource.user) ??
          CheckedBySource.user,
      checkedAt: json['checkedAt'] == null
          ? null
          : DateTime.parse(json['checkedAt'] as String),
    );

Map<String, dynamic> _$ChecklistItemDataToJson(_ChecklistItemData instance) =>
    <String, dynamic>{
      'title': instance.title,
      'isChecked': instance.isChecked,
      'linkedChecklists': instance.linkedChecklists,
      'isArchived': instance.isArchived,
      'id': instance.id,
      'checkedBy': _$CheckedBySourceEnumMap[instance.checkedBy]!,
      'checkedAt': instance.checkedAt?.toIso8601String(),
    };

const _$CheckedBySourceEnumMap = {
  CheckedBySource.user: 'user',
  CheckedBySource.agent: 'agent',
};
