/// Parses agent report markdown into structured TLDR and additional sections.
///
/// Used by both the expandable report section on task detail pages and the
/// collapsed report snapshot in the activity log.
({String tldr, String? additional}) parseReportContent(String content) {
  if (content.isEmpty) return (tldr: '', additional: null);

  // Try to find the TLDR section heading: ## 📋 TLDR
  final tldrHeadingRegex = RegExp(
    r'(## 📋 TLDR\n)',
    multiLine: true,
  );
  final headingMatch = tldrHeadingRegex.firstMatch(content);

  if (headingMatch != null) {
    // Find the next H2 heading after TLDR to split
    final afterTldr = content.substring(headingMatch.end);
    final nextHeadingRegex = RegExp(r'\n## ', multiLine: true);
    final nextHeadingMatch = nextHeadingRegex.firstMatch(afterTldr);

    if (nextHeadingMatch != null) {
      final tldrEnd = headingMatch.end + nextHeadingMatch.start;
      final tldr = content.substring(0, tldrEnd).trim();
      final additional = content.substring(tldrEnd).trim();
      return (
        tldr: tldr,
        additional: additional.isEmpty ? null : additional,
      );
    }
    // No additional sections after TLDR
    return (tldr: content, additional: null);
  }

  // Fallback: try **TLDR:** bold prefix pattern
  final tldrBoldRegex = RegExp(
    r'^\*\*TLDR:\*\*[^\n]*(?:\n(?!\n)[^\n]*)*',
    multiLine: true,
  );
  final boldMatch = tldrBoldRegex.firstMatch(content);

  if (boldMatch != null) {
    // Include everything before the TLDR match (title, status bar)
    final tldr = content.substring(0, boldMatch.end).trim();
    final additional = content.substring(boldMatch.end).trim();
    return (
      tldr: tldr,
      additional: additional.isEmpty ? null : additional,
    );
  }

  // Final fallback: first paragraph as TLDR
  final paragraphs = content.split(RegExp(r'\n\n+'));
  final tldr = paragraphs.first.trim();
  final additional =
      paragraphs.length > 1 ? paragraphs.skip(1).join('\n\n').trim() : null;
  return (tldr: tldr, additional: additional);
}
