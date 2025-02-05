// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'summary_checklist_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SummaryChecklistStateImpl _$$SummaryChecklistStateImplFromJson(
        Map<String, dynamic> json) =>
    _$SummaryChecklistStateImpl(
      summary: json['summary'] as String?,
      checklistItems: (json['checklistItems'] as List<dynamic>?)
          ?.map((e) => ChecklistItemData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$SummaryChecklistStateImplToJson(
        _$SummaryChecklistStateImpl instance) =>
    <String, dynamic>{
      'summary': instance.summary,
      'checklistItems': instance.checklistItems,
    };
