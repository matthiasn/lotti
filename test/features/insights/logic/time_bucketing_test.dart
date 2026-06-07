import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

/// Generated entry spec: a start instant plus a duration, both derived from
/// bounded ints so shrinking converges to the epoch-adjacent minimal case.
class _EntrySpec {
  const _EntrySpec({
    required this.startMinutesFromAnchor,
    required this.durationMinutes,
    required this.categorySeed,
  });

  /// Anchored in March 2024 so generated spans regularly cross the European
  /// and US DST spring-forward transitions (Mar 10 / Mar 31, 2024).
  static final DateTime anchor = DateTime(2024, 3);

  final int startMinutesFromAnchor;
  final int durationMinutes;
  final int categorySeed;

  DateTime get start => DateTime(
    anchor.year,
    anchor.month,
    anchor.day,
    0,
    startMinutesFromAnchor,
  );

  DateTime get end => DateTime(
    anchor.year,
    anchor.month,
    anchor.day,
    0,
    startMinutesFromAnchor + durationMinutes,
  );

  String? get categoryId => categorySeed == 0 ? null : 'cat-$categorySeed';

  InsightsTimeRow get row =>
      InsightsTimeRow(dateFrom: start, dateTo: end, categoryId: categoryId);

  @override
  String toString() =>
      '_EntrySpec(+${startMinutesFromAnchor}m, ${durationMinutes}m, '
      'cat:$categorySeed)';
}

extension _AnyInsights on glados.Any {
  glados.Generator<_EntrySpec> get entrySpec => combine3(
    // Up to ~40 days of starts → spans cross both March 2024 DST changes.
    intInRange(0, 40 * 24 * 60),
    // 1 minute … 3 days, so multi-midnight splits are exercised.
    intInRange(1, 3 * 24 * 60),
    intInRange(0, 4),
    (int start, int duration, int category) => _EntrySpec(
      startMinutesFromAnchor: start,
      durationMinutes: duration,
      categorySeed: category,
    ),
  );

  glados.Generator<List<_EntrySpec>> get entrySpecs => list(entrySpec);
}

int _windowStartDay() => epochDay(_EntrySpec.anchor) - 1;

