import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:openai_dart/openai_dart.dart';

part 'task_functions.freezed.dart';
part 'task_functions.g.dart';

/// Function definitions for task-related AI operations
class TaskFunctions {
  static const String setTaskLanguage = 'set_task_language';
  static const String updateTaskEstimate = 'update_task_estimate';
  static const String updateTaskDueDate = 'update_task_due_date';

  /// Get all available function definitions for task operations
  static List<ChatCompletionTool> getTools() {
    final currentDate = DateTime.now().toIso8601String().split('T')[0];

    return [
      ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: setTaskLanguage,
          description:
              'Set the detected language for the task based on the content analysis',
          parameters: {
            'type': 'object',
            'properties': {
              'languageCode': {
                'type': 'string',
                'description': 'ISO 639-1 language code',
                'enum': SupportedLanguage.values.map((e) => e.code).toList(),
              },
              'confidence': {
                'type': 'string',
                'enum': ['high', 'medium', 'low'],
                'description': 'Confidence level of language detection',
              },
              'reason': {
                'type': 'string',
                'description':
                    'Brief explanation of why this language was detected',
              },
            },
            'required': ['languageCode', 'confidence', 'reason'],
          },
        ),
      ),
      const ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: updateTaskEstimate,
          description:
              'Set the time estimate for the current task based on voice transcript. '
              'Call when the user mentions duration (e.g., "30 minutes", "2 hours", '
              '"half a day", "a week"). Only sets the estimate if not already set.',
          parameters: {
            'type': 'object',
            'properties': {
              'minutes': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 1440,
                'description': 'Time estimate in minutes (max 24 hours). '
                    'Convert: 1 hour = 60, half day = 240, full day = 480. '
                    'Tasks over a day should be broken into subtasks.',
              },
              'reason': {
                'type': 'string',
                'description':
                    'Brief explanation of what was said that indicated this estimate.',
              },
              'confidence': {
                'type': 'string',
                'enum': ['high', 'medium', 'low'],
                'description':
                    'Confidence level. Use "high" for explicit statements, '
                        '"medium" for implied, "low" for uncertain.',
              },
            },
            'required': ['minutes', 'reason', 'confidence'],
          },
        ),
      ),
      ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: updateTaskDueDate,
          description:
              'Set the due date for the current task based on voice transcript. '
              'Current date: $currentDate. Call when the user mentions a deadline '
              '(e.g., "due tomorrow", "by Friday", "needs to be done by January 15th"). '
              'Only sets the date if not already set.',
          parameters: {
            'type': 'object',
            'properties': {
              'dueDate': {
                'type': 'string',
                'format': 'date',
                'description':
                    'Due date in ISO 8601 format (YYYY-MM-DD). Resolve relative '
                        'dates to absolute dates based on current date.',
              },
              'reason': {
                'type': 'string',
                'description':
                    'Brief explanation of what was said that indicated this due date.',
              },
              'confidence': {
                'type': 'string',
                'enum': ['high', 'medium', 'low'],
                'description':
                    'Confidence level. Use "high" for explicit deadlines, '
                        '"medium" for implied, "low" for uncertain.',
              },
            },
            'required': ['dueDate', 'reason', 'confidence'],
          },
        ),
      ),
    ];
  }
}

/// Response from the set task language function
@freezed
abstract class SetTaskLanguageResult with _$SetTaskLanguageResult {
  const factory SetTaskLanguageResult({
    required String languageCode,
    required LanguageDetectionConfidence confidence,
    required String reason,
  }) = _SetTaskLanguageResult;

  factory SetTaskLanguageResult.fromJson(Map<String, dynamic> json) =>
      _$SetTaskLanguageResultFromJson(json);
}

enum LanguageDetectionConfidence {
  high,
  medium,
  low,
}
