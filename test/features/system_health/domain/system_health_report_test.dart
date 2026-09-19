import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/system_health/domain/log_digest.dart';
import 'package:lotti/features/system_health/domain/system_health_range.dart';
import 'package:lotti/features/system_health/domain/system_health_report.dart';
import 'package:lotti/features/system_health/service/system_health_report_builder.dart';
import 'package:lotti/services/logging_domains.dart';

void main() {
  final at = DateTime(2026, 9, 12, 14, 3);

  test('fromMarkdown splits a full report into summary and digest', () {
    const full =
        '# Lotti system health report\n\n'
        '- Generated: 2026-09-12 14:03\n'
        '- Window: 2026-09-05 14:03 → 2026-09-12 14:03 (last 7 days)\n\n'
        '## Top findings\n\nText.\n\n'
        '<details>\n<summary>Digest (redacted evidence)</summary>\n\n'
        '### Counts by domain\n\n| a | 1 |\n\n</details>\n';
    final document = SystemHealthReportDocument.fromMarkdown(
      full,
      generatedAt: at,
      path: '/x/report.md',
    );
    expect(document.markdown, full);
    expect(
      document.summaryMarkdown,
      startsWith('# Lotti system health report'),
    );
    expect(document.summaryMarkdown, endsWith('## Top findings\n\nText.\n'));
    expect(document.windowStart, DateTime(2026, 9, 5, 14, 3));
    expect(document.windowEnd, DateTime(2026, 9, 12, 14, 3));
    expect(document.digestMarkdown, '### Counts by domain\n\n| a | 1 |\n');
    expect(document.generatedAt, at);
    expect(document.path, '/x/report.md');
  });

  test('fromMarkdown without a details block keeps everything as summary', () {
    final document = SystemHealthReportDocument.fromMarkdown(
      '# Report only\n',
      generatedAt: at,
    );
    expect(document.summaryMarkdown, '# Report only\n');
    expect(document.digestMarkdown, isEmpty);
    expect(document.path, isNull);
    expect(document.windowStart, isNull);
    expect(document.windowEnd, isNull);
  });

  test('a truncated details block yields the remainder as digest', () {
    final document = SystemHealthReportDocument.fromMarkdown(
      '# S\n\n<details>\n<summary>x</summary>\n\n### Digest\n',
      generatedAt: at,
    );
    expect(document.summaryMarkdown, '# S\n');
    expect(document.digestMarkdown, '<summary>x</summary>\n\n### Digest\n');
  });

  group('round-trip properties', () {
    const builder = SystemHealthReportBuilder();
    final base = DateTime(2026, 9, 12, 14, 3);

    LogDigest digestWith(List<String> messages) => LogDigest(
      domainCounts: const [],
      issues: [
        for (final (i, message) in messages.indexed)
          LogIssueBucket(
            domain: LogDomain.agentRuntime,
            level: 'ERROR',
            subDomain: 'execute',
            signature: message,
            count: i + 1,
            firstSeen: base,
            lastSeen: base,
            sample: message,
          ),
      ],
      slowQueries: const [],
      errorBursts: const [],
      filesRead: 1,
      linesRead: messages.length,
      slowQueryCount: 0,
      superSlowQueryCount: 0,
      truncated: false,
    );

    // Model findings may carry any Markdown, including their own collapsed
    // sections.
    final findingsLine = glados.any.choose([
      '### Finding',
      'Plain text.',
      '',
      '<details>',
      '<summary>More</summary>',
      '</details>',
      '- Window: nonsense',
    ]);

    glados.Glados3(
      glados.any.combine3(
        glados.any.intInRange(0, 60 * 24 * 30),
        glados.any.intInRange(0, 60 * 24 * 30),
        glados.any.choose(SystemHealthPreset.values),
        (int back, int length, SystemHealthPreset preset) => SystemHealthRange(
          preset: preset,
          start: base.subtract(Duration(minutes: back + length)),
          // Seconds past the minute, which the header drops.
          end: base
              .subtract(Duration(minutes: back))
              .add(const Duration(seconds: 7)),
        ),
      ),
      glados.any.listWithLengthInRange(0, 6, findingsLine),
      glados.any.listWithLengthInRange(
        0,
        4,
        glados.any.choose(['wake failed #', 'sync stalled', 'a | b']),
      ),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'a saved report reads back its window, summary and digest',
      (range, findings, messages) {
        final rendered = builder.renderReport(
          request: SystemHealthRequest(
            range: range,
            domains: const {LogDomain.agentRuntime},
            includeSlowQueries: false,
          ),
          digest: digestWith(messages),
          generatedAt: base,
          findingsSource: SystemHealthFindingsSource.model,
          findings: findings.join('\n'),
        );

        final document = SystemHealthReportDocument.fromMarkdown(
          rendered.full,
          generatedAt: base,
        );

        DateTime minute(DateTime t) =>
            DateTime(t.year, t.month, t.day, t.hour, t.minute);
        expect(document.windowStart, minute(range.start));
        expect(document.windowEnd, minute(range.end));
        expect(document.summaryMarkdown, rendered.summary);
        expect(document.digestMarkdown, rendered.digest);
      },
      tags: 'glados',
    );
  });
}
