import 'package:openai_dart/openai_dart.dart';

/// Helper utilities for extracting text content from OpenAI message types
class ContentExtractionHelper {
  /// Flattens a user message's content into a plain string.
  ///
  /// Handles both shapes the sealed openai_dart union can take: a bare string
  /// is returned as-is, while a list of content parts has its text parts
  /// concatenated (empty/whitespace-only parts are dropped, but surviving
  /// parts keep their original, untrimmed text). Non-text parts (images,
  /// audio, refusals) contribute nothing.
  static String extractTextFromUserContent(
    ChatCompletionUserMessageContent content,
  ) => switch (content) {
    ChatCompletionUserMessageContentString(:final value) => value,
    ChatCompletionMessageContentParts(:final value) => [
      for (final part in value)
        if (part case ChatCompletionMessageContentPartText(
          :final text,
        ) when text.trim().isNotEmpty)
          text,
    ].join(),
  };
}
