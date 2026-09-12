import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/system_health/domain/log_digest.dart';
import 'package:lotti/services/logging_domains.dart';

void main() {
  const counts = [
    DomainCounts(domain: LogDomain.ai, errors: 2, warnings: 1, infos: 10),
    DomainCounts(domain: LogDomain.sync, errors: 3, warnings: 0, infos: 0),
  ];

  LogDigest digest({
    List<DomainCounts> domainCounts = counts,
    List<LogIssueBucket> issues = const [],
    List<SlowQueryBucket> slowQueries = const [],
  }) => LogDigest(
    domainCounts: domainCounts,
    issues: issues,
    slowQueries: slowQueries,
    errorBursts: const [],
    filesRead: 1,
    linesRead: 1,
    slowQueryCount: 0,
    superSlowQueryCount: 0,
    truncated: false,
  );

  test('error and warning counts sum across domains', () {
    expect(digest().errorCount, 5);
    expect(digest().warningCount, 1);
  });

  test('DomainCounts.total sums all levels', () {
    expect(counts.first.total, 13);
  });

  test('isEmpty only when nothing at all was counted', () {
    expect(digest().isEmpty, isFalse);
    expect(digest(domainCounts: const []).isEmpty, isTrue);
  });
}
