import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';
import 'package:lotti/features/companion/rig/rig_math.dart';

/// Face features in head-local units (origin at the face's centre, y down):
/// eyes with lids and gaze, brows, nose, and the mouth.

/// Draws the mouth centred on (x, y). [smile] lifts both corners (below zero
/// turns them down); [skew] lifts the right one and lowers the left: a smirk.
void drawMouth(
  Canvas canvas,
  CompanionPalette c,
  double x,
  double y,
  MouthShape m,
  double smile, {
  double skew = 0,
}) {
  final hw = m.halfWidth * (1 + 0.08 * smile);
  final lift = 2.4 * smile;
  final liftL = 2.4 * (smile - skew);
  final liftR = 2.4 * (smile + skew);
  final lx = x - hw;
  final rx = x + hw;
  final cy = y - lift * 0.3;
  final topIn = cy - m.open * 0.32;
  final botIn = cy + m.open * 0.85;
  final rnd = m.round;
  final topOut = topIn - m.open * 0.15 - m.upperLip;
  final botOut = botIn + m.open * 0.2 + m.lowerLip;

  void upperEdge(Path p) => p
    ..moveTo(lx - 1.2, cy - liftL)
    ..cubicTo(
      lx + hw * 0.2,
      topOut + 1.2,
      x - hw * 0.45,
      topOut - 0.6,
      x - hw * 0.12,
      topOut + 0.2,
    )
    ..cubicTo(
      x - 0.8,
      topOut + 1,
      x + 0.8,
      topOut + 1,
      x + hw * 0.12,
      topOut + 0.2,
    )
    ..cubicTo(
      x + hw * 0.45,
      topOut - 0.6,
      rx - hw * 0.2,
      topOut + 1.2,
      rx + 1.2,
      cy - liftR,
    );

  // Outer lips: the upper with a soft cupid's bow, the lower fuller.
  final lips = Path();
  upperEdge(lips);
  lips
    ..cubicTo(
      rx - hw * 0.15,
      botOut + 1.5,
      lx + hw * 0.15,
      botOut + 1.5,
      lx - 1.2,
      cy - liftL,
    )
    ..close();
  fillPath(canvas, lips, c.lips);
  // The upper lip a touch darker: lit from above.
  final upper = Path();
  upperEdge(upper);
  upper
    ..cubicTo(
      rx - hw * 0.3,
      topIn + 0.5,
      lx + hw * 0.3,
      topIn + 0.5,
      lx - 1.2,
      cy - liftL,
    )
    ..close();
  fillPath(canvas, upper, c.lipsUpper);

  if (m.open > 0.6) {
    final inner = Path()
      ..moveTo(lx, cy - liftL)
      ..cubicTo(
        lx + hw * (0.3 - 0.25 * rnd),
        topIn - m.open * 0.15 * (1 + rnd),
        rx - hw * (0.3 - 0.25 * rnd),
        topIn - m.open * 0.15 * (1 + rnd),
        rx,
        cy - liftR,
      )
      ..cubicTo(
        rx - hw * (0.2 - 0.15 * rnd),
        botIn + m.open * 0.2 * (1 + rnd) - lift * 0.4,
        lx + hw * (0.2 - 0.15 * rnd),
        botIn + m.open * 0.2 * (1 + rnd) - lift * 0.4,
        lx,
        cy - liftL,
      )
      ..close();
    canvas
      ..save()
      ..clipPath(inner);
    fillPath(canvas, inner, c.mouthIn);
    if (m.tongue > 0.01) {
      fillPath(
        canvas,
        ellipse(
          Offset(x, botIn + 1.5),
          hw * 0.75,
          1 + m.open * 0.35 * m.tongue,
        ),
        c.tongue,
      );
    }
    if (m.tongueUp > 0.01) {
      fillPath(
        canvas,
        ellipse(
          Offset(x, topIn + m.open * 0.45),
          hw * 0.45,
          m.open * 0.35 * m.tongueUp + 0.5,
        ),
        c.tongue,
      );
    }
    if (m.teethTop > 0.01) {
      final th = math.min(m.open * 0.55, 3.2) * m.teethTop + m.bite * 2;
      canvas.drawRect(
        Rect.fromLTWH(
          lx + hw * 0.18,
          topIn - m.open * 0.3 - 2,
          hw * 1.64,
          th + m.open * 0.3 + 1.2,
        ),
        Paint()..color = c.teeth,
      );
    }
    if (m.teethBottom > 0.01) {
      final th = math.min(m.open * 0.4, 2) * m.teethBottom;
      canvas.drawRect(
        Rect.fromLTWH(lx + hw * 0.3, botIn - th + 1, hw * 1.4, th + 2),
        Paint()..color = c.teeth,
      );
    }
    canvas.restore();
  } else {
    // Closed: a seam that follows the smile.
    strokePath(
      canvas,
      Path()
        ..moveTo(lx + 0.6, cy - liftL)
        ..cubicTo(
          lx + hw * 0.4,
          cy + 0.9 + smile * 0.8,
          rx - hw * 0.4,
          cy + 0.9 + smile * 0.8,
          rx - 0.6,
          cy - liftR,
        ),
      c.mouthIn,
      1.1,
    );
  }
  if (m.bite > 0.01 && m.open <= 0.6) {
    canvas.drawRect(
      Rect.fromLTWH(lx + hw * 0.3, cy - 0.4, hw * 1.4, 2 * m.bite),
      Paint()..color = c.teeth,
    );
  }
  // The lower lip's highlight.
  fillPath(
    canvas,
    ellipse(Offset(x - hw * 0.15, botOut - m.lowerLip * 0.45), hw * 0.32, 0.9),
    c.lipsLight.withValues(alpha: 0.55),
  );
}

