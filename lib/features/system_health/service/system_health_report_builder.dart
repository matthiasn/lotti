import 'package:intl/intl.dart';
import 'package:lotti/features/system_health/domain/log_digest.dart';
import 'package:lotti/features/system_health/domain/system_health_range.dart';
import 'package:lotti/features/system_health/domain/system_health_report.dart';

/// The three renderings one analysis produces.
typedef RenderedSystemHealthReport = ({
  String full,
  String summary,
  String digest,
});

/// Renders a digest as Markdown, and wraps it into the copyable report.
///
/// The digest rendering doubles as the prompt handed to the model, so it is
/// budgeted: [renderDigest] halves the number of buckets it shows until the
/// text fits [maxDigestChars]. The report the user copies carries the same
/// digest, collapsed under a `<details>` block, so a reader can check the
/// findings against the evidence they were drawn from.
class SystemHealthReportBuilder {
  const SystemHealthReportBuilder({this.maxDigestChars = 24000});

  final int maxDigestChars;

  static final DateFormat _instant = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _minute = DateFormat('yyyy-MM-dd HH:mm');
  static final NumberFormat _count = NumberFormat.decimalPattern('en_US');

  static const String _redactionNote =
      'PII redaction was applied before analysis: emails, UUIDs, Matrix '
      'ids, tokens and credentials, home-directory paths, IP addresses, '
      'phone numbers and URL query strings were replaced with bracketed '
      'placeholders. Log messages are telemetry by contract and carry no '
      'user content.';

  RenderedSystemHealthReport renderReport({
    required SystemHealthRequest request,
    required LogDigest digest,
    required DateTime generatedAt,
    required SystemHealthFindingsSource findingsSource,
    String? findings,
    String? failureDescription,
  }) {
    final buffer = StringBuffer()
      ..writeln('# Lotti system health report')
      ..writeln()
      ..writeln('- Generated: ${_instant.format(generatedAt)}')
      ..writeln('- Window: ${_describeRange(request.range)}')
      ..writeln('- Domains: ${_describeDomains(request)}')
      ..writeln(
        '- Files read: ${_count.format(digest.filesRead)} · '
        'Lines read: ${_count.format(digest.linesRead)}',
      )
      ..writeln(
        '- Errors: ${_count.format(digest.errorCount)} · '
        'Warnings: ${_count.format(digest.warningCount)} · '
        'Slow queries: ${_count.format(digest.slowQueryCount)} '
        '(super slow: ${_count.format(digest.superSlowQueryCount)})',
      )
      ..writeln('- $_redactionNote')
      ..writeln()
      ..writeln('## Top findings')
      ..writeln();

    switch (findingsSource) {
      case SystemHealthFindingsSource.model:
        buffer
          ..writeln(
            '*Written by ${request.model?.name ?? 'the model'} from '
            'the redacted digest below.*',
          )
          ..writeln()
          ..writeln((findings ?? '').trim());
      case SystemHealthFindingsSource.noModel:
        buffer.writeln(
          '*No model was selected. The digest below is the complete result; '
          'run again with a model to get findings.*',
        );
      case SystemHealthFindingsSource.inferenceFailed:
        buffer.writeln(
          '*The model call failed'
          '${failureDescription == null ? '' : ': $failureDescription'}. '
          'The digest below is still complete.*',
        );
      case SystemHealthFindingsSource.nothingToAnalyse:
        buffer.writeln(
          '*No errors, warnings or slow queries were logged in this window '
          'for the selected domains.*',
        );
    }

    final summary = buffer.toString();
    final digestMarkdown = renderDigest(digest);
    final full = StringBuffer(summary)
      ..writeln()
      ..writeln('<details>')
      ..writeln('<summary>Digest (redacted evidence)</summary>')
      ..writeln()
      ..write(digestMarkdown)
      ..writeln()
      ..writeln('</details>');
    return (full: full.toString(), summary: summary, digest: digestMarkdown);
  }

  /// The digest as Markdown, trimmed to [maxDigestChars].
  String renderDigest(LogDigest digest) {
    var issueLimit = digest.issues.length;
    var queryLimit = digest.slowQueries.length;
    var text = _renderDigest(digest, issueLimit, queryLimit);
    while (text.length > maxDigestChars && (issueLimit > 3 || queryLimit > 3)) {
      issueLimit = issueLimit > 3 ? (issueLimit / 2).ceil() : issueLimit;
      queryLimit = queryLimit > 3 ? (queryLimit / 2).ceil() : queryLimit;
      text = _renderDigest(digest, issueLimit, queryLimit);
    }
    return text;
  }

