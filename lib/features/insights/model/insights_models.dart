import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Sentinel category key used for the "Other" rollup series in charts.
///
/// Real category ids are UUIDs, so this sentinel cannot collide with them.
/// Uncategorized time keeps the `null` key, mirroring the convention used
/// by the Daily OS time history aggregation.
const String kInsightsOtherCategoryKey = '__insights_other__';

const DeepCollectionEquality _deepEquality = DeepCollectionEquality();

/// A slim time row read from the journal table: just the absolute time span
/// and the resolved category id (`null` = uncategorized).
///
/// Deliberately excludes the `serialized` JSON payload — reading and
/// deserializing full `JournalEntity` rows is what would blow the
/// sub-200ms budget at 10k+ entries, not SQLite itself.
@immutable
class InsightsTimeRow {
  const InsightsTimeRow({
    required this.dateFrom,
    required this.dateTo,
    required this.categoryId,
  });

  /// Start of the time span (local time, converted from epoch storage).
  final DateTime dateFrom;

  /// End of the time span (local time, converted from epoch storage).
  final DateTime dateTo;

  /// Resolved category id; `null` when uncategorized.
  final String? categoryId;

  @override
  bool operator ==(Object other) =>
      other is InsightsTimeRow &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(dateFrom, dateTo, categoryId);

  @override
  String toString() => 'InsightsTimeRow($dateFrom → $dateTo, $categoryId)';
}

/// A half-open absolute time interval `[start, end)`.
@immutable
class TimeInterval {
  const TimeInterval(this.start, this.end)
    : assert(!(start == end), 'TimeInterval must not be empty');

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  @override
  bool operator ==(Object other) =>
      other is TimeInterval && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TimeInterval($start → $end)';
}

/// Merged, non-overlapping intervals plus their total length for one
/// (day, category) cell.
@immutable
class InsightsDayCell {
  const InsightsDayCell({required this.seconds, required this.intervals});

  /// Union length of [intervals] in seconds. Overlapping entries within the
  /// same category are merged, so parallel timers do not double-count.
  final int seconds;

  /// Merged, chronologically sorted intervals. Kept so the hourly (1d) view
  /// can re-bucket without another database round trip.
  final List<TimeInterval> intervals;

  @override
  bool operator ==(Object other) =>
      other is InsightsDayCell &&
      other.seconds == seconds &&
      _deepEquality.equals(other.intervals, intervals);

  @override
  int get hashCode => Object.hash(seconds, _deepEquality.hash(intervals));
}

/// Bucketized time data for one contiguous loaded window of local days.
///
/// Keys of [days] are epoch-day indices (see `epochDay` in
/// `time_bucketing.dart`); inner keys are category ids with `null` for
/// uncategorized. Value equality is deep so an unchanged background refetch
/// short-circuits provider rebuilds (no UI flash).
@immutable
class InsightsDayBuckets {
  const InsightsDayBuckets({required this.windowStartDay, required this.days});

  static const InsightsDayBuckets empty = InsightsDayBuckets(
    windowStartDay: 0,
    days: <int, Map<String?, InsightsDayCell>>{},
  );

  /// First epoch day covered by the loaded window (inclusive).
  final int windowStartDay;

  /// epochDay → categoryId → merged cell. Days without data are absent.
  final Map<int, Map<String?, InsightsDayCell>> days;

  @override
  bool operator ==(Object other) =>
      other is InsightsDayBuckets &&
      other.windowStartDay == windowStartDay &&
      _deepEquality.equals(other.days, days);

  @override
  int get hashCode => Object.hash(windowStartDay, _deepEquality.hash(days));
}

/// Quick-access range presets, mirroring the Cursor usage dashboard.
enum InsightsRangePreset { d1, d7, d30, mtd, ytd, lastMonth }

/// A resolved, day-aligned analysis range `[startDay, endDayExclusive)`.
@immutable
class InsightsRange {
  const InsightsRange({
    required this.startDay,
    required this.endDayExclusive,
    this.preset,
  }) : assert(startDay < endDayExclusive, 'range must span at least one day');

  /// First epoch day of the range (inclusive).
  final int startDay;

  /// Epoch day after the last included day (exclusive).
  final int endDayExclusive;

  /// The preset this range was resolved from; `null` for custom ranges.
  final InsightsRangePreset? preset;

  int get dayCount => endDayExclusive - startDay;

  @override
  bool operator ==(Object other) =>
      other is InsightsRange &&
      other.startDay == startDay &&
      other.endDayExclusive == endDayExclusive &&
      other.preset == preset;

