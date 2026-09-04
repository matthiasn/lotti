/// The fixed camera tour the harness drives with `PLAZA_TOUR=1`: the poses
/// the documentation screenshots are taken from.
///
/// Poses are derived from the built world, never hard-coded, so they track
/// layout changes; and they are a function of seeded data alone, so the
/// tour is reproducible on every machine.
library;

import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_surfaces.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';

/// A named stop on the tour: a pose derived from the world. Poses may be
/// null when the world lacks the thing (no anomalies, no plaza); the
/// harness skips those stops.
class TourStop {
  const TourStop({required this.name, required this.pose});

  final String name;
  final CameraPose? Function(PlazaWorld world) pose;
}

/// The tour, in order: the landing, the project card on the jumbotron,
/// the map, the street and its shopfronts, then the alarms, closing on
/// the wall you fly to. Names double as screenshot file names.
final List<TourStop> plazaTourStops = [
  TourStop(
    name: 'home',
    pose: (w) => w.plaza?.home,
  ),
  const TourStop(name: 'jumbotron', pose: jumbotronStopPose),
  TourStop(
    name: 'overview',
    pose: (w) => w.plaza?.overview,
  ),
  TourStop(
    name: 'block',
    pose: (w) => blockBeaconPose(w, fraction: 0.25),
  ),
  const TourStop(name: 'shopfront', pose: shopfrontPose),
  TourStop(
    name: 'billboard',
    pose: (w) {
      final slot = w.plaza?.pylons.firstOrNull;
      return slot == null ? null : PlazaSurfaces.facingPose(slot);
    },
  ),
  TourStop(
    name: 'attention-closeup',
    // The second anomaly when there is one: the billboard stop has just
    // shown the first, and seven stops should show a project, not a task.
    pose: (w) => closeupBeacon(w)?.pose,
  ),
];

/// The block beacon [fraction] of the way from oldest to newest, or null
/// when the street has no built weeks.
CameraPose? blockBeaconPose(PlazaWorld world, {required double fraction}) {
  final blocks = world.beacons
      .where((b) => b.kind == BeaconKind.block)
      .toList()
      .reversed
      .toList(); // oldest first
  if (blocks.isEmpty) return null;
  final index = (blocks.length * fraction).floor().clamp(0, blocks.length - 1);
  return blocks[index].pose;
}

/// The jumbotron stop stands beside the plaza on the tower's side, this
/// far outside its edge and this far short of its back, so the line to
/// the screen runs outside the pylons; it may pitch up to this much,
/// which keeps the paving in frame and the whole screen under the top
/// edge from there.
const jumbotronStopClearance = 8.0;
const jumbotronStopBack = 12.0;
const double jumbotronStopPitch = 22 * math.pi / 180;

/// Eye level beside the plaza, looking up at the jumbotron's screen with
/// no pylon in the way. Null without a plaza or a jumbotron.
CameraPose? jumbotronStopPose(PlazaWorld world) {
  final plaza = world.plaza;
  final slot = world.jumbotron;
  if (plaza == null || slot == null) return null;
  final ground = plaza.footprint;
  // Which side of the plaza the tower stands on, in the plaza's frame.
  final (towerLateral, _) = ground.local(slot.x, slot.z);
  final (x, z) = ground.toWorld(
    towerLateral.sign * (plaza.width / 2 + jumbotronStopClearance),
    plaza.depth / 2 - jumbotronStopBack,
  );
  final d = groundDistanceBetween(x, z, slot.x, slot.z);
  return CameraPose(
    x: x,
    y: eyeHeight,
    z: z,
    yaw: math.atan2(slot.x - x, slot.z - z),
    pitch: math.min(
      math.atan2(slot.centerY - eyeHeight, d),
      jumbotronStopPitch,
    ),
  );
}

/// The shopfront stop stands this far before the end wall and this far
/// out from the facade plane, on the road, looking at the building's
/// near corner: the parade on the end wall and the named facade in one
/// frame.
const shopfrontStandOff = 18.0;
const shopfrontRoadOffset = 6.0;

