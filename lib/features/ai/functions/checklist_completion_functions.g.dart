// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_completion_functions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChecklistCompletionSuggestion _$ChecklistCompletionSuggestionFromJson(
        Map<String, dynamic> json) =>
    _ChecklistCompletionSuggestion(
      checklistItemId: json['checklistItemId'] as String,
      reason: json['reason'] as String,
      confidence: $enumDecode(
          _$ChecklistCompletionConfidenceEnumMap, json['confidence']),
    );

Map<String, dynamic> _$ChecklistCompletionSuggestionToJson(
        _ChecklistCompletionSuggestion instance) =>
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

_AddChecklistItemResult _$AddChecklistItemResultFromJson(
        Map<String, dynamic> json) =>
    _AddChecklistItemResult(
      checklistId: json['checklistId'] as String,
      checklistItemId: json['checklistItemId'] as String,
      checklistCreated: json['checklistCreated'] as bool,
    );

Map<String, dynamic> _$AddChecklistItemResultToJson(
        _AddChecklistItemResult instance) =>
    <String, dynamic>{
      'checklistId': instance.checklistId,
      'checklistItemId': instance.checklistItemId,
      'checklistCreated': instance.checklistCreated,
    };
