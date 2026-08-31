import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

/// First-person walk camera with an animated overhead search mode.
///
/// Eye height ~1.7 m, WASD/arrows + drag-look on desktop. The overhead
/// toggle blends smoothly — transitions are animated, never cut (spec §10).
class FlyCameraController {
  FlyCameraController({
    required Vector3 position,
    required this._yaw,
  }) : _position = Vector3.copy(position);

  static const _eyeHeight = 1.7;
  static const _walkSpeed = 12.0;
  static const _sprintFactor = 3.0;
  static const _overheadHeight = 90.0;
  static const _overheadBack = 40.0;

  final Vector3 _position;
  double _yaw;
  double _pitch = 0;
  final Set<LogicalKeyboardKey> _pressed = {};

  double _overheadBlend = 0;
  bool _overhead = false;

  /// Scripted forward input (benchmark mode): -1..1, applied when no key is
  /// pressed.
  double autoForward = 0;

  Vector3 get position => _position;
  bool get overhead => _overhead;

  /// Feed key events from the harness. Returns true when handled.
  bool handleKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    final tracked = {
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
    };
    if (!tracked.contains(key)) return false;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _pressed.add(key);
    } else if (event is KeyUpEvent) {
      _pressed.remove(key);
    }
    return true;
  }

  /// Mouse-drag look, in logical pixels.
  void addLookDelta(double dx, double dy) {
    _yaw -= dx * 0.0035;
    _pitch = (_pitch - dy * 0.0035).clamp(-1.35, 1.35);
  }

  void toggleOverhead() => _overhead = !_overhead;

  /// Jump to a pose (used on preset change / locator entry).
  void reset({required Vector3 position, required double yaw}) {
    _position.setFrom(position);
    _yaw = yaw;
    _pitch = 0;
  }

  bool _down(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
      _pressed.contains(a) || _pressed.contains(b);

  /// Advance one frame.
  void update(double dt) {
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

    if (forwardInput != 0 || strafeInput != 0) {
      var speed = _walkSpeed;
      if (_down(LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight)) {
        speed *= _sprintFactor;
      }
      // Overhead mode pans faster: it is the search mode.
      speed *= 1 + _overheadBlend * 4;
      final sinY = math.sin(_yaw);
      final cosY = math.cos(_yaw);
      _position
        ..x += (sinY * forwardInput + cosY * strafeInput) * speed * dt
        ..z += (cosY * forwardInput - sinY * strafeInput) * speed * dt;
    }
    _position.y = _eyeHeight;

    final target = _overhead ? 1.0 : 0.0;
    final rate = dt * 2.2;
    _overheadBlend =
        _overheadBlend + (target - _overheadBlend).clamp(-rate, rate);
  }

  /// The camera for this frame.
  Camera camera() {
    final sinY = math.sin(_yaw);
    final cosY = math.cos(_yaw);
    final cosP = math.cos(_pitch);
    final forward = Vector3(sinY * cosP, math.sin(_pitch), cosY * cosP);

    // Smoothstep the blend so both ends ease.
    final t = _overheadBlend * _overheadBlend * (3 - 2 * _overheadBlend);

    final groundEye = _position;
    final overheadEye = Vector3(
      _position.x - sinY * _overheadBack,
      _overheadHeight,
      _position.z - cosY * _overheadBack,
    );
    final eye = Vector3(
      groundEye.x + (overheadEye.x - groundEye.x) * t,
      groundEye.y + (overheadEye.y - groundEye.y) * t,
      groundEye.z + (overheadEye.z - groundEye.z) * t,
    );

    final groundTarget = groundEye + forward * 10;
    // Overhead looks at the walker's spot, tracking the street.
    final overheadTarget = Vector3(_position.x, 0, _position.z);
    final lookAt = Vector3(
      groundTarget.x + (overheadTarget.x - groundTarget.x) * t,
      groundTarget.y + (overheadTarget.y - groundTarget.y) * t,
      groundTarget.z + (overheadTarget.z - groundTarget.z) * t,
    );

    return PerspectiveCamera(
      position: eye,
      target: lookAt,
      fovFar: 2500,
    );
  }
}
