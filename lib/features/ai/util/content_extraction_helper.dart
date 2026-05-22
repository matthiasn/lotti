import 'package:lotti/features/ai/model/ai_chat_message.dart';

/// Helper utilities for extracting text content from AI message types.
class ContentExtractionHelper {
  /// Extracts the plain-text concatenation of an [AiUserContent], dropping
  /// non-text parts (images, audio) since callers only need the text.
  ///
  /// Text parts are concatenated without a separator. This matches the
  /// historical openai_dart helper behavior that downstream tests and
  /// callers (Gemini's transcript builder and Ollama's message serializer
  /// — neither interleaves media between text parts) depend on.
  static String extractTextFromUserContent(AiUserContent content) {
    return switch (content) {
      AiUserTextContent(:final text) => text,
      AiUserPartsContent(:final parts) =>
        parts
            .whereType<AiTextPart>()
            .map((p) => p.text)
            .where((t) => t.trim().isNotEmpty)
            .join(),
    };
  }
}
