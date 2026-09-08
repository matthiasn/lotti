import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/character_loop.dart';
import 'package:lotti/features/plaza/domain/character_population.dart';
import 'package:lotti/features/plaza/domain/meerkat_motion.dart';

enum CharacterSpecies { penguin, meerkat }

/// A route and its support phases, independent of a rendering skeleton.
class TrafficCharacter {
  const TrafficCharacter({
    required this.id,
    required this.species,
    required this.radius,
    required this.maxSpeed,
    required this.positionAt,
    required this.supportedAt,
  });

  factory TrafficCharacter.penguin(CharacterCompanion companion) =>
      TrafficCharacter(
        id: companion.id,
        species: CharacterSpecies.penguin,
        radius: 0.9 * companion.gait.scale,
        maxSpeed: companion.gait.loop.pace,
        positionAt: companion.positionAt,
        supportedAt: (time) {
          final pose = companion.gait.at(time);
          return pose.left.planted && pose.right.planted;
        },
      );

  factory TrafficCharacter.meerkat(MeerkatMotion motion) => TrafficCharacter(
    id: motion.id,
    species: CharacterSpecies.meerkat,
    radius: 1.9 * motion.scale,
    maxSpeed: motion.boutDistance / (MeerkatMotion.runDuration - 0.45),
    positionAt: motion.positionAt,
    supportedAt: (time) {
      final pose = motion.at(time);
      return pose.speed == 0 || pose.paws.every((paw) => paw.planted);
    },
  );

  final String id;
  final CharacterSpecies species;
  final double radius;
  final double maxSpeed;
  final CharacterPose Function(double seconds) positionAt;
  final bool Function(double seconds) supportedAt;
}

/// Reserves enough route to finish a step before another character may enter.
/// Reservations include the complete swept body envelope, including a meerkat's
/// tail. A blocked walker decelerates its *animation clock* to a supported pose:
/// roots and planted feet therefore retain the same world-space contacts.
class CharacterTraffic {
  CharacterTraffic(List<TrafficCharacter> characters)
    : _walkers = {
        for (final (priority, character) in characters.indexed)
          character.id: _Walker(character, priority),
      };

  final Map<String, _Walker> _walkers;
  final Map<String, _Reservation> _crossingGuards = {};
  double? _lastSeconds;
  double _remainder = 0;
  static const double _stepSeconds = 1 / 30;
  static const _acceleration = 3.0;

  double clockFor(String id) => _walkers[id]!.time;
  bool visibleFor(String id) => _walkers[id]!.admitted;

  /// Hidden species release reservations. On reappearance they wait offscreen
  /// until their saved position and next supporting step are clear. Reduced
  /// motion and long suspension discard elapsed time instead of catching up.
  void update({
    required double seconds,
    required bool animate,
    required bool showPenguins,
    required bool showMeerkats,
  }) {
    final previous = _lastSeconds;
    _lastSeconds = seconds;
    for (final walker in _walkers.values) {
      walker.enabled = switch (walker.character.species) {
        CharacterSpecies.penguin => showPenguins,
        CharacterSpecies.meerkat => showMeerkats,
      };
      if (!walker.enabled) {
        walker
          ..admitted = false
          ..reservation = null
          ..rate = 0;
      }
    }
    _admit();
    if (!animate || previous == null) return;
    _remainder += (seconds - previous).clamp(0.0, 0.25);
    while (_remainder + 1e-9 >= _stepSeconds) {
      _step();
      _remainder -= _stepSeconds;
    }
  }

  void _admit() {
    for (final walker in _walkers.values) {
      if (!walker.enabled || walker.admitted) continue;
      final end = _supportAfter(walker, walker.time + 2.0);
      final reservation = _Reservation(walker.character, walker.time, end);
      if (!_clear(walker, reservation)) continue;
      walker
        ..end = end
        ..reservation = reservation
        ..admitted = true;
    }
  }

