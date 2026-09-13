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
      checkedBy:
          $enumDecodeNullable(
            _$ChangeSourceEnumMap,
            json['checkedBy'],
            unknownValue: ChangeSource.user,
          ) ??
          ChangeSource.user,
      checkedAt: json['checkedAt'] == null
          ? null
          : DateTime.parse(json['checkedAt'] as String),
      approvalHistory:
          (json['approvalHistory'] as List<dynamic>?)
              ?.map(
                (e) =>
                    ChecklistItemProvenance.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ChecklistItemDataToJson(_ChecklistItemData instance) =>
    <String, dynamic>{
      'title': instance.title,
      'isChecked': instance.isChecked,
      'linkedChecklists': instance.linkedChecklists,
      'isArchived': instance.isArchived,
      'id': instance.id,
      'checkedBy': _$ChangeSourceEnumMap[instance.checkedBy]!,
      'checkedAt': instance.checkedAt?.toIso8601String(),
      'approvalHistory': instance.approvalHistory,
    };

const _$ChangeSourceEnumMap = {
  ChangeSource.user: 'user',
  ChangeSource.agent: 'agent',
};

_ChecklistItemProvenance _$ChecklistItemProvenanceFromJson(
  Map<String, dynamic> json,
) => _ChecklistItemProvenance(
  approvedBy: json['approvedBy'] as String,
  approvalHost: json['approvalHost'] as String,
  approvedAt: DateTime.parse(json['approvedAt'] as String),
  approvalMode: $enumDecode(
    _$ChecklistApprovalModeEnumMap,
    json['approvalMode'],
  ),
  originatingMessageId: json['originatingMessageId'] as String,
  conversationId: json['conversationId'] as String,
  changeSetId: json['changeSetId'] as String,
  decisionId: json['decisionId'] as String,
  agentId: json['agentId'] as String,
  source: json['source'] as String? ?? 'chat_suggestion',
  appliedBy: json['appliedBy'] as String? ?? 'task_agent',
  isChecked: json['isChecked'] as bool?,
);

Map<String, dynamic> _$ChecklistItemProvenanceToJson(
  _ChecklistItemProvenance instance,
) => <String, dynamic>{
  'approvedBy': instance.approvedBy,
  'approvalHost': instance.approvalHost,
  'approvedAt': instance.approvedAt.toIso8601String(),
  'approvalMode': _$ChecklistApprovalModeEnumMap[instance.approvalMode]!,
  'originatingMessageId': instance.originatingMessageId,
  'conversationId': instance.conversationId,
  'changeSetId': instance.changeSetId,
  'decisionId': instance.decisionId,
  'agentId': instance.agentId,
  'source': instance.source,
  'appliedBy': instance.appliedBy,
  'isChecked': instance.isChecked,
};

const _$ChecklistApprovalModeEnumMap = {
  ChecklistApprovalMode.individual: 'individual',
  ChecklistApprovalMode.confirmAll: 'confirm_all',
};
