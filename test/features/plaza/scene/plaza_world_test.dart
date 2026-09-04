import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/flight.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/scenery.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';

import '../plaza_fixtures.dart';

void main() {
  final tasks = syntheticPlazaTasks();
  final world = PlazaWorld(
    tasks: tasks,
    now: syntheticNow(tasks),
    projectLabel: 'Synthetic',
    layout: StreetLayout(projectSeed: 1337),
    categoryLabels: {0xFF5C9DFF.toRadixString(16): 'work'},
  );

  test('derives plan, plaza, attention, beacons and billboards once', () {
    expect(world.plan.placements.length, tasks.length);
    expect(world.plaza, isNotNull);
    expect(world.attention.length, tasks.length);
    expect(world.anomalies, everyElement((TaskAttention a) => a.anomalous));
    expect(world.billboards.length, lessThanOrEqualTo(billboardSlots));
    expect(world.beacons.first.kind, BeaconKind.home);
    expect(
      world.beacons.where((b) => b.kind == BeaconKind.attention).length,
      world.anomalies.length,
    );
  });

  test('billboard slots are pylons then mounted screens, rank order', () {
    final ranks = world.billboardSlots.map((s) => s.rank).toList();
    expect(ranks, [0, 1, 2, 3, 4, 5]);
    expect(world.billboardSlots.take(4).every((s) => s.onPylon), isTrue);
    expect(world.mountedScreens.every((s) => !s.onPylon), isTrue);
    // Only as many slots are built as there are candidates, in rank order.
    expect(world.builtBillboardSlots, hasLength(world.billboards.length));
    expect(
      world.builtBillboardSlots.map((s) => s.rank),
      ranks.take(world.billboards.length),
    );
    final quiet = PlazaWorld(
      tasks: tasks.take(3).toList(),
      now: syntheticNow(tasks),
      projectLabel: 'Quiet',
      layout: StreetLayout(projectSeed: 1337),
    );
    expect(quiet.builtBillboardSlots.length, quiet.billboards.length);
    expect(quiet.builtBillboardSlots.length, lessThan(billboardSlots));
  });

  group('solids', () {
    bool inside(Footprint f, double x, double z) {
      final sinF = math.sin(f.facingRadians);
      final cosF = math.cos(f.facingRadians);
      final dx = x - f.x;
      final dz = z - f.z;
      final v = dx * sinF + dz * cosF;
      final u = dx * cosF - dz * sinF;
      return u.abs() < f.width / 2 && v.abs() < f.depth / 2;
    }

    void expectSolid(Footprint f, String what) {
      // A walker standing at the footprint's centre is pushed out of it.
      final (x, z) = world.collider.resolve(f.x, f.z);
      expect((x, z), isNot((f.x, f.z)), reason: '$what is walk-through');
      expect(inside(f, x, z), isFalse, reason: '$what still holds the walker');
    }

    test('every scenery box is solid, not just the plots', () {
      final scenery = world.scenery;
      expect(scenery.fillers, isNotEmpty);
      expect(scenery.heroTowers, isNotEmpty);
      expect(scenery.jumbotronTower, isNotNull);
      expect(scenery.skyline, hasLength(skylineTowerCount));
      for (final box in scenery.boxes) {
        expectSolid(box.footprint, box.id);
      }
      for (final p in world.plan.placements.values) {
        expectSolid(p.footprint, p.taskId);
      }
    });

    test(
      'the pylon posts, the gantry legs and the lamp posts are solid; the '
      'signs and the beam hang above the walker, for the flights',
      () {
        final pylons = world.builtBillboardSlots.where((s) => s.onPylon);
        expect(pylons, isNotEmpty);
        for (final s in pylonSolidsFor(pylons)) {
          final f = s.footprint;
          if (s.atWalkHeight) {
            expectSolid(f, 'pylon post at ${f.x}, ${f.z}');
          } else {
            // Under the sign, between the posts, the walker stands; the
            // sign itself is a solid the world knows.
            expect(world.collider.resolve(f.x, f.z), (f.x, f.z));
            expect(
              world.solids.any(
                (w) => w.contains(f.x, (s.bottom + s.top) / 2, f.z),
              ),
              isTrue,
            );
          }
        }
        final gantry = gantrySolidsFor(world.gantry!);
        for (final leg in gantry.take(2)) {
          final f = leg.footprint;
          expectSolid(f, 'gantry leg at ${f.x}, ${f.z}');
        }
        final beam = gantry.last.footprint;
        expect(world.collider.resolve(beam.x, beam.z), (beam.x, beam.z));
        expect(
          world.solids.any(
            (s) => s.contains(beam.x, world.gantry!.bottom + 1, beam.z),
          ),
          isTrue,
        );
        for (final s in lampPostSolidsFor(world.lampPosts)) {
          final f = s.footprint;
          expectSolid(f, 'lamp post at ${f.x}, ${f.z}');
        }
        expect(
          world.solids.length,
          world.plan.placements.length +
              world.spires.length +
              world.scenery.solids.length +
              3 * pylons.length +
              world.roofBillboards.length +
              3 +
              world.lampPosts.length,
        );
        // In the air: the signs, the roof panels, the beam and the spires.
        expect(
          world.solids.where((s) => !s.atWalkHeight).length,
          pylons.length +
              world.roofBillboards.length +
              1 +
              world.spires.length +
              world.scenery.heroTowers.length +
              1,
        );
      },
    );
  });

  group('flights over the district', () {
    /// Whether [f] enters any solid on its way, sampled finely.
    bool passesThrough(Flight f) {
      for (var t = 0.0; t <= 1.0001; t += 0.001) {
        final p = f.poseAt(t);
        if (world.solids.any((s) => s.contains(p.x, p.y, p.z))) return true;
      }
      return false;
    }

    test('every walk stop and beacon on the ground stands clear', () {
      final poses = [
        for (final stop in world.walkStops!) stop.pose,
        for (final beacon in world.beacons) beacon.pose,
      ];
      expect(poses.where((p) => p.y == eyeHeight), hasLength(greaterThan(8)));
      for (final pose in poses) {
        if (pose.y > eyeHeight) continue;
        expect(
          world.collider.resolve(pose.x, pose.z),
          (pose.x, pose.z),
          reason: '$pose stands in a solid',
        );
      }
    });

    test('the morning walk flies over the district, never through it', () {
      final stops = world.walkStops!;
      expect(stops.length, greaterThanOrEqualTo(4));
      var blind = 0;
      for (var i = 1; i < stops.length; i++) {
        final from = stops[i - 1].pose;
        final to = stops[i].pose;
        // Planned blind, the straight line runs through the block.
        if (passesThrough(Flight.plan(from, to))) blind++;
        expect(
          passesThrough(Flight.plan(from, to, solids: world.solids)),
          isFalse,
          reason: '${stops[i - 1].label} → ${stops[i].label}',
        );
      }
      expect(blind, greaterThan(0));
    });

    test('between two stops on the ground the walk follows the street', () {
      final stops = world.walkStops!;
      final network = world.network!;
      var routed = 0;
      for (var i = 1; i < stops.length; i++) {
        final from = stops[i - 1].pose;
        final to = stops[i].pose;
        if (from.y > eyeHeight || to.y > eyeHeight) continue;
        final f = Flight.route(
          from,
          to,
          via: network.pathBetween(
            (from.x, from.z),
            (to.x, to.z),
            join: Flight.joinDistance,
          ),
          solids: world.solids,
        );
        routed++;
        final label = '${stops[i - 1].label} → ${stops[i].label}';
        expect(f.legCount, greaterThan(1), reason: label);
        // The street is clear at street height: nothing to lift over.
        expect(f.arc, 0, reason: label);
        expect(passesThrough(f), isFalse, reason: label);
        for (var t = 0.0; t <= 1.0001; t += 0.01) {
          expect(
            f.poseAt(t).y,
            lessThanOrEqualTo(Flight.streetFlightHeight + 1e-9),
            reason: label,
          );
        }
      }
      expect(routed, greaterThanOrEqualTo(3));
    });

    test('cycling the beacons flies over the district too', () {
      final nav = world.beacons
          .where((b) => b.kind != BeaconKind.attention)
          .toList();
      expect(nav.length, greaterThan(3));
      for (var i = 0; i < nav.length; i++) {
        final next = nav[(i + 1) % nav.length];
        expect(
          passesThrough(
            Flight.plan(nav[i].pose, next.pose, solids: world.solids),
          ),
          isFalse,
          reason: '${nav[i].label} → ${next.label}',
        );
      }
    });
  });

  test('tickers: mounted screens, the gantry, and the hero rooflines', () {
    expect(world.gantry, isNotNull);
    expect(world.tickers.length, 3 + world.heroes.length);
    expect(world.heroes.length, lessThanOrEqualTo(2));
    // Heroes are the tallest buildings that carry no roof billboard, so a
    // roofline ticker never covers a billboard.
    final roofed = {
      for (final s in world.roofBillboards) world.anomalies[s.rank].task.id,
    };
    for (final hero in world.heroes) {
      expect(roofed, isNot(contains(hero.task.id)));
    }
    expect(world.countsText, startsWith('Synthetic   ·   '));
    expect(world.countsText, isNot(contains('—')));
  });

  test('labels and counts for the HUD', () {
    expect(world.liveTaskCount, tasks.where((t) => !t.deleted).length);
    expect(
      world.builtWeeks,
      world.plan.segments.where((s) => !s.isGap).length,
    );
    expect(world.weekLabel(0), startsWith('W1 · '));
    expect(world.weekOf(tasks.first), startsWith('W'));
    final work = tasks.firstWhere((t) => t.categoryColor == 0xFF5C9DFF);
    expect(world.categoryLabelOf(work), 'work');
    final other = tasks.firstWhere((t) => t.categoryColor != 0xFF5C9DFF);
    expect(world.categoryLabelOf(other), 'task');
  });

  test('ticker text leads with the project and the attention count', () {
    expect(
      world.tickerText,
      startsWith('Synthetic   ·   ${world.anomalies.length} need attention'),
    );
    expect(world.tickerText, contains('in progress'));
    expect(world.tickerText, endsWith('of ${world.liveTaskCount} done'));
  });

  test('street furniture is derived with the world', () {
    expect(world.jumbotron, isNotNull);
    expect(world.spires, hasLength(2));
    expect(world.lampPosts, isNotEmpty);
    expect(
      world.banners.map((b) => b.taskId).toSet(),
      world.plan.placements.values
          .where((p) => p.height >= 12)
          .map((p) => p.taskId)
          .toSet(),
    );
  });

  test('walk stops exist when there is a plaza', () {
    expect(world.walkStops, isNotNull);
    expect(world.walkStops!.first.pose, world.plaza!.overview);
    final empty = PlazaWorld(
      tasks: const [],
      now: DateTime.utc(2026),
      projectLabel: 'Empty',
      layout: StreetLayout(projectSeed: 1),
    );
    expect(empty.plaza, isNull);
    expect(empty.walkStops, isNull);
    expect(empty.beacons, isEmpty);
  });
}
