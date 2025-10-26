import 'package:openai_dart/openai_dart.dart';

/// Function definitions for label-related AI operations
class LabelFunctions {
  static const String assignTaskLabels = 'assign_task_labels';

  /// Provide the tool schema for assigning labels to a task by ID.
  ///
  /// Example call arguments (from the model):
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
              'Assign one or more existing labels to the current task using label IDs. This is add-only, will not remove existing labels.',
          parameters: {
            'type': 'object',
            'properties': {
              'labelIds': {
                'type': 'array',
                'description': 'Array of label IDs to add to the task',
                'items': {'type': 'string'},
              },
            },
            'required': ['labelIds'],
          },
        ),
      ),
    ];
  }
}
