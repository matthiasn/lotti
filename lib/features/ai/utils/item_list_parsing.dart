// A robust parser for comma-separated item lists that appear in tool calls.
// Supports:
// - JSON-array alternative is handled by callers; this parses only strings
// - Quotes: "..." or '...' to group items with commas (quotes themselves are not retained)
// - Backslash escapes: \\ to escape next char, including comma
// - Parentheses/brackets/braces: commas inside (), [], {} do not split
// - Trims whitespace; discards empty results
// Notes:
// - Unbalanced quotes/grouping: best-effort parsing; commas remain unsplit while a group is open
// - Trailing backslash: treated as an incomplete escape and ignored (i.e., dropped)
List<String> parseItemListString(String input) {
  final items = <String>[];
  final buf = StringBuffer();
  var escape = false;
  var inQuotes = false;
  String? quoteChar;
  var paren = 0;
  var bracket = 0;
  var brace = 0;

  void push() {
    final s = buf.toString().trim();
    if (s.isNotEmpty) items.add(s);
    buf.clear();
  }

  for (var i = 0; i < input.length; i++) {
    final ch = input[i];

    if (escape) {
      buf.write(ch);
      escape = false;
      continue;
    }

    if (ch == r'\') {
      escape = true;
      continue;
    }

    if (inQuotes) {
      if (ch == quoteChar) {
        inQuotes = false;
        quoteChar = null;
      } else {
        buf.write(ch);
      }
      continue;
    }

    // Enter quotes when encountering ' or "
    final cu = ch.codeUnitAt(0);
    if (cu == 34 || cu == 39) {
      inQuotes = true;
      quoteChar = ch;
      continue;
    }

    // Track nesting so commas inside groupings don't split
    if (ch == '(') {
      paren++;
      buf.write(ch);
      continue;
    }
    if (ch == ')') {
      if (paren > 0) paren--;
      buf.write(ch);
      continue;
    }
    if (ch == '[') {
      bracket++;
      buf.write(ch);
      continue;
    }
    if (ch == ']') {
      if (bracket > 0) bracket--;
      buf.write(ch);
      continue;
    }
    if (ch == '{') {
      brace++;
      buf.write(ch);
      continue;
    }
    if (ch == '}') {
      if (brace > 0) brace--;
      buf.write(ch);
      continue;
    }

    if (ch == ',' && paren == 0 && bracket == 0 && brace == 0) {
      push();
      continue;
    }

    buf.write(ch);
  }

  // Flush remainder
  push();

  return items;
}
