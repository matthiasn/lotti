import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/character_gait.dart';
import 'package:lotti/features/plaza/domain/character_loop.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

/// A meerkat finishes a four-paw stop before rising into a tail-braced lookout.
enum MeerkatAction { scamper, settle, rise, lookout, lower, forage }

/// Distance-driven diagonal steps and a deterministic stop/lookout cycle.
/// Paw contacts remain fixed in world space, even through acceleration, turns,
/// and skipped frames. Raising the body never advances its route distance.
class MeerkatMotion {
  const MeerkatMotion({
    required this.id,
    required this.loop,
    required this.scale,
    required this.phase,
    this.timeOffset = 0,
  });

  final String id;
  final CharacterLoop loop;
  final double scale;
  final double phase;
  final double timeOffset;

  static const runDuration = 3.2;
  static const settleDuration = 0.25;
  static const riseDuration = 0.75;
  static const lookoutDuration = 3.2;
  static const lowerDuration = 0.65;
  static const forageDuration = 1.4;
  static const double cycleDuration =
      runDuration +
      settleDuration +
      riseDuration +
      lookoutDuration +
      lowerDuration +
      forageDuration;
  static const stance = 0.62;
  static const pawHeight = 0.075;
  static const pawWidth = 0.19;
  static const frontReach = 0.82;
  static const rearReach = -0.08;
  static const _ramp = 0.45;
  static const _stepOffset = 0.05;

  double get strideDistance => 0.68 * scale;
  double get boutDistance => 8 * strideDistance;

  MeerkatPose at(double seconds) {
    final clock = seconds + timeOffset;
    final block = (clock / cycleDuration).floor();
    final t = clock % cycleDuration;
    final run = _run(t);
    final distance = (block + run.progress) * boutDistance;
    final cycles = distance / strideDistance + _stepOffset;
    final root = _onRoute(distance);
    final sinceStop = t - runDuration;
    final double upright;
    final MeerkatAction action;
    if (sinceStop < 0) {
      action = MeerkatAction.scamper;
      upright = 0;
    } else if (sinceStop < settleDuration) {
      action = MeerkatAction.settle;
      upright = 0;
    } else if (sinceStop < settleDuration + riseDuration) {
      action = MeerkatAction.rise;
      upright = _ease((sinceStop - settleDuration) / riseDuration);
    } else if (sinceStop < settleDuration + riseDuration + lookoutDuration) {
      action = MeerkatAction.lookout;
      upright = 1;
    } else if (sinceStop <
        settleDuration + riseDuration + lookoutDuration + lowerDuration) {
      action = MeerkatAction.lower;
      upright =
          1 -
          _ease(
            (sinceStop - settleDuration - riseDuration - lookoutDuration) /
                lowerDuration,
          );
    } else {
      action = MeerkatAction.forage;
      upright = 0;
    }
    final scanTime = sinceStop - settleDuration - riseDuration;
    final scan = _scan(scanTime);
    final forageTime = scanTime - lookoutDuration - lowerDuration;
    return MeerkatPose(
      root: root,
      action: action,
      distance: distance,
      cycle: cycles * 2 * math.pi,
      speed: run.speed * boutDistance,
      upright: upright,
      headYaw: upright * scan,
      headPitch:
          upright * 0.08 +
          (action == MeerkatAction.forage
              ? 0.12 * math.pow(math.sin(math.pi * forageTime / 0.7), 2)
              : 0),
      blink: _blink(seconds),
      frontLeft: _paw(cycles, side: -1, front: true, offset: 0),
      frontRight: _paw(cycles, side: 1, front: true, offset: 0.5),
      rearLeft: _paw(cycles, side: -1, front: false, offset: 0.5),
      rearRight: _paw(cycles, side: 1, front: false, offset: 0),
    );
  }