  @override
  int get hashCode => Object.hash(startDay, endDayExclusive, preset);

  @override
  String toString() =>
      'InsightsRange($startDay..<$endDayExclusive, preset: $preset)';
}

/// X-axis granularity for the chart, derived from the range length.
enum InsightsGranularity { hour, day, week }

/// Chart-ready stacked series for the selected range.
///
/// [seriesKeys] are ordered bottom-to-top of the stack (largest total
/// first); values may include [kInsightsOtherCategoryKey] and `null`
/// (uncategorized). `values[seriesIndex][bucketIndex]` is seconds.
@immutable
class InsightsChartData {
  const InsightsChartData({
    required this.granularity,
    required this.bucketStarts,
    required this.seriesKeys,
    required this.values,
    this.rolledUpCount = 0,
    this.partialFirstBucket = false,
    this.partialLastBucket = false,
  });

  static const InsightsChartData empty = InsightsChartData(
    granularity: InsightsGranularity.day,
    bucketStarts: <DateTime>[],
    seriesKeys: <String?>[],
    values: <List<int>>[],
  );

  final InsightsGranularity granularity;

  /// Local start time of each x bucket (hour, day, or week start).
  final List<DateTime> bucketStarts;

  /// Stacking order, bottom of stack first.
  final List<String?> seriesKeys;

  /// Seconds per series per bucket: `values[series][bucket]`.
  final List<List<int>> values;

  /// How many categories were rolled into [kInsightsOtherCategoryKey] —
  /// surfaced in the legend so the chart and the exhaustive table tell
  /// the same story.
  final int rolledUpCount;

  /// Whether the first/last weekly bucket is truncated by the range (e.g.
  /// YTD starting mid-week) — flagged in tooltips so shorter edge bars
  /// aren't misread as low-activity weeks.
  final bool partialFirstBucket;
  final bool partialLastBucket;

  bool get isEmpty =>
      values.isEmpty || values.every((row) => row.every((v) => v == 0));

  @override
  bool operator ==(Object other) =>
      other is InsightsChartData &&
      other.granularity == granularity &&
      other.rolledUpCount == rolledUpCount &&
      other.partialFirstBucket == partialFirstBucket &&
      other.partialLastBucket == partialLastBucket &&
      _deepEquality.equals(other.bucketStarts, bucketStarts) &&
      _deepEquality.equals(other.seriesKeys, seriesKeys) &&
      _deepEquality.equals(other.values, values);

  @override
  int get hashCode => Object.hash(
    granularity,
    rolledUpCount,
    partialFirstBucket,
    partialLastBucket,
    _deepEquality.hash(bucketStarts),
    _deepEquality.hash(seriesKeys),
    _deepEquality.hash(values),
  );
}

/// One row of the per-category breakdown table.
@immutable
class InsightsTableRow {
  const InsightsTableRow({
    required this.categoryId,
    required this.seconds,
    required this.share,
    required this.avgSecondsPerDay,
  });

  /// Category id; `null` for uncategorized.
  final String? categoryId;

  /// Union-merged seconds for this category within the range.
  final int seconds;

  /// Fraction of the range total, in `[0, 1]`.
  final double share;

  /// Average over days **in the range** (not days with data), so the
  /// number answers "typical daily load", consistently across ranges.
  final int avgSecondsPerDay;

  @override
  bool operator ==(Object other) =>
      other is InsightsTableRow &&
      other.categoryId == categoryId &&
      other.seconds == seconds &&
      other.share == share &&
      other.avgSecondsPerDay == avgSecondsPerDay;

  @override
  int get hashCode => Object.hash(categoryId, seconds, share, avgSecondsPerDay);
}

/// Headline numbers for the KPI tiles.
///
/// [focusSeconds]/[otherSeconds] are `null` until the user has configured
/// focus categories — the UI hides those tiles rather than showing dead
/// zeros.
@immutable
class InsightsKpis {
  const InsightsKpis({
    required this.totalSeconds,
    required this.focusSeconds,
    required this.otherSeconds,
  });

  final int totalSeconds;
  final int? focusSeconds;
  final int? otherSeconds;

  @override
  bool operator ==(Object other) =>
      other is InsightsKpis &&
      other.totalSeconds == totalSeconds &&
      other.focusSeconds == focusSeconds &&
      other.otherSeconds == otherSeconds;

  @override
  int get hashCode => Object.hash(totalSeconds, focusSeconds, otherSeconds);
}
