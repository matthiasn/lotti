import 'dart:math' as math;
import 'dart:ui';

/// The few drawing moves the rig repeats: fills, strokes, ellipses and
/// tapered limbs, so the painters read close to the Python rig they were
/// ported from.

void fillPath(Canvas canvas, Path path, Color color) =>
    canvas.drawPath(path, Paint()..color = color);

void strokePath(
  Canvas canvas,
  Path path,
  Color color,
  double width, {
  StrokeCap cap = StrokeCap.round,
}) => canvas.drawPath(
  path,
  Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = cap
    ..strokeJoin = StrokeJoin.round,
);

Path ellipse(Offset centre, double rx, double ry) =>
    Path()
      ..addOval(Rect.fromCenter(center: centre, width: rx * 2, height: ry * 2));

Path circle(Offset centre, double r) =>
    Path()..addOval(Rect.fromCircle(center: centre, radius: r));

void fillCircle(Canvas canvas, Offset centre, double r, Color color) =>
    canvas.drawCircle(centre, r, Paint()..color = color);

/// An open arc of a circle, as cairo draws it: clockwise from [a0] to [a1].
Path arc(Offset centre, double r, double a0, double a1) =>
    Path()..addArc(Rect.fromCircle(center: centre, radius: r), a0, a1 - a0);

/// A limb segment from [a] to [b], [wa] wide at one end and [wb] at the
/// other, with round ends.
Path tapered(Offset a, Offset b, double wa, double wb) {
  final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
  final n = Offset(-math.sin(ang), math.cos(ang));
  final p = Path()
    ..moveTo(a.dx + n.dx * wa / 2, a.dy + n.dy * wa / 2)
    ..lineTo(b.dx + n.dx * wb / 2, b.dy + n.dy * wb / 2)
    ..arcTo(
      Rect.fromCircle(center: b, radius: wb / 2),
      ang + math.pi / 2,
      -math.pi,
      false,
    )
    ..lineTo(a.dx - n.dx * wa / 2, a.dy - n.dy * wa / 2)
    ..arcTo(
      Rect.fromCircle(center: a, radius: wa / 2),
      ang - math.pi / 2,
      -math.pi,
      false,
    );
  return p..close();
}

/// Shorthands for building paths from [Offset]s.
extension PathBuild on Path {
  void moveToPoint(Offset p) => moveTo(p.dx, p.dy);

  void lineToPoint(Offset p) => lineTo(p.dx, p.dy);

  void curve(Offset c1, Offset c2, Offset p) =>
      cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p.dx, p.dy);
}

/// A closed, smooth (Catmull-Rom-like) outline through [pts].
Path smoothClosed(List<Offset> pts, [double tension = 0.3]) {
  final n = pts.length;
  final path = Path()..moveToPoint(pts.first);
  for (var i = 0; i < n; i++) {
    final p0 = pts[(i - 1 + n) % n];
    final p1 = pts[i];
    final p2 = pts[(i + 1) % n];
    final p3 = pts[(i + 2) % n];
    path.curve(p1 + (p2 - p0) * tension, p2 - (p3 - p1) * tension, p2);
  }
  return path..close();
}

/// A rounded rectangle outline.
Path roundedRect(double x, double y, double w, double h, double r) =>
    Path()..addRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
    );
