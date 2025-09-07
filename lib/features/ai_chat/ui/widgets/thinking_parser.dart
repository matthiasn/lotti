// Result of parsing a message that may contain hidden `thinking` content.
import 'dart:collection';

class ParsedThinking {
  const ParsedThinking({required this.visible, this.thinking});

  /// The content to display as the actual assistant message (markdown).
  final String visible;

  /// Optional hidden reasoning/thinking content.
  ///
  /// Note: When multiple thinking sections are present in the source, they
  /// are concatenated (in order) into this single string. This allows the UI
  /// to present one elegant, collapsible disclosure that updates as streaming
  /// continues, regardless of how many distinct thinking blocks appear before
  /// or after tool calls.
  final String? thinking;
}

/// Compiled patterns and configuration for parsing thinking blocks.
class ThinkingPatterns {
  // HTML-like tags (case-insensitive)
  static final RegExp htmlOpen = RegExp('<think>', caseSensitive: false);
  static final RegExp htmlClose = RegExp('</think>', caseSensitive: false);

  // Bracket-style tags (case-insensitive)
  static final RegExp bracketOpen = RegExp(r'\[think\]', caseSensitive: false);
  static final RegExp bracketClose =
      RegExp(r'\[/think\]', caseSensitive: false);

  // Fenced code block language (case-insensitive)
  static final RegExp fenceOpen =
      RegExp(r'```[ \t]*think[ \t]*\n', caseSensitive: false);
  static const String fenceClose = '```';
}

/// Utilities related to thinking content.
class ThinkingUtils {
  static const int maxThinkingLength = 20000; // Prevent runaway UI

  // Lightweight LRU cache for parsed results
  static final LinkedHashMap<String, ParsedThinking> _cache =
      LinkedHashMap<String, ParsedThinking>();
  static const int _cacheLimit = 100;