/// Draws one eye centred on [centre]; [side] is -1 for the left, +1 for the
/// right. [blink] 1 shuts it, [squint] lifts the lower lid, [gaze] moves the
/// iris. An animal's eye takes a bigger [irisRadius], a cat's a [slit] pupil,
/// and neither has the [lashes] at the outer corner.
void drawEye(
  Canvas canvas,
  CompanionPalette c,
  Offset centre,
  int side,
  double blink,
  double squint,
  Offset gaze, {
  double irisRadius = 7.6,
  bool slit = false,
  bool lashes = true,
}) {
  final cx = centre.dx;
  final cy = centre.dy;
  final s = side.toDouble();
  final inner = Offset(cx - s * 10.5, cy + 1);
  final outer = Offset(cx + s * 11.5, cy - 0.8);
  final closedY = cy + 2.5 + 2;
  final lid1 = Offset(cx - s * 7, lerpDouble(cy - 11.5, closedY, blink));
  final lid2 = Offset(cx + s * 7.5, lerpDouble(cy - 11.5, closedY, blink));
  final sq = squint * 0.55;
  final low1 = Offset(cx + s * 7, lerpDouble(cy + 8.5, cy - 1, sq));
  final low2 = Offset(cx - s * 6.5, lerpDouble(cy + 8.5, cy - 1, sq));

  // The lid's crease above.
  strokePath(
    canvas,
    Path()
      ..moveTo(cx - s * 8, cy - 12.5 + blink * 3)
      ..cubicTo(
        cx - s * 3,
        cy - 16 + blink * 3,
        cx + s * 5,
        cy - 16 + blink * 3,
        cx + s * 10,
        cy - 12 + blink * 3,
      ),
    c.skinShade.withValues(alpha: 0.6),
    1,
  );

  if (blink < 0.97) {
    final white = Path()
      ..moveToPoint(inner)
      ..curve(lid1, lid2, outer)
      ..curve(low1, low2, inner)
      ..close();
    canvas
      ..save()
      ..clipPath(white);
    fillPath(canvas, white, c.eyeWhite);
    final iris = Offset(cx + gaze.dx * 3.2 + s * 0.6, cy - 0.5 + gaze.dy * 2.2);
    canvas.drawCircle(
      iris,
      irisRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          iris + const Offset(-1.5, -2.5),
          irisRadius + 0.6,
          [c.irisLight, c.iris],
          [0.06, 1],
        ),
    );
    if (slit) {
      // Narrow in the light, a little rounder as the eye narrows.
      fillPath(
        canvas,
        ellipse(iris + const Offset(0, 0.3), 1.5 + squint, irisRadius * 0.82),
        c.pupil,
      );
    } else {
      fillCircle(
        canvas,
        iris + const Offset(0, 0.3),
        irisRadius * 0.47,
        c.pupil,
      );
    }
    fillCircle(
      canvas,
      iris + const Offset(-2.6, -2.8),
      2.2,
      const Color(0xFFFFFFFF),
    );
    fillCircle(
      canvas,
      iris + const Offset(2.6, 2.5),
      0.9,
      const Color(0xCCFFFFFF),
    );
    // The upper lid's shadow on the eyeball.
    fillPath(
      canvas,
      Path()
        ..moveToPoint(inner)
        ..curve(lid1, lid2, outer)
        ..lineTo(outer.dx, outer.dy + 3)
        ..cubicTo(
          lid2.dx,
          lid2.dy + 3.5,
          lid1.dx,
          lid1.dy + 3.5,
          inner.dx,
          inner.dy + 3,
        )
        ..close(),
      const Color(0x2E40261A),
    );
    canvas.restore();
  }

  // The upper lash line, and two lashes at the outer corner.
  strokePath(
    canvas,
    Path()
      ..moveToPoint(inner)
      ..curve(lid1, lid2, outer),
    c.ink,
    2.1,
  );
  if (!lashes) return;
  for (final (k, d) in [
    (0, const Offset(2.6, -2.2)),
    (1, const Offset(3.4, 0.2)),
  ]) {
    final from = Offset(
      outer.dx - s * (1.2 + k * 1.8),
      outer.dy - 0.6 - (1 - k) * 0.8,
    );
    strokePath(
      canvas,
      Path()
        ..moveToPoint(from)
        ..lineTo(from.dx + s * d.dx, from.dy + d.dy - 1.2),
      c.ink,
      1.3,
    );
  }
}

