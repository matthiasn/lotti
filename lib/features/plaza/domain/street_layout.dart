/// Deterministic, merge-stable street layout for the project plaza.
///
/// Pure Dart, no Flutter dependency.
///
/// Placement must survive sync: Lotti is local-first with concurrent task
/// creation on multiple devices, so there is no global creation order.
/// Placement is therefore a pure function of data that merges identically
/// everywhere — `createdAt`, with `id` as tiebreak — bucketed by week:
///
/// - One bucket = one week of the project's life; one plot group per bucket.
/// - Within a bucket, tasks subdivide the plot group ordered by
///   `(createdAt, id)`, alternating sides.
/// - A late-syncing task can only jostle its siblings inside one bucket —
///   a bounded blast radius of a single plot group, never the street.
/// - Empty weeks collapse to a short gap: a visible pause, not a hike.
///   (Known edge: a task syncing into a previously *empty* week widens that
///   gap into a plot group and shifts everything downstream. Accepted for
///   the prototype; the M2 invariant test documents it.)
/// - The road's course (bends) is a function of the project seed and the
///   bucket index alone, never of task data.
library;

import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/plaza_task.dart';

/// Stable 32-bit FNV-1a hash of [input].
///
/// `String.hashCode` is not guaranteed stable across VM versions, and plot
/// rhythm must never change under the user's feet, so we hash explicitly.
int stableHash(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Which side of the road a plot sits on.
enum PlotSide { left, right }

/// A placed plot: world-space position and orientation for one task.
class PlotPlacement {
  const PlotPlacement({
    required this.taskId,
    required this.bucketIndex,
    required this.side,
    required this.x,
    required this.z,
    required this.facingRadians,
    required this.width,
    required this.depth,
    required this.height,
  });

  final String taskId;

  /// The week bucket (plot group) this task belongs to.
  final int bucketIndex;

  final PlotSide side;

  /// Plot center, world space (y is always ground level).
  final double x;
  final double z;

  /// Rotation about +Y such that the facade faces the road.
  final double facingRadians;

  /// Building footprint along the road.
  final double width;

  /// Building footprint away from the road.
  final double depth;

  /// Building height. Deterministic per task id, surface-independent.
  final double height;
}

/// One straight run of road: a plot group (week) or a collapsed gap.
class RoadSegment {
  const RoadSegment({
    required this.bucketIndex,
    required this.startX,
    required this.startZ,
    required this.headingRadians,
    required this.length,
    required this.isGap,
  });

  final int bucketIndex;
  final double startX;
  final double startZ;

  /// Direction of travel, radians about +Y (0 = +Z).
  final double headingRadians;
  final double length;

  /// True for a collapsed empty week.
  final bool isGap;
}

/// The output of [StreetLayout.plan].
class StreetPlan {
  const StreetPlan({
    required this.epoch,
    required this.segments,
    required this.placements,
  });

  /// Start of week zero.
  final DateTime epoch;

  /// One segment per week bucket, in order, gaps included.
  final List<RoadSegment> segments;

  /// One placement per (non-filtered) task, keyed by task id.
  final Map<String, PlotPlacement> placements;
}

/// Lays out the street. All knobs are deterministic tuning inputs; nothing
/// here consults wall-clock time or unseeded randomness.
class StreetLayout {
  StreetLayout({
    required this.projectSeed,
    this.roadWidth = 8,
    this.groupLength = 46,
    this.gapLength = 7,
    this.plotDepth = 8,
    this.sideMargin = 2,
    this.minBuildingWidth = 2.5,
    this.maxBuildingWidth = 12,
    this.bendEveryBuckets = 3,
    this.maxBendRadians = math.pi / 5,
  });

  final int projectSeed;
  final double roadWidth;

  /// Road length one non-empty week occupies.
  final double groupLength;

  /// Road length a collapsed empty week occupies.
  final double gapLength;

  final double plotDepth;

  /// Unbuilt strip at each end of a plot group, per side.
  final double sideMargin;

  /// Buildings never get thinner than this, however busy the week.
  final double minBuildingWidth;

  /// Nor wider than this, however quiet.
  final double maxBuildingWidth;

  /// Roughly every Nth bucket boundary bends the road (hash-decided).
  final int bendEveryBuckets;
  final double maxBendRadians;

  /// Deterministic relative width factor for a task id (0.5 .. 1.5).
  double widthFactorFor(String taskId) {
    final t = (stableHash(taskId) & 0xFFFF) / 0xFFFF;
    return 0.5 + t;
  }

  /// Deterministic building height for a task id (independent of state).
  double heightFor(String taskId) {
    final t = ((stableHash(taskId) >> 16) & 0xFFFF) / 0xFFFF;
    return 3.0 + 5.0 * t * t;
  }

  /// Start of the week containing [time] (Monday 00:00).
  static DateTime weekStart(DateTime time) {
    final day = DateTime(time.year, time.month, time.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// The signed bend applied *after* bucket [bucketIndex], purely from the
  /// project seed and the bucket index.
  double bendAfter(int bucketIndex) {
    final roll = stableHash('$projectSeed:bend:$bucketIndex');
    if (roll % bendEveryBuckets != 0) return 0;
    final t = ((roll >> 8) & 0xFFFF) / 0xFFFF;
    return (t * 2 - 1) * maxBendRadians;
  }

  /// Plans the street for [tasks].
  ///
  /// [epoch] anchors week zero; it defaults to the Monday of the earliest
  /// `createdAt`. Pass a fixed project epoch when one exists — the default
  /// shifts if a task older than all known ones syncs in.
  ///
  /// Input order is irrelevant: tasks are sorted by `(createdAt, id)`
  /// internally, so shuffled arrival produces an identical street.
  StreetPlan plan(List<PlazaTask> tasks, {DateTime? epoch}) {
    if (tasks.isEmpty) {
      return StreetPlan(
        epoch: epoch ?? DateTime(2000),
        segments: const [],
        placements: const {},
      );
    }

    final ordered = [...tasks]
      ..sort((a, b) {
        final byDate = a.createdAt.compareTo(b.createdAt);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });

    final anchor = epoch ?? weekStart(ordered.first.createdAt);

    int bucketOf(PlazaTask task) =>
        task.createdAt.difference(anchor).inDays ~/ 7;

    final byBucket = <int, List<PlazaTask>>{};
    for (final task in ordered) {
      byBucket.putIfAbsent(bucketOf(task), () => []).add(task);
    }
    final lastBucket = byBucket.keys.reduce(math.max);

    final segments = <RoadSegment>[];
    final placements = <String, PlotPlacement>{};

    var x = 0.0;
    var z = 0.0;
    var heading = 0.0; // Start heading +Z.

    for (var bucket = 0; bucket <= lastBucket; bucket++) {
      final weekTasks = byBucket[bucket];
      final isGap = weekTasks == null;
      final length = isGap ? gapLength : groupLength;

      segments.add(
        RoadSegment(
          bucketIndex: bucket,
          startX: x,
          startZ: z,
          headingRadians: heading,
          length: length,
          isGap: isGap,
        ),
      );

      if (weekTasks != null) {
        _placeBucket(
          weekTasks,
          bucket: bucket,
          startX: x,
          startZ: z,
          heading: heading,
          into: placements,
        );
      }

      x += math.sin(heading) * length;
      z += math.cos(heading) * length;
      heading += bendAfter(bucket);
    }

    return StreetPlan(
      epoch: anchor,
      segments: segments,
      placements: placements,
    );
  }

  void _placeBucket(
    List<PlazaTask> weekTasks, {
    required int bucket,
    required double startX,
    required double startZ,
    required double heading,
    required Map<String, PlotPlacement> into,
  }) {
    final sinH = math.sin(heading);
    final cosH = math.cos(heading);
    final usable = groupLength - 2 * sideMargin;

    for (final side in PlotSide.values) {
      final sideTasks = <PlazaTask>[
        for (var i = 0; i < weekTasks.length; i++)
          if ((i.isEven) == (side == PlotSide.left)) weekTasks[i],
      ];
      if (sideTasks.isEmpty) continue;

      final weights = [for (final t in sideTasks) widthFactorFor(t.id)];
      final totalWeight = weights.reduce((a, b) => a + b);

      var cursor = sideMargin;
      for (var i = 0; i < sideTasks.length; i++) {
        final task = sideTasks[i];
        final slot = usable * weights[i] / totalWeight;
        final centerAlong = cursor + slot / 2;
        final buildingWidth = (slot * 0.82).clamp(
          minBuildingWidth,
          maxBuildingWidth,
        );

        final sideSign = side == PlotSide.left ? -1.0 : 1.0;
        final lateral = sideSign * (roadWidth / 2 + plotDepth / 2);
        // Lateral axis is the road's right-hand normal.
        into[task.id] = PlotPlacement(
          taskId: task.id,
          bucketIndex: bucket,
          side: side,
          x: startX + sinH * centerAlong + cosH * lateral,
          z: startZ + cosH * centerAlong - sinH * lateral,
          // Facade faces the road.
          facingRadians:
              heading + (side == PlotSide.left ? math.pi / 2 : -math.pi / 2),
          width: buildingWidth,
          depth: plotDepth * 0.8,
          height: heightFor(task.id),
        );
        cursor += slot;
      }
    }
  }
}
