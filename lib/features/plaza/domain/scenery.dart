/// Set dressing placed by the street plan alone: the filler blocks behind
/// the plots, a hero tower past every row that folds, the tower under the
/// jumbotron and the skyline ring, plus the ground footprints of the
/// pylon footings, the gantry legs and the lamp posts.
///
/// Every solid the scene stands on the ground is placed here, in pure
/// Dart, so the scene and the walker collider read one list and nothing
/// can be walked through. Sizes and positions are seeded by id through
/// [stableUnit], never by task data.
library;

import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

/// A seeded box on the ground: [yawRadians] rotates it about +Y, its local
/// X spans [width] and its local Z spans [depth].
class SceneryBox {
  const SceneryBox({
    required this.id,
    required this.x,
    required this.z,
    required this.yawRadians,
    required this.width,
    required this.depth,
    required this.height,
  });

  /// Stable id: the seed for the box's hashed details.
  final String id;
  final double x;
  final double z;
  final double yawRadians;
  final double width;
  final double depth;
  final double height;

  Footprint get footprint => Footprint(
    x: x,
    z: z,
    facingRadians: yawRadians,
    width: width,
    depth: depth,
  );
}

/// City fabric behind one week's plots. Its yaw is the road's heading, so
/// local Z runs along the road: [depth] is the frontage and [width] how far
/// the block reaches away from the street.
class FillerBlock extends SceneryBox {
  const FillerBlock({
    required super.id,
    required this.bucketIndex,
    required this.side,
    required super.x,
    required super.z,
    required super.yawRadians,
    required super.width,
    required super.depth,
    required super.height,
  });

  final int bucketIndex;

  /// -1 on the road's left, +1 on its right.
  final double side;
}

/// The tower past the far end of a row that folds, on the row's axis,
/// facing back down it: the horizon a walker walks toward.
class HeroTower extends SceneryBox {
  const HeroTower({
    required super.id,
    required this.bucketIndex,
    required super.x,
    required super.z,
    required super.yawRadians,
    required super.width,
    required super.depth,
    required super.height,
  });

  /// The bucket of the row the tower closes.
  final int bucketIndex;
}

/// A tower on the ring around the district; [index] runs round the ring.
class SkylineTower extends SceneryBox {
  const SkylineTower({
    required super.id,
    required this.index,
    required super.x,
    required super.z,
    required super.yawRadians,
    required super.width,
    required super.depth,
    required super.height,
  });

  final int index;
}

/// What a piece of plaza furniture is.
enum FurnitureKind { bench, planter, kiosk }

/// A bench, a planter or a kiosk on the plaza: solid, so the walker goes
/// round it.
class PlazaFurniture extends SceneryBox {
  const PlazaFurniture({
    required super.id,
    required this.kind,
    required super.x,
    required super.z,
    required super.yawRadians,
    required super.width,
    required super.depth,
    required super.height,
  });

  final FurnitureKind kind;
}

/// Everything seeded that stands around the street.
class Scenery {
  const Scenery({
    required this.fillers,
    required this.heroTowers,
    required this.jumbotronTower,
    required this.skyline,
    required this.furniture,
  });

  final List<FillerBlock> fillers;
  final List<HeroTower> heroTowers;
  final SceneryBox? jumbotronTower;
  final List<SkylineTower> skyline;
  final List<PlazaFurniture> furniture;

  /// Every box, for the collider.
  List<SceneryBox> get boxes => [
    ...fillers,
    ...heroTowers,
    ?jumbotronTower,
    ...skyline,
    ...furniture,
  ];
}

/// Fillers stand this far past the plots' back line.
const fillerSetback = 4.0;

/// No filler stands on the plaza or within this margin of it.
const fillerPlazaMargin = 12.0;

