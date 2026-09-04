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

/// Plaza-local ([lateral], [along]) from the end of [last], the frame
/// shifted sideways by [lateralOffset] (see [frontierPlazaFor]), to the
/// world. Lateral is the road's right-hand normal; along is its heading.
(double, double) _plazaPoint(
  RoadSegment last,
  double lateralOffset,
  double lateral,
  double along,
) => frameToWorld(
  last.endX,
  last.endZ,
  last.headingRadians,
  lateral + lateralOffset,
  along,
);

/// How a billboard is mounted.
enum BillboardMount {
  /// Two posts at the plaza edge.
  pylon,

  /// Flush on the plaza-facing wall of a newest building.
  wall,

  /// Above the roof of the task's own building, facing its street.
  roof,

  /// The giant screen on the tower behind the plaza.
  jumbotron,
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
enum BeaconKind { home, block, corner, attention }

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

  /// Every beacon reads from the overview; block and corner stops from a
  /// little less far, so the street thins them out first.
  double get visibleRange => switch (kind) {
    BeaconKind.attention || BeaconKind.home => 450,
    _ => 320,
  };
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
    this.lateralOffset = 0,
  });

  final double centerX;
  final double centerZ;

  /// Direction the street was travelling when it reached the plaza.
  final double headingRadians;
  final double width;
  final double depth;

  /// How far the plaza is shifted sideways off the last row's axis, world
  /// metres along the road's right-hand normal: zero for a straight street,
  /// otherwise enough to clear the previous row's plots and back streets.
  final double lateralOffset;

  /// Where you land in the morning: in the plaza, looking back down the
  /// street.
  final CameraPose home;

  /// The district map: high over the plaza, pitched down the street.
  final CameraPose overview;

  /// The four pylon slots, rank order.
  final List<BillboardSlot> pylons;

  /// The square's rectangle on the ground, local Z along the street's
  /// heading.
  Footprint get footprint => Footprint(
    x: centerX,
    z: centerZ,
    facingRadians: headingRadians,
    width: width,
    depth: depth,
  );
}

/// Plaza dimensions, world meters. The plaza starts [plazaSetback] past the
/// street end and is [plazaDepth] deep and [plazaWidth] wide.
const plazaSetback = 7.0;
const plazaDepth = 72.0;
const plazaWidth = 62.0;

/// Home stands far enough back that all four pylons, turned toward the
/// focal point, sit inside the frame at a 60° vertical field of view on
/// a 3:2 window.
const _homeAlong = 73.0;

/// Pylon slots in plaza-local metres: (lateral, along, width, height,
/// bottom). Rank order; every panel faces the point (0, 52) on the plaza
/// so they all read from the home pose, and they sit inside a 60° field of
/// view from there. The rear pair stands on tall legs so, seen from home,
/// each panel clears the front pair's top edge instead of cutting across
/// it (`plaza_layout_test` projects the corners to check).
const _pylonSlots = <(double, double, double, double, double)>[
  (-14, 20, 16, 9, 4.5),
  (14, 23, 13, 7.5, 5.5),
  (-19, 38, 11, 6.2, 11.5),
  (19, 41, 9.5, 5.4, 11.5),
];
const _pylonFocusAlong = 52.0;

/// Home looks a little up: the masthead and the rear pylons sit in the
/// upper frame, and the paving stops at the fourth metre instead of
/// filling the lower half.
const double homePitch = 6 * math.pi / 180;

/// Clearance the plaza keeps from the last row's axis once the street has
/// folded: half the plaza plus the road's half width, so the square sits
/// beside the row's mouth on the district's outside.
const double plazaFoldClearance = plazaWidth / 2 + 11;

