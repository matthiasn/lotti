import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/system_health/domain/log_digest.dart';
import 'package:lotti/features/system_health/domain/system_health_range.dart';
import 'package:lotti/features/system_health/domain/system_health_report.dart';
import 'package:lotti/features/system_health/service/system_health_report_builder.dart';
import 'package:lotti/services/logging_domains.dart';

import '../../agents/test_data/ai_config_factories.dart';

void main() {
  const builder = SystemHealthReportBuilder();
  final generatedAt = DateTime(2026, 9, 12, 14, 3);
  final range = SystemHealthRange(
    preset: SystemHealthPreset.last7Days,
    start: DateTime(2026, 9, 5, 14, 3),
    end: generatedAt,
  );
  final t0 = DateTime(2026, 9, 12, 0, 5);

  LogIssueBucket issue(int index, {String level = 'ERROR', int count = 1}) =>
      LogIssueBucket(
        domain: LogDomain.agentRuntime,
        level: level,
        subDomain: 'execute',
        signature: 'wake failed # $index',
        count: count,
        firstSeen: t0,
        lastSeen: t0,
        sample: 'wake failed `now` $index',
        sampleFrames: const ['#0 Foo.bar (package:lotti/foo.dart:1:1)'],
      );

  SlowQueryBucket query(int index, {QueueDepthStats? queueDepth}) =>
      SlowQueryBucket(
        databaseName: 'db.sqlite',
        queueDepth: queueDepth,
        statement: 'SELECT $index FROM journal',
        operation: 'select',
        count: 3,
        superSlowCount: 1,
        p50Ms: 12.4,
        p95Ms: 200,
        maxMs: 388.759,
        totalMs: 600,
        firstSeen: t0,
        lastSeen: t0,
        planShapes: const ['84|0|USE TEMP B-TREE FOR ORDER BY'],
        topFrames: const [
          '#10 JournalDb.get (package:lotti/database/database.dart:1:1)',
        ],
      );

  LogDigest digest({
    List<LogIssueBucket> issues = const [],
    List<SlowQueryBucket> slowQueries = const [],
    List<DomainCounts> domainCounts = const [],
    List<ErrorBurst> errorBursts = const [],
    bool truncated = false,
  }) => LogDigest(
    domainCounts: domainCounts,
    issues: issues,
    slowQueries: slowQueries,
    errorBursts: errorBursts,
    filesRead: 3,
    linesRead: 1234,
    slowQueryCount: 6,
    superSlowQueryCount: 2,
    truncated: truncated,
  );

  SystemHealthRequest request({bool withModel = true}) => SystemHealthRequest(
    range: range,
    domains: {LogDomain.sync, LogDomain.agentRuntime},
    includeSlowQueries: true,
    model: withModel ? testAiModel() : null,
  );

  group('renderReport', () {
    test('header names the window, domains, counts and the redaction', () {
      final rendered = builder.renderReport(
        request: request(),
        digest: digest(
          domainCounts: const [
            DomainCounts(
              domain: LogDomain.agentRuntime,
              errors: 4,
              warnings: 1,
              infos: 1200,
            ),
          ],
        ),
        generatedAt: generatedAt,
        findingsSource: SystemHealthFindingsSource.model,
        findings: '### Finding one\nText.',
      );

      expect(rendered.summary, startsWith('# Lotti system health report'));
      expect(rendered.summary, contains('- Generated: 2026-09-12 14:03'));
      expect(
        rendered.summary,
        contains('- Window: 2026-09-05 14:03 → 2026-09-12 14:03 (last 7 days)'),
      );
      expect(
        rendered.summary,
        contains('- Domains: agentRuntime, sync · slow queries included'),
      );
      expect(rendered.summary, contains('Files read: 3 · Lines read: 1,234'));
      expect(
        rendered.summary,
        contains('Errors: 4 · Warnings: 1 · Slow queries: 6 (super slow: 2)'),
      );
      expect(rendered.summary, contains('PII redaction was applied'));
      expect(rendered.summary, contains('*Written by Test Model from'));
      expect(rendered.summary, contains('### Finding one\nText.'));
      expect(rendered.full, startsWith(rendered.summary));
      expect(rendered.full, contains('<details>'));
      expect(rendered.full, contains(rendered.digest));
      expect(rendered.full, endsWith('</details>\n'));
    });

    test('explains a digest-only report when no model was chosen', () {
      final rendered = builder.renderReport(
        request: request(withModel: false),
        digest: digest(),
        generatedAt: generatedAt,
        findingsSource: SystemHealthFindingsSource.noModel,
      );
      expect(rendered.summary, contains('*No model was selected.'));
      expect(rendered.summary, contains('slow queries included'));
    });

    test('explains a failed model call with its redacted reason', () {
      final rendered = builder.renderReport(
        request: request(),
        digest: digest(),
        generatedAt: generatedAt,
        findingsSource: SystemHealthFindingsSource.inferenceFailed,
        failureDescription: 'provider has no API key',
      );
      expect(
        rendered.summary,
        contains('*The model call failed: provider has no API key. The digest'),
      );
    });

    test('says so when nothing was logged', () {
      final rendered = builder.renderReport(
        request: SystemHealthRequest(
          range: range,
          domains: const {},
          includeSlowQueries: false,
        ),
        digest: digest(),
        generatedAt: generatedAt,
        findingsSource: SystemHealthFindingsSource.nothingToAnalyse,
      );
      expect(
        rendered.summary,
        contains('*No errors, warnings or slow queries'),
      );
      expect(
        rendered.summary,
        contains('- Domains: none · slow queries excluded'),
      );
      expect(rendered.digest, '*Nothing was logged in this window.*\n');
    });

    test('custom windows are labelled as such', () {
      final rendered = builder.renderReport(
        request: SystemHealthRequest(
          range: SystemHealthRange.days(
            firstDay: DateTime(2026, 9),
            lastDay: DateTime(2026, 9, 3),
          ),
          domains: const {LogDomain.ai},
          includeSlowQueries: false,
        ),
        digest: digest(),
        generatedAt: generatedAt,
        findingsSource: SystemHealthFindingsSource.noModel,
      );
      expect(
        rendered.summary,
        contains('- Window: 2026-09-01 00:00 → 2026-09-03 23:59 (custom)'),
      );
    });
  });

  group('renderDigest', () {
    test(
      'a statement with queue-depth stats renders them on their own row',
      () {
        final text = builder.renderDigest(
          digest(
            slowQueries: [
              query(
                1,
                queueDepth: const QueueDepthStats(
                  inFlightP50: 3,
                  inFlightMax: 61,
                  openTransactionsP50: 1,
                  openTransactionsMax: 4,
                ),
              ),
              query(2),
            ],
          ),
        );

        expect(
          text,
          contains(
            '   - queue at start: in flight p50 3 · max 61 · '
            'open transactions p50 1 · max 4',
          ),
        );
        // Only the bucket that carries stats gets the row.
        expect('queue at start'.allMatches(text), hasLength(1));
      },
    );

    test('renders counts, bursts, issues and slow queries', () {
      final text = builder.renderDigest(
        digest(
          domainCounts: const [
            DomainCounts(
              domain: LogDomain.sync,
              errors: 2,
              warnings: 0,
              infos: 9,
            ),
          ],
          errorBursts: [ErrorBurst(minute: t0, count: 38)],
          issues: [
            issue(1, count: 12),
            issue(2, level: 'WARN'),
          ],
          slowQueries: [query(1)],
        ),
      );

      expect(text, contains('| sync | 2 | 0 | 9 |'));
      expect(text, contains('- 2026-09-12 00:05 — 38 errors in one minute'));
      expect(
        text,
        contains('### Issues (2 of 2 signatures, most frequent first)'),
      );
      expect(
        text,
        contains(
          '1. **ERROR agentRuntime execute** ×12 '
          '(first 2026-09-12 00:05, last 2026-09-12 00:05)',
        ),
      );
      // Back-ticks inside a sample cannot break the inline code span.
      expect(text, contains("   `wake failed 'now' 1`"));
      expect(text, contains('   - #0 Foo.bar (package:lotti/foo.dart:1:1)'));
      expect(text, contains('2. **WARN agentRuntime execute** ×1'));
      expect(
        text,
        contains(
          '1. **select** on db.sqlite ×3 · p50 12ms · p95 200ms · '
          'max 389ms · total 600ms · '
          'super slow ×1 (2026-09-12 00:05 → 2026-09-12 00:05)',
        ),
      );
      expect(text, contains('   `SELECT 1 FROM journal`'));
      expect(text, contains('   - plan: 84|0|USE TEMP B-TREE FOR ORDER BY'));
      expect(text, contains('   - from: #10 JournalDb.get'));
    });

    test('marks a truncated digest with a plus sign', () {
      final text = builder.renderDigest(
        digest(issues: [issue(1)], truncated: true),
      );
      expect(text, contains('### Issues (1 of 1+ signatures'));
    });

    test('halves the shown buckets until the text fits the budget', () {
      const tight = SystemHealthReportBuilder(maxDigestChars: 1500);
      final text = tight.renderDigest(
        digest(
          issues: [for (var i = 0; i < 40; i++) issue(i)],
          slowQueries: [for (var i = 0; i < 40; i++) query(i)],
        ),
      );

      expect(text.length, lessThanOrEqualTo(1500 + 200));
      expect(text, contains('more not shown'));
      expect(text, contains('### Issues (3 of 40 signatures'));
      expect(text, contains('### Slow queries (3 of 40 statements'));
    });

    test('long fragments are cut with an ellipsis', () {
      final text = builder.renderDigest(
        digest(
          issues: [
            LogIssueBucket(
              domain: LogDomain.ai,
              level: 'ERROR',
              signature: 's',
              count: 1,
              firstSeen: t0,
              lastSeen: t0,
              sample: 'x' * 600,
            ),
          ],
        ),
      );
      expect(text, contains('${'x' * 400}…`'));
    });
  });
}
