import 'package:flutter/foundation.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';

/// Minimum gap (in hours) between entry clusters to trigger compression.
const int kDefaultGapThreshold = 4;

/// Hours of padding around each entry to keep visible.
const int kDefaultBufferHours = 1;

/// Default start hour when no entries exist (6 AM).
const int kDefaultDayStart = 6;

/// Default end hour when no entries exist (10 PM).
const int kDefaultDayEnd = 22;

/// Height per hour in visible (uncompressed) regions.
const double kNormalHourHeight = 40;

/// Height per hour in compressed regions.
const double kCompressedHourHeight = 8;

/// Represents a time range that should remain visible (not compressed).
@immutable
class VisibleCluster {
  const VisibleCluster({
    required this.startHour,
    required this.endHour,
  });

  /// Inclusive start hour.
  final int startHour;

  /// Exclusive end hour.
  final int endHour;

  /// Number of hours in this cluster.
  int get hourCount => endHour - startHour;

  @override
  String toString() => 'VisibleCluster($startHour-$endHour)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisibleCluster &&
          runtimeType == other.runtimeType &&
          startHour == other.startHour &&
          endHour == other.endHour;

  @override
  int get hashCode => startHour.hashCode ^ endHour.hashCode;
}

/// Represents a compressed time range between visible clusters.
@immutable
class CompressedRegion {
  const CompressedRegion({
    required this.startHour,
    required this.endHour,
  });

  /// Inclusive start hour.
  final int startHour;

  /// Exclusive end hour.
  final int endHour;

  /// Number of hours in this region.
  int get hourCount => endHour - startHour;

  @override
  String toString() => 'CompressedRegion($startHour-$endHour)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompressedRegion &&
          runtimeType == other.runtimeType &&
          startHour == other.startHour &&
          endHour == other.endHour;

  @override
  int get hashCode => startHour.hashCode ^ endHour.hashCode;
}

/// Complete folding state for a day's timeline.
class TimelineFoldingState {
  const TimelineFoldingState({
    required this.visibleClusters,
    required this.compressedRegions,
  });

  /// List of visible (uncompressed) time clusters.
  final List<VisibleCluster> visibleClusters;

  /// List of compressed (foldable) time regions.
  final List<CompressedRegion> compressedRegions;

  /// Whether the timeline has any compressed regions.
  bool get hasCompressedRegions => compressedRegions.isNotEmpty;

  @override
  String toString() =>
      'TimelineFoldingState(visible: $visibleClusters, compressed: $compressedRegions)';
}

/// Calculates the folding state for a day's timeline.
///
/// This algorithm identifies "visible clusters" (hours with activity) and
/// compresses gaps between them when those gaps exceed [gapThreshold] hours.
///
/// Parameters:
/// - [plannedSlots]: Planned time blocks from the day plan.
/// - [actualSlots]: Actual recorded time entries.
/// - [gapThreshold]: Minimum hours between clusters to trigger compression.
/// - [bufferHours]: Hours of padding around each entry to keep visible.
/// - [defaultDayStart]: Start hour when no entries exist (default 6 AM).
/// - [defaultDayEnd]: End hour when no entries exist (default 10 PM).
TimelineFoldingState calculateFoldingState({
  required List<PlannedTimeSlot> plannedSlots,
  required List<ActualTimeSlot> actualSlots,
  int gapThreshold = kDefaultGapThreshold,
  int bufferHours = kDefaultBufferHours,
  int defaultDayStart = kDefaultDayStart,
  int defaultDayEnd = kDefaultDayEnd,
}) {
  // Step 1: Collect all entry hours with buffer
  final occupiedHours = <int>{};

  for (final slot in [...plannedSlots, ...actualSlots]) {
    final startHour = slot.startTime.hour;

    // Handle entries that cross midnight (endTime is on a different day)
    // For such entries, clamp to end of day (24) for this day's timeline
    final crossesMidnight = !_isSameDay(slot.startTime, slot.endTime);
    final rawEndHour = slot.endTime.hour + (slot.endTime.minute > 0 ? 1 : 0);
    final endHour = crossesMidnight ? 24 : rawEndHour;

    // Add buffer
    final bufferedStart = (startHour - bufferHours).clamp(0, 23);
    final bufferedEnd = (endHour + bufferHours).clamp(1, 24);

    for (var h = bufferedStart; h < bufferedEnd; h++) {
      occupiedHours.add(h);
    }
  }

  // Step 2: If no entries, use default day bounds
  if (occupiedHours.isEmpty) {
    return TimelineFoldingState(
      visibleClusters: [
        VisibleCluster(startHour: defaultDayStart, endHour: defaultDayEnd),
      ],
      compressedRegions: [
        if (defaultDayStart > 0)
          CompressedRegion(startHour: 0, endHour: defaultDayStart),
        if (defaultDayEnd < 24)
          CompressedRegion(startHour: defaultDayEnd, endHour: 24),
      ],
    );
  }

  // Step 3: Build visible clusters from occupied hours
  final sortedHours = occupiedHours.toList()..sort();
  final clusters = <VisibleCluster>[];

  var clusterStart = sortedHours.first;
  var clusterEnd = clusterStart + 1;

  for (var i = 1; i < sortedHours.length; i++) {
    final hour = sortedHours[i];
    if (hour <= clusterEnd) {
      // Extend current cluster
      clusterEnd = hour + 1;
    } else {
      // Check if gap is large enough to compress
      final gap = hour - clusterEnd;
      if (gap >= gapThreshold) {
        // Finalize current cluster, start new one
        clusters
            .add(VisibleCluster(startHour: clusterStart, endHour: clusterEnd));
        clusterStart = hour;
      }
      // If gap is small, just extend the cluster to include this hour
      clusterEnd = hour + 1;
    }
  }
  // Add final cluster
  clusters.add(VisibleCluster(startHour: clusterStart, endHour: clusterEnd));

  // Step 4: Identify compressed regions (gaps >= threshold)
  final compressed = <CompressedRegion>[];

  // Before first cluster (if gap is large enough)
  final firstCluster = clusters.first;
  if (firstCluster.startHour >= gapThreshold) {
    compressed.add(
      CompressedRegion(startHour: 0, endHour: firstCluster.startHour),
    );
  } else if (firstCluster.startHour > 0) {
    // Extend first cluster to start of day if gap is small
    clusters[0] = VisibleCluster(startHour: 0, endHour: firstCluster.endHour);
  }

  // Between clusters
  for (var i = 0; i < clusters.length - 1; i++) {
    final currentCluster = clusters[i];
    final nextCluster = clusters[i + 1];
    final gap = nextCluster.startHour - currentCluster.endHour;

    if (gap >= gapThreshold) {
      compressed.add(
        CompressedRegion(
          startHour: currentCluster.endHour,
          endHour: nextCluster.startHour,
        ),
      );
    }
  }

  // After last cluster (if gap is large enough)
  final lastCluster = clusters.last;
  final endGap = 24 - lastCluster.endHour;
  if (endGap >= gapThreshold) {
    compressed.add(
      CompressedRegion(startHour: lastCluster.endHour, endHour: 24),
    );
  } else if (lastCluster.endHour < 24) {
    // Extend last cluster to end of day if gap is small
    clusters[clusters.length - 1] = VisibleCluster(
      startHour: lastCluster.startHour,
      endHour: 24,
    );
  }

  return TimelineFoldingState(
    visibleClusters: clusters,
    compressedRegions: compressed,
  );
}

