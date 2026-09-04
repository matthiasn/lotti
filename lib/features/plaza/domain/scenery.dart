/// Set dressing placed by the street plan alone: the filler blocks behind
/// the plots, a hero tower past every row that folds, the tower under the
/// jumbotron and the skyline ring, plus the solids of the pylons, the
/// gantry, the lamp posts, the roof panels and the spires.
///
/// Every solid the scene builds is placed here, in pure Dart, with its
/// height, so the scene, the walker collider and the flight planner read
/// one list and nothing can be walked or flown through. Sizes and
/// positions are seeded by id through [stableUnit], never by task data.
library;

import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
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

  /// The box as the solid it is; a box with a spire adds the spire.
  List<Solid> get solids => [Solid(footprint: footprint, top: height)];

  /// A thin solid standing on the roof, [size] square and [spireHeight]
  /// tall, at the box's centre.
  Solid spireSolid({required double size, required double spireHeight}) =>
      Solid.post(
        x: x,
        z: z,
        facingRadians: yawRadians,
        size: size,
        bottom: height,
        top: height + spireHeight,
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

  @override
  List<Solid> get solids => [
    ...super.solids,
    spireSolid(size: heroSpireSize, spireHeight: heroSpireHeight),
  ];
}

/// The tower the jumbotron hangs on, with its own spire.
class JumbotronTower extends SceneryBox {
  const JumbotronTower({
    required super.id,
    required super.x,
    required super.z,
    required super.yawRadians,
    required super.width,
    required super.depth,
    required super.height,
  });

  @override
  List<Solid> get solids => [
    ...super.solids,
    spireSolid(size: jumbotronSpireSize, spireHeight: jumbotronSpireHeight),
  ];
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
  final JumbotronTower? jumbotronTower;
  final List<SkylineTower> skyline;
  final List<PlazaFurniture> furniture;

  /// Every box.
  List<SceneryBox> get boxes => [
    ...fillers,
    ...heroTowers,
    ?jumbotronTower,
    ...skyline,
    ...furniture,
  ];

  /// Every box as solids, spires included.
  List<Solid> get solids => [for (final box in boxes) ...box.solids];
}

/// Spires: on the two tallest plots, on every hero tower and on the
/// jumbotron tower, each a square post with a blinking light on top.
const plotSpireHeight = 8.0;
const plotSpireSize = 0.4;
const heroSpireHeight = 14.0;
const heroSpireSize = 0.6;
const jumbotronSpireHeight = 10.0;
const jumbotronSpireSize = 0.5;

/// The mast is the tallest piece of a task building's roof kit: a flight
/// over a plot clears the building's height plus this.
const roofKitHeight = 4.4;

/// A task building with room for its roof kit above it.
Solid plotSolidFor(PlotPlacement p) =>
    Solid(footprint: p.footprint, top: p.height + roofKitHeight);

/// The spire on one of the tallest plots (`spiresFor`).
Solid plotSpireSolidFor(PlotPlacement p) => Solid.post(
  x: p.x,
  z: p.z,
  facingRadians: p.facingRadians,
  size: plotSpireSize,
  bottom: p.height,
  top: p.height + plotSpireHeight,
);

/// Fillers stand this far past the plots' back line.
const fillerSetback = 4.0;

/// No filler stands on the plaza or within this margin of it.
const fillerPlazaMargin = 12.0;

/// A filler stops this short of another segment's street corridor, so the
/// alley between them reads; and it needs at least this much reach to be
/// worth standing at all.
const fillerCorridorMargin = 2.0;
const fillerMinReach = 4.0;

/// The ground a segment's street takes, with [fillerCorridorMargin] round
/// it: the road with its plots, or the road alone on a gap or a connector.
Footprint streetCorridorFor(
  RoadSegment segment, {
  required double roadWidth,
  required double plotDepth,
}) {
  final (x, z) = frameToWorld(
    segment.startX,
    segment.startZ,
    segment.headingRadians,
    0,
    segment.length / 2,
  );
  return Footprint(
    x: x,
    z: z,
    facingRadians: segment.headingRadians,
    width:
        (segment.isGap ? roadWidth : roadWidth + 2 * plotDepth) +
        2 * fillerCorridorMargin,
    depth: segment.length + 2 * fillerCorridorMargin,
  );
}

