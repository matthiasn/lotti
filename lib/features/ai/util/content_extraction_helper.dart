import 'package:openai_dart/openai_dart.dart';

/// Helper utilities for extracting text content from OpenAI message types
class ContentExtractionHelper {
  /// Flattens a user message's content into a plain string.
  ///
  /// Handles both shapes the openai_dart union can take: a bare string is
  /// returned as-is, while a list of content parts has its `text` parts
  /// concatenated (empty/whitespace-only parts are dropped, but surviving
  /// parts keep their original, untrimmed text). Falls back to `toString()`
  /// for any other value.
  static String extractTextFromUserContent(
    ChatCompletionUserMessageContent content,
  ) {
    final value = content.value;

    if (value is String) {
      return value;
    } else if (value is List) {
      // Handle list of content parts
      final textParts = <String>[];
      for (final part in value) {
        if (part is ChatCompletionMessageContentPart) {
          // Use toJson() to extract content safely
          final partMap = part.toJson();
          if (partMap['type'] == 'text') {
            final text = partMap['text'];
            if (text is String) {
              // Only add non-empty text parts, but preserve the original text
              final trimmed = text.trim();
              if (trimmed.isNotEmpty) {
                textParts.add(text);
              }
            }
          }
        }
      }
      return textParts.join();
    }

    // Fallback
    return content.toString();
  }
}
