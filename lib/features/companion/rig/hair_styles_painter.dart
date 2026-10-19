import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/rig/hair_painter.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';

/// Her hair in every style: the bun of the pitch videos (`hair_painter.dart`)
/// and the styles a person may give her instead, in head-local units (origin at the face's centre,
/// y down; the face spans x ±45 and y -58..40).
///
/// Each style has a back layer, drawn behind the head and the body, and a
/// front layer over the forehead, whose outline also casts the forehead's
/// shadow. Like the bun's wisps, the parts that hang — the locs, the bob's
/// ends, the afro's mass — trail the head's motion by the hair lag.

/// How far a point at [y] trails the head: nothing at the crown, the full
/// lag at the ends.
double _hang(double y) =>
    math.pow(((y + 70) / 150).clamp(0.0, 1.0), 1.4).toDouble();

Offset _trail(Offset p, Offset lag) => p + lag * _hang(p.dy);

/// Points on an ellipse round [centre], from angle [a0] to [a1] (radians, y
/// down, 0 pointing right), [n] steps.
List<Offset> _arc(
  Offset centre,
  double rx,
  double ry,
  double a0,
  double a1,
  int n,
) => [
  for (var i = 0; i <= n; i++)
    centre +
        Offset(
          rx * math.cos(a0 + (a1 - a0) * i / n),
          ry * math.sin(a0 + (a1 - a0) * i / n),
        ),
];

/// The hair over the top of the head, from the left temple round the crown
/// to the right one.
List<Offset> _crown(double r, double y) =>
    _arc(Offset(0, y), r, r, math.pi, 2 * math.pi, 16);

void _sheen(Canvas canvas, Path hair, CompanionPalette c) {
  canvas
    ..save()
    ..clipPath(hair)
    ..drawPaint(
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-60, -110),
          const Offset(60, 0),
          [
            c.hairLight.withValues(alpha: 0.5),
            const Color(0x00FFFFFF),
            c.hairShade.withValues(alpha: 0.45),
          ],
          [0, 0.5, 1],
        ),
    )
    ..restore();
}

/// Little curls inside [region]: an arc in shade with a lit edge, on a
/// staggered grid so no two rows line up.
void _curlTexture(
  Canvas canvas,
  CompanionPalette c,
  Path region,
  Rect bounds,
  double step,
  double r,
) {
  var row = 0;
  for (var y = bounds.top + step / 2; y < bounds.bottom; y += step * 0.8) {
    final shift = row.isEven ? 0.0 : step / 2;
    for (var x = bounds.left + shift; x < bounds.right; x += step) {
      final at = Offset(x, y);
      if (!region.contains(at)) continue;
      final a = (x * 0.37 + y * 0.21) % (2 * math.pi);
      strokePath(canvas, arc(at, r, a, a + 4), c.hairShade, 1.2);
      strokePath(
        canvas,
        arc(at + const Offset(-0.6, -0.6), r * 0.7, a + 0.4, a + 2.4),
        c.hairLight.withValues(alpha: 0.8),
        0.9,
      );
    }
    row++;
  }
}

// ---- Curls: short and tight, close to the head. ----

List<Offset> _curlsCap() => [
  ..._crown(60, -34),
  const Offset(60, -10),
  const Offset(56, 10),
  const Offset(46, 20),
  const Offset(-46, 20),
  const Offset(-56, 10),
  const Offset(-60, -10),
];

List<Offset> _curlsFront(double yaw) => [
  for (final p in [
    ..._crown(61, -32),
    const Offset(56, -20),
    const Offset(48, -34),
    const Offset(34, -44),
    const Offset(16, -49),
    const Offset(0, -50),
    const Offset(-16, -49),
    const Offset(-34, -44),
    const Offset(-48, -34),
    const Offset(-56, -20),
  ])
    p + Offset(yaw * 4, 0),
];

