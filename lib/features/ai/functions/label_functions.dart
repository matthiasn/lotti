import 'package:openai_dart/openai_dart.dart';

/// Function definitions for label-related AI operations
class LabelFunctions {
  static const String assignTaskLabels = 'assign_task_labels';

  /// Provide the tool schema for assigning labels to a task by ID.
  ///
  /// Preferred arguments (Phase 2):
  /// {"labels": [{"id": "bug", "confidence": "very_high"}]}
  ///
  /// Backward-compatible (deprecated):
  /// {"labelIds": ["bug", "backend", "ui"]}
  ///
  /// Expected structured response (string) from the system:
  /// {
  ///   "function": "assign_task_labels",
  ///   "request": {"labelIds": ["bug", "backend", "ui"]},
  ///   "result": {"assigned": ["bug", "backend"], "invalid": ["ui"], "skipped": []},
  ///   "message": "Assigned 2 label(s); 1 invalid; 0 skipped"
  /// }
  static List<ChatCompletionTool> getTools() {
    return [
      const ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: assignTaskLabels,
          description:
              'Assign one or more existing labels to the current task. Add-only; will not remove existing labels. Use `labels` array (preferred) with per-label confidence, or `labelIds` array (deprecated). At least one must be provided.',
          parameters: {
            'type': 'object',
            'properties': {
              // New Phase 2 schema: prefer structured labels with confidence.
              'labels': {
                'type': 'array',
                'description':
                    'Preferred. Array of objects with {id, confidence}. Omit low-confidence labels. Provide highest-confidence first.',
                'items': {
                  'type': 'object',
                  'properties': {
                    'id': {
                      'type': 'string',
                      'description': 'Label ID to add to the task',
                    },
                    'confidence': {
                      'type': 'string',
                      'description':
                          'Confidence for selecting this label (low, medium, high, very_high). Low should be omitted.',
                    },
                  },
                  'required': ['id'],
                  'additionalProperties': false,
                },
              },
              'labelIds': {
                'type': 'array',
                'description':
                    '[Deprecated] Array of label IDs to add to the task. Use `labels` instead.',
                'items': {'type': 'string'},
              },
            },
            // Note: oneOf removed for OpenAI reasoning model compatibility.
            // Handler accepts either `labels` or `labelIds`.
            'additionalProperties': false,
          },
        ),
      ),
    ];
  }
}
