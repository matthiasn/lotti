import 'package:flutter/foundation.dart' show immutable;

/// Represents a time range with a start and end time.
@immutable
class TimeRange {
  const TimeRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  /// Returns true if this range overlaps with [other].
  ///
  /// Two ranges overlap if they share any common time, including touching
  /// at endpoints (to allow merging adjacent ranges).
  bool overlaps(TimeRange other) {
    return !end.isBefore(other.start) && !other.end.isBefore(start);
  }

  /// Merges this range with [other], returning a new range that covers both.
  ///
  /// Should only be called when the ranges overlap (or are adjacent).
  TimeRange merge(TimeRange other) {
    return TimeRange(
      start: start.isBefore(other.start) ? start : other.start,
      end: end.isAfter(other.end) ? end : other.end,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TimeRange($start - $end)';
}

/// Calculates the union of overlapping time ranges.
///
/// Given a list of potentially overlapping ranges, returns a list of
/// non-overlapping ranges that cover the same total time span.
///
/// Example:
/// ```text
/// Input:   |======| |====|  |======|
///                    |====|
/// Output:  |======| |=========|
/// ```
///
/// The algorithm:
/// 1. Sort ranges by start time
/// 2. Iterate through ranges, merging any that overlap with the current range
/// 3. When a gap is found, start a new merged range
List<TimeRange> mergeOverlappingRanges(List<TimeRange> ranges) {
  if (ranges.isEmpty) return [];
  if (ranges.length == 1) return ranges;

  // Sort by start time
  final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));

  final merged = <TimeRange>[];
  var current = sorted.first;

  for (var i = 1; i < sorted.length; i++) {
    final next = sorted[i];

    if (current.overlaps(next)) {
      // Ranges overlap or touch - merge them
      current = current.merge(next);
    } else {
      // Gap found - save current and start new
      merged.add(current);
      current = next;
    }
  }

  // Don't forget the last range
  merged.add(current);

  return merged;
}

/// Calculates the total duration covered by a list of potentially overlapping
/// time ranges, without double-counting overlapping portions.
///
/// This is the core function for preventing double-counting of overlapping
/// time entries within the same category.
Duration calculateUnionDuration(List<TimeRange> ranges) {
  if (ranges.isEmpty) return Duration.zero;

  final merged = mergeOverlappingRanges(ranges);
  return merged.fold(
    Duration.zero,
    (total, range) => total + range.duration,
  );
}