void _drawCurlsBack(Canvas canvas, CompanionPalette c, Offset lag) {
  final cap = [for (final p in _curlsCap()) p + lag * 0.15];
  fillPath(canvas, smoothClosed(cap, 0.22), c.hairBack);
  for (final p in _crown(60, -34)) {
    fillCircle(canvas, p + lag * 0.15, 8.5, c.hairBack);
  }
}

void _drawCurlsFront(Canvas canvas, CompanionPalette c, double yaw) {
  final outline = _curlsFront(yaw);
  final hair = smoothClosed(outline, 0.24);
  fillPath(canvas, hair, c.hair);
  // A curly edge: bumps along the crown and the hairline.
  for (final p in outline) {
    fillCircle(canvas, p, p.dy < -40 && p.dx.abs() > 30 ? 7.5 : 5.5, c.hair);
  }
  _sheen(canvas, hair, c);
  final bounds = hair.getBounds();
  _curlTexture(canvas, c, hair, bounds, 11, 3.2);
}

// ---- Afro: full and round. ----

// Wider than tall, and no taller than the bust framing has room for above
// her head: its curls top out near y -99, the bun's at -90.
const _afroCentre = Offset(0, -38);
const _afroRx = 74.0;
const _afroRy = 52.0;
const _afroBump = 9.0;

/// Where the afro's outline meets the hairline at the temples (y -26), as an
/// angle below its equator.
final double _afroTemple = math.asin((-26 - _afroCentre.dy) / _afroRy);

List<Offset> _afroFront(Offset lag, double yaw) => [
  for (final p in _arc(
    _afroCentre,
    _afroRx,
    _afroRy,
    math.pi - _afroTemple,
    2 * math.pi + _afroTemple,
    28,
  ))
    p + lag * 0.25,
  for (final p in const [
    Offset(60, -26),
    Offset(48, -36),
    Offset(34, -46),
    Offset(16, -51),
    Offset(0, -52),
    Offset(-16, -51),
    Offset(-34, -46),
    Offset(-48, -36),
    Offset(-60, -26),
  ])
    p + Offset(yaw * 4, 0),
];

void _drawAfroBack(Canvas canvas, CompanionPalette c, Offset lag) {
  final outline = [
    for (final p in _arc(
      _afroCentre,
      _afroRx,
      _afroRy,
      0,
      2 * math.pi,
      36,
    ))
      p + lag * 0.25,
  ];
  fillPath(canvas, smoothClosed(outline, 0.2), c.hairBack);
  for (final p in outline) {
    fillCircle(canvas, p, _afroBump, c.hairBack);
  }
}

void _drawAfroFront(Canvas canvas, CompanionPalette c, Offset lag, double yaw) {
  final outline = _afroFront(lag, yaw);
  final hair = smoothClosed(outline, 0.2);
  fillPath(canvas, hair, c.hair);
  for (final p in outline.take(29)) {
    fillCircle(canvas, p, _afroBump, c.hair);
  }
  _sheen(canvas, hair, c);
  _curlTexture(canvas, c, hair, hair.getBounds().inflate(8), 12, 3.6);
}

// ---- Locs: to below the shoulders, the ends swinging. ----

/// Where each loc behind the head starts, and how far down it hangs.
const _backLocs = [
  (-48.0, -26.0, 92.0),
  (-38.0, -14.0, 100.0),
  (-26.0, -6.0, 96.0),
  (-12.0, -2.0, 104.0),
  (0.0, 0.0, 98.0),
  (12.0, -2.0, 102.0),
  (26.0, -6.0, 96.0),
  (38.0, -14.0, 100.0),
  (48.0, -26.0, 90.0),
];

