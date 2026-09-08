import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/character_gait.dart';
import 'package:lotti/features/plaza/domain/character_loop.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

/// Deterministic walkers distributed throughout the inhabited street network.
/// Routes stay inside asphalt or plaza paving and never cut across buildings.
class CharacterPopulation {
  static const pairSeparation = 2.6;
  static const streetGround = 0.045;

  static List<CharacterCompanion> forWorld({
    required StreetPlan plan,
    required FrontierPlaza? plaza,
    required List<Solid> solids,
    required double roadWidth,
  }) {
    final result = <CharacterCompanion>[];
    // Pavement occupies 3 m per side, plus half the 0.35 m kerb width.
    final usable = roadWidth / 2 - 3 - 0.175;
    for (final (index, segment) in plan.segments.indexed) {
      final paired =
          usable >= CharacterLoop.clearance + pairSeparation / 2 + 0.25 + 3.2;
      const margin = CharacterLoop.clearance + 0.25;
      bool bends(RoadSegment other) =>
          math.cos(other.headingRadians - segment.headingRadians) < 0.999;
      // Keep each route outside the crossing street's full width, so actors
      // on independently timed circuits cannot meet at a folded junction.
      final junctionMargin = roadWidth / 2 + margin;
      final start = index > 0 && bends(plan.segments[index - 1])
          ? junctionMargin
          : margin;
      final end =
          index + 1 < plan.segments.length && bends(plan.segments[index + 1])
          ? junctionMargin
          : margin;
      final available = segment.length - start - end;
      final radius = math.min(
        math.min(5.5, (available - 6) / 2),
        usable - margin - (paired ? pairSeparation / 2 : 0),
      );
      final halfStraight = available / 2 - radius;
      if (radius < 2 || halfStraight < 3) continue;
      final center = (start + segment.length - end) / 2;
      final id = 'street-${segment.bucketIndex}-${segment.isConnector}';
      final seed = stableHash(id) & 0xFFFF;
      // At folded junctions, nearby buildings may intrude into the asphalt.
      // Prefer the wide central circuit, then fit a smaller route in the
      // clear side of the street. Every candidate retains the junction inset.
      var placed = false;
      for (var r = radius; r >= 2 && !placed; r -= 1) {
        final pair = paired && r >= 3.2;
        final shift = usable - r - margin - (pair ? pairSeparation / 2 : 0);
        for (final lateral in [0.0, shift, -shift]) {
          for (var straight = available / 2 - r; straight >= 3; straight -= 2) {
            final loop = CharacterLoop(
              x:
                  segment.startX +
                  math.sin(segment.headingRadians) * center +
                  math.cos(segment.headingRadians) * lateral,
              z:
                  segment.startZ +
                  math.cos(segment.headingRadians) * center -
                  math.sin(segment.headingRadians) * lateral,
              heading: segment.headingRadians,
              radius: r,
              halfStraight: straight,
              pace: 1.05 + (seed % 4) * 0.04,
              ground: streetGround,
            );
            final walkers = _populate(
              id,
              loop,
              solids,
              groups: 3,
              paired: pair,
            );
            if (walkers.isEmpty) continue;
            result.addAll(walkers);
            placed = true;
            break;
          }
          if (placed) break;
        }
      }
    }
    final square = CharacterLoop.forPlaza(plaza, solids);
    if (square != null) {
      result.addAll(
        _populate('plaza', square, solids, groups: 4, paired: true),
      );
    }
    return List.unmodifiable(result);
  }

  static List<CharacterCompanion> _populate(
    String id,
    CharacterLoop loop,
    List<Solid> solids, {
    required int groups,
    required bool paired,
  }) {
    if (!loop.clears(solids)) return const [];
    final left = loop.translated(-pairSeparation / 2);
    final right = loop.translated(pairSeparation / 2);
    final pairsFit = paired && left.clears(solids) && right.clears(solids);
    final seed = stableHash(id) & 0xFFFF;
    final result = <CharacterCompanion>[];
    // Repeat the entire solo/pair mix, spreading twice as many groups around
    // the circuit without putting a second penguin on an existing position.
    final groupCount = groups * 2;
    for (var group = 0; group < groupCount; group++) {
      final pair = pairsFit && (group % groups).isEven;
      final phase = group / groupCount + 0.05 + (seed % 17) / 1000;
      final conversation = seed + group * 31;
      final count = pair ? 2 : 1;
      for (var member = 0; member < count; member++) {
        final route = pair ? (member == 0 ? left : right) : loop;
        result.add(
          CharacterCompanion(
            id: '$id-$group-$member',
            region: id,
            gait: CharacterGait(
              loop: route,
              scale: [1.0, 0.88, 0.96, 0.82][(seed + group + member) % 4],
              phase: phase,
              stepPhase: member * 0.31 + (seed % 11) / 17,
            ),
            partnerLoop: pair ? (member == 0 ? right : left) : null,
            conversationSeed: conversation,
            responseDelay: member * 0.55,
          ),
        );
      }
    }
    return result;
  }
}

/// One companion's route, footsteps and occasional attention to its partner.
/// Social actions use the same paused clock as locomotion and do not steer feet.
class CharacterCompanion {
  const CharacterCompanion({
    required this.id,
    required this.region,
    required this.gait,
    this.partnerLoop,
    this.conversationSeed = 0,
    this.responseDelay = 0,
  });

  final String id;
  final String region;
  final CharacterGait gait;
  final CharacterLoop? partnerLoop;
  final int conversationSeed;
  final double responseDelay;

  CharacterPose positionAt(double seconds) =>
      gait.loop.at(seconds, phase: gait.phase);

  /// Ease in, hold an inward glance, then return to the route. Replies lag
  /// their partner; most of each 9–13 second interval is spent looking ahead.
  /// A smooth facing gate suppresses conversation through tight U-turns.
  ({double yaw, double nod}) attentionAt(double seconds) {
    final partner = partnerLoop;
    if (partner == null) return (yaw: 0, nod: 0);
    final interval = 9.0 + conversationSeed % 5;
    final time = (seconds + conversationSeed % 7 - responseDelay) % interval;
    final hold = 0.9 + (conversationSeed % 4) * 0.1;
    final double weight;
    if (time < 0.35) {
      weight = _ease(time / 0.35);
    } else if (time < 0.35 + hold) {
      weight = 1;
    } else if (time < 0.85 + hold) {
      weight = 1 - _ease((time - 0.35 - hold) / 0.5);
    } else {
      return (yaw: 0, nod: 0);
    }
    final here = positionAt(seconds);
    final there = partner.at(seconds, phase: gait.phase);
    final bearing = math.atan2(there.x - here.x, there.z - here.z);
    final angle = math.atan2(
      math.sin(bearing - here.yaw),
      math.cos(bearing - here.yaw),
    );
    final forward = math.cos(here.yaw - gait.loop.heading).abs();
    final gate = _ease(((forward - 0.8) / 0.2).clamp(0, 1));
    final amount = weight * gate;
    final nod = math.sin(math.pi * ((time - 0.35) / hold).clamp(0, 1));
    return (
      yaw: angle.clamp(-0.48, 0.48) * amount,
      nod: 0.045 * nod * nod * amount,
    );
  }

  static double _ease(double t) => t * t * t * (10 + t * (-15 + 6 * t));
}
