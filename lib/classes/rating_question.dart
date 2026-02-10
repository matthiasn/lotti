import 'package:freezed_annotation/freezed_annotation.dart';

part 'rating_question.freezed.dart';
part 'rating_question.g.dart';

/// Defines a single question within a rating catalog.
///
/// The [question] text is localized (shown to the user in their language).
/// The [description] is always English and explains the semantic meaning
/// of the dimension for LLM consumption.
@freezed
abstract class RatingQuestion with _$RatingQuestion {
  const factory RatingQuestion({
    /// Stable identifier for this question (e.g., "productivity").
    required String key,

    /// Localized question text shown to the user.
    required String question,

    /// English semantic description of what this dimension measures and
    /// how to interpret the 0-1 scale. Used by LLMs to determine
    /// "good" vs "bad" outcomes without external schema knowledge.
    required String description,

    /// Input type for the UI and value interpretation.
    /// - 'tapBar': continuous 0.0-1.0 tap bar (tap anywhere to set value)
    /// - 'segmented': categorical buttons with fixed values
    /// - 'boolean': yes/no (0.0 or 1.0)
    @Default('tapBar') String inputType,

    /// Available options for 'segmented' input type.
    /// Each option has a display label and a normalized value.
    List<RatingQuestionOption>? options,
  }) = _RatingQuestion;

  factory RatingQuestion.fromJson(Map<String, dynamic> json) =>
      _$RatingQuestionFromJson(json);
}

/// A single option within a segmented rating question.
@freezed
abstract class RatingQuestionOption with _$RatingQuestionOption {
  const factory RatingQuestionOption({
    /// Display label for this option (localized).
    required String label,

    /// Normalized value (0.0-1.0) assigned when this option is selected.
    required double value,
  }) = _RatingQuestionOption;

  factory RatingQuestionOption.fromJson(Map<String, dynamic> json) =>
      _$RatingQuestionOptionFromJson(json);
}