void _loc(
  Canvas canvas,
  Offset from,
  Offset to,
  double width,
  Color fill,
  Color marks,
) {
  fillPath(canvas, tapered(from, to, width, width * 0.75), fill);
  // The twists: short marks across the loc, all the way down.
  final d = to - from;
  final n = Offset(-d.dy, d.dx) / d.distance;
  for (var t = 0.12; t < 0.95; t += 0.11) {
    final at = from + d * t;
    final half = width * (1 - 0.25 * t) * 0.42;
    strokePath(
      canvas,
      Path()
        ..moveToPoint(at - n * half)
        ..quadraticBezierTo(
          at.dx + d.dx * 0.02,
          at.dy + 2.2,
          at.dx + n.dx * half,
          at.dy + n.dy * half,
        ),
      marks,
      1,
    );
  }
}

void _drawLocsBack(Canvas canvas, CompanionPalette c, Offset lag) {
  fillPath(canvas, smoothClosed(_locsCap(), 0.22), c.hairBack);
  for (final (x, y, end) in _backLocs) {
    final from = Offset(x, y);
    final to = _trail(Offset(x * 1.3, end), lag * 1.6);
    _loc(canvas, from, to, 10, c.hairBack, c.hairShade);
  }
}

List<Offset> _locsCap() => [
  ..._crown(57, -34),
  const Offset(58, -8),
  const Offset(54, 14),
  const Offset(44, 22),
  const Offset(-44, 22),
  const Offset(-54, 14),
  const Offset(-58, -8),
];

List<Offset> _locsFront(double yaw) => [
  for (final p in [
    ..._crown(58, -34),
    const Offset(54, -22),
    const Offset(46, -36),
    const Offset(34, -46),
    const Offset(18, -51),
    const Offset(4, -52),
    const Offset(-10, -50),
    const Offset(-24, -47),
    const Offset(-40, -39),
    const Offset(-54, -24),
  ])
    p + Offset(yaw * 4, 0),
];

void _drawLocsFront(
  Canvas canvas,
  CompanionPalette c,
  Offset lag,
  double yaw,
) {
  final hair = smoothClosed(_locsFront(yaw), 0.24);
  fillPath(canvas, hair, c.hair);
  _sheen(canvas, hair, c);
  // Locs swept back from an off-centre parting.
  canvas
    ..save()
    ..clipPath(hair);
  final parting = Offset(-6 + yaw * 4, -92);
  for (var k = -5; k <= 5; k++) {
    final end = Offset(k * 12.0 + yaw * 4, k.abs() > 3 ? -20.0 : -48.0);
    strokePath(
      canvas,
      Path()
        ..moveToPoint(parting)
        ..quadraticBezierTo(
          (parting.dx + end.dx) / 2 + k * 3,
          (parting.dy + end.dy) / 2 - 6,
          end.dx,
          end.dy,
        ),
      c.hairShade.withValues(alpha: 0.7),
      1.3,
    );
  }
  canvas.restore();
  // Two locs each side, hanging in front of the shoulders.
  for (final s in [-1, 1]) {
    for (var k = 0; k < 2; k++) {
      final from = Offset(s * (50 + k * 6) + yaw * 3, -26 + k * 8);
      final to = _trail(
        Offset(s * (56 + k * 8) + yaw * 2, 74 + k * 10),
        lag * 1.5,
      );
      _loc(canvas, from, to, 8, c.hair, c.hairShade);
    }
  }
}

// ---- Bob: to the chin, with a straight fringe. ----

List<Offset> _bobBack(Offset lag) => [
  ..._crown(59, -34),
  const Offset(61, -8),
  const Offset(62, 14),
  _trail(const Offset(60, 32), lag),
  _trail(const Offset(50, 40), lag),
  const Offset(38, 36),
  const Offset(-38, 36),
  _trail(const Offset(-50, 40), lag),
  _trail(const Offset(-60, 32), lag),
  const Offset(-62, 14),
  const Offset(-61, -8),
];