/// The plaza's sideways shift for [plan]: zero for a straight street;
/// on a folded one, [plazaFoldClearance] toward the district's outside
/// (away from the centroid of every plot).
double plazaLateralOffsetFor(StreetPlan plan) {
  final last = plan.last;
  if (last == null) return 0;
  final folded = plan.segments.any((s) => s.isConnector);
  if (!folded || plan.placements.isEmpty) return 0;
  var cx = 0.0;
  var cz = 0.0;
  for (final p in plan.placements.values) {
    cx += p.x;
    cz += p.z;
  }
  cx /= plan.placements.length;
  cz /= plan.placements.length;
  // Lateral component of (centroid − street end) in the last row's frame.
  final (toCentroid, _) = worldToFrame(
    last.endX,
    last.endZ,
    last.headingRadians,
    cx,
    cz,
  );
  return toCentroid >= 0 ? -plazaFoldClearance : plazaFoldClearance;
}

/// Builds the plaza at the end of [plan]. Returns null for an empty street.
///
/// On a folded street the last row runs back alongside an earlier one, so
/// a plaza straight off its end would land on that row's plots. The plaza
/// is then shifted sideways to the district's outside (away from the
/// centroid of every plot) by [plazaFoldClearance].
FrontierPlaza? frontierPlazaFor(StreetPlan plan) {
  final last = plan.last;
  if (last == null) return null;
  final lateralOffset = plazaLateralOffsetFor(plan);
  final lookBack = last.headingRadians + math.pi;

  final (cx, cz) = _plazaPoint(
    last,
    lateralOffset,
    0,
    plazaSetback + plazaDepth / 2,
  );
  final (hx, hz) = _plazaPoint(last, lateralOffset, 0, _homeAlong);

  final pylons = <BillboardSlot>[];
  for (final (rank, slot) in _pylonSlots.indexed) {
    final (lateral, along, width, height, bottom) = slot;
    final (px, pz) = _plazaPoint(last, lateralOffset, lateral, along);
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
    lateralOffset: lateralOffset,
    home: CameraPose(
      x: hx,
      y: eyeHeight,
      z: hz,
      yaw: lookBack,
      pitch: homePitch,
    ),
    overview: overviewPoseFor(plan),
    pylons: pylons,
  );
}

/// The map shot: high over the district, behind its oldest edge, looking
/// toward the plaza so the jumbotron tower is the far landmark. Height and
/// stand-off scale with the district's footprint so the whole thing fills
/// the frame with a little headroom at a 55° pitch.
CameraPose overviewPoseFor(StreetPlan plan) {
  final last = plan.last;
  if (last == null) return const CameraPose(x: 0, y: 120, z: -100, yaw: 0);
  final points = <(double, double)>[
    for (final p in plan.placements.values) (p.x, p.z),
    for (final s in plan.segments) (s.startX, s.startZ),
    (last.endX, last.endZ),
  ];
  var minX = double.infinity;
  var maxX = -double.infinity;
  var minZ = double.infinity;
  var maxZ = -double.infinity;
  for (final (x, z) in points) {
    minX = math.min(minX, x);
    maxX = math.max(maxX, x);
    minZ = math.min(minZ, z);
    maxZ = math.max(maxZ, z);
  }
  // Include the plaza and the jumbotron tower in the footprint.
  const plazaFar = plazaSetback + plazaDepth + 20;
  final (fx, fz) = _plazaPoint(last, plazaLateralOffsetFor(plan), 0, plazaFar);
  minX = math.min(minX, fx);
  maxX = math.max(maxX, fx);
  final jumbotron = jumbotronSlotFor(plan);
  if (jumbotron != null) {
    minX = math.min(minX, jumbotron.x);
    maxX = math.max(maxX, jumbotron.x);
    minZ = math.min(minZ, jumbotron.z);
    maxZ = math.max(maxZ, jumbotron.z);
  }
  minZ = math.min(minZ, fz);
  maxZ = math.max(maxZ, fz);
  final cx = (minX + maxX) / 2;
  final cz = (minZ + maxZ) / 2;
  final extent = math.max(maxX - minX, maxZ - minZ).clamp(120.0, 2000.0);
  // Aim a little short of the centre (toward the near rows) and stand off
  // by the extent, so the nearest row and the jumbotron both fit with
  // headroom at a 60° field of view.
  final back = 0.5 * extent;
  final height = 0.72 * extent;
  final h = last.headingRadians;
  final aimBack = 0.08 * extent;
  return CameraPose(
    x: cx - math.sin(h) * (back + aimBack),
    y: height,
    z: cz - math.cos(h) * (back + aimBack),
    yaw: h,
    pitch: -math.atan2(height, back),
  );
}

