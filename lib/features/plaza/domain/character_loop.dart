import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/solid.dart';

/// A constant-speed circuit with straight sides and semicircular ends.
/// Coordinates and clearances are world metres, not screen-space styling.
/// The tangent is continuous at every join, including the wrap back to zero.
class CharacterLoop {
  const CharacterLoop({
    required this.x,
    required this.z,
    required this.heading,
    required this.radius,
    required this.halfStraight,
  }) : assert(radius > 0, 'radius must be positive'),
       assert(halfStraight >= 0, 'straight length cannot be negative');

  final double x;
  final double z;
  final double heading;
  final double radius;
  final double halfStraight;

  /// Envelope of the largest penguin, including its balancing flippers.
  static const clearance = 1.8;
  static const height = 3.2;
  static const speed = 1.8;

  double get length => 4 * halfStraight + 2 * math.pi * radius;

  /// Derives a circuit inside the plaza and checks its swept clearance.
  /// A world without enough unobstructed paving has no roaming characters.
  static CharacterLoop? forPlaza(FrontierPlaza? plaza, List<Solid> solids) {
    if (plaza == null) return null;
    final radius = math.min(plaza.width * 0.11, plaza.depth * 0.09);
    final halfStraight = plaza.depth * 0.08;
    final centerAlong = plaza.depth * 0.06;
    if (radius <= clearance ||
        radius + clearance >= plaza.width / 2 ||
        centerAlong + halfStraight + radius + clearance >= plaza.depth / 2) {
      return null;
    }
    final (x, z) = plaza.footprint.toWorld(0, centerAlong);
    final loop = CharacterLoop(
      x: x,
      z: z,
      heading: plaza.headingRadians,
      radius: radius,
      halfStraight: halfStraight,
    );
    // Half-metre samples with a half-step of extra clearance cover the
    // entire curve, including any obstacle between two sampled positions.
    const sampleStep = 0.5;
    final samples = (loop.length / sampleStep).ceil();
    final obstacles = solids.where((s) => s.bottom < height && s.top > 0);
    for (var i = 0; i < samples; i++) {
      final pose = loop.at(0, phase: i / samples);
      for (final solid in obstacles) {
        if (solid.footprint.contains(
          pose.x,
          pose.z,
          clearance: clearance + sampleStep / 2,
        )) {
          return null;
        }
      }
    }
    return loop;
  }

  /// Samples the route without a frame delta.
  /// [phase] is a fraction of the circuit; the caller owns the paused clock.
  CharacterPose at(double seconds, {double phase = 0}) {
    final travel = seconds * speed + phase * length;
    var distance = travel % length;
    final straight = 2 * halfStraight;
    final arc = math.pi * radius;
    double lateral;
    double along;
    double yaw;
    if (distance < straight) {
      lateral = radius;
      along = -halfStraight + distance;
      yaw = 0;
    } else if (distance < straight + arc) {
      final angle = (distance - straight) / radius;
      lateral = radius * math.cos(angle);
      along = halfStraight + radius * math.sin(angle);
      yaw = -angle;
    } else if (distance < 2 * straight + arc) {
      distance -= straight + arc;
      lateral = -radius;
      along = halfStraight - distance;
      yaw = -math.pi;
    } else {
      final angle = math.pi + (distance - 2 * straight - arc) / radius;
      lateral = radius * math.cos(angle);
      along = -halfStraight + radius * math.sin(angle);
      yaw = -angle;
    }
    final sinH = math.sin(heading);
    final cosH = math.cos(heading);
    return CharacterPose(
      x: x + lateral * cosH + along * sinH,
      z: z - lateral * sinH + along * cosH,
      yaw: heading + yaw,
    );
  }
}

/// The position and forward tangent of a companion on its route.
class CharacterPose {
  const CharacterPose({
    required this.x,
    required this.z,
    required this.yaw,
  });

  final double x;
  final double z;
  final double yaw;
}
