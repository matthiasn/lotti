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
/// - The road folds into a district: after every [StreetLayout.foldEvery]
///   buckets it turns 90°, runs a connector, and turns 90° again, so rows
///   alternate direction (a serpentine) and a long project becomes a
///   compact block of rows instead of a kilometres-long line. The fold is a
///   function of the bucket index alone, never of task data.
/// - Building height is weight, not verbosity: priority times the log of
///   how connected and how open the task is (see [StreetLayout.heightFor]).
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

/// Deterministic 0..1 from an [id] and a [salt]: seeded variation (massing,
/// tile offsets, set dressing) that must never move under the user's feet.
double stableUnit(String id, String salt) =>
    (stableHash('$id:$salt') & 0xFFFF) / 0xFFFF;

/// A solid's rectangle on the ground: centre, rotation about +Y, and the
/// extents along its local X ([width]) and local Z ([depth]). Everything
/// the scene builds on the ground has one, and the walker collider keeps
/// the camera out of all of them.
class Footprint {
  const Footprint({
    required this.x,
    required this.z,
    required this.facingRadians,
    required this.width,
    required this.depth,
  });

  final double x;
  final double z;

  /// Rotation about +Y: the local Z axis points along
  /// `(sin facing, cos facing)` in the world, local X along
  /// `(cos facing, -sin facing)`.
  final double facingRadians;

  /// Extent along local X.
  final double width;

  /// Extent along local Z.
  final double depth;

  /// The point in this footprint's frame: `u` along local X (the width),
  /// `v` along local Z (the depth), both from the centre.
  (double, double) local(double x, double z) {
    final sinF = math.sin(facingRadians);
    final cosF = math.cos(facingRadians);
    final dx = x - this.x;
    final dz = z - this.z;
    return (dx * cosF - dz * sinF, dx * sinF + dz * cosF);
  }

  /// The interval this footprint covers along the world axis ([ax], [az]).
  (double, double) _projection(double ax, double az) {
    final sinF = math.sin(facingRadians);
    final cosF = math.cos(facingRadians);
    final centre = x * ax + z * az;
    final half =
        (ax * cosF - az * sinF).abs() * width / 2 +
        (ax * sinF + az * cosF).abs() * depth / 2;
    return (centre - half, centre + half);
  }
}

/// Whether two footprints overlap on the ground: a separating-axis test on
/// the four edge normals. Touching edges do not count.
bool footprintsOverlap(Footprint a, Footprint b) {
  for (final box in [a, b]) {
    final sinF = math.sin(box.facingRadians);
    final cosF = math.cos(box.facingRadians);
    // The box's own axes: local X, then local Z.
    for (final (ax, az) in [(cosF, -sinF), (sinF, cosF)]) {
      final (aMin, aMax) = a._projection(ax, az);
      final (bMin, bMax) = b._projection(ax, az);
      if (aMax <= bMin || bMax <= aMin) return false;
    }
  }
  return true;
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

  /// Building height, world meters: weight-driven (see
  /// [StreetLayout.heightFor]).
  final double height;

  /// The plot's rectangle on the ground.
  Footprint get footprint => Footprint(
    x: x,
    z: z,
    facingRadians: facingRadians,
    width: width,
    depth: depth,
  );
}

/// One straight run of road: a plot group (week), a collapsed gap, or a
/// fold connector between two rows.
class RoadSegment {
  const RoadSegment({
    required this.bucketIndex,
    required this.startX,
    required this.startZ,
    required this.headingRadians,
    required this.length,
    required this.isGap,
    this.isConnector = false,
  });

  /// The week bucket, or the bucket the connector follows.
  final int bucketIndex;
  final double startX;
  final double startZ;

  /// Direction of travel, radians about +Y (0 = +Z).
  final double headingRadians;
  final double length;

  /// True for a collapsed empty week.
  final bool isGap;

  /// True for the road between two rows of the fold; carries no buildings.
  final bool isConnector;

  /// World position of the far end of the segment.
  double get endX => startX + math.sin(headingRadians) * length;
  double get endZ => startZ + math.cos(headingRadians) * length;
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

  /// One segment per week bucket, in order, gaps and fold connectors
  /// included.
  final List<RoadSegment> segments;

  /// Where the street ends: the far end of the newest segment, and the
  /// heading it was travelling. The frontier plaza opens here.
  RoadSegment? get last => segments.isEmpty ? null : segments.last;

  /// One placement per (non-filtered) task, keyed by task id.
  final Map<String, PlotPlacement> placements;
}

