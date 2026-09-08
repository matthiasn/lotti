import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/character_loop.dart';
import 'package:lotti/features/plaza/domain/character_population.dart';
import 'package:lotti/features/plaza/domain/meerkat_motion.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

/// Small foraging circuits distributed through the same inhabited districts.
/// Solid clearance covers the whole circuit, including the long tail. Traffic
/// arbitration handles moving neighbours separately from fixed-world geometry.
abstract final class MeerkatPopulation {
  static const clearance = 1.05;

  static List<MeerkatMotion> forWorld({
    required StreetPlan plan,
    required FrontierPlaza? plaza,
    required List<Solid> solids,
    required double roadWidth,
    required List<CharacterCompanion> penguins,
  }) {
    final result = <MeerkatMotion>[];
    void place(String id, CharacterLoop loop) {
      if (!loop.clears(solids, envelope: clearance)) return;
      if (result.any(
        (other) =>
            math.pow(other.loop.x - loop.x, 2) +
                math.pow(other.loop.z - loop.z, 2) <
            36,
      )) {
        return;
      }
      final scale = 0.68 + 0.08 * stableUnit(id, 'scale');
      for (final phase in [0.0, 0.25, 0.5, 0.75]) {
        final motion = MeerkatMotion(
          id: id,
          loop: loop,
          scale: scale,
          phase: phase,
          timeOffset: stableUnit(id, 'behaviour') * MeerkatMotion.cycleDuration,
        );
        final at = motion.at(0).root;
        final occupied = penguins.any((penguin) {
          final other = penguin.positionAt(0);
          return math.pow(at.x - other.x, 2) + math.pow(at.z - other.z, 2) <
              math.pow(clearance + 1.1 * penguin.gait.scale, 2);
        });
        if (occupied) continue;
        result.add(motion);
        return;
      }
    }

    if (roadWidth / 2 - 3.175 > 1.1 + clearance) {
      for (final segment in plan.segments) {
        if (segment.length < 18) continue;
        final id = 'street-${segment.bucketIndex}-${segment.isConnector}';
        for (final (i, fraction) in [0.32, 0.68].indexed) {
          final along = segment.length * fraction;
          place(
            'meerkat-$id-$i',
            CharacterLoop(
              x: segment.startX + math.sin(segment.headingRadians) * along,
              z: segment.startZ + math.cos(segment.headingRadians) * along,
              heading: segment.headingRadians,
              radius: 1.1,
              halfStraight: 1.4,
              ground: CharacterPopulation.streetGround,
            ),
          );
        }
      }
    }
    if (plaza != null) {
      for (final (i, point) in [
        (-0.22, -0.15),
        (0.22, -0.15),
        (-0.22, 0.17),
        (0.22, 0.17),
        (0.0, -0.24),
        (0.0, 0.25),
      ].indexed) {
        if (point.$1.abs() * plaza.width + 1.1 + clearance >= plaza.width / 2 ||
            point.$2.abs() * plaza.depth + 2.5 + clearance >= plaza.depth / 2) {
          continue;
        }
        final (x, z) = plaza.footprint.toWorld(
          point.$1 * plaza.width,
          point.$2 * plaza.depth,
        );
        place(
          'meerkat-plaza-$i',
          CharacterLoop(
            x: x,
            z: z,
            heading: plaza.headingRadians,
            radius: 1.1,
            halfStraight: 1.4,
          ),
        );
      }
    }
    return List.unmodifiable(result);
  }
}
