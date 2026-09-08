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
  static const clearance = 1.5;

  /// A bounded crowd keeps a Home lookout and samples the remaining circuits
  /// across the district, so small budgets do not fill only the first street.
  static List<MeerkatMotion> forWorld({
    required StreetPlan plan,
    required FrontierPlaza? plaza,
    required List<Solid> solids,
    required double roadWidth,
    required List<CharacterCompanion> penguins,
    int? maxCount,
  }) {
    if (maxCount != null && maxCount <= 0) return const [];
    final result = <MeerkatMotion>[];
    final lanes = <CharacterLoop, List<CharacterPose>>{};
    for (final penguin in penguins) {
      final loop = penguin.gait.loop;
      lanes.putIfAbsent(loop, () {
        final steps = (loop.length / 0.25).ceil();
        return [for (var i = 0; i < steps; i++) loop.at(0, phase: i / steps)];
      });
    }
    void place(String id, CharacterLoop loop) {
      if (!loop.clears(solids, envelope: clearance)) return;
      // A fixed-route actor cannot sidestep on a shared, opposing lane. Keep
      // forage loops out of these narrow corridors; transverse encounters
      // remain the runtime traffic controller's responsibility.
      final steps = (loop.length / 0.25).ceil();
      for (var i = 0; i < steps; i++) {
        final here = loop.at(0, phase: i / steps);
        for (final lane in lanes.values) {
          for (final there in lane) {
            final dx = here.x - there.x;
            final dz = here.z - there.z;
            if (dx * dx + dz * dz < 2.5 * 2.5 &&
                math.cos(here.yaw - there.yaw).abs() > 0.85) {
              return;
            }
          }
        }
      }
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
    if (maxCount == null || maxCount >= result.length) {
      return List.unmodifiable(result);
    }
    final home = result
        .where((m) => m.id.startsWith('meerkat-plaza'))
        .firstOrNull;
    final remaining = result.where((m) => m != home).toList();
    final slots = maxCount - (home == null ? 0 : 1);
    return List.unmodifiable([
      ?home,
      for (var i = 0; i < slots; i++)
        remaining[(i * remaining.length / slots).floor()],
    ]);
  }
}