  /// An integrated eased velocity gives zero speed at both ends of a bout.
  /// Eight whole strides finish at a phase with all four paws planted.
  static ({double progress, double speed}) _run(double t) {
    const area = runDuration - _ramp;
    if (t >= runDuration) return (progress: 1, speed: 0);
    if (t < _ramp) {
      return (
        progress: _ramp * _integral(t / _ramp) / area,
        speed: _ease(t / _ramp) / area,
      );
    }
    if (t > runDuration - _ramp) {
      final remaining = (runDuration - t) / _ramp;
      return (
        progress: 1 - _ramp * _integral(remaining) / area,
        speed: _ease(remaining) / area,
      );
    }
    return (progress: (t - _ramp / 2) / area, speed: 1 / area);
  }

  CharacterPose _onRoute(double distance) =>
      loop.at(0, phase: phase + distance / loop.length);

  CharacterFootPose _paw(
    double cycles, {
    required int side,
    required bool front,
    required double offset,
  }) {
    final cycle = cycles + offset;
    final progress = cycle % 1;
    final contact =
        (cycle.floor() - offset + stance / 2 - _stepOffset) * strideDistance;
    final a = _contact(contact, side: side, front: front);
    if (progress < stance) return a;
    final b = _contact(contact + strideDistance, side: side, front: front);
    final t = (progress - stance) / (1 - stance);
    final eased = _ease(t);
    final arc = math.sin(math.pi * t);
    return CharacterFootPose(
      x: a.x + (b.x - a.x) * eased,
      y: a.y + 0.075 * scale * arc * arc,
      z: a.z + (b.z - a.z) * eased,
      yaw: a.yaw + _angle(b.yaw - a.yaw) * eased,
      pitch: 0.12 * arc * arc,
      planted: false,
    );
  }

  CharacterFootPose _contact(
    double distance, {
    required int side,
    required bool front,
  }) {
    final root = _onRoute(distance);
    final lateral = side * pawWidth * scale;
    final along = (front ? frontReach : rearReach) * scale;
    return CharacterFootPose(
      x: root.x + math.cos(root.yaw) * lateral + math.sin(root.yaw) * along,
      y: loop.ground + pawHeight * scale,
      z: root.z - math.sin(root.yaw) * lateral + math.cos(root.yaw) * along,
      yaw: root.yaw,
      pitch: 0,
      planted: true,
    );
  }

  /// Quick, held looks read as vigilance instead of a pendulum oscillation.
  double _scan(double seconds) {
    const targets = [0.0, -0.55, 0.48, 0.12, -0.25];
    final time = seconds.clamp(0.0, lookoutDuration);
    final index = (time / 0.8).floor().clamp(0, 3);
    final local = time - index * 0.8;
    final direction = stableUnit(id, 'scan-side') < 0.5 ? -1 : 1;
    return direction *
        (targets[index] +
            (targets[index + 1] - targets[index]) * _ease(local / 0.2));
  }

  double _blink(double seconds) {
    final local = seconds + stableUnit(id, 'blink') * 4.9;
    final time = local % 4.9;
    if (time < 0.055) return _ease(time / 0.055);
    if (time < 0.095) return 1;
    if (time < 0.21) return 1 - _ease((time - 0.095) / 0.115);
    return 0;
  }

  static double _ease(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * t * (10 + t * (-15 + 6 * t));
  }

  static double _integral(double t) => math.pow(t, 4) * (2.5 + t * (-3 + t));

  static double _angle(double angle) =>
      math.atan2(math.sin(angle), math.cos(angle));
}

class MeerkatPose {
  const MeerkatPose({
    required this.root,
    required this.action,
    required this.distance,
    required this.cycle,
    required this.speed,
    required this.upright,
    required this.headYaw,
    required this.headPitch,
    required this.blink,
    required this.frontLeft,
    required this.frontRight,
    required this.rearLeft,
    required this.rearRight,
  });

  final CharacterPose root;
  final MeerkatAction action;
  final double distance;
  final double cycle;
  final double speed;
  final double upright;
  final double headYaw;
  final double headPitch;
  final double blink;
  final CharacterFootPose frontLeft;
  final CharacterFootPose frontRight;
  final CharacterFootPose rearLeft;
  final CharacterFootPose rearRight;

  List<CharacterFootPose> get paws => [
    frontLeft,
    frontRight,
    rearLeft,
    rearRight,
  ];
}
