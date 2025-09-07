/// Result of parsing a message that may contain hidden `thinking` content.
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

/// Parses assistant output to extract any hidden `thinking` sections and
/// return visible content separately.
///
/// Recognized patterns (multiple supported and concatenated):
/// - `<think> ... </think>` (HTML-like)
/// - ```think\n ... \n``` (fenced code with language `think`)
/// - `[think] ... [/think]` (BBCode-like)
///
/// Streaming-friendly: also detects open-ended blocks (no closing yet) and
/// assigns all remaining content to `thinking` until more tokens arrive.
ParsedThinking parseThinking(String content) {
  if (content.isEmpty) return const ParsedThinking(visible: '');

  final fenceOpen = RegExp(r'```[ \t]*think[ \t]*\n');

  final visible = StringBuffer();
  final thinking = StringBuffer();

  var index = 0;
  var foundThinking = false;

  int? fenceBodyStartFor(int from) {
    for (final m in fenceOpen.allMatches(content, from)) {
      return m.end; // body begins after the opening line
    }
    return null;
  }

  while (index < content.length) {
    final htmlIdx = content.indexOf('<think>', index);
    final bracketIdx = content.indexOf('[think]', index);
    var fenceIdx = -1;
    final iter = fenceOpen.allMatches(content, index).iterator;
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
        bodyStart = fenceBodyStartFor(nextIdx) ??
            // If we failed to locate the newline, treat everything after
            // the marker as body to stay resilient to streaming oddities.
            (nextIdx + '```think'.length);
        closeToken = '```';
        afterCloseAdvance = closeToken.length;

      default:
        // Should not happen; treat as visible
        visible.write(content.substring(nextIdx));
        index = content.length;
        continue;
    }

    final closeIdx = content.indexOf(closeToken, bodyStart);
    if (closeIdx >= 0) {
      // Closed block
      final segment = content.substring(bodyStart, closeIdx);
      if (foundThinking && thinking.isNotEmpty) thinking.write('\n\n---\n\n');
      thinking.write(segment);
      foundThinking = true;
      index = closeIdx + afterCloseAdvance;
    } else {
      // Open-ended: everything after opening belongs to thinking
      final segment = content.substring(bodyStart);
      if (foundThinking && thinking.isNotEmpty) thinking.write('\n\n---\n\n');
      thinking.write(segment);
      foundThinking = true;
      index = content.length; // end
    }
  }

  final visibleStr = visible.toString().trim();
  final thinkingStr = foundThinking ? thinking.toString().trim() : null;
  return ParsedThinking(visible: visibleStr, thinking: thinkingStr);
}
//
