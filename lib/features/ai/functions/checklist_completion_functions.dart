import 'package:freezed_annotation/freezed_annotation.dart';

part 'checklist_completion_functions.freezed.dart';

/// Function definition for suggesting checklist item completion
class ChecklistCompletionFunctions {
  static const String suggestChecklistCompletion =
      'suggest_checklist_completion';
  static const String addMultipleChecklistItems =
      'add_multiple_checklist_items';
  static const String updateChecklistItems = 'update_checklist_items';
}

/// Response from the suggest checklist completion function
@freezed
abstract class ChecklistCompletionSuggestion
    with _$ChecklistCompletionSuggestion {
  const factory ChecklistCompletionSuggestion({
    required String checklistItemId,
    required String reason,
    @JsonKey(unknownEnumValue: ChecklistCompletionConfidence.low)
    required ChecklistCompletionConfidence confidence,
  }) = _ChecklistCompletionSuggestion;
}

enum ChecklistCompletionConfidence {
  high,
  medium,
  low,
}
