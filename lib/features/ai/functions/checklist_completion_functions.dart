import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:openai_dart/openai_dart.dart';

part 'checklist_completion_functions.freezed.dart';
part 'checklist_completion_functions.g.dart';

/// Function definition for suggesting checklist item completion
class ChecklistCompletionFunctions {
  static const String suggestChecklistCompletion =
      'suggest_checklist_completion';

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
