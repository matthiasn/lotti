import 'dart:math' show min;

/// Truncate [text] to [maxLength] characters, collapsing newlines into spaces
/// and appending "…" if truncated.
String truncateAgentText(String text, int maxLength) {
  final singleLine = text.replaceAll('\n', ' ').trim();
  if (maxLength <= 0) return '';
  if (singleLine.length <= maxLength) return singleLine;
  if (maxLength == 1) return '…';
  return '${singleLine.substring(0, min(maxLength - 1, singleLine.length))}…';
}
