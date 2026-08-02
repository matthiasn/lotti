import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_functions.freezed.dart';
part 'task_functions.g.dart';

/// Function definitions for task-related AI operations
class TaskFunctions {
  static const String setTaskLanguage = 'set_task_language';
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

/// Utility class for parsing AI function call arguments.
///
/// AI models sometimes return non-string values for fields that should be
/// strings (e.g., `{"confidence": true}` instead of `{"confidence": "high"}`).
/// This class provides safe parsing methods that normalize these values.
class TaskFunctionArgs {
  const TaskFunctionArgs._();

  /// Normalizes a value to String?, handling non-string types from AI.
  ///
  /// - If the value is already a String, returns it as-is
  /// - If the value is null, returns null
  /// - Otherwise, converts to string via toString()
  ///
  /// This is useful for optional string fields like `reason` and `confidence`
  /// that the AI might accidentally send as other types.
  static String? normalizeToString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Extracts and normalizes the common 'reason' and 'confidence' fields
  /// from AI function call arguments.
  ///
  /// Returns a record with the normalized values, handling cases where
  /// the AI sends non-string types (e.g., `{"confidence": true}`).
  ///
  /// Example:
  /// ```dart
  /// final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
  /// final (:reason, :confidence) = TaskFunctionArgs.extractReasonAndConfidence(args);
  /// ```
  static ({String? reason, String? confidence}) extractReasonAndConfidence(
    Map<String, dynamic> args,
  ) {
    return (
      reason: normalizeToString(args['reason']),
      confidence: normalizeToString(args['confidence']),
    );
  }
}