List<Offset> _bobFront(Offset lag, double yaw) => [
  for (final p in [
    ..._crown(60, -34),
    const Offset(61, -10),
    const Offset(61, 12),
    _trail(const Offset(58, 30), lag),
    _trail(const Offset(48, 38), lag),
    const Offset(46, 22),
    const Offset(46, 0),
    const Offset(45, -24),
    const Offset(38, -36),
    const Offset(20, -39),
    const Offset(0, -40),
    const Offset(-20, -39),
    const Offset(-38, -36),
    const Offset(-45, -24),
    const Offset(-46, 0),
    const Offset(-46, 22),
    _trail(const Offset(-48, 38), lag),
    _trail(const Offset(-58, 30), lag),
    const Offset(-61, 12),
    const Offset(-61, -10),
  ])
    p + Offset(yaw * 4, 0),
];

void _drawBobFront(Canvas canvas, CompanionPalette c, Offset lag, double yaw) {
  final hair = smoothClosed(_bobFront(lag, yaw), 0.18);
  fillPath(canvas, hair, c.hair);
  _sheen(canvas, hair, c);
  // The fringe's strands, and a shine across the crown.
  canvas
    ..save()
    ..clipPath(hair);
  for (var x = -36.0; x <= 36; x += 8) {
    strokePath(
      canvas,
      Path()
        ..moveTo(x + yaw * 4, -62)
        ..lineTo(x + yaw * 4 + 1, -42),
      c.hairShade.withValues(alpha: 0.55),
      1.1,
    );
  }
  strokePath(
    canvas,
    arc(Offset(yaw * 4, -34), 48, 3.7, 5),
    c.hairLight.withValues(alpha: 0.8),
    3,
  );
  canvas.restore();
}

// ---- Every style. ----

/// The hair behind the head, in [style].
void drawBackHair(
  Canvas canvas,
  CompanionPalette c,
  Offset lag,
  CompanionHairStyle style,
) => switch (style) {
  CompanionHairStyle.bun => drawBunBack(canvas, c, lag),
  CompanionHairStyle.curls => _drawCurlsBack(canvas, c, lag),
  CompanionHairStyle.afro => _drawAfroBack(canvas, c, lag),
  CompanionHairStyle.locs => _drawLocsBack(canvas, c, lag),
  CompanionHairStyle.bob => fillPath(
    canvas,
    smoothClosed(_bobBack(lag), 0.2),
    c.hairBack,
  ),
};

/// The hair over the forehead, in [style].
void drawFrontHair(
  Canvas canvas,
  CompanionPalette c,
  Offset lag,
  double yaw,
  CompanionHairStyle style,
) => switch (style) {
  CompanionHairStyle.bun => drawBunFront(canvas, c, lag, yaw),
  CompanionHairStyle.curls => _drawCurlsFront(canvas, c, yaw),
  CompanionHairStyle.afro => _drawAfroFront(canvas, c, lag, yaw),
  CompanionHairStyle.locs => _drawLocsFront(canvas, c, lag, yaw),
  CompanionHairStyle.bob => _drawBobFront(canvas, c, lag, yaw),
};

/// The outline of the front hair in [style]: what shades the forehead below
/// it.
List<Offset> fringeFor(CompanionHairStyle style, Offset lag, double yaw) =>
    switch (style) {
      CompanionHairStyle.bun => bunFringe(lag, yaw),
      CompanionHairStyle.curls => _curlsFront(yaw),
      CompanionHairStyle.afro => _afroFront(lag, yaw),
      CompanionHairStyle.locs => _locsFront(yaw),
      CompanionHairStyle.bob => _bobFront(lag, yaw),
    };

/// The front hair's shadow on the forehead, in [style].
void drawForeheadShadow(
  Canvas canvas,
  CompanionPalette c,
  Offset lag,
  double yaw,
  CompanionHairStyle style,
) => fillPath(
  canvas,
  smoothClosed([
    for (final p in fringeFor(style, lag, yaw)) p + const Offset(0, 3.5),
  ], 0.24),
  c.skinDeep.withValues(alpha: 0.3),
);