  static ParsedThinking? _getCache(String key) => _cache[key];
  static void _setCache(String key, ParsedThinking value) {
    if (_cache.length > _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  /// Remove all thinking blocks and return only the visible content.
  static String stripThinking(String input) => parseThinking(input).visible;
}

/// Parses assistant output to extract any hidden `thinking` sections and
/// return visible content separately.
///
/// Behavior:
/// - Supports HTML, bracket, and fenced-code syntaxes, case-insensitive.
/// - Aggregates multiple segments in order, separated by a Markdown HR (---).
/// - Handles open-ended blocks for streaming and nested blocks (HTML/bracket).
/// - Enforces a maximum combined length for thinking to protect the UI.
///
/// Recognized patterns (multiple supported and concatenated):
/// - `<think> ... </think>` (HTML-like)
/// - ```think\n ... \n``` (fenced code with language `think`)
/// - `[think] ... [/think]` (BBCode-like)
///
/// Streaming-friendly: also detects open-ended blocks (no closing yet) and
/// assigns all remaining content to `thinking` until more tokens arrive.
ParsedThinking parseThinking(String content) {
  try {
    if (content.isEmpty) return const ParsedThinking(visible: '');

    // Memoize to avoid repeated heavy regex work on identical content.
    final cached = ThinkingUtils._getCache(content);
    if (cached != null) return cached;

    final visible = StringBuffer();
    final thinking = StringBuffer();

    var index = 0;
    var foundThinking = false;

    int? fenceBodyStartFor(int from) {
      final match =
          ThinkingPatterns.fenceOpen.firstMatch(content.substring(from));
      if (match == null) return null;
      return from + match.end; // body begins after the opening line
    }

    // Extract a possibly nested block using open/close tokens (case-insensitive).
    // Returns the end index after the close and the extracted body.
    ({int end, String body}) extractNested(
      int bodyStart,
      String openToken,
      String closeToken,
    ) {
      final lower = content.toLowerCase();
      final open = openToken.toLowerCase();
      final close = closeToken.toLowerCase();
      var depth = 1;
      var pos = bodyStart;
      while (pos < content.length) {
        final nextOpen = lower.indexOf(open, pos);
        final nextClose = lower.indexOf(close, pos);
        if (nextClose < 0) {
          // Open-ended
          return (end: content.length, body: content.substring(bodyStart));
        }
        if (nextOpen >= 0 && nextOpen < nextClose) {
          depth += 1;
          pos = nextOpen + open.length;
        } else {
          depth -= 1;
          pos = nextClose + close.length;
          if (depth == 0) {
            final body = content.substring(bodyStart, nextClose);
            return (end: pos, body: body);
          }
        }
      }
      // If we exit the loop, treat as open-ended
      return (end: content.length, body: content.substring(bodyStart));
    }

    while (index < content.length) {
      final lower = content.toLowerCase();
      final htmlIdx = lower.indexOf('<think>', index);
      final bracketIdx = lower.indexOf('[think]', index);
      var fenceIdx = -1;
      final iter =
          ThinkingPatterns.fenceOpen.allMatches(content, index).iterator;
      if (iter.moveNext()) {
        fenceIdx = iter.current.start;
      }

      // Choose earliest start token from current index
      var nextIdx = content.length;
      String? type;
      if (htmlIdx >= 0 && htmlIdx < nextIdx) {
        nextIdx = htmlIdx;
        type = 'html';
      }
      if (bracketIdx >= 0 && bracketIdx < nextIdx) {
        nextIdx = bracketIdx;
        type = 'bracket';
      }
      if (fenceIdx >= 0 && fenceIdx < nextIdx) {
        nextIdx = fenceIdx;
        type = 'fence';
      }

      if (type == null) {
        // No more thinking blocks; add remainder to visible and stop.
        visible.write(content.substring(index));
        break;
      }

      // Emit preceding visible content
      if (nextIdx > index) {
        visible.write(content.substring(index, nextIdx));
      }

      // Advance past opening token and capture thinking until its close (or end)
      int bodyStart;
      String closeToken;
      int afterCloseAdvance;

      switch (type) {
        case 'html':
          bodyStart = nextIdx + '<think>'.length;
          closeToken = '</think>';
          afterCloseAdvance = closeToken.length;

        case 'bracket':
          bodyStart = nextIdx + '[think]'.length;
          closeToken = '[/think]';
          afterCloseAdvance = closeToken.length;

        case 'fence':
          bodyStart =
              fenceBodyStartFor(nextIdx) ?? (nextIdx + '```think'.length);
          closeToken = ThinkingPatterns.fenceClose;
          afterCloseAdvance = closeToken.length;

        default:
          // Should not happen; treat as visible
          visible.write(content.substring(nextIdx));
          index = content.length;
          continue;
      }

      String segment;
      int nextIndexAfterClose;

      if (type == 'html') {
        final res = extractNested(bodyStart, '<think>', '</think>');
        segment = res.body;
        nextIndexAfterClose = res.end;
      } else if (type == 'bracket') {
        final res = extractNested(bodyStart, '[think]', '[/think]');
        segment = res.body;
        nextIndexAfterClose = res.end;
      } else {
        // fence: not nested, find next ```
        final closeIdx = content.indexOf(closeToken, bodyStart);
        if (closeIdx >= 0) {
          segment = content.substring(bodyStart, closeIdx);
          nextIndexAfterClose = closeIdx + afterCloseAdvance;
        } else {
          segment = content.substring(bodyStart);
          nextIndexAfterClose = content.length;
        }
      }

      if (foundThinking && thinking.isNotEmpty) thinking.write('\n\n---\n\n');
      // Enforce maximum length to avoid UI stalls.
      final remaining = ThinkingUtils.maxThinkingLength - thinking.length;
      if (remaining > 0) {
        if (segment.length > remaining) {
          thinking
            ..write(segment.substring(0, remaining))
            ..write('\n\n[Thinking content truncated...]');
          foundThinking = true;
          break; // Stop processing further thinking blocks
        } else {
          thinking.write(segment);
        }
      } else {
        thinking.write('\n\n[Thinking content truncated...]');
        break;
      }
      foundThinking = true;
      index = nextIndexAfterClose;
    }

    final visibleStr = visible.toString().trim();
    final thinkingStr = foundThinking ? thinking.toString().trim() : null;
    final result = ParsedThinking(visible: visibleStr, thinking: thinkingStr);
    // Only cache reasonably-sized content
    if (content.length <= 10000) ThinkingUtils._setCache(content, result);
    return result;
  } catch (_) {
    // Defensive fallback — return original content visible if anything fails
    return ParsedThinking(visible: content);
  }
}
//
