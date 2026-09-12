import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/system_health/domain/log_digest.dart';
import 'package:lotti/features/system_health/domain/system_health_report.dart';
import 'package:lotti/features/system_health/service/system_health_report_store.dart';
import 'package:path/path.dart' as p;

import '../system_health_test_fixtures.dart';

void main() {
  late Directory root;
  late SystemHealthReportStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('system_health_store');
    store = SystemHealthReportStore(
      directory: Directory(p.join(root.path, 'reports')),
    );
  });

  tearDown(() => root.delete(recursive: true));

  SystemHealthReport report(DateTime generatedAt, String findings) =>
      SystemHealthReport(
        request: SystemHealthRequest(
          range: fixtureRange(),
          domains: const {},
          includeSlowQueries: false,
        ),
        generatedAt: generatedAt,
        digest: const LogDigest(
          domainCounts: [],
          issues: [],
          slowQueries: [],
          errorBursts: [],
          filesRead: 0,
          linesRead: 0,
          slowQueryCount: 0,
          superSlowQueryCount: 0,
          truncated: false,
        ),
        markdown:
            '# Report\n\n'
            '- Window: 2026-09-11 00:00 → 2026-09-12 23:59 (custom)\n\n'
            '$findings\n\n<details>\n<summary>D</summary>\n\n'
            'digest body\n\n</details>\n',
        summaryMarkdown:
            '# Report\n\n'
            '- Window: 2026-09-11 00:00 → 2026-09-12 23:59 (custom)\n\n'
            '$findings\n',
        digestMarkdown: 'digest body\n',
        findingsSource: SystemHealthFindingsSource.model,
        findings: findings,
      );

  test(
    'save writes a timestamped markdown file and returns its path',
    () async {
      final document = await store.save(
        report(DateTime(2026, 9, 12, 14, 3, 7), '### One'),
      );

      expect(
        document.path,
        p.join(root.path, 'reports', 'system-health-2026-09-12-140307.md'),
      );
      expect(await File(document.path!).readAsString(), startsWith('# Report'));
      expect(document.summaryMarkdown, endsWith('### One\n'));
      expect(document.windowStart, fixtureRange().start);
      // A fresh document carries the exact request bound, not the parsed one.
      expect(document.windowEnd, fixtureRange().end);
      expect(document.digestMarkdown, 'digest body\n');
    },
  );

  test('loadLatest returns the newest report split into its parts', () async {
    await store.save(report(DateTime(2026, 9, 10, 8), '### Old'));
    await store.save(report(DateTime(2026, 9, 12, 9), '### New'));
    await store.save(report(DateTime(2026, 9, 11, 23, 59), '### Middle'));
    await File(p.join(store.directory.path, 'notes.md')).writeAsString('x');
    await File(
      p.join(store.directory.path, 'system-health-not-a-date.md'),
    ).writeAsString('x');

    final latest = await store.loadLatest();

    expect(latest, isNotNull);
    expect(latest!.generatedAt, DateTime(2026, 9, 12, 9));
    expect(latest.summaryMarkdown, endsWith('### New\n'));
    expect(latest.digestMarkdown, 'digest body\n');
    expect(latest.markdown, contains('<details>'));
    expect(latest.path, endsWith('system-health-2026-09-12-090000.md'));
  });

  test('list returns every readable report, newest first', () async {
    await store.save(report(DateTime(2026, 9, 10, 8), '### Old'));
    await store.save(report(DateTime(2026, 9, 12, 9), '### New'));
    await store.save(report(DateTime(2026, 9, 11, 23, 59), '### Middle'));
    final unreadable = File(
      p.join(store.directory.path, 'system-health-2026-09-13-000000.md'),
    );
    await unreadable.writeAsString('# secret');
    await Process.run('chmod', ['000', unreadable.path]);
    addTearDown(() => Process.run('chmod', ['644', unreadable.path]));

    final documents = await store.list();

    expect(
      documents.map((d) => d.summaryMarkdown.trim().split('\n').last),
      ['### New', '### Middle', '### Old'],
    );
    expect(
      documents.first.path,
      endsWith('system-health-2026-09-12-090000.md'),
    );
    expect(documents.first.windowStart, fixtureRange().start);
    expect(documents.first.windowEnd, DateTime(2026, 9, 12, 23, 59));
  });

  test('loadLatest is null without a folder or without reports', () async {
    expect(await store.loadLatest(), isNull);
    await store.directory.create(recursive: true);
    expect(await store.loadLatest(), isNull);
  });

  test('loadLatest is null when the newest file cannot be read', () async {
    await store.directory.create(recursive: true);
    final unreadable = File(
      p.join(store.directory.path, 'system-health-2026-09-12-090000.md'),
    );
    await unreadable.writeAsString('# secret');
    await Process.run('chmod', ['000', unreadable.path]);
    addTearDown(() => Process.run('chmod', ['644', unreadable.path]));
    expect(await store.loadLatest(), isNull);
  });
}