/// Calculates the pixel height for a timeline with folding applied.
///
/// Parameters:
/// - [foldingState]: The calculated folding state.
/// - [expandedRegions]: Set of startHour values for regions that are expanded.
/// - [normalHourHeight]: Height in pixels for normal (visible) hours.
/// - [compressedHourHeight]: Height in pixels for compressed hours.
double calculateFoldedTimelineHeight({
  required TimelineFoldingState foldingState,
  required Set<int> expandedRegions,
  double normalHourHeight = kNormalHourHeight,
  double compressedHourHeight = kCompressedHourHeight,
}) {
  var totalHeight = 0.0;

  // Add height for visible clusters
  for (final cluster in foldingState.visibleClusters) {
    totalHeight += cluster.hourCount * normalHourHeight;
  }

  // Add height for compressed regions (expanded or collapsed)
  for (final region in foldingState.compressedRegions) {
    final isExpanded = expandedRegions.contains(region.startHour);
    if (isExpanded) {
      totalHeight += region.hourCount * normalHourHeight;
    } else {
      totalHeight += region.hourCount * compressedHourHeight;
    }
  }

  return totalHeight;
}

/// Converts a time (hour + fractional minutes) to a Y position in the folded timeline.
///
/// Parameters:
/// - [hour]: The hour to convert.
/// - [minute]: The minute within the hour.
/// - [foldingState]: The calculated folding state.
/// - [expandedRegions]: Set of startHour values for regions that are expanded.
/// - [normalHourHeight]: Height in pixels for normal (visible) hours.
/// - [compressedHourHeight]: Height in pixels for compressed hours.
double timeToFoldedPosition({
  required int hour,
  required int minute,
  required TimelineFoldingState foldingState,
  required Set<int> expandedRegions,
  double normalHourHeight = kNormalHourHeight,
  double compressedHourHeight = kCompressedHourHeight,
}) {
  var position = 0.0;
  final timeInHours = hour + minute / 60.0;

  // Combine visible clusters and compressed regions, sorted by start hour
  final allRegions = <({int startHour, int endHour, bool isCompressed})>[];

  for (final cluster in foldingState.visibleClusters) {
    allRegions.add((
      startHour: cluster.startHour,
      endHour: cluster.endHour,
      isCompressed: false,
    ));
  }

  for (final region in foldingState.compressedRegions) {
    final isExpanded = expandedRegions.contains(region.startHour);
    allRegions.add((
      startHour: region.startHour,
      endHour: region.endHour,
      isCompressed: !isExpanded,
    ));
  }

  allRegions.sort((a, b) => a.startHour.compareTo(b.startHour));

  for (final region in allRegions) {
    final hourHeight =
        region.isCompressed ? compressedHourHeight : normalHourHeight;

    if (timeInHours < region.startHour) {
      // Time is before this region - shouldn't happen in a valid timeline
      break;
    } else if (timeInHours <= region.endHour) {
      // Time is within this region
      final hoursIntoRegion = timeInHours - region.startHour;
      position += hoursIntoRegion * hourHeight;
      break;
    } else {
      // Time is after this region
      final regionHours = region.endHour - region.startHour;
      position += regionHours * hourHeight;
    }
  }

  return position;
}

/// Checks if a given hour is within a compressed (and not expanded) region.
bool isHourInCompressedRegion({
  required int hour,
  required TimelineFoldingState foldingState,
  required Set<int> expandedRegions,
}) {
  for (final region in foldingState.compressedRegions) {
    if (hour >= region.startHour && hour < region.endHour) {
      return !expandedRegions.contains(region.startHour);
    }
  }
  return false;
}

/// Checks if two DateTimes are on the same calendar day.
bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
