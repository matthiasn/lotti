import 'dart:math' show min;

/// Truncate [text] to [maxLength] characters, collapsing newlines into spaces
/// and appending "…" if truncated.
String truncateAgentText(String text, int maxLength) {
  final singleLine = text.replaceAll('\n', ' ').trim();
  if (singleLine.length <= maxLength) return singleLine;
  return '${singleLine.substring(0, min(maxLength, singleLine.length))}…';
}
