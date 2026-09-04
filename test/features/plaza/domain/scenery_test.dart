import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/scenery.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

import '../plaza_fixtures.dart';

/// Local (along, lateral) of a world point in a segment's frame.
(double, double) _inSegment(RoadSegment s, double x, double z) {
  final sinH = math.sin(s.headingRadians);
  final cosH = math.cos(s.headingRadians);
  final dx = x - s.startX;
  final dz = z - s.startZ;
  return (dx * sinH + dz * cosH, dx * cosH - dz * sinH);
}

/// A slot's frame: world position of local (lx, lz).
(double, double) _fromSlot(
  double x,
  double z,
  double facing,
  double lx,
  double lz,
) => (
  x + lx * math.cos(facing) + lz * math.sin(facing),
  z - lx * math.sin(facing) + lz * math.cos(facing),
);

void main() {
  final layout = StreetLayout(projectSeed: 1337);
  final tasks = syntheticPlazaTasks();
  final plan = layout.plan(tasks);
  final plaza = frontierPlazaFor(plan)!;
  final jumbotron = jumbotronSlotFor(plan)!;
  final scenery = sceneryFor(
    plan,
    plaza: plaza,
    jumbotron: jumbotron,
    roadWidth: layout.roadWidth,
    plotDepth: layout.plotDepth,
  );

  group('fillerBlocksFor', () {
    final fillers = scenery.fillers;
    final segmentsByBucket = {
      for (final s in plan.segments)
        if (!s.isGap && !s.isConnector) s.bucketIndex: s,
    };

    test('stands behind the plots of its own built row, never on a gap', () {
      expect(fillers, isNotEmpty);
      final lateralBase =
          layout.roadWidth / 2 + layout.plotDepth + fillerSetback;
      for (final f in fillers) {
        final segment = segmentsByBucket[f.bucketIndex];
        expect(segment, isNotNull, reason: '${f.id} is on a gap or connector');
        final (along, lateral) = _inSegment(segment!, f.x, f.z);
        expect(f.yawRadians, segment.headingRadians);
        // The near face is at least the setback past the plots' back line.
        expect(
          lateral.abs() - f.width / 2,
          greaterThanOrEqualTo(lateralBase - 1e-9),
          reason: f.id,
        );
        expect(lateral.sign, f.side, reason: f.id);
        // Whole frontage inside the row.
        expect(along - f.depth / 2, greaterThanOrEqualTo(2 - 1e-9));
        expect(along + f.depth / 2, lessThanOrEqualTo(segment.length - 1));
      }
    });

    test('stands in no street: the folds bring the rows within reach', () {
      final corridors = [
        for (final s in plan.segments)
          streetCorridorFor(
            s,
            roadWidth: layout.roadWidth,
            plotDepth: layout.plotDepth,
          ),
      ];
      // A corridor is the road with its plots, or the road alone.
      final row = plan.segments.firstWhere((s) => !s.isGap);
      final link = plan.segments.firstWhere((s) => s.isConnector);
      expect(
        streetCorridorFor(row, roadWidth: 18, plotDepth: 10).width,
        18 + 20 + 2 * fillerCorridorMargin,
      );
      expect(
        streetCorridorFor(link, roadWidth: 18, plotDepth: 10).width,
        18 + 2 * fillerCorridorMargin,
      );
      expect(
        streetCorridorFor(row, roadWidth: 18, plotDepth: 10).depth,
        row.length + 2 * fillerCorridorMargin,
      );
      for (final f in fillers) {
        expect(f.width, greaterThanOrEqualTo(fillerMinReach), reason: f.id);
        for (final c in corridors) {
          expect(footprintsOverlap(f.footprint, c), isFalse, reason: f.id);
        }
      }
      // With the default fold the rows leave no room at all: the sides
      // facing another row carry nothing, the outer sides still do.
      final sides = [
        for (final s in segmentsByBucket.values)
          for (final side in [-1.0, 1.0])
            fillers.where(
              (f) => f.bucketIndex == s.bucketIndex && f.side == side,
            ),
      ];
      expect(sides.where((s) => s.isEmpty), isNotEmpty);
      expect(sides.where((s) => s.isNotEmpty), isNotEmpty);
    });

    test('a wider fold leaves room: blocks are cut back, not dropped', () {
      final wide = StreetLayout(projectSeed: 1337, connectorLength: 60);
      final widePlan = wide.plan(tasks);
      final cut = fillerBlocksFor(
        widePlan,
        null,
        roadWidth: wide.roadWidth,
        plotDepth: wide.plotDepth,
      );
      final corridors = [
        for (final s in widePlan.segments)
          streetCorridorFor(
            s,
            roadWidth: wide.roadWidth,
            plotDepth: wide.plotDepth,
          ),
      ];
      for (final f in cut) {
        for (final c in corridors) {
          expect(footprintsOverlap(f.footprint, c), isFalse, reason: f.id);
        }
      }
      // Some blocks stand narrower than seeded, and none narrower than the
      // minimum: cut to the alley short of the next row, not thrown away.
      final seeded = {for (final f in cut) f.id: 8 + stableUnit(f.id, 'd') * 8};
      expect(cut.where((f) => f.width < seeded[f.id]! - 1e-9), isNotEmpty);
      expect(cut.every((f) => f.width >= fillerMinReach), isTrue);
    });

    test('leaves an alley of at least two metres between neighbours', () {
      for (final segment in segmentsByBucket.values) {
        for (final side in [-1.0, 1.0]) {
          final row =
              fillers
                  .where(
                    (f) =>
                        f.bucketIndex == segment.bucketIndex && f.side == side,
                  )
                  .map((f) => (_inSegment(segment, f.x, f.z).$1, f.depth))
                  .toList()
                ..sort((a, b) => a.$1.compareTo(b.$1));
          for (var i = 0; i + 1 < row.length; i++) {
            final end = row[i].$1 + row[i].$2 / 2;
            final next = row[i + 1].$1 - row[i + 1].$2 / 2;
            expect(next - end, greaterThanOrEqualTo(2 - 1e-9));
          }
        }
      }
    });

    test('keeps off the plaza and its margin', () {
      final sinH = math.sin(plaza.headingRadians);
      final cosH = math.cos(plaza.headingRadians);
      for (final f in fillers) {
        final dx = f.x - plaza.centerX;
        final dz = f.z - plaza.centerZ;
        final along = dx * sinH + dz * cosH;
        final lateral = dx * cosH - dz * sinH;
        final onPlaza =
            along.abs() < plaza.depth / 2 + fillerPlazaMargin &&
            lateral.abs() < plaza.width / 2 + fillerPlazaMargin;
        expect(onPlaza, isFalse, reason: f.id);
      }
      // The exclusion is real: a plaza dropped onto a filler removes that
      // filler, and its margin, and nothing else.
      final victim = fillers[fillers.length ~/ 2];
      final dropped = FrontierPlaza(
        centerX: victim.x,
        centerZ: victim.z,
        headingRadians: victim.yawRadians,
        width: 1,
        depth: 1,
        home: plaza.home,
        overview: plaza.overview,
        pylons: const [],
      );
      final fenced = fillerBlocksFor(
        plan,
        dropped,
        roadWidth: layout.roadWidth,
        plotDepth: layout.plotDepth,
      );
      final ids = fenced.map((f) => f.id).toSet();
      expect(ids, isNot(contains(victim.id)));
      for (final f in fillers) {
        final dx = f.x - victim.x;
        final dz = f.z - victim.z;
        final far =
            math.sqrt(dx * dx + dz * dz) > 0.5 + fillerPlazaMargin * math.sqrt2;
        if (far) expect(ids, contains(f.id), reason: f.id);
      }
      expect(fenced.length, lessThan(fillers.length));
    });

    test('sizes stay inside the seeded ranges and never move', () {
      for (final f in fillers) {
        expect(f.depth, inInclusiveRange(7, 16));
        expect(f.width, inInclusiveRange(8, 16));
        expect(f.height, inInclusiveRange(12, 60));
      }
      // The fabric is the tall layer: a quarter are mid-rise landmarks
      // above every plot, the rest still rise over the shops.
      final landmarks = fillers.where((f) => f.height >= 40);
      expect(landmarks.length, greaterThan(fillers.length ~/ 8));
      expect(landmarks.length, lessThan(fillers.length ~/ 2));
      final again = fillerBlocksFor(
        plan,
        plaza,
        roadWidth: layout.roadWidth,
        plotDepth: layout.plotDepth,
      );
      expect(again.map((f) => f.id), fillers.map((f) => f.id));
      for (final (a, b) in [
        for (var i = 0; i < fillers.length; i++) (fillers[i], again[i]),
      ]) {
        expect(b.x, a.x);
        expect(b.z, a.z);
      }
    });
  });

  group('heroTowersFor', () {
    test('one per folding row, on its axis, facing back down it', () {
      final towers = scenery.heroTowers;
      final connectors = plan.segments.where((s) => s.isConnector).toList();
      expect(connectors, isNotEmpty);
      expect(towers, hasLength(connectors.length));
      for (final tower in towers) {
        final row = plan.segments.firstWhere(
          (s) => s.bucketIndex == tower.bucketIndex && !s.isConnector,
        );
        expect(
          tower.x,
          closeTo(
            row.endX + math.sin(row.headingRadians) * heroTowerStandOff,
            1e-9,
          ),
        );
        expect(
          tower.z,
          closeTo(
            row.endZ + math.cos(row.headingRadians) * heroTowerStandOff,
            1e-9,
          ),
        );
        expect(tower.yawRadians, row.headingRadians + math.pi);
        expect(tower.width, inInclusiveRange(26, 34));
        expect(tower.depth, closeTo(tower.width * 0.8, 1e-9));
        expect(tower.height, inInclusiveRange(70, 86));
      }
    });

    test('a straight street has none', () {
      final short = layout.plan(tasks.take(6).toList());
      expect(short.segments.any((s) => s.isConnector), isFalse);
      expect(heroTowersFor(short), isEmpty);
    });
  });

  group('jumbotronTowerFor', () {
    test('a box behind the screen, wider and taller than it', () {
      final tower = scenery.jumbotronTower!;
      final (x, z) = _fromSlot(
        jumbotron.x,
        jumbotron.z,
        jumbotron.facingRadians,
        0,
        -jumbotronTowerSetback,
      );
      expect(tower.x, closeTo(x, 1e-9));
      expect(tower.z, closeTo(z, 1e-9));
      expect(tower.yawRadians, jumbotron.facingRadians);
      expect(tower.width, jumbotron.width + 2 * jumbotronTowerMargin);
      expect(tower.depth, jumbotronTowerDepth);
      expect(
        tower.height,
        jumbotron.bottom + jumbotron.height + jumbotronTowerCrown,
      );
    });

    test('none without a jumbotron', () {
      expect(jumbotronTowerFor(null), isNull);
    });
  });

  group('skylineFor', () {
    test('a ring beyond every plot and the plaza, in index order', () {
      final ring = scenery.skyline;
      expect(ring, hasLength(skylineTowerCount));
      final (cx, cz) = planCenterOf(plan);
      var reach = 0.0;
      for (final p in plan.placements.values) {
        reach = math.max(
          reach,
          math.sqrt(math.pow(p.x - cx, 2) + math.pow(p.z - cz, 2)),
        );
      }
      final plazaReach = math.sqrt(
        math.pow(plaza.centerX - cx, 2) + math.pow(plaza.centerZ - cz, 2),
      );
      final inner = math.max(reach, plazaReach + 60) + skylineRingClearance;
      for (final (i, tower) in ring.indexed) {
        expect(tower.index, i);
        final r = math.sqrt(
          math.pow(tower.x - cx, 2) + math.pow(tower.z - cz, 2),
        );
        expect(
          r,
          inInclusiveRange(inner - 1e-9, inner + 90 + 1e-9),
          reason: tower.id,
        );
        final angle = math.atan2(tower.z - cz, tower.x - cx);
        // Within the seeded jitter of its slot on the ring.
        final slot = i / skylineTowerCount * 2 * math.pi;
        final delta = (angle - slot + math.pi) % (2 * math.pi) - math.pi;
        expect(delta, inInclusiveRange(-1e-9, 0.1 + 1e-9), reason: tower.id);
        expect(tower.yawRadians, closeTo(-slot - delta, 1e-9));
        expect(tower.width, inInclusiveRange(16, 42));
        expect(tower.depth, closeTo(tower.width * 0.8, 1e-9));
        expect(tower.height, inInclusiveRange(24, 78));
      }
    });

    test('an empty street rings the origin', () {
      final empty = layout.plan(const []);
      expect(planCenterOf(empty), (0, 0));
      final ring = skylineFor(empty, null);
      for (final tower in ring) {
        final r = math.sqrt(tower.x * tower.x + tower.z * tower.z);
        expect(
          r,
          inInclusiveRange(
            skylineRingClearance - 1e-9,
            skylineRingClearance + 90 + 1e-9,
          ),
        );
      }
    });
  });

  group('plazaFurnitureFor', () {
    test('benches and planters down both sides, a kiosk in a corner', () {
      final furniture = scenery.furniture;
      final sinH = math.sin(plaza.headingRadians);
      final cosH = math.cos(plaza.headingRadians);
      (double, double) local(PlazaFurniture f) {
        final dx = f.x - plaza.centerX;
        final dz = f.z - plaza.centerZ;
        return (dx * cosH - dz * sinH, dx * sinH + dz * cosH);
      }

      final kiosks = furniture.where((f) => f.kind == FurnitureKind.kiosk);
      expect(kiosks, hasLength(1));
      final (kl, ka) = local(kiosks.single);
      expect(kl, closeTo(kioskLateral, 1e-9));
      expect(ka, closeTo(kioskAlong, 1e-9));
      expect(kiosks.single.yawRadians, plaza.headingRadians + math.pi / 2);
      expect(kiosks.single.height, kioskHeight);

      // The foreground pair: a bench and a planter a few metres ahead of
      // home, either side of the axis.
      final near = furniture.where((f) => f.id.startsWith('plaza-near'));
      expect(near, hasLength(2));
      final homeAlong =
          (plaza.home.x - plaza.centerX) * sinH +
          (plaza.home.z - plaza.centerZ) * cosH;
      for (final f in near) {
        final (lateral, along) = local(f);
        expect(lateral.abs(), closeTo(nearHomeLateral, 1e-9));
        expect(along, closeTo(homeAlong - nearHomeAhead, 1e-9));
      }
      expect(near.map((f) => f.kind).toSet(), hasLength(2));

      final sides = furniture.where(
        (f) => f.kind != FurnitureKind.kiosk && !f.id.startsWith('plaza-near'),
      );
      expect(sides.length, greaterThanOrEqualTo(8));
      for (final f in sides) {
        final (lateral, along) = local(f);
        expect(lateral.abs(), closeTo(plaza.width / 2 - furnitureInset, 1e-9));
        expect(along.abs(), lessThan(plaza.depth / 2 - furnitureInset));
        expect(f.yawRadians, plaza.headingRadians);
        if (f.kind == FurnitureKind.bench) {
          expect(
            (f.width, f.depth, f.height),
            (benchWidth, benchLength, benchHeight),
          );
        } else {
          expect(
            (f.width, f.depth, f.height),
            (planterSize, planterSize, planterHeight),
          );
        }
      }
      // Alternating, and the same on both sides.
      for (final side in [-1.0, 1.0]) {
        final row = sides.where((f) => local(f).$1.sign == side).toList()
          ..sort((a, b) => local(a).$2.compareTo(local(b).$2));
        expect(row.length, greaterThanOrEqualTo(4));
        for (var i = 0; i + 1 < row.length; i++) {
          expect(row[i].kind, isNot(row[i + 1].kind));
          expect(
            local(row[i + 1]).$2 - local(row[i]).$2,
            closeTo(furnitureSpacing, 1e-9),
          );
        }
      }
      expect(furniture.map((f) => f.id).toSet(), hasLength(furniture.length));
    });

    test('nothing on the home pose or in front of a pylon panel', () {
      final home = plaza.home;
      for (final f in scenery.furniture) {
        final dx = f.x - home.x;
        final dz = f.z - home.z;
        final d = math.sqrt(dx * dx + dz * dz);
        expect(d, greaterThan(4), reason: f.id);
        // Seen from home, the top of every piece sits below the bottom
        // edge of every pylon panel in the same direction, so nothing on
        // the ground hides a billboard.
        final top = math.atan2(f.height - home.y, d);
        for (final pylon in plaza.pylons) {
          final px = pylon.x - home.x;
          final pz = pylon.z - home.z;
          final pd = math.sqrt(px * px + pz * pz);
          final bearingGap =
              ((math.atan2(dx, dz) - math.atan2(px, pz)) + math.pi) %
                  (2 * math.pi) -
              math.pi;
          final panelHalfAngle = math.atan2(pylon.width / 2, pd);
          if (bearingGap.abs() > panelHalfAngle + 0.05) continue;
          final panelBottom = math.atan2(pylon.bottom - home.y, pd);
          expect(
            top,
            lessThan(panelBottom),
            reason: '${f.id} hides pylon ${pylon.rank}',
          );
        }
      }
    });

    test('none without a plaza', () {
      expect(plazaFurnitureFor(null), isEmpty);
    });
  });

  test('planCenterOf is the mean of the segment starts', () {
    final (cx, cz) = planCenterOf(plan);
    final n = plan.segments.length;
    expect(
      cx,
      closeTo(plan.segments.fold<double>(0, (s, e) => s + e.startX) / n, 1e-9),
    );
    expect(
      cz,
      closeTo(plan.segments.fold<double>(0, (s, e) => s + e.startZ) / n, 1e-9),
    );
  });

  test('Scenery.boxes is every box, in one list', () {
    expect(
      scenery.boxes.length,
      scenery.fillers.length +
          scenery.heroTowers.length +
          1 +
          scenery.skyline.length +
          scenery.furniture.length,
    );
    expect(
      scenery.boxes.map((b) => b.id).toSet(),
      hasLength(scenery.boxes.length),
    );
    final box = scenery.fillers.first;
    final footprint = box.footprint;
    expect(footprint.x, box.x);
    expect(footprint.z, box.z);
    expect(footprint.facingRadians, box.yawRadians);
    expect(footprint.width, box.width);
    expect(footprint.depth, box.depth);
    final without = Scenery(
      fillers: const [],
      heroTowers: const [],
      jumbotronTower: null,
      skyline: scenery.skyline,
      furniture: const [],
    );
    expect(without.boxes, hasLength(skylineTowerCount));
  });

  group('furniture solids', () {
    const slot = BillboardSlot(
      rank: 0,
      x: 0,
      z: 0,
      facingRadians: 0,
      width: 10,
      height: 6,
      bottom: 4,
      mount: BillboardMount.pylon,
    );

    test('a pylon is two posts on footings behind the panel and the sign', () {
      final solids = pylonSolidsFor([slot]);
      expect(solids, hasLength(3));
      final posts = solids.take(2).toList();
      expect(posts.map((s) => s.footprint.x), [-4, 4]);
      for (final post in posts) {
        expect(post.footprint.z, -pylonPostSetback);
        expect(post.footprint.width, pylonFootingSize);
        expect(post.footprint.depth, pylonFootingSize);
        expect(post.footprint.facingRadians, 0);
        expect(post.bottom, 0);
        expect(post.top, slot.bottom);
        expect(post.atWalkHeight, isTrue);
      }
      final sign = solids.last;
      expect(sign.footprint.x, 0);
      expect(sign.footprint.z, 0);
      expect(sign.footprint.width, 10);
      expect(sign.footprint.depth, signDepth);
      expect(sign.bottom, 4);
      expect(sign.top, 10);
      // The walker passes under the sign between the posts; a flight
      // cannot pass through it.
      expect(sign.atWalkHeight, isFalse);
      expect(sign.contains(0, eyeHeight, 0), isFalse);
      expect(sign.contains(0, 7, 0), isTrue);
    });

    glados.Glados3<double, double, double>(
      glados.any.doubleInRange(-500, 500),
      glados.any.doubleInRange(-500, 500),
      glados.any.doubleInRange(-math.pi, math.pi),
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'pylon posts, signs, gantry legs and beams turn with their slot',
      (x, z, facing) {
        final slot = BillboardSlot(
          rank: 0,
          x: x,
          z: z,
          facingRadians: facing,
          width: 12,
          height: 6,
          bottom: 4,
          mount: BillboardMount.pylon,
        );
        final pylon = pylonSolidsFor([slot]);
        for (final (i, side) in [-1.0, 1.0].indexed) {
          final (fx, fz) = _fromSlot(
            x,
            z,
            facing,
            side * 12 * pylonPostSpread,
            -pylonPostSetback,
          );
          final post = pylon[i].footprint;
          expect(post.x, closeTo(fx, 1e-6), reason: '$x $z $facing');
          expect(post.z, closeTo(fz, 1e-6), reason: '$x $z $facing');
          expect(post.facingRadians, facing);
        }
        expect(pylon[2].footprint.facingRadians, facing);
        expect(pylon[2].footprint.x, x);
        expect(pylon[2].footprint.z, z);
        final gantry = TickerSlot(
          x: x,
          z: z,
          facingRadians: facing,
          width: 22,
          height: 1.8,
          bottom: 10.5,
          speedMetersPerSecond: 4,
        );
        final parts = gantrySolidsFor(gantry);
        expect(parts, hasLength(3));
        for (final (i, side) in [-1.0, 1.0].indexed) {
          final (lx, lz) = _fromSlot(x, z, facing, side * 11, 0);
          final leg = parts[i];
          expect(leg.footprint.x, closeTo(lx, 1e-6), reason: '$x $z $facing');
          expect(leg.footprint.z, closeTo(lz, 1e-6), reason: '$x $z $facing');
          expect(leg.footprint.width, gantryLegSize);
          expect(leg.footprint.depth, gantryLegSize);
          expect(leg.bottom, 0);
          expect(leg.top, gantryTopFor(gantry));
        }
        final beam = parts[2];
        expect(beam.footprint.x, x);
        expect(beam.footprint.z, z);
        expect(beam.footprint.facingRadians, facing);
        expect(beam.footprint.width, 22 + gantryLegSize);
        expect(beam.footprint.depth, gantryBeamDepth);
        expect(beam.bottom, 10.5);
        expect(beam.top, gantryTopFor(gantry));
      },
      tags: 'glados',
    );

    test('the gantry beam spans the street above the walker', () {
      const gantry = TickerSlot(
        x: 0,
        z: 0,
        facingRadians: 0,
        width: 22,
        height: 1.8,
        bottom: 10.5,
        speedMetersPerSecond: 4,
      );
      expect(gantryTopFor(gantry), closeTo(12.7, 1e-9));
      final beam = gantrySolidsFor(gantry).last;
      expect(beam.atWalkHeight, isFalse);
      expect(beam.contains(5, eyeHeight, 0), isFalse);
      expect(beam.contains(5, 11, 0), isTrue);
      expect(beam.contains(11.5, 11, 0), isFalse);
    });

    test('lamp posts are a small square each, as tall as the pole', () {
      final posts = lampPostSolidsFor([(1, 2), (3, 4)]);
      expect(posts.map((p) => (p.footprint.x, p.footprint.z)), [
        (1, 2),
        (3, 4),
      ]);
      for (final p in posts) {
        expect(p.footprint.width, lampPostSize);
        expect(p.footprint.depth, lampPostSize);
        expect(p.bottom, 0);
        expect(p.top, lampPostHeight);
      }
    });

    test('a roof panel is a sign standing on the roof', () {
      const panel = BillboardSlot(
        rank: 0,
        x: 3,
        z: 4,
        facingRadians: 1,
        width: 9,
        height: 4,
        bottom: 30.5,
        mount: BillboardMount.roof,
      );
      final sign = signSolidFor(panel);
      expect(sign.footprint.x, 3);
      expect(sign.footprint.z, 4);
      expect(sign.footprint.facingRadians, 1);
      expect(sign.footprint.width, 9);
      expect(sign.footprint.depth, signDepth);
      expect(sign.bottom, 30.5);
      expect(sign.top, 34.5);
      expect(sign.atWalkHeight, isFalse);
    });
  });

  group('spires and the roof kit', () {
    test('a plot is solid up to its roof kit, and may carry a spire', () {
      const p = PlotPlacement(
        taskId: 't',
        bucketIndex: 0,
        side: PlotSide.left,
        x: 1,
        z: 2,
        facingRadians: 0.5,
        width: 8,
        depth: 8,
        height: 30,
      );
      final solid = plotSolidFor(p);
      expect(solid.footprint.x, 1);
      expect(solid.footprint.z, 2);
      expect(solid.footprint.width, 8);
      expect(solid.bottom, 0);
      expect(solid.top, 30 + roofKitHeight);
      final spire = plotSpireSolidFor(p);
      expect(spire.footprint.x, 1);
      expect(spire.footprint.z, 2);
      expect(spire.footprint.facingRadians, 0.5);
      expect(spire.footprint.width, plotSpireSize);
      expect(spire.footprint.depth, plotSpireSize);
      expect(spire.bottom, 30);
      expect(spire.top, 30 + plotSpireHeight);
      expect(spire.atWalkHeight, isFalse);
    });

    test('hero towers and the jumbotron tower add spires; fillers do not', () {
      const hero = HeroTower(
        id: 'h',
        bucketIndex: 0,
        x: 0,
        z: 0,
        yawRadians: 0,
        width: 20,
        depth: 20,
        height: 60,
      );
      expect(hero.solids, hasLength(2));
      expect(hero.solids.first.top, 60);
      expect(hero.solids.first.bottom, 0);
      final spire = hero.solids.last;
      expect(spire.bottom, 60);
      expect(spire.top, 60 + heroSpireHeight);
      expect(spire.footprint.width, heroSpireSize);
      expect(spire.footprint.depth, heroSpireSize);
      final tower = scenery.jumbotronTower!;
      expect(tower.solids, hasLength(2));
      expect(tower.solids.first.top, tower.height);
      expect(tower.solids.last.bottom, tower.height);
      expect(tower.solids.last.top, tower.height + jumbotronSpireHeight);
      expect(tower.solids.last.footprint.depth, jumbotronSpireSize);
      expect(scenery.fillers.first.solids, hasLength(1));
      expect(
        scenery.solids.length,
        scenery.boxes.length + scenery.heroTowers.length + 1,
      );
    });
  });
}
