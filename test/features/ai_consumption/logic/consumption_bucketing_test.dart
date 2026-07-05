import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_consumption/logic/consumption_bucketing.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart'
    show dayStart, epochDay;

ConsumptionMetricRow _row({
  required DateTime createdAt,
  String? categoryId,
  int totalTokens = 0,
  double energyKwh = 0,
}) {
  return ConsumptionMetricRow(
    createdAt: createdAt,
    categoryId: categoryId,
    metrics: ConsumptionMetrics(
      callCount: 1,
      totalTokens: totalTokens,
      energyKwh: energyKwh,
    ),
  );
}

void main() {
  // A fixed window anchor well inside the supported range.
  final day = epochDay(DateTime(2026, 3, 15));
  final base = dayStart(day);

  test('sums calls in the same (day, category) cell', () {
    final buckets = bucketize(
      [
        _row(
          createdAt: base.add(const Duration(hours: 1)),
          categoryId: 'a',
          totalTokens: 100,
          energyKwh: 0.001,
        ),
        _row(
          createdAt: base.add(const Duration(hours: 5)),
          categoryId: 'a',
          totalTokens: 40,
          energyKwh: 0.002,
        ),
      ],
      windowStartDay: day,
    );

    final cell = buckets.days[day]!['a']!;
    expect(cell.callCount, 2);
    expect(cell.totalTokens, 140);
    expect(cell.energyKwh, closeTo(0.003, 1e-9));
  });

  test('keeps different categories in separate cells on the same day', () {
    final buckets = bucketize(
      [
        _row(createdAt: base, categoryId: 'a', totalTokens: 100),
        _row(createdAt: base, categoryId: 'b', totalTokens: 30),
        _row(createdAt: base, totalTokens: 7), // null category
      ],
      windowStartDay: day,
    );

    final cells = buckets.days[day]!;
    expect(cells['a']!.totalTokens, 100);
    expect(cells['b']!.totalTokens, 30);
    expect(cells[null]!.totalTokens, 7);
  });

  test('separates calls across days', () {
    final nextDay = base.add(const Duration(days: 1, hours: 2));
    final buckets = bucketize(
      [
        _row(createdAt: base, categoryId: 'a', totalTokens: 100),
        _row(createdAt: nextDay, categoryId: 'a', totalTokens: 5),
      ],
      windowStartDay: day,
    );

    expect(buckets.days[day]!['a']!.totalTokens, 100);
    expect(buckets.days[epochDay(nextDay)]!['a']!.totalTokens, 5);
  });

  test('clips rows before the window start', () {
    final before = base.subtract(const Duration(hours: 1));
    final buckets = bucketize(
      [
        _row(createdAt: before, categoryId: 'a', totalTokens: 999),
        _row(createdAt: base, categoryId: 'a', totalTokens: 10),
      ],
      windowStartDay: day,
    );

    expect(buckets.days[day]!['a']!.totalTokens, 10);
    // The clipped row created no earlier-day bucket.
    expect(buckets.days.length, 1);
  });

  test('empty input yields empty buckets', () {
    final buckets = bucketize([], windowStartDay: day);
    expect(buckets.days, isEmpty);
    expect(buckets.windowStartDay, day);
  });

  glados.Glados(
    glados.any.list(glados.any.intInRange(0, 100000)),
    glados.ExploreConfig(numRuns: 160),
  ).test('additive fold preserves total tokens and call count', (seeds) {
    final rows = [
      for (final n in seeds)
        _row(
          createdAt: base.add(Duration(days: n % 30, minutes: n % 720)),
          categoryId: 'cat-${n % 4}',
          totalTokens: n,
        ),
    ];

    final buckets = bucketize(rows, windowStartDay: day);

    var totalTokens = 0;
    var callCount = 0;
    for (final byCategory in buckets.days.values) {
      for (final cell in byCategory.values) {
        totalTokens += cell.totalTokens;
        callCount += cell.callCount;
      }
    }

    // No row is before the window, so nothing is clipped: every call is folded
    // into exactly one cell and no metric is created or lost.
    expect(callCount, rows.length);
    expect(
      totalTokens,
      rows.fold<int>(0, (sum, r) => sum + r.metrics.totalTokens),
    );
  });
}
