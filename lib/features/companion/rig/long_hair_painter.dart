import 'dart:math' as math;
import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';

/// Three straight and wavy styles, in head-local units (origin at the face's
/// centre, y down; the face spans x ±45 and y -58..40): long hair parted in
/// the middle and falling past the shoulders, soft waves to the shoulders
/// parted on the left, and a ponytail. Named for their shape, never for a
/// people; every character may wear them. What hangs — the long sheets, the
/// waves' ends, the tail — trails the head's motion by the hair lag.

/// [p], trailing the head by as much of [lag] as its height gives: none at
/// the crown, all of it at the ends.
Offset _hang(Offset p, Offset lag) =>
    p + lag * math.pow(((p.dy + 70) / 170).clamp(0.0, 1.0), 1.3).toDouble();

/// Points over the crown, from the left temple to the right, [r] out from
/// (0, [y]), turned by [yaw].
List<Offset> _crown(double r, double y, double yaw) => [
  for (var i = 0; i <= 16; i++)
    Offset(
      r * math.cos(math.pi + math.pi * i / 16) + yaw * 4,
      y + r * math.sin(math.pi + math.pi * i / 16),
    ),
];

/// Strokes [lines] in [colour] at [alpha], clipped to [hair].
void _comb(
  Canvas canvas,
  Path hair,
  List<Path> lines,
  Color colour,
  double alpha,
) {
  canvas
    ..save()
    ..clipPath(hair);
  for (final line in lines) {
    strokePath(canvas, line, colour.withValues(alpha: alpha), 1);
  }
  canvas.restore();
}

/// A soft light over the crown's near side, kept small so dark hair stays
/// dark.
void _shine(Canvas canvas, Path hair, CompanionPalette c, double yaw) {
  canvas
    ..save()
    ..clipPath(hair);
  fillPath(
    canvas,
    ellipse(Offset(-18 + yaw * 4, -78), 22, 9),
    c.hairLight.withValues(alpha: 0.35),
  );
  canvas.restore();
}

// ---- Long: straight, parted in the middle, past the shoulders. ----

List<Offset> _longBack(Offset lag) => [
  ..._crown(58, -34, 0),
  const Offset(60, -6),
  const Offset(61, 30),
  _hang(const Offset(60, 70), lag),
  _hang(const Offset(56, 108), lag),
  _hang(const Offset(36, 112), lag),
  const Offset(24, 60),
  const Offset(-24, 60),
  _hang(const Offset(-36, 112), lag),
  _hang(const Offset(-56, 108), lag),
  _hang(const Offset(-60, 70), lag),
  const Offset(-61, 30),
  const Offset(-60, -6),
];

/// The long hair's front: over the crown to a middle parting, and down
/// either side of the face in a curtain to below the jaw.
List<Offset> longFringe(Offset lag, double yaw) => [
  for (final p in [
    ..._crown(59, -34, 0),
    const Offset(60, -10),
    const Offset(60, 30),
    _hang(const Offset(58, 64), lag),
    _hang(const Offset(48, 72), lag),
    const Offset(44, 40),
    const Offset(44, 0),
    const Offset(43, -24),
    const Offset(34, -40),
    const Offset(14, -48),
    const Offset(2, -50),
    const Offset(0, -46),
    const Offset(-2, -50),
    const Offset(-14, -48),
    const Offset(-34, -40),
    const Offset(-43, -24),
    const Offset(-44, 0),
    const Offset(-44, 40),
    _hang(const Offset(-48, 72), lag),
    _hang(const Offset(-58, 64), lag),
    const Offset(-60, 30),
    const Offset(-60, -10),
  ])
    p + Offset(yaw * 4, 0),
];

void drawLongBack(Canvas canvas, CompanionPalette c, Offset lag) =>
    fillPath(canvas, smoothClosed(_longBack(lag), 0.2), c.hairBack);

void drawLongFront(Canvas canvas, CompanionPalette c, Offset lag, double yaw) {
  final hair = smoothClosed(longFringe(lag, yaw), 0.2);
  fillPath(canvas, hair, c.hair);
  _shine(canvas, hair, c, yaw);
  final x = yaw * 4;
  _comb(
    canvas,
    hair,
    [
      // The parting, and the hair falling straight from it.
      Path()
        ..moveTo(x, -47)
        ..lineTo(x, -92),
      for (final s in [-1.0, 1.0])
        for (var k = 0; k < 4; k++)
          Path()
            ..moveTo(x + s * (4 + k * 10), -88 + k * 8)
            ..quadraticBezierTo(
              x + s * (40 + k * 4),
              -60 + k * 6,
              x + s * (48 + k * 3),
              30 + k * 10,
            ),
    ],
    c.hairShade,
    0.45,
  );
}

// ---- Waves: soft, to the shoulders, parted on the left. ----

/// One side's wavy edge, from the temple down to the shoulder on side [s],
/// alternately in and out.
List<Offset> _waveSide(double s, Offset lag, {required bool back}) => [
  for (var k = 0; k < 6; k++)
    _hang(
      Offset(s * (back ? 62 : 60) + s * (k.isEven ? 0 : 6), -8 + k * 12),
      lag,
    ),
];

