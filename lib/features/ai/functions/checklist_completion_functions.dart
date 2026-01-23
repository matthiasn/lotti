import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:openai_dart/openai_dart.dart';

part 'checklist_completion_functions.freezed.dart';
part 'checklist_completion_functions.g.dart';

/// Function definition for suggesting checklist item completion
class ChecklistCompletionFunctions {
  static const String suggestChecklistCompletion =
      'suggest_checklist_completion';
  static const String addMultipleChecklistItems =
      'add_multiple_checklist_items';
  static const String updateChecklistItems = 'update_checklist_items';

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
          name: addMultipleChecklistItems,
          description:
              'Add one or more checklist items to the task in a single call. Always pass a JSON array of objects. If no checklist exists, create a "TODOs" checklist first.',
          parameters: {
            'type': 'object',
            'properties': {
              'items': {
                'type': 'array',
                'minItems': 1,
                'items': {
                  'type': 'object',
                  'properties': {
                    'title': {
                      'type': 'string',
                      'minLength': 1,
                      'maxLength': 400,
                      'description':
                          'Checklist item title (trimmed, non-empty, max 400 chars)',
                    },
                    'isChecked': {
                      'type': 'boolean',
                      'description':
                          'Whether the item is already checked (default: false)'
                    },
                  },
                  'required': ['title'],
                },
                'description':
                    'Array of checklist item objects. Example: {"items": [{"title": "Buy milk"}, {"title": "Write tests", "isChecked": true}] }',
              },
            },
            'required': ['items'],
          },
        ),
      ),
      const ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: updateChecklistItems,
          description:
              'Update one or more existing checklist items. Use to mark items as '
              'done/undone or to correct titles (e.g., fix transcription errors '
              'like "mac OS" → "macOS"). Each update requires the item ID and at '
              'least one field to change.',
          parameters: {
            'type': 'object',
            'properties': {
              'items': {
                'type': 'array',
                'minItems': 1,
                'maxItems': 20,
                'items': {
                  'type': 'object',
                  'properties': {
                    'id': {
                      'type': 'string',
                      'description': 'The ID of the checklist item to update',
                    },
                    'isChecked': {
                      'type': 'boolean',
                      'description':
                          'New checked status. Set true when user indicates '
                              'completion, false to uncheck if user explicitly says '
                              'to uncheck.',
                    },
                    'title': {
                      'type': 'string',
                      'minLength': 1,
                      'maxLength': 400,
                      'description':
                          'Updated title text. Use to fix transcription errors '
                              'or clarify wording.',
                    },
                  },
                  'required': ['id'],
                },
                'description':
                    'Array of updates. Each must have id and at least one of '
                        'isChecked or title.',
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
