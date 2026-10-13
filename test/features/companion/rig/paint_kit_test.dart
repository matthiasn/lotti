import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';

import '../companion_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ellipse, circle and roundedRect have the bounds they are given', () {
    expect(
      ellipse(const Offset(10, 20), 5, 3).getBounds(),
      const Rect.fromLTRB(5, 17, 15, 23),
    );
    expect(
      circle(Offset.zero, 4).getBounds(),
      const Rect.fromLTRB(-4, -4, 4, 4),
    );
    expect(
      roundedRect(1, 2, 10, 6, 2).getBounds(),
      const Rect.fromLTRB(1, 2, 11, 8),
    );
  });

  test('arc runs clockwise from its first angle to its second', () {
    final b = arc(Offset.zero, 10, 0, math.pi / 2).getBounds();
    // From (10, 0) down to (0, 10): the lower right quarter.
    expect(b.left, closeTo(0, 1e-6));
    expect(b.top, closeTo(0, 1e-6));
    expect(b.right, closeTo(10, 1e-6));
    expect(b.bottom, closeTo(10, 1e-6));
  });

  test('tapered covers both ends with round caps of its widths', () {
    final p = tapered(Offset.zero, const Offset(40, 0), 10, 6);
    expect(p.contains(const Offset(-4, 0)), isTrue);
    expect(p.contains(const Offset(42.5, 0)), isTrue);
    expect(p.contains(const Offset(20, 4)), isTrue);
    expect(p.contains(const Offset(40, 3.5)), isFalse);
    expect(p.getBounds().top, closeTo(-5, 1e-6));
  });

  test('smoothClosed runs through every point and closes', () {
    const pts = [Offset.zero, Offset(40, 0), Offset(40, 40), Offset(0, 40)];
    final p = smoothClosed(pts);
    expect(p.contains(const Offset(20, 20)), isTrue);
    final b = p.getBounds();
    expect(b.left, lessThanOrEqualTo(0));
    expect(b.right, greaterThanOrEqualTo(40));
  });

  test('PathBuild draws through the offsets it is given', () {
    final p = Path()
      ..moveToPoint(Offset.zero)
      ..lineToPoint(const Offset(10, 0))
      ..curve(const Offset(10, 5), const Offset(5, 10), const Offset(0, 10))
      ..close();
    expect(p.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
  });

  test('fillPath, strokePath and fillCircle paint their colour', () async {
    const red = Color(0xFFFF0000);
    const green = Color(0xFF00FF00);
    const blue = Color(0xFF0000FF);
    final r = await Raster.of(60, 20, (canvas) {
      fillPath(canvas, ellipse(const Offset(10, 10), 6, 6), red);
      strokePath(
        canvas,
        Path()
          ..moveTo(25, 10)
          ..lineTo(35, 10),
        green,
        4,
      );
      fillCircle(canvas, const Offset(50, 10), 6, blue);
    });
    expect(r.at(10, 10), red);
    expect(r.at(30, 10), green);
    expect(r.at(50, 10), blue);
    expect(r.at(30, 3), const Color(0xFF000000));
  });
}
