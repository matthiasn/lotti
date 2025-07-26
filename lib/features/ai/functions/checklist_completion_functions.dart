import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:openai_dart/openai_dart.dart';

part 'checklist_completion_functions.freezed.dart';
part 'checklist_completion_functions.g.dart';

/// Function definition for suggesting checklist item completion
class ChecklistCompletionFunctions {
  static const String suggestChecklistCompletion =
      'suggest_checklist_completion';
  static const String addChecklistItem = 'add_checklist_item';

  /// Get all available function definitions for checklist operations
  static List<ChatCompletionTool> getTools() {
    return [
      const ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: suggestChecklistCompletion,
          description:
              'Suggest that a checklist item should be marked as completed based on evidence from audio transcriptions, task summaries, or other context',
          parameters: {
            'type': 'object',
            'properties': {
              'checklistItemId': {
                'type': 'string',
                'description':
                    'The ID of the checklist item that appears to be completed',
              },
              'reason': {
                'type': 'string',
                'description':
                    'A brief explanation of why this item appears to be completed based on the evidence',
              },
              'confidence': {
                'type': 'string',
                'enum': ['high', 'medium', 'low'],
                'description': 'Confidence level in the completion suggestion',
              },
            },
            'required': ['checklistItemId', 'reason', 'confidence'],
          },
        ),
      ),
      const ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: addChecklistItem,
          description:
              'Add a new checklist item to the task. If no checklist exists, create a "to-do" checklist first.',
          parameters: {
            'type': 'object',
            'properties': {
              'actionItemDescription': {
                'type': 'string',
                'description': 'The description of the checklist item to add',
              },
            },
            'required': ['actionItemDescription'],
          },
        ),
      ),
    ];
  }
}

/// Response from the suggest checklist completion function
@freezed
class ChecklistCompletionSuggestion with _$ChecklistCompletionSuggestion {
  const factory ChecklistCompletionSuggestion({
    required String checklistItemId,
    required String reason,
    required ChecklistCompletionConfidence confidence,
  }) = _ChecklistCompletionSuggestion;

  factory ChecklistCompletionSuggestion.fromJson(Map<String, dynamic> json) =>
      _$ChecklistCompletionSuggestionFromJson(json);
}

enum ChecklistCompletionConfidence {
  high,
  medium,
  low,
}

/// Response from the add checklist item function
@freezed
class AddChecklistItemResult with _$AddChecklistItemResult {
  const factory AddChecklistItemResult({
    required String checklistId,
    required String checklistItemId,
    required bool checklistCreated,
  }) = _AddChecklistItemResult;

  factory AddChecklistItemResult.fromJson(Map<String, dynamic> json) =>
      _$AddChecklistItemResultFromJson(json);
}