  String _renderDigest(LogDigest digest, int issueLimit, int queryLimit) {
    final buffer = StringBuffer();
    if (digest.domainCounts.isNotEmpty) {
      buffer
        ..writeln('### Counts by domain')
        ..writeln()
        ..writeln('| Domain | Errors | Warnings | Info |')
        ..writeln('|---|---:|---:|---:|');
      for (final counts in digest.domainCounts) {
        buffer.writeln(
          '| ${counts.domain.wireName} | ${_count.format(counts.errors)} | '
          '${_count.format(counts.warnings)} | ${_count.format(counts.infos)} |',
        );
      }
      buffer.writeln();
    }

    if (digest.errorBursts.isNotEmpty) {
      buffer
        ..writeln('### Error bursts')
        ..writeln();
      for (final burst in digest.errorBursts) {
        buffer.writeln(
          '- ${_minute.format(burst.minute)} — '
          '${_count.format(burst.count)} errors in one minute',
        );
      }
      buffer.writeln();
    }

    final shownIssues = digest.issues.take(issueLimit).toList();
    if (shownIssues.isNotEmpty) {
      final hidden = digest.issues.length - shownIssues.length;
      buffer
        ..writeln(
          '### Issues (${shownIssues.length} of '
          '${_count.format(digest.issues.length)}'
          '${digest.truncated ? '+' : ''} signatures, most frequent first)',
        )
        ..writeln();
      for (final (index, issue) in shownIssues.indexed) {
        final scope = issue.subDomain == null
            ? issue.domain.wireName
            : '${issue.domain.wireName} ${issue.subDomain}';
        buffer
          ..writeln(
            '${index + 1}. **${issue.level} $scope** ×${_count.format(issue.count)} '
            '(first ${_instant.format(issue.firstSeen)}, '
            'last ${_instant.format(issue.lastSeen)})',
          )
          ..writeln('   `${_inline(issue.sample)}`');
        for (final frame in issue.sampleFrames) {
          buffer.writeln('   - ${_inline(frame)}');
        }
      }
      if (hidden > 0) {
        buffer.writeln('${shownIssues.length + 1}. … $hidden more not shown');
      }
      buffer.writeln();
    }

    final shownQueries = digest.slowQueries.take(queryLimit).toList();
    if (shownQueries.isNotEmpty) {
      final hidden = digest.slowQueries.length - shownQueries.length;
      buffer
        ..writeln(
          '### Slow queries (${shownQueries.length} of '
          '${_count.format(digest.slowQueries.length)}'
          '${digest.truncated ? '+' : ''} statements, most total time first)',
        )
        ..writeln();
      for (final (index, query) in shownQueries.indexed) {
        buffer
          ..writeln(
            '${index + 1}. **${query.operation}** ×${_count.format(query.count)} · '
            'p50 ${_ms(query.p50Ms)} · p95 ${_ms(query.p95Ms)} · '
            'max ${_ms(query.maxMs)} · total ${_ms(query.totalMs)} · '
            'super slow ×${_count.format(query.superSlowCount)} '
            '(${_instant.format(query.firstSeen)} → '
            '${_instant.format(query.lastSeen)})',
          )
          ..writeln('   `${_inline(query.statement)}`');
        for (final plan in query.planShapes) {
          buffer.writeln('   - plan: ${_inline(plan)}');
        }
        for (final frame in query.topFrames) {
          buffer.writeln('   - from: ${_inline(frame)}');
        }
      }
      if (hidden > 0) {
        buffer.writeln('${shownQueries.length + 1}. … $hidden more not shown');
      }
      buffer.writeln();
    }

    if (buffer.isEmpty) {
      buffer.writeln('*Nothing was logged in this window.*');
    }
    return buffer.toString();
  }

  static const int _inlineLength = 400;

  /// Single-line, back-tick safe, bounded rendering of a log fragment.
  static String _inline(String text) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').replaceAll('`', "'");
    return collapsed.length <= _inlineLength
        ? collapsed
        : '${collapsed.substring(0, _inlineLength)}…';
  }

  static String _ms(double value) => '${value.toStringAsFixed(0)}ms';

  static String _describeRange(SystemHealthRange range) {
    final preset = switch (range.preset) {
      SystemHealthPreset.last24Hours => 'last 24 hours',
      SystemHealthPreset.last7Days => 'last 7 days',
      SystemHealthPreset.last14Days => 'last 14 days',
      SystemHealthPreset.custom => 'custom',
    };
    return '${_instant.format(range.start)} → ${_instant.format(range.end)} '
        '($preset)';
  }

  static String _describeDomains(SystemHealthRequest request) {
    final names = request.domains.map((d) => d.wireName).toList()..sort();
    final slow = request.includeSlowQueries
        ? 'slow queries included'
        : 'slow queries excluded';
    return names.isEmpty ? 'none · $slow' : '${names.join(', ')} · $slow';
  }
}
