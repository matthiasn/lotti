import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

/// Smart-folding model for the day timeline: clusters occupied hours into
/// visible regions, folds long empty gaps into collapsible regions, and maps
/// hour values onto pixel offsets that account for collapsed segments.
///
/// Pure math extracted from `day_timeline.dart` so the clustering and
/// position invariants are directly unit/property-testable.
class TimelineFoldingState {
  TimelineFoldingState({
    required this.startHour,
    required this.endHour,
    required this.segments,
  });
  factory TimelineFoldingState.fromBlocks({
    required List<TimeBlock> blocks,
    required DateTime dayDate,
    required int startHour,
    required int endHour,
    required Set<int> expandedRegionStarts,
    required double collapsedHourHeight,
  }) {
    final occupiedHours = <int>{};
    final dayStart = DateTime(dayDate.year, dayDate.month, dayDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    for (final block in blocks) {
      final effectiveStart = block.start.isBefore(dayStart)
          ? dayStart
          : block.start;
      final effectiveEnd = block.end.isAfter(dayEnd) ? dayEnd : block.end;
      if (!effectiveStart.isBefore(effectiveEnd)) continue;

      final start = effectiveStart.hour;
      final end = effectiveEnd == dayEnd
          ? 24
          : effectiveEnd.hour + (effectiveEnd.minute > 0 ? 1 : 0);
      if (start >= endHour || end <= startHour) continue;

      final clampedStart = start.clamp(startHour, endHour - 1);
      final clampedEnd = end.clamp(startHour + 1, endHour);
      for (var hour = clampedStart; hour < clampedEnd; hour++) {
        occupiedHours.add(hour);
      }
    }

    if (occupiedHours.isEmpty) {
      return TimelineFoldingState(
        startHour: startHour,
        endHour: endHour,
        segments: [
          TimelineVisibleRegion(startHour: startHour, endHour: endHour),
        ],
      );
    }

    final sortedHours = occupiedHours.toList()..sort();
    final clusters = <TimelineVisibleRegion>[];
    var clusterStart = sortedHours.first;
    var clusterEnd = clusterStart + 1;

    for (var i = 1; i < sortedHours.length; i++) {
      final hour = sortedHours[i];
      if (hour <= clusterEnd) {
        clusterEnd = hour + 1;
        continue;
      }

      final gap = hour - clusterEnd;
      if (gap >= _gapThresholdHours) {
        clusters.add(
          TimelineVisibleRegion(startHour: clusterStart, endHour: clusterEnd),
        );
        clusterStart = hour;
      }
      clusterEnd = hour + 1;
    }
    clusters.add(
      TimelineVisibleRegion(startHour: clusterStart, endHour: clusterEnd),
    );

    if (clusters.first.startHour - startHour < _gapThresholdHours) {
      clusters[0] = TimelineVisibleRegion(
        startHour: startHour,
        endHour: clusters.first.endHour,
      );
    }

    final lastCluster = clusters.last;
    if (endHour - lastCluster.endHour < _gapThresholdHours) {
      clusters[clusters.length - 1] = TimelineVisibleRegion(
        startHour: lastCluster.startHour,
        endHour: endHour,
      );
    }

    final segments = <TimelineRegion>[];
    var cursor = startHour;
    for (final cluster in clusters) {
      if (cluster.startHour - cursor >= _gapThresholdHours) {
        segments.add(
          TimelineFoldRegion(
            startHour: cursor,
            endHour: cluster.startHour,
            isExpanded: expandedRegionStarts.contains(cursor),
            collapsedHourHeight: collapsedHourHeight,
          ),
        );
      }
      segments.add(cluster);
      cursor = cluster.endHour;
    }

    if (endHour - cursor >= _gapThresholdHours) {
      segments.add(
        TimelineFoldRegion(
          startHour: cursor,
          endHour: endHour,
          isExpanded: expandedRegionStarts.contains(cursor),
          collapsedHourHeight: collapsedHourHeight,
        ),
      );
    }

    return TimelineFoldingState(
      startHour: startHour,
      endHour: endHour,
      segments: segments,
    );
  }

  static const _gapThresholdHours = 4;
  final int startHour;
  final int endHour;
  final List<TimelineRegion> segments;

  Iterable<TimelineFoldRegion> get compressedRegions =>
      segments.whereType<TimelineFoldRegion>();

  List<int> get visibleHourLabels {
    final labels = <int>{};
    for (final segment in segments) {
      if (segment is TimelineFoldRegion && !segment.isExpanded) continue;
      for (var hour = segment.startHour; hour <= segment.endHour; hour++) {
        labels.add(hour);
      }
    }
    return labels.toList()..sort();
  }

  double totalHeight(double pxPerMinute) {
    return segments.fold<double>(
      0,
      (height, segment) => height + segment.height(pxPerMinute),
    );
  }

  double positionForDate(
    DateTime date, {
    required DateTime windowStart,
    required double pxPerMinute,
  }) {
    final rawHour = startHour + date.difference(windowStart).inMinutes / 60.0;
    return positionForHourValue(
      rawHour.clamp(startHour.toDouble(), endHour.toDouble()),
      pxPerMinute,
    );
  }

  double positionForHour(int hour, double pxPerMinute) {
    return positionForHourValue(hour.toDouble(), pxPerMinute);
  }

  double positionForHourValue(double hourValue, double pxPerMinute) {
    var position = 0.0;
    for (final segment in segments) {
      if (hourValue <= segment.startHour) return position;
      if (hourValue <= segment.endHour) {
        final hoursIntoSegment = hourValue - segment.startHour;
        return position + segment.hourHeight(pxPerMinute) * hoursIntoSegment;
      }
      position += segment.height(pxPerMinute);
    }
    return position;
  }
}

sealed class TimelineRegion {
  const TimelineRegion({
    required this.startHour,
    required this.endHour,
  });

  final int startHour;
  final int endHour;

  int get hourCount => endHour - startHour;

  double hourHeight(double pxPerMinute);

  double height(double pxPerMinute) => hourCount * hourHeight(pxPerMinute);
}

class TimelineVisibleRegion extends TimelineRegion {
  const TimelineVisibleRegion({
    required super.startHour,
    required super.endHour,
  });

  @override
  double hourHeight(double pxPerMinute) => 60 * pxPerMinute;
}

class TimelineFoldRegion extends TimelineRegion {
  const TimelineFoldRegion({
    required super.startHour,
    required super.endHour,
    required this.isExpanded,
    required this.collapsedHourHeight,
  });

  final bool isExpanded;
  final double collapsedHourHeight;

  @override
  double hourHeight(double pxPerMinute) =>
      isExpanded ? 60 * pxPerMinute : collapsedHourHeight;
}
