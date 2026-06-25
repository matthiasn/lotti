import 'package:flutter/rendering.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';

/// Stands the character on the ground of a [size] canvas with its **feet** at
/// [feetFraction] of the height, horizontally at [centreX], facing right unless
/// [flip] (then mirrored), uniformly scaled by [scale]. [feetOffset] is the
/// rig's rest distance from origin to the feet (see
/// [CharacterScene.restFeetOffset]); the origin is lifted by it so the feet —
/// not the hips — land on the floor line.
Affine2D groundedBase(
  Size size, {
  required double centreX,
  double scale = 1,
  double feetFraction = 0.92,
  double feetOffset = 0,
  bool flip = false,
}) => Affine2D.translation(
  centreX,
  size.height * feetFraction - feetOffset * scale,
).multiply(Affine2D.scale(flip ? -scale : scale, scale));

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
    this.eyeOpenScale = 1,
    this.feetFraction = 0.9,
    this.groundColor,
    this.shadowColor = const Color(0x33000000),
    this.locomote = false,
    this.walkingPair = false,
    CharacterRenderer? renderer,
  }) : _renderer = renderer ?? CharacterRenderer();

  final CharacterScene scene;
  final Clip clip;
  final double timeSeconds;
  final Expression expression;
  final double scale;

  /// Manual eyelid multiplier (1 = no change) — drives the demo's blink.
  final double eyeOpenScale;

  /// Fraction of the canvas height at which the floor (and the feet) sit.
  final double feetFraction;

  /// When set, a floor band is filled from [feetFraction] to the bottom so the
  /// character has something to stand on instead of floating in the void.
  final Color? groundColor;

  /// Colour of the soft ground-contact shadow under the feet.
  final Color shadowColor;

  /// When true (and the clip carries a [Clip.locomotionSpeed]) the character
  /// travels: it walks across the stage and ping-pongs at the edges (turning to
  /// face the direction of travel). Travelling is what makes the planted foot
  /// hold still in world space instead of skating in place.
  final bool locomote;

  /// When true, paints two copies of the same rig side-by-side with a phase
  /// offset. The pair shares one travelling group centre, so they keep their
  /// lane spacing instead of ping-ponging into each other.
  final bool walkingPair;
  final CharacterRenderer _renderer;

  // Keep the cat this far from the stage edges as it walks back and forth.
  static const double _edgeMargin = 64;
  static const double _pairScaleFactor = 0.82;
  static const double _pairSpacing = 155;

  @override
  void paint(Canvas canvas, Size size) {
    final floorY = size.height * feetFraction;
    if (groundColor != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, floorY, size.width, size.height - floorY),
        Paint()..color = groundColor!,
      );
    }

    // Horizontal placement + facing: centred by default; ping-ponging across
    // the stage when locomotion is on, so the body travels over a planted foot.
    var centreX = size.width / 2;
    var flip = false;
    if (locomote && clip.locomotes) {
      final drawScale = walkingPair ? scale * _pairScaleFactor : scale;
      final travelPx =
          scene.locomotionOffset(clip, timeSeconds).abs() * drawScale;
      final groupHalfWidth = walkingPair ? _pairSpacing * drawScale / 2 : 0.0;
      final margin = _edgeMargin + groupHalfWidth;
      final band = (size.width - 2 * margin).clamp(1.0, size.width);
      final cyc = travelPx % (2 * band);
      final movingRight = cyc <= band;
      final pos = movingRight ? cyc : 2 * band - cyc; // triangle 0..band..0
      centreX = margin + pos;
      // Face the direction of travel. The authored cycle sweeps the planted
      // foot forward in body-space, so the character must be MIRRORED while it
      // walks in the +x direction for the foot to hold still on the floor (the
      // mirror cancels the foot's body-frame sweep against the body's travel).
      flip = movingRight;
    }

    if (walkingPair) {
      final drawScale = scale * _pairScaleFactor;
      final spacing = _pairSpacing * drawScale;
      _paintCharacterAt(
        canvas,
        size,
        floorY: floorY,
        centreX: centreX - spacing / 2,
        flip: flip,
        timeSeconds: timeSeconds,
        scale: drawScale,
      );
      _paintCharacterAt(
        canvas,
        size,
        floorY: floorY,
        centreX: centreX + spacing / 2,
        flip: flip,
        timeSeconds: timeSeconds + clip.duration * 0.5,
        scale: drawScale,
      );
      return;
    }

    _paintCharacterAt(
      canvas,
      size,
      floorY: floorY,
      centreX: centreX,
      flip: flip,
      timeSeconds: timeSeconds,
      scale: scale,
    );
  }

  void _paintCharacterAt(
    Canvas canvas,
    Size size, {
    required double floorY,
    required double centreX,
    required bool flip,
    required double timeSeconds,
    required double scale,
  }) {
    final base = groundedBase(
      size,
      centreX: centreX,
      scale: scale,
      feetFraction: feetFraction,
      feetOffset: scene.restFeetOffset,
      flip: flip,
    );
    final frame = scene.frameAt(
      clip: clip,
      timeSeconds: timeSeconds,
      expression: expression,
      base: base,
      eyeOpenScale: eyeOpenScale,
    );

    // Contact shadow: a soft ellipse pinned to the floor under the feet. As the
    // lowest foot lifts off the floor (passing, a jump) the shadow shrinks and
    // fades, which is what reads as weight and contact.
    final footY = scene.lowestDrawnY(frame.world);
    final lift = ((floorY - footY) / (90 * scale)).clamp(0.0, 1.0);
    final shadowW = 96 * scale * (1 - 0.5 * lift);
    final shadowAlpha = ((shadowColor.a * 255.0).round() * (1 - 0.7 * lift))
        .round()
        .clamp(0, 255);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centreX, floorY),
        width: shadowW,
        height: shadowW * 0.2,
      ),
      Paint()..color = shadowColor.withAlpha(shadowAlpha),
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
      old.eyeOpenScale != eyeOpenScale ||
      old.feetFraction != feetFraction ||
      old.groundColor != groundColor ||
      old.shadowColor != shadowColor ||
      old.locomote != locomote ||
      old.walkingPair != walkingPair ||
      old._renderer != _renderer;
}
