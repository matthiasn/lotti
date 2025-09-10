// Helper utilities for chat streaming parsing and formatting.

/// Utility helpers for streaming parsing and formatting in ChatSessionController.
class ChatStreamUtils {
  static const int maxStreamingContentSize = 1000000; // 1MB cap
  static const String ellipsis = '…';

  // Regex patterns for open/close tokens (whitespace-tolerant)
  static final RegExp htmlOpen =
      RegExp(r'<think(?:ing)?\s*>', caseSensitive: false);
  static final RegExp htmlClose =
      RegExp(r'</think(?:ing)?\s*>', caseSensitive: false);
  static final RegExp bracketOpen =
      RegExp(r'\[(?:think|thinking)\s*\]', caseSensitive: false);
  static final RegExp bracketClose =
      RegExp(r'\[/(?:think|thinking)\s*\]', caseSensitive: false);
  static final RegExp fenceOpen =
      RegExp(r'```[ \t]*(?:think|thinking)[ \t]*\n', caseSensitive: false);
  static final RegExp fenceClose = RegExp('```', caseSensitive: false);

  /// Returns a regex for the closing token that matches the given opening token.
  static RegExp closeRegexFromOpenToken(String token) {
    if (token.startsWith('<')) return htmlClose;
    if (token.startsWith('[')) return bracketClose;
    return fenceClose;
  }

  /// Wraps a thinking body in a canonical thinking block wrapper.
  static String wrapThinkingBlock(String text) =>
      '<thinking>\n$text\n</thinking>';

  /// Returns whether a following chunk should upgrade a pending soft break to a blank line.
  static bool shouldUpgradeSoftBreak(String nextChunk) {
    return RegExp(r'^\s*(?:[-*•]|\d{1,2}\.|#{1,6}\s)').hasMatch(nextChunk);
  }

  /// Returns true if [s] is only whitespace but contains a line break.
  static bool isWhitespaceWithLineBreak(String s) {
    final hasLineBreak = s.contains('\n') || s.contains('\r');
    final isWhitespaceOnly = s.trim().isEmpty;
    return hasLineBreak && isWhitespaceOnly;
  }

  /// Computes a trailing partial opener to carry to the next chunk, if any.
  /// Returns the partial suffix to carry (possibly empty).
  static String computeOpenTagCarry(String s) {
    // Candidate opening tokens (without the closing char to support partials).
    const candidates = <String>[
      '<thinking',
      '<think',
      '[thinking',
      '[think',
      '```thinking',
      '```think',
    ];
    final lower = s.toLowerCase();
    var carry = '';
    for (final token in candidates) {
      final maxLen = token.length;
      for (var i = maxLen; i > 0; i--) {
        final prefix = token.substring(0, i);
        if (lower.endsWith(prefix)) {
          if (prefix.startsWith('<') ||
              prefix.startsWith('[') ||
              prefix.startsWith('`')) {
            if (i > carry.length) carry = s.substring(s.length - i);
          }
          break;
        }
      }
    }
    // Do not treat a complete opener (with optional whitespace) as carry.
    final trimmed = lower.trimRight();
    final fullOpeners = <RegExp>[
      RegExp(r'<think(?:ing)?\s*>\s*$', caseSensitive: false),
      RegExp(r'\[(?:think|thinking)\s*\]\s*$', caseSensitive: false),
      RegExp(r'```[ \t]*(?:think|thinking)[ \t]*\n\s*$', caseSensitive: false),
    ];
    for (final re in fullOpeners) {
      if (re.hasMatch(trimmed)) return '';
    }
    return carry;
  }

  /// Finds the earliest thinking open token in [chunk] starting at [fromIndex].
  /// Returns a match record with indices and close token, or null if none.
  static ({int idx, int end, String closeToken})? findEarliestOpenMatch(
    String chunk,
    int fromIndex,
  ) {
    final openSpecs = <({RegExp re, String token, String closeToken})>[
      (re: htmlOpen, token: '<thinking>', closeToken: '</thinking>'),
      (re: bracketOpen, token: '[thinking]', closeToken: '[/thinking]'),
      (re: fenceOpen, token: '```thinking\n', closeToken: '```'),
    ];
    ({int idx, int end, String closeToken})? earliest;
    for (final spec in openSpecs) {
      final m = spec.re.firstMatch(chunk.substring(fromIndex));
      if (m == null) continue;
      final start = fromIndex + m.start;
      final end = fromIndex + m.end;
      if (earliest == null || start < earliest.idx) {
        earliest = (idx: start, end: end, closeToken: spec.closeToken);
      }
    }
    return earliest;
  }

  /// Returns [content] truncated to [cap] with a trailing ellipsis when exceeding cap.
  static String truncateWithEllipsis(String content, int cap) {
    if (content.length <= cap) return content;
    return '${content.substring(0, cap)}$ellipsis';
  }

  /// Returns true if [content] looks truncated by [truncateWithEllipsis].
  static bool isTruncated(String content) => content.endsWith(ellipsis);

  /// Prepares a visible chunk, optionally upgrading a pending soft break.
  /// Returns the text to append (or null to defer) and the new pending flag.
  static ({String? text, bool pendingSoftBreak}) prepareVisibleChunk(
    String rawText, {
    required bool pendingSoftBreak,
  }) {
    if (rawText.isEmpty) return (text: '', pendingSoftBreak: pendingSoftBreak);
    if (isWhitespaceWithLineBreak(rawText)) {
      return (text: null, pendingSoftBreak: true);
    }
    var text = rawText;
    var pending = pendingSoftBreak;
    if (pending) {
      final prefix = shouldUpgradeSoftBreak(rawText) ? '\n\n' : '\n';
      text = '$prefix$text';
      pending = false;
    }
    return (text: text, pendingSoftBreak: pending);
  }
}
