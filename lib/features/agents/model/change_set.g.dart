// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'change_set.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChangeItem _$ChangeItemFromJson(Map<String, dynamic> json) => _ChangeItem(
  toolName: json['toolName'] as String,
  args: json['args'] as Map<String, dynamic>,
  humanSummary: json['humanSummary'] as String,
  status:
      $enumDecodeNullable(_$ChangeItemStatusEnumMap, json['status']) ??
      ChangeItemStatus.pending,
  groupId: json['groupId'] as String?,
  revision: (json['revision'] as num?)?.toInt(),
  effectKey: json['effectKey'] as String?,
  base: json['base'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ChangeItemToJson(_ChangeItem instance) =>
    <String, dynamic>{
      'toolName': instance.toolName,
      'args': instance.args,
      'humanSummary': instance.humanSummary,
      'status': _$ChangeItemStatusEnumMap[instance.status]!,
      'groupId': instance.groupId,
      'revision': instance.revision,
      'effectKey': instance.effectKey,
      'base': instance.base,
    };

const _$ChangeItemStatusEnumMap = {
  ChangeItemStatus.pending: 'pending',
  ChangeItemStatus.confirmed: 'confirmed',
  ChangeItemStatus.rejected: 'rejected',
  ChangeItemStatus.deferred: 'deferred',
  ChangeItemStatus.retracted: 'retracted',
};
