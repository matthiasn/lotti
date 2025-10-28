import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:openai_dart/openai_dart.dart';

part 'checklist_completion_functions.freezed.dart';
part 'checklist_completion_functions.g.dart';

/// Function definition for suggesting checklist item completion
class ChecklistCompletionFunctions {
  static const String suggestChecklistCompletion =
      'suggest_checklist_completion';
  static const String addChecklistItem = 'add_checklist_item';
  static const String addMultipleChecklistItems =
      'add_multiple_checklist_items';

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
      const ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: addMultipleChecklistItems,
          description:
              'Add multiple checklist items to the task at once. Prefer a JSON array of strings for items; alternatively, a comma-separated string is accepted. If no checklist exists, create a "TODOs" checklist first.',
          parameters: {
            'type': 'object',
            'properties': {
              'items': {
                'oneOf': [
                  {
                    'type': 'array',
                    'items': {
                      'type': 'string',
                      'minLength': 1,
                    },
                    'description':
                        'Array of checklist item descriptions (preferred). Example: ["cheese", "tomatoes, sliced", "pepperoni"]',
                  },
                  {
                    'type': 'string',
                    'description':
                        r'Comma-separated list (fallback). Escape commas inside an item with \\ or wrap items in quotes. Commas inside parentheses/brackets/braces are treated as part of the item.',
                  },
                ],
                'description': 'List of checklist items to add',
              },
            },
            'required': ['items'],
          },
        ),
      ),
    ];
  }
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
abstract class AddChecklistItemResult with _$AddChecklistItemResult {
  const factory AddChecklistItemResult({
    required String checklistId,
    required String checklistItemId,
    required bool checklistCreated,
  }) = _AddChecklistItemResult;

  factory AddChecklistItemResult.fromJson(Map<String, dynamic> json) =>
      _$AddChecklistItemResultFromJson(json);
}
