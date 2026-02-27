// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'change_set.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChangeItem _$ChangeItemFromJson(Map<String, dynamic> json) => _ChangeItem(
      toolName: json['toolName'] as String,
      args: json['args'] as Map<String, dynamic>,
      humanSummary: json['humanSummary'] as String,
      status: $enumDecodeNullable(_$ChangeItemStatusEnumMap, json['status']) ??
          ChangeItemStatus.pending,
    );

Map<String, dynamic> _$ChangeItemToJson(_ChangeItem instance) =>
    <String, dynamic>{
      'toolName': instance.toolName,
      'args': instance.args,
      'humanSummary': instance.humanSummary,
      'status': _$ChangeItemStatusEnumMap[instance.status]!,
    };

const _$ChangeItemStatusEnumMap = {
  ChangeItemStatus.pending: 'pending',
  ChangeItemStatus.confirmed: 'confirmed',
  ChangeItemStatus.rejected: 'rejected',
  ChangeItemStatus.deferred: 'deferred',
};
