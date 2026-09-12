import 'package:clock/clock.dart';
import 'package:lotti/features/system_health/domain/log_digest.dart';
import 'package:lotti/features/system_health/domain/system_health_report.dart';
import 'package:lotti/features/system_health/service/log_digest_builder.dart';
import 'package:lotti/features/system_health/service/log_file_reader.dart';
import 'package:lotti/features/system_health/service/log_redactor.dart';
import 'package:lotti/features/system_health/service/system_health_findings_inference.dart';
import 'package:lotti/features/system_health/service/system_health_report_builder.dart';

/// Turns a [SystemHealthRequest] into a [SystemHealthReport].
///
/// Read → redact and digest → optionally ask a model for the top findings →
/// render. The class has no UI dependency on purpose: the Settings page
/// calls it today, and a scheduled check can call the same method later.
class SystemHealthAnalyzer {
  const SystemHealthAnalyzer({
    required this.reader,
    this.digestBuilder = const LogDigestBuilder(),
    this.reportBuilder = const SystemHealthReportBuilder(),
    this.redactor = const LogRedactor(),
    this.findingsWriter,
  });

  final LogFileReader reader;
  final LogDigestBuilder digestBuilder;
  final SystemHealthReportBuilder reportBuilder;
  final LogRedactor redactor;

  /// Absent when the caller has no way to run a model; the report is then
  /// digest-only.
  final SystemHealthFindingsWriter? findingsWriter;

  /// What the model is told before it sees the digest.
  static const String systemMessage =
      'You are a senior Flutter and Dart engineer reviewing redacted '
      'diagnostic logs from Lotti, a journaling app built with Flutter, '
      'Riverpod, Drift and SQLite. You receive a digest, not raw logs: '
      'per-domain counts, error and warning signatures with a sample and '
      'stack frames, error bursts, and slow-query statistics with query '
      'plans.\n\n'
      'Write the top three findings that most deserve engineering '
      'attention, ordered by impact. Each finding is a "### " heading '
      'followed by two to four sentences: what the evidence shows (quote '
      'counts, signatures and timings from the digest), the most likely '
      'cause, and one concrete next step for an engineer with access to '
      'the codebase. Prefer what repeats most or costs the most time. If '
      'the digest shows nothing worth attention, say so in one sentence.\n\n'
      'Never invent facts that are not in the digest. Do not restate the '
      'digest, do not add a preamble or a closing remark, and stay under '
      '300 words. Output Markdown only.';

  Future<SystemHealthReport> analyze(SystemHealthRequest request) async {
    final input = await reader.read(
      range: request.range,
      domains: request.domains,
      includeSlowQueries: request.includeSlowQueries,
    );
    final digest = digestBuilder.build(input);
    final generatedAt = clock.now();

    var source = SystemHealthFindingsSource.noModel;
    String? findings;
    String? failure;

    final writer = findingsWriter;
    final model = request.model;
    if (!_hasAnythingToAnalyse(digest)) {
      source = SystemHealthFindingsSource.nothingToAnalyse;
    } else if (model != null && writer != null) {
      try {
        findings = await writer(
          systemMessage: systemMessage,
          prompt: reportBuilder.renderDigest(digest),
          model: model,
        );
        source = findings.trim().isEmpty
            ? SystemHealthFindingsSource.inferenceFailed
            : SystemHealthFindingsSource.model;
        if (source == SystemHealthFindingsSource.inferenceFailed) {
          failure = 'the model returned an empty response';
          findings = null;
        }
      } catch (error) {
        source = SystemHealthFindingsSource.inferenceFailed;
        failure = redactor.redact(error.toString());
      }
    }

    final rendered = reportBuilder.renderReport(
      request: request,
      digest: digest,
      generatedAt: generatedAt,
      findingsSource: source,
      findings: findings,
      failureDescription: failure,
    );
    return SystemHealthReport(
      request: request,
      generatedAt: generatedAt,
      digest: digest,
      markdown: rendered.full,
      summaryMarkdown: rendered.summary,
      digestMarkdown: rendered.digest,
      findingsSource: source,
      findings: findings,
      failureDescription: failure,
    );
  }

  static bool _hasAnythingToAnalyse(LogDigest digest) =>
      digest.issues.isNotEmpty || digest.slowQueries.isNotEmpty;
}
