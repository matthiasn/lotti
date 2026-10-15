import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';

/// Silver hair in a soft low bun, in head-local units (origin at the face's
/// centre).
///
/// The cap sits close to the head, parted a little off centre, with soft
/// waves swept back over the ears into a bun low behind the left side of the
/// neck. A few loose strands at the temples carry the lag the spring gives
/// the hair, so a nod still moves something, the way a bun's wisps do.

List<Offset> _lagged(List<Offset> pts, Offset lag) => [
  for (final p in pts)
    () {
      final w = math.pow(((p.dy + 70) / 110).clamp(0.0, 1.0), 1.6).toDouble();
      return p + lag * w;
    }(),
];

/// The hair cap: close to the skull, down over the ears to the nape.
List<Offset> capOutline() => [
  for (var i = 0; i < 15; i++)
    Offset(
      56 * math.cos(math.pi + math.pi * i / 14),
      -34 + 56 * math.sin(math.pi + math.pi * i / 14),
    ),
  const Offset(58, -8),
  const Offset(54, 14),
  const Offset(44, 22),
  const Offset(-44, 22),
  const Offset(-54, 14),
  const Offset(-58, -8),
];

/// The hairline: swept back from an off-centre parting, the forehead clear.
List<Offset> fringeOutline() => [
  for (var i = 0; i < 13; i++)
    Offset(
      57 * math.cos(math.pi + math.pi * i / 12),
      -34 + 56 * math.sin(math.pi + math.pi * i / 12),
    ),
  const Offset(54, -22),
  const Offset(46, -36),
  const Offset(34, -46),
  const Offset(18, -51),
  const Offset(4, -52),
  const Offset(-10, -50),
  const Offset(-24, -47),
  const Offset(-40, -39),
  const Offset(-54, -24),
];

/// The bun and the cap behind the face.
void drawBackHair(Canvas canvas, CompanionPalette c, Offset lag) {
  final bun = Offset(-26 + lag.dx * 0.6, 26 + lag.dy * 0.4);
  fillPath(canvas, ellipse(bun, 21, 18), c.hairBack);
  for (var k = 0; k < 4; k++) {
    final a = -0.6 + k * 0.9;
    strokePath(
      canvas,
      arc(bun, 12 - k * 1.5, a, a + 1.9),
      c.hairShade.withValues(alpha: 0.7),
      1.5,
    );
  }
  fillPath(
    canvas,
    smoothClosed(
      _lagged(capOutline(), Offset(lag.dx * 0.4, lag.dy * 0.3)),
      0.22,
    ),
    c.hairBack,
  );
}

List<Offset> _fringe(Offset lag, double yaw) => [
  for (final p in _lagged(fringeOutline(), lag * 0.4)) p + Offset(yaw * 4, 0),
];

/// The hair over the forehead, its waves and the loose strands.
void drawFrontHair(Canvas canvas, CompanionPalette c, Offset lag, double yaw) {
  final fringe = smoothClosed(_fringe(lag, yaw), 0.24);
  fillPath(canvas, fringe, c.hair);
  canvas
    ..save()
    ..clipPath(fringe)
    ..drawPaint(
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-60, -100),
          const Offset(60, -10),
          [
            c.hairLight.withValues(alpha: 0.55),
            const Color(0x00FFFFFF),
            c.hairShade.withValues(alpha: 0.5),
          ],
          [0, 0.5, 1],
        ),
    )
    ..restore();
  _waveMarks(canvas, c, yaw);
  _wisps(canvas, c, lag, yaw);
}

/// The fringe's shadow on the forehead.
void drawForeheadShadow(
  Canvas canvas,
  CompanionPalette c,
  Offset lag,
  double yaw,
) {
  fillPath(
    canvas,
    smoothClosed([
      for (final p in _fringe(lag, yaw)) p + const Offset(0, 3.5),
    ], 0.24),
    c.skinDeep.withValues(alpha: 0.3),
  );
}

/// Swept-back waves: arcs that follow the hair from the parting to the ears.
const _waves = [
  (-8.0, -62.0, 30.0, 3.4, 4.6),
  (12.0, -70.0, 26.0, 3.6, 4.9),
  (30.0, -58.0, 22.0, 3.9, 5.2),
  (-30.0, -60.0, 24.0, 2.9, 4.1),
  (-46.0, -40.0, 16.0, 2.6, 3.9),
  (48.0, -40.0, 16.0, 5.4, 6.6),
];

void _waveMarks(Canvas canvas, CompanionPalette c, double yaw) {
  for (final (x, y, r, a0, a1) in _waves) {
    strokePath(
      canvas,
      arc(Offset(x + yaw * 4, y), r, a0, a1),
      c.hairShade.withValues(alpha: 0.5),
      1.5,
    );
    strokePath(
      canvas,
      arc(Offset(x + yaw * 4 - 1, y - 1.5), r * 0.9, a0 + 0.1, a1 - 0.2),
      c.hairLight.withValues(alpha: 0.7),
      1.1,
    );
  }
}

/// Two loose strands at each temple: the only hair the lag swings.
void _wisps(Canvas canvas, CompanionPalette c, Offset lag, double yaw) {
  for (final s in [-1, 1]) {
    for (var k = 0; k < 2; k++) {
      final x0 = s * (50 + k * 4) + yaw * 3;
      final y0 = -26.0 + k * 8;
      strokePath(
        canvas,
        Path()
          ..moveTo(x0, y0)
          ..cubicTo(
            x0 + s * 4 + lag.dx * 0.6,
            y0 + 12 + lag.dy * 0.5,
            x0 + s * 2 + lag.dx * 1.2,
            y0 + 22 + lag.dy,
            x0 - s * 3 + lag.dx * 1.6,
            y0 + 30 + lag.dy * 1.2,
          ),
        c.hair.withValues(alpha: 0.95),
        2.4 - k * 0.6,
      );
    }
  }
}
