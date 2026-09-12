import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/system_health/domain/log_digest.dart';
import 'package:lotti/features/system_health/domain/system_health_range.dart';
import 'package:lotti/services/logging_domains.dart';

/// What one analysis run covers.
class SystemHealthRequest {
  const SystemHealthRequest({
    required this.range,
    required this.domains,
    required this.includeSlowQueries,
    this.model,
  });

  final SystemHealthRange range;

  /// Domains whose daily files are read. Mirrors the logging-domain toggles.
  final Set<LogDomain> domains;

  /// Whether the slow-query and super-slow-query files are read too.
  final bool includeSlowQueries;

  /// The model that writes the findings, or `null` for a digest-only report.
  final AiConfigModel? model;
}

/// How the findings section of a report came to be.
enum SystemHealthFindingsSource {
  /// A model wrote the findings from the digest.
  model,

  /// No model was chosen; the report is the digest alone.
  noModel,

  /// A model was chosen but the call failed; the report is the digest alone.
  inferenceFailed,

  /// Nothing was logged in the window, so there was nothing to analyse.
  nothingToAnalyse,
}

/// The outcome of one analysis run.
class SystemHealthReport {
  const SystemHealthReport({
    required this.request,
    required this.generatedAt,
    required this.digest,
    required this.markdown,
    required this.summaryMarkdown,
    required this.digestMarkdown,
    required this.findingsSource,
    this.findings,
    this.failureDescription,
  });

  final SystemHealthRequest request;
  final DateTime generatedAt;
  final LogDigest digest;

  /// The full report, ready for the clipboard: [summaryMarkdown] followed
  /// by [digestMarkdown] inside a collapsed `<details>` block.
  final String markdown;

  /// Header and findings only — what the page shows expanded.
  final String summaryMarkdown;

  /// The redacted evidence the findings were drawn from.
  final String digestMarkdown;
  final SystemHealthFindingsSource findingsSource;

  /// The model's findings, when [findingsSource] is
  /// [SystemHealthFindingsSource.model].
  final String? findings;

  /// A redacted description of why inference failed, when it did.
  final String? failureDescription;

  /// The report as the page shows and the store keeps it.
  SystemHealthReportDocument toDocument({String? path}) =>
      SystemHealthReportDocument(
        markdown: markdown,
        summaryMarkdown: summaryMarkdown,
        digestMarkdown: digestMarkdown,
        generatedAt: generatedAt,
        path: path,
      );
}

/// A report reduced to its text: what the page renders, what the clipboard
/// gets, and what survives a restart on disk.
///
/// A fresh run produces one from its [SystemHealthReport]; opening the page
/// later restores one from the newest saved file, where the request and the
/// digest objects are gone but the text is all that is needed.
class SystemHealthReportDocument {
  const SystemHealthReportDocument({
    required this.markdown,
    required this.summaryMarkdown,
    required this.digestMarkdown,
    required this.generatedAt,
    this.path,
  });

  /// Splits a saved full report back into its summary and digest.
  factory SystemHealthReportDocument.fromMarkdown(
    String markdown, {
    required DateTime generatedAt,
    String? path,
  }) {
    final index = markdown.indexOf(detailsMarker);
    if (index < 0) {
      return SystemHealthReportDocument(
        markdown: markdown,
        summaryMarkdown: markdown,
        digestMarkdown: '',
        generatedAt: generatedAt,
        path: path,
      );
    }
    final summary = markdown.substring(0, index);
    final rest = markdown.substring(index + detailsMarker.length);
    final summaryEnd = rest.indexOf('\n\n');
    final closing = rest.lastIndexOf('\n</details>');
    final digest = summaryEnd < 0 || closing < summaryEnd
        ? rest
        : rest.substring(summaryEnd + 2, closing);
    return SystemHealthReportDocument(
      markdown: markdown,
      summaryMarkdown: summary,
      digestMarkdown: digest,
      generatedAt: generatedAt,
      path: path,
    );
  }

  /// Marker between the summary and the collapsed digest in [markdown].
  static const String detailsMarker = '\n<details>\n';

  final String markdown;
  final String summaryMarkdown;
  final String digestMarkdown;
  final DateTime generatedAt;

  /// Where the report was saved, when it was.
  final String? path;
}