List<Offset> _wavesBack(Offset lag) => [
  ..._crown(59, -34, 0),
  ..._waveSide(1, lag, back: true),
  _hang(const Offset(46, 66), lag),
  const Offset(26, 50),
  const Offset(-26, 50),
  _hang(const Offset(-46, 66), lag),
  ..._waveSide(-1, lag, back: true).reversed,
];

/// The waves' front: over the crown, a fringe swept across the forehead
/// from a parting on the left, and wavy curtains down to the shoulders.
List<Offset> wavesFringe(Offset lag, double yaw) => [
  for (final p in [
    ..._crown(60, -34, 0),
    ..._waveSide(1, lag, back: false),
    _hang(const Offset(48, 64), lag),
    const Offset(44, 36),
    const Offset(45, 4),
    const Offset(44, -20),
    const Offset(36, -32),
    const Offset(18, -37),
    const Offset(0, -43),
    const Offset(-14, -51),
    const Offset(-28, -44),
    const Offset(-42, -30),
    const Offset(-45, 4),
    const Offset(-44, 36),
    _hang(const Offset(-48, 64), lag),
    ..._waveSide(-1, lag, back: false).reversed,
  ])
    p + Offset(yaw * 4, 0),
];

void drawWavesBack(Canvas canvas, CompanionPalette c, Offset lag) =>
    fillPath(canvas, smoothClosed(_wavesBack(lag), 0.25), c.hairBack);

void drawWavesFront(Canvas canvas, CompanionPalette c, Offset lag, double yaw) {
  final hair = smoothClosed(wavesFringe(lag, yaw), 0.25);
  fillPath(canvas, hair, c.hair);
  _shine(canvas, hair, c, yaw);
  final x = yaw * 4;
  _comb(
    canvas,
    hair,
    [
      // The sweep across the forehead from the parting.
      for (var k = 0; k < 4; k++)
        Path()
          ..moveTo(x - 14, -52 - k * 6)
          ..quadraticBezierTo(x + 10, -48 - k * 6, x + 40 + k * 4, -30 - k * 8),
      // A soft S down each side.
      for (final s in [-1.0, 1.0])
        for (var k = 0; k < 3; k++)
          Path()
            ..moveTo(x + s * (50 + k * 3), -14)
            ..cubicTo(
              x + s * (58 + k * 3),
              8,
              x + s * (46 + k * 3),
              28,
              x + s * (54 + k * 3),
              52,
            ),
    ],
    c.hairShade,
    0.5,
  );
}

// ---- Ponytail: pulled back smooth, the tail swinging behind. ----

/// The hair behind the head, pulled back tight: it hugs the skull and
/// shows beside the face no lower than the temples.
List<Offset> _ponyCap() => [
  ..._crown(54, -34, 0),
  const Offset(52, -22),
  const Offset(44, -6),
  const Offset(-44, -6),
  const Offset(-52, -22),
];

/// The tail, from its tie at the back of the crown out over the right and
/// down behind the neck, its end swinging furthest.
List<Offset> _tail(Offset lag) => [
  const Offset(30, -66),
  const Offset(48, -58),
  _hang(const Offset(62, -30), lag * 1.4),
  _hang(const Offset(64, 10), lag * 1.6),
  _hang(const Offset(58, 52), lag * 1.8),
  _hang(const Offset(50, 76), lag * 2),
  _hang(const Offset(46, 48), lag * 1.8),
  _hang(const Offset(48, 8), lag * 1.6),
  const Offset(40, -40),
  const Offset(26, -56),
];

/// The ponytail's front: smooth over the crown, the hairline clear of the
/// forehead, everything pulled back.
List<Offset> ponytailFringe(double yaw) => [
  for (final p in [
    ..._crown(56, -34, 0),
    const Offset(50, -28),
    const Offset(42, -40),
    const Offset(28, -48),
    const Offset(14, -51),
    const Offset(0, -52),
    const Offset(-14, -51),
    const Offset(-28, -48),
    const Offset(-42, -40),
    const Offset(-50, -28),
  ])
    p + Offset(yaw * 4, 0),
];

void drawPonytailBack(Canvas canvas, CompanionPalette c, Offset lag) {
  fillPath(canvas, smoothClosed(_ponyCap(), 0.22), c.hairBack);
  final tail = smoothClosed(_tail(lag));
  fillPath(canvas, tail, c.hairBack);
  _comb(
    canvas,
    tail,
    [
      for (var k = 0; k < 3; k++)
        Path()
          ..moveTo(36 + k * 4, -58)
          ..quadraticBezierTo(62 + k * 2, -20, 50 + k * 3, 60),
    ],
    c.hairShade,
    0.6,
  );
  // The tie round the tail's root.
  fillPath(canvas, ellipse(const Offset(36, -60), 6, 4.5), c.hairShade);
}

void drawPonytailFront(Canvas canvas, CompanionPalette c, double yaw) {
  final hair = smoothClosed(ponytailFringe(yaw), 0.24);
  fillPath(canvas, hair, c.hair);
  _shine(canvas, hair, c, yaw);
  final x = yaw * 4;
  _comb(
    canvas,
    hair,
    [
      // Combed back from the hairline towards the tie.
      for (var k = -4; k <= 4; k++)
        Path()
          ..moveTo(x + k * 11, -50 + k.abs() * 2.5)
          ..quadraticBezierTo(x + k * 7, -78, x + 30, -90),
    ],
    c.hairShade,
    0.4,
  );
}
