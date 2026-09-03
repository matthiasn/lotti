/// The frontier plaza and the beacon network: everything that sits on top
/// of the street without moving a single building.
///
/// Pure Dart. Poses, slots and beacons are functions of the [StreetPlan]
/// (and, for attention beacons, of the attention verdicts), so they are as
/// merge-stable as the street itself.
library;

import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

/// Eye height of the walker, world meters.
const eyeHeight = 2.2;

/// A camera pose: eye position, yaw about +Y (0 = looking along +Z) and
/// pitch (positive = up).
class CameraPose {
  const CameraPose({
    required this.x,
    required this.y,
    required this.z,
    required this.yaw,
    this.pitch = 0,
  });

  final double x;
  final double y;
  final double z;
  final double yaw;
  final double pitch;

  double distanceTo(CameraPose other) {
    final dx = other.x - x;
    final dy = other.y - y;
    final dz = other.z - z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  @override
  String toString() =>
      'CameraPose(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, '
      '${z.toStringAsFixed(1)}, yaw ${yaw.toStringAsFixed(2)}, '
      'pitch ${pitch.toStringAsFixed(2)})';
}

/// A world-space point with the street's local frame at the frontier.
class _Frame {
  _Frame(this.originX, this.originZ, this.heading);

  final double originX;
  final double originZ;

  /// Direction of travel of the last segment.
  final double heading;

  /// Local (lateral, along) → world. Lateral is the road's right-hand
  /// normal; along is the heading.
  (double, double) toWorld(double lateral, double along) => (
    originX + math.sin(heading) * along + math.cos(heading) * lateral,
    originZ + math.cos(heading) * along - math.sin(heading) * lateral,
  );
}

/// How a billboard is mounted.
enum BillboardMount {
  /// Two posts at the plaza edge.
  pylon,

  /// Flush on the plaza-facing wall of a newest building.
  wall,

  /// Above the roof of the task's own building, facing its street.
  roof,
}

/// One billboard mount: a pylon at the plaza edge, a screen on the
/// plaza-facing wall of the newest building on one side, or a panel on the
/// roof of an anomalous building.
class BillboardSlot {
  const BillboardSlot({
    required this.rank,
    required this.x,
    required this.z,
    required this.facingRadians,
    required this.width,
    required this.height,
    required this.bottom,
    required this.mount,
    this.pulseSeconds = 3,
  });

  /// Pylon-mounted (two posts) — kept for the plaza builder.
  bool get onPylon => mount == BillboardMount.pylon;

  /// Attention rank (0 = most urgent). Slot order is stable; only the
  /// content changes.
  final int rank;
  final double x;
  final double z;

  /// Rotation about +Y of the panel's outward normal.
  final double facingRadians;
  final double width;
  final double height;

  /// Height of the panel's bottom edge above ground.
  final double bottom;

  final BillboardMount mount;

  /// Glow cycle length; shorter is more agitated.
  final double pulseSeconds;

  /// World-space centre of the panel.
  double get centerY => bottom + height / 2;
}

/// Where a ticker band runs: on the plaza-facing wall under a mounted
/// screen, or along the roofline of a hero building.
class TickerSlot {
  const TickerSlot({
    required this.x,
    required this.z,
    required this.facingRadians,
    required this.width,
    required this.height,
    required this.bottom,
    required this.speedMetersPerSecond,
  });

  final double x;
  final double z;
  final double facingRadians;
  final double width;
  final double height;
  final double bottom;
  final double speedMetersPerSecond;
}

/// What a beacon is for; drives its look and its visibility range.
enum BeaconKind { home, block, corner, overview, attention }

/// A beacon: a visible point plus the curated pose it flies you to.
class Beacon {
  const Beacon({
    required this.id,
    required this.kind,
    required this.label,
    required this.pose,
    required this.markerX,
    required this.markerY,
    required this.markerZ,
    this.taskId,
  });

