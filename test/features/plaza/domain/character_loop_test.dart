import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/plaza/data/demo_world_projection.dart';
import 'package:lotti/features/plaza/domain/character_loop.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';

import '../plaza_fixtures.dart';

void main() {
  const loop = CharacterLoop(
    x: 10,
    z: 20,
    heading: 0,
    radius: 4,
    halfStraight: 6,
  );

  test('advances at running speed and follows the circuit tangent', () {
    final start = loop.at(0);
    final next = loop.at(1);
    expect((start.x, start.z, start.yaw), (14, 14, 0));
    expect(next.z - start.z, closeTo(CharacterLoop.speed, 1e-9));
    expect(next.x, start.x);
    final opposite = loop.at(0, phase: 0.5);
    expect(opposite.x, closeTo(6, 1e-9));
    expect(opposite.z, closeTo(26, 1e-9));
    expect(opposite.yaw, closeTo(-math.pi, 1e-9));
  });

  test('positions and tangents join smoothly, including the loop seam', () {
    for (final distance in [
      0.0,
      12.0,
      12 + 4 * math.pi,
      24 + 4 * math.pi,
      loop.length,
    ]) {
      final seconds = distance / CharacterLoop.speed;
      final a = loop.at(seconds - 1e-5);
      final b = loop.at(seconds + 1e-5);
      expect(a.x, closeTo(b.x, 0.0001));
      expect(a.z, closeTo(b.z, 0.0001));
      expect(math.sin(a.yaw), closeTo(math.sin(b.yaw), 0.0001));
      expect(math.cos(a.yaw), closeTo(math.cos(b.yaw), 0.0001));
    }
  });

  test('empty worlds and obstructed circuits produce no characters', () {
    expect(CharacterLoop.forPlaza(null, const []), isNull);
    final world = PlazaWorld(
      tasks: plazaTasksFromDemoWorld(now: manualDemoNow),
      now: manualDemoNow,
      projectLabel: 'Project Waddle',
      layout: StreetLayout(projectSeed: 1337),
    );
    final circuit = CharacterLoop.forPlaza(world.plaza, world.solids)!;
    final at = circuit.at(0);
    final obstacle = Solid.post(x: at.x, z: at.z, size: 1, top: 1);
    expect(CharacterLoop.forPlaza(world.plaza, [obstacle]), isNull);
    // A high sign is safe to run under.
    expect(
      CharacterLoop.forPlaza(world.plaza, [
        Solid.post(x: at.x, z: at.z, size: 1, bottom: 5, top: 8),
      ]),
      isNotNull,
    );
  });

  for (final folded in [false, true]) {
    test('the ${folded ? 'folded' : 'demo'} circuit clears every solid', () {
      final tasks = folded
          ? syntheticPlazaTasks()
          : plazaTasksFromDemoWorld(now: manualDemoNow);
      final world = PlazaWorld(
        tasks: tasks,
        now: manualDemoNow,
        projectLabel: 'Test plaza',
        layout: StreetLayout(projectSeed: 1337),
      );
      final circuit = CharacterLoop.forPlaza(world.plaza, world.solids)!;
      for (var i = 0; i < 1000; i++) {
        final pose = circuit.at(0, phase: i / 1000);
        expect(world.plaza!.footprint.contains(pose.x, pose.z), isTrue);
        for (final solid in world.solids) {
          if (solid.bottom >= CharacterLoop.height) continue;
          expect(
            solid.footprint.contains(
              pose.x,
              pose.z,
              clearance: CharacterLoop.clearance,
            ),
            isFalse,
            reason: 'sample $i intersects ${solid.footprint}',
          );
        }
      }
    });
  }

  glados.Glados(glados.any.int, glados.ExploreConfig(numRuns: 60)).test(
    'speed and facing agree at arbitrary times; four runners stay apart',
    (value) {
      final seconds = (value % 100000) / 100;
      final a = loop.at(seconds);
      final b = loop.at(seconds + 0.001);
      final dx = b.x - a.x;
      final dz = b.z - a.z;
      expect(
        math.sqrt(dx * dx + dz * dz),
        closeTo(CharacterLoop.speed * 0.001, 1e-6),
      );
      expect(
        dx / (CharacterLoop.speed * 0.001),
        closeTo(math.sin(a.yaw), 0.001),
      );
      expect(
        dz / (CharacterLoop.speed * 0.001),
        closeTo(math.cos(a.yaw), 0.001),
      );
      final next = loop.at(seconds, phase: 0.25);
      expect(
        math.sqrt(math.pow(next.x - a.x, 2) + math.pow(next.z - a.z, 2)),
        greaterThan(2 * CharacterLoop.clearance),
      );
    },
    tags: 'glados',
  );
}