/// How far a brow may rise (positive) or fall (negative), in units of its
/// raise. A brow sits on a bone under skin: it travels a little and then
/// stops, so the lift saturates instead of growing with every mood, gesture,
/// flourish and spring overshoot added up — one brow up at its height
/// (`CompanionFlourish.oneBrow`) on a skeptical face once carried it far off
/// the eye into a hook.
const browMaxRise = 1.3;
const browMaxFall = 1.0;

/// [raise] as the brow can travel it: smoothly saturating at
/// [browMaxRise] going up, stopping at [browMaxFall] going down.
double browLift(double raise) {
  if (raise <= 0) return math.max(raise, -browMaxFall);
  final e = math.exp(2 * raise / browMaxRise);
  return browMaxRise * (e - 1) / (e + 1);
}

/// The brow's three anchor points for [centre], [side], [raise] and [tilt]:
/// its inner end, its peak and its outer end. The [tilt] — the inner end
/// drawn down in a frown, or up in worry — is limited, and gives way as the
/// brow rises: a brow lifted high cannot also knot at the nose. [arch] is how
/// high its peak stands over its ends: 1 for a woman's arched brow, less for
/// a man's straighter one.
({Offset inner, Offset peak, Offset outer}) browShape(
  Offset centre,
  int side,
  double raise,
  double tilt, {
  double arch = 1,
}) {
  final s = side.toDouble();
  final cx = centre.dx;
  final lift = browLift(raise);
  final give = 1 - 0.6 * math.max(0, lift) / browMaxRise;
  final t = tilt.clamp(-1.2, 1.2) * give;
  final y = centre.dy - lift * 3.5;
  return (
    inner: Offset(cx - s * 10, y + 2 - t * 2.5),
    peak: Offset(cx + s * 2, y - 3.2 * arch - lift * 0.6),
    outer: Offset(cx + s * 12.5, y + 1 + t * 0.8),
  );
}

/// Draws one brow centred on [centre]; [raise] lifts it, [tilt] lifts its
/// inner end, both within what a brow can do ([browShape]). [fullness]
/// thickens it downwards: above 1 for a younger face or a man's; [arch] is
/// [browShape]'s.
void drawBrow(
  Canvas canvas,
  CompanionPalette c,
  Offset centre,
  int side,
  double raise,
  double tilt, {
  double fullness = 1,
  double arch = 1,
}) {
  final f = fullness;
  final s = side.toDouble();
  final (:inner, :peak, :outer) = browShape(
    centre,
    side,
    raise,
    tilt,
    arch: arch,
  );
  fillPath(
    canvas,
    Path()
      ..moveTo(inner.dx, inner.dy + 2.6 * f)
      ..cubicTo(
        inner.dx + s,
        inner.dy - 2.2,
        peak.dx - s * 5,
        peak.dy - 2.4,
        peak.dx,
        peak.dy - 2.2,
      )
      ..cubicTo(
        peak.dx + s * 5,
        peak.dy - 2,
        outer.dx - s,
        outer.dy - 1.5,
        outer.dx,
        outer.dy,
      )
      ..cubicTo(
        outer.dx - s * 3,
        outer.dy + 0.6,
        peak.dx + s * 4,
        peak.dy + 1.6 * f,
        peak.dx,
        peak.dy + 1.6 * f,
      )
      ..cubicTo(
        peak.dx - s * 5,
        peak.dy + 1.8 * f,
        inner.dx + s,
        inner.dy + 2.4 * f,
        inner.dx,
        inner.dy + 2.6 * f,
      )
      ..close(),
    c.brow,
  );
}

/// Draws the nose with its tip at (x, y).
void drawNose(Canvas canvas, CompanionPalette c, double x, double y) {
  fillPath(
    canvas,
    Path()
      ..moveTo(x - 3.6, y + 1.2)
      ..cubicTo(x - 2.4, y + 3.6, x + 2.4, y + 3.6, x + 3.6, y + 1.2)
      ..cubicTo(x + 2, y + 2.2, x - 2, y + 2.2, x - 3.6, y + 1.2)
      ..close(),
    c.skinDeep,
  );
  strokePath(
    canvas,
    Path()
      ..moveTo(x - 1.6, y - 6)
      ..cubicTo(x - 2.6, y - 2, x - 2, y - 0.5, x - 1, y + 0.2),
    c.skinLight.withValues(alpha: 0.7),
    1,
  );
}