  final String id;
  final BeaconKind kind;
  final String label;
  final CameraPose pose;

  /// Where the dot is drawn.
  final double markerX;
  final double markerY;
  final double markerZ;

  /// The task an attention beacon points at.
  final String? taskId;

  /// Attention beacons stay visible from farther away.
  double get visibleRange => kind == BeaconKind.attention ? 400 : 140;
}

/// The frontier plaza: the square at the newest end of the street.
class FrontierPlaza {
  const FrontierPlaza({
    required this.centerX,
    required this.centerZ,
    required this.headingRadians,
    required this.width,
    required this.depth,
    required this.home,
    required this.overview,
    required this.pylons,
  });

  final double centerX;
  final double centerZ;

  /// Direction the street was travelling when it reached the plaza.
  final double headingRadians;
  final double width;
  final double depth;

  /// Where you land in the morning: in the plaza, looking back down the
  /// street.
  final CameraPose home;

  /// The district map: high over the plaza, pitched down the street.
  final CameraPose overview;

  /// The four pylon slots, rank order.
  final List<BillboardSlot> pylons;
}

/// Plaza dimensions, world meters. The plaza starts [plazaSetback] past the
/// street end and is [plazaDepth] deep and [plazaWidth] wide.
const plazaSetback = 7.0;
const plazaDepth = 58.0;
const plazaWidth = 62.0;
const _homeAlong = 56.0;
const _overviewAlong = 160.0;
const _overviewHeight = 140.0;
const _overviewPitch = -0.62;

/// Pylon slots in plaza-local metres: (lateral, along, width, height,
/// bottom). Rank order; every panel faces the point (0, 48) on the plaza
/// so they all read from the home pose.
const _pylonSlots = <(double, double, double, double, double)>[
  (-19, 18, 15, 8.5, 4),
  (19, 20, 14, 8, 5.5),
  (-22, 36, 12, 7, 3.5),
  (22, 38, 12, 7, 6),
];
const _pylonFocusAlong = 48.0;

/// Builds the plaza at the end of [plan]. Returns null for an empty street.
FrontierPlaza? frontierPlazaFor(StreetPlan plan) {
  final last = plan.last;
  if (last == null) return null;
  final frame = _Frame(last.endX, last.endZ, last.headingRadians);
  final lookBack = last.headingRadians + math.pi;

  final (cx, cz) = frame.toWorld(0, plazaSetback + plazaDepth / 2);
  final (hx, hz) = frame.toWorld(0, _homeAlong);
  final (ox, oz) = frame.toWorld(0, _overviewAlong);

  final pylons = <BillboardSlot>[];
  for (final (rank, slot) in _pylonSlots.indexed) {
    final (lateral, along, width, height, bottom) = slot;
    final (px, pz) = frame.toWorld(lateral, along);
    // Face the plaza's focal point, expressed in the local frame then
    // rotated into the world.
    final localFacing = math.atan2(0 - lateral, _pylonFocusAlong - along);
    pylons.add(
      BillboardSlot(
        rank: rank,
        x: px,
        z: pz,
        facingRadians: last.headingRadians + localFacing,
        width: width,
        height: height,
        bottom: bottom,
        mount: BillboardMount.pylon,
      ),
    );
  }

  return FrontierPlaza(
    centerX: cx,
    centerZ: cz,
    headingRadians: last.headingRadians,
    width: plazaWidth,
    depth: plazaDepth,
    home: CameraPose(x: hx, y: eyeHeight, z: hz, yaw: lookBack),
    overview: CameraPose(
      x: ox,
      y: _overviewHeight,
      z: oz,
      yaw: lookBack,
      pitch: _overviewPitch,
    ),
    pylons: pylons,
  );
}

/// The newest building on each side of the street, if any: the two whose
/// plaza-facing end walls carry the mounted screens and tickers.
List<PlotPlacement> plazaMounts(StreetPlan plan) {
  final last = plan.last;
  if (last == null) return const [];
  double along(PlotPlacement p) {
    final dx = p.x - last.startX;
    final dz = p.z - last.startZ;
    return dx * math.sin(last.headingRadians) +
        dz * math.cos(last.headingRadians);
  }

  final result = <PlotPlacement>[];
  for (final side in PlotSide.values) {
    PlotPlacement? best;
    for (final p in plan.placements.values) {
      if (p.side != side) continue;
      if (best == null || along(p) > along(best)) best = p;
    }
    if (best != null) result.add(best);
  }
  return result;
}

/// Screen and ticker slots on the plaza-facing end walls of [plazaMounts].
///
/// Returns the mounted billboard slots (ranks 4 and 5) and one ticker band
/// under each, in the same order as [plazaMounts].
({List<BillboardSlot> screens, List<TickerSlot> tickers}) mountedSlotsFor(
  StreetPlan plan,
) {
  final last = plan.last;
  final screens = <BillboardSlot>[];
  final tickers = <TickerSlot>[];
  if (last == null) return (screens: screens, tickers: tickers);
  for (final (i, mount) in plazaMounts(plan).indexed) {
    // The end wall faces along the street heading (toward the plaza).
    final facing = last.headingRadians;
    final endX = mount.x + math.sin(facing) * (mount.width / 2 + 0.15);
    final endZ = mount.z + math.cos(facing) * (mount.width / 2 + 0.15);
    screens.add(
      BillboardSlot(
        rank: 4 + i,
        x: endX,
        z: endZ,
        facingRadians: facing,
        width: math.min(9.6, mount.depth * 1.2),
        height: 7,
        bottom: 2.6,
        mount: BillboardMount.wall,
      ),
    );
    tickers.add(
      TickerSlot(
        x: endX,
        z: endZ,
        facingRadians: facing,
        width: mount.depth * 1.1,
        height: 1.3,
        bottom: 1.2,
        speedMetersPerSecond: i.isEven ? 3.5 : 2.8,
      ),
    );
  }
  return (screens: screens, tickers: tickers);
}

/// Roof billboards for the anomalies, most urgent first, at most [cap]:
/// a panel above the task's own building facing its street, sized and
/// agitated by score, so the thing that needs you is lit where it stands.
List<BillboardSlot> roofBillboardsFor(
  StreetPlan plan,
  List<TaskAttention> anomalies, {
  int cap = 12,
}) {
  final slots = <BillboardSlot>[];
  for (final (rank, anomaly) in anomalies.take(cap).indexed) {
    final p = plan.placements[anomaly.task.id];
    if (p == null) continue;
    final height = (2.6 + anomaly.score * 0.45).clamp(3.0, 6.0);
    slots.add(
      BillboardSlot(
        rank: rank,
        x: p.x + math.sin(p.facingRadians) * (p.depth / 2 - 0.4),
        z: p.z + math.cos(p.facingRadians) * (p.depth / 2 - 0.4),
        facingRadians: p.facingRadians,
        width: p.width * 0.95,
        height: height,
        bottom: p.height + 0.5,
        mount: BillboardMount.roof,
        pulseSeconds: (3.6 - anomaly.score * 0.4).clamp(1.2, 3.0),
      ),
    );
  }
  return slots;
}

/// A ticker band along the roofline of [hero]'s street-facing wall.
TickerSlot rooflineTickerFor(PlotPlacement hero, {required bool fast}) =>
    TickerSlot(
      x: hero.x + math.sin(hero.facingRadians) * (hero.depth / 2 + 0.05),
      z: hero.z + math.cos(hero.facingRadians) * (hero.depth / 2 + 0.05),
      facingRadians: hero.facingRadians,
      width: hero.width,
      height: 1.9,
      bottom: hero.height + 0.2,
      speedMetersPerSecond: fast ? 4.2 : 3.4,
    );

/// The pose that looks straight at a building's facade from the road:
/// far enough back to frame a wide or tall wall, tilted to keep the
/// facade centre in view from eye height.
CameraPose taskPoseFor(PlotPlacement p) {
  final d = math.max(
    13,
    math.max(p.width * 1.1, (p.height - eyeHeight) * 1.9),
  );
  final facing = p.facingRadians;
  final facadeX = p.x + math.sin(facing) * (p.depth / 2);
  final facadeZ = p.z + math.cos(facing) * (p.depth / 2);
  return CameraPose(
    x: facadeX + math.sin(facing) * d,
    y: eyeHeight,
    z: facadeZ + math.cos(facing) * d,
    yaw: facing + math.pi,
    pitch: math.atan2(p.height / 2 - eyeHeight, d),
  );
}

/// Height of the beacon dot above the road.
const _markerHeight = 1.6;

/// How far into a block its beacon stands.
const blockBeaconInset = 3.0;

/// The navigation beacons: Home, one per built week (newest first), one per
/// fold corner; then one attention beacon per anomaly.
List<Beacon> beaconsFor(
  StreetPlan plan,
  FrontierPlaza? plaza,
  List<TaskAttention> anomalies, {
  required String projectLabel,
  required String Function(int bucketIndex) weekLabel,
}) {
  final beacons = <Beacon>[];
  if (plaza != null) {
    beacons.add(
      Beacon(
        id: 'home',
        kind: BeaconKind.home,
        label: 'Home — $projectLabel',
        pose: plaza.home,
        markerX: plaza.home.x,
        markerY: _markerHeight,
        markerZ: plaza.home.z,
      ),
    );
  }
  for (final segment in plan.segments.reversed) {
    if (segment.isConnector) {
      beacons.add(
        Beacon(
          id: 'corner-${segment.bucketIndex}',
          kind: BeaconKind.corner,
          label: 'Corner after ${weekLabel(segment.bucketIndex)}',
          pose: CameraPose(
            x: segment.startX,
            y: eyeHeight,
            z: segment.startZ,
            yaw: segment.headingRadians,
          ),
          markerX: segment.startX,
          markerY: _markerHeight,
          markerZ: segment.startZ,
        ),
      );
      continue;
    }
    if (segment.isGap) continue;
    // Stand at the block's start looking down it, so its buildings are
    // ahead on both sides rather than beside and behind the camera.
    final x =
        segment.startX + math.sin(segment.headingRadians) * blockBeaconInset;
    final z =
        segment.startZ + math.cos(segment.headingRadians) * blockBeaconInset;
    beacons.add(
      Beacon(
        id: 'block-${segment.bucketIndex}',
        kind: BeaconKind.block,
        label: '${weekLabel(segment.bucketIndex)} — block',
        pose: CameraPose(
          x: x,
          y: eyeHeight,
          z: z,
          yaw: segment.headingRadians,
        ),
        markerX: x,
        markerY: _markerHeight,
        markerZ: z,
      ),
    );
  }
  for (final anomaly in anomalies) {
    final placement = plan.placements[anomaly.task.id];
    if (placement == null) continue;
    final pose = taskPoseFor(placement);
    beacons.add(
      Beacon(
        id: 'att-${anomaly.task.id}',
        kind: BeaconKind.attention,
        label: anomaly.task.title,
        pose: pose,
        markerX: pose.x,
        markerY: 1.8,
        markerZ: pose.z,
        taskId: anomaly.task.id,
      ),
    );
  }
  return beacons;
}

/// `W12 · Mar 23` for the bucket that starts `bucketIndex` weeks after
/// [epoch].
String weekLabelFor(DateTime epoch, int bucketIndex) {
  final start = epoch.add(Duration(days: 7 * bucketIndex));
  return 'W${bucketIndex + 1} · ${shortDate(start)}';
}