/// A second row of blocks behind the plots with alleys between, so the
/// street has a back and the overview has texture between the plots and
/// the skyline. Seeded per bucket, side and slot; nothing on the plaza,
/// and nothing in any street: the folds bring the rows closer than a
/// filler's reach, so a block that would stand in the next row's corridor
/// is cut back to an alley short of it, or left out when too little of it
/// is left. A dropped block never shifts its neighbours.
List<FillerBlock> fillerBlocksFor(
  StreetPlan plan,
  FrontierPlaza? plaza, {
  required double roadWidth,
  required double plotDepth,
}) {
  final lateralBase = roadWidth / 2 + plotDepth + fillerSetback;
  final corridors = [
    for (final segment in plan.segments)
      streetCorridorFor(segment, roadWidth: roadWidth, plotDepth: plotDepth),
  ];
  final plazaGround = plaza?.footprint;
  bool onPlaza(double x, double z) =>
      plazaGround != null &&
      plazaGround.contains(x, z, clearance: fillerPlazaMargin);

  final blocks = <FillerBlock>[];
  for (final segment in plan.segments) {
    if (segment.isGap) continue;
    for (final side in [-1.0, 1.0]) {
      var along = 2.0;
      var i = 0;
      while (along < segment.length - 4) {
        final id = 'filler-${segment.bucketIndex}-$side-$i';
        final frontage = 7 + stableUnit(id, 'w') * 9;
        if (along + frontage > segment.length - 1) break;
        // The fabric behind the plots is the tall layer: the plots are
        // the shops, the city rises behind them; a quarter are mid-rise
        // landmarks so the roofline behind a row is jagged.
        final tall = stableUnit(id, 'tall') < 0.25;
        final height = tall
            ? 40 + stableUnit(id, 'h') * 20
            : 12 + stableUnit(id, 'h') * 22;
        final inner = lateralBase + stableUnit(id, 'l') * 4;
        FillerBlock at(double reach) {
          final (x, z) = frameToWorld(
            segment.startX,
            segment.startZ,
            segment.headingRadians,
            side * (inner + reach / 2),
            along + frontage / 2,
          );
          return FillerBlock(
            id: id,
            bucketIndex: segment.bucketIndex,
            side: side,
            x: x,
            z: z,
            yawRadians: segment.headingRadians,
            width: reach,
            depth: frontage,
            height: height,
          );
        }

        var block = at(8 + stableUnit(id, 'd') * 8);
        if (!onPlaza(block.x, block.z)) {
          // Cut the reach back, a metre at a time, until the block stands
          // in no street.
          while (block.width >= fillerMinReach &&
              corridors.any((c) => footprintsOverlap(block.footprint, c))) {
            block = at(block.width - 1);
          }
          if (block.width >= fillerMinReach) blocks.add(block);
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
    final (x, z) = frameToWorld(
      row.endX,
      row.endZ,
      row.headingRadians,
      0,
      heroTowerStandOff,
    );
    towers.add(
      HeroTower(
        id: id,
        bucketIndex: row.bucketIndex,
        x: x,
        z: z,
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
JumbotronTower? jumbotronTowerFor(BillboardSlot? jumbotron) {
  if (jumbotron == null) return null;
  final (x, z) = frameToWorld(
    jumbotron.x,
    jumbotron.z,
    jumbotron.facingRadians,
    0,
    -jumbotronTowerSetback,
  );
  return JumbotronTower(
    id: 'jumbotron',
    x: x,
    z: z,
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
    radius = math.max(radius, groundDistanceBetween(cx, cz, p.x, p.z));
  }
  if (plaza != null) {
    radius = math.max(
      radius,
      groundDistanceBetween(cx, cz, plaza.centerX, plaza.centerZ) + 60,
    );
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
  final ground = plaza.footprint;
  final out = <PlazaFurniture>[];
  final lateral = plaza.width / 2 - furnitureInset;
  final reach = plaza.depth / 2 - furnitureInset - furnitureSpacing / 2;
  for (final side in [-1.0, 1.0]) {
    var i = 0;
    for (var along = -reach; along <= reach + 1e-9; along += furnitureSpacing) {
      final bench = i.isEven;
      final (x, z) = ground.toWorld(side * lateral, along);
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
  final (_, homeAlong) = ground.local(plaza.home.x, plaza.home.z);
  for (final (side, kind) in [
    (-1.0, FurnitureKind.bench),
    (1.0, FurnitureKind.planter),
  ]) {
    final (nx, nz) = ground.toWorld(
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
  final (kx, kz) = ground.toWorld(kioskLateral, kioskAlong);
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

/// A billboard's panel, backing and glow, front to back: the depth of a
/// pylon's sign and of a roof panel as a solid.
const signDepth = 0.8;

/// The solids of every pylon in [pylons]: two posts on their footings,
/// ground to the panel's bottom, and the sign itself in the air.
List<Solid> pylonSolidsFor(Iterable<BillboardSlot> pylons) => [
  for (final slot in pylons) ...[
    for (final side in [-1.0, 1.0]) _pylonPost(slot, side),
    signSolidFor(slot),
  ],
];

/// One of a pylon's posts, on its footing, ground to the panel's bottom.
Solid _pylonPost(BillboardSlot slot, double side) {
  final (x, z) = frameToWorld(
    slot.x,
    slot.z,
    slot.facingRadians,
    side * slot.width * pylonPostSpread,
    -pylonPostSetback,
  );
  return Solid.post(
    x: x,
    z: z,
    facingRadians: slot.facingRadians,
    size: pylonFootingSize,
    top: slot.bottom,
  );
}

/// A billboard's sign as a solid: the panel's rectangle, [signDepth]
/// thick, from its bottom edge to its top.
Solid signSolidFor(BillboardSlot slot) => Solid(
  footprint: Footprint(
    x: slot.x,
    z: slot.z,
    facingRadians: slot.facingRadians,
    width: slot.width,
    depth: signDepth,
  ),
  bottom: slot.bottom,
  top: slot.bottom + slot.height,
);

/// The gantry's legs are this square, at either end of its span; the beam
/// over the band is this thick, and this deep front to back.
const gantryLegSize = 0.5;
const gantryBeamThickness = 0.4;
const gantryBeamDepth = 0.5;

/// The top of the gantry: the beam sits on the band.
double gantryTopFor(TickerSlot gantry) =>
    gantry.bottom + gantry.height + gantryBeamThickness;

/// The two legs of the ticker gantry, and the band with its beam spanning
/// the street between them.
List<Solid> gantrySolidsFor(TickerSlot gantry) => [
  for (final side in [-1.0, 1.0]) _gantryLeg(gantry, side),
  Solid(
    footprint: Footprint(
      x: gantry.x,
      z: gantry.z,
      facingRadians: gantry.facingRadians,
      width: gantry.width + gantryLegSize,
      depth: gantryBeamDepth,
    ),
    bottom: gantry.bottom,
    top: gantryTopFor(gantry),
  ),
];

/// One leg of the gantry, at one end of its span.
Solid _gantryLeg(TickerSlot gantry, double side) {
  final (x, z) = frameToWorld(
    gantry.x,
    gantry.z,
    gantry.facingRadians,
    side * gantry.width / 2,
    0,
  );
  return Solid.post(
    x: x,
    z: z,
    facingRadians: gantry.facingRadians,
    size: gantryLegSize,
    top: gantryTopFor(gantry),
  );
}

/// A lamp post's pole is this square and this tall.
const lampPostSize = 0.16;
const lampPostHeight = 5.2;

/// One solid per lamp post.
List<Solid> lampPostSolidsFor(Iterable<(double, double)> posts) => [
  for (final (x, z) in posts)
    Solid.post(x: x, z: z, size: lampPostSize, top: lampPostHeight),
];
