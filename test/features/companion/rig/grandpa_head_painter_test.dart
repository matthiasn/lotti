import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/grandpa_head_painter.dart';

import '../companion_test_utils.dart';

final CompanionPalette _c = CompanionLook.grandpa.palette;
const _black = Color(0xFF000000);

/// Head-local units at twice their size, the face's centre at (120, 140)
/// of a 240 × 260 canvas.
Future<Raster> _draw(void Function(Canvas canvas) draw) =>
    Raster.of(240, 260, (canvas) {
      canvas
        ..translate(120, 140)
        ..scale(2);
      draw(canvas);
    });

/// The canvas pixel at head-local ([x], [y]).
Offset _px(double x, double y) => Offset(120 + x * 2, 140 + y * 2);

double _meanX(List<Offset> pts) =>
    pts.map((p) => p.dx).reduce((a, b) => a + b) / pts.length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the beard', () {
    test('covers the jaw and the chin, and keeps clear of the eyes', () async {
      final r = await _draw((c) => drawBeard(c, _c, 0));
      expect(r.count(_c.hair, tolerance: 20), greaterThan(1500));
      final chin = _px(0, 40);
      expect(r.at(chin.dx, chin.dy), isNot(_black));
      for (final x in [-19.0, 19.0]) {
        final eye = _px(x, -6);
        expect(r.at(eye.dx, eye.dy), _black);
      }
      // The nose and the cheeks above the beard's inner edge stay bare.
      final nose = _px(0, 8);
      expect(r.at(nose.dx, nose.dy), _black);
    });

    test('is in shade under the jaw', () async {
      final r = await _draw((c) => drawBeard(c, _c, 0));
      final under = _px(0, 44);
      final cheek = _px(-40, 4);
      expect(
        r.at(under.dx, under.dy).computeLuminance(),
        lessThan(r.at(cheek.dx, cheek.dy).computeLuminance()),
      );
    });

    test('turns with the head', () {
      expect(_meanX(beardOutline(1)), greaterThan(_meanX(beardOutline(0))));
    });
  });

  group('the moustache', () {
    test('sits between the nose and the mouth, as wide as the mouth', () {
      final b = moustachePath(0, 0).getBounds();
      expect(b.top, greaterThan(8)); // the nose
      expect(b.bottom, lessThan(23)); // the mouth's line
      expect(b.width, closeTo(36, 2));
      expect(b.center.dx, closeTo(0, 0.5));
    });

    test('follows the face as it turns and tips', () {
      final b = moustachePath(4, 3).getBounds();
      expect(b.center.dx, closeTo(4.4, 0.5));
      expect(b.top, greaterThan(moustachePath(0, 0).getBounds().top));
    });

    test('is painted in the hair colour, lit along its top', () async {
      final r = await _draw((c) => drawMoustache(c, _c, 0, 0));
      expect(r.count(_c.hair, tolerance: 20), greaterThan(150));
      final centre = r.centroid(_c.hair, tolerance: 20)!;
      expect(centre.dy, closeTo(_px(0, 15).dy, 6));
    });
  });

  group('the flat cap', () {
    test('sits on the crown, its brim over the brow', () {
      final b = flatCapPath(0).getBounds();
      expect(b.bottom, lessThan(-30)); // above the brows' -27
      expect(b.top, lessThan(-80));
      expect(b.width, greaterThan(100));
    });

    test('turns with the head', () {
      expect(
        flatCapPath(1).getBounds().center.dx,
        greaterThan(flatCapPath(0).getBounds().center.dx),
      );
    });

    test('paints its crown, and its peak darker', () async {
      final r = await _draw((c) => drawFlatCap(c, _c, 0));
      expect(r.count(_c.cap), greaterThan(2000));
      final peak = _px(0, -32);
      expect(near(r.at(peak.dx, peak.dy), _c.capShade), isTrue);
    });
  });
}
