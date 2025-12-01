/// Shared string utility functions.
///
/// These utilities are used by multiple features to ensure consistent
/// text processing across the application.
library;

/// Normalizes whitespace in a string by trimming and collapsing
/// internal whitespace sequences to single spaces.
///
/// This is used by:
/// - AI checklist update handler (for title corrections from AI)
/// - Correction capture service (for manual title corrections)
///
/// Examples:
/// - "  hello   world  " -> "hello world"
/// - "test\n\tfoo" -> "test foo"
String normalizeWhitespace(String text) {
  return text.trim().replaceAll(RegExp(r'\s+'), ' ');
}
