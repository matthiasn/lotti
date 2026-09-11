import 'package:lotti/features/ai/model/inference.dart';

/// Helper utilities for extracting text content from inference messages.
class ContentExtractionHelper {
  /// Flattens a user message's content into a plain string.
  ///
  /// Handles both shapes the content union can take: a bare string is returned
  /// as-is, while a list of parts has its text parts concatenated. Empty and
  /// whitespace-only parts are dropped, but surviving parts keep their
  /// original, untrimmed text. Non-text parts contribute nothing.
  static String extractTextFromUserContent(LottiUserContent content) =>
      switch (content) {
        LottiUserText(:final text) => text,
        LottiUserParts(:final parts) =>
          parts
              .whereType<LottiTextPart>()
              .map((part) => part.text)
              .where((text) => text.trim().isNotEmpty)
              .join(),
      };
}
