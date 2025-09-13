import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:openai_dart/openai_dart.dart';

part 'task_functions.freezed.dart';
part 'task_functions.g.dart';

/// Function definitions for task-related AI operations
class TaskFunctions {
  static const String setTaskLanguage = 'set_task_language';

  /// Get all available function definitions for task operations
  static List<ChatCompletionTool> getTools() {
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
