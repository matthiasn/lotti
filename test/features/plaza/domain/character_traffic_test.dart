import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/plaza/data/demo_world_projection.dart';
import 'package:lotti/features/plaza/domain/character_loop.dart';
import 'package:lotti/features/plaza/domain/character_population.dart';
import 'package:lotti/features/plaza/domain/character_traffic.dart';
import 'package:lotti/features/plaza/domain/meerkat_population.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';

void main() {
  TrafficCharacter walker(
    String id,
    CharacterPose Function(double) position, {
    CharacterSpecies species = CharacterSpecies.penguin,
    double speed = 2,
  }) => TrafficCharacter(
    id: id,
    species: species,
    radius: 0.5,
    maxSpeed: speed,
    positionAt: position,
    supportedAt: (time) => time % 0.5 < 0.1,
  );

  void update(
    CharacterTraffic traffic,
    double seconds, {
    bool animate = true,
    bool penguins = true,
    bool meerkats = true,
  }) => traffic.update(
    seconds: seconds,
    animate: animate,
    showPenguins: penguins,
    showMeerkats: meerkats,
  );

  void separated(CharacterTraffic traffic, List<TrafficCharacter> cast) {
    for (var i = 0; i < cast.length; i++) {
      final a = cast[i];
      if (!traffic.visibleFor(a.id)) continue;
      final p = a.positionAt(traffic.clockFor(a.id));
      for (final b in cast.skip(i + 1)) {
        if (!traffic.visibleFor(b.id)) continue;
        final q = b.positionAt(traffic.clockFor(b.id));
        final d = math.sqrt(math.pow(p.x - q.x, 2) + math.pow(p.z - q.z, 2));
        expect(
          d,
          greaterThanOrEqualTo(a.radius + b.radius),
          reason: '${a.id}/${b.id}',
        );
      }
    }
  }

  test('different cadences yield at a crossing and both finish it', () {
    final cast = [
      walker(
        'penguin',
        (t) => CharacterPose(x: t - 4, z: 0, yaw: math.pi / 2),
        speed: 1,
      ),
      walker(
        'meerkat',
        (t) => CharacterPose(x: 0, z: 2 * t - 8, yaw: 0),
        species: CharacterSpecies.meerkat,
      ),
    ];
    final traffic = CharacterTraffic(cast);
    var held = false;
    var previous = 0.0;
    for (var frame = 0; frame <= 600; frame++) {
      update(traffic, frame / 30);
      separated(traffic, cast);
      final time = traffic.clockFor('meerkat');
      if (frame > 5 && time == previous) {
        expect(cast.last.supportedAt(time), isTrue);
        held = true;
      }
      previous = time;
    }
    expect(held, isTrue);
    for (final actor in cast) {
      expect(traffic.clockFor(actor.id), greaterThan(12));
    }
  });

  test('a stationary lookout reserves space until it scampers away', () {
    final cast = [
      walker(
        'lookout',
        (t) => CharacterPose(x: math.max(0, t - 5), z: 0, yaw: math.pi / 2),
        species: CharacterSpecies.meerkat,
        speed: 1,
      ),
      walker('walker', (t) => CharacterPose(x: 0, z: t - 3, yaw: 0), speed: 1),
    ];
    final traffic = CharacterTraffic(cast);
    for (var frame = 0; frame <= 450; frame++) {
      update(traffic, frame / 30);
      separated(traffic, cast);
      if (frame == 120) {
        expect(traffic.clockFor('walker'), lessThan(2));
      }
    }
    expect(traffic.clockFor('walker'), greaterThan(7));
  });

  test('faster follower brakes behind a slower walker without tunnelling', () {
    final cast = [
      walker('slow', (t) => CharacterPose(x: t, z: 0, yaw: 0), speed: 1),
      walker(
        'fast',
        (t) => CharacterPose(x: 2 * t - 4, z: 0, yaw: 0),
        species: CharacterSpecies.meerkat,
      ),
    ];
    final traffic = CharacterTraffic(cast);
    for (var frame = 0; frame <= 200; frame++) {
      update(traffic, frame * 0.2);
      separated(traffic, cast);
    }
    expect(traffic.clockFor('slow'), greaterThan(35));
    expect(traffic.clockFor('fast'), inExclusiveRange(15, 25));
    update(traffic, 1000);
    separated(traffic, cast);
    expect(traffic.clockFor('slow'), lessThan(41));
  });

  test('hidden species release space; reappearance waits for a safe gap', () {
    final cast = [
      walker('penguin', (t) => CharacterPose(x: t - 3, z: 0, yaw: 0), speed: 1),
      walker(
        'meerkat',
        (t) => const CharacterPose(x: 0, z: 0, yaw: 0),
        species: CharacterSpecies.meerkat,
      ),
    ];
    final traffic = CharacterTraffic(cast);
    update(traffic, 0, meerkats: false);
    for (var frame = 1; frame <= 95; frame++) {
      update(traffic, frame / 30, meerkats: false);
    }
    expect(traffic.visibleFor('meerkat'), isFalse);
    update(traffic, 96 / 30);
    expect(traffic.visibleFor('meerkat'), isFalse);
    for (var frame = 97; frame <= 210; frame++) {
      update(traffic, frame / 30);
      separated(traffic, cast);
    }
    expect(traffic.visibleFor('meerkat'), isTrue);
    expect(traffic.clockFor('penguin'), greaterThan(6));
  });

  test(
    'fixed steps agree across frame rates and reduced motion has no catch-up',
    () {
      final cast = [walker('solo', (t) => CharacterPose(x: t, z: 0, yaw: 0))];
      final a = CharacterTraffic(cast);
      final b = CharacterTraffic(cast);
      for (var i = 0; i <= 300; i++) {
        update(a, i / 30);
      }
      for (var i = 0; i <= 600; i++) {
        update(b, i / 60);
      }
      expect(a.clockFor('solo'), closeTo(b.clockFor('solo'), 1e-9));
      final before = a.clockFor('solo');
      update(a, 20, animate: false);
      expect(a.clockFor('solo'), before);
      update(a, 20 + 1 / 30);
      expect(a.clockFor('solo') - before, closeTo(1 / 30, 1e-9));
    },
  );

  test('the full demo population remains separated through mixed cycles', () {
    final world = PlazaWorld(
      tasks: plazaTasksFromDemoWorld(now: manualDemoNow),
      now: manualDemoNow,
      projectLabel: 'Project Waddle',
      layout: StreetLayout(projectSeed: 1337, roadWidth: 25),
    );
    final penguins = CharacterPopulation.forWorld(
      plan: world.plan,
      plaza: world.plaza,
      solids: world.solids,
      roadWidth: world.layout.roadWidth,
    );
    final meerkats = MeerkatPopulation.forWorld(
      plan: world.plan,
      plaza: world.plaza,
      solids: world.solids,
      roadWidth: world.layout.roadWidth,
      penguins: penguins,
    );
    final cast = [
      ...penguins.map(TrafficCharacter.penguin),
      ...meerkats.map(TrafficCharacter.meerkat),
    ];
    final traffic = CharacterTraffic(cast);
    for (var frame = 0; frame <= 600; frame++) {
      update(traffic, frame * 0.2);
      separated(traffic, cast);
    }
    expect(cast.where((a) => traffic.visibleFor(a.id)), hasLength(cast.length));
    for (final actor in cast) {
      expect(traffic.clockFor(actor.id), greaterThan(30), reason: actor.id);
    }
  });
}