/// A second row of blocks behind the plots with alleys between, so the
/// street has a back and the overview has texture between the plots and
/// the skyline. Seeded per bucket, side and slot; nothing on the plaza.
List<FillerBlock> fillerBlocksFor(
  StreetPlan plan,
  FrontierPlaza? plaza, {
  required double roadWidth,
  required double plotDepth,
}) {
  final lateralBase = roadWidth / 2 + plotDepth + fillerSetback;
  bool onPlaza(double x, double z) {
    if (plaza == null) return false;
    final dx = x - plaza.centerX;
    final dz = z - plaza.centerZ;
    final along =
        dx * math.sin(plaza.headingRadians) +
        dz * math.cos(plaza.headingRadians);
    final lateral =
        dx * math.cos(plaza.headingRadians) -
        dz * math.sin(plaza.headingRadians);
    return along.abs() < plaza.depth / 2 + fillerPlazaMargin &&
        lateral.abs() < plaza.width / 2 + fillerPlazaMargin;
  }

  final blocks = <FillerBlock>[];
  for (final segment in plan.segments) {
    if (segment.isGap) continue;
    final sinH = math.sin(segment.headingRadians);
    final cosH = math.cos(segment.headingRadians);
    for (final side in [-1.0, 1.0]) {
      var along = 2.0;
      var i = 0;
      while (along < segment.length - 4) {
        final id = 'filler-${segment.bucketIndex}-$side-$i';
        final frontage = 7 + stableUnit(id, 'w') * 9;
        if (along + frontage > segment.length - 1) break;
        final reach = 8 + stableUnit(id, 'd') * 8;
        // The fabric behind the plots is the tall layer: the plots are
        // the shops, the city rises behind them; a quarter are mid-rise
        // landmarks so the roofline behind a row is jagged.
        final tall = stableUnit(id, 'tall') < 0.25;
        final height = tall
            ? 40 + stableUnit(id, 'h') * 20
            : 12 + stableUnit(id, 'h') * 22;
        final lateral =
            side * (lateralBase + reach / 2 + stableUnit(id, 'l') * 4);
        final cx =
            segment.startX + sinH * (along + frontage / 2) + cosH * lateral;
        final cz =
            segment.startZ + cosH * (along + frontage / 2) - sinH * lateral;
        if (!onPlaza(cx, cz)) {
          blocks.add(
            FillerBlock(
              id: id,
              bucketIndex: segment.bucketIndex,
              side: side,
              x: cx,
              z: cz,
              yawRadians: segment.headingRadians,
              width: reach,
              depth: frontage,
              height: height,
            ),
          );
        }
        along += frontage + 2 + stableUnit(id, 'gap') * 4;
        i++;
      }
    }
  }
  return blocks;
}

/// How far past a folding row's end its hero tower stands.
const heroTowerStandOff = 90.0;

/// One hero tower past the far end of every row that folds, on the row's
/// axis, facing back down the row. The last row's far end has the
/// jumbotron instead.
List<HeroTower> heroTowersFor(StreetPlan plan) {
  final towers = <HeroTower>[];
  final segments = plan.segments;
  for (var i = 1; i < segments.length; i++) {
    if (!segments[i].isConnector) continue;
    final row = segments[i - 1];
    final id = 'hero-${row.bucketIndex}';
    final width = 26 + stableUnit(id, 'w') * 8;
    towers.add(
      HeroTower(
        id: id,
        bucketIndex: row.bucketIndex,
        x: row.endX + math.sin(row.headingRadians) * heroTowerStandOff,
        z: row.endZ + math.cos(row.headingRadians) * heroTowerStandOff,
        yawRadians: row.headingRadians + math.pi,
        width: width,
        depth: width * 0.8,
        height: 70 + stableUnit(id, 'h') * 16,
      ),
    );
  }
  return towers;
}

/// The jumbotron's tower: this much wider than the screen on each side,
/// this deep, its centre this far behind the screen's plane, and rising
/// this far above the screen's top.
const jumbotronTowerMargin = 2.0;
const jumbotronTowerDepth = 6.0;
const jumbotronTowerSetback = 3.5;
const jumbotronTowerCrown = 14.0;

/// The tower the jumbotron hangs on, behind the plaza.
SceneryBox? jumbotronTowerFor(BillboardSlot? jumbotron) {
  if (jumbotron == null) return null;
  final sinF = math.sin(jumbotron.facingRadians);
  final cosF = math.cos(jumbotron.facingRadians);
  return SceneryBox(
    id: 'jumbotron',
    x: jumbotron.x - sinF * jumbotronTowerSetback,
    z: jumbotron.z - cosF * jumbotronTowerSetback,
    yawRadians: jumbotron.facingRadians,
    width: jumbotron.width + 2 * jumbotronTowerMargin,
    depth: jumbotronTowerDepth,
    height: jumbotron.bottom + jumbotron.height + jumbotronTowerCrown,
  );
}

