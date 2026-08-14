import 'package:lotti/features/agents/model/agent_domain_entity.dart';

/// The report's own summary, when it has one.
///
/// A report whose author split the tiers carries an explicit
/// [AgentReportEntity.tldr], and its [AgentReportEntity.content] is the
/// expanded body ALONE. Deriving a preview from that content would show the
/// first body section instead of the summary, so the explicit field wins
/// wherever it is set. Older reports have none and keep the
/// parsed-from-markdown behaviour.
String? explicitReportTldr(AgentReportEntity report) {
  final tldr = report.tldr?.trim();
  return tldr == null || tldr.isEmpty ? null : tldr;
}

/// True when [content] already opens with its own TLDR section.
///
/// Task and project agents author `content` as the COMPLETE report, starting
/// with a `## 📋 TLDR` heading, and set [AgentReportEntity.tldr] to the same
/// summary alongside it. Goal agents split the two: the summary lives only in
/// the field and `content` is the body. The heading is what tells the two
/// formats apart.
bool contentCarriesItsOwnTldr(String content) =>
    _tldrHeadingRegex.hasMatch(stripLeadingH1(content));

final _tldrHeadingRegex = RegExp(r'## 📋 TLDR\n', multiLine: true);

/// The full rendering of a report: its summary, then the body it introduces.
///
/// A view that renders [AgentReportEntity.content] alone silently drops the
/// summary for a report that split the tiers. Prepending it unconditionally
/// makes the opposite mistake — a task report whose content already opens with
/// its own TLDR section would show the summary twice — so the summary is added
/// only when the body does not already carry one.
String reportBodyWithTldr(AgentReportEntity report) {
  final tldr = explicitReportTldr(report);
  final content = report.content.trim();
  if (tldr == null) return report.content;
  if (content.isEmpty || content == tldr) return tldr;
  if (contentCarriesItsOwnTldr(content)) return report.content;
  return '$tldr\n\n$content';
}

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