/// Lays out the street. All knobs are deterministic tuning inputs; nothing
/// here consults wall-clock time or unseeded randomness.
class StreetLayout {
  StreetLayout({
    required this.projectSeed,
    this.roadWidth = 18,
    this.pxPerMeter = 90,
    this.maxBuildingHeight = 32,
    this.groupLength = 40,
    this.gapLength = 4,
    this.plotDepth = 10,
    this.sideMargin = 1.5,
    this.minBuildingWidth = 2.5,
    this.maxBuildingWidth = 18,
    this.foldEvery = 4,
    this.connectorLength = 44,
    this.minBuildingHeight = 6,
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

  /// The street turns back on itself after this many buckets (built or
  /// gap), so a district is rows of at most this many weeks.
  final int foldEvery;

  /// Road length of the connector between two rows; must clear both rows'
  /// plots (road width plus a plot depth on each side).
  final double connectorLength;

  /// The shortest building: a task with nothing linked and nothing open.
  final double minBuildingHeight;

  /// Deterministic relative width factor for a task id (0.5 .. 1.5).
  double widthFactorFor(String taskId) {
    final t = (stableHash(taskId) & 0xFFFF) / 0xFFFF;
    return 0.5 + t;
  }

  /// Logical pixels per world meter on a facade texture. The scene layer
  /// sizes facade widget subtrees with the same value.
  final double pxPerMeter;

  /// Cap on building height, world meters.
  final double maxBuildingHeight;

  /// Every week's heaviest task rises this much higher: one landmark per
  /// block, so the skyline has a silhouette at every range.
  static const landmarkFactor = 1.3;

  /// Weight-driven building height, world meters.
  ///
  /// `floor + priorityWeight × 4.2 × ln(1 + heft)`, capped at
  /// [maxBuildingHeight]: a heavy urgent task is a tower, a lone low-priority
  /// task is a bungalow, and a wordy title changes nothing. Still a pure
  /// function of merged task data, so it is identical on every device.
  /// (The week's landmark is promoted by [landmarkFactor] in [plan].)
  double heightFor(PlazaTask task) {
    final weight = switch (task.priority) {
      <= 0 => 1.6,
      1 => 1.3,
      2 => 1.0,
      _ => 0.8,
    };
    final raw = minBuildingHeight + weight * 4.2 * math.log(1 + task.heft);
    return raw.clamp(minBuildingHeight, maxBuildingHeight);
  }

  /// Start of the UTC week containing [time] (Monday 00:00 UTC).
  ///
  /// Weeks are anchored in UTC so every device derives the same bucket from
  /// the same instant regardless of its local time zone or DST — the local
  /// calendar would break the merge-stable placement invariant.
  static DateTime weekStart(DateTime time) {
    final utc = time.toUtc();
    final day = DateTime.utc(utc.year, utc.month, utc.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// The signed 90° turn applied *after* bucket [bucketIndex], or zero.
  ///
  /// Row `r` ends after bucket `(r + 1) × foldEvery − 1`; even rows turn
  /// right, odd rows turn left, so the street snakes back and forth. Purely
  /// a function of the bucket index.
  double foldAfter(int bucketIndex) {
    if ((bucketIndex + 1) % foldEvery != 0) return 0;
    final row = (bucketIndex + 1) ~/ foldEvery - 1;
    return row.isEven ? -math.pi / 2 : math.pi / 2;
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

    // Normalize even an explicit epoch to its UTC week start, so a Tuesday
    // or local-time anchor cannot shift the Monday-aligned bucket grid.
    final anchor = weekStart(epoch ?? ordered.first.createdAt);

    // A task older than an explicit epoch lands in bucket zero rather than
    // being silently dropped to a negative bucket the street never renders.
    int bucketOf(PlazaTask task) =>
        math.max(0, task.createdAt.difference(anchor).inDays ~/ 7);

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

      final turn = foldAfter(bucket);
      if (turn != 0 && bucket < lastBucket) {
        heading += turn;
        segments.add(
          RoadSegment(
            bucketIndex: bucket,
            startX: x,
            startZ: z,
            headingRadians: heading,
            length: connectorLength,
            isGap: true,
            isConnector: true,
          ),
        );
        x += math.sin(heading) * connectorLength;
        z += math.cos(heading) * connectorLength;
        heading += turn;
      }
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

    // The week's landmark: its heaviest task (ties by id) stands taller.
    PlazaTask? landmark;
    for (final t in weekTasks) {
      if (landmark == null ||
          heightFor(t) > heightFor(landmark) ||
          (heightFor(t) == heightFor(landmark) &&
              t.id.compareTo(landmark.id) < 0)) {
        landmark = t;
      }
    }

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
        // Never wider than 95% of the slot: in a crowded week the minimum
        // width yields to the slot so neighbors cannot intersect.
        final buildingWidth = math.min(
          slot * 0.95,
          (slot * 0.9).clamp(minBuildingWidth, maxBuildingWidth),
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
          height: task == landmark
              ? math.min(
                  maxBuildingHeight * 1.3,
                  heightFor(task) * landmarkFactor,
                )
              : heightFor(task),
        );
        cursor += slot;
      }
    }
  }
}
