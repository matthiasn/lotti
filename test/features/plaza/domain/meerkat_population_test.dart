import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/plaza/data/demo_world_projection.dart';
import 'package:lotti/features/plaza/domain/character_population.dart';
import 'package:lotti/features/plaza/domain/meerkat_population.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';

import '../plaza_fixtures.dart';

void main() {
  for (final folded in [false, true]) {
    test('foraging circuits clear the ${folded ? 'folded' : 'demo'} world', () {
      final world = PlazaWorld(
        tasks: folded
            ? syntheticPlazaTasks()
            : plazaTasksFromDemoWorld(now: manualDemoNow),
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
      final cast = MeerkatPopulation.forWorld(
        plan: world.plan,
        plaza: world.plaza,
        solids: world.solids,
        roadWidth: world.layout.roadWidth,
        penguins: penguins,
      );
      expect(cast.length, greaterThanOrEqualTo(8));
      expect(cast.any((m) => m.id.startsWith('meerkat-plaza')), isTrue);
      expect(cast.any((m) => m.id.startsWith('meerkat-street')), isTrue);
      expect(cast.map((m) => m.id).toSet().length, cast.length);
      expect(cast.map((m) => m.at(0).action).toSet().length, greaterThan(1));
      for (final motion in cast) {
        expect(
          motion.loop.clears(
            world.solids,
            envelope: MeerkatPopulation.clearance,
          ),
          isTrue,
          reason: motion.id,
        );
        expect(motion.scale, inInclusiveRange(0.68, 0.76));
      }
      for (final budget in [0, 1, 6, 1000]) {
        final limited = MeerkatPopulation.forWorld(
          plan: world.plan,
          plaza: world.plaza,
          solids: world.solids,
          roadWidth: world.layout.roadWidth,
          penguins: penguins,
          maxCount: budget,
        );
        expect(limited.length, budget.clamp(0, cast.length));
        expect(limited.map((m) => m.id).toSet().length, limited.length);
        expect(limited.every((m) => cast.any((c) => c.id == m.id)), isTrue);
        if (budget == 1 || budget == 6) {
          expect(limited.first.id, startsWith('meerkat-plaza'));
        }
        if (budget == 6) {
          final streets = limited.where(
            (m) => m.id.startsWith('meerkat-street'),
          );
          expect(streets.length, greaterThanOrEqualTo(2));
          expect(streets.map((m) => m.loop.z).toSet().length, greaterThan(1));
        }
      }
      if (!folded) expect(penguins, hasLength(78));
    });
  }
}
