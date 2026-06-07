import 'dart:math' as math;

import 'package:lotti/features/insights/model/insights_models.dart';

/// Pure bucketing logic for the Insights time analysis dashboard.
///
/// Everything in this file is deterministic and free of Flutter/database
/// imports so it can be exhaustively property-tested (see the Glados tests
/// in `test/features/insights/logic/`).
///
/// Day keys are "epoch days": the number of calendar days since 1970-01-01
/// for the **local** calendar date. They are computed through a UTC anchor
/// so the index is a pure calendar quantity, immune to DST offsets.

/// Epoch-day index of the local calendar date of [dt].
int epochDay(DateTime dt) =>
    DateTime.utc(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Local midnight at the start of the given epoch [day].
///
/// Uses the UTC anchor to recover (year, month, day), then constructs the
/// local `DateTime` — the proven DST-safe pattern from the Daily OS
/// controllers (calendar arithmetic, never `Duration`-based day math).
DateTime dayStart(int day) {
  final anchor = DateTime.fromMillisecondsSinceEpoch(
    day * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return DateTime(anchor.year, anchor.month, anchor.day);
}

/// Local midnight at the start of the day **after** [dt]'s calendar day.
///
/// `DateTime(y, m, d + 1)` lets Dart normalize month/year rollover and lands
/// exactly on the next local midnight even across 23h/25h DST days, unlike
/// `dt.add(const Duration(days: 1))`.
DateTime nextLocalMidnight(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day + 1);

/// Merges overlapping or touching intervals into a sorted, disjoint list.
///
/// This is the union semantic used across the app (see
/// `calculateUnionDuration` in the Daily OS feature): a 90-minute entry
/// containing a parallel 45-minute entry counts 90 minutes, not 135.
///
/// Scope note: the union applies **within one (day, category) cell**.
/// Parallel entries in *different* categories each count fully toward
/// their own category — correct for a stacked per-category breakdown,
/// which means a day's summed total can exceed wall-clock time.
List<TimeInterval> mergeIntervals(List<TimeInterval> intervals) {
  if (intervals.length <= 1) return List.of(intervals);
  final sorted = List.of(intervals)..sort((a, b) => a.start.compareTo(b.start));
  final merged = <TimeInterval>[sorted.first];
  for (final interval in sorted.skip(1)) {
    final last = merged.last;
    if (!interval.start.isAfter(last.end)) {
      if (interval.end.isAfter(last.end)) {
        merged[merged.length - 1] = TimeInterval(last.start, interval.end);
      }
    } else {
      merged.add(interval);
    }
  }
  return merged;
}

/// Total length of a disjoint interval list, in whole seconds.
int intervalSeconds(List<TimeInterval> intervals) {
  var total = 0;
  for (final interval in intervals) {
    total += interval.duration.inSeconds;
  }
  return total;
}

/// Splits the absolute span `[start, end)` into per-local-day segments.
///
/// The sum of segment durations is exactly `end - start` — local midnights
/// are absolute instants, so no time is created or lost across DST
/// transitions.
List<TimeInterval> splitByLocalDay(DateTime start, DateTime end) {
  final segments = <TimeInterval>[];
  var cursor = start;
  while (cursor.isBefore(end)) {
    final boundary = nextLocalMidnight(cursor);
    final segmentEnd = boundary.isBefore(end) ? boundary : end;
    segments.add(TimeInterval(cursor, segmentEnd));
    cursor = segmentEnd;
  }
  return segments;
}

/// Buckets slim time rows into per-day, per-category cells.
///
/// Rows are clipped to the window start (rows can overlap the window edge
/// because the query loads by interval overlap), split at local midnights,
/// and union-merged per (day, category) cell.
InsightsDayBuckets bucketize(
  List<InsightsTimeRow> rows, {
  required int windowStartDay,
}) {
  final windowStart = dayStart(windowStartDay);
  final raw = <int, Map<String?, List<TimeInterval>>>{};

  for (final row in rows) {
    var start = row.dateFrom;
    final end = row.dateTo;
    if (!end.isAfter(start)) continue;
    if (start.isBefore(windowStart)) {
      start = windowStart;
      if (!end.isAfter(start)) continue;
    }
    for (final segment in splitByLocalDay(start, end)) {
      raw
          .putIfAbsent(
            epochDay(segment.start),
            () => <String?, List<TimeInterval>>{},
          )
          .putIfAbsent(row.categoryId, () => <TimeInterval>[])
          .add(segment);
    }
  }

  final days = <int, Map<String?, InsightsDayCell>>{};
  raw.forEach((day, byCategory) {
    final cells = <String?, InsightsDayCell>{};
    byCategory.forEach((categoryId, intervals) {
      final merged = mergeIntervals(intervals);
      final seconds = intervalSeconds(merged);
      if (seconds > 0) {
        cells[categoryId] = InsightsDayCell(
          seconds: seconds,
          intervals: merged,
        );
      }
    });
    if (cells.isNotEmpty) {
      days[day] = cells;
    }
  });

  return InsightsDayBuckets(windowStartDay: windowStartDay, days: days);
}

/// Seconds per category for every day of [range], zero-filled for days
/// without data. Index `i` of the result is day `range.startDay + i`.
List<Map<String?, int>> dailyTotals(
  InsightsDayBuckets buckets,
  InsightsRange range,
) {
  return List.generate(range.dayCount, (i) {
    final cells = buckets.days[range.startDay + i];
    if (cells == null) return const <String?, int>{};
    return {
      for (final entry in cells.entries) entry.key: entry.value.seconds,
    };
  });
}

/// Seconds per category for each of the 24 hours of epoch [day], computed
/// by re-slicing the merged cell intervals — no extra database round trip.
List<Map<String?, int>> hourlyTotals(InsightsDayBuckets buckets, int day) {
  final cells = buckets.days[day];
  final start = dayStart(day);
  // Hour boundaries built via constructor normalization (DST-safe). On a
  // 25h fall-back day the repeated-hour slot widens to two hours; on a
  // 23h day the skipped hour stays empty — the half-open slots always
  // tile the day, so totals remain exact either way.
  final boundaries = List<DateTime>.generate(
    25,
    (h) => DateTime(start.year, start.month, start.day, h),
  );
  final result = List.generate(24, (_) => <String?, int>{});
  if (cells == null) return result;

  cells.forEach((categoryId, cell) {
    for (final interval in cell.intervals) {
      for (var h = 0; h < 24; h++) {
        final hourStart = boundaries[h];
        final hourEnd = boundaries[h + 1];
        final overlapStart = interval.start.isAfter(hourStart)
            ? interval.start
            : hourStart;
        final overlapEnd = interval.end.isBefore(hourEnd)
            ? interval.end
            : hourEnd;
        if (overlapEnd.isAfter(overlapStart)) {
          final seconds = overlapEnd.difference(overlapStart).inSeconds;
          result[h][categoryId] = (result[h][categoryId] ?? 0) + seconds;
        }
      }
    }
  });
  return result;
}

/// Total seconds per category across the whole range, descending.
List<MapEntry<String?, int>> rankedCategoryTotals(
  List<Map<String?, int>> totalsPerBucket,
) {
  final totals = <String?, int>{};
  for (final bucket in totalsPerBucket) {
    bucket.forEach((categoryId, seconds) {
      totals[categoryId] = (totals[categoryId] ?? 0) + seconds;
    });
  }
  final entries = totals.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries;
}

/// Maximum number of distinct chart series before the "Other" rollup.
///
/// Stephen Few: beyond ~6 stacked bands, middle series become
/// indistinguishable; the exhaustive table below the chart carries the
/// full breakdown instead.
const int kInsightsMaxChartSeries = 6;

/// Days above which the chart aggregates to calendar weeks to keep the
/// x-axis legible and the painter cheap (YTD → ~52 points, not 366).
const int kInsightsWeeklyThresholdDays = 120;

/// Granularity for a range: hourly for a single day, weekly for long
/// ranges, daily otherwise.
InsightsGranularity granularityFor(InsightsRange range) {
  if (range.dayCount == 1) return InsightsGranularity.hour;
  if (range.dayCount > kInsightsWeeklyThresholdDays) {
    return InsightsGranularity.week;
  }
  return InsightsGranularity.day;
}

/// Epoch day of the Monday on or before epoch [day].
/// Day 0 (1970-01-01) was a Thursday; day 4 the first Monday.
int weekStartDay(int day) {
  final offset = (day - 4) % 7;
  return day - (offset < 0 ? offset + 7 : offset);
}

/// Builds chart-ready stacked series for [range]: resolves granularity,
/// aggregates weekly when needed, ranks categories, and rolls everything
/// beyond [kInsightsMaxChartSeries] into [kInsightsOtherCategoryKey].
///
/// Series are ordered largest-total-first so the biggest category sits on
/// the stack baseline where it stays comparable across buckets.
/// [precomputedDaily] lets the caller share one `dailyTotals` pass across
/// [buildChartData], [buildTableRows], and [buildKpis] — the aggregation
/// is the dominant cost of a page build (measured ~3× redundancy without
/// sharing). Must equal `dailyTotals(buckets, range)` when provided.
InsightsChartData buildChartData(
  InsightsDayBuckets buckets,
  InsightsRange range, {
  List<Map<String?, int>>? precomputedDaily,
}) {
  final granularity = granularityFor(range);

  List<Map<String?, int>> perBucket;
  List<DateTime> bucketStarts;
  var partialFirstBucket = false;
  var partialLastBucket = false;

  switch (granularity) {
    case InsightsGranularity.hour:
      perBucket = hourlyTotals(buckets, range.startDay);
      final start = dayStart(range.startDay);
      bucketStarts = List.generate(
        24,
        (h) => DateTime(start.year, start.month, start.day, h),
      );
    case InsightsGranularity.day:
      perBucket = precomputedDaily ?? dailyTotals(buckets, range);
      bucketStarts = List.generate(
        range.dayCount,
        (i) => dayStart(range.startDay + i),
      );
    case InsightsGranularity.week:
      final daily = precomputedDaily ?? dailyTotals(buckets, range);
      final firstWeek = weekStartDay(range.startDay);
      final lastWeek = weekStartDay(range.endDayExclusive - 1);
      final weekCount = (lastWeek - firstWeek) ~/ 7 + 1;
      perBucket = List.generate(weekCount, (_) => <String?, int>{});
      for (var i = 0; i < daily.length; i++) {
        final week = (weekStartDay(range.startDay + i) - firstWeek) ~/ 7;
        daily[i].forEach((categoryId, seconds) {
          perBucket[week][categoryId] =
              (perBucket[week][categoryId] ?? 0) + seconds;
        });
      }
      // The first week may begin before the range (e.g. YTD starting on a
      // Thursday); clamp its label to the range start so a YTD chart never
      // shows a previous-year date.
      bucketStarts = List.generate(weekCount, (w) {
        final weekStart = firstWeek + w * 7;
        return dayStart(
          weekStart < range.startDay ? range.startDay : weekStart,
        );
      });
      // Truncated edge weeks read as artificial dips; flag them so the
      // tooltip can say "partial week".
      partialFirstBucket = range.startDay > firstWeek;
      partialLastBucket = range.endDayExclusive < lastWeek + 7;
  }

  final ranked = rankedCategoryTotals(perBucket);
  final visible = ranked.take(kInsightsMaxChartSeries).map((e) => e.key);
  final rolledUp = ranked
      .skip(kInsightsMaxChartSeries)
      .map((e) => e.key)
      .toSet();

  final seriesKeys = <String?>[
    ...visible,
    if (rolledUp.isNotEmpty) kInsightsOtherCategoryKey,
  ];

  final values = [
    for (final key in seriesKeys)
      [
        for (final bucket in perBucket)
          key == kInsightsOtherCategoryKey
              ? rolledUp.fold<int>(0, (sum, id) => sum + (bucket[id] ?? 0))
              : bucket[key] ?? 0,
      ],
  ];

  return InsightsChartData(
    granularity: granularity,
    bucketStarts: bucketStarts,
    seriesKeys: seriesKeys,
    values: values,
    rolledUpCount: rolledUp.length,
    partialFirstBucket: partialFirstBucket,
    partialLastBucket: partialLastBucket,
  );
}

/// Running-sum transform of `values[series][bucket]` along buckets.
/// Each output row is monotone non-decreasing.
List<List<int>> accumulate(List<List<int>> values) {
  return [
    for (final row in values)
      () {
        var running = 0;
        return [for (final v in row) running += v];
      }(),
  ];
}

/// Per-category table rows for [range]: union-merged seconds, share of the
/// range total, and average over days **in the range**.
///
/// [precomputedRanked] shares one ranking pass with [buildKpis] (see
/// [buildChartData] for the rationale).
List<InsightsTableRow> buildTableRows(
  InsightsDayBuckets buckets,
  InsightsRange range, {
  List<MapEntry<String?, int>>? precomputedRanked,
}) {
  final ranked =
      precomputedRanked ?? rankedCategoryTotals(dailyTotals(buckets, range));
  final total = ranked.fold<int>(0, (sum, e) => sum + e.value);
  if (total == 0) return const [];
  return [
    for (final entry in ranked)
      InsightsTableRow(
        categoryId: entry.key,
        seconds: entry.value,
        share: entry.value / total,
        avgSecondsPerDay: entry.value ~/ range.dayCount,
      ),
  ];
}

/// KPI totals for [range]. Focus/other stay `null` until [focusCategoryIds]
/// is non-empty so the UI can hide unconfigured tiles instead of rendering
/// dead zeros.
InsightsKpis buildKpis(
  InsightsDayBuckets buckets,
  InsightsRange range, {
  required Set<String> focusCategoryIds,
  List<MapEntry<String?, int>>? precomputedRanked,
}) {
  final ranked =
      precomputedRanked ?? rankedCategoryTotals(dailyTotals(buckets, range));
  final total = ranked.fold<int>(0, (sum, e) => sum + e.value);
  if (focusCategoryIds.isEmpty) {
    return InsightsKpis(
      totalSeconds: total,
      focusSeconds: null,
      otherSeconds: null,
    );
  }
  final focus = ranked
      .where((e) => e.key != null && focusCategoryIds.contains(e.key))
      .fold<int>(0, (sum, e) => sum + e.value);
  return InsightsKpis(
    totalSeconds: total,
    focusSeconds: focus,
    otherSeconds: math.max(0, total - focus),
  );
}
