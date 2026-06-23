import 'package:flutter/rendering.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';

/// Computes a base transform that stands the character on the ground of a
/// [size] canvas: origin (hips) horizontally centred, feet near the bottom,
/// uniformly scaled by [scale].
Affine2D groundedBase(
  Size size, {
  double scale = 1,
  double feetFraction = 0.92,
}) => Affine2D.translation(
  size.width / 2,
  size.height * feetFraction,
).multiply(Affine2D.scale(scale, scale));

/// A [CustomPainter] that resolves and draws one frame of a [CharacterScene].
///
/// Per the plan's perf guidance the live ticker lives in the widget `State`,
/// not in a provider; this painter just turns `(clip, time, expression)` into
/// pixels via the shared [CharacterRenderer].
class CharacterPainter extends CustomPainter {
  CharacterPainter({
    required this.scene,
    required this.clip,
    required this.timeSeconds,
    this.expression = Expression.neutral,
    this.scale = 1,
    CharacterRenderer? renderer,
  }) : _renderer = renderer ?? CharacterRenderer();

  final CharacterScene scene;
  final Clip clip;
  final double timeSeconds;
  final Expression expression;
  final double scale;
  final CharacterRenderer _renderer;

  @override
  void paint(Canvas canvas, Size size) {
    final base = groundedBase(size, scale: scale);
    final frame = scene.frameAt(
      clip: clip,
      timeSeconds: timeSeconds,
      expression: expression,
      base: base,
    );
    _renderer.paint(canvas, scene.rig, frame.world, frame.face);
  }

  @override
  bool shouldRepaint(CharacterPainter old) =>
      old.timeSeconds != timeSeconds ||
      old.clip != clip ||
      old.expression != expression ||
      old.scene != scene ||
      old.scale != scale ||
      old._renderer != _renderer;
}
