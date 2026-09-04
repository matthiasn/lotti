import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/flight.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_network.dart';
import 'package:lotti/features/plaza/domain/walk_collider.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

/// First-person walk camera with flights.
///
/// WASD/arrows walk (shift sprints), drag looks, and [flyTo] hands the pose
/// to a [Flight]: between two stops on the ground it follows the street
/// network; otherwise it is the direct line. Either way it is planned over
/// the world's solids, so it lifts over whatever stands on its line; any
/// movement input cancels a flight in place. Walking happens at
/// [eyeHeight] and stays out of buildings via the collider; a pose set
/// elsewhere (the overview) keeps its height until the next step, which
/// lands beside a building, never inside one.
class FlyCameraController {
  FlyCameraController({
    required CameraPose pose,
    WalkCollider? collider,
    Iterable<Solid> solids = const [],
    StreetNetwork? network,
  }) : _pose = pose,
       _collider = collider,
       _solids = List.unmodifiable(solids),
       _network = network;
  // ignore_for_file: prefer_initializing_formals

  static const walkSpeed = 3.4;
  static const _sprintFactor = 2.5;

  /// Vertical field of view: a game camera, not a phone lens.
  static const double fovRadiansY = 60 * math.pi / 180;

  /// Velocity smoothing: reaches ~63% of the target in this many seconds.
  static const _accelSeconds = 0.12;

  double _vForward = 0;
  double _vStrafe = 0;

  CameraPose _pose;
  final WalkCollider? _collider;
  final List<Solid> _solids;
  final StreetNetwork? _network;

  /// A pose no higher than this above the ground counts as a stop on the
  /// street, which a flight reaches along the network.
  static const double groundCeiling = Flight.streetFlightHeight + 1;
  final Set<LogicalKeyboardKey> _pressed = {};
  Flight? _flight;

  /// Scripted forward input (benchmark mode): -1..1, applied when no key is
  /// pressed.
  double autoForward = 0;

  /// Called when a flight lands.
  void Function()? onArrived;

  /// Called on any movement input (used to abandon the morning walk).
  void Function()? onMovement;

  CameraPose get pose => _pose;
  set pose(CameraPose value) {
    _pose = value;
    _flight = null;
    _landing = false;
    _vForward = 0;
    _vStrafe = 0;
  }

  Vector3 get position => Vector3(_pose.x, _pose.y, _pose.z);

  /// The unit view direction for the current yaw and pitch.
  Vector3 get forward {
    final cosP = math.cos(_pose.pitch);
    return Vector3(
      math.sin(_pose.yaw) * cosP,
      math.sin(_pose.pitch),
      math.cos(_pose.yaw) * cosP,
    );
  }

  double get yaw => _pose.yaw;
  double get pitch => _pose.pitch;
  Flight? get flight => _flight;
  bool get flying => _flight != null;

  /// Whether the walker is under way: a movement key held, or still
  /// coasting after one.
  bool get moving =>
      _vForward != 0 || _vStrafe != 0 || _pressed.any(_movementKeys.contains);

  /// Starts a flight to [target], discarding walking momentum; the current
  /// flight, if any, is replaced.
  /// From one stop on the ground to another the flight follows the street
  /// network; a climb, a dive or a world without a street takes the direct
  /// line. Both are swept over every solid on the way.
  Flight flyTo(CameraPose target) {
    final network = _network;
    final onGround = _pose.y <= groundCeiling && target.y <= groundCeiling;
    final flight = network != null && onGround
        ? Flight.route(
            _pose,
            target,
            via: network.pathBetween(
              (_pose.x, _pose.z),
              (target.x, target.z),
              join: Flight.joinDistance,
            ),
            solids: _solids,
          )
        : Flight.plan(_pose, target, solids: _solids);
    _flight = flight;
    _landing = false;
    _vForward = 0;
    _vStrafe = 0;
    return flight;
  }

