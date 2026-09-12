import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/system_health/domain/system_health_report.dart';

void main() {
  final at = DateTime(2026, 9, 12, 14, 3);

  test('fromMarkdown splits a full report into summary and digest', () {
    const full =
        '# Lotti system health report\n\n## Top findings\n\nText.\n\n'
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
      '# Lotti system health report\n\n## Top findings\n\nText.\n',
    );
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
  });

  test('a truncated details block yields the remainder as digest', () {
    final document = SystemHealthReportDocument.fromMarkdown(
      '# S\n\n<details>\n<summary>x</summary>\n\n### Digest\n',
      generatedAt: at,
    );
    expect(document.summaryMarkdown, '# S\n');
    expect(document.digestMarkdown, '<summary>x</summary>\n\n### Digest\n');
  });
}