void main() {
  group('epochDay / dayStart', () {
    test('round-trips local calendar dates', () {
      final dates = [
        DateTime(2024, 3, 10),
        DateTime(2024, 10, 27),
        DateTime(1969, 12, 31),
        DateTime(2026, 6, 7),
      ];
      for (final date in dates) {
        expect(dayStart(epochDay(date)), date);
      }
    });

    test('all instants of one local day map to the same epoch day', () {
      final midnight = DateTime(2024, 3, 10);
      final lateEvening = DateTime(2024, 3, 10, 23, 59, 59);
      expect(epochDay(midnight), epochDay(lateEvening));
      expect(epochDay(DateTime(2024, 3, 11)), epochDay(midnight) + 1);
    });
  });

  group('nextLocalMidnight', () {
    test('preserves the input timezone flavor — UTC in, UTC out', () {
      final next = nextLocalMidnight(DateTime.utc(2024, 3, 9, 22));
      expect(next.isUtc, isTrue);
      expect(next, DateTime.utc(2024, 3, 10));
      // Local inputs (the only flavor the app produces) stay local.
      expect(nextLocalMidnight(DateTime(2024, 3, 9, 22)).isUtc, isFalse);
    });

    test('lands on the next calendar day across month and year ends', () {
      expect(
        nextLocalMidnight(DateTime(2024, 12, 31, 18)),
        DateTime(2025),
      );
      expect(
        nextLocalMidnight(DateTime(2024, 2, 29, 5)),
        DateTime(2024, 3),
      );
    });
  });

  group('mergeIntervals', () {
    test('merges overlapping and touching intervals', () {
      final merged = mergeIntervals([
        TimeInterval(DateTime(2024, 3, 1, 10), DateTime(2024, 3, 1, 11)),
        TimeInterval(DateTime(2024, 3, 1, 10, 30), DateTime(2024, 3, 1, 12)),
        TimeInterval(DateTime(2024, 3, 1, 12), DateTime(2024, 3, 1, 13)),
        TimeInterval(DateTime(2024, 3, 1, 15), DateTime(2024, 3, 1, 16)),
      ]);
      expect(merged, [
        TimeInterval(DateTime(2024, 3, 1, 10), DateTime(2024, 3, 1, 13)),
        TimeInterval(DateTime(2024, 3, 1, 15), DateTime(2024, 3, 1, 16)),
      ]);
      expect(intervalSeconds(merged), 4 * 3600);
    });

    test('nested interval does not extend the container', () {
      final merged = mergeIntervals([
        TimeInterval(DateTime(2024, 3, 1, 10), DateTime(2024, 3, 1, 11, 30)),
        TimeInterval(DateTime(2024, 3, 1, 10, 30), DateTime(2024, 3, 1, 11)),
      ]);
      expect(intervalSeconds(merged), 90 * 60);
    });
  });

  group('bucketize', () {
    test('splits a midnight-crossing entry across both days', () {
      final buckets = bucketize(
        [
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3, 1, 23),
            dateTo: DateTime(2024, 3, 2, 1),
            categoryId: 'work',
          ),
        ],
        windowStartDay: epochDay(DateTime(2024, 3)),
      );
      final day1 = buckets.days[epochDay(DateTime(2024, 3))]!;
      final day2 = buckets.days[epochDay(DateTime(2024, 3, 2))]!;
      expect(day1['work']!.seconds, 3600);
      expect(day2['work']!.seconds, 3600);
    });

    test('clips entries overlapping the window start', () {
      final windowStartDay = epochDay(DateTime(2024, 3, 2));
      final buckets = bucketize(
        [
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3, 1, 22),
            dateTo: DateTime(2024, 3, 2, 2),
            categoryId: 'work',
          ),
        ],
        windowStartDay: windowStartDay,
      );
      expect(buckets.days.keys, [windowStartDay]);
      expect(buckets.days[windowStartDay]!['work']!.seconds, 2 * 3600);
    });

    test('parallel same-category entries union-merge, not double-count', () {
      final buckets = bucketize(
        [
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3, 1, 10),
            dateTo: DateTime(2024, 3, 1, 11, 30),
            categoryId: 'work',
          ),
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3, 1, 10, 30),
            dateTo: DateTime(2024, 3, 1, 11, 15),
            categoryId: 'work',
          ),
        ],
        windowStartDay: epochDay(DateTime(2024, 3)),
      );
      expect(
        buckets.days[epochDay(DateTime(2024, 3))]!['work']!.seconds,
        90 * 60,
      );
    });

    test('different categories are counted independently', () {
      final buckets = bucketize(
        [
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3, 1, 10),
            dateTo: DateTime(2024, 3, 1, 11),
            categoryId: 'work',
          ),
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3, 1, 10),
            dateTo: DateTime(2024, 3, 1, 11),
            categoryId: null,
          ),
        ],
        windowStartDay: epochDay(DateTime(2024, 3)),
      );
      final cells = buckets.days[epochDay(DateTime(2024, 3))]!;
      expect(cells['work']!.seconds, 3600);
      expect(cells[null]!.seconds, 3600);
    });

    test('zero or negative duration rows are dropped', () {
      final buckets = bucketize(
        [
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3, 1, 10),
            dateTo: DateTime(2024, 3, 1, 10),
            categoryId: 'work',
          ),
        ],
        windowStartDay: epochDay(DateTime(2024, 3)),
      );
      expect(buckets.days, isEmpty);
    });
  });

  group('dailyTotals / hourlyTotals', () {
    final buckets = bucketize(
      [
        InsightsTimeRow(
          dateFrom: DateTime(2024, 3, 1, 9, 30),
          dateTo: DateTime(2024, 3, 1, 11, 15),
          categoryId: 'work',
        ),
      ],
      windowStartDay: epochDay(DateTime(2024, 3)),
    );

    test('dailyTotals zero-fills missing days, index-aligned to range', () {
      final range = InsightsRange(
        startDay: epochDay(DateTime(2024, 2, 29)),
        endDayExclusive: epochDay(DateTime(2024, 3, 3)),
      );
      final totals = dailyTotals(buckets, range);
      expect(totals, hasLength(3));
      expect(totals[0], isEmpty);
      expect(totals[1], {'work': 105 * 60});
      expect(totals[2], isEmpty);
    });

    test('hourlyTotals slices merged intervals at hour boundaries', () {
      final hours = hourlyTotals(buckets, epochDay(DateTime(2024, 3)));
      expect(hours, hasLength(24));
      expect(hours[9], {'work': 30 * 60});
      expect(hours[10], {'work': 3600});
      expect(hours[11], {'work': 15 * 60});
      expect(hours[12], isEmpty);
    });
  });

  group('granularityFor / weekStartDay', () {
    InsightsRange rangeOfDays(int days) =>
        InsightsRange(startDay: 19000, endDayExclusive: 19000 + days);

    test('1 day → hour, ≤120 days → day, >120 days → week', () {
      expect(granularityFor(rangeOfDays(1)), InsightsGranularity.hour);
      expect(granularityFor(rangeOfDays(2)), InsightsGranularity.day);
      expect(granularityFor(rangeOfDays(120)), InsightsGranularity.day);
      expect(granularityFor(rangeOfDays(121)), InsightsGranularity.week);
    });

    test('weekStartDay maps every day to its Monday', () {
      // 2024-03-04 was a Monday.
      final monday = epochDay(DateTime(2024, 3, 4));
      for (var offset = 0; offset < 7; offset++) {
        expect(weekStartDay(monday + offset), monday);
      }
      expect(weekStartDay(monday - 1), monday - 7);
    });
  });

  group('buildChartData', () {
    test('ranks series largest-first and rolls overflow into Other', () {
      final day = DateTime(2024, 3);
      final rows = <InsightsTimeRow>[
        for (var c = 0; c < 8; c++)
          InsightsTimeRow(
            dateFrom: DateTime(day.year, day.month, day.day, c),
            // category 0 gets 8h, category 7 gets 1h.
            dateTo: DateTime(day.year, day.month, day.day, c + (8 - c)),
            categoryId: 'cat-$c',
          ),
      ];
      final buckets = bucketize(rows, windowStartDay: epochDay(day));
      final range = InsightsRange(
        startDay: epochDay(day),
        endDayExclusive: epochDay(day) + 7,
      );
      final chart = buildChartData(buckets, range);

      expect(chart.granularity, InsightsGranularity.day);
      expect(chart.seriesKeys, hasLength(kInsightsMaxChartSeries + 1));
      expect(chart.seriesKeys.first, 'cat-0');
      expect(chart.seriesKeys.last, kInsightsOtherCategoryKey);
      // Other = cat-6 (2h) + cat-7 (1h) on day 0.
      expect(chart.values.last[0], 3 * 3600);
      // Total across all series equals the bucketized total.
      final chartTotal = chart.values
          .expand((row) => row)
          .fold<int>(0, (a, b) => a + b);
      expect(chartTotal, 36 * 3600);
    });

    test('single-day range produces 24 hourly buckets', () {
      final day = DateTime(2024, 3);
      final buckets = bucketize(
        [
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3, 1, 14),
            dateTo: DateTime(2024, 3, 1, 15, 30),
            categoryId: 'work',
          ),
        ],
        windowStartDay: epochDay(day),
      );
      final chart = buildChartData(
        buckets,
        InsightsRange(
          startDay: epochDay(day),
          endDayExclusive: epochDay(day) + 1,
        ),
      );
      expect(chart.granularity, InsightsGranularity.hour);
      expect(chart.bucketStarts, hasLength(24));
      expect(chart.values.single[14], 3600);
      expect(chart.values.single[15], 30 * 60);
    });

    test('long ranges aggregate to Monday-aligned weeks', () {
      // 2024-01-01 was a Monday.
      final start = DateTime(2024);
      final buckets = bucketize(
        [
          InsightsTimeRow(
            dateFrom: DateTime(2024, 1, 2, 10),
            dateTo: DateTime(2024, 1, 2, 12),
            categoryId: 'work',
          ),
          InsightsTimeRow(
            dateFrom: DateTime(2024, 1, 9, 10),
            dateTo: DateTime(2024, 1, 9, 11),
            categoryId: 'work',
          ),
        ],
        windowStartDay: epochDay(start),
      );
      final chart = buildChartData(
        buckets,
        InsightsRange(
          startDay: epochDay(start),
          endDayExclusive: epochDay(start) + 200,
        ),
      );
      expect(chart.granularity, InsightsGranularity.week);
      expect(chart.bucketStarts.first, DateTime(2024));
      expect(chart.values.single[0], 2 * 3600);
      expect(chart.values.single[1], 3600);
    });

    test('empty buckets yield empty chart data', () {
      final chart = buildChartData(
        InsightsDayBuckets.empty,
        const InsightsRange(startDay: 19000, endDayExclusive: 19007),
      );
      expect(chart.isEmpty, isTrue);
      expect(chart.seriesKeys, isEmpty);
      expect(chart.bucketStarts, hasLength(7));
    });

    test(
      'mid-week range edges flag partial weeks and clamp the first label',
      () {
        // 2026-01-01 was a Thursday; "today" mid-range is a Sunday.
        final start = DateTime(2026);
        final buckets = bucketize(
          [
            InsightsTimeRow(
              dateFrom: DateTime(2026, 1, 2, 10),
              dateTo: DateTime(2026, 1, 2, 12),
              categoryId: 'work',
            ),
          ],
          windowStartDay: epochDay(start),
        );
        final chart = buildChartData(
          buckets,
          InsightsRange(
            startDay: epochDay(start),
            // Ends mid-week too (a Monday, exclusive → Sunday last day).
            endDayExclusive: epochDay(DateTime(2026, 6, 8)),
          ),
        );
        expect(chart.granularity, InsightsGranularity.week);
        expect(chart.partialFirstBucket, isTrue);
        expect(chart.partialLastBucket, isFalse);
        // The first label is clamped to the range start, never Dec 2025.
        expect(chart.bucketStarts.first, DateTime(2026));
        // The second bucket starts on the first full week's Monday.
        expect(chart.bucketStarts[1], DateTime(2026, 1, 5));
      },
    );

    test('a truncated final week sets partialLastBucket', () {
      final start = DateTime(2026); // Thursday
      final chart = buildChartData(
        InsightsDayBuckets.empty,
        InsightsRange(
          startDay: epochDay(start),
          // Ends on a Thursday (exclusive) → Wednesday last day, mid-week.
          endDayExclusive: epochDay(DateTime(2026, 6, 4)),
        ),
      );
      expect(chart.partialLastBucket, isTrue);
    });
  });

  group('accumulate', () {
    test('produces running sums per series', () {
      expect(
        accumulate([
          [1, 2, 3],
          [0, 0, 5],
        ]),
        [
          [1, 3, 6],
          [0, 0, 5],
        ],
      );
    });
  });

  group('buildTableRows', () {
    test('computes share and avg over days in range', () {
      final day = DateTime(2024, 3);
      final buckets = bucketize(
        [
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3, 1, 9),
            dateTo: DateTime(2024, 3, 1, 12),
            categoryId: 'work',
          ),
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3, 1, 13),
            dateTo: DateTime(2024, 3, 1, 14),
            categoryId: null,
          ),
        ],
        windowStartDay: epochDay(day),
      );
      final rows = buildTableRows(
        buckets,
        InsightsRange(
          startDay: epochDay(day),
          endDayExclusive: epochDay(day) + 4,
        ),
      );
      expect(rows, hasLength(2));
      expect(rows[0].categoryId, 'work');
      expect(rows[0].seconds, 3 * 3600);
      expect(rows[0].share, closeTo(0.75, 1e-9));
      expect(rows[0].avgSecondsPerDay, 3 * 3600 ~/ 4);
      expect(rows[1].categoryId, isNull);
      expect(rows[1].share, closeTo(0.25, 1e-9));
    });

    test('returns empty for ranges without data', () {
      expect(
        buildTableRows(
          InsightsDayBuckets.empty,
          const InsightsRange(startDay: 19000, endDayExclusive: 19007),
        ),
        isEmpty,
      );
    });
  });

  group('buildKpis', () {
    final day = DateTime(2024, 3);
    final buckets = bucketize(
      [
        InsightsTimeRow(
          dateFrom: DateTime(2024, 3, 1, 9),
          dateTo: DateTime(2024, 3, 1, 12),
          categoryId: 'work',
        ),
        InsightsTimeRow(
          dateFrom: DateTime(2024, 3, 1, 13),
          dateTo: DateTime(2024, 3, 1, 14),
          categoryId: 'errands',
        ),
      ],
      windowStartDay: epochDay(day),
    );
    final range = InsightsRange(
      startDay: epochDay(day),
      endDayExclusive: epochDay(day) + 7,
    );

    test('without focus configuration only total is reported', () {
      final kpis = buildKpis(buckets, range, focusCategoryIds: const {});
      expect(kpis.totalSeconds, 4 * 3600);
      expect(kpis.focusSeconds, isNull);
      expect(kpis.otherSeconds, isNull);
    });

    test('with focus categories, focus + other partition the total', () {
      final kpis = buildKpis(buckets, range, focusCategoryIds: const {'work'});
      expect(kpis.totalSeconds, 4 * 3600);
      expect(kpis.focusSeconds, 3 * 3600);
      expect(kpis.otherSeconds, 3600);
    });
  });

  // ---------------------------------------------------------------------
  // Property-based tests (Glados)
  // ---------------------------------------------------------------------

  glados.Glados<List<_EntrySpec>>(
    glados.any.entrySpecs,
  ).test('bucketize conserves per-row duration when no same-category rows '
      'overlap (midnight/DST splits lose nothing)', (specs) {
    // De-overlap by giving every row its own category, isolating the
    // split logic from the (separately tested) union-merge.
    final rows = [
      for (var i = 0; i < specs.length; i++)
        InsightsTimeRow(
          dateFrom: specs[i].start,
          dateTo: specs[i].end,
          categoryId: 'unique-$i',
        ),
    ];
    final buckets = bucketize(rows, windowStartDay: _windowStartDay());
    final bucketTotal = buckets.days.values
        .expand((cells) => cells.values)
        .fold<int>(0, (sum, cell) => sum + cell.seconds);
    final rowTotal = rows.fold<int>(
      0,
      (sum, r) => sum + r.dateTo.difference(r.dateFrom).inSeconds,
    );
    expect(bucketTotal, rowTotal);
  }, tags: 'glados');

  glados.Glados<List<_EntrySpec>>(
    glados.any.entrySpecs,
  ).test('every bucketized segment lies within its day and within the '
      'window', (specs) {
    final windowStartDay = _windowStartDay();
    final buckets = bucketize(
      [for (final s in specs) s.row],
      windowStartDay: windowStartDay,
    );
    buckets.days.forEach((day, cells) {
      expect(day, greaterThanOrEqualTo(windowStartDay));
      final start = dayStart(day);
      final end = nextLocalMidnight(start);
      for (final cell in cells.values) {
        for (final interval in cell.intervals) {
          expect(interval.start.isBefore(start), isFalse);
          expect(interval.end.isAfter(end), isFalse);
        }
      }
    });
  }, tags: 'glados');

  glados.Glados<List<_EntrySpec>>(
    glados.any.entrySpecs,
  ).test('union-merged cells never exceed naive sums and merging is '
      'idempotent', (specs) {
    final buckets = bucketize(
      [for (final s in specs) s.row],
      windowStartDay: _windowStartDay(),
    );
    for (final cells in buckets.days.values) {
      for (final cell in cells.values) {
        // Idempotence: merging an already-merged list is a no-op.
        expect(mergeIntervals(cell.intervals), cell.intervals);
        // Disjoint and sorted.
        for (var i = 1; i < cell.intervals.length; i++) {
          expect(
            cell.intervals[i].start.isAfter(cell.intervals[i - 1].end),
            isTrue,
          );
        }
        expect(cell.seconds, intervalSeconds(cell.intervals));
      }
    }
  }, tags: 'glados');

  glados.Glados<List<_EntrySpec>>(
    glados.any.entrySpecs,
  ).test('chart totals equal table totals equal KPI total for any data', (
    specs,
  ) {
    final buckets = bucketize(
      [for (final s in specs) s.row],
      windowStartDay: _windowStartDay(),
    );
    final range = InsightsRange(
      startDay: _windowStartDay(),
      // Wide enough to cover every generated span (40 days + 3-day max
      // duration + slack).
      endDayExclusive: _windowStartDay() + 50,
    );
    final chartTotal = buildChartData(
      buckets,
      range,
    ).values.expand((row) => row).fold<int>(0, (a, b) => a + b);
    final tableTotal = buildTableRows(
      buckets,
      range,
    ).fold<int>(0, (sum, row) => sum + row.seconds);
    final kpiTotal = buildKpis(
      buckets,
      range,
      focusCategoryIds: const {},
    ).totalSeconds;
    expect(chartTotal, tableTotal);
    expect(tableTotal, kpiTotal);
  }, tags: 'glados');

  glados.Glados<List<_EntrySpec>>(
    glados.any.entrySpecs,
  ).test('table shares sum to 1 and rows are ranked descending', (specs) {
    final buckets = bucketize(
      [for (final s in specs) s.row],
      windowStartDay: _windowStartDay(),
    );
    final range = InsightsRange(
      startDay: _windowStartDay(),
      endDayExclusive: _windowStartDay() + 50,
    );
    final rows = buildTableRows(buckets, range);
    if (rows.isEmpty) return;
    final shareSum = rows.fold<double>(0, (sum, row) => sum + row.share);
    expect(shareSum, closeTo(1, 1e-9));
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].seconds, lessThanOrEqualTo(rows[i - 1].seconds));
    }
  }, tags: 'glados');

  glados.Glados<int>(
    glados.any.intInRange(-100000, 100000),
  ).test('weekStartDay maps every day onto the Monday at or before it', (
    day,
  ) {
    final monday = weekStartDay(day);
    expect(monday, lessThanOrEqualTo(day));
    expect(day - monday, lessThan(7));
    // Anchor: epoch day 4 (1970-01-05) was a Monday; Mondays are ≡ 4 mod 7.
    final remainder = monday % 7;
    expect(remainder < 0 ? remainder + 7 : remainder, 4);
    // Idempotence: a Monday maps to itself.
    expect(weekStartDay(monday), monday);
  }, tags: 'glados');

  glados.Glados<List<_EntrySpec>>(
    glados.any.entrySpecs,
  ).test('cumulative series are monotone non-decreasing', (specs) {
    final buckets = bucketize(
      [for (final s in specs) s.row],
      windowStartDay: _windowStartDay(),
    );
    final chart = buildChartData(
      buckets,
      InsightsRange(
        startDay: _windowStartDay(),
        endDayExclusive: _windowStartDay() + 50,
      ),
    );
    for (final row in accumulate(chart.values)) {
      for (var i = 1; i < row.length; i++) {
        expect(row[i], greaterThanOrEqualTo(row[i - 1]));
      }
    }
  }, tags: 'glados');

  glados.Glados<List<_EntrySpec>>(
    glados.any.entrySpecs,
  ).test("hourly totals for a day sum to that day's daily total", (specs) {
    final buckets = bucketize(
      [for (final s in specs) s.row],
      windowStartDay: _windowStartDay(),
    );
    for (final day in buckets.days.keys) {
      final hourlySum = hourlyTotals(
        buckets,
        day,
      ).expand((bucket) => bucket.values).fold<int>(0, (a, b) => a + b);
      final dailySum = buckets.days[day]!.values.fold<int>(
        0,
        (sum, cell) => sum + cell.seconds,
      );
      expect(hourlySum, dailySum);
    }
  }, tags: 'glados');
}