  static final Set<LogicalKeyboardKey> _movementKeys = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };
  static final Set<LogicalKeyboardKey> _trackedKeys = {
    ..._movementKeys,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
  };

  /// Feed key events from the harness. Returns true when handled.
  bool handleKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    if (!_trackedKeys.contains(key)) return false;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _pressed.add(key);
      if (_movementKeys.contains(key)) _movementInput();
    } else if (event is KeyUpEvent) {
      _pressed.remove(key);
    }
    return true;
  }

  /// Above this height a movement key lands the camera first.
  static const double _landingAbove = eyeHeight + 1.5;

  /// Whether the flight under way is a landing: a held key's repeats
  /// must not restart it from rest every few milliseconds.
  bool _landing = false;

  void _movementInput() {
    if (_landing) return;
    _flight = null;
    // Aloft — from the overview, or a flight cut short over the street or
    // mid-arc — a short landing flight, not a one-frame drop.
    if (_pose.y > _landingAbove) _land();
    onMovement?.call();
  }

  /// Lands on the nearest ground the walker may stand on: straight down
  /// over a street, beside the wall when the camera is over a roof.
  void _land() {
    var x = _pose.x;
    var z = _pose.z;
    final collider = _collider;
    if (collider != null) (x, z) = collider.resolve(x, z);
    _flight = Flight.plan(
      _pose,
      CameraPose(x: x, y: eyeHeight, z: z, yaw: _pose.yaw),
      solids: _solids,
    );
    _landing = true;
  }

  /// Mouse-drag look, in logical pixels. Cancels a flight in place and
  /// notifies the owner to abandon any guided walk.
  void addLookDelta(double dx, double dy) {
    _flight = null;
    _landing = false;
    _pose = CameraPose(
      x: _pose.x,
      y: _pose.y,
      z: _pose.z,
      yaw: _pose.yaw - dx * 0.0032,
      pitch: (_pose.pitch - dy * 0.0028).clamp(-1.25, 1.25),
    );
    onMovement?.call();
  }

  bool _down(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
      _pressed.contains(a) || _pressed.contains(b);

  /// Advance one frame.
  void update(double dt) {
    final flight = _flight;
    if (flight != null) {
      _pose = flight.advance(
        Duration(microseconds: (dt * 1e6).round()),
      );
      if (flight.done) {
        _flight = null;
        _landing = false;
        onArrived?.call();
      }
      return;
    }

    // A key-up lost to a focus change (clicking the overlay, panning)
    // would leave a movement key latched and the camera walking forever;
    // reconcile with the hardware's actual pressed set every frame.
    _pressed.removeWhere(
      (key) => !HardwareKeyboard.instance.logicalKeysPressed.contains(key),
    );

    var forwardInput =
        (_down(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp)
            ? 1.0
            : 0.0) -
        (_down(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown)
            ? 1.0
            : 0.0);
    if (forwardInput == 0) forwardInput = autoForward;
    final strafeInput =
        (_down(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight)
            ? 1.0
            : 0.0) -
        (_down(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft)
            ? 1.0
            : 0.0);

    var x = _pose.x;
    var z = _pose.z;
    var y = _pose.y;
    var speed = walkSpeed;
    if (_down(LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight)) {
      speed *= _sprintFactor;
    }
    // Short acceleration and deceleration instead of an on/off switch.
    final blend = dt <= 0 ? 1.0 : (1 - math.exp(-dt / _accelSeconds));
    _vForward += (forwardInput * speed - _vForward) * blend;
    _vStrafe += (strafeInput * speed - _vStrafe) * blend;
    if (_vForward.abs() < 0.01) _vForward = 0;
    if (_vStrafe.abs() < 0.01) _vStrafe = 0;
    if (_vForward != 0 || _vStrafe != 0) {
      // Walking happens at eye height; a pose set from the overview drops
      // to the ground on the first step.
      y = eyeHeight;
      final sinY = math.sin(_pose.yaw);
      final cosY = math.cos(_pose.yaw);
      x += (sinY * _vForward + cosY * _vStrafe) * dt;
      z += (cosY * _vForward - sinY * _vStrafe) * dt;
      final collider = _collider;
      if (collider != null) {
        (x, z) = collider.resolve(x, z);
      }
    }
    _pose = CameraPose(x: x, y: y, z: z, yaw: _pose.yaw, pitch: _pose.pitch);
  }

  /// The camera for this frame.
  Camera camera() {
    final eye = position;
    return PerspectiveCamera(
      position: eye,
      target: eye + forward * 10,
      fovRadiansY: fovRadiansY,
      fovFar: 1400,
    );
  }
}
