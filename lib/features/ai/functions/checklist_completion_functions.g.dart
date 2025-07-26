// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_completion_functions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChecklistCompletionSuggestionImpl
    _$$ChecklistCompletionSuggestionImplFromJson(Map<String, dynamic> json) =>
        _$ChecklistCompletionSuggestionImpl(
          checklistItemId: json['checklistItemId'] as String,
          reason: json['reason'] as String,
          confidence: $enumDecode(
              _$ChecklistCompletionConfidenceEnumMap, json['confidence']),
        );

Map<String, dynamic> _$$ChecklistCompletionSuggestionImplToJson(
        _$ChecklistCompletionSuggestionImpl instance) =>
    <String, dynamic>{
      'checklistItemId': instance.checklistItemId,
      'reason': instance.reason,
      'confidence':
          _$ChecklistCompletionConfidenceEnumMap[instance.confidence]!,
    };

const _$ChecklistCompletionConfidenceEnumMap = {
  ChecklistCompletionConfidence.high: 'high',
  ChecklistCompletionConfidence.medium: 'medium',
  ChecklistCompletionConfidence.low: 'low',
};

_$AddChecklistItemResultImpl _$$AddChecklistItemResultImplFromJson(
        Map<String, dynamic> json) =>
    _$AddChecklistItemResultImpl(
      checklistId: json['checklistId'] as String,
      checklistItemId: json['checklistItemId'] as String,
      checklistCreated: json['checklistCreated'] as bool,
    );

Map<String, dynamic> _$$AddChecklistItemResultImplToJson(
        _$AddChecklistItemResultImpl instance) =>
    <String, dynamic>{
      'checklistId': instance.checklistId,
      'checklistItemId': instance.checklistItemId,
      'checklistCreated': instance.checklistCreated,
    };
