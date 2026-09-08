import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/character_loop.dart';

/// A short-stride penguin walk with world-space foot contacts. Overlapping
/// support transfers weight between feet without an aerial phase.
/// The curve and all contacts are sampled analytically, so frame rate and
/// skipped frames cannot alter a landing position.
class CharacterGait {
  const CharacterGait({
    required this.loop,
    required this.scale,
    required this.phase,
    this.stepPhase = 0,
  });

  final CharacterLoop loop;
  final double scale;
  final double phase;
  final double stepPhase;

  static const stance = 0.60;
  static const ankleHeight = 0.095;
  static const hipWidth = 0.27;
  static const gravity = 9.81;
  static const strideLength = 0.85;
  static const recoveryLift = 0.07;

  double get strideDistance => strideLength * scale;
  double get period => strideDistance / loop.pace;

  CharacterWalkPose at(double seconds) {
    final travel = seconds * loop.pace + phase * loop.length;
    final cycles = travel / strideDistance + stepPhase;
    // Low through double support, highest as the body passes over one foot.
    // Weight is centred on the left at cycle .3 and on the right at .8.
    final weightPhase = (cycles - 0.05) * 2 * math.pi;
    final bounce = -0.014 * scale * math.cos(2 * weightPhase);
    final root = loop.at(seconds, phase: phase);
    final before = loop.at(seconds - 0.18, phase: phase);
    final after = loop.at(seconds + 0.18, phase: phase);
    final yawRate = _angle(after.yaw - before.yaw) / 0.36;
    return CharacterWalkPose(
      root: root,
      cycle: cycles * 2 * math.pi,
      bounce: bounce,
      weightShift: -math.sin(weightPhase),
      bank: -math.atan(loop.pace * yawRate / gravity),
      left: _foot(cycles, offset: 0, side: -1),
      right: _foot(cycles, offset: 0.5, side: 1),
    );
  }

  CharacterFootPose _foot(
    double cycles, {
    required double offset,
    required int side,
  }) {
    final legCycle = cycles + offset;
    final progress = legCycle % 1;
    final contactTravel =
        (legCycle.floor() - offset + stance / 2 - stepPhase) * strideDistance;
    final a = _contact(contactTravel, side);
    if (progress < stance) return a;
    final b = _contact(contactTravel + strideDistance, side);
    final t = (progress - stance) / (1 - stance);
    // Quintic ease gives zero velocity and acceleration at both contacts.
    final ease = t * t * t * (10 + t * (-15 + 6 * t));
    // Recover the heel early, then unfold into the next contact. A symmetric
    // sine arc makes the leg march upward at mid-swing instead of folding.
    final remaining = 1 - t;
    final lift = 729 / 16 * t * t * math.pow(remaining, 4);
    final fold = math.sin(math.pi * (t / 0.65).clamp(0, 1));
    return CharacterFootPose(
      x: a.x + (b.x - a.x) * ease,
      y: a.y + recoveryLift * scale * lift,
      z: a.z + (b.z - a.z) * ease,
      yaw: a.yaw + _angle(b.yaw - a.yaw) * ease,
      pitch: 0.16 * fold * fold,
      planted: false,
    );
  }

  CharacterFootPose _contact(double distance, int side) {
    final pose = loop.at(0, phase: distance / loop.length);
    return CharacterFootPose(
      x: pose.x + math.cos(pose.yaw) * side * hipWidth * scale,
      y: loop.ground + ankleHeight * scale,
      z: pose.z - math.sin(pose.yaw) * side * hipWidth * scale,
      yaw: pose.yaw,
      pitch: 0,
      planted: true,
    );
  }

  static double _angle(double angle) =>
      math.atan2(math.sin(angle), math.cos(angle));
}

class CharacterWalkPose {
  const CharacterWalkPose({
    required this.root,
    required this.cycle,
    required this.bounce,
    required this.weightShift,
    required this.bank,
    required this.left,
    required this.right,
  });
  final CharacterPose root;
  final double cycle;
  final double bounce;
  final double weightShift;
  final double bank;
  final CharacterFootPose left;
  final CharacterFootPose right;
}

class CharacterFootPose {
  const CharacterFootPose({
    required this.x,
    required this.y,
    required this.z,
    required this.yaw,
    required this.pitch,
    required this.planted,
  });
  final double x;
  final double y;
  final double z;
  final double yaw;
  final double pitch;
  final bool planted;
}
