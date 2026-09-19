// Splits assistant output into ordered visible and reasoning segments for the
// evolution chat UI. Open-ended markers are supported so streamed reasoning
// remains classified as thinking until its closing marker arrives.

/// A single content segment extracted from assistant output,
/// preserving order and type.
class ThinkingSegment {
  const ThinkingSegment({required this.isThinking, required this.text});

  final bool isThinking;
  final String text;
}

class _ThinkingPatterns {
  // Fenced code block language (case-insensitive) — support ```think and ```thinking
  static final RegExp fenceOpen = RegExp(
    r'```[ \t]*(?:think|thinking)[ \t]*\n',
    caseSensitive: false,
  );
  static const String fenceClose = '```';
}

/// The marker families a thinking block can open with.
enum _BlockType { html, bracket, fence }

// Extract a possibly nested block using open/close tokens (case-insensitive).
// Returns the end index after the close and the extracted body.
({int end, String body}) _extractNested(
  String content,
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

// Determine the next block type and its index from a given position.
// Returns null if no further blocks are found.
({_BlockType type, int nextIdx})? _findNextBlockType(
  String content,
  int index,
) {
  final lower = content.toLowerCase();

  // Earliest of <think> or <thinking>
  final htmlIdxThink = lower.indexOf('<think>', index);
  final htmlIdxThinking = lower.indexOf('<thinking>', index);
  int htmlIdx;
  if (htmlIdxThink == -1) {
    htmlIdx = htmlIdxThinking;
  } else if (htmlIdxThinking == -1) {
    htmlIdx = htmlIdxThink;
  } else {
    htmlIdx = htmlIdxThink < htmlIdxThinking ? htmlIdxThink : htmlIdxThinking;
  }

  // Earliest of [think] or [thinking]
  final bracketIdxThink = lower.indexOf('[think]', index);
  final bracketIdxThinking = lower.indexOf('[thinking]', index);
  int bracketIdx;
  if (bracketIdxThink == -1) {
    bracketIdx = bracketIdxThinking;
  } else if (bracketIdxThinking == -1) {
    bracketIdx = bracketIdxThink;
  } else {
    bracketIdx = bracketIdxThink < bracketIdxThinking
        ? bracketIdxThink
        : bracketIdxThinking;
  }

  // Fenced: find next match start
  var fenceIdx = -1;
  final iter = _ThinkingPatterns.fenceOpen.allMatches(content, index).iterator;
  if (iter.moveNext()) {
    fenceIdx = iter.current.start;
  }

  var nextIdx = content.length;
  _BlockType? type;
  if (htmlIdx >= 0 && htmlIdx < nextIdx) {
    nextIdx = htmlIdx;
    type = _BlockType.html;
  }
  if (bracketIdx >= 0 && bracketIdx < nextIdx) {
    nextIdx = bracketIdx;
    type = _BlockType.bracket;
  }
  if (fenceIdx >= 0 && fenceIdx < nextIdx) {
    nextIdx = fenceIdx;
    type = _BlockType.fence;
  }

  if (type == null) return null;
  return (type: type, nextIdx: nextIdx);
}

// Given a block type and its start index, resolve tokens and body start.
({int bodyStart, String openToken, String closeToken, int afterCloseAdvance})
_resolveTokens(String content, _BlockType type, int nextIdx) {
  final lowerAll = content.toLowerCase();
  switch (type) {
    case _BlockType.html:
      if (lowerAll.startsWith('<thinking>', nextIdx)) {
        const openToken = '<thinking>';
        const closeToken = '</thinking>';
        return (
          bodyStart: nextIdx + openToken.length,
          openToken: openToken,
          closeToken: closeToken,
          afterCloseAdvance: closeToken.length,
        );
      } else {
        const openToken = '<think>';
        const closeToken = '</think>';
        return (
          bodyStart: nextIdx + openToken.length,
          openToken: openToken,
          closeToken: closeToken,
          afterCloseAdvance: closeToken.length,
        );
      }
    case _BlockType.bracket:
      if (lowerAll.startsWith('[thinking]', nextIdx)) {
        const openToken = '[thinking]';
        const closeToken = '[/thinking]';
        return (
          bodyStart: nextIdx + openToken.length,
          openToken: openToken,
          closeToken: closeToken,
          afterCloseAdvance: closeToken.length,
        );
      } else {
        const openToken = '[think]';
        const closeToken = '[/think]';
        return (
          bodyStart: nextIdx + openToken.length,
          openToken: openToken,
          closeToken: closeToken,
          afterCloseAdvance: closeToken.length,
        );
      }
    case _BlockType.fence:
      final openToken = lowerAll.startsWith('```thinking', nextIdx)
          ? '```thinking'
          : '```think';
      // `nextIdx` is where `_findNextBlockType` matched the fence opener, so
      // it matches again right there; the body starts after its newline.
      final opener = _ThinkingPatterns.fenceOpen.matchAsPrefix(
        content,
        nextIdx,
      )!;
      const closeToken = _ThinkingPatterns.fenceClose;
      return (
        bodyStart: opener.end,
        openToken: openToken,
        closeToken: closeToken,
        afterCloseAdvance: closeToken.length,
      );
  }
}

/// Splits content into ordered segments of visible vs. thinking blocks.
/// Each recognized section remains its own segment.
List<ThinkingSegment> splitThinkingSegments(String content) {
  final segments = <ThinkingSegment>[];
  try {
    if (content.isEmpty) return segments;

    var index = 0;

    while (index < content.length) {
      final found = _findNextBlockType(content, index);
      if (found == null) {
        final tail = content.substring(index);
        if (tail.isNotEmpty) {
          segments.add(ThinkingSegment(isThinking: false, text: tail));
        }
        break;
      }

      // Visible before block
      if (found.nextIdx > index) {
        final vis = content.substring(index, found.nextIdx);
        if (vis.isNotEmpty) {
          segments.add(ThinkingSegment(isThinking: false, text: vis));
        }
      }

      final tokens = _resolveTokens(content, found.type, found.nextIdx);

      String segment;
      int nextIndexAfterClose;
      if (found.type == _BlockType.fence) {
        final closeIdx = content.indexOf(tokens.closeToken, tokens.bodyStart);
        if (closeIdx >= 0) {
          segment = content.substring(tokens.bodyStart, closeIdx);
          nextIndexAfterClose = closeIdx + tokens.afterCloseAdvance;
        } else {
          segment = content.substring(tokens.bodyStart);
          nextIndexAfterClose = content.length;
        }
      } else {
        final res = _extractNested(
          content,
          tokens.bodyStart,
          tokens.openToken,
          tokens.closeToken,
        );
        segment = res.body;
        nextIndexAfterClose = res.end;
      }

      segments.add(ThinkingSegment(isThinking: true, text: segment));
      index = nextIndexAfterClose;
    }

    return segments;
  } catch (_) {
    return [ThinkingSegment(isThinking: false, text: content)];
  }
}

//
