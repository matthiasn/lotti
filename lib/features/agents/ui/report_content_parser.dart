/// Parses agent report markdown into structured TLDR and additional sections.
///
/// Used by both the expandable report section on task detail pages and the
/// collapsed report snapshot in the activity log.
({String tldr, String? additional}) parseReportContent(String content) {
  if (content.isEmpty) return (tldr: '', additional: null);

  final normalizedContent = stripLeadingH1(content);

  // Try to find the TLDR section heading: ## 📋 TLDR
  final tldrHeadingRegex = RegExp(
    r'(## 📋 TLDR\n)',
    multiLine: true,
  );
  final headingMatch = tldrHeadingRegex.firstMatch(normalizedContent);

  if (headingMatch != null) {
    // Find the next H2 heading after TLDR to split
    final afterTldr = normalizedContent.substring(headingMatch.end);
    final nextHeadingRegex = RegExp(r'\n## ', multiLine: true);
    final nextHeadingMatch = nextHeadingRegex.firstMatch(afterTldr);

    if (nextHeadingMatch != null) {
      final tldrEnd = headingMatch.end + nextHeadingMatch.start;
      final tldr = normalizedContent.substring(0, tldrEnd).trim();
      final additional = normalizedContent.substring(tldrEnd).trim();
      return (
        tldr: tldr,
        additional: additional.isEmpty ? null : additional,
      );
    }
    // No additional sections after TLDR
    return (tldr: normalizedContent, additional: null);
  }

  // Fallback: try **TLDR:** bold prefix pattern
  final tldrBoldRegex = RegExp(
    r'^\*\*TLDR:\*\*[^\n]*(?:\n(?!\n)[^\n]*)*',
    multiLine: true,
  );
  final boldMatch = tldrBoldRegex.firstMatch(normalizedContent);

  if (boldMatch != null) {
    // Include everything before the TLDR match (title, status bar)
    final tldr = normalizedContent.substring(0, boldMatch.end).trim();
    final additional = normalizedContent.substring(boldMatch.end).trim();
    return (
      tldr: tldr,
      additional: additional.isEmpty ? null : additional,
    );
  }

  // Final fallback: first paragraph as TLDR
  final paragraphs = normalizedContent.split(RegExp(r'\n\n+'));
  final tldr = paragraphs.first.trim();
  final additional = paragraphs.length > 1
      ? paragraphs.skip(1).join('\n\n').trim()
      : null;
  return (tldr: tldr, additional: additional);
}

/// Removes a leading `# …` H1 heading line from Markdown content.
///
/// Useful when the UI already renders the project/task title, so the H1 inside
/// the report body would be redundant.
String stripLeadingH1(String content) {
  final leadingHeadingRegex = RegExp(r'^\s*# [^\n]+\n+');
  final match = leadingHeadingRegex.firstMatch(content);
  if (match == null) {
    return content;
  }

  return content.substring(match.end).trimLeft();
}