  void _step() {
    _crossingGuards.clear();
    // Drop travelled space before granting the next step. Stable population
    // order breaks simultaneous crossing ties without random jitter.
    for (final walker in _walkers.values.where((w) => w.admitted)) {
      walker.reservation = _Reservation(
        walker.character,
        walker.time,
        walker.end,
      );
    }
    for (final walker in _walkers.values.where((w) => w.admitted)) {
      if (walker.end - walker.time < 1.7) {
        final end = _supportAfter(walker, walker.time + 2.0);
        final proposed = _Reservation(walker.character, walker.time, end);
        if (_clear(walker, proposed)) {
          walker
            ..end = end
            ..reservation = proposed;
        }
      }
      final remaining = walker.end - walker.time;
      final double rate = math.min(
        1,
        math.min(
          walker.rate + _acceleration * _stepSeconds,
          math.sqrt(2 * _acceleration * remaining),
        ),
      );
      final travel = (walker.rate + rate) * 0.5 * _stepSeconds;
      if (travel >= remaining) {
        walker
          ..time = walker.end
          ..rate = 0;
      } else {
        walker
          ..time += travel
          ..rate = rate;
      }
    }
    _admit();
  }

  bool _clear(_Walker walker, _Reservation proposed) {
    for (final other in _walkers.values) {
      if (identical(walker, other) || !other.admitted) continue;
      if (proposed.overlaps(other.reservation!)) return false;
      if (other.priority < walker.priority) {
        // Reserve a crossing's exit as well as its entry before a second
        // approach can stop inside it. Following traffic may still advance
        // along the same tangent; holding it would trap the leader too.
        final guard = _crossingGuards.putIfAbsent(
          other.character.id,
          () => _Reservation(other.character, other.time, other.time + 4),
        );
        if (proposed.overlaps(guard, crossingOnly: true)) return false;
      }
    }
    return true;
  }

  /// The species' gait supplies double/four-paw support. The search is bounded
  /// by the longest stride, never by a wall-clock timer.
  static double _supportAfter(_Walker walker, double time) {
    for (var step = 0; step < 200; step++) {
      final candidate = time + step * 0.005;
      if (walker.character.supportedAt(candidate)) return candidate;
    }
    throw StateError('No supporting pose for ${walker.character.id}');
  }
}

class _Walker {
  _Walker(this.character, this.priority);
  final TrafficCharacter character;
  final int priority;
  bool enabled = true;
  bool admitted = false;
  double time = 0;
  double end = 0;
  double rate = 0;
  _Reservation? reservation;
}

class _Reservation {
  _Reservation(TrafficCharacter character, double start, double end)
    : radius = character.radius + 0.025 {
    // At most 5 cm of travel between samples. Inflating each sample by half
    // that distance covers every intervening position, including curved paths.
    final steps = math.max(
      1,
      ((end - start) * character.maxSpeed / 0.05).ceil(),
    );
    for (var i = 0; i <= steps; i++) {
      final point = character.positionAt(start + (end - start) * i / steps);
      points.add(point);
      minX = math.min(minX, point.x - radius);
      maxX = math.max(maxX, point.x + radius);
      minZ = math.min(minZ, point.z - radius);
      maxZ = math.max(maxZ, point.z + radius);
    }
  }

  final double radius;
  final List<CharacterPose> points = [];
  double minX = double.infinity;
  double maxX = double.negativeInfinity;
  double minZ = double.infinity;
  double maxZ = double.negativeInfinity;

  bool overlaps(_Reservation other, {bool crossingOnly = false}) {
    if (maxX < other.minX ||
        minX > other.maxX ||
        maxZ < other.minZ ||
        minZ > other.maxZ) {
      return false;
    }
    final separation = radius + other.radius;
    for (final a in points) {
      for (final b in other.points) {
        if (crossingOnly && math.cos(a.yaw - b.yaw) > 0.5) continue;
        final dx = a.x - b.x;
        final dz = a.z - b.z;
        if (dx * dx + dz * dz < separation * separation) return true;
      }
    }
    return false;
  }
}