/// Towers on the skyline ring, and how far beyond the district's radius
/// the ring starts. The towers stand 24 to 78 m so their lit rooflines
/// show over the fillers from the street.
const skylineTowerCount = 48;
const skylineRingClearance = 50.0;

/// The centre of the plan: the mean of its segment starts, the origin for
/// an empty street.
(double, double) planCenterOf(StreetPlan plan) {
  if (plan.segments.isEmpty) return (0, 0);
  var sumX = 0.0;
  var sumZ = 0.0;
  for (final s in plan.segments) {
    sumX += s.startX;
    sumZ += s.startZ;
  }
  return (sumX / plan.segments.length, sumZ / plan.segments.length);
}

/// A ring of towers around the district so the street dissolves into a
/// city instead of a black table: [skylineRingClearance] beyond the
/// farthest plot (or the plaza plus 60 m), with a seeded spread outward.
List<SkylineTower> skylineFor(StreetPlan plan, FrontierPlaza? plaza) {
  final (cx, cz) = planCenterOf(plan);
  var radius = 0.0;
  for (final p in plan.placements.values) {
    final dx = p.x - cx;
    final dz = p.z - cz;
    radius = math.max(radius, math.sqrt(dx * dx + dz * dz));
  }
  if (plaza != null) {
    final dx = plaza.centerX - cx;
    final dz = plaza.centerZ - cz;
    radius = math.max(radius, math.sqrt(dx * dx + dz * dz) + 60);
  }
  radius += skylineRingClearance;
  final towers = <SkylineTower>[];
  for (var i = 0; i < skylineTowerCount; i++) {
    final id = 'skyline-$i';
    final angle =
        i / skylineTowerCount * 2 * math.pi + stableUnit(id, 'a') * 0.1;
    final r = radius + stableUnit(id, 'r') * 90;
    final width = 16 + stableUnit(id, 'w') * 26;
    towers.add(
      SkylineTower(
        id: id,
        index: i,
        x: cx + math.cos(angle) * r,
        z: cz + math.sin(angle) * r,
        yawRadians: -angle,
        width: width,
        depth: width * 0.8,
        height: 24 + stableUnit(id, 'h') * 54,
      ),
    );
  }
  return towers;
}

/// Plaza furniture, plaza-local metres: benches and planters this far in
/// from the long sides, one every [furnitureSpacing] along, alternating;
/// a kiosk in the back-left corner, out of the home pose's frame and off
/// every line from home to a pylon.
const furnitureInset = 4.0;
const furnitureSpacing = 12.0;
const benchWidth = 0.6;
const benchLength = 2.0;
const benchHeight = 0.9;
const planterSize = 1.4;
const planterHeight = 0.8;
const kioskWidth = 3.0;
const kioskDepth = 2.4;
const kioskHeight = 3.2;
const kioskLateral = -21.0;
const kioskAlong = 20.0;

/// A bench and a planter this far ahead of home and this far to either
/// side of the axis: a foreground for the first frame, inside its edges,
/// and too low to hide any pylon's panel from the eye at home.
const nearHomeAhead = 8.0;
const nearHomeLateral = 4.0;