/// The newest building on each side of the street, if any: the two whose
/// plaza-facing end walls carry the mounted screens and tickers.
List<PlotPlacement> plazaMounts(StreetPlan plan) {
  final last = plan.last;
  if (last == null) return const [];
  double along(PlotPlacement p) =>
      worldToFrame(last.startX, last.startZ, last.headingRadians, p.x, p.z).$2;

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
    final (endX, endZ) = frameToWorld(
      mount.x,
      mount.z,
      facing,
      0,
      mount.width / 2 + 0.15,
    );
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
    final (x, z) = p.footprint.toWorld(0, p.depth / 2 - 0.4);
    slots.add(
      BillboardSlot(
        rank: rank,
        x: x,
        z: z,
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

/// A vertical neon banner on the plaza-facing end wall of a tall building.
class BannerSlot {
  const BannerSlot({
    required this.taskId,
    required this.x,
    required this.z,
    required this.facingRadians,
    required this.width,
    required this.height,
    required this.bottom,
  });

  final String taskId;
  final double x;
  final double z;
  final double facingRadians;
  final double width;
  final double height;
  final double bottom;

  double get centerY => bottom + height / 2;
}

/// Buildings at least [minHeight] tall carry a vertical banner down the
/// end wall that faces along the row (toward the plaza on the last row).
List<BannerSlot> bannersFor(StreetPlan plan, {double minHeight = 12}) {
  final slots = <BannerSlot>[];
  for (final segment in plan.segments) {
    if (segment.isGap) continue;
    for (final p in plan.placements.values) {
      if (p.bucketIndex != segment.bucketIndex || p.height < minHeight) {
        continue;
      }
      final facing = segment.headingRadians;
      final (x, z) = frameToWorld(p.x, p.z, facing, 0, p.width / 2 + 0.06);
      slots.add(
        BannerSlot(
          taskId: p.taskId,
          x: x,
          z: z,
          facingRadians: facing,
          width: math.min(1.8, p.depth * 0.3),
          height: p.height * 0.7,
          bottom: p.height * 0.15,
        ),
      );
    }
  }
  return slots;
}

/// Lamp posts stand about this far apart along a kerb.
const lampRhythm = 18.0;

/// A lamp post needs a gap at least this wide between two buildings.
const _lampMinGap = 2.5;

/// Lamp posts on the pavement of both kerbs at a [lampRhythm] beat, each
/// beat snapped to the nearest gap between buildings (never in front of a
/// facade), plus the head of every built block on the left kerb (the week
/// sign hangs from it), as (x, z) pairs. Two posts never stand closer
/// than a third of the beat.
List<(double, double)> lampPostsFor(
  StreetPlan plan, {
  required double roadWidth,
}) {
  final posts = <(double, double)>[];
  final lateral = roadWidth / 2 - kerbFixtureInset;
  for (final segment in plan.segments) {
    if (segment.isGap) continue;
    double along(PlotPlacement p) => worldToFrame(
      segment.startX,
      segment.startZ,
      segment.headingRadians,
      p.x,
      p.z,
    ).$2;
    for (final side in PlotSide.values) {
      final sign = side == PlotSide.left ? -1.0 : 1.0;
      final plots =
          plan.placements.values
              .where(
                (p) => p.bucketIndex == segment.bucketIndex && p.side == side,
              )
              .toList()
            ..sort((a, b) => along(a).compareTo(along(b)));
      // The gaps a post may stand in: before the first plot, between
      // neighbours at least [_lampMinGap] apart, and after the last.
      final gaps = <(double, double)>[];
      var cursor = 0.0;
      for (final p in plots) {
        final start = along(p) - p.width / 2;
        if (start - cursor >= _lampMinGap) gaps.add((cursor, start));
        cursor = along(p) + p.width / 2;
      }
      if (segment.length - cursor >= _lampMinGap) {
        gaps.add((cursor, segment.length));
      }
      final spots = <double>[if (side == PlotSide.left) blockHeadAlong];
      for (
        var beat = lampRhythm / 2;
        beat < segment.length;
        beat += lampRhythm
      ) {
        // Snap the beat into the nearest gap.
        double? best;
        for (final (start, end) in gaps) {
          final a = beat.clamp(start + 0.8, end - 0.8);
          if (a < start || a > end) continue;
          if (best == null || (a - beat).abs() < (best - beat).abs()) best = a;
        }
        if (best == null) continue;
        if (spots.every((s) => (s - best!).abs() >= lampRhythm / 3)) {
          spots.add(best);
        }
      }
      for (final a in spots) {
        posts.add(
          frameToWorld(
            segment.startX,
            segment.startZ,
            segment.headingRadians,
            sign * lateral,
            a,
          ),
        );
      }
    }
  }
  return posts;
}

/// Where the block-head lamp post stands, along the road and in from the
/// road edge: the week sign hangs from the same post.
const blockHeadAlong = 1.5;
const kerbFixtureInset = 1.6;

/// A week sign at the head of each built block, hung from the left-hand
/// block-head lamp post (the right kerb is where the plaza's pylons show
/// past a block's mouth), facing whoever walks in: (bucketIndex, x, z,
/// facing).
List<(int, double, double, double)> weekSignsFor(
  StreetPlan plan, {
  required double roadWidth,
}) {
  final signs = <(int, double, double, double)>[];
  for (final segment in plan.segments) {
    if (segment.isGap) continue;
    final (x, z) = frameToWorld(
      segment.startX,
      segment.startZ,
      segment.headingRadians,
      -(roadWidth / 2 - kerbFixtureInset),
      blockHeadAlong,
    );
    signs.add((segment.bucketIndex, x, z, segment.headingRadians + math.pi));
  }
  return signs;
}

/// The ticker gantry spanning the street mouth at the plaza, facing home.
TickerSlot? gantryTickerFor(StreetPlan plan, {required double roadWidth}) {
  final last = plan.last;
  if (last == null) return null;
  const along = 3.0;
  final (x, z) = frameToWorld(
    last.endX,
    last.endZ,
    last.headingRadians,
    0,
    along,
  );
  return TickerSlot(
    x: x,
    z: z,
    facingRadians: last.headingRadians,
    width: roadWidth + 4,
    height: 1.8,
    bottom: 10.5,
    speedMetersPerSecond: 4.5,
  );
}

/// The jumbotron's tower stands this far outside the plaza's edge, this
/// far along from the street end (beside the mouth, on the district's
/// outside), with the screen's bottom this high so it clears the raised
/// rear pylon on its side from home and still fits under the frame's top
/// edge at [homePitch].
const jumbotronLateralClearance = 6.0;
const jumbotronAlong = 6.0;
const jumbotronBottom = 35.0;

/// The jumbotron: a giant screen on a tower beside the plaza's mouth, on
/// the district's outside, turned to face home, so the masthead sits over
/// the billboards in the morning's first frame and marks the way out.
BillboardSlot? jumbotronSlotFor(StreetPlan plan) {
  final last = plan.last;
  if (last == null) return null;
  final offset = plazaLateralOffsetFor(plan);
  final side = offset == 0 ? -1.0 : offset.sign;
  final (x, z) = _plazaPoint(
    last,
    offset,
    side * (plazaWidth / 2 + jumbotronLateralClearance),
    jumbotronAlong,
  );
  final (hx, hz) = _plazaPoint(last, offset, 0, _homeAlong);
  return BillboardSlot(
    rank: 0,
    x: x,
    z: z,
    facingRadians: math.atan2(hx - x, hz - z),
    width: 30,
    height: 16,
    bottom: jumbotronBottom,
    mount: BillboardMount.jumbotron,
    pulseSeconds: 6,
  );
}

/// Tallest first, ties by task id, so the order never moves under the
/// user's feet.
int tallestFirst(PlotPlacement a, PlotPlacement b) {
  final byHeight = b.height.compareTo(a.height);
  return byHeight != 0 ? byHeight : a.taskId.compareTo(b.taskId);
}

/// The [count] tallest buildings, tallest first: they carry spires with
/// blinking warning lights.
List<PlotPlacement> spiresFor(StreetPlan plan, {int count = 2}) =>
    ([...plan.placements.values]..sort(tallestFirst)).take(count).toList();

/// A ticker band along the roofline of [hero]'s street-facing wall.
TickerSlot rooflineTickerFor(PlotPlacement hero, {required bool fast}) {
  final (x, z) = hero.footprint.toWorld(0, hero.depth / 2 + 0.05);
  return TickerSlot(
    x: x,
    z: z,
    facingRadians: hero.facingRadians,
    width: hero.width,
    height: 1.9,
    bottom: hero.height + 0.2,
    speedMetersPerSecond: fast ? 4.2 : 3.4,
  );
}

/// The pose that looks straight at a building's facade from the road:
/// far enough back to frame a wide or tall wall, tilted to keep the
/// facade centre in view from eye height.
/// Roof signage above a building that the task pose must frame.
const roofSignageHeight = 6.5;

/// The task pose never stands farther from the facade than this. With the
/// default road (18 m) and plots (10 m deep, buildings 8 m) the facade is
/// 10 m from the crown and the far pavement's lamp posts 7.4 m past it
/// ([kerbFixtureInset]); the pose stays the walker's clearance short of
/// that lamp line, on the far kerb, so no stop stands in a post or in the
/// building opposite and no flight ends in a wall. Inside the live range,
/// so the wall you flew to is the one that goes live.
const maxTaskStandOff = 16.5;

/// How far in front of the facade the task pose stands: the whole framed
/// extent — wall plus roof signage plus a margin — at a 60° vertical field
/// of view (half-angle 30°, so distance ≥ 0.87 × the extent), never closer
/// than a wide wall needs, and never past [maxTaskStandOff]; a tall
/// landmark is framed by pitching up instead.
double taskStandOffFor(PlotPlacement p) {
  final extent = p.height + roofSignageHeight + 3;
  return math.min(
    maxTaskStandOff,
    math.max(16, math.max(p.width * 1.2, extent * 0.9)),
  );
}

/// A task pose never pitches up more than this: the ground stays in the
/// frame and verticals stay near vertical; a tall wall loses its roof
/// signage rather than its street.
const double maxTaskPitch = 14 * math.pi / 180;

CameraPose taskPoseFor(PlotPlacement p) {
  final d = taskStandOffFor(p);
  final facing = p.facingRadians;
  // In front of the facade, which is half the depth out from the centre.
  final (x, z) = p.footprint.toWorld(0, p.depth / 2 + d);
  return CameraPose(
    x: x,
    y: eyeHeight,
    z: z,
    yaw: facing + math.pi,
    pitch: math.min(
      math.atan2((p.height + roofSignageHeight) / 2 - eyeHeight, d),
      maxTaskPitch,
    ),
  );
}

/// Height of the beacon dot above the road.
const _markerHeight = 1.6;

/// Where a block's beacon stands: this far *before* the block starts, so
/// its first pair of facades fits the frame with margin at a 60° field of
/// view (a 32 m tall landmark at 14 m needs the distance). On the road's
/// crown: twenty metres before a block is beside the previous block's
/// last buildings, and a kerb-line pose there stands two metres from a
/// wall.
const blockBeaconInset = -20.0;

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
    // Stand just before the block looking down it, so its buildings are
    // ahead on both sides rather than beside and behind the camera.
    final (x, z) = frameToWorld(
      segment.startX,
      segment.startZ,
      segment.headingRadians,
      0,
      blockBeaconInset,
    );
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
          pitch: 0.05,
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
