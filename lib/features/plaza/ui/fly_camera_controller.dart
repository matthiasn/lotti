import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/flight.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/walk_collider.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

/// First-person walk camera with flights.
///
/// WASD/arrows walk (shift sprints), drag looks, and [flyTo] hands the pose
/// to a [Flight]; any movement input cancels a flight in place. Walking
/// happens at [eyeHeight] and stays out of buildings via the collider; a
/// pose set elsewhere (the overview) keeps its height until the next step.
class FlyCameraController {
  FlyCameraController({required CameraPose pose, WalkCollider? collider})
    : _pose = pose,
      _collider = collider;
  // ignore_for_file: prefer_initializing_formals

  static const walkSpeed = 5.0;
  static const _sprintFactor = 3.0;

  /// Vertical field of view: a game camera, not a phone lens.
  static const double fovRadiansY = 60 * math.pi / 180;

  /// Velocity smoothing: reaches ~63% of the target in this many seconds.
  static const _accelSeconds = 0.12;

  double _vForward = 0;
  double _vStrafe = 0;

  CameraPose _pose;
  final WalkCollider? _collider;
  final Set<LogicalKeyboardKey> _pressed = {};
  Flight? _flight;

  /// Called when a flight lands.
  void Function()? onArrived;

  /// Called when movement input cancels a flight.
  void Function()? onFlightCancelled;

  /// Called on any movement input (used to abandon the morning walk).
  void Function()? onMovement;

  CameraPose get pose => _pose;
  set pose(CameraPose value) {
    _pose = value;
    _flight = null;
    _vForward = 0;
    _vStrafe = 0;
  }

  Vector3 get position => Vector3(_pose.x, _pose.y, _pose.z);
  double get yaw => _pose.yaw;
  double get pitch => _pose.pitch;
  Flight? get flight => _flight;
  bool get flying => _flight != null;

  /// Starts a flight to [target]; the current flight, if any, is replaced.
  Flight flyTo(CameraPose target, {double timeScale = 1}) {
    final flight = Flight.plan(_pose, target, timeScale: timeScale);
    _flight = flight;
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

  void _movementInput() {
    if (_flight != null) {
      _flight = null;
      onFlightCancelled?.call();
    }
    onMovement?.call();
  }

  /// Mouse-drag look, in logical pixels. Cancels a flight in place.
  void addLookDelta(double dx, double dy) {
    if (_flight != null) {
      _flight = null;
      onFlightCancelled?.call();
    }
    _pose = CameraPose(
      x: _pose.x,
      y: _pose.y,
      z: _pose.z,
      yaw: _pose.yaw - dx * 0.0032,
      pitch: (_pose.pitch - dy * 0.0028).clamp(-1.25, 1.25),
    );
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

    final forwardInput =
        (_down(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp)
            ? 1.0
            : 0.0) -
        (_down(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown)
            ? 1.0
            : 0.0);
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
    final sinY = math.sin(_pose.yaw);
    final cosY = math.cos(_pose.yaw);
    final cosP = math.cos(_pose.pitch);
    final forward = Vector3(sinY * cosP, math.sin(_pose.pitch), cosY * cosP);
    final eye = position;
    return PerspectiveCamera(
      position: eye,
      target: eye + forward * 10,
      fovRadiansY: fovRadiansY,
      fovFar: 2500,
    );
  }
}