/// The shopfront stop pitches no more than this: the head facade stays
/// close to square instead of keystoning.
const double shopfrontPitch = 6 * math.pi / 180;

/// The tasks the other stops already show: the top billboard and the
/// closeup's anomaly. The shopfront stop looks elsewhere, so the tour is
/// a story about more than two problems.
Set<String> _shownElsewhere(PlazaWorld world) => {
  if (world.billboards.isNotEmpty) world.billboards.first.task.id,
  ?closeupBeacon(world)?.taskId,
};

/// The attention beacon the closeup stands at: the second when there is
/// one (the billboard stop has just shown the first), else the first.
Beacon? closeupBeacon(PlazaWorld world) {
  final attention = world.beacons
      .where((b) => b.kind == BeaconKind.attention)
      .toList();
  if (attention.isEmpty) return null;
  return attention[attention.length > 1 ? 1 : 0];
}

/// Eye level on the road at a built row's head, three-quarters on to the
/// block-head building's near corner: the shopfront parade up its end
/// wall, and the facade with the task's name beside it, pitched to the
/// wall's middle but never past [PlazaSurfaces.maxFacingPitch]. Of the
/// bare head walls (the plaza mounts carry a screen and a ticker instead)
/// not shown by another stop, the one whose dressing says the most: on
/// alarm first, then trading, then fitting out, then shuttered for the
/// night; the oldest row on a tie. Null on a street with no such wall.
CameraPose? shopfrontPose(PlazaWorld world) {
  final deleted = {
    for (final t in world.tasks)
      if (t.deleted) t.id,
  };
  final mounted = {
    for (final p in plazaMounts(world.plan)) p.taskId,
    ..._shownElsewhere(world),
  };
  int rank(PlotPlacement p) => switch (world.attention[p.taskId]?.lantern) {
    LanternState.blocked || LanternState.overdue => 0,
    LanternState.inProgress => 1,
    LanternState.open => 2,
    _ => 3,
  };
  (PlotPlacement, RoadSegment)? best;
  for (final segment in world.plan.segments) {
    if (segment.isGap || segment.isConnector) continue;
    double along(PlotPlacement p) => worldToFrame(
      segment.startX,
      segment.startZ,
      segment.headingRadians,
      p.x,
      p.z,
    ).$2;
    for (final side in PlotSide.values) {
      final row =
          world.plan.placements.values
              .where(
                (p) =>
                    p.bucketIndex == segment.bucketIndex &&
                    p.side == side &&
                    !deleted.contains(p.taskId),
              )
              .toList()
            ..sort((a, b) => along(a).compareTo(along(b)));
      final head = row.firstOrNull;
      if (head == null || mounted.contains(head.taskId)) continue;
      if (best == null || rank(head) < rank(best.$1)) best = (head, segment);
    }
  }
  if (best == null) return null;
  final (head, segment) = best;
  final (lateral, along) = worldToFrame(
    segment.startX,
    segment.startZ,
    segment.headingRadians,
    head.x,
    head.z,
  );
  // The near corner: the end wall meets the facade on the road side.
  final toRoad = lateral < 0 ? 1.0 : -1.0;
  final cornerAlong = along - head.width / 2;
  final cornerLateral = lateral + toRoad * head.depth / 2;
  final eyeAlong = cornerAlong - shopfrontStandOff;
  final eyeLateral = cornerLateral + toRoad * shopfrontRoadOffset;
  final (ex, ez) = frameToWorld(
    segment.startX,
    segment.startZ,
    segment.headingRadians,
    eyeLateral,
    eyeAlong,
  );
  final (cx, cz) = frameToWorld(
    segment.startX,
    segment.startZ,
    segment.headingRadians,
    cornerLateral,
    cornerAlong,
  );
  final reach = groundDistanceBetween(ex, ez, cx, cz);
  return CameraPose(
    x: ex,
    y: eyeHeight,
    z: ez,
    yaw: math.atan2(cx - ex, cz - ez),
    pitch: math
        .atan2(head.height / 3 - eyeHeight, reach)
        .clamp(
          0.0,
          shopfrontPitch,
        ),
  );
}