/// The furniture on [plaza]: benches and planters down both long sides and
/// a kiosk. Nothing when there is no plaza.
List<PlazaFurniture> plazaFurnitureFor(FrontierPlaza? plaza) {
  if (plaza == null) return const [];
  final h = plaza.headingRadians;
  final out = <PlazaFurniture>[];
  final lateral = plaza.width / 2 - furnitureInset;
  final reach = plaza.depth / 2 - furnitureInset - furnitureSpacing / 2;
  for (final side in [-1.0, 1.0]) {
    var i = 0;
    for (var along = -reach; along <= reach + 1e-9; along += furnitureSpacing) {
      final bench = i.isEven;
      final (x, z) = _slotToWorld(
        plaza.centerX,
        plaza.centerZ,
        h,
        side * lateral,
        along,
      );
      out.add(
        PlazaFurniture(
          id: 'plaza-${side < 0 ? 'l' : 'r'}-$i',
          kind: bench ? FurnitureKind.bench : FurnitureKind.planter,
          x: x,
          z: z,
          yawRadians: h,
          width: bench ? benchWidth : planterSize,
          depth: bench ? benchLength : planterSize,
          height: bench ? benchHeight : planterHeight,
        ),
      );
      i++;
    }
  }
  // Home's along in the plaza frame, from its world pose.
  final homeAlong =
      (plaza.home.x - plaza.centerX) * math.sin(h) +
      (plaza.home.z - plaza.centerZ) * math.cos(h);
  for (final (side, kind) in [
    (-1.0, FurnitureKind.bench),
    (1.0, FurnitureKind.planter),
  ]) {
    final (nx, nz) = _slotToWorld(
      plaza.centerX,
      plaza.centerZ,
      h,
      side * nearHomeLateral,
      homeAlong - nearHomeAhead,
    );
    final bench = kind == FurnitureKind.bench;
    out.add(
      PlazaFurniture(
        id: 'plaza-near-${side < 0 ? 'l' : 'r'}',
        kind: kind,
        x: nx,
        z: nz,
        // The bench sits across the axis, facing the pylons.
        yawRadians: bench ? h + math.pi / 2 : h,
        width: bench ? benchWidth : planterSize,
        depth: bench ? benchLength : planterSize,
        height: bench ? benchHeight : planterHeight,
      ),
    );
  }
  final (kx, kz) = _slotToWorld(
    plaza.centerX,
    plaza.centerZ,
    h,
    kioskLateral,
    kioskAlong,
  );
  out.add(
    PlazaFurniture(
      id: 'plaza-kiosk',
      kind: FurnitureKind.kiosk,
      x: kx,
      z: kz,
      // Its front faces the plaza's axis.
      yawRadians: h + math.pi / 2,
      width: kioskWidth,
      depth: kioskDepth,
      height: kioskHeight,
    ),
  );
  return out;
}

/// All the seeded dressing for [plan].
Scenery sceneryFor(
  StreetPlan plan, {
  required FrontierPlaza? plaza,
  required BillboardSlot? jumbotron,
  required double roadWidth,
  required double plotDepth,
}) => Scenery(
  fillers: fillerBlocksFor(
    plan,
    plaza,
    roadWidth: roadWidth,
    plotDepth: plotDepth,
  ),
  heroTowers: heroTowersFor(plan),
  jumbotronTower: jumbotronTowerFor(jumbotron),
  skyline: skylineFor(plan, plaza),
  furniture: plazaFurnitureFor(plaza),
);

/// A pylon's two posts stand this far behind the panel's plane and this
/// fraction of its width out from its centre; each post is
/// [pylonPostSize] square on a [pylonFootingSize] square footing.
const pylonPostSetback = 0.6;
const pylonPostSpread = 0.4;
const pylonPostSize = 0.6;
const pylonFootingSize = 1.6;

/// Local (x, z) in a slot's frame to the world.
(double, double) _slotToWorld(
  double x,
  double z,
  double facing,
  double lx,
  double lz,
) {
  final sinF = math.sin(facing);
  final cosF = math.cos(facing);
  return (x + lx * cosF + lz * sinF, z - lx * sinF + lz * cosF);
}

/// The footings of every pylon in [pylons], two per slot.
List<Footprint> pylonFootprintsFor(Iterable<BillboardSlot> pylons) => [
  for (final slot in pylons)
    for (final side in [-1.0, 1.0])
      () {
        final (x, z) = _slotToWorld(
          slot.x,
          slot.z,
          slot.facingRadians,
          side * slot.width * pylonPostSpread,
          -pylonPostSetback,
        );
        return Footprint(
          x: x,
          z: z,
          facingRadians: slot.facingRadians,
          width: pylonFootingSize,
          depth: pylonFootingSize,
        );
      }(),
];

/// The gantry's legs are this square, at either end of its span.
const gantryLegSize = 0.5;

/// The two legs of the ticker gantry.
List<Footprint> gantryLegFootprintsFor(TickerSlot gantry) => [
  for (final side in [-1.0, 1.0])
    () {
      final (x, z) = _slotToWorld(
        gantry.x,
        gantry.z,
        gantry.facingRadians,
        side * gantry.width / 2,
        0,
      );
      return Footprint(
        x: x,
        z: z,
        facingRadians: gantry.facingRadians,
        width: gantryLegSize,
        depth: gantryLegSize,
      );
    }(),
];

/// A lamp post's pole is this square.
const lampPostSize = 0.16;

/// One footprint per lamp post.
List<Footprint> lampPostFootprintsFor(Iterable<(double, double)> posts) => [
  for (final (x, z) in posts)
    Footprint(
      x: x,
      z: z,
      facingRadians: 0,
      width: lampPostSize,
      depth: lampPostSize,
    ),
];
